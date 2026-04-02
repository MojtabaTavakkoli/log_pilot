import 'package:gql/ast.dart';
import 'package:gql_exec/gql_exec.dart';
import 'package:gql_link/gql_link.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';
import 'package:log_pilot/src/network/network_log_formatter.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// A GraphQL [Link] that logs operations through LogPilot.
///
/// ```dart
/// final link = LogPilotGraphQLLink().concat(httpLink);
/// final client = GraphQLClient(link: link, cache: GraphQLCache());
/// ```
class LogPilotGraphQLLink extends Link {
  LogPilotGraphQLLink({
    LogPilotPrinter? printer,
    this.logQuery = true,
    this.logVariables = true,
    this.logData = true,
    this.logErrors = true,
    this.createRecords = true,
  }) : _printer = printer;

  final LogPilotPrinter? _printer;
  final bool logQuery;
  final bool logVariables;
  final bool logData;
  final bool logErrors;

  /// When `true` (default), a [LogPilotRecord] is dispatched to history,
  /// sinks, and the overlay for each completed operation.
  final bool createRecords;

  LogPilotPrinter get _p => _printer ?? LogPilotZone.printer;

  NetworkLogFormatter? _cachedFormatter;
  LogPilotPrinter? _cachedPrinter;

  NetworkLogFormatter get _formatter {
    final p = _p;
    if (_cachedFormatter == null || _cachedPrinter != p) {
      _cachedPrinter = p;
      _cachedFormatter = NetworkLogFormatter(p);
    }
    return _cachedFormatter!;
  }

  @override
  Stream<Response> request(Request request, [NextLink? forward]) async* {
    final operationType = _operationType(request.operation.document);
    final operationName = request.operation.operationName;

    final stopwatch = Stopwatch()..start();

    _p.printNetwork(
      title: 'GraphQL $operationType',
      level: LogLevel.debug,
      lines: _formatter.formatGraphQL(
        operationType: operationType,
        operationName: operationName,
        query: logQuery ? _printNode(request.operation.document) : null,
        variables: logVariables
            ? Map<String, dynamic>.from(request.variables)
            : null,
      ),
    );

    if (forward == null) return;

    await for (final response in forward(request)) {
      stopwatch.stop();

      final errors = response.errors;
      final hasErrors = errors != null && errors.isNotEmpty;

      if (hasErrors && logErrors) {
        _p.printNetwork(
          title: 'GraphQL Error',
          level: LogLevel.error,
          lines: _formatter.formatGraphQL(
            operationType: operationType,
            operationName: operationName,
            errors: errors
                .map((e) => <String, dynamic>{
                      'message': e.message,
                      if (e.locations != null)
                        'locations': e.locations
                            ?.map((l) => {'line': l.line, 'column': l.column})
                            .toList(),
                      if (e.path != null) 'path': e.path,
                    })
                .toList(),
            data: logData ? response.data : null,
            duration: stopwatch.elapsed,
          ),
        );
      } else {
        _p.printNetwork(
          title: 'GraphQL Response',
          level: LogLevel.info,
          lines: _formatter.formatGraphQL(
            operationType: operationType,
            operationName: operationName,
            data: logData ? response.data : null,
            duration: stopwatch.elapsed,
          ),
        );
      }

      if (createRecords) {
        final ms = stopwatch.elapsedMilliseconds;
        final name = operationName ?? operationType;
        LogPilot.log(
          hasErrors ? LogLevel.error : LogLevel.info,
          'GraphQL $name'
              '${hasErrors ? ' (${errors.length} error(s))' : ''}'
              ' (${ms}ms)',
          tag: 'graphql',
          metadata: {
            'operationType': operationType,
            if (operationName != null) 'operationName': operationName,
            'durationMs': ms,
            if (hasErrors)
              'errors': errors.map((e) => e.message).toList(),
          },
        );
      }

      yield response;
    }
  }

  String _operationType(DocumentNode document) {
    for (final def in document.definitions) {
      if (def is OperationDefinitionNode) {
        return switch (def.type) {
          OperationType.query => 'Query',
          OperationType.mutation => 'Mutation',
          OperationType.subscription => 'Subscription',
        };
      }
    }
    return 'Operation';
  }

  String? _printNode(DocumentNode document) {
    try {
      return document.toString();
    } catch (_) {
      return null;
    }
  }
}

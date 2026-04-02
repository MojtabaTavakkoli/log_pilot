import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';
import 'package:log_pilot/src/network/network_log_formatter.dart';
import 'package:log_pilot/src/network/log_pilot_http_interceptor.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// Chopper interceptor that logs requests and responses through LogPilot.
///
/// ```dart
/// final chopper = ChopperClient(
///   interceptors: [LogPilotChopperInterceptor()],
/// );
/// ```
class LogPilotChopperInterceptor implements Interceptor {
  LogPilotChopperInterceptor({
    LogPilotPrinter? printer,
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponseHeaders = false,
    this.logResponseBody = false,
    this.maxResponseBodySize = 4 * 1024,
    this.injectSessionHeader = true,
    this.createRecords = true,
    LogLevel Function(int statusCode)? logLevelForStatus,
  })  : _printer = printer,
        _logLevelForStatus = logLevelForStatus ??
            LogPilotHttpClient.defaultLogLevelForStatus;

  final LogPilotPrinter? _printer;
  final bool logRequestHeaders;
  final bool logRequestBody;
  final bool logResponseHeaders;
  final bool logResponseBody;

  /// Maximum number of characters of the response body to log.
  /// Bodies larger than this are truncated. Set to `0` for unlimited.
  final int maxResponseBodySize;

  /// When `true`, automatically adds `X-LogPilot-Session` (and
  /// `X-LogPilot-Trace` if a trace ID is set) to outgoing requests.
  final bool injectSessionHeader;

  /// When `true` (default), a [LogPilotRecord] is dispatched to history,
  /// sinks, and the overlay for each completed request.
  final bool createRecords;

  final LogLevel Function(int statusCode) _logLevelForStatus;

  LogPilotPrinter get _p => _printer ?? LogPilotZone.printer;
  NetworkLogFormatter get _formatter => NetworkLogFormatter(_p);

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
    Chain<BodyType> chain,
  ) async {
    var request = chain.request;

    if (injectSessionHeader) {
      final headers = Map<String, String>.from(request.headers);
      headers['X-LogPilot-Session'] = LogPilotZone.sessionId;
      final traceId = LogPilotZone.traceId;
      if (traceId != null) headers['X-LogPilot-Trace'] = traceId;
      request = request.copyWith(headers: headers);
    }

    _p.printNetwork(
      title: 'Request',
      level: LogLevel.debug,
      lines: _formatter.formatRequest(
        method: request.method,
        uri: request.url,
        headers: logRequestHeaders
            ? Map<String, dynamic>.from(request.headers)
            : null,
        body: logRequestBody ? request.body : null,
      ),
    );

    final stopwatch = Stopwatch()..start();

    try {
      final response = await chain.proceed(request);
      stopwatch.stop();

      Object? body;
      if (logResponseBody) {
        body = response.body;
        if (maxResponseBodySize > 0 &&
            body is String &&
            body.length > maxResponseBodySize) {
          body = '${body.substring(0, maxResponseBodySize)}'
              '\n... truncated (${body.length} chars total)';
        }
      }

      final level = _logLevelForStatus(response.statusCode);

      if (!response.isSuccessful) {
        _p.printNetwork(
          title: 'Response Error',
          level: level,
          lines: _formatter.formatError(
            method: request.method,
            uri: request.url,
            statusCode: response.statusCode,
            error: response.error,
            body: body,
            duration: stopwatch.elapsed,
          ),
        );
      } else {
        _p.printNetwork(
          title: 'Response',
          level: level,
          lines: _formatter.formatResponse(
            method: request.method,
            uri: request.url,
            statusCode: response.statusCode,
            headers: logResponseHeaders
                ? Map<String, dynamic>.from(response.headers)
                : null,
            body: body,
            duration: stopwatch.elapsed,
          ),
        );
      }

      if (createRecords) {
        final ms = stopwatch.elapsedMilliseconds;
        LogPilot.log(
          level,
          '${request.method} ${request.url} → ${response.statusCode}'
              ' (${ms}ms)',
          tag: 'http',
          metadata: {
            'method': request.method,
            'url': request.url.toString(),
            'statusCode': response.statusCode,
            'durationMs': ms,
          },
        );
      }

      return response;
    } catch (e) {
      stopwatch.stop();

      _p.printNetwork(
        title: 'Request Error',
        level: LogLevel.error,
        lines: _formatter.formatError(
          method: request.method,
          uri: request.url,
          error: e,
          duration: stopwatch.elapsed,
        ),
      );

      if (createRecords) {
        LogPilot.log(
          LogLevel.error,
          '${request.method} ${request.url} failed'
              ' (${stopwatch.elapsedMilliseconds}ms)',
          tag: 'http',
          error: e,
          metadata: {
            'method': request.method,
            'url': request.url.toString(),
            'durationMs': stopwatch.elapsedMilliseconds,
          },
        );
      }

      rethrow;
    }
  }
}

import 'package:dio/dio.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';
import 'package:log_pilot/src/network/network_log_formatter.dart';
import 'package:log_pilot/src/network/log_pilot_http_interceptor.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// Dio [Interceptor] that logs requests, responses, and errors through LogPilot.
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(LogPilotDioInterceptor());
/// ```
class LogPilotDioInterceptor extends Interceptor {
  LogPilotDioInterceptor({
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
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['log_pilot_start'] = DateTime.now().millisecondsSinceEpoch;

    if (injectSessionHeader) {
      options.headers['X-LogPilot-Session'] = LogPilotZone.sessionId;
      final traceId = LogPilotZone.traceId;
      if (traceId != null) {
        options.headers['X-LogPilot-Trace'] = traceId;
      }
    }

    _p.printNetwork(
      title: 'Request',
      level: LogLevel.debug,
      lines: _formatter.formatRequest(
        method: options.method,
        uri: options.uri,
        headers: logRequestHeaders ? _stringifyHeaders(options.headers) : null,
        body: logRequestBody ? options.data : null,
      ),
    );

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final duration = _elapsed(response.requestOptions);

    Object? body;
    if (logResponseBody) {
      body = response.data;
      if (maxResponseBodySize > 0 &&
          body is String &&
          body.length > maxResponseBodySize) {
        body = '${body.substring(0, maxResponseBodySize)}'
            '\n... truncated (${body.length} chars total)';
      }
    }

    final statusCode = response.statusCode ?? 0;
    final responseLevel = _logLevelForStatus(statusCode);

    _p.printNetwork(
      title: 'Response',
      level: responseLevel,
      lines: _formatter.formatResponse(
        method: response.requestOptions.method,
        uri: response.requestOptions.uri,
        statusCode: statusCode,
        statusMessage: response.statusMessage,
        headers: logResponseHeaders
            ? response.headers.map
                .map((k, v) => MapEntry(k, v.join(', ')))
            : null,
        body: body,
        duration: duration,
      ),
    );

    if (createRecords) {
      final opts = response.requestOptions;
      final ms = duration?.inMilliseconds;
      LogPilot.log(
        responseLevel,
        '${opts.method} ${opts.uri} → $statusCode'
            '${ms != null ? ' (${ms}ms)' : ''}',
        tag: 'http',
        metadata: {
          'method': opts.method,
          'url': opts.uri.toString(),
          'statusCode': statusCode,
          if (ms != null) 'durationMs': ms,
        },
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final duration = _elapsed(err.requestOptions);

    _p.printNetwork(
      title: 'Request Error',
      level: LogLevel.error,
      lines: _formatter.formatError(
        method: err.requestOptions.method,
        uri: err.requestOptions.uri,
        statusCode: err.response?.statusCode,
        error: err.message,
        body: err.response?.data,
        duration: duration,
      ),
    );

    if (createRecords) {
      final opts = err.requestOptions;
      final ms = duration?.inMilliseconds;
      LogPilot.log(
        LogLevel.error,
        '${opts.method} ${opts.uri} failed'
            '${ms != null ? ' (${ms}ms)' : ''}',
        tag: 'http',
        error: err,
        metadata: {
          'method': opts.method,
          'url': opts.uri.toString(),
          if (err.response?.statusCode != null)
            'statusCode': err.response!.statusCode,
          if (ms != null) 'durationMs': ms,
        },
      );
    }

    handler.next(err);
  }

  Duration? _elapsed(RequestOptions options) {
    final start = options.extra['log_pilot_start'] as int?;
    if (start == null) return null;
    return Duration(
      milliseconds: DateTime.now().millisecondsSinceEpoch - start,
    );
  }

  Map<String, dynamic> _stringifyHeaders(Map<String, dynamic> headers) =>
      headers.map((k, v) => MapEntry(k, v.toString()));
}

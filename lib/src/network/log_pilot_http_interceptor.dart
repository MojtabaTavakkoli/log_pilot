import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';
import 'package:log_pilot/src/network/network_log_formatter.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// A wrapper around [http.Client] that logs all requests through LogPilot.
///
/// ```dart
/// final client = LogPilotHttpClient();
/// final response = await client.get(Uri.parse('https://api.example.com'));
/// ```
class LogPilotHttpClient extends http.BaseClient {
  LogPilotHttpClient({
    http.Client? inner,
    LogPilotPrinter? printer,
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponseHeaders = false,
    this.logResponseBody = false,
    this.maxResponseBodySize = 4 * 1024,
    this.injectSessionHeader = true,
    this.createRecords = true,
    LogLevel Function(int statusCode)? logLevelForStatus,
  })  : _inner = inner ?? http.Client(),
        _printer = printer,
        _logLevelForStatus = logLevelForStatus ?? defaultLogLevelForStatus;

  final http.Client _inner;
  final LogPilotPrinter? _printer;
  final bool logRequestHeaders;
  final bool logRequestBody;
  final bool logResponseHeaders;
  final bool logResponseBody;

  /// Maximum number of bytes of the response body to log.
  /// Bodies larger than this are truncated. Set to `0` for unlimited.
  final int maxResponseBodySize;

  /// When `true`, automatically adds `X-LogPilot-Session` (and
  /// `X-LogPilot-Trace` if a trace ID is set) to outgoing requests.
  final bool injectSessionHeader;

  /// When `true` (default), a [LogPilotRecord] is dispatched to history,
  /// sinks, and the overlay for each completed request. Set to `false`
  /// if you only want console output.
  final bool createRecords;

  final LogLevel Function(int statusCode) _logLevelForStatus;

  /// Default status-code → log-level mapping used when no custom
  /// [logLevelForStatus] is provided.
  ///
  /// - 5xx → [LogLevel.error]
  /// - 4xx → [LogLevel.warning]
  /// - everything else → [LogLevel.info]
  static LogLevel defaultLogLevelForStatus(int statusCode) {
    if (statusCode >= 500) return LogLevel.error;
    if (statusCode >= 400) return LogLevel.warning;
    return LogLevel.info;
  }

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
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();

    if (injectSessionHeader) {
      request.headers['X-LogPilot-Session'] = LogPilotZone.sessionId;
      final traceId = LogPilotZone.traceId;
      if (traceId != null) {
        request.headers['X-LogPilot-Trace'] = traceId;
      }
    }

    final bodyString = request is http.Request ? request.body : null;

    _p.printNetwork(
      title: 'Request',
      level: LogLevel.debug,
      lines: _formatter.formatRequest(
        method: request.method,
        uri: request.url,
        headers: logRequestHeaders
            ? Map<String, dynamic>.from(request.headers)
            : null,
        body: logRequestBody ? bodyString : null,
      ),
    );

    try {
      final streamedResponse = await _inner.send(request);
      stopwatch.stop();

      final bytes = await streamedResponse.stream.toBytes();
      String? responseBody;
      if (logResponseBody) {
        if (maxResponseBodySize > 0 && bytes.length > maxResponseBodySize) {
          try {
            responseBody =
                '${utf8.decode(bytes.sublist(0, maxResponseBodySize), allowMalformed: true)}'
                '\n... truncated (${bytes.length} bytes total)';
          } catch (_) {
            responseBody = '<binary ${bytes.length} bytes, truncated>';
          }
        } else {
          try {
            responseBody = utf8.decode(bytes);
          } catch (_) {
            responseBody = '<binary ${bytes.length} bytes>';
          }
        }
      }

      final statusCode = streamedResponse.statusCode;
      final responseLevel = _logLevelForStatus(statusCode);

      _p.printNetwork(
        title: 'Response',
        level: responseLevel,
        lines: _formatter.formatResponse(
          method: request.method,
          uri: request.url,
          statusCode: statusCode,
          statusMessage: streamedResponse.reasonPhrase,
          headers: logResponseHeaders
              ? Map<String, dynamic>.from(streamedResponse.headers)
              : null,
          body: responseBody,
          duration: stopwatch.elapsed,
        ),
      );

      if (createRecords) {
        LogPilot.log(
          responseLevel,
          '${request.method} ${request.url} → $statusCode'
              ' (${stopwatch.elapsedMilliseconds}ms)',
          tag: 'http',
          metadata: {
            'method': request.method,
            'url': request.url.toString(),
            'statusCode': statusCode,
            'durationMs': stopwatch.elapsedMilliseconds,
            if (streamedResponse.reasonPhrase != null)
              'reason': streamedResponse.reasonPhrase,
          },
        );
      }

      return http.StreamedResponse(
        http.ByteStream.fromBytes(bytes),
        streamedResponse.statusCode,
        contentLength: streamedResponse.contentLength,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
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

  @override
  void close() => _inner.close();
}

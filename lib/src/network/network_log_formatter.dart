import 'dart:convert';

import 'package:log_pilot/src/core/ansi_styles.dart';
import 'package:log_pilot/src/core/json_formatter.dart';
import 'package:log_pilot/src/core/log_pilot_config.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';

/// Shared formatter that turns raw request/response data into structured
/// lines ready for [LogPilotPrinter.printNetwork].
///
/// Handles REST requests/responses, errors, and GraphQL operations.
/// Applies sensitive field masking to both headers and JSON bodies.
class NetworkLogFormatter {
  NetworkLogFormatter(this._printer)
      : _config = _printer.config,
        _json = JsonFormatter(_printer.config);

  final LogPilotPrinter _printer;
  final LogPilotConfig _config;
  final JsonFormatter _json;

  String _c(String t, AnsiColor c) => _printer.applyColor(t, c);
  String _b(String t) => _printer.applyBold(t);
  String _d(String t) => _printer.applyDim(t);

  // ── Request ───────────────────────────────────────────────────────

  /// Format an outgoing HTTP request.
  List<String> formatRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? headers,
    Object? body,
  }) {
    final lines = <String>[];

    lines.add('${_b(_c(method.toUpperCase(), AnsiColor.cyan))} $uri');

    if (headers != null && headers.isNotEmpty) {
      lines.add('');
      lines.add(_d('Headers:'));
      lines.addAll(_formatHeaders(headers));
    }

    if (body != null) {
      lines.add('');
      lines.add(_d('Body:'));
      lines.addAll(_formatBody(body));
    }

    return lines;
  }

  // ── Response ──────────────────────────────────────────────────────

  /// Format an HTTP response with status color-coding and optional duration.
  List<String> formatResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    String? statusMessage,
    Map<String, dynamic>? headers,
    Object? body,
    Duration? duration,
  }) {
    final lines = <String>[];

    final status = _c('$statusCode', _statusColor(statusCode));
    final msg = statusMessage != null ? ' $statusMessage' : '';
    final dur = duration != null ? _d(' [${duration.inMilliseconds}ms]') : '';

    lines.add(
      '${_b(_c(method.toUpperCase(), AnsiColor.cyan))} $uri $status$msg$dur',
    );

    if (headers != null && headers.isNotEmpty) {
      lines.add('');
      lines.add(_d('Response Headers:'));
      lines.addAll(_formatHeaders(headers));
    }

    if (body != null) {
      lines.add('');
      lines.add(_d('Response Body:'));
      lines.addAll(_formatBody(body));
    }

    return lines;
  }

  // ── Error ─────────────────────────────────────────────────────────

  /// Format a network error, optionally with status code, duration, and body.
  List<String> formatError({
    required String method,
    required Uri uri,
    int? statusCode,
    Object? error,
    Object? body,
    Duration? duration,
  }) {
    final lines = <String>[];

    final statusPart = statusCode != null
        ? _c(' $statusCode', _statusColor(statusCode))
        : '';
    final dur = duration != null ? _d(' [${duration.inMilliseconds}ms]') : '';

    lines.add(
      '${_b(_c(method.toUpperCase(), AnsiColor.red))} $uri$statusPart$dur',
    );

    if (error != null) {
      lines.add('');
      lines.add(_c('Error: $error', AnsiColor.red));
    }

    if (body != null) {
      lines.add('');
      lines.add(_d('Error Body:'));
      lines.addAll(_formatBody(body));
    }

    return lines;
  }

  // ── GraphQL ───────────────────────────────────────────────────────

  /// Format a GraphQL operation (query, mutation, or subscription).
  List<String> formatGraphQL({
    required String operationType,
    String? operationName,
    String? query,
    Map<String, dynamic>? variables,
    Map<String, dynamic>? data,
    List<dynamic>? errors,
    Duration? duration,
  }) {
    final lines = <String>[];

    final name = operationName ?? 'anonymous';
    final dur = duration != null ? _d(' [${duration.inMilliseconds}ms]') : '';

    lines.add(
      '${_c(operationType.toUpperCase(), AnsiColor.magenta)} ${_b(name)}$dur',
    );

    if (query != null) {
      lines.add('');
      lines.add(_d('Query:'));
      for (final line in query.split('\n')) {
        lines.add(_c('  $line', AnsiColor.grey));
      }
    }

    if (variables != null && variables.isNotEmpty) {
      lines.add('');
      lines.add(_d('Variables:'));
      lines.addAll(_indentColorizedJson(variables));
    }

    if (errors != null && errors.isNotEmpty) {
      lines.add('');
      lines.add(_c('GraphQL Errors:', AnsiColor.red));
      for (final err in errors) {
        if (err is Map) {
          final message = err['message'] ?? err.toString();
          lines.add(_c('  - $message', AnsiColor.red));
          final locations = err['locations'];
          if (locations is List && locations.isNotEmpty) {
            lines.add(_d('    at: $locations'));
          }
          final path = err['path'];
          if (path != null) {
            lines.add(_d('    path: $path'));
          }
        } else {
          lines.add(_c('  - $err', AnsiColor.red));
        }
      }
    }

    if (data != null) {
      lines.add('');
      lines.add(_d('Data:'));
      lines.addAll(_indentColorizedJson(data));
    }

    return lines;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Encode JSON with key/value syntax highlighting, indented by 2 spaces.
  List<String> _indentColorizedJson(Object value) {
    return _json
        .encodeColorized(value, _printer.applyColor)
        .map((l) => '  $l')
        .toList();
  }

  List<String> _formatHeaders(Map<String, dynamic> headers) {
    return headers.entries.map((entry) {
      final value = _json.maskSensitiveFields(
        {entry.key: entry.value},
      )[entry.key];
      return _d('  ${entry.key}: $value');
    }).toList();
  }

  List<String> _formatBody(Object body) {
    if (body is Map<String, dynamic>) return _indentColorizedJson(body);
    if (body is List) return _indentColorizedJson(body);

    final str = body.toString();
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic> || decoded is List) {
        return _indentColorizedJson(decoded);
      }
    } catch (_) {
      // not JSON
    }

    return _truncateLines(str);
  }

  List<String> _truncateLines(String text) {
    if (text.length > _config.maxPayloadSize) {
      return [
        '  ${text.substring(0, _config.maxPayloadSize)}',
        _d('  [...truncated at ${_config.maxPayloadSize ~/ 1024}KB]'),
      ];
    }
    return text.split('\n').map((l) => '  $l').toList();
  }

  AnsiColor _statusColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return AnsiColor.green;
    if (statusCode >= 300 && statusCode < 400) return AnsiColor.cyan;
    if (statusCode >= 400 && statusCode < 500) return AnsiColor.yellow;
    return AnsiColor.red;
  }
}

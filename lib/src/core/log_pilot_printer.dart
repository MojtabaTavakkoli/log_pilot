import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:log_pilot/src/core/ansi_styles.dart';
import 'package:log_pilot/src/core/breadcrumb.dart';
import 'package:log_pilot/src/core/json_formatter.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/output_format.dart';
import 'package:log_pilot/src/core/log_pilot_config.dart';
import 'package:log_pilot/src/errors/stack_trace_simplifier.dart';

/// The formatted output engine for LogPilot.
///
/// Draws box-bordered log blocks, pretty-prints JSON, and routes output
/// through [developer.log] so it appears in DevTools.
class LogPilotPrinter {
  LogPilotPrinter(this.config)
      : _json = JsonFormatter(config);

  /// The configuration driving this printer's behavior.
  final LogPilotConfig config;

  final JsonFormatter _json;

  static const _topLeft = '┌';
  static const _bottomLeft = '└';
  static const _verticalLine = '│';
  static const _horizontalLine = '─';
  static const _divider = '├';

  String _border(String corner) {
    final count = (config.maxLineWidth - 1).clamp(0, config.maxLineWidth);
    return '$corner${_horizontalLine * count}';
  }

  String _padLine(String text) => '$_verticalLine $text';

  // ── Styling that respects config.colorize ──────────────────────────

  /// Apply [color] only when colorization is enabled.
  ///
  /// Uses `force: true` so the user's [LogPilotConfig.colorize] intent
  /// overrides terminal auto-detection (important on Windows / web
  /// where `stdout.supportsAnsiEscapes` may be `false` but DevTools
  /// still renders ANSI).
  String applyColor(String text, AnsiColor color) =>
      config.colorize ? colorize(text, color, force: true) : text;

  /// Apply bold only when colorization is enabled.
  String applyBold(String text) =>
      config.colorize ? bold(text, force: true) : text;

  /// Apply dim only when colorization is enabled.
  String applyDim(String text) =>
      config.colorize ? dim(text, force: true) : text;

  // ── Public API ────────────────────────────────────────────────────

  /// Print a structured log block.
  ///
  /// [caller] is an optional source location string (e.g.
  /// `package:my_app/home.dart:42:8`) shown in the header area.
  /// Most IDEs and terminals make this clickable.
  ///
  /// [tag] is an optional identifier for this log. When
  /// [LogPilotConfig.onlyTags] is non-empty, only logs whose tag is in
  /// that set are printed.
  void printLog({
    required LogLevel level,
    required String title,
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    List<String>? preformattedLines,
    String? caller,
    String? tag,
    String? errorId,
    List<Breadcrumb>? breadcrumbs,
  }) {
    if (!config.enabled || level.priority < config.logLevel.priority) return;
    if (!config.isTagAllowed(tag)) return;

    switch (config.outputFormat) {
      case OutputFormat.pretty:
        _printPretty(
          level: level, title: title, message: message, error: error,
          stackTrace: stackTrace, metadata: metadata,
          preformattedLines: preformattedLines, caller: caller, tag: tag,
          errorId: errorId, breadcrumbs: breadcrumbs,
        );
      case OutputFormat.plain:
        _printPlain(
          level: level, message: message, error: error,
          stackTrace: stackTrace, metadata: metadata, caller: caller, tag: tag,
          errorId: errorId, breadcrumbs: breadcrumbs,
        );
      case OutputFormat.json:
        _printJson(
          level: level, message: message, error: error,
          stackTrace: stackTrace, metadata: metadata, caller: caller, tag: tag,
          errorId: errorId, breadcrumbs: breadcrumbs,
        );
    }
  }

  void _printPretty({
    required LogLevel level,
    required String title,
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    List<String>? preformattedLines,
    String? caller,
    String? tag,
    String? errorId,
    List<Breadcrumb>? breadcrumbs,
  }) {
    final lines = <String>[];

    lines.add(_border(_topLeft));
    lines.add(_padLine(_header(level, title)));

    if (config.showTimestamp) {
      lines.add(_padLine(applyDim(_timestamp())));
    }

    if (tag != null) {
      lines.add(_padLine(applyDim('[$tag]')));
    }

    if (errorId != null) {
      lines.add(_padLine(applyDim('id: $errorId')));
    }

    if (caller != null && config.showCaller) {
      lines.add(_padLine(
        applyDim('at $caller'),
      ));
    }

    lines.add(_border(_divider));

    if (message != null && message.isNotEmpty) {
      for (final line in _wrapText(message)) {
        lines.add(_padLine(line));
      }
    }

    if (preformattedLines != null) {
      for (final line in preformattedLines) {
        lines.add(_padLine(line));
      }
    }

    if (metadata != null && metadata.isNotEmpty) {
      lines.add(_border(_divider));
      for (final line in _json.encodeColorized(metadata, applyColor)) {
        lines.add(_padLine(line));
      }
    }

    if (config.showDetails) {
      if (error != null) {
        lines.add(_border(_divider));
        lines.add(
          _padLine(applyColor('Error: ${error.runtimeType}', AnsiColor.red)),
        );
        for (final line in _wrapText(error.toString())) {
          lines.add(_padLine(line));
        }
      }

      if (stackTrace != null) {
        lines.add(_border(_divider));
        lines.add(_padLine(applyDim('Stack Trace:')));
        final simplifier = StackTraceSimplifier(
          maxFrames: config.stackTraceDepth,
        );
        for (final frame in simplifier.simplify(stackTrace)) {
          lines.add(_padLine(frame));
        }
      }

      if (breadcrumbs != null && breadcrumbs.isNotEmpty) {
        lines.add(_border(_divider));
        lines.add(_padLine(applyDim('Breadcrumbs (${breadcrumbs.length}):')));
        for (final b in breadcrumbs) {
          final cat = b.category != null ? '[${b.category}] ' : '';
          lines.add(_padLine(applyDim('  $cat${b.message}')));
        }
      }
    }

    lines.add(_border(_bottomLeft));

    _emit(lines.join('\n'), level: level);
  }

  void _printPlain({
    required LogLevel level,
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? caller,
    String? tag,
    String? errorId,
    List<Breadcrumb>? breadcrumbs,
  }) {
    final buf = StringBuffer();
    if (config.showTimestamp) {
      buf.write('${_timestamp()} ');
    }
    buf.write('[${level.label}]');
    if (errorId != null) buf.write(' $errorId');
    if (tag != null) buf.write(' [$tag]');
    if (caller != null && config.showCaller) buf.write(' ($caller)');
    if (message != null && message.isNotEmpty) buf.write(' $message');
    if (error != null) buf.write(' | Error: $error');
    if (metadata != null && metadata.isNotEmpty) {
      buf.write(' | ${jsonEncode(metadata)}');
    }
    if (config.showDetails && stackTrace != null) {
      final simplifier = StackTraceSimplifier(
        maxFrames: config.stackTraceDepth,
      );
      final frames = simplifier.simplify(stackTrace);
      if (frames.isNotEmpty) {
        buf.write(' | Stack: ${frames.join(' <- ')}');
      }
    }
    if (config.showDetails && breadcrumbs != null && breadcrumbs.isNotEmpty) {
      buf.write(' | Breadcrumbs: ');
      buf.write(breadcrumbs.map((b) => b.toString()).join(' -> '));
    }

    _emit(buf.toString(), level: level);
  }

  void _printJson({
    required LogLevel level,
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? caller,
    String? tag,
    String? errorId,
    List<Breadcrumb>? breadcrumbs,
  }) {
    final map = <String, dynamic>{
      'level': level.label,
      'timestamp': DateTime.now().toIso8601String(),
      if (errorId != null) 'errorId': errorId,
      if (tag != null) 'tag': tag,
      if (caller != null && config.showCaller) 'caller': caller,
      if (message != null) 'message': message,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      if (error != null) 'error': error.toString(),
    };
    if (config.showDetails && stackTrace != null) {
      final simplifier = StackTraceSimplifier(
        maxFrames: config.stackTraceDepth,
      );
      map['stackTrace'] = simplifier.simplify(stackTrace);
    }
    if (config.showDetails && breadcrumbs != null && breadcrumbs.isNotEmpty) {
      map['breadcrumbs'] = breadcrumbs.map((b) => b.toJson()).toList();
    }

    _emit(jsonEncode(map), level: level);
  }

  /// Print a block specifically for network requests/responses.
  void printNetwork({
    required String title,
    required LogLevel level,
    required List<String> lines,
    String? tag,
  }) {
    if (!config.enabled || level.priority < config.logLevel.priority) return;
    if (!config.isTagAllowed(tag)) return;

    switch (config.outputFormat) {
      case OutputFormat.pretty:
        _printNetworkPretty(title: title, level: level, lines: lines, tag: tag);
      case OutputFormat.plain:
        final stripped = lines.map(stripAnsi).join(' | ');
        final buf = StringBuffer();
        if (config.showTimestamp) buf.write('${_timestamp()} ');
        buf.write('[${level.label}]');
        if (tag != null) buf.write(' [$tag]');
        buf.write(' $title: $stripped');
        _emit(buf.toString(), level: level, name: 'LogPilot.network');
      case OutputFormat.json:
        final map = <String, dynamic>{
          'level': level.label,
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'network',
          'title': title,
          if (tag != null) 'tag': tag,
          'details': lines.map(stripAnsi).toList(),
        };
        _emit(jsonEncode(map), level: level, name: 'LogPilot.network');
    }
  }

  void _printNetworkPretty({
    required String title,
    required LogLevel level,
    required List<String> lines,
    String? tag,
  }) {
    final output = <String>[];
    output.add(_border(_topLeft));
    output.add(_padLine(_header(level, title)));
    if (config.showTimestamp) {
      output.add(_padLine(applyDim(_timestamp())));
    }
    if (tag != null) {
      output.add(_padLine(applyDim('[$tag]')));
    }
    output.add(_border(_divider));

    for (final line in lines) {
      output.add(_padLine(line));
    }

    output.add(_border(_bottomLeft));

    _emit(output.join('\n'), level: level, name: 'LogPilot.network');
  }

  /// Pretty-format a JSON string (auto-detect and indent).
  ///
  /// Returns **unpadded** content lines. The caller is responsible for
  /// wrapping them in `_padLine` or passing them as `preformattedLines`.
  List<String> formatJsonString(String raw) {
    final parsed = _json.tryParseAndEncodeColorized(raw, applyColor);
    if (parsed != null) return parsed;
    return [raw];
  }

  // ── Private helpers ───────────────────────────────────────────────

  String _header(LogLevel level, String title) {
    final label = applyColor(' ${level.label} ', level.color);
    return '${applyBold(label)} $title';
  }

  String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Wrap text to fit inside the box, stripping ANSI for measurement.
  List<String> _wrapText(String text) {
    final contentWidth = (config.maxLineWidth - 4).clamp(1, config.maxLineWidth);
    final result = <String>[];
    for (final rawLine in text.split('\n')) {
      if (stripAnsi(rawLine).length <= contentWidth) {
        result.add(rawLine);
      } else {
        final plain = stripAnsi(rawLine);
        for (var i = 0; i < plain.length; i += contentWidth) {
          final end = (i + contentWidth).clamp(0, plain.length);
          result.add(plain.substring(i, end));
        }
      }
    }
    return result;
  }

  /// Route output through the most efficient channel for the platform.
  ///
  /// On web, `developer.log()` has significant overhead from JS interop.
  /// For plain and JSON formats (which don't need DevTools level support),
  /// `print()` is substantially cheaper.
  void _emit(String text, {required LogLevel level, String name = 'LogPilot'}) {
    if (kIsWeb && config.outputFormat != OutputFormat.pretty) {
      // ignore: avoid_print
      print(text);
    } else {
      developer.log(text, name: name, level: _developerLogLevel(level));
    }
  }

  int _developerLogLevel(LogLevel level) {
    return switch (level) {
      LogLevel.verbose => 500,
      LogLevel.debug   => 500,
      LogLevel.info    => 800,
      LogLevel.warning => 900,
      LogLevel.error   => 1000,
      LogLevel.fatal   => 1200,
    };
  }
}

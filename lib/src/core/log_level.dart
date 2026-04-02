import 'package:log_pilot/src/core/ansi_styles.dart';

/// Severity levels for log messages, ordered by [priority].
enum LogLevel {
  verbose(0, 'VERBOSE', AnsiColor.grey),
  debug(1, 'DEBUG', AnsiColor.blue),
  info(2, 'INFO', AnsiColor.green),
  warning(3, 'WARNING', AnsiColor.yellow),
  error(4, 'ERROR', AnsiColor.red),
  fatal(5, 'FATAL', AnsiColor.magenta);

  const LogLevel(this.priority, this.label, this.color);

  /// Numeric priority; higher means more severe.
  final int priority;

  /// Human-readable label shown in log output.
  final String label;

  /// Terminal color associated with this level.
  final AnsiColor color;

  bool operator >=(LogLevel other) => priority >= other.priority;
}

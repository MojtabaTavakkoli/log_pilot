import 'package:flutter/foundation.dart';

/// Severity levels mirroring `LogLevel` from the LogPilot package.
enum LogEntryLevel {
  verbose(0, 'VERBOSE'),
  debug(1, 'DEBUG'),
  info(2, 'INFO'),
  warning(3, 'WARNING'),
  error(4, 'ERROR'),
  fatal(5, 'FATAL');

  const LogEntryLevel(this.priority, this.label);

  final int priority;
  final String label;

  bool operator >=(LogEntryLevel other) => priority >= other.priority;

  static LogEntryLevel fromString(String label) {
    return LogEntryLevel.values.firstWhere(
      (l) => l.label == label.toUpperCase() || l.name == label.toLowerCase(),
      orElse: () => LogEntryLevel.info,
    );
  }
}

/// A breadcrumb entry deserialized from the LogPilot JSON output.
@immutable
class BreadcrumbEntry {
  const BreadcrumbEntry({
    required this.timestamp,
    required this.message,
    this.category,
    this.metadata,
  });

  final DateTime timestamp;
  final String message;
  final String? category;
  final Map<String, dynamic>? metadata;

  factory BreadcrumbEntry.fromJson(Map<String, dynamic> json) {
    return BreadcrumbEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String,
      category: json['category'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// A deserialized log record from the running app, mirroring `LogPilotRecord`.
///
/// This class is used by the DevTools extension to display log entries
/// without depending on the `LogPilot` package directly.
@immutable
class LogEntry {
  const LogEntry({
    required this.level,
    required this.timestamp,
    this.message,
    this.tag,
    this.caller,
    this.metadata,
    this.error,
    this.stackTrace,
    this.sessionId,
    this.traceId,
    this.errorId,
    this.breadcrumbs,
  });

  final LogEntryLevel level;
  final DateTime timestamp;
  final String? message;
  final String? tag;
  final String? caller;
  final Map<String, dynamic>? metadata;
  final String? error;
  final String? stackTrace;
  final String? sessionId;
  final String? traceId;
  final String? errorId;
  final List<BreadcrumbEntry>? breadcrumbs;

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogEntryLevel.fromString(json['level'] as String? ?? 'INFO'),
      timestamp: DateTime.parse(json['timestamp'] as String),
      message: json['message'] as String?,
      tag: json['tag'] as String?,
      caller: json['caller'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      sessionId: json['sessionId'] as String?,
      traceId: json['traceId'] as String?,
      errorId: json['errorId'] as String?,
      breadcrumbs: _parseBreadcrumbs(json['breadcrumbs']),
    );
  }

  static List<BreadcrumbEntry>? _parseBreadcrumbs(dynamic raw) {
    if (raw == null) return null;
    if (raw is! List) return null;
    return raw
        .whereType<Map<String, dynamic>>()
        .map(BreadcrumbEntry.fromJson)
        .toList();
  }

  bool get hasError => error != null;
  bool get hasStack => stackTrace != null && stackTrace!.isNotEmpty;
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;
  bool get hasBreadcrumbs => breadcrumbs != null && breadcrumbs!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'level': level.label,
        'timestamp': timestamp.toIso8601String(),
        if (message != null) 'message': message,
        if (tag != null) 'tag': tag,
        if (caller != null) 'caller': caller,
        if (metadata != null) 'metadata': metadata,
        if (error != null) 'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (sessionId != null) 'sessionId': sessionId,
        if (traceId != null) 'traceId': traceId,
        if (errorId != null) 'errorId': errorId,
      };
}

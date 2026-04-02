import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// A scoped logger instance that auto-applies a [tag] to every log.
///
/// Use this for class-level or feature-level loggers instead of
/// repeating the `tag:` parameter on every call:
///
/// ```dart
/// class AuthService {
///   static final _log = LogPilotLogger('AuthService');
///
///   Future<void> signIn(String email) async {
///     _log.info('Attempting sign in', metadata: {'email': email});
///     try {
///       await _auth.signIn(email);
///       _log.info('Sign in successful');
///     } catch (e, st) {
///       _log.error('Sign in failed', error: e, stackTrace: st);
///     }
///   }
/// }
/// ```
class LogPilotLogger {
  /// Creates a logger that tags every log with [tag].
  const LogPilotLogger(this.tag);

  /// The tag applied to every log from this instance.
  final String tag;

  /// Log at an arbitrary [level].
  void log(
    LogLevel level,
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(level, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log at [LogLevel.verbose].
  void verbose(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(LogLevel.verbose, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log at [LogLevel.debug].
  void debug(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(LogLevel.debug, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log at [LogLevel.info].
  void info(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(LogLevel.info, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log at [LogLevel.warning].
  void warning(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(LogLevel.warning, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log at [LogLevel.error].
  void error(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(LogLevel.error, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log at [LogLevel.fatal].
  void fatal(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) =>
      LogPilot.log(LogLevel.fatal, message,
          tag: tag, error: error, stackTrace: stackTrace, metadata: metadata);

  /// Log a JSON string with automatic pretty-printing.
  void json(String raw, {LogLevel level = LogLevel.debug}) =>
      LogPilot.json(raw, level: level, tag: tag);

  /// Start a named timer. The [label] is prefixed with this logger's
  /// [tag] to avoid collisions across loggers.
  void time(String label) => LogPilot.time('$tag/$label');

  /// Stop a named timer and log the elapsed duration.
  Duration? timeEnd(String label, {LogLevel level = LogLevel.debug}) =>
      LogPilot.timeEnd('$tag/$label', level: level, tag: tag);

  /// Cancel a running timer without logging.
  void timeCancel(String label) => LogPilot.timeCancel('$tag/$label');

  /// Run [work] with a named timer, logging on success and
  /// cancelling on exception. The label is prefixed with this
  /// logger's [tag].
  Future<T> withTimer<T>(
    String label, {
    LogLevel level = LogLevel.debug,
    required Future<T> Function() work,
  }) =>
      LogPilot.withTimer('$tag/$label', level: level, tag: tag, work: work);

  /// Synchronous version of [withTimer].
  T withTimerSync<T>(
    String label, {
    LogLevel level = LogLevel.debug,
    required T Function() work,
  }) =>
      LogPilot.withTimerSync('$tag/$label', level: level, tag: tag, work: work);

  /// Run [work] with a trace ID set, clearing it when done.
  ///
  /// Convenience wrapper around [LogPilot.withTraceId] — the trace ID is
  /// global (not scoped to this logger's tag).
  Future<T> withTraceId<T>(
    String traceId,
    Future<T> Function() work,
  ) =>
      LogPilot.withTraceId(traceId, work);

  /// Synchronous version of [withTraceId].
  T withTraceIdSync<T>(String traceId, T Function() work) =>
      LogPilot.withTraceIdSync(traceId, work);
}

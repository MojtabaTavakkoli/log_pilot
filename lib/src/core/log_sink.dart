import 'dart:async';

import 'package:log_pilot/src/core/log_pilot_record.dart';

/// Interface for log output destinations.
///
/// Implement this to route log records to files, crash reporters,
/// remote backends, or any custom destination. Register sinks via
/// [LogPilotConfig.sinks].
///
/// ```dart
/// class SentrySink implements LogSink {
///   @override
///   void onLog(LogPilotRecord record) {
///     Sentry.addBreadcrumb(Breadcrumb(
///       message: record.message,
///       level: _mapLevel(record.level),
///     ));
///   }
/// }
/// ```
abstract class LogSink {
  /// Called for every log record that passes the level and tag filters.
  ///
  /// Runs synchronously on the logging call stack by default. For
  /// expensive work, prefer [AsyncLogSink] which batches records and
  /// dispatches on a microtask boundary.
  ///
  /// If this method throws, the exception is caught by the dispatch
  /// loop (in debug mode the error is printed via `debugPrint`), and
  /// remaining sinks still receive the record. This prevents one
  /// broken sink from silencing all others.
  void onLog(LogPilotRecord record);

  /// Release any resources held by this sink.
  ///
  /// Called when the config is replaced or the app is shutting down.
  /// The default implementation is a no-op.
  void dispose() {}
}

/// A [LogSink] whose [flush] callback runs on a microtask boundary,
/// receiving a batch of records instead of one at a time.
///
/// Use this for expensive operations (HTTP uploads, file I/O, UI state
/// updates) that should not block the logging call site.
///
/// ```dart
/// LogPilotConfig(
///   sinks: [
///     AsyncLogSink(
///       flush: (records) {
///         for (final r in records) {
///           FirebaseCrashlytics.instance.log(r.message ?? '');
///         }
///       },
///     ),
///   ],
/// )
/// ```
class AsyncLogSink implements LogSink {
  AsyncLogSink({required this.flush});

  /// Called with batched records on a microtask boundary.
  final void Function(List<LogPilotRecord> records) flush;

  final List<LogPilotRecord> _pending = [];
  bool _scheduled = false;

  @override
  void onLog(LogPilotRecord record) {
    _pending.add(record);
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_flush);
    }
  }

  void _flush() {
    _scheduled = false;
    if (_pending.isEmpty) return;
    final batch = List<LogPilotRecord>.of(_pending);
    _pending.clear();
    flush(batch);
  }

  @override
  void dispose() {
    if (_pending.isNotEmpty) _flush();
  }
}

/// A [LogSink] that forwards records to a plain callback.
///
/// **Warning:** The callback runs synchronously during the logging call,
/// which may be inside Flutter's build/layout phase. If your callback
/// calls `setState`, `notifyListeners`, or any method that triggers a
/// rebuild, Flutter will throw `setState() called during build`.
///
/// For UI-affecting callbacks, use [BufferedCallbackSink] (timer-deferred)
/// or [AsyncLogSink] (microtask-deferred) instead:
///
/// ```dart
/// // WRONG — causes build-during-build crash:
/// CallbackSink((r) => setState(() => logs.add(r)))
///
/// // RIGHT — timer-deferred, safe for UI:
/// BufferedCallbackSink(onFlush: (batch) => setState(() => logs.addAll(batch)))
/// ```
///
/// `CallbackSink` is safe for fire-and-forget work that does not touch
/// widget state: crash reporters, analytics events, file writes.
///
/// ```dart
/// LogPilotConfig(
///   sinks: [
///     CallbackSink((record) {
///       FirebaseCrashlytics.instance.log(record.message ?? '');
///     }),
///   ],
/// )
/// ```
class CallbackSink implements LogSink {
  const CallbackSink(this._callback);

  final void Function(LogPilotRecord record) _callback;

  @override
  void onLog(LogPilotRecord record) => _callback(record);

  @override
  void dispose() {}
}

/// A [LogSink] that collects records and flushes them in batches,
/// either when [maxBatchSize] is reached or after [flushInterval].
///
/// Prevents the O(n) list-copy anti-pattern that arises when connecting
/// a [CallbackSink] directly to UI state.
///
/// ```dart
/// LogPilotConfig(
///   sinks: [
///     BufferedCallbackSink(
///       onFlush: (batch) {
///         setState(() => records.addAll(batch));
///       },
///     ),
///   ],
/// )
/// ```
class BufferedCallbackSink implements LogSink {
  BufferedCallbackSink({
    required this.onFlush,
    this.maxBatchSize = 50,
    this.flushInterval = const Duration(milliseconds: 500),
  });

  /// Called with a batch of records when the buffer is flushed.
  final void Function(List<LogPilotRecord> batch) onFlush;

  /// Flush when the buffer reaches this size.
  final int maxBatchSize;

  /// Flush periodically even if [maxBatchSize] is not reached.
  final Duration flushInterval;

  final List<LogPilotRecord> _buffer = [];
  Timer? _timer;

  @override
  void onLog(LogPilotRecord record) {
    _buffer.add(record);
    if (_buffer.length >= maxBatchSize) {
      _flush();
    } else {
      _timer ??= Timer(flushInterval, _flush);
    }
  }

  void _flush() {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) return;
    final batch = List<LogPilotRecord>.of(_buffer);
    _buffer.clear();
    onFlush(batch);
  }

  @override
  void dispose() {
    _flush();
    _timer?.cancel();
  }
}

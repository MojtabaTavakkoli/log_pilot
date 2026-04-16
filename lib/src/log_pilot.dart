import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:log_pilot/src/core/breadcrumb.dart';
import 'package:log_pilot/src/core/error_id.dart';
import 'package:log_pilot/src/core/log_history.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_config.dart';
import 'package:log_pilot/src/core/log_pilot_diagnostics.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/core/log_pilot_record.dart';
import 'package:log_pilot/src/core/rate_limiter.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';
import 'package:log_pilot/src/log_pilot_logger.dart';

/// The primary entry point for the LogPilot package.
///
/// ```dart
/// void main() {
///   LogPilot.init(
///     config: LogPilotConfig(logLevel: LogLevel.verbose),
///     child: const MyApp(),
///   );
/// }
///
/// // Anywhere in your app:
/// LogPilot.info('User signed in', metadata: {'userId': '123'});
/// LogPilot.error('Payment failed', error: e, stackTrace: st);
/// LogPilot.json('{"key": "value"}');
/// ```
abstract final class LogPilot {
  /// Initialize LogPilot and wrap [child] in error-catching zones.
  ///
  /// Call this in `main()` instead of `runApp()`. Sets up
  /// `FlutterError.onError`, `PlatformDispatcher.onError`, and
  /// `runZonedGuarded` to catch and prettify all errors automatically.
  static void init({
    LogPilotConfig? config,
    LogPilotErrorCallback? onError,
    required Widget child,
  }) {
    LogPilotZone.snapshotBuilder = snapshot;
    LogPilotZone.exportForLLMBuilder = exportForLLM;
    LogPilotZone.init(config: config, onError: onError, child: child);
  }

  /// Set the configuration without installing error zones.
  ///
  /// Use this when you only want manual logging and don't need LogPilot
  /// to replace `runApp()` or catch Flutter errors. Call `runApp()`
  /// yourself afterward.
  ///
  /// ```dart
  /// void main() {
  ///   LogPilot.configure(config: LogPilotConfig(logLevel: LogLevel.info));
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// You can also skip [configure] entirely and just call
  /// `LogPilot.info(...)` — it works out of the box with sensible
  /// defaults in debug mode.
  static void configure({LogPilotConfig? config}) {
    LogPilotZone.snapshotBuilder = snapshot;
    LogPilotZone.exportForLLMBuilder = exportForLLM;
    LogPilotZone.configure(config: config);
  }

  /// Whether [init] has been called.
  static bool get isInitialized => LogPilotZone.isInitialized;

  /// The active configuration.
  static LogPilotConfig get config => LogPilotZone.config;

  /// The shared printer instance.
  static LogPilotPrinter get printer => LogPilotZone.printer;

  /// The current minimum log level.
  ///
  /// Logs with a priority below this level are suppressed from both
  /// console output and sink dispatch.
  ///
  /// ```dart
  /// print(LogPilot.logLevel); // LogLevel.verbose
  /// ```
  static LogLevel get logLevel => LogPilotZone.config.logLevel;

  /// Change the minimum log level at runtime.
  ///
  /// This is the primary API for AI agents and debugging tools to
  /// increase or decrease verbosity without editing source code or
  /// restarting the app. The change takes effect immediately.
  ///
  /// ```dart
  /// LogPilot.setLogLevel(LogLevel.verbose); // crank up for debugging
  /// // ... reproduce the issue ...
  /// LogPilot.setLogLevel(LogLevel.warning); // quiet down again
  /// ```
  static void setLogLevel(LogLevel level) => LogPilotZone.setLogLevel(level);

  // ── Diagnostics ──────────────────────────────────────────────────

  static LogPilotDiagnostics? _diagnostics;

  /// The active diagnostics instance, or `null` if not enabled.
  ///
  /// Enable via [enableDiagnostics]. Once enabled, LogPilot tracks
  /// records-per-second and sink dispatch latency, and can auto-degrade
  /// the log level when throughput spikes.
  static LogPilotDiagnostics? get diagnostics => _diagnostics;

  /// Enable self-monitoring diagnostics.
  ///
  /// When throughput exceeds [throughputThreshold] records per second,
  /// the log level is automatically raised to [degradeLevel] (if
  /// [autoDegrade] is true), preventing a logging-induced freeze.
  ///
  /// ```dart
  /// LogPilot.enableDiagnostics(autoDegrade: true, throughputThreshold: 50);
  /// ```
  static LogPilotDiagnostics enableDiagnostics({
    bool autoDegrade = false,
    int throughputThreshold = 50,
    LogLevel degradeLevel = LogLevel.warning,
  }) {
    _diagnostics?.stop();
    _diagnostics = LogPilotDiagnostics(
      autoDegrade: autoDegrade,
      throughputThreshold: throughputThreshold,
      degradeLevel: degradeLevel,
    )..start();
    return _diagnostics!;
  }

  /// Disable diagnostics and restore any auto-degraded log level.
  static void disableDiagnostics() {
    _diagnostics?.stop();
    _diagnostics = null;
  }

  /// Create a scoped [LogPilotLogger] that auto-tags every log.
  ///
  /// ```dart
  /// class AuthService {
  ///   static final _log = LogPilot.create('AuthService');
  ///
  ///   void signIn() {
  ///     _log.info('Attempting sign in');
  ///   }
  /// }
  /// ```
  static LogPilotLogger create(String tag) => LogPilotLogger(tag);

  // ── History / Export ────────────────────────────────────────────────

  /// An unmodifiable list of recent log records, oldest first.
  ///
  /// The buffer size is controlled by [LogPilotConfig.maxHistorySize].
  /// Returns an empty list when history is disabled (`maxHistorySize: 0`).
  static List<LogPilotRecord> get history =>
      LogPilotZone.history?.records ?? const [];

  /// Return only records matching the given filters.
  ///
  /// All parameters are optional and combined with AND logic. See
  /// [LogHistory.where] for detailed parameter descriptions.
  static List<LogPilotRecord> historyWhere({
    LogLevel? level,
    String? tag,
    String? messageContains,
    String? traceId,
    bool? hasError,
    DateTime? after,
    DateTime? before,
    String? metadataKey,
  }) =>
      LogPilotZone.history?.where(
        level: level,
        tag: tag,
        messageContains: messageContains,
        traceId: traceId,
        hasError: hasError,
        after: after,
        before: before,
        metadataKey: metadataKey,
      ) ??
      const [];

  /// Export recent history as human-readable text (one line per record).
  ///
  /// Pass [format] to choose between `text` and `json` (NDJSON).
  static String export({ExportFormat format = ExportFormat.text}) {
    final h = LogPilotZone.history;
    if (h == null || h.isEmpty) return '';
    return switch (format) {
      ExportFormat.text => h.exportAsText(),
      ExportFormat.json => h.exportAsJson(),
    };
  }

  /// Intelligently compress the log history to fit within a token budget.
  ///
  /// Designed to prevent the common failure mode of pasting 50KB of
  /// logs into an LLM prompt. The algorithm:
  ///
  /// 1. **Prioritizes errors and warnings** — they always appear first.
  /// 2. **Deduplicates** — repeated messages are collapsed into
  ///    "message (×N)" summaries.
  /// 3. **Truncates verbose entries** — messages longer than ~200 chars
  ///    are trimmed with `...`.
  /// 4. **Fills remaining budget** with recent info/debug/verbose records.
  ///
  /// Uses approximate token counting: 4 characters ≈ 1 token.
  ///
  /// [tokenBudget] controls the maximum output size in approximate
  /// tokens (default 4000, which is ~16k chars).
  ///
  /// ```dart
  /// final summary = LogPilot.exportForLLM(tokenBudget: 2000);
  /// // paste into AI chat — guaranteed to fit in context window
  /// ```
  static String exportForLLM({int tokenBudget = 4000}) {
    final h = LogPilotZone.history;
    if (h == null || h.isEmpty) return '';

    final charBudget = tokenBudget * 4;
    final records = h.records;

    final errors = <LogPilotRecord>[];
    final warnings = <LogPilotRecord>[];
    final others = <LogPilotRecord>[];
    for (final r in records) {
      if (r.level == LogLevel.error || r.level == LogLevel.fatal) {
        errors.add(r);
      } else if (r.level == LogLevel.warning) {
        warnings.add(r);
      } else {
        others.add(r);
      }
    }

    final buf = StringBuffer();
    buf.writeln('=== LogPilot summary (${records.length} records) ===');

    var remaining = charBudget - buf.length;

    if (errors.isNotEmpty) {
      buf.writeln('--- errors/fatal (${errors.length}) ---');
      remaining -= 40;
      remaining = _appendDeduped(buf, errors, remaining);
    }

    if (warnings.isNotEmpty && remaining > 100) {
      buf.writeln('--- warnings (${warnings.length}) ---');
      remaining -= 35;
      remaining = _appendDeduped(buf, warnings, remaining);
    }

    if (others.isNotEmpty && remaining > 100) {
      buf.writeln('--- recent (${others.length}) ---');
      remaining -= 30;
      // Only take the tail (most recent) for non-error records.
      final tail = others.length > 50
          ? others.sublist(others.length - 50)
          : others;
      _appendDeduped(buf, tail, remaining);
    }

    return buf.toString();
  }

  /// Append deduplicated, truncated records to [buf], respecting [charBudget].
  /// Returns remaining budget.
  static int _appendDeduped(
    StringBuffer buf,
    List<LogPilotRecord> records,
    int charBudget,
  ) {
    var remaining = charBudget;

    // Group consecutive identical messages.
    final groups = <({LogPilotRecord record, int count})>[];
    for (final r in records) {
      if (groups.isNotEmpty &&
          groups.last.record.message == r.message &&
          groups.last.record.level == r.level) {
        groups[groups.length - 1] = (
          record: groups.last.record,
          count: groups.last.count + 1,
        );
      } else {
        groups.add((record: r, count: 1));
      }
    }

    for (final g in groups) {
      if (remaining <= 0) break;

      final r = g.record;
      final msg = r.message ?? '';
      final truncated = msg.length > 200
          ? '${msg.substring(0, 197)}...'
          : msg;

      final line = StringBuffer();
      line.write('[${r.level.label}]');
      if (r.errorId != null) line.write(' ${r.errorId}');
      if (r.tag != null) line.write(' [${r.tag}]');
      line.write(' $truncated');
      if (r.error != null) {
        final errStr = r.error.toString();
        final errTrunc = errStr.length > 100
            ? '${errStr.substring(0, 97)}...'
            : errStr;
        line.write(' | $errTrunc');
      }
      if (g.count > 1) line.write(' (×${g.count})');

      final lineStr = line.toString();
      if (lineStr.length > remaining) {
        // Write what we can and stop.
        buf.writeln(lineStr.substring(0, remaining));
        remaining = 0;
        break;
      }

      buf.writeln(lineStr);
      remaining -= lineStr.length + 1; // +1 for newline
    }

    return remaining;
  }

  /// Remove all records from the in-memory history.
  static void clearHistory() => LogPilotZone.history?.clear();

  // ── Diagnostic Snapshot ─────────────────────────────────────────────

  /// Return a structured summary of recent LogPilot activity.
  ///
  /// Designed for AI agents to call after a crash or unexpected behavior
  /// to understand what happened in one shot — without scrolling through
  /// the full log history.
  ///
  /// The returned map includes:
  /// - `sessionId` / `traceId` — correlation identifiers
  /// - `config` — current output format, log level, enabled state
  /// - `history` — total count and counts per log level
  /// - `recentErrors` — the last few error/fatal records (as maps)
  /// - `recentLogs` — the last few records of any level
  /// - `recentByTag` — last N records grouped by tag (when [groupByTag])
  /// - `activeTimers` — labels of currently running `LogPilot.time()` timers
  /// - `timestamp` — when the snapshot was taken
  ///
  /// [maxRecentErrors] controls how many error/fatal records to include
  /// (default 5). [maxRecentLogs] controls total recent records (default 10).
  ///
  /// When [groupByTag] is `true`, a `recentByTag` section is included
  /// that groups the most recent [perTagLimit] records by their tag.
  /// This is useful for agents that want "show me the last 3 AuthLogs
  /// entries" without knowing timestamps.
  ///
  /// ```dart
  /// final snap = LogPilot.snapshot(groupByTag: true, perTagLimit: 3);
  /// print(snap['recentByTag']['Auth']); // last 3 Auth-tagged records
  /// ```
  static Map<String, dynamic> snapshot({
    int maxRecentErrors = 5,
    int maxRecentLogs = 10,
    bool groupByTag = false,
    int perTagLimit = 5,
  }) {
    final history = LogPilotZone.history;
    final records = history?.records ?? const <LogPilotRecord>[];

    final levelCounts = <String, int>{};
    for (final r in records) {
      levelCounts[r.level.label] = (levelCounts[r.level.label] ?? 0) + 1;
    }

    final errors = records
        .where((r) =>
            r.level == LogLevel.error || r.level == LogLevel.fatal)
        .toList();
    final recentErrors = errors.length > maxRecentErrors
        ? errors.sublist(errors.length - maxRecentErrors)
        : errors;

    final recentLogs = records.length > maxRecentLogs
        ? records.sublist(records.length - maxRecentLogs)
        : records;

    final config = LogPilotZone.config;

    final result = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'sessionId': LogPilotZone.sessionId,
      if (LogPilotZone.traceId != null) 'traceId': LogPilotZone.traceId,
      'config': {
        'enabled': config.enabled,
        'logLevel': config.logLevel.label,
        'outputFormat': config.outputFormat.name,
        'showCaller': config.showCaller,
      },
      'history': {
        'total': records.length,
        'maxSize': config.maxHistorySize,
        ...levelCounts,
      },
      'recentErrors': recentErrors.map((r) => r.toJson()).toList(),
      'recentLogs': recentLogs.map((r) => r.toJson()).toList(),
      'activeTimers': _timers.keys.toList(),
    };

    if (groupByTag) {
      result['recentByTag'] = _groupByTag(records, perTagLimit);
    }

    return result;
  }

  /// Group records by tag and take the last [limit] per group.
  static Map<String, dynamic> _groupByTag(
    List<LogPilotRecord> records,
    int limit,
  ) {
    final grouped = <String, List<LogPilotRecord>>{};
    for (final r in records) {
      final key = r.tag ?? '(untagged)';
      (grouped[key] ??= []).add(r);
    }
    return grouped.map((tag, list) {
      final tail = list.length > limit
          ? list.sublist(list.length - limit)
          : list;
      return MapEntry(tag, {
        'total': list.length,
        'recent': tail.map((r) => r.toJson()).toList(),
      });
    });
  }

  /// Export [snapshot] as a formatted JSON string.
  ///
  /// Convenience for pasting into AI chats or attaching to bug reports.
  static String snapshotAsJson({
    int maxRecentErrors = 5,
    int maxRecentLogs = 10,
    bool groupByTag = false,
    int perTagLimit = 5,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      snapshot(
        maxRecentErrors: maxRecentErrors,
        maxRecentLogs: maxRecentLogs,
        groupByTag: groupByTag,
        perTagLimit: perTagLimit,
      ),
    );
  }

  /// Reset all LogPilot state to defaults.
  ///
  /// Intended for test teardown. Clears history, resets config, and
  /// marks LogPilot as un-initialized so [init] can be called again.
  @visibleForTesting
  static void reset() {
    _timers.clear();
    _rateLimiter = null;
    _sinkRateLimiter = null;
    _diagnostics?.stop();
    _diagnostics = null;
    LogPilotZone.reset();
  }

  // ── Session & Trace IDs ─────────────────────────────────────────────

  /// A unique identifier for this app session, auto-generated on
  /// [init] or [configure].
  ///
  /// Every [LogPilotRecord] carries this value in [LogPilotRecord.sessionId].
  /// Network interceptors inject it as an `X-LogPilot-Session` header.
  ///
  /// ```dart
  /// print(LogPilot.sessionId); // e.g. "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d"
  /// ```
  static String get sessionId => LogPilotZone.sessionId;

  /// Set an ambient trace ID for per-request or per-operation correlation.
  ///
  /// All subsequent logs will include this trace ID in
  /// [LogPilotRecord.traceId] until [clearTraceId] is called.
  ///
  /// ```dart
  /// LogPilot.setTraceId('req-12345');
  /// await doWork(); // all logs inside carry traceId
  /// LogPilot.clearTraceId();
  /// ```
  static void setTraceId(String traceId) => LogPilotZone.traceId = traceId;

  /// Clear the ambient trace ID.
  static void clearTraceId() => LogPilotZone.traceId = null;

  /// The current ambient trace ID, or `null` if none is set.
  static String? get traceId => LogPilotZone.traceId;

  /// Run [work] with [traceId] set, clearing it when done.
  ///
  /// All logs emitted inside [work] carry [traceId] in
  /// [LogPilotRecord.traceId]. The trace ID is cleared in a `finally`
  /// block, so it is safe even when [work] throws.
  ///
  /// ```dart
  /// await LogPilot.withTraceId('req-123', () async {
  ///   await placeOrder();    // all logs carry traceId 'req-123'
  ///   await sendReceipt();
  /// });
  /// // traceId is null here — even if placeOrder threw
  /// ```
  ///
  /// **Nesting caveat:** trace IDs do not stack. If `withTraceId` is
  /// called inside another `withTraceId`, the inner `finally` clears
  /// the outer trace. Use unique spans rather than nested calls.
  static Future<T> withTraceId<T>(
    String traceId,
    Future<T> Function() work,
  ) async {
    setTraceId(traceId);
    try {
      return await work();
    } finally {
      clearTraceId();
    }
  }

  /// Synchronous version of [withTraceId].
  ///
  /// ```dart
  /// final result = LogPilot.withTraceIdSync('op-42', () {
  ///   return computeTotal(cart);
  /// });
  /// ```
  static T withTraceIdSync<T>(String traceId, T Function() work) {
    setTraceId(traceId);
    try {
      return work();
    } finally {
      clearTraceId();
    }
  }

  // ── Breadcrumbs ─────────────────────────────────────────────────────

  /// Add a manual breadcrumb to the trail.
  ///
  /// Breadcrumbs are lightweight markers that record what happened
  /// before an error. They are automatically attached to error/fatal
  /// [LogPilotRecord]s so AI agents and developers get immediate pre-crash
  /// context.
  ///
  /// LogPilot also auto-adds a breadcrumb for every regular log call.
  /// Use [addBreadcrumb] when you want to record an event that
  /// doesn't need a full log entry (e.g. a button tap, a state
  /// transition, a lifecycle callback).
  ///
  /// ```dart
  /// LogPilot.addBreadcrumb('Tapped checkout button', category: 'ui');
  /// LogPilot.addBreadcrumb('Cart total: \$42.00', category: 'state',
  ///     metadata: {'items': 3});
  /// ```
  static void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    LogPilotZone.breadcrumbs?.add(Breadcrumb(
      timestamp: DateTime.now(),
      message: message,
      category: category,
      metadata: metadata,
    ));
  }

  /// The current breadcrumb trail, oldest first.
  ///
  /// Returns an empty list when breadcrumbs are disabled
  /// (`maxBreadcrumbs: 0`).
  static List<Breadcrumb> get breadcrumbs =>
      LogPilotZone.breadcrumbs?.crumbs ?? const [];

  /// Clear all breadcrumbs from the buffer.
  static void clearBreadcrumbs() => LogPilotZone.breadcrumbs?.clear();

  // ── Performance Timing ──────────────────────────────────────────────

  static final Map<String, Stopwatch> _timers = {};

  /// Start a named timer for measuring operation duration.
  ///
  /// Call [timeEnd] with the same [label] to stop the timer and log the
  /// elapsed time. Multiple timers can run concurrently with different
  /// labels.
  ///
  /// ```dart
  /// LogPilot.time('fetchUsers');
  /// final users = await api.fetchUsers();
  /// LogPilot.timeEnd('fetchUsers');  // logs: "fetchUsers: 342ms"
  /// ```
  static void time(String label) {
    _timers[label] = Stopwatch()..start();
  }

  /// Stop a named timer and log the elapsed duration.
  ///
  /// Logs at [level] (default: [LogLevel.debug]) with the [tag] `'perf'`.
  /// Returns the elapsed [Duration], or `null` if no timer with [label]
  /// was found.
  ///
  /// The timer is removed after this call. Calling [timeEnd] again with
  /// the same label without a prior [time] call logs a warning.
  static Duration? timeEnd(
    String label, {
    LogLevel level = LogLevel.debug,
    String? tag,
  }) {
    final sw = _timers.remove(label);
    if (sw == null) {
      warning('LogPilot.timeEnd("$label") called without a matching LogPilot.time()',
          tag: tag ?? 'perf');
      return null;
    }
    sw.stop();
    final elapsed = sw.elapsed;
    _log(
      level,
      '$label: ${elapsed.inMilliseconds}ms',
      tag: tag ?? 'perf',
      metadata: {
        'label': label,
        'elapsedMs': elapsed.inMilliseconds,
        'elapsedUs': elapsed.inMicroseconds,
      },
    );
    return elapsed;
  }

  /// Run [work] with a named timer, logging the elapsed time on
  /// success and cancelling on exception.
  ///
  /// Unlike [instrumentAsync], the timer is registered via [time] and
  /// is visible in [snapshot] `activeTimers` while running.
  ///
  /// ```dart
  /// final users = await LogPilot.withTimer('fetchUsers', work: () => api.getUsers());
  /// ```
  static Future<T> withTimer<T>(
    String label, {
    LogLevel level = LogLevel.debug,
    String? tag,
    required Future<T> Function() work,
  }) async {
    time(label);
    try {
      final result = await work();
      timeEnd(label, level: level, tag: tag);
      return result;
    } catch (_) {
      timeCancel(label);
      rethrow;
    }
  }

  /// Synchronous version of [withTimer].
  ///
  /// ```dart
  /// final config = LogPilot.withTimerSync('parseConfig', work: () => parse(raw));
  /// ```
  static T withTimerSync<T>(
    String label, {
    LogLevel level = LogLevel.debug,
    String? tag,
    required T Function() work,
  }) {
    time(label);
    try {
      final result = work();
      timeEnd(label, level: level, tag: tag);
      return result;
    } catch (_) {
      timeCancel(label);
      rethrow;
    }
  }

  /// Cancel a running timer without logging the elapsed time.
  ///
  /// Useful when an operation is abandoned and you don't want a timing
  /// log to appear. If no timer with [label] exists, a [LogLevel.verbose]
  /// hint is logged to aid debugging (e.g. misspelled label or
  /// double-cancel).
  static void timeCancel(String label) {
    final sw = _timers.remove(label);
    if (sw == null) {
      verbose(
        'LogPilot.timeCancel("$label") called without a matching LogPilot.time()',
        tag: 'perf',
      );
      return;
    }
    sw.stop();
  }

  // ── Instrumentation ────────────────────────────────────────────────

  /// Wrap a synchronous expression with automatic timing, result
  /// logging, and error capture.
  ///
  /// Designed for AI agents to quickly add observability to suspicious
  /// code without writing boilerplate — and remove it in one line when
  /// debugging is done.
  ///
  /// Logs at [LogLevel.debug] on success (with return value) and
  /// [LogLevel.error] on failure (with error + stack trace). The
  /// original return value or exception is always propagated.
  ///
  /// ```dart
  /// final result = LogPilot.instrument('parseConfig', () => parseConfig(raw));
  /// ```
  static T instrument<T>(
    String label,
    T Function() fn, {
    String? tag,
    LogLevel level = LogLevel.debug,
  }) {
    final sw = Stopwatch()..start();
    try {
      final result = fn();
      sw.stop();
      _log(
        level,
        '$label completed in ${sw.elapsedMilliseconds}ms',
        tag: tag ?? 'instrument',
        metadata: {
          'label': label,
          'elapsedMs': sw.elapsedMilliseconds,
          'result': '$result',
        },
      );
      return result;
    } catch (e, st) {
      sw.stop();
      _log(
        LogLevel.error,
        '$label failed after ${sw.elapsedMilliseconds}ms',
        error: e,
        stackTrace: st,
        tag: tag ?? 'instrument',
        metadata: {
          'label': label,
          'elapsedMs': sw.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  /// Wrap an asynchronous operation with automatic timing, result
  /// logging, and error capture.
  ///
  /// The async counterpart to [instrument]. Awaits the [Future]
  /// returned by [fn] and logs timing + result on completion.
  ///
  /// ```dart
  /// final users = await LogPilot.instrumentAsync(
  ///   'fetchUsers',
  ///   () => api.getUsers(),
  /// );
  /// ```
  static Future<T> instrumentAsync<T>(
    String label,
    Future<T> Function() fn, {
    String? tag,
    LogLevel level = LogLevel.debug,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await fn();
      sw.stop();
      _log(
        level,
        '$label completed in ${sw.elapsedMilliseconds}ms',
        tag: tag ?? 'instrument',
        metadata: {
          'label': label,
          'elapsedMs': sw.elapsedMilliseconds,
          'result': '$result',
        },
      );
      return result;
    } catch (e, st) {
      sw.stop();
      _log(
        LogLevel.error,
        '$label failed after ${sw.elapsedMilliseconds}ms',
        error: e,
        stackTrace: st,
        tag: tag ?? 'instrument',
        metadata: {
          'label': label,
          'elapsedMs': sw.elapsedMilliseconds,
        },
      );
      rethrow;
    }
  }

  // ── Level-based logging ───────────────────────────────────────────

  /// Log at an arbitrary [level].
  ///
  /// This is the general-purpose entry point that the named convenience
  /// methods ([verbose], [debug], [info], [warning], [error], [fatal])
  /// delegate to. Use it when the log level is determined at runtime
  /// (e.g. in observers or integration layers).
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation — the function is only called if the log passes
  /// the level filter.
  static void log(
    LogLevel level,
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(level, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log at [LogLevel.verbose].
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation — the function is only called if the log passes
  /// the level filter.
  static void verbose(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.verbose, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log at [LogLevel.debug].
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation.
  static void debug(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.debug, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log at [LogLevel.info].
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation.
  static void info(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.info, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log at [LogLevel.warning].
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation.
  static void warning(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.warning, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log at [LogLevel.error].
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation.
  static void error(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.error, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log at [LogLevel.fatal].
  ///
  /// [message] can be a [String] or a `String Function()` for lazy
  /// evaluation.
  static void fatal(
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) =>
      _log(LogLevel.fatal, message,
          error: error, stackTrace: stackTrace, metadata: metadata, tag: tag);

  /// Log a JSON string with automatic pretty-printing.
  ///
  /// Supports both JSON objects and arrays. Falls back to raw text
  /// if parsing fails.
  static void json(
    String raw, {
    LogLevel level = LogLevel.debug,
    String? tag,
  }) {
    final config = LogPilotZone.config;
    final hasHistory = LogPilotZone.history != null;
    if (!config.enabled && config.sinks.isEmpty && !hasHistory) return;
    if (level.priority < config.logLevel.priority) return;
    if (!config.isTagAllowed(tag)) return;

    final printer = LogPilotZone.printer;
    final caller = _captureCaller();
    final timestamp = DateTime.now();

    if (config.enabled) {
      final limiter = _getRateLimiter(config);
      var shouldPrint = true;

      if (limiter != null) {
        final result = limiter.check(level, raw);
        switch (result.action) {
          case RateLimitAction.suppress:
            shouldPrint = false;
          case RateLimitAction.summarize:
            printer.printLog(
              level: level,
              title: 'JSON',
              message: '$raw\n'
                  '... repeated ${result.suppressedCount} times',
              caller: caller,
              tag: tag,
            );
            shouldPrint = false;
          case RateLimitAction.allow:
            break;
        }
      }

      if (shouldPrint) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            printer.printLog(
              level: level,
              title: 'JSON',
              metadata: decoded,
              caller: caller,
              tag: tag,
            );
          } else if (decoded is List || decoded != null) {
            printer.printLog(
              level: level,
              title: 'JSON',
              preformattedLines: printer.formatJsonString(raw),
              caller: caller,
              tag: tag,
            );
          }
        } catch (_) {
          printer.printLog(
            level: level,
            title: 'JSON',
            message: raw,
            caller: caller,
            tag: tag,
          );
        }
      }
    }

    final crumbMessage = tag != null
        ? 'json: $tag'
        : 'json: ${raw.length > 50 ? '${raw.substring(0, 50)}...' : raw}';
    LogPilotZone.breadcrumbs?.add(Breadcrumb(
      timestamp: timestamp,
      message: crumbMessage,
      category: tag,
    ));

    _dispatchToSinks(LogPilotRecord(
      level: level,
      timestamp: timestamp,
      message: raw,
      tag: tag,
      caller: caller,
      sessionId: LogPilotZone.sessionId,
      traceId: LogPilotZone.traceId,
    ));
  }

  // ── Private ───────────────────────────────────────────────────────

  static RateLimiter? _rateLimiter;

  static RateLimiter? _getRateLimiter(LogPilotConfig config) {
    if (config.deduplicateWindow <= Duration.zero) {
      _rateLimiter = null;
      return null;
    }
    if (_rateLimiter == null ||
        _rateLimiter!.window != config.deduplicateWindow) {
      _rateLimiter = RateLimiter(config.deduplicateWindow);
    }
    return _rateLimiter;
  }

  static void _log(
    LogLevel level,
    Object message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
    String? tag,
  }) {
    final config = LogPilotZone.config;

    final hasHistory = LogPilotZone.history != null;
    if (!config.enabled && config.sinks.isEmpty && !hasHistory) return;

    if (level.priority < config.logLevel.priority) return;
    if (!config.isTagAllowed(tag)) return;

    final resolved = _resolveMessage(message);
    final caller = _captureCaller();
    final timestamp = DateTime.now();

    final isError =
        level == LogLevel.error || level == LogLevel.fatal;

    // Snapshot breadcrumbs before adding the current one (for error records).
    List<Breadcrumb>? crumbs;
    String? eid;
    if (isError) {
      final buf = LogPilotZone.breadcrumbs;
      if (buf != null && buf.length > 0) {
        crumbs = List.unmodifiable(buf.crumbs);
      }
      if (error != null) {
        eid = generateErrorId(error: error, stackTrace: stackTrace);
      }
    }

    // Auto-add breadcrumb for this log call.
    LogPilotZone.breadcrumbs?.add(Breadcrumb(
      timestamp: timestamp,
      message: resolved,
      category: tag,
    ));

    // Console output with optional deduplication.
    if (config.enabled) {
      final limiter = _getRateLimiter(config);
      var shouldPrint = true;

      if (limiter != null) {
        final result = limiter.check(level, resolved);
        switch (result.action) {
          case RateLimitAction.suppress:
            shouldPrint = false;
          case RateLimitAction.summarize:
            LogPilotZone.printer.printLog(
              level: level,
              title: level.label,
              message: '$resolved\n'
                  '... repeated ${result.suppressedCount} times',
              error: error,
              stackTrace: stackTrace,
              metadata: metadata,
              caller: caller,
              tag: tag,
            );
            shouldPrint = false;
          case RateLimitAction.allow:
            break;
        }
      }

      if (shouldPrint) {
        LogPilotZone.printer.printLog(
          level: level,
          title: level.label,
          message: resolved,
          error: error,
          stackTrace: stackTrace,
          metadata: metadata,
          caller: caller,
          tag: tag,
          errorId: eid,
          breadcrumbs: crumbs,
        );
      }
    }

    final record = LogPilotRecord(
      level: level,
      timestamp: timestamp,
      message: resolved,
      tag: tag,
      caller: caller,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
      sessionId: LogPilotZone.sessionId,
      traceId: LogPilotZone.traceId,
      errorId: eid,
      breadcrumbs: crumbs,
    );

    _dispatchToSinks(record);
  }

  /// Resolve a message that may be a [String] or a lazy `String Function()`.
  static String _resolveMessage(Object message) {
    if (message is String) return message;
    if (message is String Function()) return message();
    return message.toString();
  }

  /// Add a record to the in-memory history and dispatch to sinks.
  ///
  /// History is always updated synchronously. Sink dispatch is also
  /// synchronous (for simplicity and test compatibility), but
  /// deduplication is applied when [LogPilotConfig.deduplicateWindow] is
  /// set. For sinks that do expensive work, use [AsyncLogSink] or
  /// [BufferedCallbackSink] which handle their own deferral.
  ///
  /// Each sink is wrapped in a try-catch so a throwing sink cannot
  /// prevent subsequent sinks from receiving the record.
  static void _dispatchToSinks(LogPilotRecord record) {
    LogPilotZone.history?.add(record);

    final config = LogPilotZone.config;
    final sinks = config.sinks;
    if (sinks.isEmpty) return;

    final limiter = _getSinkRateLimiter(config);
    if (limiter != null) {
      final result = limiter.check(record.level, record.message ?? '');
      if (result.action == RateLimitAction.suppress) return;
    }

    final sw = _diagnostics != null ? (Stopwatch()..start()) : null;
    for (final sink in sinks) {
      try {
        sink.onLog(record);
      } catch (e) {
        assert(() {
          debugPrint('[LogPilot] Sink ${sink.runtimeType} threw: $e');
          return true;
        }());
      }
    }
    if (sw != null) {
      sw.stop();
      _diagnostics?.recordDispatch(sinkLatency: sw.elapsed);
    }
  }

  static RateLimiter? _sinkRateLimiter;

  static RateLimiter? _getSinkRateLimiter(LogPilotConfig config) {
    if (config.deduplicateWindow <= Duration.zero) {
      _sinkRateLimiter = null;
      return null;
    }
    if (_sinkRateLimiter == null ||
        _sinkRateLimiter!.window != config.deduplicateWindow) {
      _sinkRateLimiter = RateLimiter(config.deduplicateWindow);
    }
    return _sinkRateLimiter;
  }

  static final _frameRe = RegExp(r'#\d+\s+.+\s+\((.+)\)');

  /// Walk the current stack to find the first frame outside the LogPilot
  /// package. Returns a location string like
  /// `package:my_app/home.dart:42:8` that IDEs render as clickable.
  static String? _captureCaller() {
    if (!LogPilotZone.config.showCaller) return null;

    final frames = StackTrace.current.toString().split('\n');
    for (final frame in frames) {
      final match = _frameRe.firstMatch(frame.trim());
      if (match == null) continue;
      final location = match.group(1)!;
      if (location.contains('package:log_pilot/')) continue;
      if (location.startsWith('dart:')) continue;
      return location;
    }
    return null;
  }
}

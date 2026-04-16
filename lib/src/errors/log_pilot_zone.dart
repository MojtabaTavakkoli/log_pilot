import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:log_pilot/src/core/breadcrumb.dart';
import 'package:log_pilot/src/core/log_history.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_config.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/core/log_pilot_record.dart';
import 'package:log_pilot/src/core/error_id.dart';
import 'package:log_pilot/src/core/vm_service_uri_writer.dart';
import 'package:log_pilot/src/errors/flutter_error_parser.dart';

/// Callback that builds a snapshot map from the current LogPilot state.
///
/// Injected by [LogPilot] after static initialization so the service
/// extension can call the single canonical snapshot logic without
/// creating a circular import between log_pilot.dart and log_pilot_zone.dart.
typedef SnapshotBuilder = Map<String, dynamic> Function({
  int maxRecentErrors,
  int maxRecentLogs,
  bool groupByTag,
  int perTagLimit,
});

/// Callback for forwarding errors to external services like Crashlytics.
typedef LogPilotErrorCallback = void Function(Object error, StackTrace? stack);

/// Manages the global LogPilot state and error-catching zones.
///
/// Use [LogPilot.init] (the public facade) or call [LogPilotZone.init] directly.
class LogPilotZone {
  LogPilotZone._();

  static var _initialized = false;
  static LogPilotConfig _config = const LogPilotConfig();
  static LogPilotPrinter _printer = LogPilotPrinter(const LogPilotConfig());
  static LogHistory? _history = LogHistory(500);
  static BreadcrumbBuffer? _breadcrumbs = BreadcrumbBuffer(20);
  static String _sessionId = _generateSessionId();
  static FlutterErrorParser? _errorParser;
  static LogPilotErrorCallback? _userCallback;

  /// Tracks the signature + timestamp of the last error dispatched through
  /// `_dispatchErrorToSinks` to detect error cascades. When multiple
  /// identical errors fire within [_cascadeWindowMs], only the first is
  /// recorded at its original level; subsequent duplicates are suppressed
  /// from sinks/history to prevent log flooding.
  static String? _lastErrorSignature;
  static int _lastErrorTimestamp = 0;
  static int _cascadeSuppressed = 0;
  static const int _cascadeWindowMs = 500;

  /// Injected by [LogPilot] so the `ext.LogPilot.getSnapshot` service extension
  /// can call the canonical snapshot builder without circular imports.
  static SnapshotBuilder? snapshotBuilder;

  /// Injected by [LogPilot] so the `ext.LogPilot.exportForLLM` service
  /// extension can call the canonical export logic without circular imports.
  static String Function({int tokenBudget})? exportForLLMBuilder;

  /// Whether [init] has been called.
  static bool get isInitialized => _initialized;

  /// The active configuration.
  static LogPilotConfig get config => _config;

  /// The shared printer instance. Safe to access before [init] — uses
  /// a default config until initialization.
  static LogPilotPrinter get printer => _printer;

  /// Change the minimum log level at runtime without rebuilding
  /// the entire config or restarting the app.
  ///
  /// This replaces the current [LogPilotConfig] with a copy that has
  /// the new [level], and rebuilds the [LogPilotPrinter].
  static void setLogLevel(LogLevel level) {
    _config = _config.copyWith(logLevel: level);
    _printer = LogPilotPrinter(_config);
  }

  /// The in-memory ring buffer of recent log records, or `null` if
  /// `maxHistorySize` is 0 (disabled).
  static LogHistory? get history => _history;

  /// The breadcrumb buffer, or `null` if `maxBreadcrumbs` is 0 (disabled).
  static BreadcrumbBuffer? get breadcrumbs => _breadcrumbs;

  /// A unique identifier for this app session, auto-generated on
  /// [init] or [configure]. Use for correlating logs with backend
  /// traces, crash reports, and support tickets.
  static String get sessionId => _sessionId;

  /// The current ambient trace ID, or `null` if none is set.
  ///
  /// Set via [LogPilot.setTraceId] for per-request or per-operation
  /// correlation. All logs emitted while a trace ID is active will
  /// carry it in [LogPilotRecord.traceId].
  static String? traceId;

  /// Reset all LogPilot state to defaults.
  ///
  /// Called by [LogPilot.reset] which is the public test API. Not
  /// intended for direct use outside the package.
  static void reset() {
    _initialized = false;
    // Do NOT reset _extensionsRegistered — dart:developer extensions
    // persist for the VM lifetime and cannot be unregistered. The
    // handlers reference static state on this class, which gets
    // refreshed by init()/configure().
    _config = const LogPilotConfig();
    _printer = LogPilotPrinter(_config);
    _history = LogHistory(500);
    _breadcrumbs = BreadcrumbBuffer(20);
    _sessionId = _generateSessionId();
    traceId = null;
    _errorParser = null;
    _userCallback = null;
    snapshotBuilder = null;
    exportForLLMBuilder = null;
    _lastErrorSignature = null;
    _lastErrorTimestamp = 0;
    _cascadeSuppressed = 0;
  }

  /// Set the configuration and printer without error zones.
  ///
  /// Use this when you only need manual logging (e.g. one API response)
  /// and don't want LogPilot to replace `runApp()` or install error handlers.
  ///
  /// ```dart
  /// void main() {
  ///   LogPilot.configure(config: LogPilotConfig(logLevel: LogLevel.info));
  ///   runApp(const MyApp());
  /// }
  /// ```
  ///
  /// You can also skip [configure] entirely — `LogPilot.info(...)` works
  /// out of the box with sensible defaults in debug mode.
  static void configure({LogPilotConfig? config}) {
    _config = config ?? const LogPilotConfig();
    _printer = LogPilotPrinter(_config);
    _history = _config.maxHistorySize > 0
        ? LogHistory(_config.maxHistorySize)
        : null;
    _breadcrumbs = _config.maxBreadcrumbs > 0
        ? BreadcrumbBuffer(_config.maxBreadcrumbs)
        : null;
    _sessionId = _generateSessionId();
    traceId = null;
    _registerServiceExtensions();
  }

  /// Initialize LogPilot and wrap the app in error-catching zones.
  ///
  /// This replaces a direct `runApp()` call. It sets up
  /// [FlutterError.onError], [PlatformDispatcher.instance.onError],
  /// and [runZonedGuarded] to funnel all errors through LogPilot.
  ///
  /// ```dart
  /// void main() {
  ///   LogPilot.init(
  ///     config: LogPilotConfig(logLevel: LogLevel.verbose),
  ///     onError: (error, stack) { /* forward to Crashlytics */ },
  ///     child: const MyApp(),
  ///   );
  /// }
  /// ```
  static void init({
    LogPilotConfig? config,
    LogPilotErrorCallback? onError,
    required Widget child,
  }) {
    assert(
      !_initialized,
      'LogPilot.init() was called twice. This replaces runApp() — '
      'do NOT call both LogPilot.init() and runApp(). '
      'Use LogPilot.configure() if you want to call runApp() yourself.',
    );
    _config = config ?? const LogPilotConfig();
    _printer = LogPilotPrinter(_config);
    _history = _config.maxHistorySize > 0
        ? LogHistory(_config.maxHistorySize)
        : null;
    _breadcrumbs = _config.maxBreadcrumbs > 0
        ? BreadcrumbBuffer(_config.maxBreadcrumbs)
        : null;
    _sessionId = _generateSessionId();
    traceId = null;
    _errorParser = FlutterErrorParser(_config, _printer);
    _userCallback = onError;
    _initialized = true;
    _registerServiceExtensions();

    // All binding, error handler, and runApp calls must happen inside
    // the same zone to avoid Flutter's zone-mismatch assertion. This
    // is critical when `main()` is async (e.g. awaiting platform
    // channels before calling LogPilot.init).
    runZonedGuarded(
      () {
        WidgetsFlutterBinding.ensureInitialized();

        FlutterError.onError = (FlutterErrorDetails details) {
          _errorParser!.parse(details);

          _dispatchErrorToSinks(
            error: details.exception,
            stackTrace: details.stack,
            title: 'Flutter Error',
            message: details.summary.toString(),
          );
        };

        final originalPlatformOnError = PlatformDispatcher.instance.onError;
        PlatformDispatcher.instance.onError =
            (Object error, StackTrace stack) {
          final text = '${error.runtimeType} $error';
          if (_config.isSilenced(text)) {
            if (originalPlatformOnError != null) {
              return originalPlatformOnError(error, stack);
            }
            return true;
          }

          _printer.printLog(
            level: _levelForError(error),
            title: 'Platform Error',
            message: error.toString(),
            error: error,
            stackTrace: stack,
          );

          _dispatchErrorToSinks(
            error: error,
            stackTrace: stack,
            title: 'Platform Error',
            message: error.toString(),
          );

          if (originalPlatformOnError != null) {
            return originalPlatformOnError(error, stack);
          }
          return true;
        };

        runApp(child);
      },
      (Object error, StackTrace stack) {
        final text = '${error.runtimeType} $error';
        if (_config.isSilenced(text)) return;

        _printer.printLog(
          level: _levelForError(error),
          title: 'Uncaught Exception',
          message: error.toString(),
          error: error,
          stackTrace: stack,
        );

        _dispatchErrorToSinks(
          error: error,
          stackTrace: stack,
          title: 'Uncaught Exception',
          message: error.toString(),
        );
      },
    );
  }

  static void _dispatchErrorToSinks({
    required Object error,
    StackTrace? stackTrace,
    required String title,
    required String message,
  }) {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final sig = '${error.runtimeType}:$message';

    // Cascade detection: suppress duplicate errors within the window.
    if (sig == _lastErrorSignature &&
        (nowMs - _lastErrorTimestamp) < _cascadeWindowMs) {
      _cascadeSuppressed++;
      return;
    }

    // If we were suppressing a cascade, emit a summary record first.
    if (_cascadeSuppressed > 0) {
      final summaryRecord = LogPilotRecord(
        level: LogLevel.warning,
        timestamp: now,
        message: 'Suppressed $_cascadeSuppressed duplicate error(s) '
            'in cascade (${_cascadeWindowMs}ms window)',
        tag: 'LogPilot',
        sessionId: _sessionId,
        traceId: traceId,
      );
      _history?.add(summaryRecord);
      for (final sink in _config.sinks) {
        try {
          sink.onLog(summaryRecord);
        } catch (_) {}
      }
    }

    _lastErrorSignature = sig;
    _lastErrorTimestamp = nowMs;
    _cascadeSuppressed = 0;

    // Fire the user callback only for non-suppressed errors so external
    // crash reporters (Crashlytics, Sentry) don't receive cascade duplicates.
    _userCallback?.call(error, stackTrace);

    final eid = generateErrorId(error: error, stackTrace: stackTrace);
    final crumbs = _breadcrumbs?.crumbs;

    final record = LogPilotRecord(
      level: _levelForError(error),
      timestamp: now,
      message: '$title: $message',
      error: error,
      stackTrace: stackTrace,
      sessionId: _sessionId,
      traceId: traceId,
      errorId: eid,
      breadcrumbs: crumbs != null && crumbs.isNotEmpty
          ? List.unmodifiable(crumbs)
          : null,
    );

    _history?.add(record);

    for (final sink in _config.sinks) {
      try {
        sink.onLog(record);
      } catch (e) {
        assert(() {
          debugPrint('[LogPilot] Sink ${sink.runtimeType} threw: $e');
          return true;
        }());
      }
    }
  }

  static LogLevel _levelForError(Object error) {
    if (error is AssertionError) return LogLevel.error;
    if (error is Error) return LogLevel.fatal;
    return LogLevel.error;
  }

  /// Generate a v4-like UUID using cryptographically secure randomness.
  static String _generateSessionId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  // ── Service Extensions (for DevTools) ─────────────────────────────

  static bool _extensionsRegistered = false;

  /// Register VM service extensions so the DevTools extension (and any
  /// other VM service client) can query LogPilot state without expression
  /// evaluation — which is unavailable on web targets.
  static void _registerServiceExtensions() {
    if (_extensionsRegistered) return;
    _extensionsRegistered = true;

    developer.registerExtension('ext.LogPilot.getHistory',
        (String method, Map<String, String> params) async {
      final h = _history;
      if (h == null || h.isEmpty) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'count': 0, 'entries': <String>[]}),
        );
      }
      final entries = h.records
          .map((r) => jsonEncode(r.toJson()))
          .toList();
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'count': h.length, 'entries': entries}),
      );
    });

    developer.registerExtension('ext.LogPilot.getCount',
        (String method, Map<String, String> params) async {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'count': _history?.length ?? 0}),
      );
    });

    developer.registerExtension('ext.LogPilot.getLogLevel',
        (String method, Map<String, String> params) async {
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'level': _config.logLevel.name}),
      );
    });

    developer.registerExtension('ext.LogPilot.setLogLevel',
        (String method, Map<String, String> params) async {
      final levelName = params['level'];
      if (levelName != null) {
        final level = LogLevel.values.firstWhere(
          (l) => l.name == levelName,
          orElse: () => _config.logLevel,
        );
        _config = _config.copyWith(logLevel: level);
        _printer = LogPilotPrinter(_config);
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'level': _config.logLevel.name}),
      );
    });

    developer.registerExtension('ext.LogPilot.clearHistory',
        (String method, Map<String, String> params) async {
      _history?.clear();
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'cleared': true}),
      );
    });

    developer.registerExtension('ext.LogPilot.exportForLLM',
        (String method, Map<String, String> params) async {
      final budget = int.tryParse(params['token_budget'] ?? '') ?? 4000;
      final result = exportForLLMBuilder?.call(tokenBudget: budget) ?? '';
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'result': result}),
      );
    });

    developer.registerExtension('ext.LogPilot.getSnapshot',
        (String method, Map<String, String> params) async {
      final maxErrors = int.tryParse(params['max_recent_errors'] ?? '') ?? 5;
      final maxLogs = int.tryParse(params['max_recent_logs'] ?? '') ?? 10;
      final groupByTag = params['group_by_tag'] == 'true';
      final perTagLimit = int.tryParse(params['per_tag_limit'] ?? '') ?? 5;

      final snap = snapshotBuilder?.call(
            maxRecentErrors: maxErrors,
            maxRecentLogs: maxLogs,
            groupByTag: groupByTag,
            perTagLimit: perTagLimit,
          ) ??
          {'error': 'snapshot builder not registered'};

      return developer.ServiceExtensionResponse.result(jsonEncode(snap));
    });

    // Write the VM service URI to a well-known file so log_pilot_mcp can
    // auto-discover it without manual --vm-service-uri configuration.
    writeVmServiceUri();
  }
}

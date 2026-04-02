import 'package:flutter/foundation.dart';
import 'package:log_pilot/src/core/ansi_styles.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_sink.dart';
import 'package:log_pilot/src/core/output_format.dart';

/// Global configuration for LogPilot.
///
/// Pass an instance to [LogPilot.init] to customize behavior:
/// ```dart
/// LogPilot.init(
///   config: LogPilotConfig(
///     logLevel: LogLevel.info,
///     showCaller: true,
///     showDetails: false,
///   ),
///   child: const MyApp(),
/// );
/// ```
///
/// For common setups, use the named factory constructors:
/// ```dart
/// LogPilotConfig.debug()       // verbose, all details on
/// LogPilotConfig.production()  // warning+, console off, sinks only
/// ```
@immutable
class LogPilotConfig {
  const LogPilotConfig({
    bool? enabled,
    this.logLevel = LogLevel.verbose,
    this.outputFormat = OutputFormat.pretty,
    this.showTimestamp = true,
    this.showCaller = true,
    this.showDetails = true,
    this.colorize = true,
    this.maxLineWidth = 100,
    this.stackTraceDepth = 8,
    this.maxPayloadSize = 10 * 1024,
    this.maskPatterns = const ['Authorization', 'password', 'token', 'secret'],
    this.jsonKeyColor = AnsiColor.cyan,
    this.jsonValueColor = AnsiColor.green,
    this.silencedErrors = const {},
    this.onlyTags = const {},
    this.sinks = const [],
    this.deduplicateWindow = Duration.zero,
    this.maxHistorySize = 500,
    this.maxBreadcrumbs = 20,
  }) : enabled = enabled ?? kDebugMode;

  /// Full-detail debug configuration.
  ///
  /// Verbose level, all visual features on — the default experience
  /// with an explicit name for readability.
  factory LogPilotConfig.debug({
    OutputFormat outputFormat = OutputFormat.pretty,
    List<String> maskPatterns = const [
      'Authorization', 'password', 'token', 'secret',
    ],
    Set<String> silencedErrors = const {},
    Set<String> onlyTags = const {},
    List<LogSink> sinks = const [],
    Duration deduplicateWindow = Duration.zero,
    int maxHistorySize = 500,
    int maxBreadcrumbs = 20,
  }) {
    return LogPilotConfig(
      enabled: true,
      logLevel: LogLevel.verbose,
      outputFormat: outputFormat,
      showTimestamp: true,
      showCaller: true,
      showDetails: true,
      colorize: true,
      maskPatterns: maskPatterns,
      silencedErrors: silencedErrors,
      onlyTags: onlyTags,
      sinks: sinks,
      deduplicateWindow: deduplicateWindow,
      maxHistorySize: maxHistorySize,
      maxBreadcrumbs: maxBreadcrumbs,
    );
  }

  /// Balanced staging/QA configuration.
  ///
  /// Info level and above, compact output (no error bodies or stack
  /// traces), caller locations on.
  factory LogPilotConfig.staging({
    OutputFormat outputFormat = OutputFormat.pretty,
    List<String> maskPatterns = const [
      'Authorization', 'password', 'token', 'secret',
    ],
    Set<String> silencedErrors = const {},
    Set<String> onlyTags = const {},
    List<LogSink> sinks = const [],
    Duration deduplicateWindow = const Duration(seconds: 5),
    int maxHistorySize = 500,
    int maxBreadcrumbs = 20,
  }) {
    return LogPilotConfig(
      enabled: true,
      logLevel: LogLevel.info,
      outputFormat: outputFormat,
      showTimestamp: true,
      showCaller: true,
      showDetails: false,
      colorize: true,
      maskPatterns: maskPatterns,
      silencedErrors: silencedErrors,
      onlyTags: onlyTags,
      sinks: sinks,
      deduplicateWindow: deduplicateWindow,
      maxHistorySize: maxHistorySize,
      maxBreadcrumbs: maxBreadcrumbs,
    );
  }

  /// Minimal production configuration.
  ///
  /// Console output is **off** — only [sinks] receive log records.
  /// Warning level and above, no colors, no caller capture overhead.
  /// Pass sinks to route logs to Crashlytics, Sentry, file, etc.
  ///
  /// ```dart
  /// LogPilotConfig.production(
  ///   sinks: [
  ///     CallbackSink((record) {
  ///       FirebaseCrashlytics.instance.log(record.message ?? '');
  ///     }),
  ///   ],
  /// )
  /// ```
  factory LogPilotConfig.production({
    LogLevel logLevel = LogLevel.warning,
    OutputFormat outputFormat = OutputFormat.pretty,
    List<String> maskPatterns = const [
      'Authorization', 'password', 'token', 'secret',
    ],
    Set<String> silencedErrors = const {},
    Set<String> onlyTags = const {},
    List<LogSink> sinks = const [],
    Duration deduplicateWindow = const Duration(seconds: 5),
    int maxHistorySize = 500,
    int maxBreadcrumbs = 20,
  }) {
    return LogPilotConfig(
      enabled: false,
      logLevel: logLevel,
      outputFormat: outputFormat,
      showTimestamp: false,
      showCaller: false,
      showDetails: false,
      colorize: false,
      maskPatterns: maskPatterns,
      silencedErrors: silencedErrors,
      onlyTags: onlyTags,
      sinks: sinks,
      deduplicateWindow: deduplicateWindow,
      maxHistorySize: maxHistorySize,
      maxBreadcrumbs: maxBreadcrumbs,
    );
  }

  /// Web-optimized configuration.
  ///
  /// On web, `developer.log()` is significantly more expensive than on
  /// native, ANSI codes are unsupported in browser consoles, and string
  /// formatting has higher cost due to JS interop. This factory provides
  /// sensible defaults: info-level logging, plain output format, no
  /// caller capture (stack traces are expensive on web), compact output,
  /// and 5-second deduplication.
  ///
  /// ```dart
  /// LogPilot.init(config: LogPilotConfig.web(), child: const MyApp());
  /// ```
  factory LogPilotConfig.web({
    LogLevel logLevel = LogLevel.info,
    OutputFormat outputFormat = OutputFormat.plain,
    List<String> maskPatterns = const [
      'Authorization', 'password', 'token', 'secret',
    ],
    Set<String> silencedErrors = const {},
    Set<String> onlyTags = const {},
    List<LogSink> sinks = const [],
    Duration deduplicateWindow = const Duration(seconds: 5),
    int maxHistorySize = 200,
    int maxBreadcrumbs = 10,
  }) {
    return LogPilotConfig(
      enabled: true,
      logLevel: logLevel,
      outputFormat: outputFormat,
      showTimestamp: true,
      showCaller: false,
      showDetails: false,
      colorize: false,
      stackTraceDepth: 4,
      maxPayloadSize: 4 * 1024,
      maskPatterns: maskPatterns,
      silencedErrors: silencedErrors,
      onlyTags: onlyTags,
      sinks: sinks,
      deduplicateWindow: deduplicateWindow,
      maxHistorySize: maxHistorySize,
      maxBreadcrumbs: maxBreadcrumbs,
    );
  }

  /// Whether console output is active. Defaults to `true` in debug mode.
  ///
  /// When `false`, logs are not printed to the console but are still
  /// dispatched to [sinks].
  final bool enabled;

  /// Minimum level a log must have to be printed or dispatched.
  final LogLevel logLevel;

  /// Controls how log output is rendered to the console.
  ///
  /// - [OutputFormat.pretty] (default) — box-bordered, colorized blocks
  ///   for human reading in IDEs and DevTools.
  /// - [OutputFormat.plain] — flat single-line output with no ANSI or
  ///   borders, designed for AI agents parsing terminal output.
  /// - [OutputFormat.json] — one NDJSON line per log entry, designed for
  ///   structured log pipelines and AI agent consumption.
  ///
  /// The [plain] and [json] modes override [colorize] to `false` and
  /// ignore box-drawing settings ([maxLineWidth], [showDetails] layout).
  final OutputFormat outputFormat;

  /// Show timestamps on each log block.
  final bool showTimestamp;

  /// Show a clickable caller location (`file.dart:line:col`) in each
  /// log block produced by [LogPilot.info], [LogPilot.error], etc.
  ///
  /// The location points to the call site in your code. In most IDEs
  /// and terminals the path is clickable and jumps to the source.
  ///
  /// **Performance note:** Capturing the caller requires
  /// `StackTrace.current` on every log call, which has non-trivial
  /// overhead — especially on web where stack trace capture goes
  /// through JS interop. Disable this in production and high-
  /// throughput scenarios. [LogPilotConfig.production] and
  /// [LogPilotConfig.web] set this to `false` by default.
  final bool showCaller;

  /// Show verbose detail sections in log output.
  ///
  /// When `true` (default), error logs include the full `error.toString()`
  /// body, Flutter errors include the `informationCollector` details,
  /// and stack traces are printed.
  ///
  /// Set `false` for compact output that shows only the message, caller,
  /// and metadata.
  final bool showDetails;

  /// Use ANSI color codes in output. Set `false` for plain text.
  final bool colorize;

  /// Max character width before wrapping inside log boxes.
  final int maxLineWidth;

  /// Maximum number of stack frames to display.
  final int stackTraceDepth;

  /// Payloads larger than this (in bytes) are truncated.
  final int maxPayloadSize;

  /// Header and body field names whose values should be masked with `***`.
  ///
  /// Three pattern forms are supported:
  ///
  /// - **Substring** (default): `'token'` masks any key containing
  ///   "token" (e.g. `accessToken`, `tokenExpiry`, `refresh_token`).
  /// - **Exact match**: `'=accessToken'` masks only the key
  ///   `accessToken`, not `tokenExpiry` or `refreshToken`.
  /// - **Regex**: `'~^(access|refresh)_token$'` matches keys that
  ///   satisfy the regular expression (case-insensitive).
  ///
  /// All matching is case-insensitive.
  final List<String> maskPatterns;

  /// Color applied to JSON keys (e.g. `"name":`).
  final AnsiColor jsonKeyColor;

  /// Color applied to JSON values (e.g. `"Alice"`, `42`, `true`).
  final AnsiColor jsonValueColor;

  /// Error substrings to suppress entirely.
  ///
  /// If an error's message or runtime type name contains any of these
  /// strings (case-insensitive), the log is silenced. Works for Flutter
  /// errors, platform errors, and uncaught zone exceptions.
  ///
  /// ```dart
  /// LogPilotConfig(
  ///   silencedErrors: {'RenderFlex overflowed', 'HTTP 404'},
  /// )
  /// ```
  final Set<String> silencedErrors;

  /// When non-empty, **only** logs whose `tag` is in this set are printed.
  ///
  /// All untagged logs and logs with a different tag are silenced.
  /// When empty (default), every log is printed regardless of tag.
  ///
  /// ```dart
  /// // Only show logs tagged 'checkout' or 'auth':
  /// LogPilotConfig(onlyTags: {'checkout', 'auth'})
  ///
  /// // In your code:
  /// LogPilot.info('Starting payment', tag: 'checkout');  // printed
  /// LogPilot.info('Cache hit');                           // silenced
  /// ```
  final Set<String> onlyTags;

  /// Additional output destinations for log records.
  ///
  /// Sinks receive [LogPilotRecord] instances for every log that passes
  /// the [logLevel] and [onlyTags] filters — even when [enabled] is
  /// `false` (console off). This lets you route logs to files, crash
  /// reporters, or remote backends independently of console output.
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
  final List<LogSink> sinks;

  /// Time window for collapsing duplicate log messages.
  ///
  /// When set to a non-zero duration, identical messages (same level +
  /// message text) within this window are suppressed from both the
  /// console and sink dispatch. When the window expires, a summary line
  /// is printed: `"... repeated N times"`.
  ///
  /// [LogPilot.history] still receives every record regardless of
  /// deduplication. Set to [Duration.zero] (default) to disable.
  ///
  /// ```dart
  /// LogPilotConfig(
  ///   deduplicateWindow: Duration(seconds: 5),
  /// )
  /// ```
  final Duration deduplicateWindow;

  /// Maximum number of log records to keep in the in-memory ring buffer.
  ///
  /// The history is accessible via [LogPilot.history] and exportable via
  /// [LogPilot.export]. Oldest records are evicted when the buffer is full.
  /// Set to `0` to disable in-memory history entirely.
  ///
  /// ```dart
  /// LogPilotConfig(maxHistorySize: 1000)
  /// ```
  final int maxHistorySize;

  /// Maximum number of breadcrumbs retained for error context.
  ///
  /// When an error or fatal log is emitted, the most recent N breadcrumbs
  /// are attached to the [LogPilotRecord]. Each regular log call and navigation
  /// event automatically adds a breadcrumb. Set to `0` to disable.
  ///
  /// ```dart
  /// LogPilotConfig(maxBreadcrumbs: 30)
  /// ```
  final int maxBreadcrumbs;

  /// Returns `true` if [text] matches any pattern in [silencedErrors].
  bool isSilenced(String text) {
    if (silencedErrors.isEmpty) return false;
    final lower = text.toLowerCase();
    return silencedErrors.any((p) => lower.contains(p.toLowerCase()));
  }

  /// Returns `true` if [tag] passes the [onlyTags] filter.
  ///
  /// Always returns `true` when [onlyTags] is empty (no filtering).
  bool isTagAllowed(String? tag) {
    if (onlyTags.isEmpty) return true;
    return tag != null && onlyTags.contains(tag);
  }

  LogPilotConfig copyWith({
    bool? enabled,
    LogLevel? logLevel,
    OutputFormat? outputFormat,
    bool? showTimestamp,
    bool? showCaller,
    bool? showDetails,
    bool? colorize,
    int? maxLineWidth,
    int? stackTraceDepth,
    int? maxPayloadSize,
    List<String>? maskPatterns,
    AnsiColor? jsonKeyColor,
    AnsiColor? jsonValueColor,
    Set<String>? silencedErrors,
    Set<String>? onlyTags,
    List<LogSink>? sinks,
    Duration? deduplicateWindow,
    int? maxHistorySize,
    int? maxBreadcrumbs,
  }) {
    return LogPilotConfig(
      enabled: enabled ?? this.enabled,
      logLevel: logLevel ?? this.logLevel,
      outputFormat: outputFormat ?? this.outputFormat,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      showCaller: showCaller ?? this.showCaller,
      showDetails: showDetails ?? this.showDetails,
      colorize: colorize ?? this.colorize,
      maxLineWidth: maxLineWidth ?? this.maxLineWidth,
      stackTraceDepth: stackTraceDepth ?? this.stackTraceDepth,
      maxPayloadSize: maxPayloadSize ?? this.maxPayloadSize,
      maskPatterns: maskPatterns ?? this.maskPatterns,
      jsonKeyColor: jsonKeyColor ?? this.jsonKeyColor,
      jsonValueColor: jsonValueColor ?? this.jsonValueColor,
      silencedErrors: silencedErrors ?? this.silencedErrors,
      onlyTags: onlyTags ?? this.onlyTags,
      sinks: sinks ?? this.sinks,
      deduplicateWindow: deduplicateWindow ?? this.deduplicateWindow,
      maxHistorySize: maxHistorySize ?? this.maxHistorySize,
      maxBreadcrumbs: maxBreadcrumbs ?? this.maxBreadcrumbs,
    );
  }
}

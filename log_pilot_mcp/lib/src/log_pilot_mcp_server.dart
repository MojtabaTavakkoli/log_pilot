import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// MCP server that exposes a running Flutter app's LogPilot state to AI agents.
///
/// Connects to the app's Dart VM service and uses LogPilot's registered service
/// extensions (`ext.LogPilot.*`) to query logs, take snapshots, change log levels,
/// and more. Falls back to `evaluate` for operations that don't have a
/// dedicated service extension.
///
/// Automatically reconnects when the Dart isolate recycles (e.g. hot restart
/// or heavy navigation). If the connection drops mid-call, the server retries
/// up to [maxRetries] times with exponential backoff before surfacing the
/// error.
///
/// Usage from Cursor / Claude Code MCP config:
/// ```json
/// {
///   "LogPilot": {
///     "command": "dart",
///     "args": ["run", "log_pilot_mcp", "--vm-service-uri=ws://127.0.0.1:PORT/ws"]
///   }
/// }
/// ```
base class LogPilotMcpServer extends MCPServer
    with ToolsSupport, ResourcesSupport, LoggingSupport {
  LogPilotMcpServer(
    super.channel, {
    required this.vmServiceUri,
    this.maxRetries = 3,
  }) : super.fromStreamChannel(
          implementation: Implementation(
            name: 'log_pilot_mcp',
            version: '0.2.0',
          ),
          instructions: '''
LogPilot MCP server — exposes a running Flutter app's LogPilot logging state.

Tools:
  get_snapshot     — Structured summary of recent app activity (supports grouping by tag)
  query_logs       — Filter log history by level, tag, or count
  export_logs      — Full log history as text or NDJSON
  export_for_llm   — Compressed summary optimized for LLM context windows
  set_log_level    — Change verbosity at runtime
  get_log_level    — Read current log level
  clear_logs       — Wipe in-memory log history
  watch_logs       — Start streaming new log entries (push via notifications/message)
  stop_watch       — Stop the active watch and get a delivery summary

Resources:
  LogPilot://config    — Current LogPilot configuration
  LogPilot://session   — Session and trace IDs
  LogPilot://tail      — Latest batch of entries from the active log watcher (subscribable)

The server auto-reconnects on hot restart and isolate recycle.
''',
        ) {
    // Allow all LogPilot levels to be pushed via log(). The LoggingSupport
    // mixin defaults to warning, which would silently drop debug/info
    // entries from watch_logs.
    loggingLevel = LoggingLevel.debug;

    _registerTools();
    _registerResources();
  }

  String vmServiceUri;

  /// Maximum reconnection attempts before surfacing an error.
  final int maxRetries;

  VmService? _vmService;
  String? _isolateId;
  String? _libraryId;
  final List<String> _fallbackLibraryIds = [];
  bool _useServiceExtensions = false;
  bool _connecting = false;
  StreamSubscription<Event>? _isolateEventSub;
  StreamSubscription<Event>? _debugEventSub;

  // ── Watch / tail state ──────────────────────────────────────────────
  Timer? _watchTimer;
  int _lastSeenCount = 0;
  int _deliveredCount = 0;
  String? _watchTag;
  String? _watchLevel;
  List<Map<String, dynamic>> _lastTailBatch = [];
  Resource? _tailResource;

  /// Update the VM service URI and force a reconnection on the next
  /// tool call. Used by the file-watcher auto-discovery mechanism when
  /// the URI file changes after a full app restart.
  void updateVmServiceUri(String newUri) {
    io.stderr.writeln(
      '[log_pilot_mcp] Updating VM service URI: $newUri',
    );
    vmServiceUri = newUri;
    _resetConnection();
  }

  void _resetConnection() {
    _isolateEventSub?.cancel();
    _isolateEventSub = null;
    _debugEventSub?.cancel();
    _debugEventSub = null;
    _vmService?.dispose();
    _vmService = null;
    _isolateId = null;
    _libraryId = null;
    _fallbackLibraryIds.clear();
    _useServiceExtensions = false;
    _connecting = false;
    // Reset the watch cursor so the next poll re-syncs with the new
    // isolate's history. Keep the timer and filters alive so the watch
    // auto-resumes after reconnection.
    _lastSeenCount = 0;
    _lastTailBatch = [];
  }

  Future<void> _ensureConnected() async {
    if (_vmService != null && _isolateId != null) return;
    if (_connecting) {
      while (_connecting) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (_vmService != null && _isolateId != null) return;
    }

    _connecting = true;
    try {
      if (_vmService != null && _isolateId == null) {
        // WebSocket is alive but isolate was recycled (hot restart).
        await _resolveIsolate();
      } else {
        await _connect();
      }
    } finally {
      _connecting = false;
    }
  }

  Future<void> _connect() async {
    _vmService = await vmServiceConnectUri(vmServiceUri);

    // Listen for isolate lifecycle events so we can reconnect on hot
    // restart instead of leaving the agent with a stale connection.
    try {
      await _vmService!.streamListen(EventStreams.kIsolate);
      _isolateEventSub = _vmService!.onIsolateEvent.listen(_onIsolateEvent);
    } catch (_) {
      // Best-effort — some VM versions don't expose the stream.
    }

    // Listen for service-extension registrations so we pick up LogPilot's
    // extensions even when they register after our initial handshake
    // (common after hot restart).
    try {
      await _vmService!.streamListen(EventStreams.kDebug);
      _debugEventSub = _vmService!.onDebugEvent.listen(_onDebugEvent);
    } catch (_) {}

    await _resolveIsolate();
  }

  /// Discover the running isolate, check for LogPilot extensions, and
  /// resolve libraries for expression evaluation.
  Future<void> _resolveIsolate() async {
    final vm = await _vmService!.getVM();
    final isolate = vm.isolates?.firstOrNull;
    if (isolate == null) {
      throw StateError('No isolates found in the target VM.');
    }
    _isolateId = isolate.id!;

    final isolateObj = await _vmService!.getIsolate(_isolateId!);

    final extensions = isolateObj.extensionRPCs ?? [];
    _useServiceExtensions = extensions.contains('ext.LogPilot.getLogLevel');
    io.stderr.writeln('[log_pilot_mcp] Service extensions available: '
        '$_useServiceExtensions '
        '(found ${extensions.where((e) => e.startsWith("ext.LogPilot")).length} '
        'ext.LogPilot.* RPCs)');

    final libs = isolateObj.libraries ?? [];
    final lkRelated = libs
        .where((lib) => lib.uri?.contains('LogPilot') ?? false)
        .toList();
    io.stderr.writeln('[log_pilot_mcp] ${lkRelated.length} LogPilot libraries: '
        '${lkRelated.map((l) => l.uri).join(', ')}');

    const preferredUris = [
      'package:log_pilot/src/LogPilot.dart',
      'package:log_pilot/log_pilot.dart',
    ];

    LibraryRef? lkLib;
    for (final uri in preferredUris) {
      lkLib = libs.cast<LibraryRef?>().firstWhere(
            (lib) => lib!.uri == uri,
            orElse: () => null,
          );
      if (lkLib != null) break;
    }

    lkLib ??= libs.cast<LibraryRef?>().firstWhere(
          (lib) => lib!.uri?.endsWith('/main.dart') ?? false,
          orElse: () => null,
        );

    lkLib ??= libs.cast<LibraryRef?>().firstWhere(
          (lib) => lib!.uri?.contains('package:log_pilot/') ?? false,
          orElse: () => null,
        );

    if (lkLib != null) {
      _libraryId = lkLib.id!;
      io.stderr.writeln('[log_pilot_mcp] Selected eval library: ${lkLib.uri}');

      _fallbackLibraryIds.clear();
      for (final lib in lkRelated) {
        if (lib.id != _libraryId) _fallbackLibraryIds.add(lib.id!);
      }
      final mainLib = libs.cast<LibraryRef?>().firstWhere(
            (lib) => lib!.uri?.endsWith('/main.dart') ?? false,
            orElse: () => null,
          );
      if (mainLib != null && mainLib.id != _libraryId) {
        _fallbackLibraryIds.add(mainLib.id!);
      }
    } else {
      io.stderr.writeln('[log_pilot_mcp] No LogPilot library found for evaluate.');
      if (!_useServiceExtensions) {
        throw StateError(
          'LogPilot library not found and no service extensions registered. '
          'Make sure the app depends on LogPilot, has called LogPilot.init(), '
          'and is running in debug mode.',
        );
      }
    }
  }

  void _onIsolateEvent(Event event) {
    if (event.kind == EventKind.kIsolateStart ||
        event.kind == EventKind.kIsolateRunnable) {
      io.stderr.writeln(
        '[log_pilot_mcp] Isolate ${event.kind} detected — '
        'invalidating cached state. '
        'Next tool call will re-resolve.',
      );
      // Only invalidate isolate-specific state. Keep the WebSocket
      // connection alive — the VM service itself didn't change, just
      // the isolate it hosts. The next _withReconnect call will see
      // _isolateId == null and trigger _resolveIsolate via
      // _ensureConnected → _connect (if _vmService is also null) or
      // directly when the tool call discovers a stale isolate.
      _isolateId = null;
      _libraryId = null;
      _fallbackLibraryIds.clear();
      _useServiceExtensions = false;
    }
  }

  void _onDebugEvent(Event event) {
    if (event.kind == EventKind.kServiceExtensionAdded) {
      final ext = event.extensionRPC ?? '';
      if (ext.startsWith('ext.LogPilot.')) {
        io.stderr.writeln(
          '[log_pilot_mcp] Service extension registered: $ext',
        );
        if (!_useServiceExtensions) {
          _useServiceExtensions = true;
          io.stderr.writeln(
            '[log_pilot_mcp] Switched to service-extension mode.',
          );
        }
      }
    }
  }

  /// Returns `true` if [e] indicates a broken or stale VM connection
  /// that warrants a reconnection attempt.
  bool _isRetryableError(Object e) {
    if (e is RPCError) return true;
    if (e is SentinelException) return true;
    final msg = e.toString().toLowerCase();
    return msg.contains('websocket') ||
        msg.contains('connection') ||
        msg.contains('closed') ||
        msg.contains('sentinel') ||
        msg.contains('collected') ||
        msg.contains('stream sink');
  }

  /// Execute [action] with automatic reconnect on retryable errors.
  Future<T> _withReconnect<T>(Future<T> Function() action) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await _ensureConnected();
        return await action();
      } catch (e) {
        if (!_isRetryableError(e) || attempt == maxRetries) rethrow;
        final delayMs = 200 * (1 << attempt); // 200, 400, 800 ms
        io.stderr.writeln(
          '[log_pilot_mcp] Connection error (attempt ${attempt + 1}/$maxRetries): '
          '$e — reconnecting in ${delayMs}ms...',
        );
        _resetConnection();
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw StateError('Unreachable');
  }

  /// Call a LogPilot service extension and return the JSON response.
  Future<Map<String, dynamic>> _callExtension(
    String method, [
    Map<String, String>? args,
  ]) async {
    return _withReconnect(() async {
      final response = await _vmService!.callServiceExtension(
        method,
        isolateId: _isolateId,
        args: args,
      );
      return response.json ?? {};
    });
  }

  /// Evaluate a Dart expression against the app's VM.
  /// Tries multiple libraries until one succeeds.
  Future<String> _eval(String expression) async {
    return _withReconnect(() async {
      if (_libraryId == null) {
        throw StateError('No library available for evaluate.');
      }

      final libIds = [_libraryId!, ..._fallbackLibraryIds];
      for (var i = 0; i < libIds.length; i++) {
        final libId = libIds[i];
        final result = await _vmService!.evaluate(
          _isolateId!,
          libId,
          expression,
        );
        if (result is ErrorRef) {
          final msg = result.message ?? '';
          if (msg.contains('CompilationError') && i < libIds.length - 1) {
            io.stderr.writeln(
              '[log_pilot_mcp] Eval failed on lib $libId, trying next...',
            );
            continue;
          }
          throw StateError('Evaluation failed: $msg');
        }
        if (i > 0) {
          _libraryId = libId;
          _fallbackLibraryIds.remove(libId);
        }
        if (result is InstanceRef) {
          if (result.valueAsString != null) {
            return result.valueAsString!;
          }
          final instance = await _vmService!.getObject(
            _isolateId!,
            result.id!,
          );
          if (instance is Instance && instance.valueAsString != null) {
            return instance.valueAsString!;
          }
          return result.json.toString();
        }
        return result.toString();
      }
      throw StateError('No library could evaluate: $expression');
    });
  }

  // ── Tools ──────────────────────────────────────────────────────────

  void _registerTools() {
    registerTool(_getSnapshotTool, _getSnapshot);
    registerTool(_queryLogsTool, _queryLogs);
    registerTool(_exportLogsTool, _exportLogs);
    registerTool(_exportForLlmTool, _exportForLlm);
    registerTool(_setLogLevelTool, _setLogLevel);
    registerTool(_getLogLevelTool, _getLogLevel);
    registerTool(_clearLogsTool, _clearLogs);
    registerTool(_watchLogsTool, _watchLogs);
    registerTool(_stopWatchTool, _stopWatch);
  }

  final _getSnapshotTool = Tool(
    name: 'get_snapshot',
    description:
        'Get a structured diagnostic snapshot of recent app activity. '
        'Includes session/trace IDs, config, log counts by level, '
        'recent errors, recent logs, and active timers. '
        'Set group_by_tag to true to also get the last N logs per tag '
        '(e.g. "show me the last 3 Auth entries").',
    inputSchema: Schema.object(
      properties: {
        'max_recent_errors': Schema.int(
          description: 'Maximum error/fatal records to include (default 5)',
        ),
        'max_recent_logs': Schema.int(
          description: 'Maximum recent log records to include (default 10)',
        ),
        'group_by_tag': Schema.bool(
          description:
              'Include a recentByTag section grouping the last N records '
              'per tag (default false)',
        ),
        'per_tag_limit': Schema.int(
          description:
              'When group_by_tag is true, how many records per tag '
              '(default 5)',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _getSnapshot(CallToolRequest request) async {
    final maxErrors = request.arguments?['max_recent_errors'] as int? ?? 5;
    final maxLogs = request.arguments?['max_recent_logs'] as int? ?? 10;
    final groupByTag = request.arguments?['group_by_tag'] as bool? ?? false;
    final perTagLimit = request.arguments?['per_tag_limit'] as int? ?? 5;

    try {
      if (_useServiceExtensions) {
        final json = await _callExtension('ext.LogPilot.getSnapshot', {
          'max_recent_errors': '$maxErrors',
          'max_recent_logs': '$maxLogs',
          if (groupByTag) 'group_by_tag': 'true',
          'per_tag_limit': '$perTagLimit',
        });
        return CallToolResult(
          content: [TextContent(text: jsonEncode(json))],
        );
      }
      final json = await _eval(
        'LogPilot.snapshotAsJson('
        'maxRecentErrors: $maxErrors, '
        'maxRecentLogs: $maxLogs, '
        'groupByTag: $groupByTag, '
        'perTagLimit: $perTagLimit)',
      );
      return CallToolResult(content: [TextContent(text: json)]);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  final _queryLogsTool = Tool(
    name: 'query_logs',
    description:
        'Query the in-memory log history. Filter by level, tag, or '
        'limit the number of results. Returns JSON array of log records. '
        'Set deduplicate to true to collapse consecutive identical entries '
        '(same level + message) into a single entry with a "count" field, '
        'while preserving entries from different callers.',
    inputSchema: Schema.object(
      properties: {
        'level': Schema.string(
          description:
              'Minimum log level: verbose, debug, info, warning, error, fatal',
        ),
        'tag': Schema.string(
          description: 'Filter by tag (exact match)',
        ),
        'limit': Schema.int(
          description: 'Maximum records to return (default 20, max 100)',
        ),
        'deduplicate': Schema.bool(
          description:
              'Collapse consecutive identical entries (same level + message) '
              'into one entry with a "count" field. Entries from different '
              'callers are kept separate. Default false.',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _queryLogs(CallToolRequest request) async {
    final level = request.arguments?['level'] as String?;
    final tag = request.arguments?['tag'] as String?;
    final limit = (request.arguments?['limit'] as int? ?? 20).clamp(1, 100);
    final deduplicate =
        request.arguments?['deduplicate'] as bool? ?? false;

    try {
      if (_useServiceExtensions) {
        final json = await _callExtension('ext.LogPilot.getHistory');
        var records = _parseEntries(
          (json['entries'] as List<dynamic>?) ?? [],
        );

        if (level != null) {
          final minIndex = _levelIndex(level);
          records = records
              .where((r) => _levelIndex(r['level'] as String? ?? '') >= minIndex)
              .toList();
        }
        if (tag != null) {
          records = records.where((r) => r['tag'] == tag).toList();
        }
        if (records.length > limit) {
          records = records.sublist(records.length - limit);
        }

        if (deduplicate) {
          records = _deduplicateRecords(records);
        }

        return CallToolResult(
          content: [TextContent(text: jsonEncode(records))],
        );
      }

      final parts = <String>[];
      if (level != null) parts.add('level: LogLevel.$level');
      if (tag != null) parts.add("tag: '$tag'");

      final expr = parts.isEmpty
          ? 'LogPilot.history.take($limit).map((r) => r.toJson()).toList().toString()'
          : 'LogPilot.historyWhere(${parts.join(', ')})'
              '.take($limit).map((r) => r.toJson()).toList().toString()';

      final result = await _eval(expr);
      return CallToolResult(content: [TextContent(text: result)]);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  /// Collapse consecutive records with the same level + message into a
  /// single record with a `count` field. Records from different callers
  /// are kept separate so agents can tell which call site produced them.
  static List<Map<String, dynamic>> _deduplicateRecords(
    List<Map<String, dynamic>> records,
  ) {
    if (records.isEmpty) return records;

    final result = <Map<String, dynamic>>[];
    Map<String, dynamic>? current;
    var count = 1;

    for (final r in records) {
      if (current != null &&
          r['level'] == current['level'] &&
          r['message'] == current['message'] &&
          r['caller'] == current['caller']) {
        count++;
      } else {
        if (current != null) {
          if (count > 1) current['count'] = count;
          result.add(current);
        }
        current = Map<String, dynamic>.of(r);
        count = 1;
      }
    }
    if (current != null) {
      if (count > 1) current['count'] = count;
      result.add(current);
    }

    return result;
  }

  final _exportLogsTool = Tool(
    name: 'export_logs',
    description:
        'Export the full log history as text or NDJSON. '
        'Text format: one human-readable line per record. '
        'JSON format: one JSON object per line (NDJSON).',
    inputSchema: Schema.object(
      properties: {
        'format': Schema.string(
          description: 'Export format: "text" (default) or "json"',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _exportLogs(CallToolRequest request) async {
    final format = request.arguments?['format'] as String? ?? 'text';
    try {
      if (_useServiceExtensions) {
        final json = await _callExtension('ext.LogPilot.getHistory');
        final rawEntries = (json['entries'] as List<dynamic>?) ?? [];

        if (format == 'json') {
          final lines =
              rawEntries.map((e) => e is String ? e : jsonEncode(e));
          return CallToolResult(
            content: [TextContent(text: lines.join('\n'))],
          );
        }

        final records = _parseEntries(rawEntries);
        final lines = records.map((record) {
          final ts = record['timestamp'] ?? '';
          final lvl = (record['level'] as String? ?? '').toUpperCase();
          final t = record['tag'] ?? '';
          final msg = record['message'] ?? '';
          return '[$ts] $lvl [$t] $msg';
        });
        return CallToolResult(
          content: [TextContent(text: lines.join('\n'))],
        );
      }

      final expr = format == 'json'
          ? "LogPilot.export(format: ExportFormat.json)"
          : "LogPilot.export()";
      final result = await _eval(expr);
      return CallToolResult(content: [TextContent(text: result)]);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  final _exportForLlmTool = Tool(
    name: 'export_for_llm',
    description:
        'Export a compressed summary of log history optimized for LLM '
        'context windows. Prioritizes errors and warnings, deduplicates '
        'repeated messages, truncates verbose entries, and fills remaining '
        'budget with recent records. Output fits within the specified token '
        'budget (~4 chars per token).',
    inputSchema: Schema.object(
      properties: {
        'token_budget': Schema.int(
          description:
              'Maximum output size in approximate tokens (default 4000, '
              'which is ~16k chars)',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _exportForLlm(CallToolRequest request) async {
    final budget = request.arguments?['token_budget'] as int? ?? 4000;
    try {
      final result = await _eval('LogPilot.exportForLLM(tokenBudget: $budget)');
      return CallToolResult(content: [TextContent(text: result)]);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  final _setLogLevelTool = Tool(
    name: 'set_log_level',
    description:
        'Change the minimum log level at runtime. Takes effect immediately '
        'without app restart. Use to increase verbosity during debugging.',
    inputSchema: Schema.object(
      properties: {
        'level': Schema.string(
          description:
              'New log level: verbose, debug, info, warning, error, fatal',
        ),
      },
      required: ['level'],
    ),
  );

  FutureOr<CallToolResult> _setLogLevel(CallToolRequest request) async {
    final level = request.arguments!['level'] as String;
    final validLevels = [
      'verbose', 'debug', 'info', 'warning', 'error', 'fatal',
    ];
    if (!validLevels.contains(level)) {
      return CallToolResult(
        content: [
          TextContent(text: 'Invalid level "$level". '
              'Must be one of: ${validLevels.join(', ')}'),
        ],
        isError: true,
      );
    }
    try {
      if (_useServiceExtensions) {
        final json =
            await _callExtension('ext.LogPilot.setLogLevel', {'level': level});
        return CallToolResult(
          content: [
            TextContent(text: 'Log level set to ${json['level'] ?? level}'),
          ],
        );
      }
      await _eval('LogPilot.setLogLevel(LogLevel.$level)');
      return CallToolResult(
        content: [TextContent(text: 'Log level set to $level')],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  final _getLogLevelTool = Tool(
    name: 'get_log_level',
    description: 'Read the current minimum log level.',
    inputSchema: Schema.object(),
  );

  FutureOr<CallToolResult> _getLogLevel(CallToolRequest request) async {
    try {
      if (_useServiceExtensions) {
        final json = await _callExtension('ext.LogPilot.getLogLevel');
        return CallToolResult(
          content: [TextContent(text: json['level'] as String? ?? 'unknown')],
        );
      }
      final result = await _eval('LogPilot.logLevel.name');
      return CallToolResult(content: [TextContent(text: result)]);
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  final _clearLogsTool = Tool(
    name: 'clear_logs',
    description: 'Clear all records from the in-memory log history.',
    inputSchema: Schema.object(),
  );

  FutureOr<CallToolResult> _clearLogs(CallToolRequest request) async {
    try {
      if (_useServiceExtensions) {
        await _callExtension('ext.LogPilot.clearHistory');
        return CallToolResult(
          content: [TextContent(text: 'Log history cleared')],
        );
      }
      await _eval('LogPilot.clearHistory()');
      return CallToolResult(
        content: [TextContent(text: 'Log history cleared')],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error: $e')],
        isError: true,
      );
    }
  }

  // ── Watch / Tail ───────────────────────────────────────────────────

  final _watchLogsTool = Tool(
    name: 'watch_logs',
    description:
        'Start streaming new log entries as they arrive. '
        'Pushes new entries via MCP log notifications (notifications/message). '
        'Only one watch can be active at a time — starting a new one stops '
        'the previous. Use stop_watch to cancel.',
    inputSchema: Schema.object(
      properties: {
        'tag': Schema.string(
          description: 'Filter: only deliver entries with this tag',
        ),
        'level': Schema.string(
          description:
              'Filter: minimum log level '
              '(verbose, debug, info, warning, error, fatal)',
        ),
        'interval_ms': Schema.int(
          description:
              'Poll interval in milliseconds (default 2000, min 500)',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _watchLogs(CallToolRequest request) async {
    _stopWatchTimer();

    _watchTag = request.arguments?['tag'] as String?;
    _watchLevel = request.arguments?['level'] as String?;
    final intervalMs =
        ((request.arguments?['interval_ms'] as int?) ?? 2000).clamp(500, 30000);

    try {
      final baseline = await _fetchHistory();
      _lastSeenCount = baseline.length;
      _deliveredCount = 0;
      _lastTailBatch = [];

      _watchTimer = Timer.periodic(
        Duration(milliseconds: intervalMs),
        (_) => _pollForNewEntries(),
      );

      final filters = <String>[];
      if (_watchTag != null) filters.add('tag=$_watchTag');
      if (_watchLevel != null) filters.add('level>=$_watchLevel');
      final filterDesc =
          filters.isEmpty ? 'no filters' : filters.join(', ');

      return CallToolResult(
        content: [
          TextContent(
            text: 'Watching logs ($filterDesc, '
                'poll every ${intervalMs}ms). '
                '${baseline.length} existing entries. '
                'New entries will be pushed as notifications/message. '
                'Call stop_watch to cancel.',
          ),
        ],
      );
    } catch (e) {
      return CallToolResult(
        content: [TextContent(text: 'Error starting watch: $e')],
        isError: true,
      );
    }
  }

  final _stopWatchTool = Tool(
    name: 'stop_watch',
    description:
        'Stop the active log watcher started by watch_logs. '
        'Returns a summary of how many entries were delivered.',
    inputSchema: Schema.object(),
  );

  FutureOr<CallToolResult> _stopWatch(CallToolRequest request) {
    if (_watchTimer == null) {
      return CallToolResult(
        content: [TextContent(text: 'No active watch to stop.')],
      );
    }

    final delivered = _deliveredCount;
    _stopWatchTimer();

    return CallToolResult(
      content: [
        TextContent(
          text: 'Stopped. Delivered $delivered entries.',
        ),
      ],
    );
  }

  void _stopWatchTimer() {
    _watchTimer?.cancel();
    _watchTimer = null;
    _watchTag = null;
    _watchLevel = null;
    _lastSeenCount = 0;
    _deliveredCount = 0;
    _lastTailBatch = [];
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    if (_useServiceExtensions) {
      final json = await _callExtension('ext.LogPilot.getHistory');
      return _parseEntries((json['entries'] as List<dynamic>?) ?? []);
    }
    final raw = await _eval(
      'LogPilot.history.map((r) => r.toJsonString()).toList().toString()',
    );
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              (e is String ? jsonDecode(e) : e) as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _pollForNewEntries() async {
    try {
      final all = await _fetchHistory();
      if (all.isEmpty) return;

      // The history is a ring buffer — when full, old entries are evicted
      // and the total length stays at maxHistorySize. We can't simply diff
      // by count. Instead, compare the *last seen entry's timestamp* with
      // what's in the new batch. If the buffer shrank (eviction), reset
      // the cursor to avoid missing entries.
      final int newCount;
      if (all.length < _lastSeenCount) {
        // Buffer wrapped or was cleared — treat everything as new.
        newCount = all.length;
      } else if (all.length == _lastSeenCount) {
        // Same size — check if the last entry changed (ring buffer wrap).
        if (_lastTailBatch.isNotEmpty &&
            all.isNotEmpty &&
            _lastEntryId(all.last) != _lastEntryId(_lastTailBatch.last)) {
          // Last entry changed even though count is the same — buffer
          // wrapped. We can't determine exact new entries, so deliver
          // a conservative tail (last 20 or buffer size, whichever is
          // smaller) to avoid duplicates.
          newCount = all.length.clamp(0, 20);
        } else {
          return;
        }
      } else {
        newCount = all.length - _lastSeenCount;
      }

      var newEntries = all.sublist(all.length - newCount);
      _lastSeenCount = all.length;

      if (_watchLevel != null) {
        final minIdx = _levelIndex(_watchLevel!);
        newEntries = newEntries
            .where(
                (r) => _levelIndex(r['level'] as String? ?? '') >= minIdx)
            .toList();
      }
      if (_watchTag != null) {
        newEntries =
            newEntries.where((r) => r['tag'] == _watchTag).toList();
      }

      if (newEntries.isEmpty) return;

      _deliveredCount += newEntries.length;
      _lastTailBatch = newEntries;

      for (final entry in newEntries) {
        final lkLevel = entry['level'] as String? ?? 'info';
        final mcpLevel = _toMcpLevel(lkLevel);
        log(mcpLevel, entry, logger: 'LogPilot_tail');
      }

      if (_tailResource != null) {
        updateResource(_tailResource!);
      }
    } catch (e) {
      io.stderr.writeln('[log_pilot_mcp] Watch poll error: $e');
    }
  }

  // ── Resources ──────────────────────────────────────────────────────

  void _registerResources() {
    addResource(
      Resource(
        uri: 'LogPilot://config',
        name: 'LogPilot configuration',
        description: 'Current LogPilot configuration snapshot',
        mimeType: 'application/json',
      ),
      _readConfig,
    );

    addResource(
      Resource(
        uri: 'LogPilot://session',
        name: 'LogPilot session',
        description: 'Current session ID and trace ID',
        mimeType: 'application/json',
      ),
      _readSession,
    );

    _tailResource = Resource(
      uri: 'LogPilot://tail',
      name: 'LogPilot tail',
      description:
          'Latest batch of log entries from the active watcher. '
          'Subscribe to receive notifications when new entries arrive. '
          'Start a watcher with the watch_logs tool.',
      mimeType: 'application/json',
    );
    addResource(_tailResource!, _readTail);
  }

  FutureOr<ReadResourceResult> _readConfig(
    ReadResourceRequest request,
  ) async {
    try {
      if (_useServiceExtensions) {
        final json = await _callExtension('ext.LogPilot.getSnapshot');
        final config = json['config'] ?? {};
        return ReadResourceResult(
          contents: [
            TextResourceContents(text: jsonEncode(config), uri: request.uri),
          ],
        );
      }
      final json = await _eval('''
        '{"enabled":' + LogPilot.config.enabled.toString() +
        ',"logLevel":"' + LogPilot.config.logLevel.name + '"' +
        ',"outputFormat":"' + LogPilot.config.outputFormat.name + '"' +
        ',"maxHistorySize":' + LogPilot.config.maxHistorySize.toString() +
        ',"showCaller":' + LogPilot.config.showCaller.toString() +
        ',"showTimestamp":' + LogPilot.config.showTimestamp.toString() +
        ',"showDetails":' + LogPilot.config.showDetails.toString() +
        ',"colorize":' + LogPilot.config.colorize.toString() +
        '}'
      ''');
      return ReadResourceResult(
        contents: [TextResourceContents(text: json, uri: request.uri)],
      );
    } catch (e) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(text: '{"error":"$e"}', uri: request.uri),
        ],
      );
    }
  }

  FutureOr<ReadResourceResult> _readSession(
    ReadResourceRequest request,
  ) async {
    try {
      if (_useServiceExtensions) {
        final json = await _callExtension('ext.LogPilot.getSnapshot');
        final session = <String, dynamic>{
          'sessionId': json['sessionId'],
          if (json['traceId'] != null) 'traceId': json['traceId'],
        };
        return ReadResourceResult(
          contents: [
            TextResourceContents(text: jsonEncode(session), uri: request.uri),
          ],
        );
      }
      final json = await _eval('''
        '{"sessionId":"' + LogPilot.sessionId + '"' +
        (LogPilot.traceId != null ? ',"traceId":"' + LogPilot.traceId! + '"' : '') +
        '}'
      ''');
      return ReadResourceResult(
        contents: [TextResourceContents(text: json, uri: request.uri)],
      );
    } catch (e) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(text: '{"error":"$e"}', uri: request.uri),
        ],
      );
    }
  }

  FutureOr<ReadResourceResult> _readTail(ReadResourceRequest request) {
    final json = jsonEncode({
      'active': _watchTimer != null,
      'deliveredTotal': _deliveredCount,
      'batchSize': _lastTailBatch.length,
      'entries': _lastTailBatch,
    });
    return ReadResourceResult(
      contents: [TextResourceContents(text: json, uri: request.uri)],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  static int _levelIndex(String level) => switch (level.toLowerCase()) {
        'verbose' => 0,
        'debug' => 1,
        'info' => 2,
        'warning' => 3,
        'error' => 4,
        'fatal' => 5,
        _ => -1,
      };

  /// Parse the raw entries list from `ext.LogPilot.getHistory` into typed maps.
  static List<Map<String, dynamic>> _parseEntries(List<dynamic> entries) =>
      entries
          .map((e) =>
              jsonDecode(e is String ? e : jsonEncode(e))
                  as Map<String, dynamic>)
          .toList();

  /// Best-effort identity for a log entry, used to detect ring buffer wraps.
  static String _lastEntryId(Map<String, dynamic> entry) =>
      '${entry['timestamp']}|${entry['message']}|${entry['level']}';

  /// Map a LogPilot level string to an MCP [LoggingLevel].
  static LoggingLevel _toMcpLevel(String lkLevel) =>
      switch (lkLevel.toLowerCase()) {
        'verbose' || 'debug' => LoggingLevel.debug,
        'info' => LoggingLevel.info,
        'warning' => LoggingLevel.warning,
        'error' || 'fatal' => LoggingLevel.error,
        _ => LoggingLevel.info,
      };
}

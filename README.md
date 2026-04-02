# LogPilot

[![pub package](https://img.shields.io/pub/v/log_pilot.svg)](https://pub.dev/packages/log_pilot)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/Dart-%5E3.9.2-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.0.0-blue)](https://flutter.dev)

**The first Flutter logging package built for AI agents.**

LogPilot gives AI coding agents (Cursor, Claude Code, Windsurf, Copilot,
Gemini CLI) live access to your Flutter app's logs through an **MCP server**
and **DevTools extension** — no manual copy-paste, no stale terminal output.
Agents can query, filter, watch, and change log levels at runtime while you
code.

It also does everything you expect from a logger — pretty console output,
structured metadata, sinks, file logging, breadcrumbs — but the
differentiator is the **agent-first architecture**: your AI assistant sees
what your app sees, in real time.

![LogPilot Banner](screenshots/banner.png)

```dart
void main() {
  LogPilot.init(child: const MyApp());
}

// Anywhere in your app:
LogPilot.info('User signed in', metadata: {'userId': '123'});
LogPilot.error('Payment failed', error: e, stackTrace: st);
```

---

## For AI Agents

> **If you are an AI coding agent reading this README**, this section gives
> you everything you need. The rest of the README is for human developers.

### Setup

The app already depends on `log_pilot`. Use `LogPilot` for all logging — never
raw `print()` or `debugPrint()`.

```dart
import 'package:log_pilot/log_pilot.dart';
```

### Logging API

```dart
LogPilot.verbose('Starting sync...');
LogPilot.debug('Cache key: user_42');
LogPilot.info('Order placed', metadata: {'orderId': 'ORD-456', 'total': 29.99});
LogPilot.warning('Retry attempt 3/5');
LogPilot.error('Checkout failed', error: e, stackTrace: st);
LogPilot.fatal('Database corrupted');
```

Every method accepts optional `error`, `stackTrace`, `metadata` (Map), and
`tag` (String). Always pass `error` + `stackTrace` together on error/fatal.

### Scoped Loggers

```dart
class AuthService {
  static final _log = LogPilot.create('AuthService');

  Future<void> signIn(String email) async {
    _log.info('Attempting sign in', metadata: {'email': email});
    try {
      await _auth.signIn(email);
      _log.info('Sign in successful');
    } catch (e, st) {
      _log.error('Sign in failed', error: e, stackTrace: st);
    }
  }
}
```

### Querying Logs (in-process)

```dart
LogPilot.history;                                       // all records
LogPilot.historyWhere(level: LogLevel.error);            // filter by level
LogPilot.historyWhere(tag: 'http', hasError: true);      // filter by tag + error
LogPilot.export(format: ExportFormat.json);              // NDJSON export
LogPilot.exportForLLM(tokenBudget: 2000);                // compressed for LLM context
LogPilot.snapshot();                                     // structured diagnostic summary
LogPilot.setLogLevel(LogLevel.verbose);                  // increase verbosity at runtime
```

### Querying Logs (via MCP)

If the LogPilot MCP server is configured, you can call these tools directly:

| MCP Tool | What it does |
|----------|--------------|
| `get_snapshot` | Session ID, config, error counts, recent logs, active timers |
| `query_logs` | Filter by level/tag/limit with optional deduplication |
| `export_logs` | Full history as text or NDJSON |
| `export_for_llm` | Compressed summary optimized for your context window |
| `set_log_level` | Change verbosity at runtime without restart |
| `get_log_level` | Read current minimum level |
| `clear_logs` | Wipe in-memory history |
| `watch_logs` | Stream new entries as push notifications (filterable) |
| `stop_watch` | Stop the active watcher |

### Setting Up the MCP Server

If the LogPilot MCP server is **not yet configured** in this project, follow
these steps to enable it. **Do not skip step 3** — the server defaults to
disabled and you will loop endlessly if you only reload the window.

1. Run `dart pub get` in the `log_pilot_mcp/` directory (once).
2. Create `.cursor/mcp.json` in the project root:
   ```json
   {
     "mcpServers": {
       "LogPilot": {
         "command": "dart",
         "args": ["run", "/absolute/path/to/log_pilot/log_pilot_mcp/bin/log_pilot_mcp.dart"]
       }
     }
   }
   ```
3. **Ask the developer** to:
   - Press `Ctrl+Shift+P` → "Developer: Reload Window"
   - Open **Cursor Settings → MCP**
   - **Toggle the LogPilot server ON** (it defaults to disabled)
   - Verify the green dot appears

The server auto-discovers the running app's VM service URI from
`.dart_tool/log_pilot_vm_service_uri` — no manual URI needed. It reconnects
automatically on hot restart and full restart.

### Rules for Agents

- Always pass `error` + `stackTrace` to error/fatal calls.
- Use `tag:` for every domain (`Auth`, `Cart`, `API`, `DB`, `Nav`, etc.).
- Prefer `metadata:` maps over string interpolation.
- Use `LogPilot.create('Tag')` in classes for automatic tagging.
- Never silence errors with empty catch blocks — log them.

Copy this block into `.cursor/rules/`, `AGENTS.md`, `GEMINI.md`, or
`CLAUDE.md` for correct agent behavior in your project.

---

## Table of Contents

- [For AI Agents](#for-ai-agents)
- [MCP Server](#mcp-server)
- [DevTools Extension](#devtools-extension)
- [In-App Log Viewer](#in-app-log-viewer)
- [LLM Export](#llm-export)
- [Quick Start](#quick-start)
- [Console Output](#console-output)
- [Log Messages](#log-messages)
- [JSON Pretty-Printing](#json-pretty-printing)
- [Scoped Instance Loggers](#scoped-instance-loggers)
- [Network Logging](#network-logging)
- [Log Sinks](#log-sinks)
- [File Logging](#file-logging)
- [Config Presets](#config-presets)
- [Tagged Logging & Focus Mode](#tagged-logging--focus-mode)
- [Rate Limiting / Deduplication](#rate-limiting--deduplication)
- [Log History / Ring Buffer](#log-history--ring-buffer)
- [Session & Trace IDs](#session--trace-ids)
- [Navigation Logging](#navigation-logging)
- [BLoC Observer](#bloc-observer)
- [Performance Timing](#performance-timing)
- [Error Breadcrumbs](#error-breadcrumbs)
- [Error IDs](#error-ids)
- [Sensitive Field Masking](#sensitive-field-masking)
- [Error Silencing](#error-silencing)
- [Runtime Log-Level Override](#runtime-log-level-override)
- [Lazy Message Evaluation](#lazy-message-evaluation)
- [Instrumentation Helpers](#instrumentation-helpers)
- [Self-Diagnostics](#self-diagnostics)
- [Crash Reporter Integration](#crash-reporter-integration)
- [Diagnostic Snapshot](#diagnostic-snapshot)
- [Web Platform](#web-platform)
- [Testing](#testing)
- [Configuration Reference](#configuration-reference)
- [Package Imports](#package-imports)
- [Example App](#example-app)
- [Contributing](#contributing)
- [License](#license)

---

## MCP Server

The `log_pilot_mcp` package is a standalone MCP server that gives AI coding
agents live, bidirectional access to your running Flutter app's logs. No
terminal scraping — the agent calls structured tools over the Model Context
Protocol.

### How It Works

```
┌──────────────┐     ext.LogPilot.*     ┌─────────────────┐
│  Flutter App  │◄── VM Service ──────►│  log_pilot_mcp     │
│  (debug mode) │    extensions       │  (MCP server)    │
└──────┬───────┘                      └────────┬────────┘
       │                                       │ MCP protocol
       │ writes URI on start                   │
       ▼                                       │
  .dart_tool/                         ┌────────▼────────┐
  log_pilot_vm_service_uri              │  Cursor / Claude  │
       │                              │  / Windsurf / ... │
       └── watched by MCP server ─────└─────────────────┘
```

1. When your Flutter app starts in debug mode, `LogPilot.init()` registers
   `ext.LogPilot.*` service extensions on the Dart VM and writes the VM
   service URI to `.dart_tool/log_pilot_vm_service_uri`.
2. The MCP server watches that file, auto-discovers the URI, and connects.
3. AI agents call MCP tools (`get_snapshot`, `query_logs`, etc.) which the
   server translates into service extension calls on the running app.
4. On hot restart, the VM extensions re-register and the server
   auto-reconnects. On full restart, the URI file updates and the server
   reconnects within seconds — no manual action needed.

### Setup (Step-by-Step)

**Step 1 — Install MCP server dependencies** (once):

```bash
cd path/to/log_pilot/log_pilot_mcp
dart pub get
```

**Step 2 — Create `.cursor/mcp.json`** in your **app's project root**:

```json
{
  "mcpServers": {
    "LogPilot": {
      "command": "dart",
      "args": ["run", "/absolute/path/to/log_pilot/log_pilot_mcp/bin/log_pilot_mcp.dart"]
    }
  }
}
```

Use the **absolute path** to the script — Cursor does not reliably honor
`cwd` for project-level MCP servers.

**Step 3 — Reload and enable:**

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Run **"Developer: Reload Window"**
3. Open **Cursor Settings → MCP**
4. Find `LogPilot` in the list and **toggle it ON**
5. Verify it shows a green dot (connected)

> **Important:** After creating `mcp.json`, the server appears **disabled
> by default**. You must manually enable the toggle in Cursor Settings →
> MCP. Skipping this step causes agents to loop endlessly reloading the
> IDE trying to find the server.

**Step 4 — Start your Flutter app** in debug mode:

```bash
flutter run
```

LogPilot writes the VM service URI automatically. The MCP server picks it up
and connects. Verify by asking your agent to call `get_snapshot`.

### Auto-Discovery

LogPilot writes the Dart VM WebSocket URI to
`.dart_tool/log_pilot_vm_service_uri` every time your app starts in debug
mode. The MCP server:

- Reads the file on startup
- Watches for changes (file system watcher)
- If the file doesn't exist yet (server started before app), waits for it
  to appear
- On hot restart: isolate recycles, extensions re-register, server detects
  the isolate event and re-resolves on the next tool call
- On full restart: URI changes, file updates, server detects the change and
  reconnects within the watch interval

**No manual URI copying is needed** in the normal workflow. The only time
you need to pass `--vm-service-uri` manually is when auto-discovery fails
(e.g., the `.dart_tool` folder is not in the expected location).

### What Agents Can Do

| Tool | What it does |
|------|--------------|
| `get_snapshot` | Structured summary: session ID, config, history counts, recent errors, active timers. Supports `group_by_tag` for per-tag breakdown. |
| `query_logs` | Filter by level, tag, limit. `deduplicate: true` collapses repeated entries while preserving different call sites. |
| `export_logs` | Full history as human-readable text or NDJSON. |
| `export_for_llm` | Compressed summary optimized for LLM context windows — prioritizes errors, deduplicates, truncates verbose entries. |
| `set_log_level` / `get_log_level` | Change or read verbosity at runtime. Crank to `verbose` for debugging, back to `warning` when done. |
| `clear_logs` | Wipe in-memory history. |
| `watch_logs` | Stream new entries as MCP push notifications. Filter by tag and level. |
| `stop_watch` | Stop the watcher and get a delivery summary. |

| Resource | Contents |
|----------|----------|
| `LogPilot://config` | Current LogPilotConfig as JSON |
| `LogPilot://session` | Session ID and active trace ID |
| `LogPilot://tail` | Latest batch from the active watcher (subscribable) |

### Agent Debugging Workflow

1. `get_snapshot` — see what's happening (errors, config, timers)
2. `set_log_level(level: "verbose")` — increase detail
3. *Reproduce the issue*
4. `query_logs(level: "error", deduplicate: true)` — find the root cause
5. `export_for_llm(token_budget: 2000)` — get compressed context for analysis
6. `set_log_level(level: "warning")` — restore quiet mode

### Claude Code / Terminal Usage

```bash
cd path/to/log_pilot/log_pilot_mcp
dart run log_pilot_mcp --vm-service-uri=ws://127.0.0.1:PORT/TOKEN=/ws
```

Or use the `log_pilot_VM_SERVICE_URI` environment variable.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| Server shows "Disabled" in Cursor Settings → MCP | Toggle the switch **ON** manually. New servers default to disabled. |
| Server not appearing in MCP settings | Reload the Cursor window after creating/editing `mcp.json`. |
| `Could not find package "log_pilot_mcp"` | Use the absolute path to `log_pilot_mcp/bin/log_pilot_mcp.dart`, not `dart run log_pilot_mcp`. |
| `Failed to connect to VM service` | App isn't running in debug mode, or the URI is stale. Start the app first. |
| Tools fail after hot restart | Auto-recovers on the next call. If it persists, the VM port changed (full restart) — the URI file watcher handles this. |
| Server connects but tools return errors | The app must `import 'package:log_pilot/log_pilot.dart'` so the library is loaded. |

For the complete reference (manual URI, platform examples, `watch_logs`
parameters, `get_snapshot` parameters), see
[`log_pilot_mcp/README.md`](log_pilot_mcp/README.md).

---

## DevTools Extension

![DevTools Extension](screenshots/devtools_extension.png)

**Zero configuration** — add `log_pilot` as a dependency and a **LogPilot** tab
appears in Dart DevTools automatically.

- Real-time log table with color-coded level badges, tags, timestamps, and caller locations
- **Level filter** dropdown + **tag filter** dropdown + free-text search
- Auto-scroll with manual override
- **Toolbar**: Refresh, Clear, Set log level, Export (text/JSON), Snapshot
- **Detail view**: full message, metadata JSON tree, error + stack trace, error ID, breadcrumb timeline with copy-to-clipboard
- Works on all platforms including Flutter Web (uses VM service extensions, not expression evaluation)

| Filtered by Level + Tag | Detail with Metadata & Breadcrumbs |
|:-:|:-:|
| ![DevTools Table](screenshots/devtools_table.png) | ![DevTools Detail](screenshots/devtools_detail.png) |

---

## In-App Log Viewer

![In-App Log Viewer](screenshots/overlay_demo.gif)

```dart
MaterialApp(
  builder: (context, child) => LogPilotOverlay(child: child!),
  home: const MyHome(),
)
```

A **draggable, resizable bottom sheet** with full debug capabilities:

- Snap points at 25%, 50%, 75%, and full-screen
- **Level filter chips** (ALL, VERBOSE, DEBUG, INFO, WARNING, ERROR, FATAL)
- **Tag filter chips** — dynamically generated from logged records
- Text search across messages, tags, and levels
- **Record detail view** — tap any entry for full metadata, error, stack trace,
  breadcrumbs, caller, session/trace/error IDs, with copy-to-clipboard
- Auto-scroll toggle
- Copy full history as text or NDJSON
- Clear history button

Auto-hides in production. Override with `LogPilotOverlay(enabled: true)`.
Control FAB position: `LogPilotOverlay(entryButtonAlignment: Alignment.bottomLeft)`.

| Overlay List View | Record Detail View |
|:-:|:-:|
| ![Overlay List](screenshots/overlay_list.png) | ![Overlay Detail](screenshots/overlay_detail.png) |

---

## LLM Export

Compress log history to fit within an LLM's context window:

```dart
final summary = LogPilot.exportForLLM(tokenBudget: 2000);
```

The algorithm prioritizes errors, deduplicates consecutive identical
messages, truncates verbose entries, and fills remaining budget with the
most recent records. Default budget is 4000 tokens (~16k chars).

Also available via MCP: the `export_for_llm` tool accepts a `token_budget`
parameter and returns the compressed summary directly to the agent.

---

## Quick Start

### Install

```yaml
dependencies:
  log_pilot: ^0.15.2
```

### Pick Your Setup Level

**Full setup** — error zones + logging (recommended):

```dart
import 'package:flutter/material.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  LogPilot.init(child: const MyApp());
}
```

`LogPilot.init()` replaces `runApp()` and auto-catches every Flutter error,
platform error, and uncaught zone exception.

**Config only** — you call `runApp()` yourself:

```dart
void main() {
  LogPilot.configure(config: LogPilotConfig(logLevel: LogLevel.info));
  runApp(const MyApp());
}
```

**Zero setup** — works immediately with sensible defaults:

```dart
LogPilot.info('Hello world'); // no init needed in debug mode
```

---

## Console Output

LogPilot wraps every log in a box-bordered block with level, timestamp,
clickable caller location, and your message:

![Console Output — Pretty Format](screenshots/console_pretty.png)

Three output modes are available:

| Mode | Use case | Example |
|------|----------|---------|
| `OutputFormat.pretty` | Human in IDE (default) | Box-bordered, colorized |
| `OutputFormat.plain` | AI agents / CI | `[INFO] [auth] User signed in \| {"userId": "123"}` |
| `OutputFormat.json` | Structured pipelines | `{"level":"INFO","timestamp":"...","message":"..."}` |

| Pretty | Plain | NDJSON |
|:-:|:-:|:-:|
| ![Pretty](screenshots/output_formats_pretty.png) | ![Plain](screenshots/output_formats_plain.png) | ![NDJSON](screenshots/output_formats_NDJSON.png) |

---

## Log Messages

Every method supports optional `error`, `stackTrace`, `metadata`, and `tag`:

```dart
LogPilot.verbose('Starting sync...');
LogPilot.debug('Cache key: user_42');
LogPilot.info('Order placed', metadata: {'orderId': 'ORD-456', 'total': 29.99});
LogPilot.warning('Retry attempt 3/5');
LogPilot.error('Checkout failed', error: e, stackTrace: st);
LogPilot.fatal('Database corrupted');
```

| Verbose | Info + Metadata |
|:-:|:-:|
| ![Verbose](screenshots/log_levels_verbose.png) | ![Info](screenshots/log_levels_info_metadata.png) |

| Error + Stack Trace + Breadcrumbs | Fatal |
|:-:|:-:|
| ![Error](screenshots/log_levels_error_stack_trace.png) | ![Fatal](screenshots/log_levels_fatal.png) |

---

## JSON Pretty-Printing

```dart
LogPilot.json('{"users": [{"id": 1, "name": "Alice"}]}');
```

Keys and values render in different colors. Customize with `jsonKeyColor`
and `jsonValueColor` in the config.

![JSON Highlighting](screenshots/json_highlight.png)

---

## Scoped Instance Loggers

Create a `LogPilotLogger` for class-level logging — every log is automatically
tagged:

```dart
class AuthService {
  static final _log = LogPilot.create('AuthService');

  Future<void> signIn(String email) async {
    _log.info('Attempting sign in', metadata: {'email': email});
    try {
      await _auth.signIn(email);
      _log.info('Sign in successful');
    } catch (e, st) {
      _log.error('Sign in failed', error: e, stackTrace: st);
    }
  }
}
```

Scoped loggers also prefix timer labels: `_log.time('query')` produces `AuthService/query`.

---

## Network Logging

The **http** interceptor is built into the published package:

```dart
import 'package:log_pilot/log_pilot.dart';

final client = LogPilotHttpClient();
final response = await client.get(Uri.parse('https://api.example.com/users'));
```

![Network Logging](screenshots/network_logging.png)

Response log levels are set by HTTP status code: 5xx -> `error`, 4xx -> `warning`, 2xx/3xx -> `info`.

```dart
LogPilotHttpClient(
  logRequestHeaders: true,
  logRequestBody: true,
  logResponseHeaders: false,
  logResponseBody: true,        // opt-in (default: false)
  maxResponseBodySize: 4 * 1024, // truncate after 4 KB
  injectSessionHeader: true,     // adds X-LogPilot-Session / X-LogPilot-Trace
  createRecords: true,           // creates LogPilotRecord entries in history
)
```

Override level per status code:

```dart
LogPilotHttpClient(
  logLevelForStatus: (status) =>
      status == 429 ? LogLevel.error : LogPilotHttpClient.defaultLogLevelForStatus(status),
)
```

Query network errors from history:

```dart
final httpErrors = LogPilot.historyWhere(tag: 'http', hasError: true);
```

> **Dio, Chopper, GraphQL, and BLoC integrations** are available in the
> [source repo](https://github.com/MojtabaTavakkoli/log_pilot) but are **not
> included in the published package** yet. They will ship as separate
> packages in a future release. In the meantime you can copy the source file
> from the repo into your project.

---

## Log Sinks

Route log records to any destination alongside console output:

```dart
LogPilot.init(
  config: LogPilotConfig(
    sinks: [
      CallbackSink((record) {
        FirebaseCrashlytics.instance.log(record.message ?? '');
      }),
    ],
  ),
  child: const MyApp(),
);
```

Sinks fire **even when console output is off** (`enabled: false`), making
them ideal for production. Implement `LogSink` for custom sinks:

```dart
class RemoteSink implements LogSink {
  @override
  void onLog(LogPilotRecord record) {
    httpClient.post(apiUrl, body: record.toJsonString());
  }

  @override
  void dispose() {}
}
```

### Choosing the Right Sink

| Sink | Delivery | Best for |
|------|----------|----------|
| `CallbackSink` | Synchronous, per-record | Fire-and-forget: crash reporters, analytics |
| `AsyncLogSink` | Microtask-batched | Expensive I/O: HTTP uploads, file writes |
| `BufferedCallbackSink` | Timer + size-based batches | UI state — avoids `setState`-during-`build` |

```dart
// Microtask-batched
AsyncLogSink(flush: (records) {
  for (final r in records) { analyticsService.track(r.message ?? ''); }
})

// Timer + size-based
BufferedCallbackSink(
  maxBatchSize: 50,
  flushInterval: Duration(milliseconds: 500),
  onFlush: (batch) { setState(() => logRecords.addAll(batch)); },
)
```

Each sink's `onLog` is wrapped in a try-catch — a broken sink cannot silence the pipeline.

---

## File Logging

`FileSink` writes to local files with automatic rotation. **Mobile/desktop
only** (requires `dart:io`):

```dart
import 'dart:io';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/log_pilot_io.dart';

LogPilot.init(
  config: LogPilotConfig(
    sinks: [
      FileSink(
        directory: Directory('/path/to/logs'),
        maxFileSize: 2 * 1024 * 1024,  // 2 MB per file
        maxFileCount: 5,
        format: FileLogFormat.text,     // or .json for NDJSON
        baseFileName: 'LogPilot',
      ),
    ],
  ),
  child: const MyApp(),
);

// Export all logs for bug reports:
final allLogs = await fileSink.readAll();
Share.share(allLogs);
```

---

## Config Presets

```dart
LogPilotConfig.debug()       // verbose, all details, colors on
LogPilotConfig.staging()     // info+, compact, 5s dedup window
LogPilotConfig.production(   // console off, warning+, sinks only
  sinks: [myCrashlyticsSink],
)
LogPilotConfig.web()         // info+, plain output, no caller capture, 5s dedup
```

| Factory | Log Level | Caller | Details | Dedup | Best for |
|---------|-----------|:------:|:-------:|-------|----------|
| `LogPilotConfig()` | verbose | Yes | Yes | off | Default |
| `.debug()` | verbose | Yes | Yes | off | IDE development |
| `.staging()` | info | Yes | No | 5s | QA builds |
| `.production()` | warning | No | No | 5s | Release (console off) |
| `.web()` | info | No | No | 5s | Flutter Web |

---

## Tagged Logging & Focus Mode

```dart
LogPilot.info('Starting payment', tag: 'checkout');

// Only show specific tags during development:
LogPilotConfig(onlyTags: {'checkout', 'auth'})
```

---

## Rate Limiting / Deduplication

Collapse identical messages within a time window:

```dart
LogPilotConfig(deduplicateWindow: Duration(seconds: 5))
```

When the same message + level repeats, only the first is printed. After
the window, a summary appears:

```
│ RenderFlex overflowed by 42.0 pixels
│ ... repeated 47 times
```

Deduplication applies to both console output and sink dispatch. The
in-memory history still receives every record.

---

## Log History / Ring Buffer

```dart
final records = LogPilot.history;
final errors  = LogPilot.historyWhere(level: LogLevel.error);
final text    = LogPilot.export();
final json    = LogPilot.export(format: ExportFormat.json);

LogPilot.clearHistory();
```

`historyWhere` supports rich filtering — all parameters combine with AND logic:

```dart
LogPilot.historyWhere(
  level: LogLevel.warning,
  tag: 'http',
  messageContains: 'timeout',
  traceId: 'req-abc',
  hasError: true,
  after: DateTime.now().subtract(const Duration(minutes: 5)),
  before: DateTime.now(),
  metadataKey: 'statusCode',
);
```

Configure the buffer size (default 500, set to 0 to disable):

```dart
LogPilotConfig(maxHistorySize: 1000)
```

---

## Session & Trace IDs

Every app launch gets a unique session UUID:

```dart
print(LogPilot.sessionId); // "a1b2c3d4-e5f6-4a7b-..."
```

For per-request correlation, use the scoped helper:

```dart
await LogPilot.withTraceId('req-12345', () async {
  await processPayment();   // all logs carry traceId 'req-12345'
  await sendReceipt();
});
// traceId is null here — even if processPayment threw
```

A synchronous variant is also available:

```dart
final total = LogPilot.withTraceIdSync('calc-1', () => computeTotal(cart));
```

Network interceptors automatically inject `X-LogPilot-Session` and
`X-LogPilot-Trace` headers.

---

## Navigation Logging

Auto-log every route transition:

```dart
MaterialApp(
  navigatorObservers: [LogPilotNavigatorObserver()],
)
```

Customize:

```dart
LogPilotNavigatorObserver(
  logLevel: LogLevel.info,
  tag: 'Nav',
  logArguments: false, // hide sensitive route arguments
)
```

---

## BLoC Observer

Log BLoC/Cubit lifecycle events:

```dart
import 'package:log_pilot/log_pilot_bloc.dart';

void main() {
  Bloc.observer = LogPilotBlocObserver();
  LogPilot.init(child: const MyApp());
}
```

Customize:

```dart
LogPilotBlocObserver(
  tag: 'state',
  logEvents: true,
  logTransitions: true,
  logCreations: false,
  transitionLevel: LogLevel.debug,
)
```

---

## Performance Timing

```dart
LogPilot.time('fetchUsers');
final users = await api.fetchUsers();
LogPilot.timeEnd('fetchUsers');  // logs: "fetchUsers: 342ms"
```

Exception-safe scoped timing:

```dart
final users = await LogPilot.withTimer('fetchUsers', work: () => api.getUsers());
final config = LogPilot.withTimerSync('parseConfig', work: () => parse(raw));
```

Multiple timers run concurrently. Scoped loggers prefix automatically:

```dart
final log = LogPilot.create('DB');
log.time('query');      // label: "DB/query"
log.timeEnd('query');   // logs: "DB/query: 12ms" with tag "DB"
```

`timeCancel` removes a timer without logging.

---

## Error Breadcrumbs

Automatic trail of events before each error:

```dart
LogPilot.info('User tapped checkout', tag: 'UI');
LogPilot.info('Cart validated', tag: 'Cart');
LogPilot.error('Payment failed', error: e, stackTrace: st);
// ↑ Breadcrumbs for the 2 prior events are attached
```

Manual breadcrumbs:

```dart
LogPilot.addBreadcrumb('Button tapped', category: 'ui');
LogPilot.addBreadcrumb('Theme changed', category: 'state', metadata: {'theme': 'dark'});
```

Configure: `LogPilotConfig(maxBreadcrumbs: 30)` (default 20, 0 to disable).

---

## Error IDs

Each error/fatal log receives a deterministic hash-based ID:

```dart
LogPilot.error('Network timeout', error: TimeoutException('connect'));
// Record includes: errorId: "lk-a1b2c3"
```

The same error signature always produces the same ID across sessions.
Numeric variations are normalized — "index 5 out of range 10" and
"index 3 out of range 8" produce the same ID.

---

## Sensitive Field Masking

```dart
LogPilotConfig(
  maskPatterns: [
    'password',              // substring — masks any key containing "password"
    '=accessToken',          // exact — masks only the key "accessToken"
    '~^(refresh|auth)_.*',   // regex — matches keys via RegExp
    'Authorization',
    'secret',
  ],
)
```

| Prefix | Match type | Example | Masks |
|--------|-----------|---------|-------|
| *(none)* | Substring | `'token'` | `accessToken`, `tokenExpiry`, `refresh_token` |
| `=` | Exact key | `'=accessToken'` | `accessToken` only |
| `~` | Regex | `'~^api_key$'` | `api_key` only |

Recursive masking applies to both headers and nested JSON bodies.

---

## Error Silencing

Suppress known, noisy errors from console — crash reporters still receive them:

```dart
LogPilotConfig(silencedErrors: {'RenderFlex overflowed', 'HTTP 404'})
```

---

## Runtime Log-Level Override

Change verbosity without code edits or restart:

```dart
LogPilot.setLogLevel(LogLevel.verbose); // crank up for debugging
// ... reproduce the issue ...
LogPilot.setLogLevel(LogLevel.warning); // quiet down
```

---

## Lazy Message Evaluation

```dart
LogPilot.debug(() => 'Cache: ${cache.entries.map((e) => e.key).join(", ")}');
```

The closure is only called if debug level is active.

---

## Instrumentation Helpers

Wrap any expression with automatic timing, result logging, and error capture:

```dart
final config = LogPilot.instrument('parseConfig', () => parseConfig(raw));
final users = await LogPilot.instrumentAsync('fetchUsers', () => api.getUsers());
```

On success: logs at `debug` level with return value and elapsed time.
On failure: logs at `error` level with exception and stack trace, then rethrows.

---

## Self-Diagnostics

Monitor LogPilot's own performance and automatically degrade verbosity
when throughput spikes:

```dart
LogPilot.enableDiagnostics(
  autoDegrade: true,
  throughputThreshold: 50, // records per second before degrading
);

final snap = LogPilot.diagnostics?.snapshot;
// LogPilotDiagnosticsSnapshot(records: 142, avgSinkLatency: 34us, ...)

LogPilot.disableDiagnostics();
```

When throughput exceeds the threshold, the log level is automatically
raised to `warning`. When throughput drops below half the threshold,
the original level is restored.

---

## Crash Reporter Integration

```dart
LogPilot.init(
  onError: (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack);
  },
  child: const MyApp(),
);
```

---

## Diagnostic Snapshot

One-call structured summary of recent LogPilot activity:

```dart
final snap = LogPilot.snapshot();
// Returns Map with: sessionId, traceId, config, history counts,
// recentErrors (last 5), recentLogs (last 10), activeTimers

final jsonStr = LogPilot.snapshotAsJson();
```

Group recent logs by tag:

```dart
final snap = LogPilot.snapshot(groupByTag: true, perTagLimit: 3);
// snap['recentByTag']['Auth'] -> {total: 15, recent: [...last 3...]}
```

---

## Web Platform

The core `package:log_pilot/log_pilot.dart` is fully web-compatible — zero `dart:io`
dependency. All features work on Flutter Web:

- Console output, log history, navigation observer, BLoC observer, timing
- In-app log viewer overlay
- Network logging with `LogPilotHttpClient`
- DevTools extension

File logging requires `dart:io` — import `package:log_pilot/log_pilot_io.dart`
for mobile/desktop only. Use `LogPilotConfig.web()` for optimized web defaults.

---

## Testing

```dart
tearDown(() {
  LogPilot.reset(); // clears config, history, timers, and trace IDs
});
```

---

## Configuration Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | `bool` | `kDebugMode` | Master switch. Off in release. |
| `logLevel` | `LogLevel` | `verbose` | Minimum severity to print. |
| `outputFormat` | `OutputFormat` | `pretty` | `pretty` / `plain` / `json` |
| `showTimestamp` | `bool` | `true` | Show HH:mm:ss.SSS |
| `showCaller` | `bool` | `true` | Clickable source location |
| `showDetails` | `bool` | `true` | Error body, stack traces |
| `colorize` | `bool` | `true` | ANSI colors |
| `maxLineWidth` | `int` | `100` | Box width in characters |
| `stackTraceDepth` | `int` | `8` | Max stack frames shown |
| `maxPayloadSize` | `int` | `10240` | Truncate payloads (bytes) |
| `maskPatterns` | `List<String>` | `['Authorization', 'password', 'token', 'secret']` | Fields to mask (`=exact`, `~regex`, or substring) |
| `jsonKeyColor` | `AnsiColor` | `cyan` | JSON key color |
| `jsonValueColor` | `AnsiColor` | `green` | JSON value color |
| `silencedErrors` | `Set<String>` | `{}` | Suppress matching errors |
| `onlyTags` | `Set<String>` | `{}` | Only print matching tags |
| `sinks` | `List<LogSink>` | `[]` | Additional output destinations |
| `deduplicateWindow` | `Duration` | `Duration.zero` | Collapse identical messages (console + sinks) |
| `maxHistorySize` | `int` | `500` | Ring buffer size (0 = off) |
| `maxBreadcrumbs` | `int` | `20` | Breadcrumb buffer (0 = off) |

---

## Package Imports

| Import | What you get | Web safe? | Published? |
|--------|--------------|:---------:|:----------:|
| `package:log_pilot/log_pilot.dart` | Core: `LogPilot`, `LogPilotLogger`, `LogPilotConfig`, `LogPilotRecord`, `LogLevel`, `LogSink`, `CallbackSink`, `AsyncLogSink`, `BufferedCallbackSink`, `LogHistory`, `ExportFormat`, `LogPilotNavigatorObserver`, `LogPilotOverlay`, `LogPilotHttpClient`, ANSI helpers | Yes | Yes |
| `package:log_pilot/log_pilot_io.dart` | `FileSink`, `FileLogFormat` (requires `dart:io`) | No | Yes |
| `package:log_pilot/log_pilot_dio.dart` | `LogPilotDioInterceptor` (add `dio` to pubspec) | Yes | Repo only* |
| `package:log_pilot/log_pilot_chopper.dart` | `LogPilotChopperInterceptor` (add `chopper`) | Yes | Repo only* |
| `package:log_pilot/log_pilot_graphql.dart` | `LogPilotGraphQLLink` (add `gql`, `gql_exec`, `gql_link`) | Yes | Repo only* |
| `package:log_pilot/log_pilot_bloc.dart` | `LogPilotBlocObserver` (add `bloc`) | Yes | Repo only* |

> \* These barrels are in the source repo but excluded from the published
> package. They will ship as separate packages (e.g. `log_pilot_dio`) in a
> future release.

---

## Example App

A full runnable example with tappable buttons for every feature lives in
[`example/`](example/):

```bash
cd example && flutter run
```

![Example App](screenshots/example_app.png)

---

## Features at a Glance

| Feature | What it does |
|---------|--------------|
| **MCP server** | AI agents query, filter, watch, and control live logs via MCP protocol |
| **DevTools extension** | Real-time log viewer tab inside Dart DevTools — zero config |
| **In-app log viewer** | `LogPilotOverlay` debug sheet with filters, search, and live updates |
| **LLM export** | Compress log history for AI context windows |
| **One-line setup** | Replace `runApp()` with `LogPilot.init()` — every error is auto-formatted |
| **Pretty Flutter errors** | 15+ contextual hints, simplified stacks, clickable source locations |
| **Level-based logging** | `verbose` / `debug` / `info` / `warning` / `error` / `fatal` with structured metadata and tags |
| **Scoped loggers** | `LogPilot.create('AuthService')` for class-level auto-tagging |
| **Log sinks** | Route records to files, Crashlytics, Sentry, or any backend |
| **Built-in file logging** | `FileSink` with automatic rotation by size, text or JSON format |
| **Lazy messages** | `LogPilot.debug(() => expensiveString())` — skips work when filtered |
| **Network interceptors** | http (published); Dio, Chopper, GraphQL (repo / future packages) |
| **JSON highlighting** | Auto-detect and colorize keys/values |
| **Sensitive field masking** | Recursive masking in headers and JSON bodies |
| **Config presets** | `LogPilotConfig.debug()`, `.staging()`, `.production()`, `.web()` |
| **Rate limiting / dedup** | Collapse identical messages within a time window |
| **Log history** | In-memory ring buffer — filter, export, attach to bug reports |
| **Output formats** | `pretty`, `plain`, `json` — human and machine modes |
| **Diagnostic snapshot** | `LogPilot.snapshot()` — one-call summary for bug reports |
| **Error breadcrumbs** | Automatic trail of events before each error |
| **Error IDs** | Deterministic `lk-XXXXXX` hash for cross-session tracking |
| **Runtime log-level override** | Change verbosity at runtime without restart |
| **Instrumentation helpers** | One-line timing + error capture for any expression |
| **Session & trace IDs** | Auto-generated session UUID + per-request trace IDs |
| **Navigation logging** | Auto-logs push/pop/replace with route names & arguments |
| **BLoC observer** | Logs create/close, events, state changes, and errors |
| **Performance timing** | `LogPilot.time` / `LogPilot.timeEnd` — like `console.time` |
| **Web compatible** | Core barrel is `dart:io`-free — works on Flutter Web |
| **Lightweight core** | Optional deps (Dio, Chopper, GraphQL, BLoC) — add only what you use |

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for
architecture details and development setup.

## License

MIT — see [LICENSE](LICENSE).

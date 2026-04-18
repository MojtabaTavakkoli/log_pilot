## 1.0.0

First stable release graduation.

### Added
- **Option A/B/C Setup**: Reorganized the "Quick Start" documentation with clear setup levels and decision tables to prevent double-initialization bugs.
- **Enhanced Example**: Updated the demo app with broader AI agent audience metadata and clearer setup comments.

### Changed
- **IDE-Agnostic MCP Setup**: Transitioned all MCP server instructions from Cursor-only to a universal multi-IDE configuration (supports VS Code/Copilot, Windsurf, Claude Code, Antigravity, etc.).
- **Flutter Web Clarity**: Updated the Web documentation to explicitly state auto-discovery limitations and mark capture scripts as optional/experimental fallback.

### Fixed
- Fixed setup instruction bias that previously prioritized absolute paths and IDE-specific reload shortcuts.

---

## 1.0.0-beta.1

First beta toward the stable 1.0 release.

### Changed
- Version bumped to `1.0.0-beta.1` across `pubspec.yaml`, DevTools
  extension config, and README.

### Docs
- **CONTRIBUTING.md:** Added release/beta branching strategy with naming
  conventions and dev-branch workflow.

---

## 0.15.5

### Fixed: Service Extension Re-Registration in Tests
- `LogPilot.reset()` no longer resets the `_extensionsRegistered` flag.
  Dart VM service extensions persist for the VM lifetime and cannot be
  unregistered — resetting the flag caused "Extension already registered"
  errors in test suites that call `configure()`/`reset()` across multiple
  tests in the same file.

### Docs: README Cleanup
- Added "Features at a Glance" and "Migrating from plog" to the Table of
  Contents — previously missing, making both sections hard to discover.
- Fixed Web Platform section listing BLoC observer without qualifying it as
  repo-only — now includes a cross-reference to Package Imports.
- Fixed self-diagnostics description: "raised to warning" now explicitly says
  "reducing verbosity" to avoid misreading "raised" as "more verbose."
- Fixed Step 4 wording: "both steps" → "all three steps" to match the actual
  checklist count.
- Fixed MCP architecture diagram alignment.
- Added horizontal rule between Contributing and License sections.

---

## 0.15.4

### Changed: MCP Server Extracted to Standalone Package
- The `log_pilot_mcp` MCP server is now a **standalone package** published
  separately at [`log_pilot_mcp`](https://github.com/MojtabaTavakkoli/log_pilot_mcp).
- **New setup:** `dart pub add --dev log_pilot_mcp` — no cloning, no absolute
  paths, no Flutter dependency. The MCP server is a pure Dart CLI tool.
- Updated all documentation (README, CONTRIBUTING, agent setup sections) to
  reference the standalone package instead of the repo subfolder.
- The legacy `log_pilot_mcp/` subfolder has been removed from this repo.

### Fixed: Uncaught `AssertionError` Zone Level
- Uncaught `AssertionError` exceptions in the error zone are now logged at
  `error` level instead of `warning`. These are genuine uncaught exceptions
  (e.g. Flutter's `RenderBox` layout assertions) and the previous `warning`
  severity was understated.

### Docs: Prominent Warnings for Repo-Only Imports
- Added visible callout banners to the BLoC Observer and Network Logging
  sections warning that `log_pilot_bloc.dart`, `log_pilot_dio.dart`,
  `log_pilot_chopper.dart`, and `log_pilot_graphql.dart` are **not included**
  in the pub.dev package. Previously only a footnote in the Package Imports
  table mentioned this — users following the README hit compile errors.
- Documented `const LogPilotLogger('Tag')` as the compile-time constant
  alternative to `LogPilot.create('Tag')` in the Scoped Loggers section.

### Improved: `query_logs` MCP Tool — Rich Filtering
- `query_logs` now exposes the full power of `LogPilot.historyWhere` via MCP:
  `message_contains`, `trace_id`, `has_error`, and `metadata_key` filters,
  in addition to the existing `level`, `tag`, `limit`, and `deduplicate`.
- All filters combine with AND logic.

### Added: Example App MCP Integration
- Added `log_pilot_mcp` as a dev dependency in the example app.
- Added `.cursor/mcp.json` to the example with a working auto-discovery config.
- Updated example README with MCP setup instructions.

### Docs: Simplified MCP Setup
- Human setup reduced from 5 steps to 4 — install with `dart pub add`.
- MCP config simplified to `["run", "log_pilot_mcp"]` — no absolute paths.
- Troubleshooting table updated with new installation guidance.

---

## 0.15.3

### Docs: MCP Setup Instructions Rewrite
- Added prominent callout in both READMEs stating that `log_pilot_mcp` is
  **not included** in the pub package and must be cloned from the GitHub
  repo separately.
- Added copy-pasteable `git clone` command and `dart pub get` steps to
  the "For AI Agents" section and the MCP server README.
- Replaced ambiguous `/absolute/path/to/log_pilot` placeholders with
  `<ABSOLUTE_PATH_TO_LOG_PILOT_REPO>` with platform-specific examples.
- Promoted `--vm-service-uri` from a troubleshooting footnote to a
  primary fallback path with copy-pasteable `mcp.json` examples.

### Fixed: VM Service URI Auto-Discovery on Windows
- `writeVmServiceUri()` now tries three strategies to locate `.dart_tool`:
  cwd walk, `Platform.script` parent walk, and `Platform.resolvedExecutable`
  parent walk. Previously only cwd was checked, which fails on Windows
  where IDEs often set cwd to the Flutter SDK or system directory.
- Walk depth increased from 6 to 9 parent directories.
- Failures now log a diagnostic `debugPrint` message instead of being
  silently swallowed, so developers can see why auto-discovery failed.

### Added: `--project-root` Flag for MCP Server
- The `log_pilot_mcp` server accepts a new `--project-root=PATH` argument
  to explicitly specify the Flutter app's project root. This lets the
  server locate `.dart_tool/log_pilot_vm_service_uri` when cwd-based
  auto-discovery fails.
- The server now logs the resolved URI file path and search directory to
  stderr for easier debugging.

---

## 0.15.2

### Fixed: pub.dev Package Score
- Shortened `pubspec.yaml` description to 121 characters (pub.dev requires
  60–180). Leads with "Flutter logging", "MCP server", "AI agents" for
  search discoverability.
- Used `>-` YAML scalar to prevent trailing newline that inflated the
  published description length.
- Aligned DevTools extension `config.yaml` version with the package version.

---

## 0.15.1

### Fixed: Package Rename Cleanup
- Fixed README banner image path (`banner.jpg` → `banner.png`).
- Added `screenshots/banner.png` as the first screenshot entry so it
  displays as the package image on pub.dev.
- Rebuilt DevTools extension (`extension/devtools/build/`) to fix
  "could not read file as String: index.html" error when opening DevTools.

---

## 0.15.0

### Fixed: In-App Overlay Record Detail View
- Tapping a log record in `LogPilotOverlay` now correctly opens the detail
  view. The previous implementation used `showModalBottomSheet` which
  silently failed because the overlay sits above the `Navigator` in
  `MaterialApp.builder`. Replaced with an inline state-based detail view
  that renders inside the existing sheet — no `Navigator` dependency.

### Fixed: DevTools Extension Service Extension Mismatch
- Rebuilt the pre-compiled DevTools extension. The stale JS build was
  calling `ext.plog.*` service extensions (old package name) instead of
  `ext.LogPilot.*`. The extension now correctly connects to the running app.

### Improved: README Rewrite with Screenshots
- Complete README rewrite: developer-first structure, table of contents,
  18 screenshots/GIFs, all 30+ features documented, AI agent section
  moved to end.
- Added `screenshots` field to `pubspec.yaml` for the pub.dev carousel.

### Improved: Publication Readiness
- Updated Flutter SDK constraint from `>=1.17.0` to `>=3.0.0` to match
  the Dart SDK `^3.9.2` requirement.
- Added `mcp` to pub.dev topics for AI/MCP discoverability.
- Updated package description to mention AI agent support, MCP server,
  and DevTools extension.
- Added `@immutable` annotations to `LogPilotConfig`, `LogPilotRecord`, and
  `Breadcrumb` for static analysis correctness.
- Strengthened `analysis_options.yaml` with `prefer_const_constructors`,
  `prefer_final_locals`, `unawaited_futures`, and other strict lint rules
  across all packages.
- Aligned DevTools extension `config.yaml` version with the package version.
- Updated `.gitignore` and `.pubignore` for cleaner publishing.
- Fixed example app widget tests for scroll-dependent sections.
- Replaced default Flutter template `example/README.md` with a feature
  overview matching all 24 demo sections.
- Updated `CONTRIBUTING.md` with current architecture, directory layout,
  and design decisions.
- Added GitHub Actions CI workflow for automated testing and analysis.

---

## 0.14.1

### Improved: CallbackSink Documentation
- Added prominent warning to `CallbackSink` docstring about the
  `setState`-during-`build` foot-gun. The docstring now shows the wrong
  pattern and the correct alternative (`BufferedCallbackSink`).

### New: Error Cascade Detection
- Zone error dispatch (`_dispatchErrorToSinks`) now detects cascading
  duplicate errors within a 500ms window. Only the first (root) error is
  recorded; subsequent identical errors are suppressed. When a cascade
  ends, a summary record reports how many duplicates were suppressed.
  This prevents log flooding during build-during-build crashes and
  similar cascading failures.

### Improved: VM Service URI Auto-Discovery
- The URI writer now searches up to 6 parent directories for `.dart_tool`
  instead of only checking the current working directory. This fixes
  auto-discovery failures when the app runs inside `runZonedGuarded` or
  when the working directory differs from the project root.

### New: `export_for_llm` MCP Tool
- Added `export_for_llm` tool to `log_pilot_mcp` server. Calls
  `LogPilot.exportForLLM()` with a configurable `token_budget` parameter.
  Returns a compressed summary optimized for LLM context windows —
  prioritizes errors, deduplicates repeated messages, truncates verbose
  entries. The MCP server now has 9 tools + 3 resources.

---

## 0.14.0

### New: Overlay — Record Detail View
- Tapping any log entry in the overlay opens a detailed bottom sheet
  showing all record fields: message, level, timestamp, tag, caller,
  metadata (pretty-printed JSON), error, stack trace, breadcrumbs,
  session ID, trace ID, and error ID.
- Each section supports copy-to-clipboard; a "Copy All" button exports
  the entire record as JSON.
- Records with detail (metadata, error, stack trace, etc.) show a
  chevron indicator in the log list.

### New: Overlay — Tag Filter Chips
- A second row of filter chips now appears below the level chips,
  dynamically generated from all tags present in the current log history.
- Tapping a tag chip filters the log list to show only records with
  that tag. "All Tags" resets the filter.
- Combined with level filters and search — all three work together.
- Tag chips are colored using a deterministic hash for consistency.

### New: Test Coverage for AsyncLogSink, BufferedCallbackSink, LogPilotZone.init, LogPilotHttpClient
- Added comprehensive unit tests for `AsyncLogSink` (5 tests): batching,
  microtask-boundary flush, dispose flush, and field integrity.
- Added comprehensive unit tests for `BufferedCallbackSink` (7 tests):
  size-triggered flush, timer-triggered flush, dispose, multiple cycles,
  timer reset, and default parameter validation.
- Added integration tests for `LogPilotZone.init` (14 tests): session ID,
  sink dispatch, error records, history, trace IDs, breadcrumbs, log
  level changes, clear/reset, FlutterError.onError dispatch, onError
  callback verification, and AsyncLogSink integration.
- Added `LogPilotHttpClient` tests: status-based log levels, `createRecords`
  flag, network record metadata, and history integration.

### Improved: Test Hygiene
- All test groups now call `LogPilot.reset()` in `tearDown` or `tearDownAll`
  to prevent global state leakage across test files.
- Clipboard mock handlers are cleaned up via `addTearDown`.

---

## 0.13.0

### New: `withTimer` / `withTimerSync` Scoped Timer Helpers
- `LogPilot.withTimer(label, work: () async { ... })` wraps async work with
  `time`/`timeEnd`, cancelling the timer on exception. The timer is
  visible in `snapshot().activeTimers` while running.
- `LogPilot.withTimerSync(label, work: () { ... })` — synchronous variant.
- Both are also available on `LogPilotLogger` instances (label auto-prefixed
  with the logger's tag).

### Changed: Overlay — Draggable/Resizable Sheet
- The debug overlay now uses `DraggableScrollableSheet` instead of a
  full-screen panel.
- Starts at 50% screen height, draggable from 25% to 100%.
- Snap points at 25%, 50%, 75%, and 100%.
- Visual drag handle at the top of the sheet.
- Tapping the backdrop (area above the sheet) dismisses it.
- API (`LogPilotOverlay` constructor) is unchanged — no breaking changes.

---

## 0.12.0

### New: Network Records in History / Sinks / Overlay
- All network interceptors (`LogPilotHttpClient`, `LogPilotDioInterceptor`,
  `LogPilotChopperInterceptor`, `LogPilotGraphQLLink`) now create a `LogPilotRecord`
  for each completed request. Network activity is now visible in
  history, sinks, overlay, export, `exportForLLM`, and MCP queries.
- Records are tagged `http` (or `graphql`) with structured metadata
  including `method`, `url`, `statusCode`, and `durationMs`.
- Errors dispatch an `error`-level record with the exception attached.
- Opt out per client with `createRecords: false`.

### New: Enhanced `historyWhere` Filters
- `LogPilot.historyWhere()` and `LogHistory.where()` now accept additional
  optional parameters, all combined with AND logic:
  - `messageContains` — case-insensitive substring search on message
  - `traceId` — exact trace ID match
  - `hasError` — filter by error presence (`true` / `false`)
  - `after` / `before` — timestamp window
  - `metadataKey` — only records whose metadata contains the given key
- Existing `level` and `tag` parameters are unchanged (backward compatible).

---

## 0.11.1

### Docs: Sink Type Guide (`AsyncLogSink` / `BufferedCallbackSink`)
- README now includes a "Choosing the Right Sink" comparison table
  explaining when to use `CallbackSink`, `AsyncLogSink`, and
  `BufferedCallbackSink`.
- Documents the `setState`-during-`build` footgun and why
  `BufferedCallbackSink` solves it (Timer-based flush lands outside
  the build cycle).
- AGENTS.md updated with a sink-type quick-reference table.

### New: Scoped Trace ID Helpers
- `LogPilot.withTraceId(traceId, () async { ... })` — sets the ambient trace
  ID before the callback and clears it in a `finally` block. Safe even
  when the callback throws.
- `LogPilot.withTraceIdSync(traceId, () { ... })` — synchronous variant for
  non-async work.
- Both methods are also available on `LogPilotLogger` instances.

### New: HTTP Status-Aware Log Levels
- Network interceptors now map HTTP status codes to log levels
  automatically: 5xx → `error`, 4xx → `warning`, 2xx/3xx → `info`.
- Applies to `LogPilotHttpClient`, `LogPilotDioInterceptor`, and
  `LogPilotChopperInterceptor`.
- Customizable via the new `logLevelForStatus` constructor parameter.
- `LogPilotHttpClient.defaultLogLevelForStatus` is a public static for
  reuse across interceptors.

### New: Regex and Exact-Match Masking Patterns
- `maskPatterns` now supports three pattern forms (backward compatible):
  - **Substring** (default): `'token'` — matches any key containing "token".
  - **Exact match**: `'=accessToken'` — matches only the key `accessToken`.
  - **Regex**: `'~^(access|refresh)_token$'` — matches via RegExp.
- Patterns are compiled once and cached per `JsonFormatter` instance.
- All matching remains case-insensitive.
- Empty patterns (`""`, `"="`, `"~"`) are silently ignored instead of
  matching all keys.
- Invalid regex patterns (e.g. `"~[unclosed"`) gracefully fall back to
  substring matching instead of crashing the logging pipeline.

### Fixed: `timeCancel` Warning on Missing Label
- `LogPilot.timeCancel(label)` now logs a `verbose`-level hint when called
  with a label that has no matching `LogPilot.time()`. Previously it was a
  silent no-op, making misspelled labels and double-cancels invisible.

### Fixed: `LogPilot.json()` Breadcrumb Parity
- `LogPilot.json()` now adds a breadcrumb, matching the behavior of all
  other log methods. Previously, JSON-logged data was absent from error
  breadcrumb trails, creating gaps in pre-crash context.
- Breadcrumb message is `json: <tag>` when a tag is provided, or a
  truncated (50-char) preview of the raw JSON otherwise.

### Fixed: Sink Error Isolation
- A throwing `LogSink.onLog` no longer kills the entire dispatch loop.
  Each sink is wrapped in a try-catch so subsequent sinks still receive
  the record.
- Applies to both the normal log path (`LogPilot._dispatchToSinks`) and
  the zone error path (`LogPilotZone._dispatchErrorToSinks`).
- In debug mode, the caught error is printed via `debugPrint` for
  visibility.

## 0.11.0

### New: MCP Log Tail / Watch Mode
- `watch_logs` MCP tool starts streaming new log entries as they arrive.
  Accepts optional `tag`, `level`, and `interval_ms` filters.
- Uses `Timer.periodic` to poll `ext.LogPilot.getHistory`, diffs against the
  last seen count, and pushes new entries to the agent via MCP log
  notifications (`notifications/message` with `logger: "log_pilot_tail"`).
- `stop_watch` MCP tool cancels the active watcher and returns a
  delivery summary (total entries pushed).
- Only one watch can be active at a time — starting a new one
  automatically stops the previous.
- New `LogPilot://tail` subscribable MCP resource: returns the latest batch
  of entries from the watcher. Subscribers receive
  `notifications/resources/updated` on each poll cycle that finds new
  entries.
- `LogPilotMcpServer` now uses the `LoggingSupport` mixin from `dart_mcp`,
  enabling server-initiated push via the MCP logging protocol.
- LogPilot levels are mapped to MCP `LoggingLevel`: verbose/debug → debug,
  info → info, warning → warning, error/fatal → error.
- Default poll interval is 2 seconds (configurable via `interval_ms`,
  minimum 500ms).
- The watch timer is automatically cancelled on connection reset
  (hot restart, full restart).

### New: MCP Server Auto-Reconnect on Isolate Recycle
- The `log_pilot_mcp` server now survives hot restarts and isolate recycles
  without requiring a "Developer: Reload Window" in Cursor.
- Listens for `IsolateStart` / `IsolateRunnable` VM events and
  automatically re-resolves the isolate, libraries, and service extensions.
- Listens for `ServiceExtensionAdded` debug events so it detects LogPilot
  extensions that register after the initial handshake (common after
  hot restart).
- Every tool call is wrapped in a retry loop: on connection errors
  (WebSocket closed, stale isolate, sentinel), the server resets and
  reconnects with exponential backoff (up to 3 retries by default).
- The `maxRetries` parameter on `LogPilotMcpServer` allows callers to tune
  retry behavior.
- No agent or user action required — reconnection is fully transparent.

### Improved: Rich Snapshot via Service Extensions
- `ext.LogPilot.getSnapshot` now returns the same rich snapshot as the
  `evaluate`-based fallback path: `recentErrors`, `recentLogs`, per-level
  history counts, full config, `showCaller` status, and the new
  `recentByTag` grouping.
- Previously, the service-extension path returned a minimal stub that
  omitted recent errors, recent logs, and most config fields. Agents
  using `get_snapshot` via extensions now get the same data quality as
  those using the evaluate path.
- Accepts `max_recent_errors`, `max_recent_logs`, `group_by_tag`, and
  `per_tag_limit` parameters (forwarded from MCP tool arguments).

### New: Snapshot Grouped by Tag (`recentByTag`)
- `LogPilot.snapshot()` accepts new optional parameters: `groupByTag` (bool,
  default false) and `perTagLimit` (int, default 5).
- When `groupByTag: true`, the snapshot includes a `recentByTag` section
  that groups the last N records by their tag. Each tag entry contains
  `total` (count of all records with that tag) and `recent` (the last
  `perTagLimit` records as JSON maps).
- Untagged records appear under the key `(untagged)`.
- `LogPilot.snapshotAsJson()` forwards both new parameters.
- The MCP `get_snapshot` tool exposes `group_by_tag` (boolean) and
  `per_tag_limit` (int) input parameters, supported on both the
  service-extension and evaluate code paths.
- Designed for the common agent workflow: "show me the last 3 Auth
  entries" — without needing to know timestamps or call `query_logs`.

### New: VM Service URI Auto-Discovery
- LogPilot now writes the running app's VM service WebSocket URI to
  `.dart_tool/log_pilot_vm_service_uri` on `LogPilot.init()` / `LogPilot.configure()`.
  This is done automatically on native platforms (no-op on web).
- The `log_pilot_mcp` server reads this file at startup and watches it for
  changes. When the app does a full restart (new debug session), the URI
  file updates and the MCP server reconnects automatically — no manual
  editing of `.cursor/mcp.json` required.
- New CLI flag: `--vm-service-uri-file=PATH` to specify a custom file
  location. If no flags are given, the server auto-discovers the file
  at `.dart_tool/log_pilot_vm_service_uri` relative to the working directory.
- `log_pilot_VM_SERVICE_URI` environment variable still works as a fallback.
- `LogPilotMcpServer.updateVmServiceUri(newUri)` public method for
  programmatic URI updates.

### New: MCP `query_logs` Deduplication
- `query_logs` accepts a new `deduplicate` boolean parameter (default
  `false`). When `true`, consecutive log entries with the same level,
  message, and caller are collapsed into a single entry with a `count`
  field.
- Entries from **different callers** are kept separate, so agents can
  tell which call site produced which entry — solving the
  "duplicate entries from different methods" problem.
- Only applies to the service-extension code path (the evaluate path
  returns raw history and should be deduped client-side if needed).

### Improved: Snapshot Includes `showCaller` Config
- Both `LogPilot.snapshot()` and `ext.LogPilot.getSnapshot` now include
  `showCaller` in the config section, so agents can verify that caller
  locations are being captured.

### Published Package Scope
- The published package on pub.dev includes the core library, `http`
  interceptor, file sink, navigation observer, overlay, and all agent
  features (MCP server, snapshots, export, breadcrumbs, error IDs, etc.).
- **Dio, Chopper, GraphQL, and BLoC** integrations (`log_pilot_dio.dart`,
  `log_pilot_chopper.dart`, `log_pilot_graphql.dart`, `log_pilot_bloc.dart`) remain in
  the source repo for development but are excluded from the published
  archive. They depend on packages (`dio`, `chopper`, `gql`, `bloc`)
  that cannot be regular dependencies of the core package. These will
  ship as separate packages (e.g. `log_pilot_dio`) in a future release.

### Example App
- Added Section 24 (MCP Log Tail / Watch Mode) with buttons to simulate
  watch activity and view tool documentation.

---

## 0.10.0

### New: DevTools Extension (`log_pilot_devtools`)
- Companion DevTools extension — `LogPilot` now appears as its own tab in Dart
  DevTools when the app is running. Zero config: just add `LogPilot` as a
  dependency and the extension auto-registers.
- **Log list screen**: Real-time log table with timestamp, color-coded level
  chip, tag, truncated message, and error ID columns.
- **Level filter chips**: ALL / VERBOSE / DEBUG / INFO / WARNING / ERROR / FATAL
  — click to show only that level.
- **Tag filter**: Dropdown populated from unique tags in the log history.
- **Search**: Substring match across message, tag, error, and error ID.
- **Toolbar actions**: Refresh, Clear history, Set log level, Export (text or
  JSON copied to clipboard), Take snapshot (formatted JSON dialog), Auto-scroll
  toggle.
- **Log detail screen**: Drill-down on any row to see the full message,
  metadata as an expandable JSON tree, error + stack trace, copyable error ID,
  breadcrumb timeline, caller location, and session/trace IDs.
- **Polling for live updates**: The extension polls `LogPilot.history.length` every
  2 seconds and pulls new records when the count changes — live-stream feel
  without overloading the VM service.
- **DevTools theming**: Uses `devtools_app_shared` so the extension follows
  DevTools dark/light mode automatically.
- **No app-side changes**: Reads existing `LogPilot` APIs via VM service evaluation
  — users just need `LogPilot` in their dependencies.
- Extension source in `log_pilot_devtools/`, pre-compiled build in
  `extension/devtools/build/`.
- Extension validated with `dart run devtools_extensions validate`.

## 0.9.0

### New: Structured Console Output Modes (Agent-First)
- `OutputFormat` enum with three modes: `pretty` (default), `plain`, `json`.
- `LogPilotConfig.outputFormat` controls how LogPilot renders console output:
  - `OutputFormat.pretty` — box-bordered, colorized blocks (existing default).
  - `OutputFormat.plain` — flat single-line output with no ANSI codes or
    borders. Format: `[LEVEL] [tag] message | Error: ... | {"meta": "data"}`.
    Designed for AI agents (Cursor, Claude Code, Copilot) that parse terminal
    output programmatically.
  - `OutputFormat.json` — one NDJSON line per log entry, matching
    `LogPilotRecord.toJson()`. Designed for structured log pipelines and `jq`.
- All three modes work with `printLog` and `printNetwork`.
- All factory constructors (`debug()`, `staging()`, `production()`) accept
  `outputFormat`. Default remains `pretty` for backward compatibility.
- `copyWith(outputFormat:)` supported.
- Network logs in `plain` mode strip ANSI and join into one line.
- Network logs in `json` mode emit a single JSON line with `type: "network"`.

### New: Diagnostic Snapshot
- `LogPilot.snapshot()` — returns a structured `Map<String, dynamic>` summary
  of recent LogPilot activity, designed for AI agents to call after a crash or
  unexpected behavior to understand what happened in one shot.
- Includes: `sessionId`, `traceId`, current config (level, format, enabled),
  history counts per level, recent error/fatal records, recent logs of any
  level, and active `LogPilot.time()` timers.
- `LogPilot.snapshotAsJson()` — convenience for pretty-printed JSON string output.
- `maxRecentErrors` (default 5) and `maxRecentLogs` (default 10) parameters
  control how many records are included.

### New: Error Breadcrumbs
- Automatic breadcrumb trail that records the last N events before each error.
- Every log call (`LogPilot.info()`, `LogPilot.debug()`, etc.) auto-adds a breadcrumb.
- Manual breadcrumbs via `LogPilot.addBreadcrumb(message, category:, metadata:)`.
- When an error/fatal log is emitted, the breadcrumb trail is attached to the
  `LogPilotRecord` and displayed in console output (all three output formats).
- `LogPilotConfig.maxBreadcrumbs` controls buffer size (default 20, set 0 to disable).
- `LogPilot.breadcrumbs` getter and `LogPilot.clearBreadcrumbs()` for manual access.
- Breadcrumbs are included in `LogPilotRecord.toJson()` for sink/export consumption.
- Modeled after Sentry's breadcrumb pattern — lighter than full log records.

### New: Agent-Friendly Error IDs
- Each error/fatal log with an `error` object receives a deterministic hash-based
  ID (e.g. `lk-e3a9f2`), built from error type + normalized message + top frame.
- Same error signature always produces the same ID — agents can reference errors
  by ID across debugging sessions: "Error `lk-e3a9f2` occurred 4 times."
- Numeric variations are normalized: "index 5 out of range 10" and "index 3 out
  of range 8" produce the same ID.
- `LogPilotRecord.errorId` field, included in `toJson()`, `toFormattedString()`,
  and all console output formats.
- Uses FNV-1a 32-bit hash — fast, zero dependencies, good distribution.

### New: Instrumentation Helpers
- `LogPilot.instrument(label, () => expr)` — wraps a synchronous expression with
  automatic timing, result logging, and error capture. Logs at `debug` on
  success (with return value and elapsed ms) and `error` on failure (with
  error, stack trace, elapsed ms). The original return value or exception
  is always propagated.
- `LogPilot.instrumentAsync(label, () => future)` — the async counterpart.
  Awaits the future and logs timing + result on completion.
- Both accept optional `tag:` (default `'instrument'`) and `level:` (default
  `LogLevel.debug`) parameters.
- Designed for AI agents to quickly add observability to suspicious code
  without boilerplate — and remove it in one line when debugging is done.
- Preserves generic return types: `LogPilot.instrument<List<int>>('build', ...)`.

### New: LLM-Summarizable Export
- `LogPilot.exportForLLM(tokenBudget: 4000)` — intelligently compresses the
  log history to fit within a token budget. Prevents the common failure
  mode of pasting 50KB of logs into an LLM prompt.
- Algorithm: (1) prioritizes errors and warnings, (2) deduplicates
  consecutive identical messages with `(×N)` counts, (3) truncates
  verbose entries at ~200 chars, (4) fills remaining budget with recent
  info/debug/verbose records.
- Uses approximate token counting: 4 characters ≈ 1 token.
- Includes error IDs, tags, and error descriptions for maximum AI context.
- Output is clean text that any LLM can reason about without hitting context
  window limits.

### New: Runtime Log-Level Override
- `LogPilot.setLogLevel(LogLevel.verbose)` — change the minimum log level at
  runtime without code edits, config rebuilds, or app restart. Takes effect
  immediately for all subsequent log calls.
- `LogPilot.logLevel` getter — read the current effective log level.
- Designed for AI agents to temporarily increase verbosity during debugging
  and restore it afterwards. Preserves all other config settings.

### New: AGENTS.md (AI Agent Guidance)
- Ships an `AGENTS.md` file with the package, providing AI coding agents
  (Cursor, Claude Code, Copilot, Windsurf, Gemini CLI, etc.) with rules
  for using LogPilot correctly.
- Three size tiers: Quick Reference (~1k chars), Standard Rules (~4k chars),
  and Comprehensive Rules (~10k chars) — matching Flutter's official AI rules
  format for different token budgets.
- Covers: logging patterns by file type, tag conventions, debugging workflow,
  output format selection, decision log (rejected approaches), network logging,
  sink integration, and anti-patterns.

### New: MCP Server (`log_pilot_mcp`)
- Separate `log_pilot_mcp/` package providing an MCP (Model Context Protocol)
  server that exposes a running Flutter app's LogPilot state to AI agents.
- Built on the official `dart_mcp` package (^0.5.0) from labs.dart.dev.
- Connects to the app's Dart VM service and evaluates LogPilot expressions.
- **MCP Tools**: `get_snapshot`, `query_logs`, `export_logs`,
  `set_log_level`, `get_log_level`, `clear_logs`.
- **MCP Resources**: `LogPilot://config` (current configuration),
  `LogPilot://session` (session and trace IDs).
- Usage: configure in Cursor/Claude Code MCP settings with the
  `--vm-service-uri` flag pointing to the running Flutter app.

### Example App
- Added Section 16 (Output Formats) with buttons to switch between pretty,
  plain, and JSON modes and see the difference in console output.
- Added Section 17 (Diagnostic Snapshot) with buttons to generate and view
  snapshots.
- Added Section 18 (Error Breadcrumbs) with manual breadcrumb, error trigger,
  view trail, and clear buttons.
- Added Section 19 (Agent-Friendly Error IDs) with deterministic ID demo.
- Added Section 20 (Runtime Log-Level Override) with verbose/warning/restore.
- Added Section 21 (Instrumentation Helpers) with sync, async, and error demos.
- Added Section 22 (LLM-Summarizable Export) with 4k and 1k token budget demos.
- Added Section 23 (DevTools Extension) with info about the LogPilot DevTools tab.

---

## 0.8.0

### Improved: Web Platform Safety
- Removed `dart:io` import from `ansi_styles.dart` — the core barrel
  (`package:log_pilot/log_pilot.dart`) no longer transitively depends on `dart:io`
  at all, making web compilation reliable.
- ANSI support now defaults to `true` (DevTools renders ANSI on all
  platforms). Use `setAnsiSupported(false)` to override.

### Improved: API Completeness
- `LogPilotConfig.staging()` and `.production()` now accept `onlyTags`
  parameter — previously only the default constructor and `.debug()`
  exposed it.
- `LogPilot.reset()` — `@visibleForTesting` method for reliable test
  isolation. Clears all state (timers, rate limiter, history, config)
  and marks LogPilot as un-initialized.

### Improved: LTS Structural Cleanup
- All config factory constructors now have symmetric parameter sets,
  reducing surprises when switching between presets.
- Internal code streamlined for consistency across observers and
  interceptors.

---

## 0.7.0

### New: In-App Log Viewer Overlay
- `LogPilotOverlay` — a debug overlay widget that displays recent log records
  in a draggable sheet with real-time updates.
- Level-based filter chips (ALL, VERBOSE, DEBUG, INFO, WARNING, ERROR, FATAL).
- Full-text search across messages, tags, and levels.
- Copy-to-clipboard for text and JSON export formats.
- Auto-scroll toggle to follow new logs as they arrive.
- Clear button to reset the in-memory history.
- Floating entry button with configurable alignment.
- Auto-hides in production (`LogPilotConfig.enabled: false`).
- Override visibility with `LogPilotOverlay(enabled: true/false)`.
- Exported from `package:log_pilot/log_pilot.dart`.

### New: Web Platform Support
- The core `package:log_pilot/log_pilot.dart` barrel is now fully web-compatible —
  no `dart:io` dependency.
- `FileSink` moved to `package:log_pilot/log_pilot_io.dart` — import it only on
  mobile/desktop where `dart:io` is available.
- All other features (logging, history, navigation, BLoC, timing, overlay)
  work identically on web.
- `dart:developer.log` output appears in the browser DevTools console.
- Web-specific notes added to documentation.

### Example App
- Added `LogPilotOverlay` wrapping the app via `MaterialApp.builder`.
- Added Section 15 (In-App Log Viewer) describing the overlay.

---

## 0.6.0

### New: Performance Timing Utilities
- `LogPilot.time('label')` / `LogPilot.timeEnd('label')` — measure operation
  duration like `console.time()` in JavaScript.
- `LogPilot.timeEnd` returns the elapsed `Duration` and logs at debug level
  with metadata including `elapsedMs` and `elapsedUs`.
- `LogPilot.timeCancel('label')` — cancel a timer without logging.
- `LogPilotLogger.time` / `timeEnd` / `timeCancel` — scoped versions that
  prefix the label with the logger's tag (e.g. `AuthService/signIn`).
- Multiple concurrent timers are supported.
- Calling `timeEnd` without a matching `time` logs a warning.
- Default tag is `'perf'`; customizable via the `tag:` parameter.

### Changed: Lightweight Core (Optional Dependencies)
- Moved `dio`, `chopper`, `gql`, `gql_exec`, `gql_link`, and `bloc`
  from `dependencies` to `dev_dependencies`.
- The base `LogPilot` package now only depends on `flutter`, `meta`, and
  `http` — no more forced resolution of Dio, Chopper, GraphQL, or BLoC.
- Consumers must add the relevant package to their own pubspec when
  importing optional barrels (e.g. add `dio` to use `log_pilot_dio.dart`).
- This follows the same pattern as `talker_dio_logger`, `sentry_dio`,
  and other mature packages on pub.dev.

### Example App
- Added Section 14 (Performance Timing) with concurrent timer demos.

---

## 0.5.0

### New: Navigation / Route Logging
- `LogPilotNavigatorObserver` — a `NavigatorObserver` that auto-logs push,
  pop, replace, and remove events with route names and arguments.
- Configurable `logLevel`, `tag` (default `'navigation'`), and
  `logArguments` (disable for sensitive routes).
- Route metadata includes action, route name, previous route, and
  arguments.
- Exported from `package:log_pilot/log_pilot.dart`.

### New: BLoC Observer
- `LogPilotBlocObserver` — a `BlocObserver` that logs BLoC/Cubit lifecycle
  events through LogPilot: create, close, event, state change, and error.
- Configurable per-event-type toggles: `logEvents`, `logTransitions`,
  `logCreations`.
- Configurable log levels per event type: `eventLevel`, `transitionLevel`,
  `creationLevel`, `errorLevel`.
- State changes log current → next state with full metadata.
- Errors include the exception and stack trace.
- Exported from `package:log_pilot/log_pilot_bloc.dart` (requires `bloc` package).

### Example App
- Added Section 12 (Navigation Logging) with push/pop/replace
  demonstrations using `LogPilotNavigatorObserver`.
- Added Section 13 (BLoC Observer) with a counter cubit demo showing
  create, state change, error, and close logging.

---

## 0.4.0

### New: Correlation / Session & Trace IDs
- `LogPilot.sessionId` — auto-generated v4 UUID per app session. Regenerated
  on each `LogPilot.init()` or `LogPilot.configure()` call.
- `LogPilot.setTraceId()` / `LogPilot.clearTraceId()` — ambient per-request
  trace IDs. All logs emitted while a trace is active carry it.
- `LogPilotRecord.sessionId` and `LogPilotRecord.traceId` — new fields on every
  log record, included in `toJson()` and `toFormattedString()`.
- Network interceptors (`LogPilotHttpClient`, `LogPilotDioInterceptor`,
  `LogPilotChopperInterceptor`) auto-inject `X-LogPilot-Session` and
  `X-LogPilot-Trace` headers. Disable with `injectSessionHeader: false`.
- No external UUID dependency — uses `Random.secure()` for v4 UUID
  generation.

### Example App
- Added Section 11 (Session & Trace IDs) with buttons to view session ID,
  set/clear trace IDs, inspect record IDs, and demo HTTP header injection.

---

## 0.3.0

### New: Log History / Ring Buffer
- `LogPilot.history` — in-memory ring buffer of the most recent log records.
  Configurable via `LogPilotConfig.maxHistorySize` (default 500, set 0 to disable).
- `LogPilot.historyWhere(level:, tag:)` — filter history by severity and/or tag.
- `LogPilot.export()` — export the buffer as human-readable text or NDJSON.
  `ExportFormat.text` (default) and `ExportFormat.json` modes.
- `LogPilot.clearHistory()` — reset the buffer.
- `LogHistory` class with `add`, `clear`, `where`, `exportAsText`,
  `exportAsJson`, `records`, `length`, `isEmpty`/`isNotEmpty`.
- History captures all records regardless of `enabled` (console on/off),
  making it useful in production for bug reports and crash correlation.

### Example App
- Added Section 10 (Log History / Export) with buttons to view history
  count, filter errors, export as text/JSON, and clear the buffer.

---

## 0.2.0

### New: Rate Limiting / Deduplication
- `deduplicateWindow` config option — collapse identical log messages
  within a time window to prevent console flooding from error loops.
- Console shows the first occurrence, then a "... repeated N times" summary
  when the window expires. Sinks still receive every record.
- `LogPilotConfig.staging()` and `.production()` default to a 5-second window.

### New: File Logging
- `FileSink` — write log records to local files with automatic size-based
  rotation. Supports human-readable text and NDJSON output formats.
- Configurable `maxFileSize`, `maxFileCount`, and `baseFileName`.
- Buffered writes with periodic flush to avoid blocking the UI thread.
- `FileSink.readAll()` to export all log files as a single string for bug reports.
- `FileSink.flush()` / `FileSink.dispose()` for lifecycle management.
- `FileLogFormat.text` and `FileLogFormat.json` output modes.

### New: LogPilotRecord Serialization
- `LogPilotRecord.toJson()` — serialize log records to JSON-compatible maps.
- `LogPilotRecord.toJsonString()` — single-line JSON encoding for file/network sinks.
- `LogPilotRecord.toFormattedString()` — human-readable single-line format.

### Example App
- Added Section 8 (Rate Limiting / Dedup) with buttons to fire duplicate
  logs and see console collapsing vs sink counts.
- Added Section 9 (File Sink) with buttons to view log file path, read
  file contents, and force flush to disk.

---

## 0.1.0

Initial release.

### Core
- `LogPilot.init()` replaces `runApp()` with global error zone setup.
- Level-based logging: verbose, debug, info, warning, error, fatal.
- Clickable caller location in every log block.
- Box-bordered, colorized output via `dart:developer` (DevTools friendly).

### Architecture
- `LogPilotLogger` — scoped instance loggers with auto-tagging (`LogPilot.create('AuthService')`).
- `LogSink` / `CallbackSink` — pluggable output destinations for files, crash reporters, remote backends.
- `LogPilotRecord` — structured log records with level, message, timestamp, metadata, error, and stack trace.
- `LogPilotConfig.debug()`, `.staging()`, `.production()` — environment-aware configuration presets.
- Lazy message evaluation — `LogPilot.debug(() => expensiveString())` skips work when filtered.

### Error Handling
- Flutter error parsing with 15+ contextual hints.
- Smart stack trace simplification (collapses framework frames).
- Error silencing by keyword (`silencedErrors`) with crash reporter passthrough.
- Error handler chaining (works alongside Crashlytics, Sentry, etc.).

### Network
- Network interceptors for Dio, http, Chopper, and GraphQL.
- Status code color-coding (2xx/3xx/4xx/5xx) and duration tracking.
- Sensitive field masking (recursive, case-insensitive patterns).

### Logging Features
- JSON auto-detection, pretty-printing, and syntax highlighting.
- Tagged logging with focus mode (`onlyTags`).
- Compact vs detailed output toggle (`showDetails`).
- Sinks receive records even when console output is disabled.

# LogPilot example

A comprehensive Flutter app demonstrating every LogPilot feature with tappable
buttons for each one.

## Running

```bash
cd example
flutter run
```

## What's inside

The app has numbered sections covering:

1. **Log Levels** -- verbose through fatal with metadata and errors
2. **JSON Pretty-Print** -- auto-detect and colorize JSON
3. **Flutter Error Catching** -- overflow, null check, range errors
4. **Network Logging** -- HTTP GET/POST with masking and status-aware levels
5. **Tags & Filtering** -- `onlyTags` focus mode
6. **Scoped Loggers** -- `LogPilot.create()` and `LogPilotLogger`
7. **Sinks** -- `CallbackSink` counter and last record
8. **Rate Limiting** -- deduplication window demo
9. **File Logging** -- `FileSink` with rotation (IO only)
10. **Log History** -- ring buffer, `historyWhere`, export
11. **Session & Trace IDs** -- correlation and HTTP header injection
12. **Navigation** -- `LogPilotNavigatorObserver` push/replace/pop
13. **BLoC Observer** -- cubit lifecycle logging
14. **Performance Timing** -- `time`/`timeEnd`, `withTimer`
15. **In-App Log Viewer** -- `LogPilotOverlay` debug sheet
16. **Output Formats** -- pretty, plain, JSON
17. **Diagnostic Snapshot** -- `LogPilot.snapshot()`
18. **Error Breadcrumbs** -- automatic pre-crash context trail
19. **Error IDs** -- deterministic `lk-XXXXXX` hashes
20. **Runtime Log Level** -- `LogPilot.setLogLevel()` without restart
21. **Instrumentation** -- `LogPilot.instrument()` / `instrumentAsync()`
22. **LLM Export** -- `LogPilot.exportForLLM()` with token budgets
23. **DevTools Extension** -- LogPilot tab in Dart DevTools
24. **MCP Server** -- AI agent live log access

## Integration patterns shown

- `LogPilot.init()` replaces `runApp()` for full error zone setup
- `LogPilotNavigatorObserver` in `navigatorObservers`
- `LogPilotOverlay` in `MaterialApp.builder`
- `LogPilotBlocObserver` as `Bloc.observer`
- Conditional `FileSink` via platform-specific imports (IO vs web)

## MCP Server

The example includes `log_pilot_mcp` as a dev dependency and a
`.cursor/mcp.json` config. To test the MCP server:

1. Run the example app: `flutter run`
2. Open the project in Cursor
3. Enable the LogPilot MCP server in Cursor Settings → MCP
4. Ask the agent to call `get_snapshot` or `query_logs`

See [`example.md`](example.md) for standalone code snippets.

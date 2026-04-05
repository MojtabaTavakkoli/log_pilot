# Contributing to LogPilot

Thanks for your interest in contributing! This document covers the project
architecture, design decisions, and development workflow.

## Repository Structure

This is a multi-package repository:

```
log_pilot/
├── lib/                    # Main LogPilot library (published on pub.dev)
├── test/                   # Unit and widget tests for the core package
├── example/                # Flutter demo app with every feature
├── screenshots/            # README images and GIFs (published)
├── extension/devtools/     # Pre-compiled DevTools extension web build
├── log_pilot_devtools/       # DevTools extension source (Flutter web app)
├── log_pilot_mcp/            # MCP server for AI agent integration
└── .github/workflows/      # CI/CD
```

## Architecture

```
LogPilot (facade)                 — single entry point for users
  ├─ caller capture             — walks StackTrace.current, skips LogPilot frames
  LogPilotZone                    — global error zone setup + session ID + service extensions
    FlutterErrorParser          — parses FlutterErrorDetails + hints + caller
    StackTraceSimplifier        — collapses framework frames
  LogPilotPrinter                 — box-bordered / plain / JSON output engine
    JsonFormatter               — shared JSON encoding / masking / syntax highlight
  LogPilotConfig                  — immutable configuration with factory presets
  LogPilotRecord                  — immutable structured log entry
  LogHistory                  — ring buffer with change notifications
  BreadcrumbBuffer            — circular buffer for pre-error context trail
  RateLimiter                 — time-windowed deduplication
  LogPilotDiagnostics             — self-monitoring throughput + latency
  LogSink / CallbackSink /
    AsyncLogSink /
    BufferedCallbackSink      — pluggable output destinations
  FileSink                    — file logging with rotation (dart:io only)
  LogPilotNavigatorObserver       — auto-logs route push/pop/replace/remove
  LogPilotBlocObserver            — logs BLoC/Cubit lifecycle
  LogPilotOverlay                 — in-app debug log viewer
  LogPilotLogger                  — scoped instance with auto-tagging
  LogPilotHttpClient          \
  LogPilotDioInterceptor       |— network interceptors using
  LogPilotChopperInterceptor   |   NetworkLogFormatter + LogPilotPrinter
  LogPilotGraphQLLink         /
```

### Directory Layout

```
lib/
  log_pilot.dart                    # Main barrel export (web-safe)
  log_pilot_io.dart                 # FileSink export (dart:io only)
  log_pilot_dio.dart                # Dio interceptor (repo only, future separate package)
  log_pilot_chopper.dart            # Chopper interceptor (repo only)
  log_pilot_graphql.dart            # GraphQL link (repo only)
  log_pilot_bloc.dart               # BLoC observer (repo only)
  src/
    log_pilot.dart                  # LogPilot facade (static API)
    log_pilot_logger.dart           # Scoped instance logger
    core/
      log_level.dart           # LogLevel enum
      log_pilot_config.dart         # LogPilotConfig (immutable)
      log_pilot_printer.dart        # Output engine (pretty/plain/JSON)
      log_pilot_record.dart         # Structured log entry (immutable)
      log_sink.dart            # LogSink interface + all sink implementations
      file_sink.dart           # FileSink with rotation (dart:io)
      log_history.dart         # Ring buffer + ExportFormat
      rate_limiter.dart        # Deduplication within a time window
      breadcrumb.dart          # Breadcrumb + BreadcrumbBuffer
      error_id.dart            # FNV-1a hash-based error IDs
      log_pilot_diagnostics.dart    # Self-monitoring throughput / latency
      ansi_styles.dart         # ANSI color/style utilities
      json_formatter.dart      # JSON encoding, masking, colorizing
      output_format.dart       # OutputFormat enum
      export_format.dart       # ExportFormat enum
      vm_service_uri_writer.dart       # Conditional import dispatcher
      vm_service_uri_writer_io.dart    # Native: writes .dart_tool/log_pilot_vm_service_uri
      vm_service_uri_writer_stub.dart  # Web: no-op
    errors/
      log_pilot_zone.dart           # Global error zone + service extensions
      flutter_error_parser.dart # Flutter error parsing + contextual hints
      stack_trace_simplifier.dart # Stack frame collapsing
    navigation/
      log_pilot_navigator_observer.dart
    state/
      log_pilot_bloc_observer.dart
    ui/
      log_pilot_overlay.dart        # In-app debug log viewer overlay
    network/
      network_log_formatter.dart
      log_pilot_http_interceptor.dart
      log_pilot_dio_interceptor.dart
      log_pilot_chopper_interceptor.dart
      log_pilot_graphql_link.dart
```

## Design Decisions

- **Single facade** — `LogPilot` is the only class most users ever touch. Power
  users can access `LogPilotPrinter`, `LogPilotConfig`, `LogPilotZone` directly.

- **Immutable records and config** — `LogPilotRecord`, `LogPilotConfig`, and
  `Breadcrumb` are annotated `@immutable` with all-final fields. Config
  changes produce new instances via `copyWith`.

- **Caller capture** — `LogPilot._captureCaller()` walks `StackTrace.current`,
  skipping all `package:log_pilot/` and `dart:` frames, to find the exact line
  in user code. Disabled by default in production and web presets.

- **Three output modes** — `pretty` (box-bordered for humans), `plain`
  (single-line for AI agents), `json` (NDJSON for pipelines). All three
  support the same feature set.

- **DRY JSON handling** — `JsonFormatter` is shared between `LogPilotPrinter`
  and `NetworkLogFormatter` for encoding, truncation, masking, and syntax
  highlighting.

- **Error handler chaining** — `LogPilot.init` captures and chains with any
  existing `FlutterError.onError` and `PlatformDispatcher.onError` handlers.

- **Silencing vs filtering** — `silencedErrors` suppresses log output but
  the `onError` callback still fires. `onlyTags` is a development-time
  focus tool.

- **Web safety** — The core barrel (`log_pilot.dart`) has zero `dart:io` imports.
  `FileSink` lives in `log_pilot_io.dart` behind a conditional import.

- **VM service extensions** — DevTools and MCP access logs via
  `ext.LogPilot.*` service extensions, which work on all platforms including
  web (unlike expression evaluation).

## Development

### Prerequisites

- Dart SDK >= 3.9.2
- Flutter >= 3.0.0

### Running Tests

```bash
flutter test
```

### Running the Example App

```bash
cd example && flutter run
```

### Building the DevTools Extension

```bash
cd log_pilot_devtools && flutter build web
# Then copy build/web/ to extension/devtools/build/
```

### Code Style

This project uses `flutter_lints` with additional strict rules. Run the
analyzer before submitting:

```bash
flutter analyze
```

### Branch Naming

All work happens on short-lived branches off `main`. Use a prefix that
describes the purpose:

| Prefix | Purpose | Example |
|--------|-----------------------------|--------------------------------|
| `feature/` | New functionality | `feature/overlay-search` |
| `fix/` | Bug fix | `fix/printer-null-check` |
| `docs/` | Documentation only | `docs/readme-screenshots` |
| `refactor/` | Restructuring, no behavior change | `refactor/extract-formatter` |
| `test/` | Adding or fixing tests | `test/rate-limiter-edge-cases` |
| `chore/` | CI, tooling, dependencies | `chore/upgrade-flutter-lints` |

Keep names lowercase with hyphens. Branches are deleted after merge.

### Commit Messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`

**Scopes:** `core`, `printer`, `config`, `record`, `history`, `overlay`,
`devtools`, `mcp`, `dio`, `chopper`, `graphql`, `bloc`, `zone`, `errors`,
`navigation`, `network`, `sink`, `file-sink`, `example`, `deps`

Examples:

```
feat(overlay): add search bar to log viewer
fix(printer): handle null metadata without crash
docs: update README with MCP setup instructions
chore(deps): bump meta to ^1.16.0
```

For breaking changes, add `!` after the type/scope:

```
feat(config)!: rename prettyPrint to outputFormat
```

### Commit Prefix Labels

For PR titles and quick single-line commits, use bracket prefixes to
categorize the change at a glance:

| Prefix | When to use |
|-------------|----------------------------------------------|
| `[Feature]` | New user-facing functionality |
| `[Fix]` | Bug fix |
| `[Docs]` | Documentation only (README, CHANGELOG, etc.) |
| `[Refactor]`| Code restructuring with no behavior change |
| `[Test]` | Adding or fixing tests |
| `[Chore]` | CI, tooling, dependencies, config |
| `[Perf]` | Performance improvement |
| `[Breaking]`| Breaking API change |

Examples:

```
[Docs] Rewrite MCP setup instructions for agents
[Fix] VM service URI auto-discovery on Windows
[Feature] Add --project-root flag to MCP server
[Chore] Bump version to 0.15.3
```

Both formats are acceptable. Use Conventional Commits for detailed
commit history and bracket prefixes for PR titles and squash commits.

### Changelog

Update `CHANGELOG.md` for any user-facing change. Use
[Keep a Changelog](https://keepachangelog.com/) section names:

- **Added** — new features
- **Fixed** — bug fixes
- **Changed** — changes to existing behavior
- **Breaking** — breaking API changes
- **Removed** — removed features
- **Deprecated** — features marked for future removal

### Submitting Changes

1. Fork the repository
2. Create a branch from `main` using the naming convention above
3. Make your changes with tests
4. Run `flutter test` and `flutter analyze`
5. Update `CHANGELOG.md` if the change is user-facing
6. Commit using the Conventional Commits format
7. Submit a pull request — the PR template will guide you through the checklist

## Publishing Scope

The **published package** on pub.dev includes the core library, http
interceptor, file sink, navigation observer, overlay, DevTools extension,
and all agent features.

**Dio, Chopper, GraphQL, and BLoC** integrations are in the repo but
excluded from the published archive via `.pubignore`. They will ship as
separate packages in a future release.

# LogPilot examples

See `lib/main.dart` for a runnable Flutter app demonstrating all features.

For standalone Dart snippets, see the sections below.

## Minimal Setup

```dart
import 'package:flutter/material.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  LogPilot.init(child: const MyApp());
}
```

## With Full Configuration

```dart
void main() {
  LogPilot.init(
    config: LogPilotConfig(
      logLevel: LogLevel.verbose,
      showTimestamp: true,
      showCaller: true,
      showDetails: true,
      colorize: true,
      maxLineWidth: 120,
      stackTraceDepth: 10,
      maxPayloadSize: 20 * 1024,
      maskPatterns: ['Authorization', 'password', 'token', 'secret', 'api_key'],
      jsonKeyColor: AnsiColor.cyan,
      jsonValueColor: AnsiColor.green,
    ),
    onError: (error, stack) {
      // Forward to Crashlytics, Sentry, Datadog, etc.
    },
    child: const MyApp(),
  );
}
```

## Compact Logging (no details)

```dart
LogPilot.init(
  config: LogPilotConfig(
    showDetails: false, // hides error body, stack traces, informationCollector
    showCaller: true,   // still shows the clickable file:line
  ),
  child: const MyApp(),
);
```

## Dio Integration

```dart
import 'package:dio/dio.dart';
import 'package:log_pilot/log_pilot_dio.dart';

final dio = Dio()
  ..interceptors.add(LogPilotDioInterceptor());
```

## Chopper Integration

```dart
import 'package:chopper/chopper.dart';
import 'package:log_pilot/log_pilot_chopper.dart';

final chopper = ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [LogPilotChopperInterceptor()],
);
```

## GraphQL Integration

```dart
import 'package:graphql/client.dart';
import 'package:log_pilot/log_pilot_graphql.dart';

final httpLink = HttpLink('https://api.example.com/graphql');
final link = LogPilotGraphQLLink().concat(httpLink);
final client = GraphQLClient(link: link, cache: GraphQLCache());
```

## File Logging

```dart
import 'dart:io';
import 'package:log_pilot/log_pilot.dart';

void main() {
  final logDir = Directory('/path/to/logs');

  LogPilot.init(
    config: LogPilotConfig(
      sinks: [
        FileSink(
          directory: logDir,
          maxFileSize: 2 * 1024 * 1024,  // 2 MB per file
          maxFileCount: 5,
          format: FileLogFormat.text,     // or .json for NDJSON
        ),
      ],
    ),
    child: const MyApp(),
  );
}
```

## Export Logs for Bug Reports (File Sink)

```dart
final fileSink = FileSink(directory: logDir);

// After logging throughout the session:
final allLogs = await fileSink.readAll();
Share.share(allLogs);

// Flush before shutdown:
await fileSink.flush();
```

## Log History / Ring Buffer

```dart
// Access all recent records (oldest first)
final records = LogPilot.history;

// Filter by level or tag
final errors = LogPilot.historyWhere(level: LogLevel.error);
final authLogs = LogPilot.historyWhere(tag: 'auth');
```

## Export History for Bug Reports

```dart
// Human-readable text (one line per record)
final text = LogPilot.export();
Share.share(text);

// NDJSON for machine parsing
final json = LogPilot.export(format: ExportFormat.json);

// Clear after exporting
LogPilot.clearHistory();
```

## Configure History Size

```dart
LogPilot.init(
  config: LogPilotConfig(
    maxHistorySize: 1000, // default 500, set 0 to disable
  ),
  child: const MyApp(),
);
```

## Session & Trace IDs

```dart
// Auto-generated on init — unique per app launch
print(LogPilot.sessionId); // "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d"

// Per-request trace ID
LogPilot.setTraceId('req-12345');
await checkout();  // all logs carry traceId: "req-12345"
LogPilot.clearTraceId();
```

## Correlate with Backend

```dart
// Network interceptors auto-inject X-LogPilot-Session header
final client = LogPilotHttpClient(); // adds X-LogPilot-Session automatically
final response = await client.get(apiUrl);

// Disable header injection if needed
final client = LogPilotHttpClient(injectSessionHeader: false);
```

## Navigation Logging

```dart
MaterialApp(
  navigatorObservers: [LogPilotNavigatorObserver()],
)
```

Logs push/pop/replace/remove with route names and arguments. Customize:

```dart
LogPilotNavigatorObserver(
  tag: 'nav',
  logArguments: false, // hide route arguments from logs
)
```

## BLoC Observer

```dart
import 'package:log_pilot/log_pilot_bloc.dart';

void main() {
  Bloc.observer = LogPilotBlocObserver();
  LogPilot.init(child: const MyApp());
}
```

Customize what gets logged:

```dart
LogPilotBlocObserver(
  tag: 'state',
  logCreations: false,       // skip create/close
  transitionLevel: LogLevel.debug,
)
```

## Performance Timing

```dart
LogPilot.time('fetchUsers');
final users = await api.fetchUsers();
LogPilot.timeEnd('fetchUsers');  // logs: "fetchUsers: 342ms"
```

Multiple concurrent timers, cancel, and scoped loggers:

```dart
// Concurrent timers
LogPilot.time('fast');
LogPilot.time('slow');
await Future.delayed(Duration(milliseconds: 50));
LogPilot.timeEnd('fast');  // ~50ms
LogPilot.timeEnd('slow');  // ~50ms (still running)

// Cancel without logging
LogPilot.time('abandoned');
LogPilot.timeCancel('abandoned');

// Scoped logger prefixes label with tag
final log = LogPilot.create('DB');
log.time('query');      // label: "DB/query"
log.timeEnd('query');   // logs with tag "DB"
```

## In-App Log Viewer

```dart
MaterialApp(
  builder: (context, child) => LogPilotOverlay(child: child!),
  home: const MyHome(),
)
```

The overlay auto-hides in production. Customize the entry button position:

```dart
LogPilotOverlay(
  entryButtonAlignment: Alignment.bottomLeft,
  child: child!,
)
```

## File Logging (Mobile / Desktop)

```dart
import 'package:log_pilot/log_pilot_io.dart';  // separate import for dart:io features

LogPilot.init(
  config: LogPilotConfig(
    sinks: [FileSink(directory: logDir)],
  ),
  child: const MyApp(),
);
```

## Web Support

The main `package:log_pilot/log_pilot.dart` works on Flutter Web. All features
except `FileSink` (which requires `dart:io`) are web-compatible.

```dart
// Web-safe — works everywhere:
import 'package:log_pilot/log_pilot.dart';

// NOT web-safe — mobile/desktop only:
// import 'package:log_pilot/log_pilot_io.dart';
```

## Testing

Use `LogPilot.reset()` in your test teardown to ensure clean state:

```dart
tearDown(() {
  LogPilot.reset();
});
```

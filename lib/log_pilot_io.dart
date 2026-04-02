/// File-system dependent features for LogPilot.
///
/// Import this barrel on mobile/desktop where `dart:io` is available.
/// Do **not** import on Flutter Web — use `package:log_pilot/log_pilot.dart` instead.
///
/// ```dart
/// import 'package:log_pilot/log_pilot.dart';
/// import 'package:log_pilot/log_pilot_io.dart';
///
/// LogPilot.init(
///   config: LogPilotConfig(
///     sinks: [FileSink(directory: logDir)],
///   ),
///   child: const MyApp(),
/// );
/// ```
library;

export 'package:log_pilot/src/core/file_sink.dart';

import 'dart:io';

import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/log_pilot_io.dart';

FileSink? _fileSink;

/// IO platforms: create a FileSink using a temp-based log directory.
///
/// We avoid calling `path_provider` here because it requires the
/// Flutter binding, which must be initialized inside `LogPilot.init()`'s
/// guarded zone to avoid zone-mismatch errors. Instead, use the
/// platform temp directory which is always available.
Future<List<LogSink>> createSinks() async {
  final logDir = Directory('${Directory.systemTemp.path}/log_pilot_example_logs');

  final fileSink = FileSink(
    directory: logDir,
    maxFileSize: 2 * 1024 * 1024,
    maxFileCount: 5,
    format: FileLogFormat.text,
  );
  _fileSink = fileSink;
  return [fileSink];
}

/// The active file sink, or `null` if not yet initialized.
dynamic get activeFileSink => _fileSink;

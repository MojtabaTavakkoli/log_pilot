import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:log_pilot/src/core/log_sink.dart';
import 'package:log_pilot/src/core/log_pilot_record.dart';

/// The format used when writing log records to file.
enum FileLogFormat {
  /// Human-readable single-line format:
  /// `2026-03-28T14:23:01.456 [INFO] [auth] User signed in`
  text,

  /// One JSON object per line (NDJSON), suitable for machine parsing:
  /// `{"level":"INFO","timestamp":"2026-03-28T14:23:01.456","message":"..."}`
  json,
}

/// A [LogSink] that writes log records to files with automatic rotation.
///
/// Supports rotation by file size, configurable maximum file count, and
/// both human-readable text and NDJSON output formats.
///
/// ```dart
/// import 'dart:io';
/// import 'package:log_pilot/log_pilot.dart';
///
/// final logDir = Directory('/path/to/logs');
///
/// LogPilot.init(
///   config: LogPilotConfig(
///     sinks: [
///       FileSink(
///         directory: logDir,
///         maxFileSize: 2 * 1024 * 1024, // 2 MB
///         maxFileCount: 5,
///         format: FileLogFormat.text,
///       ),
///     ],
///   ),
///   child: const MyApp(),
/// );
/// ```
///
/// Log files are named `LogPilot.log` (current) and `LogPilot.1.log` through
/// `LogPilot.{maxFileCount - 1}.log` (rotated archives). When the current
/// file exceeds [maxFileSize], files are shifted and the oldest is
/// deleted.
///
/// Writes are buffered and flushed periodically (every 500ms by default)
/// or when the buffer reaches 100 records to avoid blocking the UI
/// thread on every log call.
class FileSink implements LogSink {
  /// Creates a file sink that writes to [directory].
  ///
  /// [maxFileSize] is the threshold in bytes that triggers rotation
  /// (default 2 MB). [maxFileCount] is the total number of files
  /// kept including the active one (default 5). [format] controls
  /// whether records are written as plain text or NDJSON.
  FileSink({
    required this.directory,
    this.maxFileSize = 2 * 1024 * 1024,
    this.maxFileCount = 5,
    this.format = FileLogFormat.text,
    this.baseFileName = 'LogPilot',
    @visibleForTesting Duration flushInterval = const Duration(milliseconds: 500),
  })  : assert(maxFileSize > 0, 'maxFileSize must be positive'),
        assert(maxFileCount >= 2, 'maxFileCount must be at least 2'),
        assert(baseFileName.isNotEmpty, 'baseFileName must not be empty'),
        _flushInterval = flushInterval;

  /// The directory where log files are stored.
  final Directory directory;

  /// Maximum size of the active log file in bytes before rotation.
  final int maxFileSize;

  /// Total number of log files to keep (active + rotated archives).
  final int maxFileCount;

  /// Output format for log records.
  final FileLogFormat format;

  /// Base name for log files (without extension). Files are named
  /// `{baseFileName}.log`, `{baseFileName}.1.log`, etc.
  final String baseFileName;

  final Duration _flushInterval;

  final List<String> _buffer = [];
  Timer? _flushTimer;
  bool _initialized = false;
  Future<void>? _pendingFlush;

  static const _maxBufferSize = 100;

  @override
  void onLog(LogPilotRecord record) {
    final line = switch (format) {
      FileLogFormat.text => record.toFormattedString(),
      FileLogFormat.json => record.toJsonString(),
    };
    _buffer.add(line);

    _ensureInitialized();

    if (_buffer.length >= _maxBufferSize) {
      unawaited(_flush());
    }
  }

  /// Flush all buffered records to disk immediately.
  ///
  /// Call this before app shutdown to ensure no records are lost.
  Future<void> flush() => _flush();

  /// Flush and release resources (cancels the periodic flush timer).
  @override
  Future<void> dispose() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flush();
  }

  /// Returns the paths of all existing log files (active + rotated),
  /// ordered from newest to oldest.
  List<File> get logFiles {
    final files = <File>[];
    final active = _activeFile;
    if (active.existsSync()) files.add(active);
    for (var i = 1; i < maxFileCount; i++) {
      final rotated = File(_rotatedPath(i));
      if (rotated.existsSync()) files.add(rotated);
    }
    return files;
  }

  /// Read and return the contents of all log files concatenated,
  /// ordered from oldest to newest.
  ///
  /// Useful for exporting logs as a single string for bug reports.
  Future<String> readAll() async {
    await _flush();
    final files = logFiles.reversed.toList();
    final buffer = StringBuffer();
    for (final file in files) {
      buffer.write(await file.readAsString());
    }
    return buffer.toString();
  }

  // ── Private ─────────────────────────────────────────────────────────

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    _flushTimer = Timer.periodic(_flushInterval, (_) {
      if (_buffer.isNotEmpty) unawaited(_flush());
    });
  }

  File get _activeFile => File('${directory.path}/$baseFileName.log');

  String _rotatedPath(int index) =>
      '${directory.path}/$baseFileName.$index.log';

  /// Serialized flush: concurrent calls wait for the in-flight flush
  /// to finish, then drain any records that accumulated during the wait.
  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    if (_pendingFlush != null) {
      await _pendingFlush;
      if (_buffer.isNotEmpty) return _flush();
      return;
    }
    _pendingFlush = _doFlush();
    try {
      await _pendingFlush;
    } finally {
      _pendingFlush = null;
    }
  }

  Future<void> _doFlush() async {
    final lines = List<String>.of(_buffer);
    _buffer.clear();

    final file = _activeFile;
    final content = '${lines.join('\n')}\n';
    await file.writeAsString(content, mode: FileMode.append, flush: true);

    final length = await file.length();
    if (length >= maxFileSize) {
      await _rotate();
    }
  }

  Future<void> _rotate() async {
    final oldest = File(_rotatedPath(maxFileCount - 1));
    if (oldest.existsSync()) {
      await oldest.delete();
    }

    for (var i = maxFileCount - 2; i >= 1; i--) {
      final source = File(_rotatedPath(i));
      if (source.existsSync()) {
        await source.rename(_rotatedPath(i + 1));
      }
    }

    final active = _activeFile;
    if (active.existsSync()) {
      await active.rename(_rotatedPath(1));
    }
  }
}

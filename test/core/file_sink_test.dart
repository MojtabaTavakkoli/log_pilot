import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/log_pilot_io.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('log_pilot_file_sink_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  LogPilotRecord makeRecord({
    LogLevel level = LogLevel.info,
    String? message,
    String? tag,
  }) {
    return LogPilotRecord(
      level: level,
      timestamp: DateTime.utc(2026, 3, 28, 14, 0, 0),
      message: message ?? 'test message',
      tag: tag,
    );
  }

  group('FileSink basic writes', () {
    test('creates directory if it does not exist', () async {
      final nestedDir = Directory('${tempDir.path}/sub/dir');
      final sink = FileSink(
        directory: nestedDir,
        flushInterval: const Duration(milliseconds: 10),
      );

      sink.onLog(makeRecord());
      await sink.flush();

      expect(nestedDir.existsSync(), isTrue);
      await sink.dispose();
    });

    test('writes text format by default', () async {
      final sink = FileSink(
        directory: tempDir,
        flushInterval: const Duration(milliseconds: 10),
      );

      sink.onLog(makeRecord(message: 'hello world'));
      await sink.flush();

      final file = File('${tempDir.path}/LogPilot.log');
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('[INFO]'));
      expect(content, contains('hello world'));
      await sink.dispose();
    });

    test('writes JSON format when configured', () async {
      final sink = FileSink(
        directory: tempDir,
        format: FileLogFormat.json,
        flushInterval: const Duration(milliseconds: 10),
      );

      sink.onLog(makeRecord(message: 'json test', tag: 'api'));
      await sink.flush();

      final file = File('${tempDir.path}/LogPilot.log');
      final lines =
          (await file.readAsString()).trim().split('\n').where((l) => l.isNotEmpty);

      expect(lines, hasLength(1));
      final decoded = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(decoded['level'], 'INFO');
      expect(decoded['message'], 'json test');
      expect(decoded['tag'], 'api');
      await sink.dispose();
    });

    test('appends to existing file', () async {
      final sink = FileSink(
        directory: tempDir,
        flushInterval: const Duration(milliseconds: 10),
      );

      sink.onLog(makeRecord(message: 'first'));
      await sink.flush();
      sink.onLog(makeRecord(message: 'second'));
      await sink.flush();

      final content = await File('${tempDir.path}/LogPilot.log').readAsString();
      expect(content, contains('first'));
      expect(content, contains('second'));
      await sink.dispose();
    });

    test('uses custom baseFileName', () async {
      final sink = FileSink(
        directory: tempDir,
        baseFileName: 'myapp',
        flushInterval: const Duration(milliseconds: 10),
      );

      sink.onLog(makeRecord());
      await sink.flush();

      expect(File('${tempDir.path}/myapp.log').existsSync(), isTrue);
      expect(File('${tempDir.path}/LogPilot.log').existsSync(), isFalse);
      await sink.dispose();
    });
  });

  group('FileSink rotation', () {
    test('rotates when file exceeds maxFileSize', () async {
      final sink = FileSink(
        directory: tempDir,
        maxFileSize: 100,
        maxFileCount: 3,
        flushInterval: const Duration(milliseconds: 10),
      );

      for (var i = 0; i < 20; i++) {
        sink.onLog(makeRecord(message: 'Message number $i with padding data'));
      }
      await sink.flush();

      // After flush + rotation, the original active file was renamed to
      // LogPilot.1.log. A new active file only appears when more records arrive.
      final rotated1 = File('${tempDir.path}/LogPilot.1.log');
      expect(rotated1.existsSync(), isTrue);
      expect(rotated1.lengthSync(), greaterThan(0));
      await sink.dispose();
    });

    test('writes to new active file after rotation', () async {
      final sink = FileSink(
        directory: tempDir,
        maxFileSize: 100,
        maxFileCount: 3,
        flushInterval: const Duration(milliseconds: 10),
      );

      for (var i = 0; i < 20; i++) {
        sink.onLog(makeRecord(message: 'Message number $i with padding data'));
      }
      await sink.flush();

      // Write more records after rotation — should create a fresh active file.
      sink.onLog(makeRecord(message: 'after rotation'));
      await sink.flush();

      final activeFile = File('${tempDir.path}/LogPilot.log');
      expect(activeFile.existsSync(), isTrue);
      final content = await activeFile.readAsString();
      expect(content, contains('after rotation'));
      await sink.dispose();
    });

    test('respects maxFileCount and deletes oldest', () async {
      final sink = FileSink(
        directory: tempDir,
        maxFileSize: 50,
        maxFileCount: 2,
        flushInterval: const Duration(milliseconds: 10),
      );

      for (var i = 0; i < 50; i++) {
        sink.onLog(makeRecord(message: 'Message $i with some extra padding'));
      }
      await sink.flush();

      // With maxFileCount=2, we should have at most LogPilot.log + LogPilot.1.log
      final file2 = File('${tempDir.path}/LogPilot.2.log');
      expect(file2.existsSync(), isFalse);
      await sink.dispose();
    });
  });

  group('FileSink.logFiles', () {
    test('returns existing files in order', () async {
      final sink = FileSink(
        directory: tempDir,
        flushInterval: const Duration(milliseconds: 10),
      );

      sink.onLog(makeRecord());
      await sink.flush();

      final files = sink.logFiles;
      expect(files, isNotEmpty);
      expect(files.first.path, contains('LogPilot.log'));
      await sink.dispose();
    });
  });

  group('FileSink.readAll()', () {
    test('returns concatenated content from all files', () async {
      final sink = FileSink(
        directory: tempDir,
        maxFileSize: 80,
        maxFileCount: 3,
        flushInterval: const Duration(milliseconds: 10),
      );

      for (var i = 0; i < 30; i++) {
        sink.onLog(makeRecord(message: 'line-$i with extra data for rotation'));
      }
      await sink.flush();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final all = await sink.readAll();
      expect(all, contains('line-0'));
      await sink.dispose();
    });
  });

  group('FileSink.dispose()', () {
    test('flushes remaining buffer on dispose', () async {
      final sink = FileSink(
        directory: tempDir,
        flushInterval: const Duration(hours: 1),
      );

      sink.onLog(makeRecord(message: 'buffered'));
      await sink.dispose();

      final content = await File('${tempDir.path}/LogPilot.log').readAsString();
      expect(content, contains('buffered'));
    });
  });

  group('FileSink buffer auto-flush', () {
    test('flushes when buffer reaches max size', () async {
      final sink = FileSink(
        directory: tempDir,
        flushInterval: const Duration(hours: 1),
      );

      for (var i = 0; i < 100; i++) {
        sink.onLog(makeRecord(message: 'item $i'));
      }

      // The 100th record should trigger an auto-flush.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final file = File('${tempDir.path}/LogPilot.log');
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('item 0'));
      await sink.dispose();
    });
  });
}

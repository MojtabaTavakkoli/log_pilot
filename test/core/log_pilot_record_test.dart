import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogPilotRecord.toJson()', () {
    test('includes all required fields', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime.utc(2026, 3, 28, 14, 23, 1, 456),
        message: 'User signed in',
      );

      final json = record.toJson();

      expect(json['level'], 'INFO');
      expect(json['timestamp'], '2026-03-28T14:23:01.456Z');
      expect(json['message'], 'User signed in');
    });

    test('omits null optional fields', () {
      final record = LogPilotRecord(
        level: LogLevel.debug,
        timestamp: DateTime.utc(2026, 1, 1),
      );

      final json = record.toJson();

      expect(json.containsKey('message'), isFalse);
      expect(json.containsKey('tag'), isFalse);
      expect(json.containsKey('caller'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('stackTrace'), isFalse);
    });

    test('includes optional fields when present', () {
      final record = LogPilotRecord(
        level: LogLevel.error,
        timestamp: DateTime.utc(2026, 3, 28),
        message: 'Failed',
        tag: 'auth',
        caller: 'package:app/main.dart:42:8',
        metadata: const {'userId': '123'},
        error: Exception('boom'),
        stackTrace: StackTrace.current,
      );

      final json = record.toJson();

      expect(json['tag'], 'auth');
      expect(json['caller'], 'package:app/main.dart:42:8');
      expect(json['metadata'], {'userId': '123'});
      expect(json['error'], contains('boom'));
      expect(json['stackTrace'], isA<String>());
    });

    test('serializes all log levels correctly', () {
      for (final level in LogLevel.values) {
        final record = LogPilotRecord(
          level: level,
          timestamp: DateTime.utc(2026, 1, 1),
        );
        expect(record.toJson()['level'], level.label);
      }
    });
  });

  group('LogPilotRecord.toJsonString()', () {
    test('produces valid JSON', () {
      final record = LogPilotRecord(
        level: LogLevel.warning,
        timestamp: DateTime.utc(2026, 3, 28),
        message: 'Token expiring',
        tag: 'auth',
      );

      final str = record.toJsonString();
      final decoded = jsonDecode(str) as Map<String, dynamic>;

      expect(decoded['level'], 'WARNING');
      expect(decoded['message'], 'Token expiring');
      expect(decoded['tag'], 'auth');
    });

    test('is a single line with no embedded newlines', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime.utc(2026, 1, 1),
        message: 'line1\nline2',
      );

      final str = record.toJsonString();
      expect(str.contains('\n'), isFalse);
    });
  });

  group('LogPilotRecord.toFormattedString()', () {
    test('includes timestamp and level', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime.utc(2026, 3, 28, 14, 23, 1, 456),
        message: 'Hello',
      );

      final str = record.toFormattedString();

      expect(str, contains('2026-03-28'));
      expect(str, contains('[INFO]'));
      expect(str, contains('Hello'));
    });

    test('includes tag when present', () {
      final record = LogPilotRecord(
        level: LogLevel.debug,
        timestamp: DateTime.utc(2026, 1, 1),
        message: 'test',
        tag: 'network',
      );

      expect(record.toFormattedString(), contains('[network]'));
    });

    test('includes error when present', () {
      final record = LogPilotRecord(
        level: LogLevel.error,
        timestamp: DateTime.utc(2026, 1, 1),
        message: 'failed',
        error: Exception('connection timeout'),
      );

      expect(record.toFormattedString(), contains('Error:'));
      expect(record.toFormattedString(), contains('connection timeout'));
    });

    test('includes metadata when present', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime.utc(2026, 1, 1),
        message: 'event',
        metadata: const {'key': 'value'},
      );

      expect(record.toFormattedString(), contains('"key":"value"'));
    });

    test('omits tag, error, metadata when absent', () {
      final record = LogPilotRecord(
        level: LogLevel.verbose,
        timestamp: DateTime.utc(2026, 1, 1),
        message: 'plain',
      );

      final str = record.toFormattedString();
      expect(str, isNot(contains('Error:')));
      expect(str, isNot(contains('[]')));
      // Should only contain timestamp, level, and message
      expect(str, contains('[VERBOSE]'));
      expect(str, contains('plain'));
    });
  });
}

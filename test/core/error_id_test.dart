import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/src/core/error_id.dart';

void main() {
  setUp(LogPilot.reset);
  tearDown(LogPilot.reset);

  group('generateErrorId', () {
    test('produces a lk-prefixed hex string', () {
      final id = generateErrorId(error: StateError('bad'));
      expect(id, startsWith('lk-'));
      expect(id.length, 9); // lk- + 6 hex chars
      expect(RegExp(r'^lk-[0-9a-f]{6}$').hasMatch(id), isTrue);
    });

    test('same error produces same ID (deterministic)', () {
      final a = generateErrorId(error: StateError('test error'));
      final b = generateErrorId(error: StateError('test error'));
      expect(a, b);
    });

    test('different error types produce different IDs', () {
      final a = generateErrorId(error: StateError('msg'));
      final b = generateErrorId(error: ArgumentError('msg'));
      expect(a, isNot(b));
    });

    test('different messages produce different IDs', () {
      final a = generateErrorId(error: Exception('timeout'));
      final b = generateErrorId(error: Exception('network failure'));
      expect(a, isNot(b));
    });

    test('numeric variations in messages produce same ID', () {
      final a = generateErrorId(error: RangeError('index 5 out of range 10'));
      final b = generateErrorId(error: RangeError('index 3 out of range 8'));
      expect(a, b);
    });
  });

  group('Error ID in LogPilotRecord', () {
    test('error records have errorId', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.error('fail', error: StateError('bad'));

      final record = records.last;
      expect(record.errorId, isNotNull);
      expect(record.errorId, startsWith('lk-'));
    });

    test('fatal records have errorId', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.fatal('crash', error: UnimplementedError('x'));

      expect(records.last.errorId, isNotNull);
    });

    test('info records do not have errorId', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.info('just info');

      expect(records.last.errorId, isNull);
    });

    test('error without error object has no errorId', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.error('error message without error object');

      expect(records.last.errorId, isNull);
    });

    test('errorId appears in toJson()', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.error('boom', error: const FormatException('bad format'));

      final json = records.last.toJson();
      expect(json.containsKey('errorId'), isTrue);
      expect(json['errorId'], startsWith('lk-'));
    });

    test('errorId appears in toFormattedString()', () {
      final record = LogPilotRecord(
        level: LogLevel.error,
        timestamp: DateTime(2026, 3, 29),
        message: 'test',
        errorId: 'lk-abc123',
      );

      expect(record.toFormattedString(), contains('eid=lk-abc123'));
    });

    test('same error type/message gives same errorId across records', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.error('fail', error: StateError('timeout'));
      LogPilot.error('fail again', error: StateError('timeout'));

      expect(records[0].errorId, records[1].errorId);
    });
  });
}

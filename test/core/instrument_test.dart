import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  setUp(LogPilot.reset);
  tearDown(LogPilot.reset);

  group('LogPilot.instrument (sync)', () {
    test('returns the function result', () {
      final result = LogPilot.instrument('add', () => 2 + 3);
      expect(result, 5);
    });

    test('logs a debug record on success', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.instrument('op', () => 'hello');

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.debug);
      expect(records.first.message, contains('op completed in'));
      expect(records.first.tag, 'instrument');
      expect(records.first.metadata!['label'], 'op');
      expect(records.first.metadata!['result'], 'hello');
      expect(records.first.metadata!['elapsedMs'], isA<int>());
    });

    test('uses custom tag when provided', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.instrument('x', () => null, tag: 'custom');

      expect(records.first.tag, 'custom');
    });

    test('uses custom level when provided', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.instrument('x', () => 1, level: LogLevel.info);

      expect(records.first.level, LogLevel.info);
    });

    test('logs an error and rethrows on failure', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      expect(
        () => LogPilot.instrument('fail', () => throw StateError('bad')),
        throwsA(isA<StateError>()),
      );

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.error);
      expect(records.first.message, contains('fail failed after'));
      expect(records.first.error, isA<StateError>());
      expect(records.first.stackTrace, isNotNull);
      expect(records.first.metadata!['label'], 'fail');
    });

    test('preserves generic return type', () {
      final list = LogPilot.instrument<List<int>>('build', () => [1, 2, 3]);
      expect(list, [1, 2, 3]);
    });
  });

  group('LogPilot.instrumentAsync', () {
    test('returns the async result', () async {
      final result = await LogPilot.instrumentAsync(
        'fetch',
        () async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 42;
        },
      );
      expect(result, 42);
    });

    test('logs a debug record on async success', () async {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      await LogPilot.instrumentAsync('fetch', () async => 'data');

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.debug);
      expect(records.first.message, contains('fetch completed in'));
      expect(records.first.metadata!['result'], 'data');
    });

    test('logs error and rethrows on async failure', () async {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      await expectLater(
        LogPilot.instrumentAsync(
          'fail',
          () async => throw Exception('network'),
        ),
        throwsA(isA<Exception>()),
      );

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.error);
      expect(records.first.message, contains('fail failed after'));
      expect(records.first.error, isA<Exception>());
    });

    test('measures real elapsed time for async ops', () async {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      await LogPilot.instrumentAsync('slow', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      });

      final ms = records.first.metadata!['elapsedMs'] as int;
      expect(ms, greaterThanOrEqualTo(40));
    });

    test('uses custom tag and level', () async {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      await LogPilot.instrumentAsync(
        'op',
        () async => null,
        tag: 'perf',
        level: LogLevel.info,
      );

      expect(records.first.tag, 'perf');
      expect(records.first.level, LogLevel.info);
    });
  });
}

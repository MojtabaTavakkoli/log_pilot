import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  final List<LogPilotRecord> records = [];

  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    records.clear();
    LogPilot.configure(
      config: LogPilotConfig(
        enabled: false,
        sinks: [CallbackSink(records.add)],
      ),
    );
  });

  tearDown(LogPilot.reset);

  group('LogPilot.time / LogPilot.timeEnd', () {
    test('logs elapsed time on timeEnd', () async {
      LogPilot.time('fetchUsers');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final elapsed = LogPilot.timeEnd('fetchUsers');

      expect(elapsed, isNotNull);
      expect(elapsed!.inMilliseconds, greaterThanOrEqualTo(40));
      expect(records, hasLength(1));
      expect(records.first.message, contains('fetchUsers'));
      expect(records.first.message, contains('ms'));
      expect(records.first.tag, 'perf');
      expect(records.first.metadata!['label'], 'fetchUsers');
      expect(records.first.metadata!['elapsedMs'], greaterThanOrEqualTo(40));
      expect(records.first.metadata!['elapsedUs'], isNotNull);
    });

    test('returns null and warns when no matching time call', () {
      final elapsed = LogPilot.timeEnd('nonexistent');

      expect(elapsed, isNull);
      expect(records, hasLength(1));
      expect(records.first.message, contains('without a matching'));
    });

    test('supports custom level and tag', () {
      LogPilot.time('op');
      LogPilot.timeEnd('op', level: LogLevel.info, tag: 'db');

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.info);
      expect(records.first.tag, 'db');
    });

    test('multiple concurrent timers', () async {
      LogPilot.time('fast');
      LogPilot.time('slow');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final fastElapsed = LogPilot.timeEnd('fast');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final slowElapsed = LogPilot.timeEnd('slow');

      expect(fastElapsed, isNotNull);
      expect(slowElapsed, isNotNull);
      expect(slowElapsed!.inMilliseconds,
          greaterThan(fastElapsed!.inMilliseconds));
      expect(records, hasLength(2));
    });

    test('timeCancel removes timer without logging', () {
      LogPilot.time('cancelled');
      LogPilot.timeCancel('cancelled');

      expect(records, isEmpty);

      final elapsed = LogPilot.timeEnd('cancelled');
      expect(elapsed, isNull);
      expect(records, hasLength(1));
      expect(records.first.message, contains('without a matching'));
    });

    test('timeCancel logs verbose hint for nonexistent timers', () {
      LogPilot.timeCancel('doesNotExist');

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.verbose);
      expect(records.first.message, contains('doesNotExist'));
      expect(records.first.message, contains('without a matching'));
      expect(records.first.tag, 'perf');
    });

    test('same label can be reused after timeEnd', () {
      LogPilot.time('reuse');
      LogPilot.timeEnd('reuse');
      records.clear();

      LogPilot.time('reuse');
      final elapsed = LogPilot.timeEnd('reuse');

      expect(elapsed, isNotNull);
      expect(records, hasLength(1));
    });

    test('records go to history', () {
      LogPilot.configure(
        config: LogPilotConfig(
          enabled: false,
          maxHistorySize: 100,
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.time('historyTest');
      LogPilot.timeEnd('historyTest');

      final history = LogPilot.historyWhere(tag: 'perf');
      expect(history, isNotEmpty);
    });

    test('records include sessionId and traceId', () {
      LogPilot.setTraceId('timing-trace');
      LogPilot.time('traced');
      LogPilot.timeEnd('traced');

      expect(records.first.sessionId, isNotNull);
      expect(records.first.traceId, 'timing-trace');
      LogPilot.clearTraceId();
    });
  });

  group('LogPilot.withTimer', () {
    test('logs elapsed time on success', () async {
      final result = await LogPilot.withTimer(
        'fetchData',
        work: () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 42;
        },
      );

      expect(result, 42);
      expect(records, hasLength(1));
      expect(records.first.message, contains('fetchData'));
      expect(records.first.tag, 'perf');
      expect(records.first.metadata!['elapsedMs'], greaterThanOrEqualTo(40));
    });

    test('cancels timer and rethrows on exception', () async {
      await expectLater(
        LogPilot.withTimer(
          'willFail',
          work: () async => throw StateError('boom'),
        ),
        throwsStateError,
      );

      // timeCancel logs a verbose hint only if timer is missing;
      // on successful cancel it should be silent
      expect(records, isEmpty);
    });

    test('accepts custom level and tag', () async {
      await LogPilot.withTimer(
        'customOp',
        level: LogLevel.info,
        tag: 'API',
        work: () async => 'done',
      );

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.info);
      expect(records.first.tag, 'API');
    });
  });

  group('LogPilot.withTimerSync', () {
    test('logs elapsed time on success', () {
      final result = LogPilot.withTimerSync(
        'parseConfig',
        work: () {
          var sum = 0;
          for (var i = 0; i < 1000; i++) {
            sum += i;
          }
          return sum;
        },
      );

      expect(result, 499500);
      expect(records, hasLength(1));
      expect(records.first.message, contains('parseConfig'));
      expect(records.first.tag, 'perf');
    });

    test('cancels timer and rethrows on exception', () {
      expect(
        () => LogPilot.withTimerSync(
          'willFail',
          work: () => throw ArgumentError('bad'),
        ),
        throwsArgumentError,
      );

      expect(records, isEmpty);
    });
  });

  group('LogPilotLogger timing', () {
    test('prefixes label with tag', () {
      const log = LogPilotLogger('AuthService');
      log.time('signIn');
      log.timeEnd('signIn');

      expect(records, hasLength(1));
      expect(records.first.message, contains('AuthService/signIn'));
      expect(records.first.tag, 'AuthService');
    });

    test('timeCancel works with prefixed label', () {
      const log = LogPilotLogger('DB');
      log.time('query');
      log.timeCancel('query');

      expect(records, isEmpty);
    });

    test('withTimer prefixes label with tag', () async {
      const log = LogPilotLogger('Cart');
      await log.withTimer('checkout', work: () async => 'ok');

      expect(records, hasLength(1));
      expect(records.first.message, contains('Cart/checkout'));
      expect(records.first.tag, 'Cart');
    });

    test('withTimerSync prefixes label with tag', () {
      const log = LogPilotLogger('Auth');
      log.withTimerSync('hash', work: () => 'hashed');

      expect(records, hasLength(1));
      expect(records.first.message, contains('Auth/hash'));
      expect(records.first.tag, 'Auth');
    });
  });
}

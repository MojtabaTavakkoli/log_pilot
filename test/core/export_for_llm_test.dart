import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  setUp(LogPilot.reset);
  tearDown(LogPilot.reset);

  group('LogPilot.exportForLLM', () {
    test('returns empty string when no history', () {
      expect(LogPilot.exportForLLM(), '');
    });

    test('returns empty string when history is disabled', () {
      LogPilot.configure(config: const LogPilotConfig(maxHistorySize: 0));
      LogPilot.info('hello');
      expect(LogPilot.exportForLLM(), '');
    });

    test('includes header with total record count', () {
      LogPilot.configure();
      LogPilot.info('one');
      LogPilot.info('two');

      final result = LogPilot.exportForLLM();
      expect(result, contains('LogPilot summary (2 records)'));
    });

    test('prioritizes errors over other records', () {
      LogPilot.configure();
      LogPilot.info('normal');
      LogPilot.error('bad thing', error: Exception('oops'));
      LogPilot.info('another normal');

      final result = LogPilot.exportForLLM();
      final errorIdx = result.indexOf('[error]');
      final recentIdx = result.indexOf('--- recent');
      expect(errorIdx, lessThan(recentIdx));
    });

    test('separates errors, warnings, and recent', () {
      LogPilot.configure();
      LogPilot.error('e1', error: Exception('a'));
      LogPilot.warning('w1');
      LogPilot.info('i1');

      final result = LogPilot.exportForLLM();
      expect(result, contains('--- errors/fatal'));
      expect(result, contains('--- warnings'));
      expect(result, contains('--- recent'));
    });

    test('deduplicates consecutive identical messages', () {
      LogPilot.configure();
      for (var i = 0; i < 10; i++) {
        LogPilot.info('repeated msg');
      }

      final result = LogPilot.exportForLLM();
      expect(result, contains('(×10)'));
      // Should not contain 10 separate lines of the same message.
      final lines = result.split('\n')
          .where((l) => l.contains('repeated msg'))
          .toList();
      expect(lines, hasLength(1));
    });

    test('does not deduplicate non-consecutive messages', () {
      LogPilot.configure();
      LogPilot.info('aaa');
      LogPilot.info('bbb');
      LogPilot.info('aaa');

      final result = LogPilot.exportForLLM();
      // Both occurrences of 'aaa' should be present since they are
      // not consecutive.
      final lines = result.split('\n')
          .where((l) => l.contains('aaa'))
          .toList();
      expect(lines, hasLength(2));
    });

    test('truncates long messages to ~200 chars', () {
      LogPilot.configure();
      final longMsg = 'x' * 500;
      LogPilot.info(longMsg);

      final result = LogPilot.exportForLLM();
      expect(result, isNot(contains('x' * 500)));
      expect(result, contains('x' * 197));
      expect(result, contains('...'));
    });

    test('includes error IDs when present', () {
      LogPilot.configure();
      LogPilot.error('fail', error: Exception('kaboom'));

      final result = LogPilot.exportForLLM();
      expect(result, contains('lk-'));
    });

    test('includes tags in output', () {
      LogPilot.configure();
      LogPilot.info('tagged', tag: 'MyTag');

      final result = LogPilot.exportForLLM();
      expect(result, contains('[MyTag]'));
    });

    test('includes error description in output', () {
      LogPilot.configure();
      LogPilot.error('oops', error: Exception('socket timeout'));

      final result = LogPilot.exportForLLM();
      expect(result, contains('socket timeout'));
    });

    test('respects token budget', () {
      LogPilot.configure();
      for (var i = 0; i < 200; i++) {
        LogPilot.info('log entry number $i with some padding text');
      }

      // Very small budget: 100 tokens ≈ 400 chars
      final result = LogPilot.exportForLLM(tokenBudget: 100);
      expect(result.length, lessThanOrEqualTo(500));
    });

    test('larger budget includes more records', () {
      LogPilot.configure();
      for (var i = 0; i < 100; i++) {
        LogPilot.info('message $i');
      }

      final small = LogPilot.exportForLLM(tokenBudget: 200);
      final large = LogPilot.exportForLLM(tokenBudget: 4000);
      expect(large.length, greaterThan(small.length));
    });

    test('handles mixed levels correctly', () {
      LogPilot.configure();
      LogPilot.verbose('v');
      LogPilot.debug('d');
      LogPilot.info('i');
      LogPilot.warning('w');
      LogPilot.error('e', error: Exception('err'));
      LogPilot.fatal('f', error: Exception('fatal'));

      final result = LogPilot.exportForLLM();
      expect(result, contains('[ERROR]'));
      expect(result, contains('[FATAL]'));
      expect(result, contains('[WARNING]'));
      expect(result, contains('[INFO]'));
    });
  });
}

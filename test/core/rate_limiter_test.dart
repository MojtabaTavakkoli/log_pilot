import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/src/core/rate_limiter.dart';

void main() {
  group('RateLimiter unit', () {
    test('allows first occurrence', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      final result = limiter.check(LogLevel.info, 'hello');

      expect(result.action, RateLimitAction.allow);
      expect(result.suppressedCount, 0);
    });

    test('suppresses duplicate within window', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      limiter.check(LogLevel.info, 'hello');
      final result = limiter.check(LogLevel.info, 'hello');

      expect(result.action, RateLimitAction.suppress);
    });

    test('suppresses multiple duplicates', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      limiter.check(LogLevel.error, 'boom');
      limiter.check(LogLevel.error, 'boom');
      limiter.check(LogLevel.error, 'boom');
      final result = limiter.check(LogLevel.error, 'boom');

      expect(result.action, RateLimitAction.suppress);
    });

    test('different messages are tracked independently', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      final r1 = limiter.check(LogLevel.info, 'first');
      final r2 = limiter.check(LogLevel.info, 'second');

      expect(r1.action, RateLimitAction.allow);
      expect(r2.action, RateLimitAction.allow);
    });

    test('same message at different levels tracked independently', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      final r1 = limiter.check(LogLevel.info, 'msg');
      final r2 = limiter.check(LogLevel.error, 'msg');

      expect(r1.action, RateLimitAction.allow);
      expect(r2.action, RateLimitAction.allow);
    });

    test('reset clears all entries', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      limiter.check(LogLevel.info, 'hello');
      limiter.reset();
      final result = limiter.check(LogLevel.info, 'hello');

      expect(result.action, RateLimitAction.allow);
    });
  });

  group('RateLimiter.flushAll()', () {
    test('returns summaries for suppressed entries', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      limiter.check(LogLevel.info, 'repeated');
      limiter.check(LogLevel.info, 'repeated');
      limiter.check(LogLevel.info, 'repeated');

      final summaries = limiter.flushAll();

      expect(summaries, hasLength(1));
      expect(summaries.first.level, LogLevel.info);
      expect(summaries.first.message, 'repeated');
      expect(summaries.first.suppressedCount, 2);
    });

    test('does not return summaries for single-occurrence entries', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      limiter.check(LogLevel.info, 'once');

      final summaries = limiter.flushAll();

      expect(summaries, isEmpty);
    });

    test('clears entries after flush', () {
      final limiter = RateLimiter(const Duration(seconds: 5));
      limiter.check(LogLevel.info, 'x');
      limiter.check(LogLevel.info, 'x');
      limiter.flushAll();

      final result = limiter.check(LogLevel.info, 'x');
      expect(result.action, RateLimitAction.allow);
    });
  });

  group('Deduplication integration (LogPilot._log)', () {
    late List<LogPilotRecord> sinkRecords;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      sinkRecords = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          showCaller: false,
          deduplicateWindow: const Duration(seconds: 10),
          sinks: [CallbackSink((r) => sinkRecords.add(r))],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => sinkRecords.clear());
    tearDownAll(LogPilot.reset);

    test('sinks deduplicate identically to console', () {
      for (var i = 0; i < 5; i++) {
        LogPilot.error('same error');
      }

      // With sink deduplication enabled, only the first occurrence and
      // the summary pass through within the dedup window.
      expect(sinkRecords, hasLength(1));
      expect(sinkRecords.first.message, 'same error');
      expect(sinkRecords.first.level, LogLevel.error);
    });

    test('different messages still reach sinks independently', () {
      LogPilot.info('alpha');
      LogPilot.info('beta');
      LogPilot.info('alpha');

      // 'alpha' appears twice but the second is within the dedup window,
      // so the sink receives: alpha, beta (2 records).
      expect(sinkRecords, hasLength(2));
      expect(sinkRecords[0].message, 'alpha');
      expect(sinkRecords[1].message, 'beta');
    });
  });

  group('Deduplication disabled', () {
    late List<LogPilotRecord> sinkRecords;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      sinkRecords = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          showCaller: false,
          deduplicateWindow: Duration.zero,
          sinks: [CallbackSink((r) => sinkRecords.add(r))],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => sinkRecords.clear());
    tearDownAll(LogPilot.reset);

    test('all records pass through when dedup is off', () {
      LogPilot.info('same');
      LogPilot.info('same');
      LogPilot.info('same');

      expect(sinkRecords, hasLength(3));
    });
  });

  group('LogPilotConfig.deduplicateWindow', () {
    test('defaults to Duration.zero', () {
      const config = LogPilotConfig();
      expect(config.deduplicateWindow, Duration.zero);
    });

    test('debug preset defaults to Duration.zero', () {
      final config = LogPilotConfig.debug();
      expect(config.deduplicateWindow, Duration.zero);
    });

    test('staging preset defaults to 5 seconds', () {
      final config = LogPilotConfig.staging();
      expect(config.deduplicateWindow, const Duration(seconds: 5));
    });

    test('production preset defaults to 5 seconds', () {
      final config = LogPilotConfig.production();
      expect(config.deduplicateWindow, const Duration(seconds: 5));
    });

    test('copyWith preserves deduplicateWindow', () {
      const config = LogPilotConfig(
        deduplicateWindow: Duration(seconds: 3),
      );
      final copy = config.copyWith(logLevel: LogLevel.info);
      expect(copy.deduplicateWindow, const Duration(seconds: 3));
    });

    test('copyWith can override deduplicateWindow', () {
      const config = LogPilotConfig(
        deduplicateWindow: Duration(seconds: 3),
      );
      final copy = config.copyWith(
        deduplicateWindow: const Duration(seconds: 10),
      );
      expect(copy.deduplicateWindow, const Duration(seconds: 10));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  setUp(LogPilot.reset);
  tearDown(LogPilot.reset);

  group('LogPilot.logLevel', () {
    test('returns the current config log level', () {
      expect(LogPilot.logLevel, LogLevel.verbose);
    });

    test('reflects changes from configure()', () {
      LogPilot.configure(config: const LogPilotConfig(logLevel: LogLevel.warning));
      expect(LogPilot.logLevel, LogLevel.warning);
    });
  });

  group('LogPilot.setLogLevel', () {
    test('changes the effective log level', () {
      expect(LogPilot.logLevel, LogLevel.verbose);
      LogPilot.setLogLevel(LogLevel.error);
      expect(LogPilot.logLevel, LogLevel.error);
    });

    test('takes effect immediately for log filtering', () {
      LogPilot.configure(config: const LogPilotConfig(logLevel: LogLevel.verbose));

      LogPilot.info('should be recorded');
      expect(LogPilot.history, hasLength(1));

      LogPilot.setLogLevel(LogLevel.error);

      LogPilot.info('should be filtered out');
      expect(LogPilot.history, hasLength(1));

      LogPilot.error('should pass filter');
      expect(LogPilot.history, hasLength(2));
    });

    test('can lower the level after raising it', () {
      LogPilot.setLogLevel(LogLevel.fatal);
      LogPilot.info('filtered');
      expect(LogPilot.history, isEmpty);

      LogPilot.setLogLevel(LogLevel.verbose);
      LogPilot.info('passes');
      expect(LogPilot.history, hasLength(1));
    });

    test('preserves other config settings', () {
      LogPilot.configure(
        config: const LogPilotConfig(
          logLevel: LogLevel.info,
          showCaller: false,
          showTimestamp: false,
          maxHistorySize: 100,
        ),
      );

      LogPilot.setLogLevel(LogLevel.error);
      expect(LogPilot.config.showCaller, isFalse);
      expect(LogPilot.config.showTimestamp, isFalse);
      expect(LogPilot.config.maxHistorySize, 100);
      expect(LogPilot.logLevel, LogLevel.error);
    });

    test('snapshot reflects the new level', () {
      LogPilot.setLogLevel(LogLevel.warning);
      final snap = LogPilot.snapshot();
      final config = snap['config'] as Map<String, dynamic>;
      expect(config['logLevel'], 'WARNING');
    });
  });
}

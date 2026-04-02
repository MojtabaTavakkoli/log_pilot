import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogPilot.configure()', () {
    tearDown(LogPilot.reset);

    test('sets config without error zones', () {
      LogPilot.configure(config: const LogPilotConfig(
        logLevel: LogLevel.warning,
        showTimestamp: false,
        colorize: false,
      ));

      expect(LogPilot.config.logLevel, LogLevel.warning);
      expect(LogPilot.config.showTimestamp, isFalse);
      expect(LogPilot.config.colorize, isFalse);
    });

    test('logging works after configure', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(config: LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        sinks: [CallbackSink(records.add)],
      ));

      LogPilot.info('works without init');

      expect(records, hasLength(1));
      expect(records.first.message, 'works without init');
    });

    test('sinks work after configure', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(config: LogPilotConfig(
        enabled: false,
        logLevel: LogLevel.verbose,
        sinks: [CallbackSink(records.add)],
      ));

      LogPilot.info('sink only');

      expect(records, hasLength(1));
      expect(records.first.message, 'sink only');
    });
  });

  group('Zero-setup usage', () {
    test('LogPilot.info works with no init or configure', () {
      // Reset to defaults by configuring with a fresh config.
      LogPilot.configure(config: const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
      ));

      expect(
        () => LogPilot.info('just works'),
        returnsNormally,
      );
    });

    test('LogPilot.json works with no init or configure', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
      ));

      expect(
        () => LogPilot.json('{"key": "value"}'),
        returnsNormally,
      );
    });

    test('instance logger works with configure', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(config: LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        sinks: [CallbackSink(records.add)],
      ));

      final log = LogPilot.create('MyService');
      log.info('service started');

      expect(records, hasLength(1));
      expect(records.first.tag, 'MyService');
    });
  });
}

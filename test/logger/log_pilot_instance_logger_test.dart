import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogPilotLogger (instance)', () {
    late List<LogPilotRecord> records;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      records = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          sinks: [CallbackSink((r) => records.add(r))],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => records.clear());
    tearDownAll(LogPilot.reset);

    test('auto-applies tag to all log levels', () {
      const log = LogPilotLogger('AuthService');

      log.verbose('v');
      log.debug('d');
      log.info('i');
      log.warning('w');
      log.error('e');
      log.fatal('f');

      expect(records, hasLength(6));
      for (final r in records) {
        expect(r.tag, 'AuthService');
      }

      expect(records[0].level, LogLevel.verbose);
      expect(records[1].level, LogLevel.debug);
      expect(records[2].level, LogLevel.info);
      expect(records[3].level, LogLevel.warning);
      expect(records[4].level, LogLevel.error);
      expect(records[5].level, LogLevel.fatal);
    });

    test('LogPilot.create() returns a LogPilotLogger with the tag', () {
      final log = LogPilot.create('Checkout');

      expect(log, isA<LogPilotLogger>());
      expect(log.tag, 'Checkout');

      log.info('payment started');
      expect(records.first.tag, 'Checkout');
      expect(records.first.message, 'payment started');
    });

    test('passes metadata through', () {
      const log = LogPilotLogger('Cart');
      log.info('item added', metadata: {'sku': 'ABC-123'});

      expect(records.first.metadata, {'sku': 'ABC-123'});
    });

    test('passes error and stackTrace through', () {
      const log = LogPilotLogger('Net');
      final err = Exception('timeout');
      final stack = StackTrace.current;
      log.error('request failed', error: err, stackTrace: stack);

      expect(records.first.error, err);
      expect(records.first.stackTrace, stack);
    });

    test('json delegates with tag', () {
      const log = LogPilotLogger('API');
      log.json('{"status":"ok"}');

      expect(records.first.tag, 'API');
      expect(records.first.message, '{"status":"ok"}');
    });

    test('supports lazy message evaluation', () {
      const log = LogPilotLogger('Perf');
      var called = false;

      log.info(() {
        called = true;
        return 'computed';
      });

      expect(called, isTrue);
      expect(records.first.message, 'computed');
    });
  });

  group('LogPilotConfig presets', () {
    test('debug() enables everything at verbose', () {
      final config = LogPilotConfig.debug();

      expect(config.enabled, isTrue);
      expect(config.logLevel, LogLevel.verbose);
      expect(config.showCaller, isTrue);
      expect(config.showDetails, isTrue);
      expect(config.colorize, isTrue);
      expect(config.showTimestamp, isTrue);
    });

    test('staging() uses info level with compact output', () {
      final config = LogPilotConfig.staging();

      expect(config.enabled, isTrue);
      expect(config.logLevel, LogLevel.info);
      expect(config.showDetails, isFalse);
      expect(config.showCaller, isTrue);
    });

    test('production() disables console, warning+ level', () {
      final config = LogPilotConfig.production();

      expect(config.enabled, isFalse);
      expect(config.logLevel, LogLevel.warning);
      expect(config.showCaller, isFalse);
      expect(config.colorize, isFalse);
      expect(config.showDetails, isFalse);
      expect(config.showTimestamp, isFalse);
    });

    test('production() accepts sinks', () {
      final sink = CallbackSink((_) {});
      final config = LogPilotConfig.production(sinks: [sink]);

      expect(config.sinks, hasLength(1));
      expect(config.enabled, isFalse);
    });

    test('copyWith preserves sinks', () {
      final sink = CallbackSink((_) {});
      final original = LogPilotConfig(sinks: [sink]);
      final copied = original.copyWith(logLevel: LogLevel.error);

      expect(copied.sinks, hasLength(1));
      expect(copied.logLevel, LogLevel.error);
    });
  });

  group('LogPilotRecord', () {
    test('toString is readable', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'hello',
        tag: 'test',
      );

      expect(record.toString(), contains('info'));
      expect(record.toString(), contains('hello'));
      expect(record.toString(), contains('test'));
    });

    test('fields are preserved', () {
      final error = Exception('err');
      final stack = StackTrace.current;
      final now = DateTime.now();

      final record = LogPilotRecord(
        level: LogLevel.error,
        timestamp: now,
        message: 'msg',
        tag: 'tag',
        caller: 'package:app/main.dart:10:5',
        metadata: const {'k': 'v'},
        error: error,
        stackTrace: stack,
      );

      expect(record.level, LogLevel.error);
      expect(record.timestamp, now);
      expect(record.message, 'msg');
      expect(record.tag, 'tag');
      expect(record.caller, 'package:app/main.dart:10:5');
      expect(record.metadata, {'k': 'v'});
      expect(record.error, error);
      expect(record.stackTrace, stack);
    });
  });
}

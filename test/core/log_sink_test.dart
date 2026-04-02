import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('CallbackSink unit', () {
    test('calls the callback with the record', () {
      LogPilotRecord? received;
      final sink = CallbackSink((r) => received = r);

      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'hello',
      );

      sink.onLog(record);

      expect(received, isNotNull);
      expect(received!.level, LogLevel.info);
      expect(received!.message, 'hello');
    });
  });

  group('LogSink dispatch (integration)', () {
    late List<LogPilotRecord> records;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      records = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          sinks: [CallbackSink((record) => records.add(record))],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => records.clear());
    tearDownAll(LogPilot.reset);

    test('receives log records from LogPilot.info()', () {
      LogPilot.info('test message', metadata: {'key': 'value'});

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.info);
      expect(records.first.message, 'test message');
      expect(records.first.metadata, {'key': 'value'});
      expect(records.first.timestamp, isA<DateTime>());
    });

    test('receives records for all log levels', () {
      LogPilot.verbose('v');
      LogPilot.debug('d');
      LogPilot.info('i');
      LogPilot.warning('w');
      LogPilot.error('e');
      LogPilot.fatal('f');

      expect(records, hasLength(6));
      expect(records.map((r) => r.level).toList(), [
        LogLevel.verbose,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
        LogLevel.fatal,
      ]);
    });

    test('receives json logs', () {
      LogPilot.json('{"user": "Alice"}', tag: 'api');

      expect(records, hasLength(1));
      expect(records.first.message, '{"user": "Alice"}');
      expect(records.first.tag, 'api');
    });

    test('includes error and stackTrace in records', () {
      final error = Exception('boom');
      final stack = StackTrace.current;
      LogPilot.error('failed', error: error, stackTrace: stack);

      expect(records, hasLength(1));
      expect(records.first.error, error);
      expect(records.first.stackTrace, stack);
    });

    test('includes tag in records', () {
      LogPilot.info('tagged', tag: 'checkout');

      expect(records, hasLength(1));
      expect(records.first.tag, 'checkout');
    });
  });

  group('Sink dispatch with console disabled', () {
    late List<LogPilotRecord> records;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      records = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: false,
          logLevel: LogLevel.verbose,
          sinks: [CallbackSink((record) => records.add(record))],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => records.clear());
    tearDownAll(LogPilot.reset);

    test('sinks still receive records when console is disabled', () {
      LogPilot.warning('should reach sink');

      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.warning);
      expect(records.first.message, 'should reach sink');
    });
  });

  group('Lazy message evaluation', () {
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

    test('String Function() is resolved when log passes filter', () {
      var called = false;

      LogPilot.info(() {
        called = true;
        return 'lazy message';
      });

      expect(called, isTrue);
      expect(records.first.message, 'lazy message');
    });

    test('plain String still works', () {
      LogPilot.info('plain string');
      expect(records.first.message, 'plain string');
    });
  });

  group('Lazy message skipped when filtered', () {
    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      LogPilot.init(
        config: const LogPilotConfig(
          enabled: false,
          logLevel: LogLevel.error,
        ),
        child: const SizedBox.shrink(),
      );
    });

    tearDownAll(LogPilot.reset);

    test('String Function() is NOT called when filtered by level', () {
      var called = false;

      LogPilot.debug(() {
        called = true;
        return 'expensive computation';
      });

      expect(called, isFalse);
    });
  });

  group('Multiple sinks', () {
    late List<LogPilotRecord> sink1;
    late List<LogPilotRecord> sink2;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      sink1 = [];
      sink2 = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          sinks: [
            CallbackSink((r) => sink1.add(r)),
            CallbackSink((r) => sink2.add(r)),
          ],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() {
      sink1.clear();
      sink2.clear();
    });

    tearDownAll(LogPilot.reset);

    test('all sinks receive the same records', () {
      LogPilot.info('broadcast');

      expect(sink1, hasLength(1));
      expect(sink2, hasLength(1));
      expect(sink1.first.message, 'broadcast');
      expect(sink2.first.message, 'broadcast');
    });
  });

  group('Sink error isolation', () {
    late List<LogPilotRecord> healthy;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      healthy = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: false,
          logLevel: LogLevel.verbose,
          sinks: [
            CallbackSink((_) => throw Exception('I am broken')),
            CallbackSink((r) => healthy.add(r)),
          ],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => healthy.clear());
    tearDownAll(LogPilot.reset);

    test('throwing sink does not prevent subsequent sinks from receiving', () {
      LogPilot.info('survives');

      expect(healthy, hasLength(1));
      expect(healthy.first.message, 'survives');
    });

    test('multiple records still dispatched after sink throws', () {
      LogPilot.info('first');
      LogPilot.warning('second');

      expect(healthy, hasLength(2));
      expect(healthy[0].message, 'first');
      expect(healthy[1].message, 'second');
    });
  });
}

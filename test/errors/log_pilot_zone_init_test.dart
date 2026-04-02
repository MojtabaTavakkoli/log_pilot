import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogPilotZone.init integration', () {
    late List<LogPilotRecord> sinkRecords;
    late List<Object> errorCallbackErrors;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      sinkRecords = [];
      errorCallbackErrors = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          sinks: [CallbackSink((r) => sinkRecords.add(r))],
        ),
        onError: (error, stack) => errorCallbackErrors.add(error),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() {
      sinkRecords.clear();
      errorCallbackErrors.clear();
      LogPilot.clearHistory();
      LogPilot.clearBreadcrumbs();
    });

    tearDownAll(LogPilot.reset);

    test('sessionId is non-empty after init', () {
      expect(LogPilot.sessionId, isNotEmpty);
    });

    test('sessionId is included in records', () {
      LogPilot.info('session check');
      expect(sinkRecords, hasLength(1));
      expect(sinkRecords.first.sessionId, equals(LogPilot.sessionId));
    });

    test('config is accessible after init', () {
      expect(LogPilot.config.logLevel, LogLevel.verbose);
      expect(LogPilot.config.enabled, isTrue);
    });

    test('sinks receive records through LogPilot.init', () {
      LogPilot.info('init sink test');
      expect(sinkRecords, hasLength(1));
      expect(sinkRecords.first.message, 'init sink test');
    });

    test('error records include errorId', () {
      try {
        throw StateError('test error');
      } catch (e, st) {
        LogPilot.error('err', error: e, stackTrace: st);
      }

      expect(sinkRecords, hasLength(1));
      expect(sinkRecords.first.errorId, isNotNull);
      expect(sinkRecords.first.errorId, startsWith('lk-'));
    });

    test('history works after init', () {
      LogPilot.info('history check');
      final history = LogPilot.history;
      expect(history, isNotEmpty);
      expect(history.last.message, 'history check');
    });

    test('traceId is carried in records when set', () {
      LogPilot.setTraceId('req-123');
      LogPilot.info('traced');
      LogPilot.clearTraceId();

      expect(sinkRecords, hasLength(1));
      expect(sinkRecords.first.traceId, 'req-123');
    });

    test('breadcrumbs are attached to error records', () {
      LogPilot.addBreadcrumb('step 1');
      LogPilot.addBreadcrumb('step 2');

      try {
        throw StateError('crash');
      } catch (e, st) {
        LogPilot.error('crashed', error: e, stackTrace: st);
      }

      expect(sinkRecords, hasLength(1));
      expect(sinkRecords.first.breadcrumbs, isNotNull);
      expect(sinkRecords.first.breadcrumbs!.length, greaterThanOrEqualTo(2));
    });

    test('setLogLevel changes the effective level at runtime', () {
      LogPilot.setLogLevel(LogLevel.error);
      LogPilot.info('should be filtered');
      expect(sinkRecords, isEmpty);

      LogPilot.error('should arrive');
      expect(sinkRecords, hasLength(1));

      LogPilot.setLogLevel(LogLevel.verbose);
    });

    test('clearHistory empties the ring buffer', () {
      LogPilot.info('before clear');
      expect(LogPilot.history, isNotEmpty);

      LogPilot.clearHistory();
      expect(LogPilot.history, isEmpty);
    });

    test('reset restores defaults', () {
      final oldSession = LogPilot.sessionId;
      LogPilot.reset();

      expect(LogPilot.sessionId, isNot(equals(oldSession)));
      expect(LogPilot.traceId, isNull);

      sinkRecords = [];
      errorCallbackErrors = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
          sinks: [CallbackSink((r) => sinkRecords.add(r))],
        ),
        onError: (error, stack) => errorCallbackErrors.add(error),
        child: const SizedBox.shrink(),
      );
    });

    test('onError callback is invoked for FlutterError', () {
      final details = FlutterErrorDetails(
        exception: StateError('callback test'),
        stack: StackTrace.current,
        library: 'test',
      );

      FlutterError.onError?.call(details);

      expect(errorCallbackErrors, isNotEmpty);
      expect(errorCallbackErrors.first, isA<StateError>());
    });
  });

  group('LogPilotZone.init error dispatch to sinks', () {
    late List<LogPilotRecord> sinkRecords;

    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      sinkRecords = [];
      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          sinks: [CallbackSink((r) => sinkRecords.add(r))],
        ),
        child: const SizedBox.shrink(),
      );
    });

    setUp(() => sinkRecords.clear());

    tearDownAll(LogPilot.reset);

    test('FlutterError.onError dispatches to sinks', () {
      final details = FlutterErrorDetails(
        exception: StateError('flutter error test'),
        stack: StackTrace.current,
        library: 'test',
      );

      FlutterError.onError?.call(details);

      final errorRecords =
          sinkRecords.where((r) => r.error != null).toList();
      expect(errorRecords, isNotEmpty);
    });
  });

  group('LogPilotZone.init with AsyncLogSink', () {
    tearDownAll(LogPilot.reset);

    test('records from init reach AsyncLogSink', () async {
      WidgetsFlutterBinding.ensureInitialized();
      final batches = <List<LogPilotRecord>>[];

      LogPilot.init(
        config: LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          sinks: [AsyncLogSink(flush: batches.add)],
        ),
        child: const SizedBox.shrink(),
      );

      LogPilot.info('async sink test');
      LogPilot.warning('async sink warning');

      await Future<void>.delayed(Duration.zero);

      expect(batches, isNotEmpty);
      final allMessages =
          batches.expand((b) => b).map((r) => r.message).toList();
      expect(allMessages, contains('async sink test'));
      expect(allMessages, contains('async sink warning'));
    });
  });
}

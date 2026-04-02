import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogPilot.snapshot', () {
    setUp(() {
      LogPilot.reset();
      LogPilot.configure(config: const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        colorize: false,
      ));
    });

    tearDown(LogPilot.reset);

    test('returns a map with required keys', () {
      final snap = LogPilot.snapshot();

      expect(snap, containsPair('timestamp', isA<String>()));
      expect(snap, containsPair('sessionId', isA<String>()));
      expect(snap, containsPair('config', isA<Map>()));
      expect(snap, containsPair('history', isA<Map>()));
      expect(snap, containsPair('recentErrors', isA<List>()));
      expect(snap, containsPair('recentLogs', isA<List>()));
      expect(snap, containsPair('activeTimers', isA<List>()));
    });

    test('config section reflects current configuration', () {
      final snap = LogPilot.snapshot();
      final config = snap['config'] as Map<String, dynamic>;

      expect(config['enabled'], isTrue);
      expect(config['logLevel'], 'VERBOSE');
      expect(config['outputFormat'], 'pretty');
    });

    test('history counts match logged records', () {
      LogPilot.info('msg1');
      LogPilot.warning('msg2');
      LogPilot.error('msg3');
      LogPilot.info('msg4');

      final snap = LogPilot.snapshot();
      final history = snap['history'] as Map<String, dynamic>;

      expect(history['total'], 4);
      expect(history['INFO'], 2);
      expect(history['WARNING'], 1);
      expect(history['ERROR'], 1);
    });

    test('recentErrors contains only error/fatal records', () {
      LogPilot.info('ok');
      LogPilot.error('err1');
      LogPilot.fatal('fatal1');
      LogPilot.debug('fine');
      LogPilot.error('err2');

      final snap = LogPilot.snapshot();
      final errors = snap['recentErrors'] as List;

      expect(errors.length, 3);
      for (final e in errors) {
        final level = (e as Map)['level'] as String;
        expect(level, anyOf('ERROR', 'FATAL'));
      }
    });

    test('recentErrors respects maxRecentErrors', () {
      for (var i = 0; i < 10; i++) {
        LogPilot.error('error $i');
      }

      final snap = LogPilot.snapshot(maxRecentErrors: 3);
      final errors = snap['recentErrors'] as List;

      expect(errors.length, 3);
      expect((errors.last as Map)['message'], 'error 9');
    });

    test('recentLogs respects maxRecentLogs', () {
      for (var i = 0; i < 20; i++) {
        LogPilot.info('msg $i');
      }

      final snap = LogPilot.snapshot(maxRecentLogs: 5);
      final logs = snap['recentLogs'] as List;

      expect(logs.length, 5);
      expect((logs.last as Map)['message'], 'msg 19');
    });

    test('activeTimers includes running timers', () {
      LogPilot.time('fetchData');
      LogPilot.time('renderUI');

      final snap = LogPilot.snapshot();
      final timers = snap['activeTimers'] as List;

      expect(timers, containsAll(['fetchData', 'renderUI']));

      LogPilot.timeCancel('fetchData');
      LogPilot.timeCancel('renderUI');
    });

    test('traceId appears when set', () {
      LogPilot.setTraceId('req-123');
      final snap = LogPilot.snapshot();
      expect(snap['traceId'], 'req-123');
      LogPilot.clearTraceId();
    });

    test('traceId absent when not set', () {
      final snap = LogPilot.snapshot();
      expect(snap.containsKey('traceId'), isFalse);
    });

    test('empty history returns zeroed counts', () {
      final snap = LogPilot.snapshot();
      final history = snap['history'] as Map<String, dynamic>;

      expect(history['total'], 0);
    });

    test('snapshotAsJson returns valid JSON', () {
      LogPilot.info('test');
      final jsonStr = LogPilot.snapshotAsJson();
      final decoded = jsonDecode(jsonStr);
      expect(decoded, isA<Map>());
      expect(decoded['sessionId'], isNotNull);
    });
  });
}

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogHistory', () {
    late LogHistory history;

    setUp(() {
      history = LogHistory(5);
    });

    LogPilotRecord makeRecord({
      LogLevel level = LogLevel.info,
      String? message,
      String? tag,
    }) {
      return LogPilotRecord(
        level: level,
        timestamp: DateTime(2026, 3, 28, 14, 0),
        message: message ?? 'test',
        tag: tag,
      );
    }

    test('starts empty', () {
      expect(history.isEmpty, isTrue);
      expect(history.isNotEmpty, isFalse);
      expect(history.length, 0);
      expect(history.records, isEmpty);
    });

    test('add records and read them back', () {
      history.add(makeRecord(message: 'a'));
      history.add(makeRecord(message: 'b'));

      expect(history.length, 2);
      expect(history.records[0].message, 'a');
      expect(history.records[1].message, 'b');
    });

    test('evicts oldest when buffer is full', () {
      for (var i = 0; i < 7; i++) {
        history.add(makeRecord(message: 'msg-$i'));
      }

      expect(history.length, 5);
      expect(history.records.first.message, 'msg-2');
      expect(history.records.last.message, 'msg-6');
    });

    test('records returns an unmodifiable list', () {
      history.add(makeRecord());
      final list = history.records;
      expect(() => list.add(makeRecord()), throwsA(isA<UnsupportedError>()));
    });

    test('clear empties the buffer', () {
      history.add(makeRecord());
      history.add(makeRecord());
      history.clear();

      expect(history.isEmpty, isTrue);
      expect(history.length, 0);
    });

    test('where filters by level', () {
      history.add(makeRecord(level: LogLevel.debug, message: 'low'));
      history.add(makeRecord(level: LogLevel.error, message: 'high'));
      history.add(makeRecord(level: LogLevel.info, message: 'mid'));

      final errors = history.where(level: LogLevel.error);
      expect(errors.length, 1);
      expect(errors.first.message, 'high');
    });

    test('where filters by tag', () {
      history.add(makeRecord(tag: 'auth', message: 'a'));
      history.add(makeRecord(tag: 'checkout', message: 'b'));
      history.add(makeRecord(message: 'c'));

      final auth = history.where(tag: 'auth');
      expect(auth.length, 1);
      expect(auth.first.message, 'a');
    });

    test('where filters by level and tag combined', () {
      history.add(
          makeRecord(level: LogLevel.error, tag: 'auth', message: 'err'));
      history.add(
          makeRecord(level: LogLevel.info, tag: 'auth', message: 'info'));
      history.add(
          makeRecord(level: LogLevel.error, tag: 'cart', message: 'other'));

      final result = history.where(level: LogLevel.error, tag: 'auth');
      expect(result.length, 1);
      expect(result.first.message, 'err');
    });

    group('enhanced where filters', () {
      LogPilotRecord makeFullRecord({
        LogLevel level = LogLevel.info,
        String? message,
        String? tag,
        String? traceId,
        Object? error,
        DateTime? timestamp,
        Map<String, dynamic>? metadata,
      }) {
        return LogPilotRecord(
          level: level,
          timestamp: timestamp ?? DateTime(2026, 3, 28, 14, 0),
          message: message ?? 'test',
          tag: tag,
          traceId: traceId,
          error: error,
          metadata: metadata,
        );
      }

      test('messageContains is case-insensitive', () {
        history.add(makeFullRecord(message: 'User Signed In'));
        history.add(makeFullRecord(message: 'cart updated'));

        final results = history.where(messageContains: 'signed in');
        expect(results, hasLength(1));
        expect(results.first.message, 'User Signed In');
      });

      test('messageContains skips null messages', () {
        history.add(makeFullRecord(message: null));
        history.add(makeFullRecord(message: 'hello world'));

        final results = history.where(messageContains: 'hello');
        expect(results, hasLength(1));
      });

      test('traceId filters by exact match', () {
        history.add(makeFullRecord(traceId: 'req-1', message: 'a'));
        history.add(makeFullRecord(traceId: 'req-2', message: 'b'));
        history.add(makeFullRecord(message: 'c'));

        final results = history.where(traceId: 'req-1');
        expect(results, hasLength(1));
        expect(results.first.message, 'a');
      });

      test('hasError: true returns only records with errors', () {
        history.add(makeFullRecord(message: 'ok'));
        history.add(makeFullRecord(
          message: 'fail',
          error: Exception('boom'),
        ));

        final results = history.where(hasError: true);
        expect(results, hasLength(1));
        expect(results.first.message, 'fail');
      });

      test('hasError: false returns only records without errors', () {
        history.add(makeFullRecord(message: 'ok'));
        history.add(makeFullRecord(
          message: 'fail',
          error: Exception('boom'),
        ));

        final results = history.where(hasError: false);
        expect(results, hasLength(1));
        expect(results.first.message, 'ok');
      });

      test('after filters by timestamp', () {
        final t1 = DateTime(2026, 3, 28, 10, 0);
        final t2 = DateTime(2026, 3, 28, 14, 0);
        final t3 = DateTime(2026, 3, 28, 18, 0);

        history.add(makeFullRecord(timestamp: t1, message: 'morning'));
        history.add(makeFullRecord(timestamp: t2, message: 'afternoon'));
        history.add(makeFullRecord(timestamp: t3, message: 'evening'));

        final results = history.where(after: DateTime(2026, 3, 28, 12, 0));
        expect(results, hasLength(2));
        expect(results.map((r) => r.message), ['afternoon', 'evening']);
      });

      test('before filters by timestamp', () {
        final t1 = DateTime(2026, 3, 28, 10, 0);
        final t2 = DateTime(2026, 3, 28, 14, 0);
        final t3 = DateTime(2026, 3, 28, 18, 0);

        history.add(makeFullRecord(timestamp: t1, message: 'morning'));
        history.add(makeFullRecord(timestamp: t2, message: 'afternoon'));
        history.add(makeFullRecord(timestamp: t3, message: 'evening'));

        final results = history.where(before: DateTime(2026, 3, 28, 15, 0));
        expect(results, hasLength(2));
        expect(results.map((r) => r.message), ['morning', 'afternoon']);
      });

      test('after and before define a time window', () {
        final t1 = DateTime(2026, 3, 28, 10, 0);
        final t2 = DateTime(2026, 3, 28, 14, 0);
        final t3 = DateTime(2026, 3, 28, 18, 0);

        history.add(makeFullRecord(timestamp: t1, message: 'morning'));
        history.add(makeFullRecord(timestamp: t2, message: 'afternoon'));
        history.add(makeFullRecord(timestamp: t3, message: 'evening'));

        final results = history.where(
          after: DateTime(2026, 3, 28, 12, 0),
          before: DateTime(2026, 3, 28, 16, 0),
        );
        expect(results, hasLength(1));
        expect(results.first.message, 'afternoon');
      });

      test('metadataKey filters by key presence', () {
        history.add(makeFullRecord(
          message: 'with-key',
          metadata: {'userId': '42', 'role': 'admin'},
        ));
        history.add(makeFullRecord(
          message: 'other-key',
          metadata: {'orderId': '99'},
        ));
        history.add(makeFullRecord(message: 'no-metadata'));

        final results = history.where(metadataKey: 'userId');
        expect(results, hasLength(1));
        expect(results.first.message, 'with-key');
      });

      test('all filters combine with AND logic', () {
        history.add(makeFullRecord(
          level: LogLevel.error,
          tag: 'auth',
          message: 'login failed',
          traceId: 'req-1',
          error: Exception('bad creds'),
          metadata: {'userId': '42'},
          timestamp: DateTime(2026, 3, 28, 14, 0),
        ));
        history.add(makeFullRecord(
          level: LogLevel.error,
          tag: 'auth',
          message: 'login failed',
          traceId: 'req-2',
          error: Exception('bad creds'),
          metadata: {'userId': '99'},
          timestamp: DateTime(2026, 3, 28, 14, 0),
        ));

        final results = history.where(
          level: LogLevel.error,
          tag: 'auth',
          messageContains: 'login',
          traceId: 'req-1',
          hasError: true,
          metadataKey: 'userId',
        );
        expect(results, hasLength(1));
        expect(results.first.traceId, 'req-1');
      });

      test('no filters returns all records', () {
        history.add(makeFullRecord(message: 'a'));
        history.add(makeFullRecord(message: 'b'));

        final results = history.where();
        expect(results, hasLength(2));
      });
    });

    test('exportAsText produces one line per record', () {
      history.add(makeRecord(level: LogLevel.info, message: 'hello'));
      history.add(makeRecord(level: LogLevel.error, message: 'oops'));

      final text = history.exportAsText();
      final lines = text.split('\n');
      expect(lines.length, 2);
      expect(lines[0], contains('[INFO]'));
      expect(lines[0], contains('hello'));
      expect(lines[1], contains('[ERROR]'));
      expect(lines[1], contains('oops'));
    });

    test('exportAsJson produces valid NDJSON', () {
      history.add(makeRecord(level: LogLevel.info, message: 'line1'));
      history.add(makeRecord(level: LogLevel.warning, message: 'line2'));

      final json = history.exportAsJson();
      final lines = json.split('\n');
      expect(lines.length, 2);

      final parsed1 = jsonDecode(lines[0]) as Map<String, dynamic>;
      expect(parsed1['level'], 'INFO');
      expect(parsed1['message'], 'line1');

      final parsed2 = jsonDecode(lines[1]) as Map<String, dynamic>;
      expect(parsed2['level'], 'WARNING');
      expect(parsed2['message'], 'line2');
    });

    test('ring buffer maintains maxSize invariant under stress', () {
      final small = LogHistory(3);
      for (var i = 0; i < 1000; i++) {
        small.add(makeRecord(message: 'iter-$i'));
      }

      expect(small.length, 3);
      expect(small.records.first.message, 'iter-997');
      expect(small.records.last.message, 'iter-999');
    });
  });

  group('LogPilot.history integration', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 10,
      ));
    });

    tearDown(LogPilot.reset);

    test('LogPilot.history returns logged records', () {
      LogPilot.clearHistory();
      LogPilot.info('recorded');

      expect(LogPilot.history, isNotEmpty);
      expect(LogPilot.history.last.message, 'recorded');
    });

    test('LogPilot.historyWhere filters by level', () {
      LogPilot.clearHistory();
      LogPilot.debug('low');
      LogPilot.error('high');

      final errors = LogPilot.historyWhere(level: LogLevel.error);
      expect(errors.length, 1);
      expect(errors.first.message, 'high');
    });

    test('LogPilot.export returns formatted text', () {
      LogPilot.clearHistory();
      LogPilot.info('export-me');

      final text = LogPilot.export();
      expect(text, contains('[INFO]'));
      expect(text, contains('export-me'));
    });

    test('LogPilot.export with json format returns NDJSON', () {
      LogPilot.clearHistory();
      LogPilot.warning('json-test');

      final json = LogPilot.export(format: ExportFormat.json);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed['level'], 'WARNING');
      expect(parsed['message'], 'json-test');
    });

    test('LogPilot.clearHistory empties the buffer', () {
      LogPilot.info('before-clear');
      LogPilot.clearHistory();

      expect(LogPilot.history, isEmpty);
    });

    test('history respects maxHistorySize from config', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 3,
      ));

      for (var i = 0; i < 10; i++) {
        LogPilot.info('msg-$i');
      }

      expect(LogPilot.history.length, 3);
      expect(LogPilot.history.first.message, 'msg-7');
    });

    test('history is empty list when maxHistorySize is 0', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 0,
      ));

      LogPilot.info('should-not-appear');
      expect(LogPilot.history, isEmpty);
    });

    test('json logs are captured in history', () {
      LogPilot.clearHistory();
      LogPilot.json('{"key":"value"}');

      expect(LogPilot.history, isNotEmpty);
      expect(LogPilot.history.last.message, '{"key":"value"}');
    });

    test('LogPilot.historyWhere filters by messageContains', () {
      LogPilot.clearHistory();
      LogPilot.info('user signed in');
      LogPilot.info('cart updated');

      final results = LogPilot.historyWhere(messageContains: 'signed');
      expect(results, hasLength(1));
      expect(results.first.message, 'user signed in');
    });

    test('LogPilot.historyWhere filters by metadata key', () {
      LogPilot.clearHistory();
      LogPilot.info('with uid', metadata: {'userId': '42'});
      LogPilot.info('without uid');

      final results = LogPilot.historyWhere(metadataKey: 'userId');
      expect(results, hasLength(1));
      expect(results.first.message, 'with uid');
    });

    test('LogPilot.historyWhere filters by hasError', () {
      LogPilot.clearHistory();
      LogPilot.info('ok');
      LogPilot.error('broken', error: Exception('x'));

      expect(LogPilot.historyWhere(hasError: true), hasLength(1));
      expect(LogPilot.historyWhere(hasError: false), hasLength(1));
      expect(LogPilot.historyWhere(hasError: true).first.message, 'broken');
    });
  });

  group('LogPilotConfig.maxHistorySize', () {
    test('default is 500', () {
      expect(const LogPilotConfig().maxHistorySize, 500);
    });

    test('debug factory default is 500', () {
      expect(LogPilotConfig.debug().maxHistorySize, 500);
    });

    test('staging factory default is 500', () {
      expect(LogPilotConfig.staging().maxHistorySize, 500);
    });

    test('production factory default is 500', () {
      expect(LogPilotConfig.production().maxHistorySize, 500);
    });

    test('copyWith preserves maxHistorySize', () {
      const config = LogPilotConfig(maxHistorySize: 200);
      final copy = config.copyWith(logLevel: LogLevel.error);
      expect(copy.maxHistorySize, 200);
    });

    test('copyWith overrides maxHistorySize', () {
      const config = LogPilotConfig(maxHistorySize: 200);
      final copy = config.copyWith(maxHistorySize: 1000);
      expect(copy.maxHistorySize, 1000);
    });
  });
}

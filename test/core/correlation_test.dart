import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('Session ID', () {
    setUp(WidgetsFlutterBinding.ensureInitialized);

    tearDown(LogPilot.reset);

    test('sessionId is auto-generated on configure', () {
      LogPilot.configure(config: const LogPilotConfig(enabled: false));
      final id = LogPilot.sessionId;
      expect(id, isNotEmpty);
      expect(id.length, 36);
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('sessionId changes on each configure call', () {
      LogPilot.configure(config: const LogPilotConfig(enabled: false));
      final id1 = LogPilot.sessionId;

      LogPilot.configure(config: const LogPilotConfig(enabled: false));
      final id2 = LogPilot.sessionId;

      expect(id1, isNot(equals(id2)));
    });

    test('sessionId is included in LogPilotRecord', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 10,
      ));
      LogPilot.clearHistory();

      LogPilot.info('with-session');

      final record = LogPilot.history.last;
      expect(record.sessionId, equals(LogPilot.sessionId));
    });

    test('sessionId is included in json log records', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 10,
      ));
      LogPilot.clearHistory();

      LogPilot.json('{"key": "value"}');

      final record = LogPilot.history.last;
      expect(record.sessionId, equals(LogPilot.sessionId));
    });
  });

  group('Trace ID', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 10,
      ));
      LogPilot.clearHistory();
      LogPilot.clearTraceId();
    });

    tearDown(LogPilot.reset);

    test('traceId is null by default', () {
      expect(LogPilot.traceId, isNull);
    });

    test('setTraceId sets the ambient trace ID', () {
      LogPilot.setTraceId('req-123');
      expect(LogPilot.traceId, 'req-123');
    });

    test('clearTraceId clears the ambient trace ID', () {
      LogPilot.setTraceId('req-123');
      LogPilot.clearTraceId();
      expect(LogPilot.traceId, isNull);
    });

    test('logs include traceId when set', () {
      LogPilot.setTraceId('req-abc');
      LogPilot.info('traced');

      final record = LogPilot.history.last;
      expect(record.traceId, 'req-abc');
    });

    test('logs have null traceId when not set', () {
      LogPilot.info('no-trace');

      final record = LogPilot.history.last;
      expect(record.traceId, isNull);
    });

    test('traceId changes mid-stream', () {
      LogPilot.setTraceId('trace-1');
      LogPilot.info('first');

      LogPilot.setTraceId('trace-2');
      LogPilot.info('second');

      LogPilot.clearTraceId();
      LogPilot.info('third');

      final records = LogPilot.history;
      expect(records[0].traceId, 'trace-1');
      expect(records[1].traceId, 'trace-2');
      expect(records[2].traceId, isNull);
    });

    test('json logs include traceId', () {
      LogPilot.setTraceId('json-trace');
      LogPilot.json('{"x":1}');

      final record = LogPilot.history.last;
      expect(record.traceId, 'json-trace');
    });
  });

  group('LogPilotRecord serialization with IDs', () {
    test('toJson includes sessionId and traceId', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'test',
        sessionId: 'sess-123',
        traceId: 'trace-456',
      );

      final json = record.toJson();
      expect(json['sessionId'], 'sess-123');
      expect(json['traceId'], 'trace-456');
    });

    test('toJson omits sessionId and traceId when null', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'test',
      );

      final json = record.toJson();
      expect(json.containsKey('sessionId'), isFalse);
      expect(json.containsKey('traceId'), isFalse);
    });

    test('toJsonString includes IDs', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'test',
        sessionId: 'sess-abc',
        traceId: 'trace-xyz',
      );

      final parsed = jsonDecode(record.toJsonString()) as Map<String, dynamic>;
      expect(parsed['sessionId'], 'sess-abc');
      expect(parsed['traceId'], 'trace-xyz');
    });

    test('toFormattedString includes session and trace IDs', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'test',
        sessionId: 'sess-abc',
        traceId: 'trace-xyz',
      );

      final formatted = record.toFormattedString();
      expect(formatted, contains('sid=sess-abc'));
      expect(formatted, contains('tid=trace-xyz'));
    });

    test('toFormattedString omits IDs when null', () {
      final record = LogPilotRecord(
        level: LogLevel.info,
        timestamp: DateTime(2026, 3, 28),
        message: 'test',
      );

      final formatted = record.toFormattedString();
      expect(formatted, isNot(contains('sid=')));
      expect(formatted, isNot(contains('tid=')));
    });
  });

  group('Sink receives records with IDs', () {
    test('callback sink gets sessionId and traceId', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(config: LogPilotConfig(
        enabled: false,
        maxHistorySize: 10,
        sinks: [CallbackSink(records.add)],
      ));

      LogPilot.setTraceId('sink-trace');
      LogPilot.info('sink-test');

      expect(records, hasLength(1));
      expect(records.first.sessionId, equals(LogPilot.sessionId));
      expect(records.first.traceId, 'sink-trace');

      LogPilot.clearTraceId();
    });
  });

  group('withTraceId (async)', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 20,
      ));
      LogPilot.clearHistory();
      LogPilot.clearTraceId();
    });

    tearDown(LogPilot.reset);

    test('sets trace ID during callback and clears after', () async {
      await LogPilot.withTraceId('async-1', () async {
        LogPilot.info('inside');
        expect(LogPilot.traceId, 'async-1');
      });

      expect(LogPilot.traceId, isNull);
      expect(LogPilot.history.last.traceId, 'async-1');
    });

    test('clears trace ID even when callback throws', () async {
      try {
        await LogPilot.withTraceId('fail-1', () async {
          LogPilot.info('before throw');
          throw Exception('boom');
        });
      } catch (_) {}

      expect(LogPilot.traceId, isNull);
      expect(LogPilot.history.last.traceId, 'fail-1');
    });

    test('returns the callback result', () async {
      final result = await LogPilot.withTraceId('ret-1', () async => 42);
      expect(result, 42);
    });
  });

  group('withTraceIdSync', () {
    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxHistorySize: 20,
      ));
      LogPilot.clearHistory();
      LogPilot.clearTraceId();
    });

    tearDown(LogPilot.reset);

    test('sets trace ID during callback and clears after', () {
      LogPilot.withTraceIdSync('sync-1', () {
        LogPilot.info('inside sync');
        expect(LogPilot.traceId, 'sync-1');
      });

      expect(LogPilot.traceId, isNull);
      expect(LogPilot.history.last.traceId, 'sync-1');
    });

    test('clears trace ID even when callback throws', () {
      try {
        LogPilot.withTraceIdSync<void>('sync-fail', () {
          throw Exception('sync boom');
        });
      } catch (_) {}

      expect(LogPilot.traceId, isNull);
    });

    test('returns the callback result', () {
      final result = LogPilot.withTraceIdSync('sync-ret', () => 'hello');
      expect(result, 'hello');
    });
  });
}

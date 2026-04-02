import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

LogPilotRecord _record({String? message, LogLevel level = LogLevel.info}) =>
    LogPilotRecord(
      level: level,
      timestamp: DateTime(2026, 3, 31),
      message: message ?? 'test',
    );

void main() {
  group('AsyncLogSink', () {
    test('batches records and flushes on microtask boundary', () async {
      final batches = <List<LogPilotRecord>>[];
      final sink = AsyncLogSink(flush: batches.add);

      sink.onLog(_record(message: 'a'));
      sink.onLog(_record(message: 'b'));
      sink.onLog(_record(message: 'c'));

      expect(batches, isEmpty, reason: 'flush is async');

      await Future<void>.delayed(Duration.zero);

      expect(batches, hasLength(1));
      expect(batches.first.map((r) => r.message), ['a', 'b', 'c']);
    });

    test('each microtask boundary produces a separate batch', () async {
      final batches = <List<LogPilotRecord>>[];
      final sink = AsyncLogSink(flush: batches.add);

      sink.onLog(_record(message: 'first'));
      await Future<void>.delayed(Duration.zero);

      sink.onLog(_record(message: 'second'));
      await Future<void>.delayed(Duration.zero);

      expect(batches, hasLength(2));
      expect(batches[0].map((r) => r.message), ['first']);
      expect(batches[1].map((r) => r.message), ['second']);
    });

    test('dispose flushes pending records', () async {
      final batches = <List<LogPilotRecord>>[];
      final sink = AsyncLogSink(flush: batches.add);

      sink.onLog(_record(message: 'pending'));
      sink.dispose();

      expect(batches, hasLength(1));
      expect(batches.first.first.message, 'pending');
    });

    test('dispose is safe when no pending records', () {
      final batches = <List<LogPilotRecord>>[];
      final sink = AsyncLogSink(flush: batches.add);

      sink.dispose();

      expect(batches, isEmpty);
    });

    test('flush callback receives correct record fields', () async {
      late List<LogPilotRecord> received;
      final sink = AsyncLogSink(flush: (batch) => received = batch);

      final error = Exception('boom');
      final stack = StackTrace.current;
      sink.onLog(LogPilotRecord(
        level: LogLevel.error,
        timestamp: DateTime(2026, 3, 31),
        message: 'err msg',
        tag: 'Test',
        error: error,
        stackTrace: stack,
        metadata: const {'k': 'v'},
      ));

      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      final r = received.first;
      expect(r.level, LogLevel.error);
      expect(r.message, 'err msg');
      expect(r.tag, 'Test');
      expect(r.error, error);
      expect(r.stackTrace, stack);
      expect(r.metadata, {'k': 'v'});
    });
  });

  group('BufferedCallbackSink', () {
    test('flushes when maxBatchSize is reached', () {
      final batches = <List<LogPilotRecord>>[];
      final sink = BufferedCallbackSink(
        onFlush: batches.add,
        maxBatchSize: 3,
        flushInterval: const Duration(hours: 1),
      );

      sink.onLog(_record(message: '1'));
      sink.onLog(_record(message: '2'));
      expect(batches, isEmpty);

      sink.onLog(_record(message: '3'));
      expect(batches, hasLength(1));
      expect(batches.first.map((r) => r.message), ['1', '2', '3']);

      sink.dispose();
    });

    test('flushes after flushInterval even if batch is not full', () {
      FakeAsync().run((async) {
        final batches = <List<LogPilotRecord>>[];
        final sink = BufferedCallbackSink(
          onFlush: batches.add,
          maxBatchSize: 100,
          flushInterval: const Duration(milliseconds: 200),
        );

        sink.onLog(_record(message: 'a'));
        async.elapse(const Duration(milliseconds: 199));
        expect(batches, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(batches, hasLength(1));
        expect(batches.first.first.message, 'a');

        sink.dispose();
      });
    });

    test('dispose flushes remaining buffered records', () {
      final batches = <List<LogPilotRecord>>[];
      final sink = BufferedCallbackSink(
        onFlush: batches.add,
        maxBatchSize: 100,
        flushInterval: const Duration(hours: 1),
      );

      sink.onLog(_record(message: 'pending'));
      expect(batches, isEmpty);

      sink.dispose();
      expect(batches, hasLength(1));
      expect(batches.first.first.message, 'pending');
    });

    test('dispose is safe when buffer is empty', () {
      final batches = <List<LogPilotRecord>>[];
      final sink = BufferedCallbackSink(
        onFlush: batches.add,
        maxBatchSize: 10,
      );

      sink.dispose();
      expect(batches, isEmpty);
    });

    test('multiple batch cycles work correctly', () {
      final batches = <List<LogPilotRecord>>[];
      final sink = BufferedCallbackSink(
        onFlush: batches.add,
        maxBatchSize: 2,
        flushInterval: const Duration(hours: 1),
      );

      sink.onLog(_record(message: 'a'));
      sink.onLog(_record(message: 'b'));
      sink.onLog(_record(message: 'c'));
      sink.onLog(_record(message: 'd'));

      expect(batches, hasLength(2));
      expect(batches[0].map((r) => r.message), ['a', 'b']);
      expect(batches[1].map((r) => r.message), ['c', 'd']);

      sink.dispose();
    });

    test('timer resets after size-triggered flush', () {
      FakeAsync().run((async) {
        final batches = <List<LogPilotRecord>>[];
        final sink = BufferedCallbackSink(
          onFlush: batches.add,
          maxBatchSize: 2,
          flushInterval: const Duration(milliseconds: 500),
        );

        sink.onLog(_record(message: 'a'));
        sink.onLog(_record(message: 'b'));
        expect(batches, hasLength(1));

        sink.onLog(_record(message: 'c'));
        async.elapse(const Duration(milliseconds: 500));
        expect(batches, hasLength(2));
        expect(batches[1].first.message, 'c');

        sink.dispose();
      });
    });

    test('default parameters have reasonable values', () {
      final sink = BufferedCallbackSink(onFlush: (_) {});
      expect(sink.maxBatchSize, 50);
      expect(sink.flushInterval, const Duration(milliseconds: 500));
      sink.dispose();
    });
  });
}

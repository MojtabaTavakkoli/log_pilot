import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    LogPilot.configure(config: const LogPilotConfig(
      enabled: false,
      maxHistorySize: 100,
    ));
    LogPilot.clearHistory();
  });

  tearDown(LogPilot.reset);

  group('LogPilotHttpClient creates records in history', () {
    test('successful GET creates an info-level record', () async {
      final mock = MockClient((_) async => http.Response('ok', 200));
      final client = LogPilotHttpClient(inner: mock);

      await client.get(Uri.parse('https://example.com/users'));

      final records = LogPilot.historyWhere(tag: 'http');
      expect(records, hasLength(1));

      final r = records.first;
      expect(r.level, LogLevel.info);
      expect(r.message, contains('GET'));
      expect(r.message, contains('example.com'));
      expect(r.message, contains('200'));
      expect(r.metadata, isNotNull);
      expect(r.metadata!['method'], 'GET');
      expect(r.metadata!['statusCode'], 200);
      expect(r.metadata!['durationMs'], isA<int>());
    });

    test('4xx response creates a warning-level record', () async {
      final mock = MockClient((_) async => http.Response('nope', 404));
      final client = LogPilotHttpClient(inner: mock);

      await client.get(Uri.parse('https://example.com/missing'));

      final records = LogPilot.historyWhere(tag: 'http');
      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.warning);
      expect(records.first.metadata!['statusCode'], 404);
    });

    test('5xx response creates an error-level record', () async {
      final mock = MockClient((_) async => http.Response('error', 500));
      final client = LogPilotHttpClient(inner: mock);

      await client.get(Uri.parse('https://example.com/fail'));

      final records = LogPilot.historyWhere(tag: 'http');
      expect(records, hasLength(1));
      expect(records.first.level, LogLevel.error);
      expect(records.first.metadata!['statusCode'], 500);
    });

    test('network error creates an error-level record with error', () async {
      final mock = MockClient((_) async {
        throw http.ClientException('connection refused');
      });
      final client = LogPilotHttpClient(inner: mock);

      try {
        await client.get(Uri.parse('https://example.com/down'));
      } catch (_) {}

      final records = LogPilot.historyWhere(tag: 'http');
      expect(records, hasLength(1));

      final r = records.first;
      expect(r.level, LogLevel.error);
      expect(r.message, contains('failed'));
      expect(r.error, isNotNull);
    });

    test('createRecords: false suppresses history records', () async {
      final mock = MockClient((_) async => http.Response('ok', 200));
      final client = LogPilotHttpClient(inner: mock, createRecords: false);

      await client.get(Uri.parse('https://example.com/quiet'));

      final records = LogPilot.historyWhere(tag: 'http');
      expect(records, isEmpty);
    });

    test('record metadata includes url and method for POST', () async {
      final mock = MockClient((_) async => http.Response('created', 201));
      final client = LogPilotHttpClient(inner: mock);

      await client.post(
        Uri.parse('https://example.com/items'),
        body: jsonEncode({'name': 'widget'}),
      );

      final records = LogPilot.historyWhere(tag: 'http');
      expect(records, hasLength(1));
      expect(records.first.metadata!['method'], 'POST');
      expect(records.first.metadata!['url'], 'https://example.com/items');
    });

    test('records appear in LogPilot.history alongside regular logs', () async {
      LogPilot.info('before request');

      final mock = MockClient((_) async => http.Response('ok', 200));
      final client = LogPilotHttpClient(inner: mock);
      await client.get(Uri.parse('https://example.com/api'));

      LogPilot.info('after request');

      expect(LogPilot.history, hasLength(3));
      expect(LogPilot.history[0].message, 'before request');
      expect(LogPilot.history[1].tag, 'http');
      expect(LogPilot.history[2].message, 'after request');
    });
  });
}

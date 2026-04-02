import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  setUp(LogPilot.reset);
  tearDown(LogPilot.reset);

  group('Breadcrumb', () {
    test('toJson includes all fields', () {
      final b = Breadcrumb(
        timestamp: DateTime(2026, 3, 29),
        message: 'Tapped button',
        category: 'ui',
        metadata: const {'id': 42},
      );
      final json = b.toJson();
      expect(json['message'], 'Tapped button');
      expect(json['category'], 'ui');
      expect(json['metadata'], {'id': 42});
      expect(json.containsKey('timestamp'), isTrue);
    });

    test('toJson omits null category and empty metadata', () {
      final b = Breadcrumb(
        timestamp: DateTime(2026, 3, 29),
        message: 'hello',
      );
      final json = b.toJson();
      expect(json.containsKey('category'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString includes category when present', () {
      final b = Breadcrumb(
        timestamp: DateTime.now(),
        message: 'clicked',
        category: 'ui',
      );
      expect(b.toString(), '[ui] clicked');
    });

    test('toString omits category when null', () {
      final b = Breadcrumb(
        timestamp: DateTime.now(),
        message: 'hello',
      );
      expect(b.toString(), 'hello');
    });
  });

  group('BreadcrumbBuffer', () {
    test('evicts oldest when full', () {
      final buf = BreadcrumbBuffer(3);
      for (var i = 0; i < 5; i++) {
        buf.add(Breadcrumb(
          timestamp: DateTime.now(),
          message: 'msg$i',
        ));
      }
      expect(buf.length, 3);
      expect(buf.crumbs.first.message, 'msg2');
      expect(buf.crumbs.last.message, 'msg4');
    });

    test('clear empties the buffer', () {
      final buf = BreadcrumbBuffer(10);
      buf.add(Breadcrumb(timestamp: DateTime.now(), message: 'x'));
      buf.clear();
      expect(buf.isEmpty, isTrue);
    });
  });

  group('LogPilot.addBreadcrumb', () {
    test('manually added breadcrumbs appear in the trail', () {
      LogPilot.addBreadcrumb('user tapped login', category: 'ui');
      LogPilot.addBreadcrumb('API call started', category: 'api');

      expect(LogPilot.breadcrumbs, hasLength(2));
      expect(LogPilot.breadcrumbs.first.message, 'user tapped login');
      expect(LogPilot.breadcrumbs.first.category, 'ui');
    });

    test('clearBreadcrumbs empties the trail', () {
      LogPilot.addBreadcrumb('a');
      LogPilot.addBreadcrumb('b');
      LogPilot.clearBreadcrumbs();
      expect(LogPilot.breadcrumbs, isEmpty);
    });
  });

  group('Auto-breadcrumbs from log calls', () {
    test('each log call adds a breadcrumb', () {
      LogPilot.info('first');
      LogPilot.debug('second');
      LogPilot.warning('third');

      expect(LogPilot.breadcrumbs, hasLength(3));
      expect(LogPilot.breadcrumbs[0].message, 'first');
      expect(LogPilot.breadcrumbs[1].message, 'second');
      expect(LogPilot.breadcrumbs[2].message, 'third');
    });

    test('log tag becomes breadcrumb category', () {
      LogPilot.info('msg', tag: 'Auth');
      expect(LogPilot.breadcrumbs.last.category, 'Auth');
    });
  });

  group('Breadcrumbs attached to error records', () {
    test('error record includes breadcrumbs from prior logs', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.info('step 1');
      LogPilot.info('step 2');
      LogPilot.info('step 3');
      LogPilot.error('something broke', error: StateError('bad'));

      final errorRecord = records.last;
      expect(errorRecord.level, LogLevel.error);
      expect(errorRecord.breadcrumbs, isNotNull);
      expect(errorRecord.breadcrumbs!.length, 3);
      expect(errorRecord.breadcrumbs![0].message, 'step 1');
      expect(errorRecord.breadcrumbs![2].message, 'step 3');
    });

    test('non-error records do not have breadcrumbs', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.info('just info');
      expect(records.last.breadcrumbs, isNull);
    });

    test('breadcrumbs respect maxBreadcrumbs config', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          maxBreadcrumbs: 3,
          sinks: [CallbackSink(records.add)],
        ),
      );

      for (var i = 0; i < 10; i++) {
        LogPilot.info('step $i');
      }
      LogPilot.error('crash', error: Exception('fail'));

      final errorRecord = records.last;
      expect(errorRecord.breadcrumbs, isNotNull);
      expect(errorRecord.breadcrumbs!.length, 3);
      expect(errorRecord.breadcrumbs!.first.message, 'step 7');
    });

    test('disabling breadcrumbs with maxBreadcrumbs: 0', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          maxBreadcrumbs: 0,
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.info('step');
      LogPilot.error('crash', error: Exception('fail'));

      expect(records.last.breadcrumbs, isNull);
      expect(LogPilot.breadcrumbs, isEmpty);
    });

    test('breadcrumbs appear in LogPilotRecord.toJson()', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(
        config: LogPilotConfig(
          sinks: [CallbackSink(records.add)],
        ),
      );

      LogPilot.addBreadcrumb('manual crumb', category: 'test');
      LogPilot.error('boom', error: StateError('x'));

      final json = records.last.toJson();
      expect(json.containsKey('breadcrumbs'), isTrue);
      final crumbs = json['breadcrumbs'] as List;
      expect(crumbs, isNotEmpty);
      expect((crumbs.first as Map)['message'], 'manual crumb');
      expect((crumbs.first as Map)['category'], 'test');
    });
  });

  group('LogPilotConfig.maxBreadcrumbs', () {
    test('default is 20', () {
      expect(const LogPilotConfig().maxBreadcrumbs, 20);
    });

    test('factories accept maxBreadcrumbs', () {
      expect(LogPilotConfig.debug(maxBreadcrumbs: 50).maxBreadcrumbs, 50);
      expect(LogPilotConfig.staging(maxBreadcrumbs: 15).maxBreadcrumbs, 15);
      expect(LogPilotConfig.production(maxBreadcrumbs: 10).maxBreadcrumbs, 10);
    });

    test('copyWith preserves and overrides maxBreadcrumbs', () {
      const c = LogPilotConfig(maxBreadcrumbs: 30);
      expect(c.copyWith().maxBreadcrumbs, 30);
      expect(c.copyWith(maxBreadcrumbs: 5).maxBreadcrumbs, 5);
    });
  });

  group('LogPilot.json() breadcrumb parity', () {
    setUp(LogPilot.reset);
    tearDown(LogPilot.reset);

    test('json() adds a breadcrumb with tag as message', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxBreadcrumbs: 20,
        maxHistorySize: 10,
      ));

      LogPilot.json('{"x":1}', tag: 'api');

      final crumbs = LogPilot.breadcrumbs;
      expect(crumbs, hasLength(1));
      expect(crumbs.first.message, 'json: api');
      expect(crumbs.first.category, 'api');
    });

    test('json() uses truncated raw when tag is null', () {
      LogPilot.configure(config: const LogPilotConfig(
        enabled: false,
        maxBreadcrumbs: 20,
        maxHistorySize: 10,
      ));

      LogPilot.json('{"short":true}');

      final crumbs = LogPilot.breadcrumbs;
      expect(crumbs, hasLength(1));
      expect(crumbs.first.message, 'json: {"short":true}');
      expect(crumbs.first.category, isNull);
    });

    test('json() breadcrumb appears in error record breadcrumbs', () {
      final records = <LogPilotRecord>[];
      LogPilot.configure(config: LogPilotConfig(
        enabled: false,
        maxBreadcrumbs: 20,
        maxHistorySize: 10,
        sinks: [CallbackSink(records.add)],
      ));

      LogPilot.json('{"cart":"items"}', tag: 'Cart');
      LogPilot.error('checkout failed', error: StateError('bad'));

      final errorRecord = records.last;
      expect(errorRecord.breadcrumbs, isNotNull);
      final messages = errorRecord.breadcrumbs!.map((b) => b.message);
      expect(messages, contains('json: Cart'));
    });
  });
}

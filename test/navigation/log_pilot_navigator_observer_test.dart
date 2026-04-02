import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  final List<LogPilotRecord> records = [];

  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    records.clear();
    LogPilot.configure(
      config: LogPilotConfig(
        enabled: false,
        sinks: [CallbackSink(records.add)],
      ),
    );
  });

  tearDown(LogPilot.reset);

  group('LogPilotNavigatorObserver', () {
    test('logs push events with route names', () {
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute('/home');

      observer.didPush(route, null);

      expect(records, hasLength(1));
      expect(records.first.message, contains('Pushed'));
      expect(records.first.message, contains('/home'));
      expect(records.first.tag, 'navigation');
      expect(records.first.metadata!['action'], 'PUSH');
      expect(records.first.metadata!['route'], '/home');
    });

    test('logs push with previous route', () {
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute('/details');
      final previous = _fakeRoute('/home');

      observer.didPush(route, previous);

      expect(records.first.message, contains('from /home'));
      expect(records.first.metadata!['previousRoute'], '/home');
    });

    test('logs pop events', () {
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute('/details');
      final previous = _fakeRoute('/home');

      observer.didPop(route, previous);

      expect(records, hasLength(1));
      expect(records.first.message, contains('Popped'));
      expect(records.first.message, contains('/details'));
      expect(records.first.message, contains('back to /home'));
      expect(records.first.metadata!['action'], 'POP');
    });

    test('logs replace events', () {
      final observer = LogPilotNavigatorObserver();
      final newRoute = _fakeRoute('/profile');
      final oldRoute = _fakeRoute('/login');

      observer.didReplace(newRoute: newRoute, oldRoute: oldRoute);

      expect(records, hasLength(1));
      expect(records.first.message, contains('Replaced'));
      expect(records.first.message, contains('/login'));
      expect(records.first.message, contains('/profile'));
      expect(records.first.metadata!['action'], 'REPLACE');
    });

    test('logs remove events', () {
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute('/dialog');

      observer.didRemove(route, null);

      expect(records, hasLength(1));
      expect(records.first.message, contains('Removed'));
      expect(records.first.message, contains('/dialog'));
      expect(records.first.metadata!['action'], 'REMOVE');
    });

    test('includes route arguments when logArguments is true', () {
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute('/details', arguments: {'id': 42});

      observer.didPush(route, null);

      expect(records.first.metadata!['arguments'], contains('42'));
    });

    test('excludes route arguments when logArguments is false', () {
      final observer = LogPilotNavigatorObserver(logArguments: false);
      final route = _fakeRoute('/details', arguments: {'id': 42});

      observer.didPush(route, null);

      expect(records.first.metadata!.containsKey('arguments'), isFalse);
    });

    test('uses custom tag', () {
      final observer = LogPilotNavigatorObserver(tag: 'routes');
      final route = _fakeRoute('/home');

      observer.didPush(route, null);

      expect(records.first.tag, 'routes');
    });

    test('handles routes without names', () {
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute(null);

      observer.didPush(route, null);

      expect(records, hasLength(1));
      expect(records.first.metadata!['route'], isNotNull);
    });

    test('handles replace with null routes', () {
      final observer = LogPilotNavigatorObserver();

      observer.didReplace(newRoute: null, oldRoute: null);

      expect(records, hasLength(1));
      expect(records.first.message, contains('Replaced'));
      expect(records.first.message, contains('?'));
    });

    test('records go to history', () {
      LogPilot.configure(
        config: LogPilotConfig(
          enabled: false,
          maxHistorySize: 100,
          sinks: [CallbackSink(records.add)],
        ),
      );
      final observer = LogPilotNavigatorObserver();
      final route = _fakeRoute('/home');

      observer.didPush(route, null);

      final history = LogPilot.history;
      expect(history.any((r) => r.tag == 'navigation'), isTrue);
    });

    test('sessionId and traceId are included in records', () {
      LogPilot.configure(
        config: LogPilotConfig(
          enabled: false,
          sinks: [CallbackSink(records.add)],
        ),
      );
      LogPilot.setTraceId('nav-trace-123');
      final observer = LogPilotNavigatorObserver();

      observer.didPush(_fakeRoute('/home'), null);

      expect(records.first.sessionId, isNotNull);
      expect(records.first.traceId, 'nav-trace-123');
      LogPilot.clearTraceId();
    });

    test('multiple transitions produce multiple records', () {
      final observer = LogPilotNavigatorObserver();

      observer.didPush(_fakeRoute('/home'), null);
      observer.didPush(_fakeRoute('/details'), _fakeRoute('/home'));
      observer.didPop(_fakeRoute('/details'), _fakeRoute('/home'));

      expect(records, hasLength(3));
      expect(records[0].metadata!['action'], 'PUSH');
      expect(records[1].metadata!['action'], 'PUSH');
      expect(records[2].metadata!['action'], 'POP');
    });
  });
}

Route<dynamic> _fakeRoute(String? name, {Object? arguments}) {
  return _TestRoute(
    settings: RouteSettings(name: name, arguments: arguments),
  );
}

class _TestRoute extends PageRoute<void> {
  _TestRoute({required RouteSettings settings}) : super(settings: settings);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return const SizedBox.shrink();
  }
}

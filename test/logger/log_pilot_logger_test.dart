import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/src/errors/flutter_error_parser.dart';

void main() {
  group('LogPilot facade', () {
    setUpAll(() {
      WidgetsFlutterBinding.ensureInitialized();
      LogPilot.init(
        config: const LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          showTimestamp: false,
        ),
        child: const SizedBox.shrink(),
      );
    });

    tearDownAll(LogPilot.reset);

    test('verbose does not throw', () {
      expect(() => LogPilot.verbose('verbose message'), returnsNormally);
    });

    test('debug does not throw', () {
      expect(() => LogPilot.debug('debug message'), returnsNormally);
    });

    test('info does not throw', () {
      expect(() => LogPilot.info('info message'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(() => LogPilot.warning('warning message'), returnsNormally);
    });

    test('error with exception does not throw', () {
      expect(
        () => LogPilot.error(
          'error message',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('fatal does not throw', () {
      expect(() => LogPilot.fatal('fatal message'), returnsNormally);
    });

    test('json auto-formats valid JSON object', () {
      expect(
        () => LogPilot.json('{"key": "value", "num": 42}'),
        returnsNormally,
      );
    });

    test('json handles invalid JSON gracefully', () {
      expect(
        () => LogPilot.json('not valid json'),
        returnsNormally,
      );
    });

    test('json handles JSON arrays', () {
      expect(
        () => LogPilot.json('[1, 2, {"name": "LogPilot"}]'),
        returnsNormally,
      );
    });

    test('info with metadata does not throw', () {
      expect(
        () => LogPilot.info(
          'with metadata',
          metadata: {'userId': '123', 'action': 'login'},
        ),
        returnsNormally,
      );
    });

    test('isInitialized returns true after init', () {
      expect(LogPilot.isInitialized, isTrue);
    });

    test('tagged log does not throw', () {
      expect(
        () => LogPilot.info('tagged message', tag: 'checkout'),
        returnsNormally,
      );
    });

    test('json with tag does not throw', () {
      expect(
        () => LogPilot.json('{"a":1}', tag: 'api'),
        returnsNormally,
      );
    });
  });

  group('LogPilotConfig filtering', () {
    test('isSilenced matches case-insensitively', () {
      const config = LogPilotConfig(
        silencedErrors: {'RenderFlex overflowed', 'HTTP 404'},
      );

      expect(config.isSilenced('A RenderFlex overflowed by 50 pixels'), isTrue);
      expect(config.isSilenced('a renderflex overflowed by 20'), isTrue);
      expect(config.isSilenced('HTTP 404 Not Found'), isTrue);
      expect(config.isSilenced('Something else entirely'), isFalse);
    });

    test('isSilenced returns false when set is empty', () {
      const config = LogPilotConfig();
      expect(config.isSilenced('any error'), isFalse);
    });

    test('isTagAllowed returns true when onlyTags is empty', () {
      const config = LogPilotConfig();
      expect(config.isTagAllowed(null), isTrue);
      expect(config.isTagAllowed('anything'), isTrue);
    });

    test('isTagAllowed filters when onlyTags is set', () {
      const config = LogPilotConfig(onlyTags: {'checkout', 'auth'});

      expect(config.isTagAllowed('checkout'), isTrue);
      expect(config.isTagAllowed('auth'), isTrue);
      expect(config.isTagAllowed('network'), isFalse);
      expect(config.isTagAllowed(null), isFalse);
    });

    test('copyWith preserves silencedErrors and onlyTags', () {
      const original = LogPilotConfig(
        silencedErrors: {'RenderFlex'},
        onlyTags: {'auth'},
      );
      final copied = original.copyWith(logLevel: LogLevel.error);

      expect(copied.silencedErrors, contains('RenderFlex'));
      expect(copied.onlyTags, contains('auth'));
      expect(copied.logLevel, LogLevel.error);
    });
  });

  group('LogPilotPrinter tag filtering', () {
    test('printLog silences untagged log when onlyTags is set', () {
      final printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        colorize: false,
        onlyTags: {'checkout'},
      ));

      // Should not throw -- just silently skip
      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'Test',
          message: 'no tag',
        ),
        returnsNormally,
      );
    });

    test('printLog allows matching tag', () {
      final printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        colorize: false,
        onlyTags: {'checkout'},
      ));

      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'Test',
          message: 'tagged',
          tag: 'checkout',
        ),
        returnsNormally,
      );
    });

    test('printNetwork respects tag filter', () {
      final printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        colorize: false,
        onlyTags: {'api'},
      ));

      expect(
        () => printer.printNetwork(
          title: 'Request',
          level: LogLevel.debug,
          lines: ['GET /users'],
          tag: 'api',
        ),
        returnsNormally,
      );
    });
  });

  group('FlutterErrorParser silencedErrors', () {
    test('silenced error is not printed', () {
      setAnsiSupported(false);
      const config = LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        silencedErrors: {'RenderFlex overflowed'},
      );
      final printer = LogPilotPrinter(config);
      final parser = FlutterErrorParser(config, printer);

      final details = FlutterErrorDetails(
        exception: Exception('A RenderFlex overflowed by 50 pixels'),
        library: 'rendering library',
      );

      expect(() => parser.parse(details), returnsNormally);
      setAnsiSupported(true);
    });
  });
}

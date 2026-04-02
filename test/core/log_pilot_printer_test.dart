import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('LogPilotPrinter', () {
    late LogPilotPrinter printer;

    setUp(() {
      printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
        colorize: false,
        maxLineWidth: 80,
      ));
    });

    test('printLog does not throw for a basic message', () {
      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'Test',
          message: 'Hello world',
        ),
        returnsNormally,
      );
    });

    test('printLog respects log level filtering', () {
      final filtered = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.error,
        showTimestamp: false,
      ));

      expect(
        () => filtered.printLog(
          level: LogLevel.debug,
          title: 'Skipped',
          message: 'this should be filtered out',
        ),
        returnsNormally,
      );
    });

    test('printLog does nothing when disabled', () {
      final disabled = LogPilotPrinter(const LogPilotConfig(enabled: false));

      expect(
        () => disabled.printLog(
          level: LogLevel.fatal,
          title: 'Disabled',
          message: 'should be silent',
        ),
        returnsNormally,
      );
    });

    test('printLog handles metadata', () {
      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'With meta',
          message: 'msg',
          metadata: {'key': 'value', 'nested': {'a': 1}},
        ),
        returnsNormally,
      );
    });

    test('printLog handles error and stack trace', () {
      expect(
        () => printer.printLog(
          level: LogLevel.error,
          title: 'Error',
          error: Exception('boom'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('printNetwork does not throw', () {
      expect(
        () => printer.printNetwork(
          title: 'Request',
          level: LogLevel.debug,
          lines: ['GET https://example.com', 'Status: 200'],
        ),
        returnsNormally,
      );
    });

    test('formatJsonString detects and formats JSON', () {
      final lines = printer.formatJsonString('{"name":"LogPilot","version":1}');
      final joined = lines.join('\n');
      expect(joined, contains('name'));
      expect(joined, contains('LogPilot'));
    });

    test('formatJsonString returns raw text for non-JSON', () {
      final lines = printer.formatJsonString('not json at all');
      expect(lines.length, 1);
      expect(lines.first, contains('not json at all'));
    });
  });
}

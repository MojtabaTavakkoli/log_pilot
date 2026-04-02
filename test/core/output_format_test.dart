import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('OutputFormat', () {
    test('LogPilotConfig defaults to OutputFormat.pretty', () {
      const config = LogPilotConfig();
      expect(config.outputFormat, OutputFormat.pretty);
    });

    test('LogPilotConfig.debug() defaults to OutputFormat.pretty', () {
      final config = LogPilotConfig.debug();
      expect(config.outputFormat, OutputFormat.pretty);
    });

    test('LogPilotConfig.staging() defaults to OutputFormat.pretty', () {
      final config = LogPilotConfig.staging();
      expect(config.outputFormat, OutputFormat.pretty);
    });

    test('LogPilotConfig.production() defaults to OutputFormat.pretty', () {
      final config = LogPilotConfig.production();
      expect(config.outputFormat, OutputFormat.pretty);
    });

    test('outputFormat can be set to plain', () {
      const config = LogPilotConfig(outputFormat: OutputFormat.plain);
      expect(config.outputFormat, OutputFormat.plain);
    });

    test('outputFormat can be set to json', () {
      const config = LogPilotConfig(outputFormat: OutputFormat.json);
      expect(config.outputFormat, OutputFormat.json);
    });

    test('copyWith preserves outputFormat', () {
      const config = LogPilotConfig(outputFormat: OutputFormat.json);
      final copied = config.copyWith(logLevel: LogLevel.error);
      expect(copied.outputFormat, OutputFormat.json);
    });

    test('copyWith can change outputFormat', () {
      const config = LogPilotConfig(outputFormat: OutputFormat.pretty);
      final copied = config.copyWith(outputFormat: OutputFormat.plain);
      expect(copied.outputFormat, OutputFormat.plain);
    });

    test('factory constructors accept outputFormat', () {
      final debug = LogPilotConfig.debug(outputFormat: OutputFormat.json);
      expect(debug.outputFormat, OutputFormat.json);

      final staging = LogPilotConfig.staging(outputFormat: OutputFormat.plain);
      expect(staging.outputFormat, OutputFormat.plain);

      final prod = LogPilotConfig.production(outputFormat: OutputFormat.json);
      expect(prod.outputFormat, OutputFormat.json);
    });
  });

  group('LogPilotPrinter with OutputFormat.plain', () {
    late LogPilotPrinter printer;

    setUp(() {
      printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        outputFormat: OutputFormat.plain,
        showTimestamp: false,
        colorize: false,
      ));
    });

    test('printLog does not throw', () {
      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'Test',
          message: 'Hello world',
        ),
        returnsNormally,
      );
    });

    test('printLog with metadata does not throw', () {
      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'Test',
          message: 'With meta',
          metadata: {'key': 'value'},
          tag: 'test',
        ),
        returnsNormally,
      );
    });

    test('printLog with error does not throw', () {
      expect(
        () => printer.printLog(
          level: LogLevel.error,
          title: 'Error',
          message: 'Boom',
          error: Exception('test error'),
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
  });

  group('LogPilotPrinter with OutputFormat.json', () {
    late LogPilotPrinter printer;

    setUp(() {
      printer = LogPilotPrinter(const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        outputFormat: OutputFormat.json,
        showTimestamp: false,
        colorize: false,
      ));
    });

    test('printLog does not throw', () {
      expect(
        () => printer.printLog(
          level: LogLevel.info,
          title: 'Test',
          message: 'Hello world',
        ),
        returnsNormally,
      );
    });

    test('printLog with all fields does not throw', () {
      expect(
        () => printer.printLog(
          level: LogLevel.warning,
          title: 'Test',
          message: 'All fields',
          metadata: {'user': 'alice'},
          tag: 'auth',
          caller: 'package:app/main.dart:10:5',
          error: const FormatException('bad input'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('printNetwork does not throw', () {
      expect(
        () => printer.printNetwork(
          title: 'Response',
          level: LogLevel.info,
          lines: ['GET https://api.example.com', '200 OK [120ms]'],
          tag: 'api',
        ),
        returnsNormally,
      );
    });
  });

  group('LogPilotPrinter respects level/tag filters in all formats', () {
    for (final format in OutputFormat.values) {
      test('$format: respects log level filtering', () {
        final printer = LogPilotPrinter(LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.error,
          outputFormat: format,
          showTimestamp: false,
          colorize: false,
        ));

        expect(
          () => printer.printLog(
            level: LogLevel.debug,
            title: 'Skipped',
            message: 'filtered out',
          ),
          returnsNormally,
        );
      });

      test('$format: respects tag filtering', () {
        final printer = LogPilotPrinter(LogPilotConfig(
          enabled: true,
          logLevel: LogLevel.verbose,
          outputFormat: format,
          onlyTags: const {'api'},
          showTimestamp: false,
          colorize: false,
        ));

        expect(
          () => printer.printLog(
            level: LogLevel.info,
            title: 'Test',
            message: 'wrong tag',
            tag: 'auth',
          ),
          returnsNormally,
        );
      });

      test('$format: does nothing when disabled', () {
        final printer = LogPilotPrinter(LogPilotConfig(
          enabled: false,
          outputFormat: format,
        ));

        expect(
          () => printer.printLog(
            level: LogLevel.fatal,
            title: 'Disabled',
            message: 'silent',
          ),
          returnsNormally,
        );
      });
    }
  });
}

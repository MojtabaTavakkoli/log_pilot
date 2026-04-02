import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/src/errors/flutter_error_parser.dart';

void main() {
  group('FlutterErrorParser', () {
    late LogPilotConfig config;
    late LogPilotPrinter printer;
    late FlutterErrorParser parser;

    setUp(() {
      setAnsiSupported(false);
      config = const LogPilotConfig(
        enabled: true,
        logLevel: LogLevel.verbose,
        showTimestamp: false,
      );
      printer = LogPilotPrinter(config);
      parser = FlutterErrorParser(config, printer);
    });

    tearDown(() => setAnsiSupported(true));

    test('parses a RenderFlex overflow error without throwing', () {
      final details = FlutterErrorDetails(
        exception: Exception('A RenderFlex overflowed by 50 pixels'),
        library: 'rendering library',
        context: ErrorDescription('during layout'),
      );

      expect(() => parser.parse(details), returnsNormally);
    });

    test('parses a setState after dispose error', () {
      final details = FlutterErrorDetails(
        exception: Exception('setState() called after dispose'),
        library: 'widgets library',
      );

      expect(() => parser.parse(details), returnsNormally);
    });

    test('parses a null check operator error', () {
      final details = FlutterErrorDetails(
        exception: Exception('Null check operator used on a null value'),
      );

      expect(() => parser.parse(details), returnsNormally);
    });

    test('handles error with stack trace', () {
      final details = FlutterErrorDetails(
        exception: Exception('Some error'),
        stack: StackTrace.current,
      );

      expect(() => parser.parse(details), returnsNormally);
    });

    test('handles error with informationCollector', () {
      final details = FlutterErrorDetails(
        exception: Exception('Test error'),
        informationCollector: () => [
          ErrorDescription('First info line'),
          ErrorDescription('Second info line'),
        ],
      );

      expect(() => parser.parse(details), returnsNormally);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/src/core/ansi_styles.dart' show ansi, bold, colorize, dim;

void main() {
  group('AnsiStyles', () {
    setUp(() => setAnsiSupported(true));
    tearDown(() => setAnsiSupported(true));

    test('colorize wraps text with color codes', () {
      final result = colorize('hello', AnsiColor.red);
      expect(result, contains('\x1B[31m'));
      expect(result, contains('hello'));
      expect(result, endsWith('\x1B[0m'));
    });

    test('bold wraps text with bold code', () {
      final result = bold('hello');
      expect(result, contains('\x1B[1m'));
      expect(result, contains('hello'));
    });

    test('dim wraps text with dim code', () {
      final result = dim('hello');
      expect(result, contains('\x1B[2m'));
    });

    test('stripAnsi removes all escape sequences', () {
      final styled = colorize(bold('hello'), AnsiColor.red);
      expect(stripAnsi(styled), equals('hello'));
    });

    test('returns plain text when ANSI is disabled', () {
      setAnsiSupported(false);
      final result = colorize('hello', AnsiColor.red);
      expect(result, equals('hello'));
    });

    test('ansi applies both color and style', () {
      final result = ansi('test', color: AnsiColor.cyan, style: AnsiStyle.underline);
      expect(result, contains('\x1B[4m'));
      expect(result, contains('\x1B[36m'));
      expect(result, contains('test'));
    });
  });
}

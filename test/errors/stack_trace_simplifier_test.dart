import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  group('StackTraceSimplifier', () {
    setUp(() => setAnsiSupported(false));
    tearDown(() => setAnsiSupported(true));

    StackTrace makeTrace(String raw) => StackTrace.fromString(raw);

    test('simplifies a basic stack trace with framework filtering', () {
      final st = makeTrace(
        '#0      myFunction (package:my_app/main.dart:10:5)\n'
        '#1      build (package:flutter/src/widgets/framework.dart:4500:12)\n'
        '#2      performRebuild (package:flutter/src/widgets/framework.dart:4600:5)\n'
        '#3      handleError (package:my_app/error_handler.dart:20:3)\n',
      );

      final simplifier = StackTraceSimplifier(maxFrames: 10);
      final lines = simplifier.simplify(st);

      expect(lines, isNotEmpty);

      final joined = lines.join('\n');
      expect(joined, contains('myFunction'));
      expect(joined, contains('handleError'));
      expect(joined, contains('Flutter internals'));
    });

    test('shows all frames when filterFrameworkFrames is false', () {
      final st = makeTrace(
        '#0      myFunction (package:my_app/main.dart:10:5)\n'
        '#1      build (package:flutter/src/widgets/framework.dart:4500:12)\n',
      );

      final simplifier = StackTraceSimplifier(
        maxFrames: 10,
        filterFrameworkFrames: false,
      );
      final lines = simplifier.simplify(st);

      expect(lines.length, 2);
      final joined = lines.join('\n');
      expect(joined, isNot(contains('Flutter internals')));
    });

    test('respects maxFrames limit', () {
      final st = makeTrace(
        '#0      a (package:my_app/a.dart:1:1)\n'
        '#1      b (package:my_app/b.dart:2:1)\n'
        '#2      c (package:my_app/c.dart:3:1)\n'
        '#3      d (package:my_app/d.dart:4:1)\n'
        '#4      e (package:my_app/e.dart:5:1)\n',
      );

      final simplifier = StackTraceSimplifier(maxFrames: 3);
      final lines = simplifier.simplify(st);

      final codeLines = lines.where((l) => !l.contains('more frames')).toList();
      expect(codeLines.length, 3);
      expect(lines.last, contains('2 more frames'));
    });

    test('handles empty stack trace', () {
      final st = makeTrace('');
      final simplifier = StackTraceSimplifier();
      final lines = simplifier.simplify(st);
      expect(lines, isEmpty);
    });

    test('handles current stack trace without crashing', () {
      final simplifier = StackTraceSimplifier(maxFrames: 5);
      expect(
        () => simplifier.simplify(StackTrace.current),
        returnsNormally,
      );
    });

    test('skips asynchronous suspension markers', () {
      final st = makeTrace(
        '#0      myFunc (package:my_app/main.dart:1:1)\n'
        '<asynchronous suspension>\n'
        '#1      otherFunc (package:my_app/other.dart:2:1)\n',
      );

      final simplifier = StackTraceSimplifier(
        maxFrames: 10,
        filterFrameworkFrames: false,
      );
      final lines = simplifier.simplify(st);

      final joined = lines.join('\n');
      expect(joined, isNot(contains('asynchronous')));
      expect(joined, contains('myFunc'));
      expect(joined, contains('otherFunc'));
    });
  });
}

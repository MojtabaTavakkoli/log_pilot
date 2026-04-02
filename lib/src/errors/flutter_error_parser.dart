import 'package:flutter/foundation.dart';
import 'package:log_pilot/src/core/ansi_styles.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_config.dart';
import 'package:log_pilot/src/core/log_pilot_printer.dart';
import 'package:log_pilot/src/errors/stack_trace_simplifier.dart';

/// Parses [FlutterErrorDetails] into readable, colorized log blocks
/// with contextual hints for common Flutter errors.
class FlutterErrorParser {
  FlutterErrorParser(this._config, this._printer);

  final LogPilotConfig _config;
  final LogPilotPrinter _printer;

  /// Parse [details] and print a prettified error + optional stack trace.
  ///
  /// Returns silently if the error matches any [LogPilotConfig.silencedErrors]
  /// pattern.
  void parse(FlutterErrorDetails details) {
    final exception = details.exception;
    final summary = details.summary.toString();

    final silenceText = '$summary ${exception.runtimeType} $exception';
    if (_config.isSilenced(silenceText)) return;

    final hint = _matchHint(summary, exception);
    final lines = <String>[];

    lines.add(_printer.applyBold(
      _printer.applyColor(summary, AnsiColor.red),
    ));

    if (hint != null) {
      lines.add('');
      lines.add(_printer.applyColor('Tip: $hint', AnsiColor.yellow));
    }

    final context = details.context;
    if (context != null) {
      lines.add('');
      lines.add(_printer.applyDim('Context: $context'));
    }

    // Extract a clickable caller from the stack trace (first user frame).
    final stack = details.stack;
    String? callerLocation;
    List<String>? simplifiedStack;

    if (stack != null) {
      final simplifier = StackTraceSimplifier(
        maxFrames: _config.stackTraceDepth,
      );
      simplifiedStack = simplifier.simplify(stack);
      callerLocation = _extractCaller(stack);
    }

    if (_config.showDetails) {
      final informational = details.informationCollector?.call();
      if (informational != null) {
        final infoLines = informational
            .map((n) => n.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList();

        if (infoLines.isNotEmpty) {
          lines.add('');
          lines.add(_printer.applyDim('Details:'));
          for (final info in infoLines.take(5)) {
            for (final sub in info.split('\n')) {
              lines.add(_printer.applyDim('  $sub'));
            }
          }
          if (infoLines.length > 5) {
            lines.add(_printer.applyDim(
              '  ... ${infoLines.length - 5} more info lines',
            ));
          }
        }
      }
    }

    _printer.printLog(
      level: LogLevel.error,
      title: 'Flutter Error',
      preformattedLines: lines,
      caller: callerLocation,
    );

    if (_config.showDetails &&
        simplifiedStack != null &&
        simplifiedStack.isNotEmpty) {
      _printer.printLog(
        level: LogLevel.error,
        title: 'Stack Trace (simplified)',
        preformattedLines: simplifiedStack,
      );
    }
  }

  static final _frameRe = RegExp(r'#\d+\s+.+\s+\((.+)\)');
  static final _frameworkRe = [
    RegExp(r'package:flutter/'),
    RegExp(r'^dart:'),
  ];

  /// Extract the first user-code location from [stack] for the caller line.
  String? _extractCaller(StackTrace stack) {
    for (final line in stack.toString().split('\n')) {
      final match = _frameRe.firstMatch(line.trim());
      if (match == null) continue;
      final location = match.group(1)!;
      if (_frameworkRe.any((p) => p.hasMatch(location))) continue;
      return location;
    }
    return null;
  }

  String? _matchHint(String summary, Object exception) {
    final text = '$summary ${exception.toString()}';
    for (final entry in _hints.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static const _hints = {
    'RenderFlex overflowed':
        'Wrap the overflowing widget in Expanded, Flexible, or use '
            'SingleChildScrollView.',
    'RenderBox was not laid out':
        'A widget has no size. Check if a Column/Row child is unconstrained.',
    'setState() called after dispose':
        'An async callback is calling setState on an unmounted widget. '
            'Guard with `if (mounted)` before calling setState.',
    'Null check operator used on a null value':
        'A `!` operator hit null. Check your nullable variables and '
            'consider using `?.` or a null guard.',
    'A RenderFlex overflowed by':
        'Wrap overflowing children in Expanded/Flexible or add a ScrollView.',
    'The following assertion was thrown during layout':
        'A layout constraint was violated. Check Expanded/Flexible usage '
            'inside Rows, Columns, and Stacks.',
    'No Material widget found':
        'Wrap your widget tree in a MaterialApp or Material widget.',
    'No MediaQuery widget ancestor found':
        'Ensure your widget is inside a MaterialApp, WidgetsApp, or '
            'MediaQuery.',
    'Looking up a deactivated widget':
        'You are accessing a BuildContext after the widget was removed '
            'from the tree.',
    'Duplicate GlobalKey detected':
        'Two widgets share the same GlobalKey. Each GlobalKey must be unique.',
    'RangeError':
        'An index was out of bounds. Check list/collection lengths before '
            'accessing by index.',
    "type 'Null' is not a subtype of type":
        'A null value was used where a non-null type was expected. '
            'Check your type casts and API responses.',
    'Navigator operation requested with a context':
        'The context used for navigation does not have a Navigator ancestor. '
            'Make sure you are using a context below MaterialApp.',
    'Incorrect use of ParentDataWidget':
        'A widget like Expanded or Positioned is used outside its '
            'expected parent (Row/Column/Stack).',
    'Bad state: Stream has already been listened to':
        'A single-subscription stream was listened to more than once. '
            'Use a broadcast stream or create a new stream for each listener.',
  };
}

import 'package:log_pilot/src/core/ansi_styles.dart';

/// Filters and simplifies Dart/Flutter stack traces for readability.
///
/// Collapses consecutive Flutter framework frames into a single
/// `[... Flutter internals ...]` boundary marker, highlights the
/// top user-code frame, and respects a configurable depth limit.
class StackTraceSimplifier {
  StackTraceSimplifier({
    this.maxFrames = 8,
    this.filterFrameworkFrames = true,
  });

  /// Maximum number of frames to display.
  final int maxFrames;

  /// Whether to collapse Flutter/Dart SDK frames into boundary markers.
  final bool filterFrameworkFrames;

  static final _frameworkPatterns = [
    RegExp(r'package:flutter/'),
    RegExp(r'^dart:'),
    RegExp(r'package:flutter_test/'),
    RegExp(r'package:test_api/'),
    RegExp(r'package:stack_trace/'),
  ];

  static final _framePattern = RegExp(r'#(\d+)\s+(.+)\s+\((.+)\)');

  /// Parse and simplify [stackTrace] into a list of formatted lines.
  List<String> simplify(StackTrace stackTrace) {
    final rawFrames = stackTrace.toString().split('\n');
    final parsed = <_Frame>[];

    for (final raw in rawFrames) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed == '<asynchronous suspension>') continue;

      final match = _framePattern.firstMatch(trimmed);
      if (match != null) {
        parsed.add(_Frame(
          member: match.group(2)!.trim(),
          location: match.group(3)!.trim(),
        ));
      } else {
        parsed.add(_Frame(member: '', location: '', raw: trimmed));
      }
    }

    final filtered =
        filterFrameworkFrames ? _filterFrames(parsed) : parsed;
    final limited = filtered.take(maxFrames).toList();
    final remaining = filtered.length - limited.length;

    final lines = <String>[];
    for (var i = 0; i < limited.length; i++) {
      lines.add(_formatFrame(limited[i], highlight: i == 0));
    }

    if (remaining > 0) {
      lines.add(dim('  ... $remaining more frames'));
    }

    return lines;
  }

  List<_Frame> _filterFrames(List<_Frame> frames) {
    final result = <_Frame>[];
    var lastWasFramework = false;

    for (final frame in frames) {
      if (_isFrameworkFrame(frame)) {
        if (!lastWasFramework) {
          result.add(_Frame(member: '', location: '', isBoundary: true));
        }
        lastWasFramework = true;
      } else {
        result.add(frame);
        lastWasFramework = false;
      }
    }

    return result;
  }

  bool _isFrameworkFrame(_Frame frame) {
    final loc = frame.location;
    if (loc.isEmpty && frame.raw != null) return false;
    return _frameworkPatterns.any((p) => p.hasMatch(loc));
  }

  String _formatFrame(_Frame frame, {bool highlight = false}) {
    if (frame.isBoundary) {
      return dim('  [... Flutter internals ...]');
    }

    if (frame.raw != null && frame.member.isEmpty) {
      return dim('  ${frame.raw}');
    }

    final location = _shortenLocation(frame.location);
    final text = '  ${frame.member}  ($location)';
    return highlight ? bold(text) : dim(text);
  }

  String _shortenLocation(String location) {
    final match = RegExp(r'package:(.+)').firstMatch(location);
    return match?.group(1) ?? location;
  }
}

class _Frame {
  _Frame({
    required this.member,
    required this.location,
    this.raw,
    this.isBoundary = false,
  });

  final String member;
  final String location;
  final String? raw;
  final bool isBoundary;
}

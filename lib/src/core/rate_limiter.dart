import 'package:log_pilot/src/core/log_level.dart';

/// Composite key for rate-limiting: a (level, message) pair.
typedef _RateLimitKey = ({LogLevel level, String message});

/// Tracks repeated log messages within a time window and collapses
/// duplicates into a single "... repeated N times" summary.
///
/// Used internally by [LogPilot] when [LogPilotConfig.deduplicateWindow] is
/// set to a non-zero duration. Each unique combination of log level
/// and message is tracked independently.
class RateLimiter {
  RateLimiter(this.window);

  /// The time window within which identical messages are collapsed.
  final Duration window;

  final Map<_RateLimitKey, _Entry> _entries = {};

  /// Check whether a log with the given [level] and [message] should
  /// be printed right now.
  ///
  /// Returns a [RateLimitResult] indicating whether the log should be:
  /// - [RateLimitAction.allow] — first occurrence, print normally
  /// - [RateLimitAction.suppress] — duplicate within the window, skip
  /// - [RateLimitAction.summarize] — window expired with suppressed
  ///   duplicates, print a summary of how many were suppressed
  RateLimitResult check(LogLevel level, String message) {
    final key = (level: level, message: message);
    final now = DateTime.now();
    final entry = _entries[key];

    if (entry == null) {
      _entries[key] = _Entry(firstSeen: now, lastSeen: now, count: 1);
      return const RateLimitResult(RateLimitAction.allow, 0);
    }

    final elapsed = now.difference(entry.firstSeen);

    if (elapsed < window) {
      entry.count++;
      entry.lastSeen = now;
      return const RateLimitResult(RateLimitAction.suppress, 0);
    }

    final suppressed = entry.count - 1;
    _entries[key] = _Entry(firstSeen: now, lastSeen: now, count: 1);

    if (suppressed > 0) {
      return RateLimitResult(RateLimitAction.summarize, suppressed);
    }
    return const RateLimitResult(RateLimitAction.allow, 0);
  }

  /// Flush all entries and return summaries for any that had suppressed
  /// duplicates. Call this periodically or on dispose to ensure no
  /// suppressed counts are lost.
  List<RateLimitSummary> flushAll() {
    final summaries = <RateLimitSummary>[];
    for (final entry in _entries.entries) {
      if (entry.value.count > 1) {
        summaries.add(RateLimitSummary(
          level: entry.key.level,
          message: entry.key.message,
          suppressedCount: entry.value.count - 1,
        ));
      }
    }
    _entries.clear();
    return summaries;
  }

  /// Remove all tracking state.
  void reset() => _entries.clear();
}

class _Entry {
  _Entry({
    required this.firstSeen,
    required this.lastSeen,
    required this.count,
  });

  final DateTime firstSeen;
  DateTime lastSeen;
  int count;
}

/// The action to take for a rate-limited log message.
enum RateLimitAction {
  /// First occurrence — print normally.
  allow,

  /// Duplicate within the window — suppress console output.
  suppress,

  /// Window expired and duplicates were suppressed — print the new
  /// message plus a "... repeated N times" summary.
  summarize,
}

/// The result of a rate limit check.
class RateLimitResult {
  const RateLimitResult(this.action, this.suppressedCount);

  /// What to do with this log message.
  final RateLimitAction action;

  /// Number of suppressed duplicates (only meaningful for [summarize]).
  final int suppressedCount;
}

/// A summary of suppressed duplicates, returned by [RateLimiter.flushAll].
class RateLimitSummary {
  const RateLimitSummary({
    required this.level,
    required this.message,
    required this.suppressedCount,
  });

  final LogLevel level;
  final String message;
  final int suppressedCount;
}

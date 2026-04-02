import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_record.dart';

export 'package:log_pilot/src/core/export_format.dart';

/// A fixed-size circular buffer that retains the most recent log records.
///
/// Uses a [Queue] internally for O(1) eviction of the oldest entry.
/// Access the history via [LogPilot.history] and export it via [LogPilot.export].
///
/// Listen to [onChanged] for notifications when records are added or
/// the buffer is cleared (used by [LogPilotOverlay] for live updates).
class LogHistory {
  /// Creates a ring buffer that holds at most [maxSize] records.
  LogHistory(this.maxSize) : assert(maxSize > 0);

  /// Maximum number of records retained.
  final int maxSize;

  final Queue<LogPilotRecord> _buffer = Queue<LogPilotRecord>();

  /// Incremented each time [add] or [clear] is called, allowing
  /// listeners to detect changes without polling.
  final ValueNotifier<int> onChanged = ValueNotifier<int>(0);

  /// Add a record to the buffer, evicting the oldest if full.
  void add(LogPilotRecord record) {
    if (_buffer.length >= maxSize) {
      _buffer.removeFirst();
    }
    _buffer.addLast(record);
    onChanged.value++;
  }

  /// An unmodifiable view of all records, oldest first.
  List<LogPilotRecord> get records => List.unmodifiable(_buffer);

  /// Number of records currently in the buffer.
  int get length => _buffer.length;

  /// Whether the buffer contains any records.
  bool get isEmpty => _buffer.isEmpty;

  /// Whether the buffer has at least one record.
  bool get isNotEmpty => _buffer.isNotEmpty;

  /// Remove all records from the buffer.
  void clear() {
    _buffer.clear();
    onChanged.value++;
  }

  /// Return records matching the given filters.
  ///
  /// All parameters are optional and combined with AND logic:
  /// - [level]: minimum log level (records below this are excluded)
  /// - [tag]: exact tag match
  /// - [messageContains]: case-insensitive substring search on message
  /// - [traceId]: exact trace ID match
  /// - [hasError]: if `true`, only records with an error; if `false`,
  ///   only records without
  /// - [after]: only records with timestamp after this time
  /// - [before]: only records with timestamp before this time
  /// - [metadataKey]: only records whose metadata contains this key
  List<LogPilotRecord> where({
    LogLevel? level,
    String? tag,
    String? messageContains,
    String? traceId,
    bool? hasError,
    DateTime? after,
    DateTime? before,
    String? metadataKey,
  }) {
    final needle = messageContains?.toLowerCase();
    return _buffer.where((r) {
      if (level != null && r.level.priority < level.priority) return false;
      if (tag != null && r.tag != tag) return false;
      if (needle != null &&
          !(r.message?.toLowerCase().contains(needle) ?? false)) {
        return false;
      }
      if (traceId != null && r.traceId != traceId) return false;
      if (hasError == true && r.error == null) return false;
      if (hasError == false && r.error != null) return false;
      if (after != null && r.timestamp.isBefore(after)) return false;
      if (before != null && r.timestamp.isAfter(before)) return false;
      if (metadataKey != null &&
          (r.metadata == null || !r.metadata!.containsKey(metadataKey))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Export all records as a single formatted string, one line per record.
  ///
  /// Uses [LogPilotRecord.toFormattedString] for human-readable output.
  String exportAsText() =>
      _buffer.map((r) => r.toFormattedString()).join('\n');

  /// Export all records as NDJSON (one JSON object per line).
  String exportAsJson() =>
      _buffer.map((r) => jsonEncode(r.toJson())).join('\n');
}

import 'dart:async';

import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';

/// Self-monitoring diagnostics for LogPilot.
///
/// Tracks records-per-second, sink dispatch latency, and optionally
/// auto-degrades the log level when throughput exceeds a threshold.
///
/// ```dart
/// final diag = LogPilotDiagnostics(
///   autoDegrade: true,
///   throughputThreshold: 50,
/// );
/// diag.start();
/// // ... later ...
/// print(diag.snapshot);
/// diag.stop();
/// ```
class LogPilotDiagnostics {
  LogPilotDiagnostics({
    this.autoDegrade = false,
    this.throughputThreshold = 50,
    this.windowDuration = const Duration(seconds: 1),
    this.degradeLevel = LogLevel.warning,
    this.onThresholdExceeded,
  });

  /// Automatically raise the minimum log level when throughput exceeds
  /// [throughputThreshold] records per [windowDuration].
  final bool autoDegrade;

  /// Number of records per [windowDuration] that triggers auto-degrade.
  final int throughputThreshold;

  /// Sampling window for throughput measurement.
  final Duration windowDuration;

  /// The log level to switch to when auto-degrading.
  final LogLevel degradeLevel;

  /// Optional callback fired when the threshold is exceeded.
  final void Function(int recordsPerSecond)? onThresholdExceeded;

  int _recordCount = 0;
  int _totalRecords = 0;
  Duration _totalSinkLatency = Duration.zero;
  int _sinkDispatchCount = 0;
  Timer? _timer;
  LogLevel? _originalLevel;
  bool _degraded = false;

  /// Start monitoring. Installs a lightweight [LogSink] that counts
  /// records and measures sink dispatch time.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(windowDuration, _onWindow);
  }

  /// Stop monitoring and restore any degraded log level.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_degraded) _restoreLevel();
  }

  /// Record a log dispatch for diagnostics tracking.
  ///
  /// Called by the sink pipeline with the time spent dispatching to
  /// all sinks for a single record.
  void recordDispatch({Duration sinkLatency = Duration.zero}) {
    _recordCount++;
    _totalRecords++;
    if (sinkLatency > Duration.zero) {
      _totalSinkLatency += sinkLatency;
      _sinkDispatchCount++;
    }
  }

  void _onWindow(Timer _) {
    final throughput = _recordCount;
    _recordCount = 0;

    if (autoDegrade && throughput > throughputThreshold && !_degraded) {
      _degraded = true;
      _originalLevel = LogPilotZone.config.logLevel;
      LogPilotZone.setLogLevel(degradeLevel);
      onThresholdExceeded?.call(throughput);
    } else if (_degraded && throughput <= throughputThreshold ~/ 2) {
      _restoreLevel();
    }
  }

  void _restoreLevel() {
    if (_originalLevel != null) {
      LogPilotZone.setLogLevel(_originalLevel!);
    }
    _degraded = false;
    _originalLevel = null;
  }

  /// Current diagnostics snapshot.
  LogPilotDiagnosticsSnapshot get snapshot => LogPilotDiagnosticsSnapshot(
        totalRecords: _totalRecords,
        averageSinkLatency: _sinkDispatchCount > 0
            ? Duration(
                microseconds:
                    _totalSinkLatency.inMicroseconds ~/ _sinkDispatchCount)
            : Duration.zero,
        isDegraded: _degraded,
        currentLogLevel: LogPilotZone.config.logLevel,
      );
}

/// Immutable snapshot of diagnostics state.
class LogPilotDiagnosticsSnapshot {
  const LogPilotDiagnosticsSnapshot({
    required this.totalRecords,
    required this.averageSinkLatency,
    required this.isDegraded,
    required this.currentLogLevel,
  });

  final int totalRecords;
  final Duration averageSinkLatency;
  final bool isDegraded;
  final LogLevel currentLogLevel;

  Map<String, dynamic> toJson() => {
        'totalRecords': totalRecords,
        'averageSinkLatencyUs': averageSinkLatency.inMicroseconds,
        'isDegraded': isDegraded,
        'currentLogLevel': currentLogLevel.name,
      };

  @override
  String toString() =>
      'LogPilotDiagnostics(records: $totalRecords, '
      'avgSinkLatency: ${averageSinkLatency.inMicroseconds}µs, '
      'degraded: $isDegraded, level: ${currentLogLevel.name})';
}

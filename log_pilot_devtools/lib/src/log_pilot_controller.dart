import 'dart:async';
import 'dart:convert';

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'log_entry.dart';

/// Bridge between the DevTools extension UI and the running app's LogPilot state.
///
/// Uses Dart VM service extensions registered by the LogPilot library
/// (`ext.LogPilot.*`) to query and control the running app's log state.
/// This approach works on all platforms including web, unlike
/// expression evaluation which is unavailable on web targets.
class LogPilotController extends DisposableController
    with AutoDisposeControllerMixin {
  LogPilotController() {
    _init();
  }

  VmService? _service;
  String? _isolateId;
  Timer? _pollTimer;

  final _entries = ValueNotifier<List<LogEntry>>([]);
  final _isConnected = ValueNotifier<bool>(false);
  final _isLoading = ValueNotifier<bool>(false);
  final _error = ValueNotifier<String?>(null);
  final _tags = ValueNotifier<Set<String>>({});
  final _currentLogLevel = ValueNotifier<String>('info');

  ValueListenable<List<LogEntry>> get entries => _entries;
  ValueListenable<bool> get isConnected => _isConnected;
  ValueListenable<bool> get isLoading => _isLoading;
  ValueListenable<String?> get error => _error;
  ValueListenable<Set<String>> get tags => _tags;
  ValueListenable<String> get currentLogLevel => _currentLogLevel;

  int _lastKnownCount = 0;

  Future<void> _init() async {
    try {
      await serviceManager.onServiceAvailable;
      _service = serviceManager.service!;

      final vm = await _service!.getVM();
      final isolate = vm.isolates?.firstOrNull;
      if (isolate == null) {
        _error.value = 'No isolates found in the target VM.';
        return;
      }
      _isolateId = isolate.id!;

      _isConnected.value = true;
      _error.value = null;

      await refresh();
      _startPolling();
    } catch (e) {
      _error.value = 'Connection failed: $e';
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!_isConnected.value || _service == null || _isolateId == null) return;
    try {
      final resp = await _service!.callServiceExtension(
        'ext.LogPilot.getCount',
        isolateId: _isolateId,
      );
      final count = (resp.json?['count'] as int?) ?? 0;
      if (count != _lastKnownCount) {
        await refresh();
      }
    } catch (_) {}
  }

  /// Pull all log entries from the running app via service extension.
  Future<void> refresh() async {
    if (!_isConnected.value || _service == null || _isolateId == null) return;
    _isLoading.value = true;
    _error.value = null;
    try {
      final resp = await _service!.callServiceExtension(
        'ext.LogPilot.getHistory',
        isolateId: _isolateId,
      );
      final json = resp.json;
      if (json == null) {
        _entries.value = [];
        _lastKnownCount = 0;
      } else {
        final count = (json['count'] as int?) ?? 0;
        final rawEntries = json['entries'] as List<dynamic>? ?? [];

        final parsed = <LogEntry>[];
        for (final raw in rawEntries) {
          try {
            // Each entry is a JSON-encoded string of a LogPilotRecord.
            final map = raw is String
                ? jsonDecode(raw) as Map<String, dynamic>
                : raw as Map<String, dynamic>;
            parsed.add(LogEntry.fromJson(map));
          } catch (_) {}
        }
        _entries.value = parsed;
        _lastKnownCount = count;
      }

      _rebuildTags();
      await _fetchLogLevel();
    } catch (e) {
      _error.value = 'Failed to fetch logs: $e';
    } finally {
      _isLoading.value = false;
    }
  }

  void _rebuildTags() {
    final tagSet = <String>{};
    for (final entry in _entries.value) {
      if (entry.tag != null) tagSet.add(entry.tag!);
    }
    _tags.value = tagSet;
  }

  Future<void> _fetchLogLevel() async {
    try {
      final resp = await _service!.callServiceExtension(
        'ext.LogPilot.getLogLevel',
        isolateId: _isolateId,
      );
      final level = resp.json?['level'] as String?;
      if (level != null && level.isNotEmpty) {
        _currentLogLevel.value = level;
      }
    } catch (_) {}
  }

  /// Change the minimum log level in the running app.
  Future<void> setLogLevel(String level) async {
    if (!_isConnected.value || _service == null || _isolateId == null) return;
    try {
      await _service!.callServiceExtension(
        'ext.LogPilot.setLogLevel',
        isolateId: _isolateId,
        args: {'level': level},
      );
      _currentLogLevel.value = level;
    } catch (e) {
      _error.value = 'Failed to set log level: $e';
    }
  }

  /// Clear the log history in the running app.
  Future<void> clearHistory() async {
    if (!_isConnected.value || _service == null || _isolateId == null) return;
    try {
      await _service!.callServiceExtension(
        'ext.LogPilot.clearHistory',
        isolateId: _isolateId,
      );
      _entries.value = [];
      _lastKnownCount = 0;
      _rebuildTags();
    } catch (e) {
      _error.value = 'Failed to clear logs: $e';
    }
  }

  /// Get a diagnostic snapshot from the running app.
  Future<String> getSnapshot() async {
    if (!_isConnected.value || _service == null || _isolateId == null) {
      return '{}';
    }
    try {
      final resp = await _service!.callServiceExtension(
        'ext.LogPilot.getSnapshot',
        isolateId: _isolateId,
      );
      return const JsonEncoder.withIndent('  ')
          .convert(resp.json ?? {});
    } catch (e) {
      return '{"error": "$e"}';
    }
  }

  /// Export logs in the specified format.
  ///
  /// Re-serializes the in-memory entries since the service extension
  /// already provides the full data in [refresh].
  Future<String> exportLogs({String format = 'text'}) async {
    if (_entries.value.isEmpty) return '';
    if (format == 'json') {
      return _entries.value
          .map((e) => jsonEncode(e.toMap()))
          .join('\n');
    }
    return _entries.value
        .map((e) => '[${e.level.label}] ${e.tag ?? ''} ${e.message ?? ''}')
        .join('\n');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _entries.dispose();
    _isConnected.dispose();
    _isLoading.dispose();
    _error.dispose();
    _tags.dispose();
    _currentLogLevel.dispose();
    super.dispose();
  }
}

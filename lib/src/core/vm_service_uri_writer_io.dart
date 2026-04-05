import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:flutter/foundation.dart';

/// Writes the VM service WebSocket URI to `.dart_tool/log_pilot_vm_service_uri`
/// so `log_pilot_mcp` can auto-discover it.
///
/// Searches multiple locations for the project's `.dart_tool` folder:
/// 1. Current working directory and up to 8 parent directories.
/// 2. The directory of `Platform.script` (the entry-point file) and its
///    parents — handles cases where the IDE launches the app with a
///    working directory that differs from the project root (common on
///    Windows).
/// 3. The directory of `Platform.resolvedExecutable` and its parents.
///
/// Only runs in debug mode. Failures are logged to stderr but never crash
/// the app.
Future<void> writeVmServiceUri() async {
  if (!kDebugMode) return;

  try {
    final info = await developer.Service.getInfo();
    final wsUri = info.serverWebSocketUri;
    if (wsUri == null) {
      debugPrint(
        '[LogPilot] VM service URI is null — auto-discovery file not written. '
        'Use --vm-service-uri to connect the MCP server manually.',
      );
      return;
    }

    final dartTool = _findDartToolDir();
    if (dartTool == null) {
      debugPrint(
        '[LogPilot] Could not locate .dart_tool directory — '
        'auto-discovery file not written. '
        'cwd=${io.Directory.current.path}. '
        'Use --vm-service-uri or --project-root when starting the MCP server.',
      );
      return;
    }

    final file = io.File('${dartTool.path}/log_pilot_vm_service_uri');
    await file.writeAsString(wsUri.toString());
  } catch (e) {
    debugPrint(
      '[LogPilot] Failed to write VM service URI file: $e. '
      'Use --vm-service-uri or --project-root when starting the MCP server.',
    );
  }
}

/// Try multiple strategies to locate the project's `.dart_tool` directory.
io.Directory? _findDartToolDir() {
  // Strategy 1: walk up from cwd.
  final fromCwd = _walkUpForDartTool(io.Directory.current);
  if (fromCwd != null) return fromCwd;

  // Strategy 2: walk up from Platform.script (the entry-point file).
  // On Windows, IDEs often set cwd to the Flutter SDK or system directory,
  // but Platform.script still points to the project's entry-point.
  try {
    final scriptUri = io.Platform.script;
    if (scriptUri.scheme == 'file') {
      final scriptDir = io.File.fromUri(scriptUri).parent;
      final fromScript = _walkUpForDartTool(scriptDir);
      if (fromScript != null) return fromScript;
    }
  } catch (_) {
    // Platform.script may throw on some embedders; ignore.
  }

  // Strategy 3: walk up from the resolved executable path.
  try {
    final execDir = io.File(io.Platform.resolvedExecutable).parent;
    final fromExec = _walkUpForDartTool(execDir);
    if (fromExec != null) return fromExec;
  } catch (_) {}

  return null;
}

/// Walk up from [start] looking for a `.dart_tool` directory, checking
/// the start directory and up to 8 parent directories.
io.Directory? _walkUpForDartTool(io.Directory start) {
  var dir = start;
  for (var i = 0; i < 9; i++) {
    final candidate = io.Directory('${dir.path}/.dart_tool');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

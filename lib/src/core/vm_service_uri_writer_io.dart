import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:flutter/foundation.dart';

/// Writes the VM service WebSocket URI to `.dart_tool/log_pilot_vm_service_uri`
/// so `log_pilot_mcp` can auto-discover it.
///
/// Searches the current working directory and up to 5 parent directories
/// for a `.dart_tool` folder. This handles cases where the working
/// directory differs from the project root (e.g. inside `runZonedGuarded`
/// or when the app is launched from a subdirectory). Only runs in debug
/// mode.
Future<void> writeVmServiceUri() async {
  if (!kDebugMode) return;

  try {
    final info = await developer.Service.getInfo();
    final wsUri = info.serverWebSocketUri;
    if (wsUri == null) return;

    final dartTool = _findDartToolDir();
    if (dartTool == null) return;

    final file = io.File('${dartTool.path}/log_pilot_vm_service_uri');
    await file.writeAsString(wsUri.toString());
  } catch (_) {
    // Best-effort — don't break the app if this fails.
  }
}

/// Walk up from cwd looking for a `.dart_tool` directory.
io.Directory? _findDartToolDir() {
  var dir = io.Directory.current;
  for (var i = 0; i < 6; i++) {
    final candidate = io.Directory('${dir.path}/.dart_tool');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

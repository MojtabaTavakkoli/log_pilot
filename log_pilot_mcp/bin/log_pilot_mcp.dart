import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';
import 'package:log_pilot_mcp/log_pilot_mcp.dart';

void main(List<String> args) {
  final uri = _parseArg(args, '--vm-service-uri=');
  final uriFile = _parseArg(args, '--vm-service-uri-file=');

  if (uri != null) {
    _startServer(uri, uriFile: uriFile);
    return;
  }

  // Try reading the URI from a file (explicit or default location).
  final filePath = uriFile ?? _defaultUriFilePath();
  if (filePath != null) {
    final file = io.File(filePath);
    if (file.existsSync()) {
      final discovered = file.readAsStringSync().trim();
      if (discovered.isNotEmpty) {
        io.stderr.writeln(
          '[log_pilot_mcp] Auto-discovered VM service URI from $filePath',
        );
        _startServer(discovered, uriFile: filePath);
        return;
      }
    }
  }

  // Check environment variable.
  final envUri = io.Platform.environment['log_pilot_VM_SERVICE_URI'];
  if (envUri != null) {
    _startServer(envUri, uriFile: filePath);
    return;
  }

  // If we have a file path (from auto-discovery) but no URI yet, wait
  // for the file to appear. This handles the case where the MCP server
  // starts before the app writes the URI file.
  if (filePath != null) {
    io.stderr.writeln(
      '[log_pilot_mcp] Waiting for VM service URI at $filePath...\n'
      '           Start your Flutter app in debug mode.',
    );
    _waitForUriFile(filePath);
    return;
  }

  io.stderr.writeln(
    'Usage: dart run log_pilot_mcp --vm-service-uri=ws://127.0.0.1:PORT/ws\n'
    '\n'
    'The VM service URI is printed when you run:\n'
    '  flutter run --verbose\n'
    '\n'
    'Options:\n'
    '  --vm-service-uri=URI        Connect to this VM service URI directly.\n'
    '  --vm-service-uri-file=PATH  Read the URI from this file. The file\n'
    '                              is watched for changes, so the server\n'
    '                              reconnects automatically on app restart.\n'
    '\n'
    'Auto-discovery: If no flags are given, the server looks for\n'
    '  .dart_tool/log_pilot_vm_service_uri (written by LogPilot on LogPilot.init()).\n'
    '\n'
    'You can also set the log_pilot_VM_SERVICE_URI environment variable.',
  );
  io.exitCode = 1;
}

LogPilotMcpServer? _server;

void _startServer(String uri, {String? uriFile}) {
  _server = LogPilotMcpServer(
    stdioChannel(input: io.stdin, output: io.stdout),
    vmServiceUri: uri,
  );

  // Watch the URI file for changes so we reconnect on full app restarts.
  if (uriFile != null) {
    _watchUriFile(uriFile);
  }
}

/// Watch for the URI file to appear (creation) and then start the server.
void _waitForUriFile(String path) {
  final file = io.File(path);
  final dir = file.parent;
  if (!dir.existsSync()) return;

  dir.watch(events: io.FileSystemEvent.create | io.FileSystemEvent.modify)
      .listen((event) {
    if (event.path.replaceAll('\\', '/') !=
        file.path.replaceAll('\\', '/')) {
      return;
    }
    try {
      final discovered = file.readAsStringSync().trim();
      if (discovered.isEmpty) return;
      io.stderr.writeln(
        '[log_pilot_mcp] Auto-discovered VM service URI from $path',
      );
      _startServer(discovered, uriFile: path);
    } catch (_) {}
  });
}

void _watchUriFile(String path) {
  final file = io.File(path);
  final dir = file.parent;
  if (!dir.existsSync()) return;

  dir.watch(events: io.FileSystemEvent.modify).listen((event) {
    if (event.path.replaceAll('\\', '/') !=
        file.path.replaceAll('\\', '/')) {
      return;
    }

    try {
      final newUri = file.readAsStringSync().trim();
      if (newUri.isEmpty) return;
      if (newUri == _server?.vmServiceUri) return;

      io.stderr.writeln(
        '[log_pilot_mcp] VM service URI changed in $path — reconnecting...',
      );
      _server?.updateVmServiceUri(newUri);
    } catch (_) {}
  });
}

String? _parseArg(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

/// Default location for the auto-written URI file. Walks up from the
/// current directory looking for a `.dart_tool` folder.
String? _defaultUriFilePath() {
  var dir = io.Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = io.File('${dir.path}/.dart_tool/log_pilot_vm_service_uri');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  // Fall back to cwd even if file doesn't exist yet (it may appear later).
  final dartTool = io.Directory('${io.Directory.current.path}/.dart_tool');
  if (dartTool.existsSync()) {
    return '${dartTool.path}/log_pilot_vm_service_uri';
  }
  return null;
}

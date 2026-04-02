import 'vm_service_uri_writer_stub.dart'
    if (dart.library.io) 'vm_service_uri_writer_io.dart' as impl;

/// Write the current VM service WebSocket URI to a well-known file so
/// external tools (like `log_pilot_mcp`) can auto-discover it without manual
/// configuration.
///
/// On web this is a no-op. On native platforms the URI is written to
/// `<project>/.dart_tool/log_pilot_vm_service_uri`.
Future<void> writeVmServiceUri() => impl.writeVmServiceUri();

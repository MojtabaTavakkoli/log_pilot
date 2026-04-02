/// MCP (Model Context Protocol) server for log_pilot — exposes runtime log state to AI coding agents.
///
/// Start the server from your IDE's MCP configuration:
/// ```json
/// {
///   "LogPilot": {
///     "command": "dart",
///     "args": ["run", "log_pilot_mcp", "--vm-service-uri=ws://127.0.0.1:PORT/ws"]
///   }
/// }
/// ```
library;

export 'src/log_pilot_mcp_server.dart';

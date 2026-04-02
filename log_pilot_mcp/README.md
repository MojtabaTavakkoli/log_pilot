# log_pilot_mcp

MCP (Model Context Protocol) server for [LogPilot](https://pub.dev/packages/LogPilot).
Exposes a running Flutter app's LogPilot state to AI coding agents in Cursor,
Claude Code, Windsurf, and other MCP-compatible tools.

## How it works

`log_pilot_mcp` connects to your Flutter app's Dart VM service and evaluates
LogPilot expressions to query logs, take diagnostic snapshots, change log
levels, and more — all without editing code or restarting.

The server **automatically reconnects** when the Dart isolate recycles
(hot restart, heavy navigation, or app restart on the same port). You no
longer need "Developer: Reload Window" after a hot restart — the next
MCP tool call transparently re-establishes the connection.

## Setup

### 1. Install dependencies

Before first use, resolve the `log_pilot_mcp` package dependencies:

```bash
cd path/to/LogPilot/log_pilot_mcp
dart pub get
```

This only needs to be done once (or after updating the package).

### 2. Configure your IDE

There are two ways to connect: **auto-discovery** (recommended) or
**manual URI**.

#### Option A: Auto-Discovery (recommended)

LogPilot automatically writes the VM service URI to
`.dart_tool/log_pilot_vm_service_uri` when your app starts. The MCP server
reads and watches this file, reconnecting automatically on every app
restart. **No manual URI copying needed.**

Create `.cursor/mcp.json` in your **app's project root**:

```json
{
  "mcpServers": {
    "LogPilot": {
      "command": "dart",
      "args": [
        "run",
        "/absolute/path/to/LogPilot/log_pilot_mcp/bin/log_pilot_mcp.dart"
      ]
    }
  }
}
```

That's it. Start your app in debug mode and the MCP server will
auto-discover the URI. On every subsequent restart, the file updates
and the server reconnects transparently.

#### Option B: Manual URI

If auto-discovery doesn't work (e.g. the app's working directory
differs from the project root), pass the URI explicitly.

Get the URI from the debug console:

```
Debug service listening on ws://127.0.0.1:PORT/TOKEN=/ws
```

```json
{
  "mcpServers": {
    "LogPilot": {
      "command": "dart",
      "args": [
        "run",
        "/absolute/path/to/LogPilot/log_pilot_mcp/bin/log_pilot_mcp.dart",
        "--vm-service-uri=ws://127.0.0.1:PORT/TOKEN=/ws"
      ]
    }
  }
}
```

**Critical fields:**

| Field | Why it's needed |
|-------|----------------|
| `command` | Must be `"dart"`. |
| `args[0]` | Must be `"run"`. |
| `args[1]` | The **absolute path** to `log_pilot_mcp/bin/log_pilot_mcp.dart`. This avoids `cwd` issues — Cursor does not reliably apply the `cwd` field for project-level MCP servers, so `dart run log_pilot_mcp` fails with "Could not find package". Using the absolute script path works from any directory. |
| `--vm-service-uri` | Must match the URI from your current debug session. |

> **Do NOT use `"type": "command"`** — Cursor's project-level MCP config
> does not require (or expect) a `type` field. Adding it may cause the
> server to fail to start. Only `command` and `args` are needed.

> **Why not `dart run log_pilot_mcp` with `cwd`?** Cursor's project-level
> MCP config (`.cursor/mcp.json`) does not reliably honor the `cwd`
> field. The command runs from the app's directory where `log_pilot_mcp` is
> not a dependency, causing a "Could not find package" error. Pointing
> directly to the script file bypasses this entirely.

> **Do NOT use `dart run --project <dir> log_pilot_mcp`** — this form also
> fails in Cursor's MCP runner. Always use the absolute path to the
> `.dart` entry-point script as the second arg.

**Example (Windows):**

```json
{
  "mcpServers": {
    "LogPilot": {
      "command": "dart",
      "args": [
        "run",
        "D:\\FlutterApps\\LogPilot\\log_pilot_mcp\\bin\\log_pilot_mcp.dart",
        "--vm-service-uri=ws://127.0.0.1:62542/0L3A7jm1D0Y=/ws"
      ]
    }
  }
}
```

**Example (macOS/Linux):**

```json
{
  "mcpServers": {
    "LogPilot": {
      "command": "dart",
      "args": [
        "run",
        "/Users/you/projects/LogPilot/log_pilot_mcp/bin/log_pilot_mcp.dart",
        "--vm-service-uri=ws://127.0.0.1:62542/0L3A7jm1D0Y=/ws"
      ]
    }
  }
}
```

**After creating or editing `.cursor/mcp.json`:**

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Type **"Developer: Reload Window"** and press Enter
3. Open **Cursor Settings → MCP** and enable the `LogPilot` server toggle
4. Verify it shows a green dot (connected)

#### Claude Code

```bash
cd path/to/LogPilot/log_pilot_mcp
dart run log_pilot_mcp --vm-service-uri=ws://127.0.0.1:PORT/TOKEN=/ws
```

Or with an environment variable:

```bash
export log_pilot_VM_SERVICE_URI=ws://127.0.0.1:PORT/TOKEN=/ws
cd path/to/LogPilot/log_pilot_mcp
dart run log_pilot_mcp
```

### 4. Verify the connection

After setup, test that the MCP server can reach your running app. In
Cursor, ask the agent to call `get_snapshot` or `get_log_level`.

From a terminal (run from the `log_pilot_mcp/` directory):

```bash
cd path/to/LogPilot/log_pilot_mcp
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}' | dart run log_pilot_mcp --vm-service-uri=ws://127.0.0.1:PORT/TOKEN=/ws
```

A successful response includes `"serverInfo":{"name":"log_pilot_mcp",...}`.

## When the app restarts

### Hot restart (same debug session)

The MCP server **automatically reconnects** — no action needed. It
detects the isolate recycle and re-resolves the connection on the next
tool call.

### Full restart (new debug session)

The VM service URI changes on every new debug session. To reconnect:

1. Copy the new `ws://...` URI from the debug console
2. Update the `--vm-service-uri` value in `.cursor/mcp.json`
3. Reload the Cursor window (`Ctrl+Shift+P` → "Developer: Reload Window")

## Available MCP Tools

| Tool            | Description                                                  |
|-----------------|--------------------------------------------------------------|
| `get_snapshot`  | Structured diagnostic summary: errors, timers, config, etc. Supports `group_by_tag` to see the last N logs per tag. |
| `query_logs`    | Filter log history by level, tag, and count                  |
| `export_logs`   | Full log history as text or NDJSON                           |
| `set_log_level` | Change verbosity at runtime (e.g. `verbose` for debugging)   |
| `get_log_level` | Read the current minimum log level                           |
| `clear_logs`    | Wipe in-memory log history                                   |
| `watch_logs`    | Stream new log entries as they arrive via MCP log notifications. Filter by tag and level. |
| `stop_watch`    | Stop the active log watcher and get a delivery summary       |

### `get_snapshot` parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_recent_errors` | int | 5 | Max error/fatal records in snapshot |
| `max_recent_logs` | int | 10 | Max recent records of any level |
| `group_by_tag` | bool | false | Include a `recentByTag` section |
| `per_tag_limit` | int | 5 | Records per tag when grouped |

When `group_by_tag` is true, the snapshot includes a `recentByTag` map
where each key is a tag name and each value contains `total` (count)
and `recent` (last N records as JSON). Untagged records appear under
`(untagged)`.

Each record in the snapshot includes a `caller` field (e.g.
`package:my_app/home.dart:42:8`) when `showCaller` is enabled in the
app's `LogPilotConfig`. This is on by default in debug and staging presets,
making it easy to disambiguate duplicate log entries from different
call sites.

### `query_logs` parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `level` | string | — | Minimum log level filter |
| `tag` | string | — | Exact tag match |
| `limit` | int | 20 | Max records (1–100) |
| `deduplicate` | bool | false | Collapse consecutive identical entries |

When `deduplicate` is true, consecutive entries with the same level,
message, and caller are collapsed into a single entry with a `count`
field. Entries from different callers are kept separate, solving the
"same message but different call site" problem.

### `watch_logs` parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `tag` | string | — | Only deliver entries with this tag |
| `level` | string | — | Minimum log level filter |
| `interval_ms` | int | 2000 | Poll interval in milliseconds (min 500) |

Starts a background poller that diffs the log history on each tick.
New entries matching the filters are pushed to the agent as MCP log
notifications (`notifications/message`) with `logger: "log_pilot_tail"`.
The subscribable `LogPilot://tail` resource is also updated on each tick.

Only one watch can be active at a time — starting a new watch
automatically stops the previous one.

### `stop_watch`

Takes no parameters. Cancels the active watcher and returns the total
number of entries delivered during the session.

## Available MCP Resources

| Resource          | Description                           |
|-------------------|---------------------------------------|
| `LogPilot://config`   | Current LogPilot configuration snapshot   |
| `LogPilot://session`  | Session ID and trace ID               |
| `LogPilot://tail`     | Latest batch of entries from the active log watcher. Subscribe to receive `notifications/resources/updated` when new entries arrive. |

## Dart MCP vs LogPilot MCP

These are two separate MCP servers that complement each other:

| Need | Use |
|------|-----|
| Widget tree, hot reload, runtime errors | Dart MCP (`user-dart`) |
| Structured LogPilot logs, snapshots, log level control | LogPilot MCP (`log_pilot_mcp`) |
| Static analysis, linting | Dart MCP (`analyze_files`) |

Both can run simultaneously. The Dart MCP connects via the DTD
(Dart Tooling Daemon), while LogPilot MCP connects via the VM service URI.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Server shows "Disabled" in Cursor Settings → MCP | Toggle the switch on. After creating `.cursor/mcp.json`, the server may appear disabled by default. |
| Server not appearing in Cursor Settings → MCP | Reload window after creating/editing `.cursor/mcp.json`. |
| `Could not find package "log_pilot_mcp"` | You're using `dart run log_pilot_mcp` or `dart run --project <dir> log_pilot_mcp` instead of the absolute script path. Replace with the absolute path to `log_pilot_mcp/bin/log_pilot_mcp.dart` in the `args` array. See the config examples above. |
| Server fails to start with `"type": "command"` | Remove the `"type"` field from `.cursor/mcp.json`. Cursor project-level MCP config does not use a `type` field. |
| `Failed to connect to VM service` | The app isn't running in debug mode, or the URI is stale. Copy a fresh URI from the debug console. |
| Tools fail after hot restart | This should auto-recover. If it persists, check that the VM service port didn't change (full restart vs hot restart). The server retries up to 3 times with backoff. |
| Server connects but tools return errors | The app must `import 'package:log_pilot/log_pilot.dart'` so the LogPilot library is loaded in the isolate. |
| Expression evaluation not available | This happens on Flutter Web in some configurations. The LogPilot DevTools extension uses `ext.LogPilot.*` service extensions instead, which work on all platforms. |

## Requirements

- The target Flutter app must depend on `LogPilot` and have imported it.
- The app must be running in **debug mode** (VM service is only available in debug/profile).
- Dart SDK ≥ 3.9.2.
- Run `dart pub get` in the `log_pilot_mcp/` directory before first use.

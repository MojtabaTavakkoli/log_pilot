/// Controls how LogPilot renders log output to the console.
///
/// The default [pretty] mode produces box-bordered, colorized blocks
/// designed for human reading in IDEs and DevTools.
///
/// The [plain] and [json] modes produce machine-parseable output
/// designed for AI agent consumption, CI pipelines, and log
/// aggregation systems.
enum OutputFormat {
  /// Box-bordered, colorized blocks via `dart:developer.log`.
  ///
  /// This is the default — optimized for human reading in IDEs.
  pretty,

  /// Flat single-line output with no ANSI codes or box borders.
  ///
  /// Format: `[LEVEL] [tag] message | Error: ... | {"key": "value"}`
  ///
  /// Designed for AI agents (Cursor, Claude Code, Copilot) that
  /// read terminal output and parse log lines programmatically.
  plain,

  /// One NDJSON line per log entry — no decoration, no ANSI.
  ///
  /// Each line is a complete JSON object matching [LogPilotRecord.toJson].
  /// Designed for structured log pipelines, AI agent consumption,
  /// and tools like `jq`.
  json,
}

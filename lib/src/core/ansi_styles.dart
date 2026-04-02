/// ANSI terminal colors for log output.
enum AnsiColor {
  red('\x1B[31m'),
  green('\x1B[32m'),
  yellow('\x1B[33m'),
  blue('\x1B[34m'),
  magenta('\x1B[35m'),
  cyan('\x1B[36m'),
  white('\x1B[37m'),
  grey('\x1B[90m');

  const AnsiColor(this.code);
  final String code;
}

/// ANSI terminal text styles.
enum AnsiStyle {
  bold('\x1B[1m'),
  dim('\x1B[2m'),
  underline('\x1B[4m');

  const AnsiStyle(this.code);
  final String code;
}

const _reset = '\x1B[0m';

/// Whether the environment supports ANSI. Defaults to `true` since
/// `dart:developer.log` (used by LogPilot) renders ANSI in DevTools on all
/// platforms including web. Call [setAnsiSupported] to override.
bool _supportsAnsi = true;

/// Override ANSI support detection (useful for testing or web).
void setAnsiSupported(bool supported) => _supportsAnsi = supported;

/// Whether the environment supports ANSI escape codes.
///
/// Defaults to `true`. [LogPilotConfig.colorize] takes precedence when
/// the user explicitly enables or disables colors.
bool get isAnsiSupported => _supportsAnsi;

/// Apply [color] and/or [style] ANSI codes to [text].
///
/// When [force] is `true`, ANSI codes are applied regardless of
/// terminal detection. This allows [LogPilotConfig.colorize] to
/// override the auto-detected value.
///
/// Returns plain [text] if ANSI is disabled and [force] is `false`.
String ansi(
  String text, {
  AnsiColor? color,
  AnsiStyle? style,
  bool force = false,
}) {
  if (!force && !_supportsAnsi) return text;
  final buffer = StringBuffer();
  if (style != null) buffer.write(style.code);
  if (color != null) buffer.write(color.code);
  buffer
    ..write(text)
    ..write(_reset);
  return buffer.toString();
}

/// Wrap [text] in the given ANSI [color].
///
/// When [force] is `true`, applies color even if the terminal
/// does not auto-detect ANSI support.
String colorize(String text, AnsiColor color, {bool force = false}) =>
    ansi(text, color: color, force: force);

/// Wrap [text] in bold.
String bold(String text, {bool force = false}) =>
    ansi(text, style: AnsiStyle.bold, force: force);

/// Wrap [text] in dim.
String dim(String text, {bool force = false}) =>
    ansi(text, style: AnsiStyle.dim, force: force);

/// Strip all ANSI escape sequences from [text].
String stripAnsi(String text) =>
    text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

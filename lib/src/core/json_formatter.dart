import 'dart:convert';

import 'package:log_pilot/src/core/ansi_styles.dart';
import 'package:log_pilot/src/core/log_pilot_config.dart';

/// Callback that applies ANSI color to [text].
typedef Colorizer = String Function(String text, AnsiColor color);

/// Shared JSON encoding, truncation, sensitive-field masking, and
/// syntax-highlighting utility.
///
/// Used internally by both [LogPilotPrinter] and [NetworkLogFormatter]
/// to avoid duplicating JSON handling logic.
class JsonFormatter {
  JsonFormatter(this._config);

  final LogPilotConfig _config;

  static const _encoder = JsonEncoder.withIndent('  ');

  static final _keyPattern = RegExp(r'^(\s*"[^"]+"\s*:)(.*)$');

  // ── Plain encoding (no ANSI) ──────────────────────────────────────

  /// Encode [value] as pretty-printed JSON lines, truncating if needed.
  ///
  /// Returns plain text (no ANSI). Use [encodeColorized] for
  /// syntax-highlighted output.
  List<String> encode(Object value) {
    final encoded = _encodeMasked(value);
    return _truncate(encoded);
  }

  /// Try to parse [raw] as JSON and pretty-print it.
  ///
  /// Returns `null` if [raw] is not valid JSON.
  List<String>? tryParseAndEncode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> || decoded is List) {
        return encode(decoded);
      }
    } catch (_) {
      // not JSON
    }
    return null;
  }

  // ── Colorized encoding ────────────────────────────────────────────

  /// Encode [value] as pretty-printed JSON with syntax highlighting.
  ///
  /// Keys are colored with [LogPilotConfig.jsonKeyColor], values with
  /// [LogPilotConfig.jsonValueColor]. Structural characters (`{`, `}`,
  /// `[`, `]`, `,`) remain uncolored.
  ///
  /// [applyColor] is the styling function (usually
  /// `LogPilotPrinter.applyColor`) so that `config.colorize: false`
  /// is respected.
  List<String> encodeColorized(Object value, Colorizer applyColor) {
    final plain = encode(value);
    return plain.map((line) => _colorizeLine(line, applyColor)).toList();
  }

  /// Parse [raw] as JSON and return syntax-highlighted lines, or `null`.
  List<String>? tryParseAndEncodeColorized(
    String raw,
    Colorizer applyColor,
  ) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> || decoded is List) {
        return encodeColorized(decoded, applyColor);
      }
    } catch (_) {
      // not JSON
    }
    return null;
  }

  // ── Masking ───────────────────────────────────────────────────────

  /// Recursively mask values whose keys match [LogPilotConfig.maskPatterns].
  Map<String, dynamic> maskSensitiveFields(Map<String, dynamic> json) {
    return json.map((key, value) {
      if (_shouldMask(key)) return MapEntry(key, '***');
      if (value is Map<String, dynamic>) {
        return MapEntry(key, maskSensitiveFields(value));
      }
      if (value is List) {
        return MapEntry(key, _maskList(value));
      }
      return MapEntry(key, value);
    });
  }

  // ── Private ───────────────────────────────────────────────────────

  String _encodeMasked(Object value) {
    try {
      final masked = value is Map<String, dynamic>
          ? maskSensitiveFields(value)
          : value;
      return _encoder.convert(masked);
    } catch (_) {
      return value.toString();
    }
  }

  List<String> _truncate(String encoded) {
    if (encoded.length > _config.maxPayloadSize) {
      final truncated = encoded.substring(0, _config.maxPayloadSize);
      return [
        ...truncated.split('\n'),
        '[...truncated at ${_config.maxPayloadSize ~/ 1024}KB]',
      ];
    }
    return encoded.split('\n');
  }

  /// Apply key/value colors to a single line of pretty-printed JSON.
  ///
  /// Lines that match `"key": value` get the key part colored with
  /// [jsonKeyColor] and the value part with [jsonValueColor].
  /// Structural-only lines (`{`, `}`, `[`, `]`) pass through unchanged.
  String _colorizeLine(String line, Colorizer applyColor) {
    final match = _keyPattern.firstMatch(line);
    if (match == null) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('"')) {
        return applyColor(line, _config.jsonValueColor);
      }
      return line;
    }

    final keyPart = match.group(1)!;
    final valuePart = match.group(2)!;

    final coloredKey = applyColor(keyPart, _config.jsonKeyColor);
    final coloredValue = _colorizeValue(valuePart, applyColor);
    return '$coloredKey$coloredValue';
  }

  String _colorizeValue(String valuePart, Colorizer applyColor) {
    final trimmed = valuePart.trimLeft();
    if (trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.isEmpty) {
      return valuePart;
    }
    final leading = valuePart.substring(
      0,
      valuePart.length - trimmed.length,
    );
    return '$leading${applyColor(trimmed, _config.jsonValueColor)}';
  }

  List<dynamic> _maskList(List<dynamic> list) {
    return list.map((item) {
      if (item is Map<String, dynamic>) return maskSensitiveFields(item);
      if (item is List) return _maskList(item);
      return item;
    }).toList();
  }

  List<_CompiledMaskPattern>? _compiledPatterns;

  List<_CompiledMaskPattern> get _patterns {
    if (_compiledPatterns == null ||
        _compiledPatterns!.length != _config.maskPatterns.length) {
      _compiledPatterns = _config.maskPatterns
          .map(_CompiledMaskPattern.parse)
          .toList(growable: false);
    }
    return _compiledPatterns!;
  }

  bool _shouldMask(String name) {
    final lower = name.toLowerCase();
    for (final p in _patterns) {
      if (p.matches(lower)) return true;
    }
    return false;
  }
}

/// Pre-compiled mask pattern. Supports three forms:
///
/// - `=fieldName`  — exact match (case-insensitive)
/// - `~regex`      — regular expression match (case-insensitive)
/// - `substring`   — case-insensitive substring (original behavior)
///
/// Empty patterns (after stripping prefix) are silently ignored.
/// Invalid regex patterns fall back to substring matching.
class _CompiledMaskPattern {
  _CompiledMaskPattern._(this._kind, this._value, this._regex);

  static final _noop = _CompiledMaskPattern._(_MaskKind.noop, '', null);

  factory _CompiledMaskPattern.parse(String raw) {
    if (raw.startsWith('=')) {
      final value = raw.substring(1).toLowerCase();
      if (value.isEmpty) return _noop;
      return _CompiledMaskPattern._(_MaskKind.exact, value, null);
    }
    if (raw.startsWith('~')) {
      final source = raw.substring(1);
      if (source.isEmpty) return _noop;
      try {
        return _CompiledMaskPattern._(
          _MaskKind.regex,
          source,
          RegExp(source, caseSensitive: false),
        );
      } catch (_) {
        return _CompiledMaskPattern._(
          _MaskKind.substring,
          source.toLowerCase(),
          null,
        );
      }
    }
    if (raw.isEmpty) return _noop;
    return _CompiledMaskPattern._(_MaskKind.substring, raw.toLowerCase(), null);
  }

  final _MaskKind _kind;
  final String _value;
  final RegExp? _regex;

  /// [name] is expected to be already lower-cased.
  bool matches(String name) => switch (_kind) {
        _MaskKind.exact => name == _value,
        _MaskKind.regex => _regex!.hasMatch(name),
        _MaskKind.substring => name.contains(_value),
        _MaskKind.noop => false,
      };
}

enum _MaskKind { exact, regex, substring, noop }

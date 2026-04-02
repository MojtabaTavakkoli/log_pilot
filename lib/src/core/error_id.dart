/// Generates a deterministic, short hash-based ID for an error signature.
///
/// The ID is built from three components:
/// 1. The error's runtime type name
/// 2. A normalized message pattern (numbers removed to group similar errors)
/// 3. The top non-framework stack frame (if available)
///
/// This lets AI agents reference errors by stable ID across debugging
/// sessions: "Error `lk-e3a9f2` occurred 4 times in the last 60s."
String generateErrorId({
  required Object error,
  StackTrace? stackTrace,
}) {
  final typeName = error.runtimeType.toString();
  final message = _normalizeMessage(error.toString());
  final topFrame = _extractTopFrame(stackTrace);

  final signature = '$typeName|$message|$topFrame';
  final hash = _fnv1a32(signature);
  return 'lk-${hash.toRadixString(16).padLeft(6, '0').substring(0, 6)}';
}

/// Strip numbers so that "index 5 out of range 10" and
/// "index 3 out of range 8" produce the same normalized form.
String _normalizeMessage(String msg) {
  return msg.replaceAll(RegExp(r'\d+'), '#');
}

/// Extract the first useful stack frame (not from dart: or package:log_pilot/).
String _extractTopFrame(StackTrace? st) {
  if (st == null) return '';
  final lines = st.toString().split('\n');
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      final content = trimmed.replaceFirst(RegExp(r'^#\d+\s+'), '');
      if (content.contains('dart:')) continue;
      if (content.contains('package:log_pilot/')) continue;
      if (content.contains('package:flutter/')) continue;
      if (content.isEmpty) continue;
      return content.replaceAll(RegExp(r':\d+'), ':#');
    }
  }
  return '';
}

/// FNV-1a 32-bit hash — fast, no crypto dependency, good distribution.
int _fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

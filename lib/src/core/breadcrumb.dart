import 'dart:collection';

import 'package:meta/meta.dart';

/// A lightweight event marker captured before an error occurs.
///
/// Breadcrumbs record the trail of activity leading up to an error,
/// giving AI agents and developers immediate pre-crash context
/// without scrolling through the full log history.
///
/// Modeled after Sentry's breadcrumb pattern — lighter than a full
/// [LogPilotRecord] and focused on the "what happened before" narrative.
@immutable
class Breadcrumb {
  const Breadcrumb({
    required this.timestamp,
    required this.message,
    this.category,
    this.metadata,
  });

  final DateTime timestamp;
  final String message;

  /// Optional category tag (e.g. `'nav'`, `'api'`, `'state'`, `'ui'`).
  final String? category;

  /// Optional structured data attached to this breadcrumb.
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'message': message,
        if (category != null) 'category': category,
        if (metadata != null && metadata!.isNotEmpty) 'metadata': metadata,
      };

  @override
  String toString() {
    final cat = category != null ? '[$category] ' : '';
    return '$cat$message';
  }
}

/// A fixed-size circular buffer for [Breadcrumb]s.
///
/// Automatically evicts the oldest crumb when full. Thread-safe for
/// single-isolate use (the common Flutter case).
class BreadcrumbBuffer {
  BreadcrumbBuffer(this.maxSize) : assert(maxSize > 0);

  final int maxSize;
  final Queue<Breadcrumb> _buffer = Queue<Breadcrumb>();

  void add(Breadcrumb crumb) {
    if (_buffer.length >= maxSize) {
      _buffer.removeFirst();
    }
    _buffer.addLast(crumb);
  }

  /// Snapshot of all breadcrumbs, oldest first.
  List<Breadcrumb> get crumbs => List.unmodifiable(_buffer);

  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;

  void clear() => _buffer.clear();
}

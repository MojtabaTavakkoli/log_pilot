import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../log_entry.dart';

/// Drill-down detail view for a single log record.
///
/// Shows the full message, metadata as a JSON tree, error + stack trace,
/// error ID, and the breadcrumb trail as a timeline.
class LogDetailScreen extends StatelessWidget {
  const LogDetailScreen({super.key, required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _LevelBadge(level: entry.level),
            const SizedBox(width: denseSpacing),
            Expanded(
              child: Text(
                entry.message ?? '(no message)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy as JSON',
            onPressed: () {
              final json = const JsonEncoder.withIndent('  ').convert(_toMap());
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied record JSON')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultSpacing),
        children: [
          _buildHeader(context),
          if (entry.message != null) ...[
            const SizedBox(height: defaultSpacing),
            _Section(
              title: 'Message',
              child: SelectableText(
                entry.message!,
                style: Theme.of(context).fixedFontStyle,
              ),
            ),
          ],
          if (entry.hasMetadata) ...[
            const SizedBox(height: defaultSpacing),
            _Section(
              title: 'Metadata',
              child: _JsonTree(data: entry.metadata!),
            ),
          ],
          if (entry.hasError) ...[
            const SizedBox(height: defaultSpacing),
            _Section(
              title: 'Error',
              child: SelectableText(
                entry.error!,
                style: Theme.of(context).fixedFontStyle.copyWith(
                      color: Colors.red.shade300,
                    ),
              ),
            ),
          ],
          if (entry.hasStack) ...[
            const SizedBox(height: defaultSpacing),
            _Section(
              title: 'Stack Trace',
              child: SelectableText(
                entry.stackTrace!,
                style: Theme.of(context).fixedFontStyle.copyWith(fontSize: 11),
              ),
            ),
          ],
          if (entry.hasBreadcrumbs) ...[
            const SizedBox(height: defaultSpacing),
            _Section(
              title: 'Breadcrumbs (${entry.breadcrumbs!.length})',
              child: _BreadcrumbTimeline(breadcrumbs: entry.breadcrumbs!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.fixedFontStyle.copyWith(fontSize: 12);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(denseSpacing),
        child: Wrap(
          spacing: defaultSpacing,
          runSpacing: densePadding,
          children: [
            _KV(label: 'Time', value: entry.timestamp.toIso8601String(), mono: mono),
            _KV(label: 'Level', value: entry.level.label, mono: mono),
            if (entry.tag != null) _KV(label: 'Tag', value: entry.tag!, mono: mono),
            if (entry.errorId != null)
              _KV(
                label: 'Error ID',
                value: entry.errorId!,
                mono: mono,
                copyable: true,
                context: context,
              ),
            if (entry.sessionId != null)
              _KV(label: 'Session', value: entry.sessionId!, mono: mono),
            if (entry.traceId != null)
              _KV(label: 'Trace', value: entry.traceId!, mono: mono),
            if (entry.caller != null)
              _KV(label: 'Caller', value: entry.caller!, mono: mono),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _toMap() => {
        'level': entry.level.label,
        'timestamp': entry.timestamp.toIso8601String(),
        if (entry.sessionId != null) 'sessionId': entry.sessionId,
        if (entry.traceId != null) 'traceId': entry.traceId,
        if (entry.errorId != null) 'errorId': entry.errorId,
        if (entry.message != null) 'message': entry.message,
        if (entry.tag != null) 'tag': entry.tag,
        if (entry.caller != null) 'caller': entry.caller,
        if (entry.hasMetadata) 'metadata': entry.metadata,
        if (entry.hasError) 'error': entry.error,
        if (entry.hasStack) 'stackTrace': entry.stackTrace,
      };
}

// ── Shared widgets ──

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final LogEntryLevel level;

  @override
  Widget build(BuildContext context) {
    final color = _colorForLevel(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: densePadding),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(denseSpacing),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _KV extends StatelessWidget {
  const _KV({
    required this.label,
    required this.value,
    required this.mono,
    this.copyable = false,
    this.context,
  });

  final String label;
  final String value;
  final TextStyle mono;
  final bool copyable;
  final BuildContext? context;

  @override
  Widget build(BuildContext ctx) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        SelectableText(value, style: mono),
        if (copyable)
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 12,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              if (context != null && context!.mounted) {
                ScaffoldMessenger.of(context!).showSnackBar(
                  SnackBar(content: Text('Copied $label')),
                );
              }
            },
          ),
      ],
    );
  }
}

/// Expandable JSON tree view for metadata.
class _JsonTree extends StatelessWidget {
  const _JsonTree({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final mono = Theme.of(context).fixedFontStyle.copyWith(fontSize: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in data.entries)
          _buildEntry(entry.key, entry.value, mono, 0),
      ],
    );
  }

  Widget _buildEntry(String key, dynamic value, TextStyle mono, int depth) {
    final indent = depth * 16.0;

    if (value is Map<String, dynamic>) {
      return Padding(
        padding: EdgeInsets.only(left: indent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(key, style: mono.copyWith(fontWeight: FontWeight.bold)),
          dense: true,
          childrenPadding: EdgeInsets.zero,
          children: [
            for (final e in value.entries) _buildEntry(e.key, e.value, mono, depth + 1),
          ],
        ),
      );
    }

    final display = value is String ? '"$value"' : value.toString();
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$key: ', style: mono.copyWith(fontWeight: FontWeight.bold)),
          Expanded(child: SelectableText(display, style: mono)),
        ],
      ),
    );
  }
}

/// Timeline view for breadcrumbs leading up to an error.
class _BreadcrumbTimeline extends StatelessWidget {
  const _BreadcrumbTimeline({required this.breadcrumbs});

  final List<BreadcrumbEntry> breadcrumbs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.fixedFontStyle.copyWith(fontSize: 11);

    return Column(
      children: [
        for (var i = 0; i < breadcrumbs.length; i++)
          _buildCrumb(breadcrumbs[i], i == breadcrumbs.length - 1, theme, mono),
      ],
    );
  }

  Widget _buildCrumb(
    BreadcrumbEntry crumb,
    bool isLast,
    ThemeData theme,
    TextStyle mono,
  ) {
    final ts = _formatTimestamp(crumb.timestamp);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: theme.dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(ts, style: mono.copyWith(color: theme.hintColor)),
                      if (crumb.category != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            crumb.category!,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(crumb.message, style: mono),
                  if (crumb.metadata != null && crumb.metadata!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      jsonEncode(crumb.metadata),
                      style: mono.copyWith(color: theme.hintColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

Color _colorForLevel(LogEntryLevel level) {
  return switch (level) {
    LogEntryLevel.verbose => Colors.grey,
    LogEntryLevel.debug => Colors.blue,
    LogEntryLevel.info => Colors.green,
    LogEntryLevel.warning => Colors.orange,
    LogEntryLevel.error => Colors.red,
    LogEntryLevel.fatal => Colors.purple,
  };
}

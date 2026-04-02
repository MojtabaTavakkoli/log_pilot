import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../log_entry.dart';
import '../log_pilot_controller.dart';
import 'log_detail_screen.dart';

/// Main screen: log table with level/tag filters, search, and toolbar actions.
class LogListScreen extends StatefulWidget {
  const LogListScreen({super.key, required this.controller});

  final LogPilotController controller;

  @override
  State<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends State<LogListScreen> {
  LogEntryLevel? _levelFilter;
  String? _tagFilter;
  String _searchQuery = '';
  bool _autoScroll = true;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  LogPilotController get _ctrl => widget.controller;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredEntries {
    var list = _ctrl.entries.value;
    if (_levelFilter != null) {
      list = list.where((e) => e.level == _levelFilter).toList();
    }
    if (_tagFilter != null) {
      list = list.where((e) => e.tag == _tagFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        return (e.message?.toLowerCase().contains(q) ?? false) ||
            (e.tag?.toLowerCase().contains(q) ?? false) ||
            (e.error?.toLowerCase().contains(q) ?? false) ||
            (e.errorId?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return list;
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        _buildFilterBar(context),
        Expanded(child: _buildLogTable(context)),
      ],
    );
  }

  // ── Toolbar ──

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return AreaPaneHeader(
      title: Row(
        children: [
          const Text('LogPilot'),
          const SizedBox(width: denseSpacing),
          ValueListenableBuilder<bool>(
            valueListenable: _ctrl.isConnected,
            builder: (_, connected, __) => Icon(
              connected ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: connected ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: denseSpacing),
          ValueListenableBuilder<bool>(
            valueListenable: _ctrl.isLoading,
            builder: (_, loading, __) => loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      actions: [
        _ToolbarButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: _ctrl.refresh,
        ),
        _ToolbarButton(
          icon: Icons.delete_outline,
          tooltip: 'Clear history',
          onPressed: () async {
            await _ctrl.clearHistory();
            setState(() {});
          },
        ),
        _LogLevelMenu(controller: _ctrl),
        _ExportMenu(controller: _ctrl),
        _ToolbarButton(
          icon: Icons.camera_alt_outlined,
          tooltip: 'Snapshot',
          onPressed: () async {
            final snap = await _ctrl.getSnapshot();
            if (!context.mounted) return;
            _showTextDialog(context, 'Diagnostic Snapshot', snap);
          },
        ),
        IconButton(
          icon: Icon(
            _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center,
            size: defaultIconSize,
          ),
          tooltip: _autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF',
          onPressed: () => setState(() => _autoScroll = !_autoScroll),
          splashRadius: defaultIconSize,
          color: _autoScroll
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  // ── Filter bar ──

  Widget _buildFilterBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: denseSpacing,
        vertical: densePadding,
      ),
      child: Row(
        children: [
          // Level filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _LevelChip(
                    label: 'ALL',
                    selected: _levelFilter == null,
                    onTap: () => setState(() => _levelFilter = null),
                  ),
                  for (final level in LogEntryLevel.values)
                    _LevelChip(
                      label: level.label,
                      color: _colorForLevel(level),
                      selected: _levelFilter == level,
                      onTap: () => setState(
                        () => _levelFilter = _levelFilter == level ? null : level,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: denseSpacing),
          // Tag filter
          ValueListenableBuilder<Set<String>>(
            valueListenable: _ctrl.tags,
            builder: (_, tagSet, __) {
              if (tagSet.isEmpty) return const SizedBox.shrink();
              final sortedTags = tagSet.toList()..sort();
              return SizedBox(
                width: 120,
                child: DropdownButtonFormField<String?>(
                  initialValue: _tagFilter,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Tag',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: densePadding,
                      vertical: densePadding,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final tag in sortedTags)
                      DropdownMenuItem(value: tag, child: Text(tag)),
                  ],
                  onChanged: (v) => setState(() => _tagFilter = v),
                ),
              );
            },
          ),
          const SizedBox(width: denseSpacing),
          // Search bar
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: defaultIconSize),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: densePadding,
                  vertical: densePadding,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: defaultIconSize),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        splashRadius: defaultIconSize,
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  // ── Log table ──

  Widget _buildLogTable(BuildContext context) {
    return ValueListenableBuilder<List<LogEntry>>(
      valueListenable: _ctrl.entries,
      builder: (_, __, ___) {
        return ValueListenableBuilder<String?>(
          valueListenable: _ctrl.error,
          builder: (context, errorMsg, _) {
            if (errorMsg != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(defaultSpacing),
                  child: Text(
                    errorMsg,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            }

            final filtered = _filteredEntries;
            if (filtered.isEmpty) {
              return const Center(child: Text('No log entries'));
            }

            _scrollToBottom();
            return ListView.builder(
              controller: _scrollController,
              itemCount: filtered.length,
              itemBuilder: (context, i) => _LogRow(
                entry: filtered[i],
                onTap: () => _openDetail(context, filtered[i]),
              ),
            );
          },
        );
      },
    );
  }

  void _openDetail(BuildContext context, LogEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogDetailScreen(entry: entry),
      ),
    );
  }

  void _showTextDialog(BuildContext context, String title, String content) {
    String formatted = content;
    try {
      final decoded = jsonDecode(content);
      formatted = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              formatted,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: formatted));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──

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

// ── Small widgets ──

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: defaultIconSize),
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: defaultIconSize,
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.white : color,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: selected,
        selectedColor: color ?? Theme.of(context).colorScheme.primary,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.onTap});

  final LogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final levelColor = _colorForLevel(entry.level);
    final ts = _formatTimestamp(entry.timestamp);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: denseSpacing,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                ts,
                style: theme.fixedFontStyle.copyWith(fontSize: 11),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                entry.level.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: levelColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (entry.tag != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.tag!,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                entry.message ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.fixedFontStyle.copyWith(fontSize: 12),
              ),
            ),
            if (entry.errorId != null) ...[
              const SizedBox(width: 6),
              Text(
                entry.errorId!,
                style: TextStyle(
                  fontSize: 10,
                  color: levelColor.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (entry.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.error_outline, size: 14, color: Colors.red.shade300),
              ),
          ],
        ),
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

class _LogLevelMenu extends StatelessWidget {
  const _LogLevelMenu({required this.controller});

  final LogPilotController controller;

  static const _levels = [
    'verbose',
    'debug',
    'info',
    'warning',
    'error',
    'fatal',
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: controller.currentLogLevel,
      builder: (context, currentLevel, _) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.tune, size: defaultIconSize),
          tooltip: 'Set log level',
          onSelected: controller.setLogLevel,
          itemBuilder: (_) => [
            for (final level in _levels)
              PopupMenuItem(
                value: level,
                child: Row(
                  children: [
                    if (level == currentLevel)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(level.toUpperCase()),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({required this.controller});

  final LogPilotController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.download, size: defaultIconSize),
      tooltip: 'Export logs',
      onSelected: (format) async {
        final result = await controller.exportLogs(format: format);
        if (!context.mounted) return;
        Clipboard.setData(ClipboardData(text: result));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported as $format — copied to clipboard')),
        );
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'text', child: Text('Export as Text')),
        PopupMenuItem(value: 'json', child: Text('Export as JSON (NDJSON)')),
      ],
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:log_pilot/src/core/log_history.dart';
import 'package:log_pilot/src/core/log_level.dart';
import 'package:log_pilot/src/core/log_pilot_record.dart';
import 'package:log_pilot/src/errors/log_pilot_zone.dart';
import 'package:log_pilot/src/log_pilot.dart';

/// A debug overlay that displays recent log records in a draggable,
/// resizable sheet.
///
/// The overlay reads from [LogPilot.history] and auto-updates as new logs
/// arrive via [LogHistory.onChanged]. Supports filtering by level and
/// searching by message text.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => LogPilotOverlay(child: child!),
///   home: const MyHome(),
/// )
/// ```
///
/// In production, the overlay is automatically hidden when
/// [LogPilotConfig.enabled] is `false`.
class LogPilotOverlay extends StatefulWidget {
  /// Wrap your app's root widget with [LogPilotOverlay] to enable the
  /// debug log viewer.
  const LogPilotOverlay({
    super.key,
    required this.child,
    this.enabled,
    this.entryButtonAlignment = Alignment.bottomRight,
  });

  /// The widget below this one in the tree (typically your app).
  final Widget child;

  /// Override the auto-detection of [LogPilotConfig.enabled]. Set to
  /// `false` to hide the overlay even in debug mode.
  final bool? enabled;

  /// Where the floating action button appears on screen.
  final Alignment entryButtonAlignment;

  @override
  State<LogPilotOverlay> createState() => _LogPilotOverlayState();
}

class _LogPilotOverlayState extends State<LogPilotOverlay> {
  bool _sheetOpen = false;

  bool get _enabled => widget.enabled ?? LogPilot.config.enabled;

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_sheetOpen)
            _LogPilotSheet(onClose: () => setState(() => _sheetOpen = false)),
          if (!_sheetOpen)
            Positioned.fill(
              child: Align(
                alignment: widget.entryButtonAlignment,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _EntryButton(
                    onTap: () => setState(() => _sheetOpen = true),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Colors.deepPurple,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.terminal_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _LogPilotSheet extends StatefulWidget {
  const _LogPilotSheet({required this.onClose});
  final VoidCallback onClose;

  @override
  State<_LogPilotSheet> createState() => _LogPilotSheetState();
}

class _LogPilotSheetState extends State<_LogPilotSheet> {
  LogLevel? _levelFilter;
  String? _tagFilter;
  String _search = '';
  List<LogPilotRecord> _records = [];
  bool _autoScroll = true;
  bool _refreshScheduled = false;
  LogPilotRecord? _detailRecord;
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _records = _fetchRecords();
    LogPilotZone.history?.onChanged.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    LogPilotZone.history?.onChanged.removeListener(_onHistoryChanged);
    _sheetCtrl.dispose();
    super.dispose();
  }

  void _onHistoryChanged() {
    if (_refreshScheduled || !mounted) return;
    _refreshScheduled = true;
    Future.microtask(() {
      _refreshScheduled = false;
      if (!mounted) return;
      setState(() {
        _records = _fetchRecords();
      });
    });
  }

  Set<String> get _allTags =>
      LogPilot.history.map((r) => r.tag).whereType<String>().toSet();

  List<LogPilotRecord> _fetchRecords() {
    var all = LogPilot.historyWhere(
      level: _levelFilter,
      tag: _tagFilter,
    );
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      all = all
          .where((r) =>
              (r.message?.toLowerCase().contains(q) ?? false) ||
              (r.tag?.toLowerCase().contains(q) ?? false) ||
              r.level.label.toLowerCase().contains(q))
          .toList();
    }
    return all;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _records = _fetchRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black87;
    final cs = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              controller: _sheetCtrl,
              initialChildSize: 0.5,
              minChildSize: 0.25,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.25, 0.5, 0.75, 1.0],
              builder: (context, scrollController) {
                return Material(
                  color: bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  elevation: 12,
                  child: _detailRecord != null
                      ? _RecordDetailInline(
                          record: _detailRecord!,
                          onBack: () =>
                              setState(() => _detailRecord = null),
                          scrollController: scrollController,
                        )
                      : Column(
                          children: [
                            _buildDragHandle(fg),
                            _buildHeader(bg, fg, cs),
                            _buildFilters(bg, fg, cs),
                            Expanded(
                              child: _buildList(bg, fg, scrollController),
                            ),
                            _buildFooter(bg, fg, cs),
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle(Color fg) {
    return Center(
      child: Container(
        width: 32,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(Color bg, Color fg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Text('LogPilot Viewer',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: fg)),
          const Spacer(),
          Text('${_records.length} records',
              style:
                  TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.6))),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.delete_sweep_rounded,
            onTap: () {
              LogPilot.clearHistory();
              _refresh();
            },
          ),
          _IconBtn(
            icon: Icons.close_rounded,
            onTap: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color bg, Color fg, ColorScheme cs) {
    final tags = _allTags.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: TextField(
              style: TextStyle(fontSize: 13, color: fg),
              decoration: InputDecoration(
                hintText: 'Search logs...',
                hintStyle: TextStyle(color: fg.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search,
                    size: 18, color: fg.withValues(alpha: 0.4)),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: fg.withValues(alpha: 0.06),
              ),
              onChanged: (v) {
                _search = v;
                _refresh();
              },
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                    label: 'ALL',
                    selected: _levelFilter == null,
                    onTap: () {
                      _levelFilter = null;
                      _refresh();
                    }),
                for (final level in LogLevel.values)
                  _FilterChip(
                    label: level.label,
                    color: _colorForLevel(level),
                    selected: _levelFilter == level,
                    onTap: () {
                      _levelFilter = level;
                      _refresh();
                    },
                  ),
              ],
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'All Tags',
                    selected: _tagFilter == null,
                    color: cs.secondary,
                    onTap: () {
                      _tagFilter = null;
                      _refresh();
                    },
                  ),
                  for (final tag in tags)
                    _FilterChip(
                      label: tag,
                      selected: _tagFilter == tag,
                      color: _colorForTag(tag),
                      onTap: () {
                        _tagFilter = tag;
                        _refresh();
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(Color bg, Color fg, ScrollController scrollController) {
    if (_records.isEmpty) {
      return Center(
        child: Text('No logs yet',
            style: TextStyle(color: fg.withValues(alpha: 0.4))),
      );
    }
    return ListView.builder(
      controller: scrollController,
      itemCount: _records.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (_, i) => _LogTile(
        record: _records[i],
        onTap: () => _showRecordDetail(context, _records[i]),
      ),
    );
  }

  void _showRecordDetail(BuildContext context, LogPilotRecord record) {
    setState(() => _detailRecord = record);
  }

  Widget _buildFooter(Color bg, Color fg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _IconBtn(
            icon: _autoScroll
                ? Icons.vertical_align_bottom_rounded
                : Icons.pause_rounded,
            onTap: () => setState(() => _autoScroll = !_autoScroll),
          ),
          const Spacer(),
          _IconBtn(
            icon: Icons.copy_rounded,
            onTap: () {
              final text = LogPilot.export();
              if (text.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: text));
              }
            },
          ),
          _IconBtn(
            icon: Icons.data_object_rounded,
            onTap: () {
              final json = LogPilot.export(format: ExportFormat.json);
              if (json.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: json));
              }
            },
          ),
        ],
      ),
    );
  }

  static Color _colorForLevel(LogLevel level) {
    return switch (level) {
      LogLevel.verbose => Colors.blueGrey,
      LogLevel.debug => Colors.blue,
      LogLevel.info => Colors.green,
      LogLevel.warning => Colors.orange,
      LogLevel.error => Colors.red,
      LogLevel.fatal => Colors.purple,
    };
  }

  static const _tagColors = [
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.deepOrange,
    Colors.lime,
    Colors.brown,
  ];

  static Color _colorForTag(String tag) =>
      _tagColors[(tag.hashCode & 0x7FFFFFFF) % _tagColors.length];
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.record, this.onTap});
  final LogPilotRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white70 : Colors.black87;
    final color = _LogPilotSheetState._colorForLevel(record.level);
    final time = record.timestamp;
    final ts =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${time.millisecond.toString().padLeft(3, '0')}';

    final hasDetail = record.metadata != null ||
        record.error != null ||
        record.stackTrace != null ||
        record.breadcrumbs != null ||
        record.caller != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(ts,
                style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: fg.withValues(alpha: 0.5))),
            const SizedBox(width: 6),
            if (record.tag != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(record.tag!,
                    style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            Expanded(
              child: Text(
                record.message ?? record.error?.toString() ?? '',
                style:
                    TextStyle(fontSize: 12, color: fg, fontFamily: 'monospace'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasDetail)
              Icon(Icons.chevron_right, size: 14, color: fg.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    final c = color ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: selected ? c.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? c : c.withValues(alpha: 0.3), width: 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected ? c : c.withValues(alpha: 0.6))),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

/// Inline detailed view for a single [LogPilotRecord], displayed within the
/// existing sheet instead of a separate modal.
///
/// Displays all record fields including metadata, error, stack trace,
/// breadcrumbs, caller, IDs, and timestamps. Supports copy-to-clipboard
/// for individual sections and the entire record as JSON.
class _RecordDetailInline extends StatelessWidget {
  const _RecordDetailInline({
    required this.record,
    required this.onBack,
    required this.scrollController,
  });
  final LogPilotRecord record;
  final VoidCallback onBack;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    final dimFg = fg.withValues(alpha: 0.6);
    final color = _LogPilotSheetState._colorForLevel(record.level);

    return Column(
      children: [
        _detailHeader(color, fg, dimFg),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _sectionRow('Level', record.level.label, fg, dimFg),
              _sectionRow(
                'Time',
                record.timestamp.toIso8601String(),
                fg,
                dimFg,
              ),
              if (record.tag != null)
                _sectionRow('Tag', record.tag!, fg, dimFg),
              if (record.message != null)
                _sectionBlock('Message', record.message!, fg, dimFg),
              if (record.caller != null)
                _sectionRow('Caller', record.caller!, fg, dimFg),
              if (record.sessionId != null)
                _sectionRow('Session ID', record.sessionId!, fg, dimFg),
              if (record.traceId != null)
                _sectionRow('Trace ID', record.traceId!, fg, dimFg),
              if (record.errorId != null)
                _sectionRow('Error ID', record.errorId!, fg, dimFg),
              if (record.metadata != null)
                _sectionBlock(
                  'Metadata',
                  _prettyJson(record.metadata!),
                  fg,
                  dimFg,
                ),
              if (record.error != null)
                _sectionBlock(
                  'Error',
                  record.error.toString(),
                  fg,
                  dimFg,
                  textColor: Colors.red,
                ),
              if (record.stackTrace != null)
                _sectionBlock(
                  'Stack Trace',
                  record.stackTrace.toString(),
                  fg,
                  dimFg,
                ),
              if (record.breadcrumbs != null &&
                  record.breadcrumbs!.isNotEmpty)
                _breadcrumbSection(fg, dimFg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailHeader(Color color, Color fg, Color dimFg) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: fg.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Record Detail',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: fg),
            ),
          ),
          _IconBtn(
            icon: Icons.copy_all_rounded,
            onTap: () {
              Clipboard.setData(
                ClipboardData(text: record.toJsonString()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionRow(String label, String value, Color fg, Color dimFg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dimFg)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style:
                  TextStyle(fontSize: 12, fontFamily: 'monospace', color: fg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBlock(
    String label,
    String value,
    Color fg,
    Color dimFg, {
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dimFg)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Clipboard.setData(ClipboardData(text: value)),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.copy, size: 12, color: dimFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: fg.withValues(alpha: 0.08)),
            ),
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: textColor ?? fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumbSection(Color fg, Color dimFg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Breadcrumbs (${record.breadcrumbs!.length})',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: dimFg)),
          const SizedBox(height: 4),
          for (final crumb in record.breadcrumbs!)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: dimFg),
                  const SizedBox(width: 6),
                  if (crumb.category != null)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(crumb.category!,
                          style: TextStyle(fontSize: 9, color: dimFg)),
                    ),
                  Expanded(
                    child: Text(crumb.message,
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: fg)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _prettyJson(Map<String, dynamic> data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }
}

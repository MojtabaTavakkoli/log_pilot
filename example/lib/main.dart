import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:log_pilot/log_pilot.dart';
import 'package:log_pilot/log_pilot_bloc.dart';

import 'platform_sinks.dart'
    if (dart.library.io) 'platform_sinks_io.dart' as platform;

// ─── Setup ───────────────────────────────────────────────────────────────────
//
// Three ways to use LogPilot (pick one):
//
//   1. Full setup — error zones + logging + sinks:
//        LogPilot.init(config: ..., child: MyApp());
//
//   2. Config only — just logging, you call runApp() yourself:
//        LogPilot.configure(config: ...);
//        runApp(MyApp());
//
//   3. Zero setup — works in debug mode with defaults:
//        LogPilot.info('it just works');
//

final sinkRecords = ValueNotifier<List<LogPilotRecord>>([]);

void main() async {
  Bloc.observer = const LogPilotBlocObserver();

  final platformSinks = await platform.createSinks();

  LogPilot.init(
    config: LogPilotConfig.debug(
      maskPatterns: const [
        'Authorization',
        '=password',
        '~^(access|refresh)_token\$',
        'secret',
      ],
      deduplicateWindow: const Duration(seconds: 5),
      sinks: [
        CallbackSink((record) {
          sinkRecords.value = [...sinkRecords.value, record];
        }),
        ...platformSinks,
      ],
    ),
    onError: (error, stack) {
      // In production, forward to Crashlytics / Sentry here.
    },
    child: const LogPilotExampleApp(),
  );
}

// ─── App Shell ──────────────────────────────────────────────────────────────

class LogPilotExampleApp extends StatelessWidget {
  const LogPilotExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LogPilot Demo',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [LogPilotNavigatorObserver()],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C5CE7),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) => LogPilotOverlay(child: child!),
      home: const _ExampleHome(),
    );
  }
}

// ─── Home Screen ────────────────────────────────────────────────────────────

class _ExampleHome extends StatelessWidget {
  const _ExampleHome();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('LogPilot'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primaryContainer,
                      cs.secondaryContainer,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(
              children: [
                const _DescriptionCard(
                  'Tap any button and check your debug console. '
                  'Every feature produces a prettified, box-bordered log.',
                ),
                const SizedBox(height: 12),
                const _SinkCounter(),
                const SizedBox(height: 20),
                _buildLogLevels(context),
                const SizedBox(height: 20),
                _buildJsonSection(context),
                const SizedBox(height: 20),
                _buildErrorSection(context),
                const SizedBox(height: 20),
                _buildNetworkSection(context),
                const SizedBox(height: 20),
                _buildTagSection(context),
                const SizedBox(height: 20),
                _buildInstanceLoggerSection(context),
                const SizedBox(height: 20),
                _buildSinkSection(context),
                const SizedBox(height: 20),
                _buildDeduplicationSection(context),
                const SizedBox(height: 20),
                _buildFileSinkSection(context),
                const SizedBox(height: 20),
                _buildHistorySection(context),
                const SizedBox(height: 20),
                _buildCorrelationSection(context),
                const SizedBox(height: 20),
                _buildNavigationSection(context),
                const SizedBox(height: 20),
                _buildBlocSection(context),
                const SizedBox(height: 20),
                _buildTimingSection(context),
                const SizedBox(height: 20),
                _buildOverlaySection(context),
                const SizedBox(height: 20),
                _buildOutputFormatSection(context),
                const SizedBox(height: 20),
                _buildSnapshotSection(context),
                const SizedBox(height: 20),
                _buildBreadcrumbSection(context),
                const SizedBox(height: 20),
                _buildErrorIdSection(context),
                const SizedBox(height: 20),
                _buildLogLevelOverrideSection(context),
                const SizedBox(height: 20),
                _buildInstrumentSection(context),
                const SizedBox(height: 20),
                _buildLlmExportSection(context),
                const SizedBox(height: 20),
                _buildDevToolsSection(context),
                const SizedBox(height: 20),
                _buildMcpTailSection(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Log Levels ─────────────────────────────────────────────────────

  Widget _buildLogLevels(BuildContext context) {
    return _Section(
      icon: Icons.sort_rounded,
      title: '1. Log Levels',
      subtitle: '6 severity levels, each with a distinct color',
      children: [
        _ActionTile(
          icon: Icons.graphic_eq_rounded,
          title: 'Verbose',
          subtitle: 'LogPilot.verbose("Background sync...")',
          color: Colors.blueGrey,
          onTap: () => LogPilot.verbose('Background sync starting...'),
        ),
        _ActionTile(
          icon: Icons.bug_report_outlined,
          title: 'Debug',
          subtitle: 'LogPilot.debug("Cache key: user_42")',
          color: Colors.blue,
          onTap: () => LogPilot.debug('Cache key resolved: user_42'),
        ),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: 'Info + Metadata',
          subtitle: 'LogPilot.info("User signed in", metadata: {...})',
          color: Colors.green,
          onTap: () => LogPilot.info(
            'User signed in',
            metadata: {
              'userId': '123',
              'plan': 'pro',
              'loginMethod': 'google',
            },
          ),
        ),
        _ActionTile(
          icon: Icons.warning_amber_rounded,
          title: 'Warning',
          subtitle: 'LogPilot.warning("Retry attempt 3/5")',
          color: Colors.orange,
          onTap: () => LogPilot.warning('Retry attempt 3 of 5'),
        ),
        _ActionTile(
          icon: Icons.error_outline_rounded,
          title: 'Error + Stack Trace',
          subtitle: 'LogPilot.error("Checkout failed", error: e, stackTrace: st)',
          color: Colors.red,
          onTap: () {
            try {
              throw Exception('Payment declined: insufficient funds');
            } catch (e, st) {
              LogPilot.error('Checkout failed', error: e, stackTrace: st);
            }
          },
        ),
        _ActionTile(
          icon: Icons.dangerous_rounded,
          title: 'Fatal',
          subtitle: 'LogPilot.fatal("Database corrupted")',
          color: Colors.purple,
          onTap: () => LogPilot.fatal('Database corrupted — cannot recover'),
        ),
      ],
    );
  }

  // ── 2. JSON ───────────────────────────────────────────────────────────

  Widget _buildJsonSection(BuildContext context) {
    return _Section(
      icon: Icons.data_object_rounded,
      title: '2. JSON Pretty-Print',
      subtitle: 'Auto-detect, indent, and colorize keys vs values',
      children: [
        _ActionTile(
          icon: Icons.account_tree_rounded,
          title: 'Nested Object',
          subtitle: 'LogPilot.json(\'{"users":[...]}\')  — keys cyan, values green',
          color: Colors.teal,
          onTap: () => LogPilot.json(
            '{"users":[{"id":1,"name":"Alice","email":"alice@example.com",'
            '"address":{"city":"Wonderland","zip":"12345"}},'
            '{"id":2,"name":"Bob","email":"bob@example.com",'
            '"address":{"city":"Springfield","zip":"67890"}}]}',
          ),
        ),
        _ActionTile(
          icon: Icons.data_array_rounded,
          title: 'Array',
          subtitle: 'LogPilot.json(\'[1, 2, {"nested": true}]\')',
          color: Colors.teal.shade700,
          onTap: () => LogPilot.json('[1, 2, {"nested": true, "items": [3, 4]}]'),
        ),
        _ActionTile(
          icon: Icons.text_snippet_outlined,
          title: 'Invalid JSON',
          subtitle: 'Falls back to raw text output',
          color: Colors.grey,
          onTap: () => LogPilot.json('this is not valid json'),
        ),
      ],
    );
  }

  // ── 3. Flutter Errors ─────────────────────────────────────────────────

  Widget _buildErrorSection(BuildContext context) {
    return _Section(
      icon: Icons.flash_on_rounded,
      title: '3. Flutter Error Catching',
      subtitle: '15+ contextual hints, simplified stacks, clickable source',
      children: [
        _ActionTile(
          icon: Icons.aspect_ratio_rounded,
          title: 'RenderFlex Overflow',
          subtitle: 'Opens a screen with overflowing Row → see hint in console',
          color: Colors.red.shade700,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _OverflowDemo()),
            );
          },
        ),
        _ActionTile(
          icon: Icons.do_not_disturb_alt_rounded,
          title: 'Null Check Error',
          subtitle: 'Caught + logged with stack trace',
          color: Colors.red.shade400,
          onTap: () {
            try {
              String? value;
              // ignore: unnecessary_non_null_assertion
              final forced = value!;
              LogPilot.debug(forced);
            } catch (e, st) {
              LogPilot.error('Null check failed', error: e, stackTrace: st);
            }
          },
        ),
        _ActionTile(
          icon: Icons.list_alt_rounded,
          title: 'RangeError',
          subtitle: 'list[10] on a 3-element list → hint in console',
          color: Colors.red.shade300,
          onTap: () {
            try {
              final list = [1, 2, 3];
              // ignore: unnecessary_statements
              list[10];
            } catch (e, st) {
              LogPilot.error('Index out of bounds', error: e, stackTrace: st);
            }
          },
        ),
      ],
    );
  }

  // ── 4. Network ────────────────────────────────────────────────────────

  Widget _buildNetworkSection(BuildContext context) {
    return _Section(
      icon: Icons.cloud_outlined,
      title: '4. Network Logging',
      subtitle: 'HTTP request/response with duration, status colors, masking',
      children: [
        _ActionTile(
          icon: Icons.download_rounded,
          title: 'HTTP GET (200)',
          subtitle: 'GET jsonplaceholder.typicode.com → green 200, JSON body',
          color: Colors.indigo,
          onTap: () async {
            final client = LogPilotHttpClient();
            try {
              await client.get(
                Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
              );
            } catch (e, st) {
              LogPilot.error('HTTP request failed', error: e, stackTrace: st);
            } finally {
              client.close();
            }
          },
        ),
        _ActionTile(
          icon: Icons.upload_rounded,
          title: 'HTTP POST (field masking)',
          subtitle: '=exact, ~regex, and substring mask patterns',
          color: Colors.indigo.shade700,
          onTap: () async {
            final client = LogPilotHttpClient();
            try {
              await client.post(
                Uri.parse('https://jsonplaceholder.typicode.com/posts'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer sk-secret-token-123',
                },
                body: '{"username":"alice","password":"super_secret_123",'
                    '"access_token":"tok_abc123","token_type":"Bearer"}',
              );
            } catch (e, st) {
              LogPilot.error('HTTP POST failed', error: e, stackTrace: st);
            } finally {
              client.close();
            }
          },
        ),
        _ActionTile(
          icon: Icons.error_outline_rounded,
          title: 'HTTP 404 (status-aware level)',
          subtitle: '4xx → warning level, 5xx → error level',
          color: Colors.red.shade800,
          onTap: () async {
            final client = LogPilotHttpClient();
            try {
              await client.get(Uri.parse('https://httpstat.us/404'));
            } catch (e, st) {
              LogPilot.error('HTTP error', error: e, stackTrace: st);
            } finally {
              client.close();
            }
          },
        ),
      ],
    );
  }

  // ── 5. Tags & Filtering ───────────────────────────────────────────────

  Widget _buildTagSection(BuildContext context) {
    return _Section(
      icon: Icons.label_rounded,
      title: '5. Tags & Filtering',
      subtitle: 'Tag logs by feature; filter with onlyTags in config',
      children: [
        _ActionTile(
          icon: Icons.shopping_cart_rounded,
          title: 'Tag: checkout',
          subtitle: 'LogPilot.info("Processing...", tag: "checkout")',
          color: Colors.deepPurple,
          onTap: () => LogPilot.info(
            'Processing payment',
            tag: 'checkout',
            metadata: {'orderId': 'ORD-789', 'amount': 49.99},
          ),
        ),
        _ActionTile(
          icon: Icons.lock_rounded,
          title: 'Tag: auth',
          subtitle: 'LogPilot.warning("Token expires...", tag: "auth")',
          color: Colors.amber.shade800,
          onTap: () => LogPilot.warning(
            'Token expires in 60s',
            tag: 'auth',
            metadata: {'expiresAt': '2026-03-23T15:00:00Z'},
          ),
        ),
        _ActionTile(
          icon: Icons.filter_alt_rounded,
          title: 'Untagged',
          subtitle: 'Visible unless onlyTags is set in config',
          color: Colors.grey,
          onTap: () => LogPilot.debug('This log has no tag'),
        ),
      ],
    );
  }

  // ── 6. Instance Loggers & Lazy Eval ───────────────────────────────────

  Widget _buildInstanceLoggerSection(BuildContext context) {
    return _Section(
      icon: Icons.class_rounded,
      title: '6. Instance Loggers & Lazy Eval',
      subtitle: 'LogPilot.create("Tag") auto-tags; () => "..." defers work',
      children: [
        _ActionTile(
          icon: Icons.person_rounded,
          title: 'AuthService Logger',
          subtitle: 'LogPilot.create("AuthService") → 2 auto-tagged logs',
          color: Colors.deepOrange,
          onTap: () {
            final log = LogPilot.create('AuthService');
            log.info('Attempting sign in', metadata: {'method': 'google'});
            log.warning('Token refresh needed');
          },
        ),
        _ActionTile(
          icon: Icons.speed_rounded,
          title: 'Lazy Evaluation',
          subtitle: '() => "..." — function only called if level passes',
          color: Colors.cyan,
          onTap: () {
            LogPilot.debug(() => 'Computed at ${DateTime.now()}: cache has '
                '${List.generate(100, (i) => i).length} entries');
          },
        ),
        _ActionTile(
          icon: Icons.shopping_bag_rounded,
          title: 'Cart Logger (instance)',
          subtitle: 'LogPilotLogger("Cart") — same as LogPilot.create',
          color: Colors.pink,
          onTap: () {
            const log = LogPilotLogger('Cart');
            log.info('Item added', metadata: {'sku': 'WIDGET-42', 'qty': 2});
            log.debug(() => 'Cart total: \$${(42 * 2.5).toStringAsFixed(2)}');
          },
        ),
      ],
    );
  }

  // ── 7. Sinks ──────────────────────────────────────────────────────────

  Widget _buildSinkSection(BuildContext context) {
    return _Section(
      icon: Icons.output_rounded,
      title: '7. Sinks (Log Routing)',
      subtitle: 'Every log above also hits the CallbackSink — see counter',
      children: [
        _ActionTile(
          icon: Icons.cleaning_services_rounded,
          title: 'Clear Sink Counter',
          subtitle: 'Reset to 0 and start counting again',
          color: Colors.brown,
          onTap: () => sinkRecords.value = [],
        ),
        _ActionTile(
          icon: Icons.visibility_rounded,
          title: 'View Last Sink Record',
          subtitle: 'Shows the last LogPilotRecord received by the sink',
          color: Colors.blueGrey,
          onTap: () {
            final list = sinkRecords.value;
            if (list.isEmpty) {
              LogPilot.info('No sink records yet — tap other buttons first');
              return;
            }
            final last = list.last;
            LogPilot.info(
              'Last sink record',
              metadata: {
                'level': last.level.label,
                'message': last.message ?? '(null)',
                'tag': last.tag ?? '(none)',
                'timestamp': last.timestamp.toIso8601String(),
                'hasError': last.error != null,
                'hasMetadata': last.metadata != null,
              },
            );
          },
        ),
      ],
    );
  }

  // ── 8. Deduplication ──────────────────────────────────────────────────

  Widget _buildDeduplicationSection(BuildContext context) {
    return _Section(
      icon: Icons.compress_rounded,
      title: '8. Rate Limiting / Dedup',
      subtitle: 'Identical logs within a time window are collapsed',
      children: [
        _ActionTile(
          icon: Icons.repeat_rounded,
          title: 'Fire 20 Identical Errors',
          subtitle: 'Console shows first + summary; sinks get all 20',
          color: Colors.red,
          onTap: () {
            for (var i = 0; i < 20; i++) {
              LogPilot.error('RenderFlex overflowed by 42.0 pixels');
            }
            LogPilot.info(
              'Dedup demo complete — check console for collapsed output',
              metadata: {'sinkRecordCount': sinkRecords.value.length},
            );
          },
        ),
        _ActionTile(
          icon: Icons.repeat_one_rounded,
          title: 'Fire 10 Identical Warnings',
          subtitle: 'Same message, warning level — see dedup in action',
          color: Colors.orange,
          onTap: () {
            for (var i = 0; i < 10; i++) {
              LogPilot.warning('Retry attempt failed');
            }
          },
        ),
        _ActionTile(
          icon: Icons.shuffle_rounded,
          title: 'Mixed Messages (no dedup)',
          subtitle: 'Different messages — all printed individually',
          color: Colors.green,
          onTap: () {
            LogPilot.info('Message A');
            LogPilot.info('Message B');
            LogPilot.info('Message C');
            LogPilot.info('Message D');
          },
        ),
      ],
    );
  }

  // ── 10. Log History / Export ──────────────────────────────────────────────

  Widget _buildHistorySection(BuildContext context) {
    return _Section(
      icon: Icons.history_rounded,
      title: '10. Log History / Export',
      subtitle: 'In-memory ring buffer of recent logs with export',
      children: [
        _ActionTile(
          icon: Icons.format_list_numbered_rounded,
          title: 'History Count',
          subtitle: 'How many records are in the in-memory buffer',
          color: Colors.deepPurple,
          onTap: () {
            final records = LogPilot.history;
            LogPilot.info(
              'History status',
              metadata: {
                'recordCount': records.length,
                'maxSize': LogPilot.config.maxHistorySize,
                'oldestLevel': records.isNotEmpty
                    ? records.first.level.label
                    : '(empty)',
                'newestLevel': records.isNotEmpty
                    ? records.last.level.label
                    : '(empty)',
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.filter_alt_rounded,
          title: 'Errors Only',
          subtitle: 'LogPilot.historyWhere(level: LogLevel.error)',
          color: Colors.red,
          onTap: () {
            final errors = LogPilot.historyWhere(level: LogLevel.error);
            LogPilot.info(
              'Error history',
              metadata: {
                'errorCount': errors.length,
                'messages':
                    errors.map((r) => r.message ?? '(null)').take(5).toList(),
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.wifi_rounded,
          title: 'HTTP Records in History',
          subtitle: 'historyWhere(tag: "http", metadataKey: "statusCode")',
          color: Colors.indigo,
          onTap: () {
            final httpRecords = LogPilot.historyWhere(
              tag: 'http',
              metadataKey: 'statusCode',
            );
            LogPilot.info(
              'HTTP history records',
              metadata: {
                'count': httpRecords.length,
                'records': httpRecords.take(5).map((r) {
                  final m = r.metadata ?? {};
                  return '${m["method"]} ${m["statusCode"]} ${m["durationMs"]}ms';
                }).toList(),
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.search_rounded,
          title: 'Enhanced historyWhere',
          subtitle: 'messageContains + time window + hasError',
          color: Colors.deepPurple,
          onTap: () {
            final fiveMinAgo =
                DateTime.now().subtract(const Duration(minutes: 5));
            final recentErrors = LogPilot.historyWhere(
              hasError: true,
              after: fiveMinAgo,
            );
            final withTimeout = LogPilot.historyWhere(
              messageContains: 'timeout',
            );
            LogPilot.info(
              'Enhanced history query',
              metadata: {
                'recentErrors (5min)': recentErrors.length,
                'mentioning "timeout"': withTimeout.length,
                'total history': LogPilot.history.length,
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.text_snippet_rounded,
          title: 'Export as Text',
          subtitle: 'LogPilot.export(format: ExportFormat.text)',
          color: Colors.teal,
          onTap: () {
            final text = LogPilot.export();
            final preview = text.length > 500
                ? '${text.substring(0, 500)}\n... (${text.length} chars)'
                : text;
            LogPilot.info(
              'Exported history (text)',
              metadata: {
                'totalChars': text.length,
                'preview': preview,
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.data_object_rounded,
          title: 'Export as JSON',
          subtitle: 'LogPilot.export(format: ExportFormat.json)',
          color: Colors.indigo,
          onTap: () {
            final json = LogPilot.export(format: ExportFormat.json);
            final lines = json.split('\n');
            LogPilot.info(
              'Exported history (JSON)',
              metadata: {
                'totalRecords': lines.length,
                'totalChars': json.length,
                'lastLine': lines.isNotEmpty ? lines.last : '(empty)',
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.delete_sweep_rounded,
          title: 'Clear History',
          subtitle: 'LogPilot.clearHistory() — resets the buffer',
          color: Colors.brown,
          onTap: () {
            final before = LogPilot.history.length;
            LogPilot.clearHistory();
            LogPilot.info(
              'History cleared',
              metadata: {'recordsBefore': before, 'recordsAfter': 0},
            );
          },
        ),
      ],
    );
  }

  // ── 11. Correlation / Trace IDs ────────────────────────────────────────

  Widget _buildCorrelationSection(BuildContext context) {
    return _Section(
      icon: Icons.fingerprint_rounded,
      title: '11. Session & Trace IDs',
      subtitle: 'Auto-generated session UUID + per-request trace IDs',
      children: [
        _ActionTile(
          icon: Icons.badge_rounded,
          title: 'View Session ID',
          subtitle: 'LogPilot.sessionId — unique per app launch',
          color: Colors.indigo,
          onTap: () {
            LogPilot.info(
              'Current session',
              metadata: {'sessionId': LogPilot.sessionId},
            );
          },
        ),
        _ActionTile(
          icon: Icons.link_rounded,
          title: 'Scoped Trace ID',
          subtitle: 'LogPilot.withTraceIdSync — auto-clears on exit',
          color: Colors.teal,
          onTap: () {
            LogPilot.withTraceIdSync(
              'req-${DateTime.now().millisecondsSinceEpoch}',
              () {
                LogPilot.info('Starting checkout flow');
                LogPilot.debug('Validating cart items');
                LogPilot.info('Checkout complete');
              },
            );
            LogPilot.info('Back to normal (no trace ID)');
          },
        ),
        _ActionTile(
          icon: Icons.search_rounded,
          title: 'Check Record IDs',
          subtitle: 'Inspect sessionId & traceId on the last history record',
          color: Colors.deepPurple,
          onTap: () {
            final records = LogPilot.history;
            if (records.isEmpty) {
              LogPilot.info('No history records yet');
              return;
            }
            final last = records.last;
            LogPilot.info(
              'Last record IDs',
              metadata: {
                'sessionId': last.sessionId ?? '(null)',
                'traceId': last.traceId ?? '(null)',
                'message': last.message ?? '(null)',
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.cloud_upload_rounded,
          title: 'HTTP with Session Header',
          subtitle: 'X-LogPilot-Session auto-injected in network requests',
          color: Colors.blue,
          onTap: () async {
            await LogPilot.withTraceId('http-trace-demo', () async {
              final client = LogPilotHttpClient();
              try {
                await client.get(
                  Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
                );
              } catch (e, st) {
                LogPilot.error('HTTP failed', error: e, stackTrace: st);
              } finally {
                client.close();
              }
            });
          },
        ),
      ],
    );
  }

  // ── 12. Navigation ──────────────────────────────────────────────────────

  Widget _buildNavigationSection(BuildContext context) {
    return _Section(
      icon: Icons.navigation_rounded,
      title: '12. Navigation Logging',
      subtitle: 'Auto-logs push/pop/replace via LogPilotNavigatorObserver',
      children: [
        _ActionTile(
          icon: Icons.open_in_new_rounded,
          title: 'Push Named Route',
          subtitle: 'Navigator.push → see PUSH log in console',
          color: Colors.indigo,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                settings: const RouteSettings(
                  name: '/details',
                  arguments: {'productId': 42},
                ),
                builder: (_) => const _NavDemoScreen(),
              ),
            );
          },
        ),
        _ActionTile(
          icon: Icons.swap_horiz_rounded,
          title: 'Push Replacement',
          subtitle: 'pushReplacement → see REPLACE log',
          color: Colors.teal,
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                settings: const RouteSettings(name: '/replacement'),
                builder: (_) => const _NavDemoScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── 13. BLoC Observer ──────────────────────────────────────────────────

  Widget _buildBlocSection(BuildContext context) {
    return _Section(
      icon: Icons.account_tree_rounded,
      title: '13. BLoC Observer',
      subtitle: 'Create/close, events, state changes, errors — all logged',
      children: [
        _ActionTile(
          icon: Icons.add_circle_outline_rounded,
          title: 'Counter Cubit',
          subtitle: 'Create → increment → increment → close',
          color: Colors.deepPurple,
          onTap: () {
            final cubit = _DemoCounterCubit();
            cubit.increment();
            cubit.increment();
            cubit.close();
          },
        ),
        _ActionTile(
          icon: Icons.error_outline_rounded,
          title: 'Cubit Error',
          subtitle: 'Create → throw error → close',
          color: Colors.red,
          onTap: () {
            final cubit = _DemoCounterCubit();
            cubit.triggerError();
            cubit.close();
          },
        ),
      ],
    );
  }

  // ── 14. Performance Timing ──────────────────────────────────────────────

  Widget _buildTimingSection(BuildContext context) {
    return _Section(
      icon: Icons.timer_rounded,
      title: '14. Performance Timing',
      subtitle: 'LogPilot.time / LogPilot.timeEnd — measure operation duration',
      children: [
        _ActionTile(
          icon: Icons.speed_rounded,
          title: 'Time a Delay (200ms)',
          subtitle: 'LogPilot.time("demo") → delay → LogPilot.timeEnd("demo")',
          color: Colors.orange,
          onTap: () async {
            LogPilot.time('demo');
            await Future<void>.delayed(const Duration(milliseconds: 200));
            LogPilot.timeEnd('demo');
          },
        ),
        _ActionTile(
          icon: Icons.compare_arrows_rounded,
          title: 'Concurrent Timers',
          subtitle: 'Two timers running in parallel with different durations',
          color: Colors.indigo,
          onTap: () async {
            LogPilot.time('fast');
            LogPilot.time('slow');
            await Future<void>.delayed(const Duration(milliseconds: 50));
            LogPilot.timeEnd('fast');
            await Future<void>.delayed(const Duration(milliseconds: 150));
            LogPilot.timeEnd('slow');
          },
        ),
        _ActionTile(
          icon: Icons.shield_rounded,
          title: 'Scoped withTimer',
          subtitle: 'LogPilot.withTimer — auto-cancels on exception',
          color: Colors.teal,
          onTap: () async {
            await LogPilot.withTimer(
              'scopedWork',
              work: () async {
                await Future<void>.delayed(const Duration(milliseconds: 100));
                return 'done';
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.cancel_outlined,
          title: 'Cancel Timer',
          subtitle: 'Start a timer then cancel it — no log produced',
          color: Colors.grey,
          onTap: () {
            LogPilot.time('cancelled');
            LogPilot.timeCancel('cancelled');
            LogPilot.info('Timer cancelled — no timing log was produced');
          },
        ),
        _ActionTile(
          icon: Icons.class_rounded,
          title: 'Scoped Logger Timer',
          subtitle: 'LogPilotLogger("DB").time("query") → prefixed label',
          color: Colors.deepPurple,
          onTap: () async {
            final log = LogPilot.create('DB');
            log.time('query');
            await Future<void>.delayed(const Duration(milliseconds: 80));
            log.timeEnd('query');
          },
        ),
      ],
    );
  }

  // ── 15. In-App Log Viewer ──────────────────────────────────────────────

  Widget _buildOverlaySection(BuildContext context) {
    return _Section(
      icon: Icons.visibility_rounded,
      title: '15. In-App Log Viewer',
      subtitle: 'LogPilotOverlay — tap the purple button at bottom-right',
      children: [
        _ActionTile(
          icon: Icons.terminal_rounded,
          title: 'Generate Sample Logs',
          subtitle: 'Emit 5 logs at different levels, then open the overlay',
          color: Colors.deepPurple,
          onTap: () {
            LogPilot.verbose('Background sync started', tag: 'sync');
            LogPilot.debug('Cache hit for key user_42');
            LogPilot.info('Order placed', metadata: {'orderId': 'ORD-123'});
            LogPilot.warning('Token expires in 60s', tag: 'auth');
            LogPilot.error('Checkout validation failed', tag: 'checkout');
          },
        ),
        _ActionTile(
          icon: Icons.view_list_rounded,
          title: 'Record Detail Demo',
          subtitle: 'Log records with metadata and errors, then tap them',
          color: Colors.indigo,
          onTap: () {
            LogPilot.info('User signed in', tag: 'Auth', metadata: {
              'userId': 'u-42',
              'method': 'Google',
            });
            try {
              throw StateError('payment method declined');
            } catch (e, st) {
              LogPilot.error('Checkout failed', error: e, stackTrace: st,
                  tag: 'Cart');
            }
            LogPilot.info('Tap a record in the overlay to see full details');
          },
        ),
        _ActionTile(
          icon: Icons.label_rounded,
          title: 'Tag Filter Demo',
          subtitle: 'Generate tagged logs, then filter by tag in the overlay',
          color: Colors.teal,
          onTap: () {
            LogPilot.info('Route changed', tag: 'Nav');
            LogPilot.debug('Cache miss', tag: 'DB');
            LogPilot.warning('Slow query', tag: 'DB');
            LogPilot.info('Token refreshed', tag: 'Auth');
            LogPilot.error('Rate limited', tag: 'API');
            LogPilot.info('Open the overlay and use the tag chips to filter');
          },
        ),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: 'About the Overlay',
          subtitle: 'Auto-hides in production; shows level/search filters',
          color: Colors.blue,
          onTap: () {
            LogPilot.info(
              'LogPilotOverlay is active via MaterialApp.builder',
              metadata: {
                'entryButton': 'bottom-right corner',
                'features': [
                  'level filtering',
                  'text search',
                  'copy to clipboard (text/JSON)',
                  'auto-scroll toggle',
                  'clear history',
                ],
              },
            );
          },
        ),
      ],
    );
  }

  // ── 16. Output Formats ──────────────────────────────────────────────────

  Widget _buildOutputFormatSection(BuildContext context) {
    return _Section(
      icon: Icons.format_align_left_rounded,
      title: '16. Output Formats (Agent-Friendly)',
      subtitle: 'Switch console output: pretty / plain / json',
      children: [
        _ActionTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Pretty Mode (default)',
          subtitle: 'Box-bordered, colorized blocks for humans',
          color: Colors.deepPurple,
          onTap: () {
            LogPilot.configure(config: LogPilot.config.copyWith(
              outputFormat: OutputFormat.pretty,
            ));
            LogPilot.info('Now using OutputFormat.pretty', metadata: {
              'audience': 'humans',
              'features': 'box borders, ANSI colors, clickable caller',
            });
          },
        ),
        _ActionTile(
          icon: Icons.short_text_rounded,
          title: 'Plain Mode',
          subtitle: 'Flat single-line output for AI agents',
          color: Colors.teal,
          onTap: () {
            LogPilot.configure(config: LogPilot.config.copyWith(
              outputFormat: OutputFormat.plain,
            ));
            LogPilot.info('Now using OutputFormat.plain', tag: 'agent', metadata: {
              'audience': 'AI agents (Cursor, Claude Code, Copilot)',
              'format': '[LEVEL] [tag] message | metadata',
            });
            LogPilot.warning('AI agents can parse this without regex', tag: 'agent');
          },
        ),
        _ActionTile(
          icon: Icons.data_object_rounded,
          title: 'JSON Mode (NDJSON)',
          subtitle: 'One JSON line per log — pipe to jq or log systems',
          color: Colors.orange,
          onTap: () {
            LogPilot.configure(config: LogPilot.config.copyWith(
              outputFormat: OutputFormat.json,
            ));
            LogPilot.info('Now using OutputFormat.json', tag: 'pipeline', metadata: {
              'format': 'NDJSON',
              'tools': ['jq', 'Datadog', 'CloudWatch'],
            });
            LogPilot.debug('Each log is a complete JSON object', tag: 'pipeline');
          },
        ),
        _ActionTile(
          icon: Icons.restore_rounded,
          title: 'Restore Pretty Mode',
          subtitle: 'Switch back to the default box-bordered output',
          color: Colors.grey,
          onTap: () {
            LogPilot.configure(config: LogPilot.config.copyWith(
              outputFormat: OutputFormat.pretty,
            ));
            LogPilot.info('Restored OutputFormat.pretty');
          },
        ),
      ],
    );
  }

  // ── 17. Diagnostic Snapshot ────────────────────────────────────────────

  Widget _buildSnapshotSection(BuildContext context) {
    return _Section(
      icon: Icons.camera_alt_rounded,
      title: '17. Diagnostic Snapshot',
      subtitle: 'One-call activity summary for AI agents & bug reports',
      children: [
        _ActionTile(
          icon: Icons.summarize_rounded,
          title: 'Take Snapshot',
          subtitle: 'LogPilot.snapshot() → structured map of recent activity',
          color: Colors.indigo,
          onTap: () {
            final snap = LogPilot.snapshot();
            LogPilot.info('Snapshot taken', metadata: {
              'historyTotal': (snap['history'] as Map)['total'],
              'activeTimers': snap['activeTimers'],
              'errorCount': (snap['recentErrors'] as List).length,
            });
          },
        ),
        _ActionTile(
          icon: Icons.code_rounded,
          title: 'Snapshot as JSON',
          subtitle: 'LogPilot.snapshotAsJson() → formatted JSON string',
          color: Colors.deepOrange,
          onTap: () {
            LogPilot.json(LogPilot.snapshotAsJson(), level: LogLevel.info);
          },
        ),
        _ActionTile(
          icon: Icons.timer_rounded,
          title: 'Snapshot with Active Timer',
          subtitle: 'Start a timer, take snapshot, cancel timer',
          color: Colors.purple,
          onTap: () {
            LogPilot.time('demoTimer');
            final snap = LogPilot.snapshot();
            final timers = snap['activeTimers'] as List;
            LogPilot.info('Snapshot shows active timers', metadata: {
              'activeTimers': timers,
            });
            LogPilot.timeCancel('demoTimer');
          },
        ),
      ],
    );
  }

  // ── 18. Error Breadcrumbs ─────────────────────────────────────────────────

  Widget _buildBreadcrumbSection(BuildContext context) {
    return _Section(
      icon: Icons.timeline_rounded,
      title: '18. Error Breadcrumbs',
      subtitle: 'Auto-captured trail of events before each error',
      children: [
        _ActionTile(
          icon: Icons.add_circle_outline_rounded,
          title: 'Add Manual Breadcrumbs',
          subtitle: 'LogPilot.addBreadcrumb() for UI events, state changes',
          color: Colors.teal,
          onTap: () {
            LogPilot.addBreadcrumb('Tapped checkout button', category: 'ui');
            LogPilot.addBreadcrumb('Cart total: \$42.00',
                category: 'state', metadata: {'items': 3});
            LogPilot.info('Manual breadcrumbs added — trigger an error to see them');
          },
        ),
        _ActionTile(
          icon: Icons.error_outline_rounded,
          title: 'Trigger Error with Breadcrumbs',
          subtitle: 'Auto-breadcrumbs from prior logs appear on the error record',
          color: Colors.red,
          onTap: () {
            LogPilot.info('User navigated to checkout', tag: 'Nav');
            LogPilot.debug('Loading payment form', tag: 'UI');
            LogPilot.addBreadcrumb('Entered card details', category: 'ui');
            LogPilot.error(
              'Payment gateway timeout',
              error: Exception('Connection timed out after 30s'),
              stackTrace: StackTrace.current,
              tag: 'API',
            );
          },
        ),
        _ActionTile(
          icon: Icons.visibility_rounded,
          title: 'View Current Breadcrumbs',
          subtitle: 'LogPilot.breadcrumbs — inspect the trail',
          color: Colors.blueGrey,
          onTap: () {
            final crumbs = LogPilot.breadcrumbs;
            LogPilot.info('Current breadcrumb trail', metadata: {
              'count': crumbs.length,
              'trail': crumbs.map((c) => c.toString()).toList(),
            });
          },
        ),
        _ActionTile(
          icon: Icons.clear_all_rounded,
          title: 'Clear Breadcrumbs',
          subtitle: 'LogPilot.clearBreadcrumbs()',
          color: Colors.grey,
          onTap: () {
            LogPilot.clearBreadcrumbs();
            LogPilot.info('Breadcrumb trail cleared');
          },
        ),
      ],
    );
  }

  // ── 19. Agent-Friendly Error IDs ─────────────────────────────────────────

  Widget _buildErrorIdSection(BuildContext context) {
    return _Section(
      icon: Icons.fingerprint_rounded,
      title: '19. Agent-Friendly Error IDs',
      subtitle: 'Deterministic LogPilot-XXXXXX hash per error signature',
      children: [
        _ActionTile(
          icon: Icons.bug_report_rounded,
          title: 'Same Error, Same ID',
          subtitle: 'Trigger identical errors — observe same error ID',
          color: Colors.deepPurple,
          onTap: () {
            try {
              final list = <int>[];
              list[5]; // RangeError
            } catch (e, st) {
              LogPilot.error('First occurrence', error: e, stackTrace: st);
            }
            try {
              final list = <int>[];
              list[10]; // Same RangeError pattern, different index
            } catch (e, st) {
              LogPilot.error('Second occurrence — same error ID',
                  error: e, stackTrace: st);
            }
          },
        ),
        _ActionTile(
          icon: Icons.compare_arrows_rounded,
          title: 'Different Errors, Different IDs',
          subtitle: 'Different exception types produce different IDs',
          color: Colors.orange,
          onTap: () {
            LogPilot.error(
              'Type error',
              error: TypeError(),
              stackTrace: StackTrace.current,
            );
            LogPilot.error(
              'Format error',
              error: const FormatException('bad input'),
              stackTrace: StackTrace.current,
            );
          },
        ),
      ],
    );
  }

  // ── 20. Runtime Log-Level Override ──────────────────────────────────────

  Widget _buildLogLevelOverrideSection(BuildContext context) {
    return _Section(
      icon: Icons.tune_rounded,
      title: '20. Runtime Log-Level Override',
      subtitle: 'LogPilot.setLogLevel() — change verbosity without restart',
      children: [
        _ActionTile(
          icon: Icons.volume_up_rounded,
          title: 'Set Verbose',
          subtitle: 'LogPilot.setLogLevel(LogLevel.verbose) — see everything',
          color: Colors.grey,
          onTap: () {
            LogPilot.setLogLevel(LogLevel.verbose);
            LogPilot.verbose('Now showing verbose logs');
            LogPilot.debug('Debug is visible too');
            LogPilot.info('Current level: ${LogPilot.logLevel.label}');
          },
        ),
        _ActionTile(
          icon: Icons.warning_amber_rounded,
          title: 'Set Warning',
          subtitle: 'LogPilot.setLogLevel(LogLevel.warning) — errors + warnings only',
          color: Colors.orange,
          onTap: () {
            LogPilot.setLogLevel(LogLevel.warning);
            LogPilot.debug('This debug log will NOT appear');
            LogPilot.info('This info log will NOT appear');
            LogPilot.warning('Only warning+ logs are visible now');
          },
        ),
        _ActionTile(
          icon: Icons.restore_rounded,
          title: 'Restore Verbose',
          subtitle: 'Back to seeing all log levels',
          color: Colors.green,
          onTap: () {
            LogPilot.setLogLevel(LogLevel.verbose);
            LogPilot.info('Restored to LogLevel.verbose');
          },
        ),
      ],
    );
  }

  // ── 21. Instrumentation Helpers ──────────────────────────────────────────

  Widget _buildInstrumentSection(BuildContext context) {
    return _Section(
      icon: Icons.science_rounded,
      title: '21. Instrumentation Helpers',
      subtitle: 'One-line timing + error capture for any expression',
      children: [
        _ActionTile(
          icon: Icons.play_circle_outline_rounded,
          title: 'Instrument Sync',
          subtitle: 'LogPilot.instrument("label", () => expr)',
          color: Colors.blue,
          onTap: () {
            final result = LogPilot.instrument('fibonacci(30)', () {
              int fib(int n) => n <= 1 ? n : fib(n - 1) + fib(n - 2);
              return fib(30);
            });
            LogPilot.info('Fibonacci result: $result');
          },
        ),
        _ActionTile(
          icon: Icons.hourglass_bottom_rounded,
          title: 'Instrument Async',
          subtitle: 'LogPilot.instrumentAsync("label", () => future)',
          color: Colors.indigo,
          onTap: () async {
            final result = await LogPilot.instrumentAsync(
              'simulatedApiCall',
              () => Future.delayed(
                const Duration(milliseconds: 500),
                () => {'users': 42, 'page': 1},
              ),
            );
            LogPilot.info('API result', metadata: result);
          },
        ),
        _ActionTile(
          icon: Icons.error_rounded,
          title: 'Instrument with Error',
          subtitle: 'Auto-captures errors with timing',
          color: Colors.red,
          onTap: () {
            try {
              LogPilot.instrument('failingOp', () {
                throw StateError('Something went wrong');
              });
            } catch (_) {
              LogPilot.info('Error was captured and re-thrown by instrument()');
            }
          },
        ),
      ],
    );
  }

  // ── 22. LLM-Summarizable Export ────────────────────────────────────────

  Widget _buildLlmExportSection(BuildContext context) {
    return _Section(
      icon: Icons.smart_toy_rounded,
      title: '22. LLM-Summarizable Export',
      subtitle: 'Compress log history to fit AI context windows',
      children: [
        _ActionTile(
          icon: Icons.compress_rounded,
          title: 'Export for LLM (4k tokens)',
          subtitle: 'LogPilot.exportForLLM(tokenBudget: 4000)',
          color: Colors.deepPurple,
          onTap: () {
            final summary = LogPilot.exportForLLM(tokenBudget: 4000);
            LogPilot.info('LLM export generated', metadata: {
              'chars': summary.length,
              'approxTokens': summary.length ~/ 4,
            });
            LogPilot.debug(summary, tag: 'llm-export');
          },
        ),
        _ActionTile(
          icon: Icons.compress_rounded,
          title: 'Export for LLM (1k tokens)',
          subtitle: 'Smaller budget — more aggressive compression',
          color: Colors.teal,
          onTap: () {
            final summary = LogPilot.exportForLLM(tokenBudget: 1000);
            LogPilot.info('Compact LLM export', metadata: {
              'chars': summary.length,
              'approxTokens': summary.length ~/ 4,
            });
            LogPilot.debug(summary, tag: 'llm-export');
          },
        ),
      ],
    );
  }

  // ── 23. DevTools Extension ─────────────────────────────────────────────

  Widget _buildDevToolsSection(BuildContext context) {
    return _Section(
      icon: Icons.developer_mode_rounded,
      title: '23. DevTools Extension',
      subtitle: 'Real-time log viewer tab in Dart DevTools',
      children: [
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: 'About the DevTools Extension',
          subtitle: 'Open DevTools to see the "LogPilot" tab — zero config!',
          color: Colors.blue,
          onTap: () {
            LogPilot.info(
              'The LogPilot DevTools extension is bundled with this package. '
              'Open Dart DevTools and look for the "LogPilot" tab to see a '
              'real-time log viewer with filters, search, and drill-down.',
              tag: 'DevTools',
              metadata: {
                'features': [
                  'Real-time log table',
                  'Level / tag / search filters',
                  'Log detail drill-down',
                  'Breadcrumb timeline',
                  'Export (text/JSON)',
                  'Set log level remotely',
                ],
              },
            );
          },
        ),
      ],
    );
  }

  // ── 24. MCP Log Tail / Watch Mode ───────────────────────────────────────

  Widget _buildMcpTailSection(BuildContext context) {
    return _Section(
      icon: Icons.stream_rounded,
      title: '24. MCP Log Tail / Watch Mode',
      subtitle:
          'watch_logs streams new entries to AI agents via MCP push notifications',
      children: [
        _ActionTile(
          icon: Icons.play_circle_outline_rounded,
          title: 'Simulate Watch Activity',
          subtitle: 'Emit 5 tagged logs an agent watcher would receive',
          color: Colors.teal,
          onTap: () {
            for (var i = 1; i <= 5; i++) {
              Future.delayed(Duration(milliseconds: i * 400), () {
                LogPilot.info(
                  'Live event $i',
                  tag: 'WatchDemo',
                  metadata: {'seq': i, 'source': 'example_app'},
                );
              });
            }
            LogPilot.info(
              'Emitting 5 events over 2 seconds — an active watch_logs '
              'watcher on log_pilot_mcp would push these as '
              'notifications/message to the agent.',
              tag: 'MCP',
            );
          },
        ),
        _ActionTile(
          icon: Icons.info_outline_rounded,
          title: 'About watch_logs',
          subtitle:
              'MCP tool — agent calls watch_logs(tag: "Auth") to stream entries',
          color: Colors.blue,
          onTap: () {
            LogPilot.info(
              'watch_logs is an MCP tool on log_pilot_mcp. It starts a periodic '
              'poller that diffs log history, filters by tag/level, and '
              'pushes new entries to the agent via notifications/message. '
              'The LogPilot://tail resource is also updated for subscribers. '
              'Call stop_watch to cancel.',
              tag: 'MCP',
              metadata: {
                'tools': ['watch_logs', 'stop_watch'],
                'resource': 'LogPilot://tail',
                'default_interval_ms': 2000,
              },
            );
          },
        ),
      ],
    );
  }

  // ── 9. File Sink ─────────────────────────────────────────────────────────

  Widget _buildFileSinkSection(BuildContext context) {
    if (kIsWeb) {
      return _Section(
        icon: Icons.save_rounded,
        title: '9. File Sink (Persistent Logs)',
        subtitle: 'File logging requires dart:io — not available on web',
        children: [
          _ActionTile(
            icon: Icons.web_rounded,
            title: 'Web Platform',
            subtitle: 'FileSink is available on mobile/desktop only',
            color: Colors.grey,
            onTap: () => LogPilot.info(
              'FileSink requires dart:io — use log_pilot_io.dart on mobile/desktop',
            ),
          ),
        ],
      );
    }

    return _Section(
      icon: Icons.save_rounded,
      title: '9. File Sink (Persistent Logs)',
      subtitle: 'All logs are also written to a local file with rotation',
      children: [
        _ActionTile(
          icon: Icons.folder_open_rounded,
          title: 'View Log File Path',
          subtitle: 'Shows the directory and files used by FileSink',
          color: Colors.teal,
          onTap: () {
            final sink = platform.activeFileSink;
            if (sink == null) {
              LogPilot.warning('FileSink not initialized');
              return;
            }
            LogPilot.info(
              'FileSink status',
              metadata: {
                'fileCount': sink.logFiles.length,
                'format': sink.format.name,
                'maxFileSize': '${sink.maxFileSize ~/ 1024}KB',
                'maxFileCount': sink.maxFileCount,
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.read_more_rounded,
          title: 'Read All Logs from File',
          subtitle: 'Reads and logs the first 500 chars from the log files',
          color: Colors.indigo,
          onTap: () async {
            final sink = platform.activeFileSink;
            if (sink == null) {
              LogPilot.warning('FileSink not initialized');
              return;
            }
            final content = await sink.readAll();
            final preview = content.length > 500
                ? '${content.substring(0, 500)}\n... (${content.length} chars total)'
                : content;
            LogPilot.info(
              'Log file contents',
              metadata: {
                'totalLength': content.length,
                'preview': preview,
              },
            );
          },
        ),
        _ActionTile(
          icon: Icons.sync_rounded,
          title: 'Force Flush to Disk',
          subtitle: 'Flushes buffered records to the log file immediately',
          color: Colors.deepOrange,
          onTap: () async {
            final sink = platform.activeFileSink;
            if (sink == null) {
              LogPilot.warning('FileSink not initialized');
              return;
            }
            await sink.flush();
            LogPilot.info('FileSink flushed to disk');
          },
        ),
      ],
    );
  }
}

// ─── Sink Counter Widget ────────────────────────────────────────────────────

class _SinkCounter extends StatelessWidget {
  const _SinkCounter();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<LogPilotRecord>>(
      valueListenable: sinkRecords,
      builder: (context, records, _) {
        return Card(
          elevation: 0,
          color: cs.tertiaryContainer.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.sensors_rounded, color: cs.tertiary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Sink received ',
                          style: TextStyle(color: cs.onTertiaryContainer),
                        ),
                        TextSpan(
                          text: '${records.length}',
                          style: TextStyle(
                            color: cs.tertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        TextSpan(
                          text: ' records',
                          style: TextStyle(color: cs.onTertiaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
                if (records.isNotEmpty)
                  Chip(
                    label: Text(
                      records.last.level.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                    side: BorderSide(
                      color: cs.tertiary.withValues(alpha: 0.3),
                    ),
                    backgroundColor: cs.tertiaryContainer,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Reusable Widgets ───────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.terminal_rounded, color: cs.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Demo Screens ───────────────────────────────────────────────────────────

class _DemoCounterCubit extends Cubit<int> {
  _DemoCounterCubit() : super(0);

  void increment() => emit(state + 1);
  void triggerError() =>
      addError(Exception('Something went wrong in cubit'), StackTrace.current);
}

class _NavDemoScreen extends StatelessWidget {
  const _NavDemoScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Demo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.navigation_rounded, size: 48, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'This screen was navigated to.\n'
                'Check your console for the PUSH log.\n'
                'Tap Back to see the POP log.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back (POP)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowDemo extends StatelessWidget {
  const _OverflowDemo();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Overflow Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The Row below intentionally overflows. '
                        'Check your debug console for LogPilot\'s prettified '
                        'error with a contextual tip.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(
              20,
              (i) => Container(
                width: 200,
                height: 80,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.primaries[i % Colors.primaries.length],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Item $i',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

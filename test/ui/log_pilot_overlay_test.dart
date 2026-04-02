import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot/log_pilot.dart';

void main() {
  setUp(() {
    LogPilot.configure(
      config: const LogPilotConfig(
        enabled: true,
        maxHistorySize: 500,
      ),
    );
    LogPilot.clearHistory();
  });

  tearDown(LogPilot.reset);

  Widget buildApp({bool? overlayEnabled, Alignment? alignment}) {
    return MaterialApp(
      home: LogPilotOverlay(
        enabled: overlayEnabled,
        entryButtonAlignment: alignment ?? Alignment.bottomRight,
        child: const Scaffold(body: Center(child: Text('Hello'))),
      ),
    );
  }

  group('LogPilotOverlay', () {
    testWidgets('shows entry button when enabled', (tester) async {
      await tester.pumpWidget(buildApp());
      expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
    });

    testWidgets('hides overlay when enabled=false', (tester) async {
      await tester.pumpWidget(buildApp(overlayEnabled: false));
      expect(find.byIcon(Icons.terminal_rounded), findsNothing);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('opens sheet on button tap', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();
      expect(find.text('LogPilot Viewer'), findsOneWidget);
      expect(find.text('No logs yet'), findsOneWidget);
    });

    testWidgets('shows log records from history', (tester) async {
      LogPilot.info('Test message alpha');
      LogPilot.warning('Test message beta');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.text('LogPilot Viewer'), findsOneWidget);
      expect(find.textContaining('Test message alpha'), findsOneWidget);
      expect(find.textContaining('Test message beta'), findsOneWidget);
      expect(find.textContaining('2 records'), findsOneWidget);
    });

    testWidgets('filter chips are visible', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('VERBOSE'), findsOneWidget);
      expect(find.text('DEBUG'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('FATAL'), findsOneWidget);
    });

    testWidgets('level filter narrows results', (tester) async {
      LogPilot.info('Info message');
      LogPilot.error('Error message');
      LogPilot.debug('Debug message');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 records'), findsOneWidget);

      await tester.tap(find.text('ERROR'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Error message'), findsOneWidget);
      expect(find.textContaining('Info message'), findsNothing);
      expect(find.textContaining('1 records'), findsOneWidget);
    });

    testWidgets('search filters by message text', (tester) async {
      LogPilot.info('Payment processed');
      LogPilot.info('User signed in');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Payment');
      await tester.pumpAndSettle();

      expect(find.textContaining('Payment processed'), findsOneWidget);
      expect(find.textContaining('User signed in'), findsNothing);
      expect(find.textContaining('1 records'), findsOneWidget);
    });

    testWidgets('close button dismisses the sheet', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.text('LogPilot Viewer'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('LogPilot Viewer'), findsNothing);
      expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
    });

    testWidgets('clear button empties the log list', (tester) async {
      LogPilot.info('Will be cleared');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('Will be cleared'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No logs yet'), findsOneWidget);
    });

    testWidgets('copy to clipboard exports text', (tester) async {
      LogPilot.info('Clipboard test');

      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map;
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );

      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      expect(clipboardContent, isNotNull);
      expect(clipboardContent, contains('Clipboard test'));
    });

    testWidgets('auto-scroll toggle works', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(
          find.byIcon(Icons.vertical_align_bottom_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.vertical_align_bottom_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('shows tags as colored chips', (tester) async {
      LogPilot.info('Tagged message', tag: 'auth');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      // 'auth' appears in both the tag filter chip row and the log tile
      expect(find.text('auth'), findsWidgets);
    });

    testWidgets('live updates when new logs arrive', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No logs yet'), findsOneWidget);

      LogPilot.info('Live log');
      await tester.pumpAndSettle();

      expect(find.textContaining('Live log'), findsOneWidget);
      expect(find.textContaining('1 records'), findsOneWidget);
    });

    testWidgets('sheet has a drag handle', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('sheet starts at half height and is draggable',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      final sheet = find.byType(DraggableScrollableSheet);
      expect(sheet, findsOneWidget);

      final sheetWidget =
          tester.widget<DraggableScrollableSheet>(sheet);
      expect(sheetWidget.initialChildSize, 0.5);
      expect(sheetWidget.minChildSize, 0.25);
      expect(sheetWidget.maxChildSize, 1.0);
    });

    // ── Feature #12: Record Detail View ──────────────────────────────

    testWidgets('tapping a log tile opens the record detail sheet',
        (tester) async {
      LogPilot.info('Detail test message', tag: 'Auth', metadata: {'key': 'val'});

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Detail test message'));
      await tester.pumpAndSettle();

      expect(find.text('Record Detail'), findsOneWidget);
      expect(find.text('INFO'), findsWidgets);
      expect(find.text('Auth'), findsWidgets);
      expect(find.textContaining('key'), findsWidgets);
    });

    testWidgets('detail sheet shows error and stack trace', (tester) async {
      try {
        throw StateError('test error');
      } catch (e, st) {
        LogPilot.error('Error occurred', error: e, stackTrace: st, tag: 'Test');
      }

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Error occurred'));
      await tester.pumpAndSettle();

      expect(find.text('Record Detail'), findsOneWidget);

      // Scroll down to reveal the Error and Stack Trace sections which
      // are below the viewport in the lazy ListView.
      await tester.dragUntilVisible(
        find.text('Stack Trace'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsWidgets);
      expect(find.text('Stack Trace'), findsOneWidget);
    });

    testWidgets('detail sheet back button dismisses it', (tester) async {
      LogPilot.info('Closeable detail');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Closeable detail'));
      await tester.pumpAndSettle();

      expect(find.text('Record Detail'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Record Detail'), findsNothing);
    });

    testWidgets('detail sheet shows copy-all button', (tester) async {
      LogPilot.info('Copy test');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Copy test'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy_all_rounded), findsOneWidget);
    });

    testWidgets('log tile shows chevron when record has detail',
        (tester) async {
      LogPilot.info('With metadata', metadata: {'k': 'v'});

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    // ── Feature #14: Tag Filter Chips ────────────────────────────────

    testWidgets('tag filter chips appear when records have tags',
        (tester) async {
      LogPilot.info('Auth msg', tag: 'Auth');
      LogPilot.info('Cart msg', tag: 'Cart');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.text('All Tags'), findsOneWidget);
      expect(find.text('Auth'), findsWidgets);
      expect(find.text('Cart'), findsWidgets);
    });

    testWidgets('tag filter chips are absent when no records have tags',
        (tester) async {
      LogPilot.info('No tag message');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.text('All Tags'), findsNothing);
    });

    testWidgets('tapping a tag chip filters records by tag', (tester) async {
      LogPilot.info('Auth event', tag: 'Auth');
      LogPilot.info('Cart event', tag: 'Cart');
      LogPilot.info('No tag event');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 records'), findsOneWidget);

      // Tap Auth chip — the tag appears in both chip row and log tiles,
      // so we find the one in the chip row (first occurrence).
      final authChips = find.text('Auth');
      await tester.tap(authChips.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('1 records'), findsOneWidget);
      expect(find.textContaining('Auth event'), findsOneWidget);
      expect(find.textContaining('Cart event'), findsNothing);
    });

    testWidgets('tapping All Tags resets the tag filter', (tester) async {
      LogPilot.info('A msg', tag: 'A');
      LogPilot.info('B msg', tag: 'B');

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.terminal_rounded));
      await tester.pumpAndSettle();

      // Filter by tag A
      final aChips = find.text('A');
      await tester.tap(aChips.first);
      await tester.pumpAndSettle();
      expect(find.textContaining('1 records'), findsOneWidget);

      // Reset
      await tester.tap(find.text('All Tags'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 records'), findsOneWidget);
    });
  });
}

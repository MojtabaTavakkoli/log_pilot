import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:log_pilot_example/main.dart';

void main() {
  testWidgets('Example app renders header and first section', (tester) async {
    await tester.pumpWidget(const LogPilotExampleApp());

    expect(find.text('LogPilot'), findsOneWidget);
    expect(find.text('1. Log Levels'), findsOneWidget);
  });

  testWidgets('Log level action tiles are present', (tester) async {
    await tester.pumpWidget(const LogPilotExampleApp());

    expect(find.text('Verbose'), findsOneWidget);
    expect(find.text('Debug'), findsOneWidget);
    expect(find.text('Info + Metadata'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Fatal'), findsOneWidget);
  });

  testWidgets('Scrolling reveals later sections', (tester) async {
    await tester.pumpWidget(const LogPilotExampleApp());

    await tester.dragUntilVisible(
      find.text('2. JSON Pretty-Print'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    expect(find.text('2. JSON Pretty-Print'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('4. Network Logging'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    expect(find.text('4. Network Logging'), findsOneWidget);
  });
}

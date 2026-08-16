// Widget tests for Codeskate CRM.
//
// NOTE: The app root (CodeskateApp) requires Firebase to be initialised, so it
// can't be pumped in a plain widget test. Instead we smoke-test the pure UI
// primitives from the design system, which have no platform dependencies.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codeskate_crm/screens/widgets/ui_kit.dart';

void main() {
  testWidgets('StatLabel renders its text in uppercase', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: StatLabel('active pipeline')),
      ),
    );

    expect(find.text('ACTIVE PIPELINE'), findsOneWidget);
  });

  testWidgets('SectionHeader shows the title and fires its action',
      (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionHeader(
            title: 'Recent leads',
            actionLabel: 'See all',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Recent leads'), findsOneWidget);

    await tester.tap(find.text('See all'));
    expect(tapped, isTrue);
  });

  testWidgets('EmptyState shows the title and hint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox_rounded,
            title: 'No leads yet',
            hint: 'New leads will show up here.',
          ),
        ),
      ),
    );

    expect(find.text('No leads yet'), findsOneWidget);
    expect(find.text('New leads will show up here.'), findsOneWidget);
  });
}

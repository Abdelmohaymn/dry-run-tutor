// Principle I / FR-009: the mic is the composer's primary target and the
// keyboard is never promoted over it.
//
// The composer has been three shapes. A 96dp circle over a language picker
// over a small underlined "or type instead" link took a third of the
// screen; a mic beside a muted pill was compact but still made the
// keyboard a destination. This is the shape that read best on a real
// device — the field simply present, the mic on the right where every
// chat app puts its send action.
//
// **A DEPARTURE from FR-009's "one deliberate tap away"**, taken on the
// learner's own instruction after the link proved hard to find. What is
// asserted here is the part of FR-009 that did not change: voice is the
// prominent action, and the keyboard is never the louder of the two.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/core/theme/tokens.dart';
import 'package:dry_run/features/chat/presentation/widgets/composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpComposer(
    WidgetTester tester, {
    required VoidCallback onMicTap,
    ValueChanged<String>? onSubmit,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Composer(onMicTap: onMicTap, onSubmit: onSubmit ?? (String _) {}),
          ),
        ),
      ),
    );
  }

  Container micTarget(WidgetTester tester) => tester.widget<Container>(
        find.ancestor(of: find.byIcon(Icons.mic), matching: find.byType(Container)).first,
      );

  testWidgets('the mic is a single large target', (WidgetTester tester) async {
    await pumpComposer(tester, onMicTap: () {});

    expect(find.byIcon(Icons.mic), findsOneWidget);
    final Size size = tester.getSize(
      find.ancestor(of: find.byIcon(Icons.mic), matching: find.byType(Container)).first,
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('tapping the mic invokes onMicTap directly — no interstitial', (
    WidgetTester tester,
  ) async {
    int micTaps = 0;
    await pumpComposer(tester, onMicTap: () => micTaps++);

    await tester.tap(find.byIcon(Icons.mic));
    expect(micTaps, 1);
  });

  testWidgets('the mic is the only filled target — the field is a muted outline', (
    WidgetTester tester,
  ) async {
    await pumpComposer(tester, onMicTap: () {});

    final BoxDecoration mic = micTarget(tester).decoration! as BoxDecoration;
    expect(mic.color, AppTokens.accentDim, reason: 'voice carries the one accent');
    expect(mic.shape, BoxShape.circle);

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.decoration!.fillColor,
      AppTokens.surface2,
      reason: 'the keyboard never wears the accent',
    );
  });

  testWidgets('typing turns the mic into send, so there are never two primary actions', (
    WidgetTester tester,
  ) async {
    final List<String> submitted = <String>[];
    await pumpComposer(tester, onMicTap: () {}, onSubmit: submitted.add);

    await tester.enterText(find.byType(TextField), 'I would walk the list once.');
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(submitted, <String>['I would walk the list once.']);
    // Cleared, and the mic is back — the field is not left holding a turn
    // that has already gone to review.
    expect(find.byIcon(Icons.mic), findsOneWidget);
  });

  testWidgets('an empty field submits nothing and keeps the mic', (WidgetTester tester) async {
    int micTaps = 0;
    final List<String> submitted = <String>[];
    await pumpComposer(tester, onMicTap: () => micTaps++, onSubmit: submitted.add);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic));

    expect(submitted, isEmpty);
    expect(micTaps, 1, reason: 'whitespace is not text, so the target is still the mic');
  });
}

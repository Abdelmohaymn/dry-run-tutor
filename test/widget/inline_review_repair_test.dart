// quickstart.md §6. data-model.md §3's revert affordance condition,
// exercised through the actual widget.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/domain/draft.dart';
import 'package:dry_run/features/chat/presentation/widgets/inline_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpReview(
    WidgetTester tester, {
    required Draft draft,
    VoidCallback? onRevert,
    ValueChanged<String>? onGlossaryApply,
    List<String> glossaryTerms = const <String>[],
    VoidCallback? onSend,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InlineReview(
            draft: draft,
            glossaryTerms: glossaryTerms,
            onChanged: (String _) {},
            onGlossaryApply: onGlossaryApply ?? (String _) {},
            onSend: onSend ?? () {},
            onSecondary: () {},
            onRevert: onRevert ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('repair changed something: the revert button is present and one tap calls onRevert', (
    WidgetTester tester,
  ) async {
    bool reverted = false;
    await pumpReview(
      tester,
      draft: const Draft(
        text: 'I would use a hash map',
        recognised: 'I would use a hash mop',
        repaired: 'I would use a hash map',
        inputMode: InputMode.voice,
      ),
      onRevert: () => reverted = true,
    );

    expect(find.text('Show what I said'), findsOneWidget);
    await tester.tap(find.text('Show what I said'));
    expect(reverted, isTrue);
  });

  testWidgets('repair changed nothing (repaired == recognised): the button is absent', (
    WidgetTester tester,
  ) async {
    await pumpReview(
      tester,
      draft: const Draft(
        text: 'nothing to fix here',
        recognised: 'nothing to fix here',
        repaired: 'nothing to fix here',
        inputMode: InputMode.voice,
      ),
    );

    expect(find.text('Show what I said'), findsNothing);
  });

  testWidgets('repair never ran (repaired == null): the button is absent', (WidgetTester tester) async {
    await pumpReview(
      tester,
      draft: const Draft(
        text: 'a typed draft',
        inputMode: InputMode.text,
      ),
    );

    expect(find.text('Show what I said'), findsNothing);
  });

  testWidgets('the glossary chips still match and apply on a repaired draft', (WidgetTester tester) async {
    // The chip fires on a NEAR-miss (the matching logic skips an exact
    // match), so this draft still has "hash mop" in `text` — repair ran
    // (`repaired` is non-null) but did not touch this particular word.
    String? applied;
    await pumpReview(
      tester,
      draft: const Draft(
        text: 'I would use a hash mop to store values',
        recognised: 'I would use a hash mop to store values',
        repaired: 'I would use a hash mop to store the values',
        inputMode: InputMode.voice,
      ),
      glossaryTerms: const <String>['hash map'],
      onGlossaryApply: (String updated) => applied = updated,
    );

    expect(find.text('hash map'), findsOneWidget);
    await tester.tap(find.text('hash map'));
    expect(applied, isNotNull);
  });

  testWidgets('the glossary chips still match and apply on a raw (never-repaired) draft', (
    WidgetTester tester,
  ) async {
    String? applied;
    await pumpReview(
      tester,
      draft: const Draft(
        text: 'I would use a hash mop to store values',
        recognised: 'I would use a hash mop to store values',
        inputMode: InputMode.voice,
      ),
      glossaryTerms: const <String>['hash map'],
      onGlossaryApply: (String updated) => applied = updated,
    );

    expect(find.text('hash map'), findsOneWidget);
    await tester.tap(find.text('hash map'));
    expect(applied, isNotNull);
  });

  testWidgets('an empty draft cannot be sent', (WidgetTester tester) async {
    bool sent = false;
    await pumpReview(
      tester,
      draft: const Draft(text: '   ', inputMode: InputMode.text),
      onSend: () => sent = true,
    );

    await tester.tap(find.byIcon(Icons.arrow_upward));
    expect(sent, isFalse);
  });
}

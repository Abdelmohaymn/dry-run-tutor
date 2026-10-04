// Feature 005: the finish offer is two plain choices, and neither one fires
// without a tap.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/presentation/widgets/finish_offer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Finish and Keep going each call their own callback, once', (WidgetTester tester) async {
    int finished = 0;
    int keptGoing = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FinishOfferCard(onFinish: () => finished++, onKeepGoing: () => keptGoing++),
        ),
      ),
    );
    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(FinishOfferCard)))!;

    expect(find.text(l10n.finishOfferTitle), findsOneWidget);
    expect(finished + keptGoing, 0);

    await tester.tap(find.text(l10n.finishOfferKeepGoing));
    expect((finished, keptGoing), (0, 1));

    await tester.tap(find.text(l10n.finishOfferFinish));
    expect((finished, keptGoing), (1, 1));
  });
}

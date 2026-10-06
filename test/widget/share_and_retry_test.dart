// Two things a real session showed were broken rather than missing.
//
//   * "Not sent — tap to retry" was a caption, not a control. Nothing was
//     listening, so a turn that failed on anything other than a transport
//     error was parked forever with no way for the learner to try again.
//   * The share card went out as five unstyled lines opening with a raw
//     approach key and closing with a `dryrun://` URI no chat app
//     makes tappable.
import 'package:dry_run/core/config/brand.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/chat/domain/message.dart';
import 'package:dry_run/features/chat/presentation/widgets/message_list.dart';
import 'package:dry_run/features/streak/presentation/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


Assessment _assessment({
  String? claimedTime = 'O(n*m)',
  String? claimedSpace = 'O(1)',
  MatchedVerdict matched = MatchedVerdict.optimal,
}) =>
    Assessment(
      sessionId: 'session-1',
      matchedApproach: matched == MatchedVerdict.none ? 'none' : 'two_pointer_scan',
      matchedVerdict: matched,
      insightsHit: const <String>['a', 'b', 'c'],
      insightsMissed: const <String>['d'],
      wrongTurnsTaken: const <String>[],
      complexity: Complexity(
        userClaimedTime: claimedTime,
        userClaimedSpace: claimedSpace,
        referenceTime: 'O(n)',
        referenceSpace: 'O(n)',
        assessment: 'correct',
      ),
      verdict: Verdict.strongPass,
      confidence: 0.9,
      feedback: 'Clear reasoning.',
      editorial: 'Two pointers.',
    );

ShareCard _card({Assessment? assessment, int streakLength = 2}) => ShareCard(
      assessment: assessment ?? _assessment(),
      streakLength: streakLength,
      problemTitle: 'First Palindromic String',
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// Everything the card paints, flattened.
String _rendered(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('\n');

void main() {
  // The card and the message text deliberately carry different things:
  // detail is welcome in a picture and noise in a sentence.
  group('the share card image', () {
    testWidgets('carries the problem, how it went, the approach and the complexity', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _card());

      final String rendered = _rendered(tester);
      expect(rendered, contains('First Palindromic String'));
      expect(rendered, contains('Strong approach'));
      expect(rendered, contains('Two pointer scan'));
      expect(rendered, contains('O(n*m) time, O(1) space'));
    });

    testWidgets('leaves the opener and the invitation to the message', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _card());

      final BuildContext context = tester.element(find.byType(ShareCard));
      final AppLocalizations l10n = AppLocalizations.of(context)!;
      final String rendered = _rendered(tester);

      // Those two lines are what the words in the thread are *for*.
      // Repeating them inside the picture is the message talking over
      // itself.
      expect(rendered, isNot(contains(l10n.shareCardOpener)));
      expect(rendered, isNot(contains(l10n.shareCardInvite)));
    });

    testWidgets('shows the landing site', (WidgetTester tester) async {
      await _pump(tester, _card());
      expect(_rendered(tester), contains(shareCardSiteLabel));
    });

    testWidgets('names no approach when the catalogue lists none', (WidgetTester tester) async {
      // `matched_approach: "none"` is a designed state — an approach the
      // author did not think of — not a gap to paper over.
      await _pump(tester, _card(assessment: _assessment(matched: MatchedVerdict.none)));

      expect(_rendered(tester), isNot(contains('Two pointer scan')));
      expect(_rendered(tester), contains('First Palindromic String'));
    });

    testWidgets('shows no complexity when the learner stated none, not the reference\'s', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _card(assessment: _assessment(claimedTime: null, claimedSpace: null)),
      );

      final String rendered = _rendered(tester);
      expect(rendered, isNot(contains('O(n)')));
      expect(rendered, isNot(contains('Complexity')));
    });

    testWidgets('shows only the half the learner stated', (WidgetTester tester) async {
      await _pump(
        tester,
        _card(assessment: _assessment(claimedTime: 'O(n log n)', claimedSpace: null)),
      );

      final String rendered = _rendered(tester);
      expect(rendered, contains('O(n log n)'));
      expect(rendered, isNot(contains('O(n) space')));
    });

    testWidgets('still never scores them out of four, or prints a dead link', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _card());

      final String rendered = _rendered(tester);
      // A tally reads as a score, which FR-022a avoids everywhere else.
      expect(rendered, isNot(contains('of 4')));
      expect(
        rendered,
        isNot(contains('dryrun://')),
        reason: 'no chat app linkifies a custom scheme — it was inert characters',
      );
      // The approach class went out as a raw ground-truth key.
      expect(rendered, isNot(contains('two_pointer_scan')));
    });

    testWidgets('keeps the streak', (WidgetTester tester) async {
      await _pump(tester, _card());

      final BuildContext context = tester.element(find.byType(ShareCard));
      expect(
        _rendered(tester),
        contains(AppLocalizations.of(context)!.shareCardStreakLine(2)),
      );
    });
  });

  group('the shared message text', () {
    testWidgets('is an invitation, not a scorecard', (WidgetTester tester) async {
      await _pump(tester, _card());
      final BuildContext context = tester.element(find.byType(ShareCard));
      final AppLocalizations l10n = AppLocalizations.of(context)!;

      final String text = shareMessageText(l10n);

      expect(text, contains(l10n.shareCardOpener));
      expect(text, isNot(contains(l10n.shareCardStreakLine(2))));
      expect(text, contains(l10n.shareCardInvite));
      expect(text.split('\n').last, AppBrand.websiteUrl);
      // The detail belongs on the card, where it is something to look at.
      // In a sentence in someone's chat thread it is noise about a problem
      // they have not seen.
      expect(text, isNot(contains('First Palindromic String')));
      expect(text, isNot(contains('Strong approach')));
      expect(text, isNot(contains('O(')));
    });
  });

  group('the retry affordance', () {
    Message failed() => const Message(
          id: 'message-1',
          seq: 0,
          role: TurnRole.user,
          text: 'I would walk the list once.',
          kind: MessageKind.turn,
          delivery: Delivery.failedRetryable,
          inputMode: InputMode.voice,
        );

    testWidgets('the label is a control, and it hands back the failed message', (
      WidgetTester tester,
    ) async {
      final List<Message> retried = <Message>[];
      await _pump(
        tester,
        SizedBox(
          height: 400,
          child: MessageList(
            messages: <Message>[failed()],
            hintCount: 3,
            onRetry: retried.add,
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(MessageList));
      await tester.tap(find.text(AppLocalizations.of(context)!.messageListFailedRetryLabel));
      await tester.pump();

      expect(retried, hasLength(1));
      expect(retried.single.id, 'message-1');
    });

    testWidgets('a delivered turn offers no retry at all', (WidgetTester tester) async {
      await _pump(
        tester,
        SizedBox(
          height: 400,
          child: MessageList(
            messages: <Message>[
              const Message(
                id: 'message-2',
                seq: 0,
                role: TurnRole.user,
                text: 'Sent fine.',
                kind: MessageKind.turn,
                delivery: Delivery.sent,
              ),
            ],
            hintCount: 3,
            onRetry: (Message _) {},
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(MessageList));
      expect(
        find.text(AppLocalizations.of(context)!.messageListFailedRetryLabel),
        findsNothing,
      );
    });
  });
}

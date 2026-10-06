// Three defects reported from one assessment on a physical device
// (2026-09-04), all on this screen:
//
//   * "Dispute this assessment" wrote a flag and changed nothing on
//     screen, so it read as a broken button. It was working; it was
//     invisible.
//   * The insight lists painted raw ground-truth keys —
//     `two_pointer_no_copy` — where a sentence belonged.
//   * Complexity was one of three fixed phrases with none of the four
//     values the judge returns behind it, so "differs from the reference"
//     could not be checked or argued with.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/assessment/presentation/assessment_copy.dart';
import 'package:dry_run/features/assessment/presentation/dispute_action.dart';
import 'package:dry_run/features/assessment/presentation/verdict_screen.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart' as chat;
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_streak_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0003',
  title: 'First Palindromic String',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'You are given a list of words.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

Session _session({bool disputed = false}) => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.complete,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: disputed,
      solutionRequestCount: 0,
    );

Assessment _assessment({
  MatchedVerdict matched = MatchedVerdict.acceptable,
  Complexity complexity = const Complexity(
    userClaimedTime: 'O(n*m)',
    userClaimedSpace: 'O(1)',
    referenceTime: 'O(n*m)',
    referenceSpace: 'O(1)',
    assessment: 'correct',
  ),
}) =>
    Assessment(
      sessionId: 'session-1',
      matchedApproach: 'two_pointer_scan',
      matchedVerdict: matched,
      insightsHit: const <String>['scan_in_array_order', 'two_pointer_no_copy'],
      insightsMissed: const <String>['constraints_are_forgiving'],
      wrongTurnsTaken: const <String>[],
      complexity: complexity,
      verdict: Verdict.pass,
      confidence: 0.8,
      feedback: 'Solid reasoning throughout.',
      editorial: 'Use two pointers.',
    );

DailySessionCubit _cubit(FakeAssessmentRepository assessments, {bool disputed = false}) =>
    DailySessionCubit(
      sessionRepository: FakeSessionRepository()..initialSession = _session(disputed: disputed),
      streakRepository: FakeStreakRepository(),
      assessmentRepository: assessments,
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );

/// The verdict screen is a lazy `ListView` and the dispute control sits
/// below the fold on a test-sized window, so it is not built until it is
/// scrolled to. Reaching it is part of using the screen, not part of what
/// is being asserted.
Future<void> _scrollToDispute(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(DisputeAction),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpVerdict(WidgetTester tester, DailySessionCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<DailySessionCubit>.value(value: cubit, child: const VerdictScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  group('humaniseInsightKey', () {
    test('turns a ground-truth key into a sentence-cased phrase', () {
      expect(humaniseInsightKey('two_pointer_no_copy'), 'Two pointer no copy');
      expect(humaniseInsightKey('scan_in_array_order'), 'Scan in array order');
    });

    test('leaves a key with nothing to split alone', () {
      expect(humaniseInsightKey('none'), 'None');
      expect(humaniseInsightKey(''), '');
    });
  });

  testWidgets('the insight lists read as words, not as ground-truth keys', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit(FakeAssessmentRepository());
    addTearDown(cubit.close);
    cubit.emit(chat.DailySessionState.verdict(_session(), _assessment()));
    await _pumpVerdict(tester, cubit);

    expect(find.text('Two pointer no copy'), findsOneWidget);
    expect(find.text('Constraints are forgiving'), findsOneWidget);
    expect(find.textContaining('_'), findsNothing);
  });

  testWidgets('complexity shows what the learner claimed beside the reference', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit(FakeAssessmentRepository());
    addTearDown(cubit.close);
    cubit.emit(
      chat.DailySessionState.verdict(
        _session(),
        _assessment(
          complexity: const Complexity(
            userClaimedTime: 'O(n log n)',
            userClaimedSpace: 'O(1)',
            referenceTime: 'O(n)',
            referenceSpace: 'O(n)',
            assessment: 'mismatched',
          ),
        ),
      ),
    );
    await _pumpVerdict(tester, cubit);

    // Twice: once in the Complexity block, once on the share card, which
    // prints the learner's own numbers rather than a verdict on them.
    expect(find.text('O(n log n) time, O(1) space'), findsWidgets);
    expect(find.text('O(n) time, O(n) space'), findsOneWidget);
  });

  testWidgets('an approach outside the reference set says so, and is not marked down', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit(FakeAssessmentRepository());
    addTearDown(cubit.close);
    cubit.emit(
      chat.DailySessionState.verdict(_session(), _assessment(matched: MatchedVerdict.none)),
    );
    await _pumpVerdict(tester, cubit);

    expect(find.textContaining("isn't one on file"), findsOneWidget);
  });

  testWidgets('disputing acknowledges the tap instead of appearing to do nothing', (
    WidgetTester tester,
  ) async {
    final FakeAssessmentRepository assessments = FakeAssessmentRepository();
    final DailySessionCubit cubit = _cubit(assessments);
    addTearDown(cubit.close);
    cubit.emit(chat.DailySessionState.verdict(_session(), _assessment()));
    await _pumpVerdict(tester, cubit);

    final BuildContext context = tester.element(find.byType(VerdictScreen));
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    await _scrollToDispute(tester);

    // Before: the control, and a line saying what it will do.
    expect(find.text(l10n.verdictDisputeAction), findsOneWidget);
    expect(find.text(l10n.verdictDisputeExplainer), findsOneWidget);

    await tester.tap(find.text(l10n.verdictDisputeAction));
    await tester.pumpAndSettle();

    // After: the notice that was authored in the ARB and never rendered.
    expect(find.text(l10n.verdictDisputedNotice), findsOneWidget);
    expect(find.text(l10n.verdictDisputeAction), findsNothing);
    expect(assessments.disputedSessionIds, contains('session-1'));
  });

  testWidgets('a session already disputed shows the notice on arrival', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit(FakeAssessmentRepository());
    addTearDown(cubit.close);
    cubit.emit(chat.DailySessionState.verdict(_session(disputed: true), _assessment()));
    await _pumpVerdict(tester, cubit);
    await _scrollToDispute(tester);

    expect(find.byType(DisputeAction), findsOneWidget);
    final BuildContext context = tester.element(find.byType(VerdictScreen));
    expect(
      find.text(AppLocalizations.of(context)!.verdictDisputedNotice),
      findsOneWidget,
      reason: 'the flag is on the session row, so it survives leaving and returning',
    );
  });
}

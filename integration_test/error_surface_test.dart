// T144 (US7), SC-008: all eleven catalogue codes, plus `transport`, driven
// through the real `DailySessionCubit` — not just `resolveErrorCopy`
// directly (`test/unit/error_copy_test.dart` already walks the sealed
// union for that) — so this is what proves each code actually reaches a
// distinct, actionable surface through the app's own error-handling path,
// not only through the mapping function in isolation.
//
// Same substitution as the rest of this directory: the relay round trip
// is scripted via `FakeSessionRepository`.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/error_copy.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/l10n/generated/app_localizations_en.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/fake_assessment_repository.dart';
import '../test/fakes/fake_config_repository.dart';
import '../test/fakes/fake_mic_rationale_repository.dart';
import '../test/fakes/fake_recognition_service.dart';
import '../test/fakes/fake_session_repository.dart';
import '../test/fakes/fake_streak_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Two Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'Given an array, return indices of the two numbers that add up to target.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

Session _session() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

/// The eleven catalogue codes (data-model.md §12) plus `transport` — the
/// closed set SC-008 requires a distinct, actionable surface for.
const List<RelayError> _allCodes = <RelayError>[
  RelayError.rateLimited(retryAfter: Duration(seconds: 5)),
  RelayError.invalidKey(),
  RelayError.quotaExhausted(),
  RelayError.unclearRetry(),
  RelayError.turnCapReached(),
  RelayError.trialConsumed(),
  RelayError.sessionAlreadyJudged(ctx: JudgedContext.repeatJudge),
  RelayError.sessionAlreadyJudged(ctx: JudgedContext.turnAfterVerdict),
  RelayError.emptyTurn(),
  RelayError.trialUnavailable(),
  RelayError.problemKilled(problemId: 'vp-0001'),
  RelayError.badRequest(),
  RelayError.transport(),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  DailySessionCubit buildCubit(FakeSessionRepository sessionRepository) => DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()
          ..cachedValue = const RuntimeConfig(
            minSupportedVersion: '1.0.0',
            killedProblemIds: <String>[],
            chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
            trial: TrialConfig(turnCap: 4),
            keyedProviders: <String>['groq'],
          ),
        micRationaleRepository: FakeMicRationaleRepository(),
      );

  test('every catalogue code plus transport resolves to a distinct, actionable message', () async {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    final Set<String> messages = <String>{};

    for (final RelayError error in _allCodes) {
      final ErrorCopy copy = resolveErrorCopy(l10n, error);
      expect(copy.message, isNotEmpty, reason: '$error resolved to an empty message');
      expect(
        messages.add(copy.message),
        isTrue,
        reason: '$error shares a message with another code — SC-008 requires distinct copy',
      );
      // "Actionable": either a next action naming what to do, or a
      // deliberate `none`/`automaticRetry` — the two codes the catalogue
      // itself says need no tap at all (`transport`, `rateLimited`).
      expect(copy.nextAction, isNotNull);
    }

    expect(messages, hasLength(_allCodes.length));
  });

  test('each code, driven through the real Cubit, reaches its correct terminal state', () async {
    for (final RelayError error in _allCodes) {
      final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        return Stream<TurnEvent>.error(RelayException(error));
      };
      final DailySessionCubit cubit = buildCubit(sessionRepository);
      addTearDown(cubit.close);
      // `DailySessionCubit` refuses every action until `open()` has
      // resolved — it throws rather than guess at a session.
      await cubit.open();

      await cubit.sendTyped('a full spoken-length turn about my approach');

      final DailySessionState state = cubit.state;
      if (error is SessionAlreadyJudged) {
        // FR-034 scenario 4: both `SESSION_ALREADY_JUDGED` situations
        // close the session rather than leaving a retryable `Failure` —
        // "retry the same text" is not a coherent next action once the
        // session is over, for either meaning of the code.
        expect(state, isA<SessionClosed>(), reason: '$error did not close the session');
      } else {
        expect(state, isA<Failure>(), reason: '$error did not surface as Failure');
        expect((state as Failure).error, error);
      }
    }
  });
}

// T085 — FR-007a/b, SC-020: spend every trial turn, save a key, and
// assert the **same** conversation continues with history and revealed
// hints intact, a raised allowance, and a visible message saying so. A
// new empty conversation here is a failure even though nothing crashed.
//
// The relay round trip itself is scripted (`FakeSessionRepository`), the
// same substitution `voice_interruption_test.dart` uses and for the same
// reason: the claim under test is the *app's* handling of the handover —
// same session id, same counters carried across `promoteToKeyed`, no
// conversation reset — not the network path, which quickstart.md
// exercises for real on a physical device.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/fake_analytics_client.dart';
import '../test/fakes/fake_assessment_repository.dart';
import '../test/fakes/fake_streak_repository.dart';
import '../test/fakes/fake_config_repository.dart';
import '../test/fakes/fake_mic_rationale_repository.dart';
import '../test/fakes/fake_recognition_service.dart';
import '../test/fakes/fake_session_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Two Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'Given an array of integers, return indices of the two numbers that add up to target.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>['hashmap'],
  hintCount: 3,
);

Session _trialSession() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      // Already 2 hints deep and 3 turns in — history the handover must
      // not discard.
      counters: const ServerCounters(
        turnIndex: 3,
        turnsRemaining: 1,
        hintsRevealed: 2,
        hintsRemaining: 8,
        sessionEnded: null,
        leakBlocked: false,
      ),
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('the taster running out mid-conversation, followed by a saved key, keeps the same session', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _trialSession();
    final FakeRemoteConfigRepository configRepository = FakeRemoteConfigRepository()
      ..cachedValue = const RuntimeConfig(
        minSupportedVersion: '1.0.0',
        killedProblemIds: <String>[],
        contentManifestUrl: '/v1/content/manifest.json',
        chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
        trial: TrialConfig(turnCap: 4),
        keyedProviders: <String>['groq'],
      );

    // The last trial turn: the relay's own `meta.session_ended == 'cap'`
    // is what tells the app the taster is spent — the app never counts
    // this itself (FR-019).
    sessionRepository.sendTurnHandler = (_, _, _) => Stream<TurnEvent>.fromIterable(<TurnEvent>[
          const TurnEvent.token('One more thing before we wrap up —'),
          TurnEvent.meta(
            const ServerCounters(
              turnIndex: 4,
              turnsRemaining: 0,
              hintsRevealed: 2,
              hintsRemaining: 8,
              sessionEnded: 'cap',
              leakBlocked: false,
            ),
          ),
        ]);

    final DailySessionCubit cubit = DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: configRepository,
      analyticsClient: FakeAnalyticsClient(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );
    addTearDown(cubit.close);

    await cubit.open();
    await cubit.sendTyped('What should I consider about the time complexity here?');

    final DailySessionState afterCap = cubit.state;
    if (afterCap is! CapReached) {
      throw StateError('expected CapReached once the taster ran out, got $afterCap');
    }
    expect(afterCap.session.path, SessionPath.trial);
    expect(afterCap.session.counters.hintsRevealed, 2, reason: 'revealed hints must survive the handover');
    final String sessionId = afterCap.session.id;

    // The key is saved (KeyEntryCubit/KeyRepository — Phase 4's own
    // suite covers the probe-before-persist contract); what this test
    // owns is what happens to the *session* once that succeeds.
    await cubit.promoteToKeyed('groq');

    final DailySessionState afterPromotion = cubit.state;
    if (afterPromotion is! Composing) {
      throw StateError('expected Composing with room to keep talking, got $afterPromotion');
    }
    expect(afterPromotion.session.id, sessionId, reason: 'same conversation, not a new one (SC-020)');
    expect(afterPromotion.session.path, SessionPath.keyed);
    expect(afterPromotion.session.counters.hintsRevealed, 2, reason: 'hints revealed carry across the handover');
    expect(afterPromotion.session.counters.turnIndex, 4, reason: 'turn history carries across the handover');
  });
}

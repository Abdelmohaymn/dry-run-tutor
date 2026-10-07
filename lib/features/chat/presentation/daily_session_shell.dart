import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/remote_config_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/models/wire_enums.dart' hide Verdict;
import '../../../core/router/app_route.dart';
import '../../assessment/domain/assessment_repository.dart';
import '../../cloud_voice/domain/cloud_voice_repository.dart';
import '../../settings/domain/settings_repository.dart';
import '../../streak/domain/streak_repository.dart';
import '../../transcript/domain/transcript_repair_repository.dart';
import '../../voice/domain/mic_rationale_repository.dart';
import '../../voice/domain/recognition_service.dart';
import '../domain/session_repository.dart';
import 'daily_session_cubit.dart';
import 'daily_session_state.dart';

/// The `ShellRoute` builder for the whole daily session flow — `/`,
/// `/session/record`, `/session/review`, `/session/mic-rationale`, and
/// `/session/recognition-unavailable` all share **one**
/// `DailySessionCubit`, because they are one flow across several routes,
/// not several independent screens (data-model.md §11).
///
/// `sl<T>()` for every dependency is resolved once, here, inside this
/// `BlocProvider(create:)` — the composition-root rule
/// (`no_service_locator_outside_root`, contracts/routes.md) — and the
/// Cubit then drives navigation itself: a [BlocListener] routes to the
/// path that matches the current state, so a screen can never be reached
/// out of the sequence FR-012/Principle V requires.
class DailySessionShell extends StatelessWidget {
  const DailySessionShell({
    required this.child,
    required this.sessionRepository,
    required this.assessmentRepository,
    required this.streakRepository,
    required this.recognitionService,
    required this.configRepository,
    required this.micRationaleRepository,
    super.key,
  });

  final Widget child;
  final SessionRepository sessionRepository;
  final AssessmentRepository assessmentRepository;
  final StreakRepository streakRepository;
  final RecognitionService recognitionService;
  final RemoteConfigRepository configRepository;
  final MicRationaleRepository micRationaleRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DailySessionCubit>(
      create: (_) => DailySessionCubit(
        sessionRepository: sessionRepository,
        assessmentRepository: assessmentRepository,
        streakRepository: streakRepository,
        recognitionService: recognitionService,
        configRepository: configRepository,
        micRationaleRepository: micRationaleRepository,
        // Resolved here, inside `create:` — an allowed `sl<T>()` site
        // (`no_service_locator_outside_root`) — rather than threaded
        // through this shell's own constructor and `buildAppRouter`'s,
        // since only FR-048b's reminder-cancel needs it (T156).
        settingsRepository: sl<SettingsRepository>(),
        // Same reasoning as settingsRepository above.
        transcriptRepairRepository: sl<TranscriptRepairRepository>(),
        // Same reasoning as settingsRepository above.
        cloudVoiceRepository: sl<CloudVoiceRepository>(),
      )..open(),
      child: BlocListener<DailySessionCubit, DailySessionState>(
        listenWhen: (DailySessionState previous, DailySessionState current) =>
            _routeFor(current) != null && _routeFor(current) != GoRouterState.of(context).matchedLocation,
        listener: (BuildContext context, DailySessionState state) {
          final String? target = _routeFor(state);
          if (target != null) {
            context.go(target);
          }
        },
        child: child,
      ),
    );
  }

  static String? _routeFor(DailySessionState state) => switch (state) {
        Opening() => null,
        ProblemUnavailable() => AppRoute.withdrawn.path,
        Reading() => AppRoute.daily.path,
        Composing() => AppRoute.daily.path,
        // Speaking, transcribing, and editing the transcript are three
        // states of the daily screen's composer, not three screens: a
        // single turn used to cost two full-screen navigations and hid
        // the conversation for both. `/session/record` and
        // `/session/review` remain routable (and their screens still
        // build) — nothing sends the learner there.
        Recording() => AppRoute.daily.path,
        Recognising() => AppRoute.daily.path,
        VoiceUploadFailed() => AppRoute.daily.path,
        ReviewingTranscript() => AppRoute.daily.path,
        Sending() => AppRoute.daily.path,
        Streaming() => AppRoute.daily.path,
        // Stays put. A hint is pulled from three different states and
        // reattaches to whichever it came from, so sending it anywhere
        // would be a navigation the learner never asked for.
        PullingHint() => AppRoute.daily.path,
        WrappingUp() => AppRoute.daily.path,
        FinishOffered() => AppRoute.daily.path,
        // A trial-path cap is "a completed session" for FR-005a's wall
        // (T090) — the app has no judge-driven `endSession` yet
        // (Phase 6, T111), so the taster running out is the completion
        // signal this phase has. A keyed-path cap stays on `/` and shows
        // `_CapReachedNotice` inline; there is no wall to reach.
        CapReached(:final session) =>
          session.path == SessionPath.trial ? AppRoute.keysWall.path : AppRoute.daily.path,
        ConfirmSolutionRelease() => AppRoute.sessionConfirmSolution.path,
        // No screen of its own: `_pursueAssessment` is typically in and
        // out of this state before a frame paints, and `/session/verdict`
        // (below) already shows a spinner for the identical
        // `state is! Verdict` case, so a dedicated route would just be
        // the same blank a moment longer.
        Judging() => AppRoute.daily.path,
        Verdict() => AppRoute.sessionVerdict.path,
        Revealed() => AppRoute.sessionReveal.path,
        SessionClosed() => AppRoute.daily.path,
        // TRIAL_CONSUMED and TRIAL_UNAVAILABLE used to route straight
        // into key entry with no intermediate screen
        // (contracts/relay-client.md, T089). They no longer navigate at
        // all: `DailyScreen` raises `showKeyPrompt` over the
        // conversation, which says why a key is being asked for before
        // any form appears, and only then *pushes* `/keys/entry`.
        // Routing from here would replace the stack and leave that form
        // with nowhere to go back to.
        // Every other `Failure` renders inline on `/` via
        // `_FailureNotice`, including `InvalidKey` — FR-005c asks for a
        // *prompt* to re-enter, not an automatic redirect, so that one
        // stays a button the learner taps.
        // RATE_LIMITED stays on `/` too: `DailyScreen` raises a popup
        // naming the key's limit, and the Cubit resends on its own.
        Failure() => AppRoute.daily.path,
        RecognitionUnavailable() => AppRoute.sessionRecognitionUnavailable.path,
      };
}

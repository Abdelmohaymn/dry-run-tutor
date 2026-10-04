import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/errors/relay_error.dart';
import '../../assessment/domain/assessment.dart';
import '../../voice/domain/recognition_availability.dart';
import '../domain/draft.dart';
import '../domain/session.dart';

part 'daily_session_state.freezed.dart';

/// `DailySessionCubit`'s state — one sealed union owning open → chat →
/// review → send → stream, because those steps share one session
/// (data-model.md §11). Exhaustively switched everywhere it is consumed:
/// `default:` is a compile error, which is the whole reason the
/// constitution mandates sealed unions over a bag of nullable fields.
///
/// `Seeding` and `UpdateRequired` are deliberately
/// **not** here at all: `core/router/app_router.dart`'s three guards
/// (T053) already redirect away from `/` before this Cubit is ever
/// constructed, and each has its own dedicated screen and route
/// (`/seeding`, `/update`) — duplicating them as states of
/// the daily loop would mean two places deciding the same thing.
///
/// `Failure` deliberately carries only the [RelayError], not a retry
/// closure: a function field breaks value-equality (`bloc_test` compares
/// states with `==`), so retrying is `DailySessionCubit.retry()` — a
/// method the screen calls directly — rather than a callback riding in
/// state.
@freezed
sealed class DailySessionState with _$DailySessionState {
  /// Transient: between `DailySessionCubit`'s construction (inside
  /// `BlocProvider(create:)`, per the composition-root rule) and
  /// `openOrResumeToday()` resolving. Not in data-model.md §11's own
  /// narrative, which starts at `Reading` — added because `sl<T>()` may
  /// only be resolved inside that `create:` callback
  /// (`no_service_locator_outside_root`), so the Cubit — not a
  /// `FutureBuilder` in the widget tree — owns the async bootstrap and
  /// needs a state to start from before it has a [Session] to attach to
  /// any other variant.
  const factory DailySessionState.opening() = Opening;

  /// `openOrResumeToday()` found no session for today and no non-withdrawn
  /// problem to start one from — every cached candidate is in
  /// `killed_problem_ids` (FR-040). No [Session] exists to carry, unlike
  /// every other variant below, which is why this sits beside [Opening]
  /// rather than joining the rest: `/withdrawn` (contracts/routes.md) is
  /// "usually invisible: a swap, not a screen", and this is the one case
  /// `DailyRepository.forToday()` cannot resolve on its own.
  const factory DailySessionState.problemUnavailable() = ProblemUnavailable;

  /// The daily, problem card expanded, before the first turn of this
  /// visit.
  const factory DailySessionState.reading(Session session) = Reading;

  /// Idle composer, mic primary. [draft] is the restored unsent draft, if
  /// any (FR-016, FR-024).
  ///
  /// [notice] is a one-line, non-error message explaining why the composer
  /// is being shown again — today only "nothing was heard". A listen
  /// session that ends with no transcript used to drop straight back here
  /// in silence, so the recording screen appeared to flash and vanish for
  /// no reason (found on a physical device). It is deliberately not a
  /// [Failure]: nothing failed, and the copy must not read as though it
  /// had.
  const factory DailySessionState.composing(Session session, Draft? draft, [String? notice]) =
      Composing;

  /// Waveform, timer, 90s cap, [warned] flips at the 15-second warning
  /// (FR-013a).
  /// [partialText] is what the recogniser has heard so far. It is shown
  /// live, and — more importantly — it is what survives an interruption:
  /// Android ends a listen session on its own pause timeout, and until
  /// this was carried here every word spoken before that point was thrown
  /// away (FR-013b, SC-005).
  const factory DailySessionState.recording({
    required Session session,
    required Duration elapsed,
    required List<double> levels,
    required bool warned,
    @Default('') String partialText,
  }) = Recording;

  const factory DailySessionState.recognising(Session session) = Recognising;

  /// **MANDATORY**, never skippable (Principle V, FR-012). [draft] is the
  /// recognised (or typed) text pending edit and send.
  const factory DailySessionState.reviewingTranscript(Session session, Draft draft) =
      ReviewingTranscript;

  const factory DailySessionState.sending(Session session, String pendingText) = Sending;

  /// Tokens painted as they arrive (FR-018).
  const factory DailySessionState.streaming(Session session, String partialText) = Streaming;

  /// `turnIndex >= config.chat.wrap_up_at_turn` (FR-022). The conversation
  /// winds down rather than stopping dead.
  const factory DailySessionState.wrappingUp(Session session) = WrappingUp;

  /// The relay's finish check says the learner has explained every
  /// required key insight (`meta.ready_to_finish`, feature 005). Offers
  /// Finish and Keep going; the conversation stays open either way and
  /// nothing is submitted without the learner's tap.
  const factory DailySessionState.finishOffered(Session session) = FinishOffered;

  /// A hint is paid for and on the wire. Its own state rather than a flag
  /// because the wait is visible: the rewarded video closes, and the rung
  /// still has to come back from `/v1/hint`. Without this the screen sat
  /// exactly as it was for that whole gap, which reads as a tap that did
  /// nothing — the learner had just watched a video for it.
  ///
  /// Painted like [Sending]: the dots go where the hint will land.
  /// `pullHint()` holds the state it came from and reattaches to it, so
  /// this never has to remember whether it interrupted [Composing],
  /// [WrappingUp] or [CapReached].
  const factory DailySessionState.pullingHint(Session session) = PullingHint;

  /// Turns spent; hints and end-session remain live (FR-023, FR-028).
  const factory DailySessionState.capReached(Session session) = CapReached;

  /// FR-021 — the only state a second solution request may be sent from.
  const factory DailySessionState.confirmSolutionRelease(Session session) = ConfirmSolutionRelease;

  /// The session has closed (status `pendingJudge`) and `/v1/judge` is in
  /// flight. No fields beyond [session] — there is nothing yet to show.
  const factory DailySessionState.judging(Session session) = Judging;

  /// The one assessment this session ever gets (Principle II — nothing
  /// here is ever constructed client-side). Dispute is always reachable
  /// from here (FR-031).
  const factory DailySessionState.verdict(Session session, Assessment assessment) = Verdict;

  /// The editorial, reached only from [Verdict] — never shown before the
  /// assessment is delivered (FR-032).
  const factory DailySessionState.revealed(Session session, Assessment assessment) = Revealed;

  /// A turn or hint attempt after the verdict was already delivered
  /// (FR-034 scenario 4) — told the session is closed rather than shown a
  /// bare failure. Distinct from [CapReached]: the cap bounds
  /// conversation, this bounds the session itself.
  const factory DailySessionState.sessionClosed(Session session) = SessionClosed;

  /// Every variant carries its own next action via `resolveErrorCopy`
  /// (`core/errors/error_copy.dart`).
  const factory DailySessionState.failure(Session session, RelayError error) = Failure;

  /// FR-011a — language pack route, keyboard interim only while this
  /// condition holds.
  const factory DailySessionState.recognitionUnavailable(Session session, RecognitionAvailability reason) =
      RecognitionUnavailable;
}

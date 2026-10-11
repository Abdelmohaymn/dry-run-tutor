import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
// `Verdict` here is `daily_session_state.dart`'s Cubit state, not the
// wire enum of the same name (`ServerCounters`/`Assessment`'s domain
// already speaks it where needed) — hidden to resolve the clash.
import '../../../core/models/wire_enums.dart' hide Verdict;
import '../../../core/network/relay_client.dart';
import '../../../core/network/sse_parser.dart' show MissingMetaFailure;
import '../../assessment/domain/assessment.dart';
import '../../assessment/domain/assessment_repository.dart';
import '../../cloud_voice/domain/cloud_voice_failure.dart';
import '../../cloud_voice/domain/cloud_voice_repository.dart';
import '../../daily/domain/daily_repository.dart' show NoProblemAvailableException;
import '../../settings/domain/reminder_time.dart';
import '../../settings/domain/settings_repository.dart';
import '../../streak/domain/streak_repository.dart';
import '../../transcript/domain/transcript_repair_repository.dart';
import '../../voice/domain/mic_rationale_repository.dart';
import '../../voice/domain/recognition_availability.dart';
import '../../voice/domain/recognition_event.dart';
import '../../voice/domain/recognition_service.dart';
import '../../voice/domain/spoken_language.dart';
import '../domain/draft.dart';
import '../domain/ended_by.dart';
import '../domain/hint_rung.dart';
import '../domain/message.dart';
import '../domain/server_counters.dart';
import '../domain/session.dart';
import '../domain/session_repository.dart';
import '../domain/turn_event.dart';
import 'daily_session_state.dart';

/// The fixed request text sent for an explicit "ask for the solution"
/// (T110). Not authored copy shown to the learner — it is the learner's
/// own turn, tagged `inputMode: text` like any typed one, and reviewed
/// nowhere because there is nothing here to mishear or misrecognise.
const String _solutionRequestText = 'Please just tell me the solution.';

/// FR-013a's 90-second recording cap for the on-device path. The cloud path
/// uses the per-clip limit `CloudVoiceRepository.nextClipLimit()` returns.
const Duration _recordingCap = Duration(seconds: 90);

/// The warning shows once this much of the active cap is left (15 s of 90 s
/// on-device, 15 s of the clip limit in the cloud).
const Duration _recordingWarningBefore = Duration(seconds: 15);

/// `Turn.text`'s wire ceiling (data-model.md §4). A turn over this is
/// trimmed at a sentence boundary rather than sent to be refused as
/// `BAD_REQUEST` (spec edge case: a very long spoken turn).
const int _maxTurnChars = 8000;

/// Rolling sample count the waveform renders from.
const int _maxLevelSamples = 40;

/// Orchestrates open → record → recognise → review → send → stream for
/// today's session (T067). Every dependency is a domain interface, so a
/// plain fake — no `sl<T>()`, no locator setup — is enough to drive this
/// in `bloc_test`.
class DailySessionCubit extends Cubit<DailySessionState> {
  DailySessionCubit({
    required SessionRepository sessionRepository,
    required AssessmentRepository assessmentRepository,
    required StreakRepository streakRepository,
    required RecognitionService recognitionService,
    required RemoteConfigRepository configRepository,
    required MicRationaleRepository micRationaleRepository,
    SettingsRepository? settingsRepository,
    TranscriptRepairRepository? transcriptRepairRepository,
    CloudVoiceRepository? cloudVoiceRepository,
  })  : _sessionRepository = sessionRepository,
        _assessmentRepository = assessmentRepository,
        _streakRepository = streakRepository,
        _recognitionService = recognitionService,
        _configRepository = configRepository,
        _micRationaleRepository = micRationaleRepository,
        _settingsRepository = settingsRepository,
        _transcriptRepairRepository = transcriptRepairRepository,
        _cloudVoiceRepository = cloudVoiceRepository,
        super(const DailySessionState.opening());

  final SessionRepository _sessionRepository;
  final AssessmentRepository _assessmentRepository;
  final StreakRepository _streakRepository;
  final RecognitionService _recognitionService;
  final RemoteConfigRepository _configRepository;
  final MicRationaleRepository _micRationaleRepository;

  /// Nullable so every existing test construction of this Cubit — none of
  /// which cares about the reminder — keeps compiling unchanged. `null`
  /// in production is not a real state: `main()`'s composition root
  /// always supplies one.
  final SettingsRepository? _settingsRepository;

  /// Nullable for the same reason as [_settingsRepository] above — every existing test construction keeps
  /// compiling, and `null` in production never happens (`main()`'s
  /// composition root always supplies one). `null` here means repair is
  /// off: [_openReviewWithRepair] opens the review step with the raw
  /// transcript immediately.
  final TranscriptRepairRepository? _transcriptRepairRepository;

  /// Nullable for the same reason as [_transcriptRepairRepository]: every
  /// existing test construction keeps compiling, and `null` in production
  /// never happens (`main()`'s composition root always supplies one). `null`
  /// here means cloud voice is off: every recording uses the on-device
  /// recogniser.
  final CloudVoiceRepository? _cloudVoiceRepository;

  /// True from the start of a cloud recording until the next recording
  /// starts; routes [stopRecording] and [cancelRecording] to the cloud
  /// repository instead of the platform recogniser.
  bool _cloudActive = false;

  /// Set when the cloud stream delivers its one terminal event, or when the
  /// learner cancels, so the stream closing afterwards is not mistaken for an
  /// interruption ("nothing heard").
  bool _cloudTerminalSeen = false;

  /// The cap the current recording runs to: [_recordingCap] on-device, the
  /// clip limit in the cloud.
  Duration _activeCap = _recordingCap;

  StreamSubscription<RecognitionEvent>? _recognitionSub;
  Timer? _recordingTicker;
  final Stopwatch _recordingStopwatch = Stopwatch();
  String? _pendingSendText;
  InputMode? _pendingSendMode;

  /// The session whose finish offer the learner turned down with Keep
  /// going (feature 005). Holds for the rest of that session only, and is
  /// sent with every later turn so the relay stops running the check.
  String? _finishOfferDismissedFor;

  Timer? _draftSaveDebounce;
  Timer? _rateLimitRetryTimer;

  /// Runtime config if the repository has it, `null` if it does not — and a
  /// repair kicked off in the background when it does not.
  ///
  /// This used to be `cached()!`, and that `!` was a live crash. The launch
  /// path can legitimately reach a session with the in-memory cache empty:
  /// `main()` hydrates from Drift and only refreshes over the network **if
  /// that hydrate returned something**, so a learner whose cached config row
  /// is missing or unparseable — while problems are still cached, which is
  /// what lets `seedGuard` wave them through — runs the whole process with
  /// nothing in the cache and nothing ever calling `load()`. The tap on Send
  /// then threw before any network call and the button looked dead, with no
  /// error anywhere on screen (found on hardware 2026-09-16).
  ///
  /// Callers must treat `null` as "no local opinion" and let the relay be the
  /// authority, per Constitution X.6's rule about never denying content.
  RuntimeConfig? get _configOrNull {
    final RuntimeConfig? cached = _configRepository.cached();
    if (cached == null) {
      unawaited(_repairConfigCache());
    }
    return cached;
  }

  bool _repairingConfig = false;

  /// One in-flight attempt at a time. Failure is silent by design: this runs
  /// beside a learner's tap, and a config fetch is never allowed to become
  /// something they have to wait for or read about.
  Future<void> _repairConfigCache() async {
    if (_repairingConfig) {
      return;
    }
    _repairingConfig = true;
    try {
      await _configRepository.load();
    } catch (_) {
      // FR-046 fail open — see the getter's doc.
    } finally {
      _repairingConfig = false;
    }
  }

  /// The rendered conversation, for `message_list.dart`. A thin pass
  /// through to the repository — the widget already holds this Cubit, so
  /// it reaches for the conversation through it rather than resolving
  /// `SessionRepository` for itself.
  Stream<List<Message>> watchMessages(String sessionId) => _sessionRepository.watchMessages(sessionId);

  /// Opens or resumes today's session and restores the unsent draft, if
  /// any (FR-016, FR-024). Called once, from `BlocProvider(create:)` —
  /// `sl<T>()` for the repositories this Cubit depends on is resolved
  /// there, not here (`no_service_locator_outside_root`).
  Future<void> open({String? problemId}) async {
    final Session session;
    try {
      session = await _sessionRepository.openOrResumeToday(problemId: problemId);
    } on NoProblemAvailableException {
      emit(const DailySessionState.problemUnavailable());
      return;
    }
    emit(DailySessionState.reading(session));

    // A session that is already over must never reopen as a live one.
    // Resuming today after finishing put the composer, the mic, the
    // finish nudge and the app bar's Finish action all back on screen for
    // a session the relay would refuse every one of them for — the
    // learner could tap all four and get nothing (found on a physical
    // device, 2026-09-04). `openOrResumeToday()` resumes the row as it
    // stands; what was missing was reading the status it came back with.
    if (session.status != SessionStatus.chatting) {
      final Assessment? assessment = await _assessmentRepository.forSession(session.id);
      if (assessment != null) {
        emit(DailySessionState.verdict(session, assessment));
        return;
      }
      // Closed, judged or not — `pendingJudge` with nothing stored means
      // the judge request never landed, and `SessionClosed` is the state
      // whose one affordance is going after it.
      emit(DailySessionState.sessionClosed(session));
      return;
    }

    final Draft? draft = await _sessionRepository.loadDraft(session);
    emit(DailySessionState.composing(session, draft));
  }

  /// Whether `/session/mic-rationale` (prototype screen 9) still needs to
  /// be shown before the first recording attempt this install has ever
  /// made — checked by the composer's mic tap, never at launch (FR-014).
  Future<bool> shouldShowMicRationale() async => !await _micRationaleRepository.hasBeenShown();

  /// Records that the mic rationale has now been seen, so it never shows
  /// again on this install.
  Future<void> confirmMicRationaleSeen() => _micRationaleRepository.markShown();

  /// FR-011a's keyboard interim: leaves [RecognitionUnavailable] for the
  /// ordinary composer, where "or type instead" is already reachable.
  void dismissRecognitionUnavailable() {
    final DailySessionState current = state;
    if (current is! RecognitionUnavailable) {
      return;
    }
    emit(DailySessionState.composing(current.session, null));
  }

  /// Starts a listen session. Emits [RecognitionUnavailable] rather than
  /// recording when the platform cannot support it (FR-011a).
  Future<void> startRecording() async {
    final Session session = _currentSession;
    // The cloud engine is chosen first. It is not subject to the platform
    // recogniser's availability, which is deliberately skipped for it.
    final Duration? cloudLimit = await _cloudVoiceRepository?.nextClipLimit();
    if (cloudLimit != null) {
      await _startCloudRecording(session, cloudLimit);
      return;
    }
    _cloudActive = false;
    _activeCap = _recordingCap;
    final RecognitionAvailability availability = await _recognitionService.availability();
    if (availability != RecognitionAvailability.available) {
      emit(DailySessionState.recognitionUnavailable(session, availability));
      return;
    }

    _recordingStopwatch
      ..reset()
      ..start();
    emit(
      DailySessionState.recording(
        session: session,
        elapsed: Duration.zero,
        levels: const <double>[],
        warned: false,
      ),
    );
    _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) => _onRecordingTick());
    await _recognitionSub?.cancel();
    _recognitionSub = _recognitionService.listen().listen(
      _onRecognitionEvent,
      onDone: () => _onRecognitionInterrupted(session),
    );
  }

  Future<void> _startCloudRecording(Session session, Duration limit) async {
    final CloudVoiceRepository repo = _cloudVoiceRepository!;
    await _recognitionSub?.cancel();
    _cloudActive = true;
    _cloudTerminalSeen = false;
    _activeCap = limit;
    _recordingStopwatch
      ..reset()
      ..start();
    emit(
      DailySessionState.recording(
        session: session,
        elapsed: Duration.zero,
        levels: const <double>[],
        warned: false,
        limit: limit,
      ),
    );
    _recordingTicker = Timer.periodic(const Duration(milliseconds: 200), (_) => _onRecordingTick());
    _recognitionSub = repo.record(limit: limit).listen(
      (RecognitionEvent event) {
        if (event is FinalTextEvent || event is RecognitionErrorEvent) {
          _cloudTerminalSeen = true;
        }
        _onRecognitionEvent(event);
      },
      // After a terminal event the stream closes on its own; only a stream
      // that closes with nothing at all is an interruption.
      onDone: () {
        if (!_cloudTerminalSeen) {
          _onRecognitionInterrupted(session);
        }
      },
    );
  }

  /// FR-011b's language picker. The platform recogniser takes one
  /// language per session — there is no auto-detection to fall back on —
  /// so these three exist purely to let the learner say which one.
  Future<List<SpokenLanguage>> spokenLanguages() => _recognitionService.supportedLanguages();

  Future<SpokenLanguage?> currentSpokenLanguage() => _recognitionService.currentLanguage();

  Future<void> setSpokenLanguage(String localeId) => _recognitionService.setLanguage(localeId);

  /// Ends the listen session normally, causing a final transcript. On the
  /// cloud path this also starts the upload, so the footer switches to
  /// "Transcribing..." straight away.
  Future<void> stopRecording() async {
    if (_cloudActive) {
      _stopRecordingTicker();
      emit(DailySessionState.recognising(_currentSession));
      await _cloudVoiceRepository!.stop();
      return;
    }
    await _recognitionService.stop();
  }

  /// Abandons the listen session with no final transcript — the mic
  /// permission-revoked and app-backgrounded interruption paths route
  /// here via [_onRecognitionInterrupted], never through a lost draft.
  Future<void> cancelRecording() async {
    if (_cloudActive) {
      // The repository closes its stream with no terminal event on cancel;
      // that must not read as "nothing heard".
      _cloudTerminalSeen = true;
      await _cloudVoiceRepository!.cancel();
    } else {
      await _recognitionService.cancel();
    }
    _stopRecordingTicker();
    emit(DailySessionState.composing(_currentSession, null));
  }

  /// Every edit updates the visible state immediately; the Drift write
  /// itself is debounced (FR-016) so a fast typist or a stream of
  /// `onChanged` calls does not turn into a write per keystroke.
  void updateDraftText(String text) {
    final DailySessionState current = state;
    if (current is! ReviewingTranscript) {
      return;
    }
    final Draft updated = current.draft.copyWith(text: text);
    emit(DailySessionState.reviewingTranscript(current.session, updated));
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_sessionRepository.saveDraft(current.session, updated));
    });
  }

  /// A tap-to-fix glossary chip replaced part of the draft (FR-012a).
  void applyGlossaryChipEdit(String updatedText) {
    updateDraftText(updatedText);
  }

  /// The typed path's peer of [reRecord]: keeps the review step mandatory
  /// (Principle V) but returns to the composer rather than opening the
  /// microphone, which is not what a turn the learner typed asked for.
  /// The draft row is left in place so FR-016/FR-024 still restore it.
  void discardDraft() {
    final DailySessionState current = state;
    if (current is! ReviewingTranscript) {
      return;
    }
    emit(DailySessionState.composing(current.session, current.draft));
  }

  /// Re-record is a peer of send, not a fallback (FR-012b): abandons the
  /// current draft and returns straight to recording.
  Future<void> reRecord() async {
    final DailySessionState current = state;
    if (current is! ReviewingTranscript) {
      return;
    }
    await _sessionRepository.deleteDraft(current.session);
    await startRecording();
  }

  /// FR-005, US2. Restores the unmodified recogniser output. `recognised` is
  /// never overwritten, so this is always exactly what was heard.
  void revertRepair() {
    final DailySessionState current = state;
    if (current is! ReviewingTranscript) return;
    final String? recognised = current.draft.recognised;
    if (recognised == null) return;
    final Draft reverted = current.draft.copyWith(text: recognised);
    emit(DailySessionState.reviewingTranscript(current.session, reverted));
    unawaited(_sessionRepository.saveDraft(current.session, reverted));
  }

  /// Sends the reviewed draft. Reachable **only** from
  /// [ReviewingTranscript] — Principle V's mandatory-review guarantee is
  /// that there is no other call path to this method that matters, since
  /// every caller is a widget built from that one state.
  Future<void> send() async {
    final DailySessionState current = state;
    if (current is! ReviewingTranscript) {
      return;
    }
    await _sendDraft(current.session, current.draft);
  }

  /// One tap from the keyboard composer. Principle V's review exists
  /// because speech-to-text mangles jargon; a typed turn was written and
  /// seen in the field itself, so a second screen showing the same text
  /// back was a tap that bought nothing. Everything [send] enforces still
  /// applies: an over-long turn is trimmed and shown back for a fresh
  /// confirm, and a too-short one is declined locally.
  Future<void> sendTyped(String text) async {
    final DailySessionState current = state;
    if (current is! Composing && current is! WrappingUp && current is! FinishOffered) {
      return;
    }
    await _sendDraft(_currentSession, Draft(text: text, inputMode: InputMode.text));
  }

  Future<void> _sendDraft(Session session, Draft draft) async {
    final String rawText = draft.text.trim();

    if (rawText.length > _maxTurnChars) {
      // Trimmed and shown back for a fresh confirm, rather than sent
      // straight through — nothing skips review, including an app-driven
      // edit (spec edge case: a very long spoken turn).
      final String trimmed = _trimAtSentenceBoundary(rawText, _maxTurnChars);
      final Draft trimmedDraft = draft.copyWith(text: trimmed);
      await _sessionRepository.saveDraft(session, trimmedDraft);
      emit(DailySessionState.reviewingTranscript(session, trimmedDraft));
      return;
    }

    final RuntimeConfig? config = _configOrNull;
    if (config != null && rawText.length < config.chat.minTurnChars) {
      // US1 scenario 7: declined locally with EMPTY_TURN's own copy,
      // no turn consumed — nothing was ever sent to the relay.
      emit(DailySessionState.failure(session, const RelayError.emptyTurn()));
      return;
    }
    // With no config, the check is skipped rather than guessed at: the relay
    // enforces `min_turn_chars` itself and answers EMPTY_TURN, which
    // `relay_error_mapper.dart` already maps to the same copy and which
    // spends no turn either. A short turn making one round trip is a far
    // better failure than a Send button that does nothing.

    final InputMode mode = draft.inputMode;
    await _sessionRepository.deleteDraft(session);
    _pendingSendText = rawText;
    _pendingSendMode = mode;
    emit(DailySessionState.sending(session, rawText));
    await _runSend(session, rawText, mode);
  }

  /// FR-042's retryable bubble, made actually tappable.
  ///
  /// "Not sent — tap to retry" was rendered as plain text under a failed
  /// turn and nothing was listening: the label described an affordance the
  /// app did not have. A transport failure is queued and drains on the
  /// next connectivity change, but every other failure parked the row
  /// forever with no way for the learner to try again (found on a physical
  /// device, 2026-09-04).
  ///
  /// Resends the words already in the conversation, reusing that row
  /// rather than appending a second copy of them.
  Future<void> retryFailedTurn(Message message) async {
    final Session session = _currentSession;
    final InputMode mode = message.inputMode ?? InputMode.text;
    _pendingSendText = message.text;
    _pendingSendMode = mode;
    emit(DailySessionState.sending(session, message.text));
    await _runSend(session, message.text, mode, retryMessageId: message.id);
  }

  /// `Failure`'s next action. A transport/relay failure resends the same
  /// text; a client-side decline (`EmptyTurn`) has nothing to resend and
  /// returns the learner to the composer to re-record or type instead —
  /// exactly `ErrorNextAction.reRecordOrType`'s meaning. A session already
  /// closed (`status: pendingJudge`, no pending turn) failed while
  /// pursuing its assessment instead — that retry (T105) re-requests the
  /// judge rather than resending a turn, and must not report the session
  /// as already assessed just because a first attempt didn't reach it.
  Future<void> retry() async {
    final DailySessionState current = state;
    if (current is! Failure) {
      return;
    }
    // A manual tap and the rate-limit timer must never both fire.
    _rateLimitRetryTimer?.cancel();
    final String? text = _pendingSendText;
    final InputMode? mode = _pendingSendMode;
    if (text != null && mode != null) {
      // Reuse the row the failed turn is already sitting in. Without this
      // the banner's "Try again" minted a fresh message id, so a
      // successful retry appended a second identical bubble and left the
      // first one reading "Not sent — tap to retry" forever — the learner
      // saw their own turn twice, one of them still marked failed (found
      // on a physical device). `retryFailedTurn` had this right; this path
      // did not.
      final String? failedId = await _failedTurnId(current.session, text);
      emit(DailySessionState.sending(current.session, text));
      await _runSend(current.session, text, mode, retryMessageId: failedId);
      return;
    }
    if (current.session.status == SessionStatus.pendingJudge) {
      await _pursueAssessment(current.session);
      return;
    }
    emit(DailySessionState.composing(current.session, null));
  }

  /// The FR-007a/b handover: `SessionRepository.promoteToKeyed` is one
  /// `UPDATE` on the same row, so the conversation continuing is a
  /// property of Drift, not of this Cubit — what this method owns is
  /// resuming the state machine on the raised allowance. A turn that
  /// failed on `InvalidKey`/`TrialConsumed`/`TrialUnavailable` is
  /// resent automatically once the new key is in place, because the
  /// learner already asked to send it once; a promotion from
  /// `CapReached` (the taster ran out) has no pending turn to resend and
  /// simply returns to an ordinary composer with more room.
  Future<void> promoteToKeyed(String providerId) async {
    final Session updated = await _sessionRepository.promoteToKeyed(_currentSession, providerId);
    final String? text = _pendingSendText;
    final InputMode? mode = _pendingSendMode;
    if (text != null && mode != null) {
      // Same reason as `retry()`: resend into the row that failed, or the
      // learner sees their turn twice, the first copy still "Not sent"
      // (found on a physical device, 2026-09-25, after saving a key).
      final String? failedId = await _failedTurnId(updated, text);
      emit(DailySessionState.sending(updated, text));
      await _runSend(updated, text, mode, retryMessageId: failedId);
      return;
    }
    emit(DailySessionState.composing(updated, null));
  }

  /// Pulls the next authored rung (FR-025). An **explicit control**,
  /// distinct from asking for a hint inside the conversation — reachable
  /// from [Composing], [WrappingUp], and [CapReached] (FR-028: the cap
  /// bounds conversation, not hints), and reattached to whichever of those
  /// the learner was in rather than forcing a return to [Composing].
  /// `turnIndex` never moves (FR-019, research.md R-007), so pulling a
  /// hint before a fresh install's first turn does not consume the taster.
  Future<void> pullHint() async {
    final DailySessionState before = state;
    final Session session = _currentSession;

    // The rung is on the wire, so it gets the same dots a turn gets.
    emit(DailySessionState.pullingHint(session));

    final Result<HintRung> result = await _sessionRepository.pullHint(session);
    switch (result) {
      case Ok<HintRung>():
        final Session refreshed = await _sessionRepository.watch(session.id).first;
        emit(_reattachSession(before, refreshed));
      case Err<HintRung>(error: final SessionAlreadyJudged _):
        // FR-034 scenario 4, same as a stray turn: told the session is
        // closed rather than shown a bare failure.
        emit(DailySessionState.sessionClosed(session));
      case Err<HintRung>(:final error):
        emit(DailySessionState.failure(session, error));
    }
  }

  /// Reveals the next authored worked example into the conversation
  /// (the peer of [pullHint]).
  ///
  /// The statement is deliberately prose — it is meant to be spoken
  /// through — which left a learner with no concrete input to picture, and
  /// a first turn that was a guess about what was even being asked. This
  /// costs no turn and no allowance for the same reason a hint does not:
  /// it never reaches the relay at all.
  Future<void> pullExample() async {
    final DailySessionState before = state;
    final Session session = _currentSession;
    if (await _sessionRepository.revealNextExample(session) == null) {
      return;
    }
    // No analytics event: `contracts/analytics-events.md` is a closed
    // list and `analytics_contract_test` enforces it, so inventing one
    // here would be a contract change, not a feature.
    //
    // Nothing about the session changed — the message stream is what
    // paints the reveal — but the state is re-emitted so the control can
    // disable itself once the last example is out.
    emit(_reattachSession(before, session));
  }

  /// The learner closing the session themselves, e.g. from [CapReached]
  /// (FR-023) — the cap bounds conversation, not the learner's ability to
  /// end it. `endedByFromSessionEnded` reads the reason off the session's
  /// own last-known truth rather than assuming voluntary: a cap-ended
  /// session closed from here is still `ended_by: cap` on the wire
  /// (T111), and only a session with no server opinion at all defaults to
  /// [EndedBy.user]. Credits the streak transactionally inside
  /// `SessionRepository.endSession`, before any judge request exists
  /// (FR-036, Principle IV), then pursues the one assessment the session
  /// gets.
  Future<void> endSessionUser() async {
    // Reachable from the ordinary composer and the wrap-up, not only from
    // the cap. Guarding this to `CapReached` was the *only* call path, so
    // a learner who had worked the problem out in two turns could not ask
    // for their assessment without first spending every remaining turn —
    // US4 scenario 1 and FR-023 both unreachable in practice (found on a
    // physical device). The cap bounds the conversation; it was never
    // meant to be the only door out of it.
    final Session? session = switch (state) {
      Composing(:final Session session) => session,
      WrappingUp(:final Session session) => session,
      FinishOffered(:final Session session) => session,
      CapReached(:final Session session) => session,
      _ => null,
    };
    if (session == null || session.counters.turnIndex < 1) {
      // Nothing has been said yet, so there is nothing to assess. The
      // screen does not offer the control in that case either.
      return;
    }
    final EndedBy reason = endedByFromSessionEnded(session.counters.sessionEnded);
    final Session updated = await _sessionRepository.endSession(session, reason);
    // FR-048b: the reminder exists to prompt an unstarted day, not to nag
    // someone who already finished it.
    await _settingsRepository?.cancelTodaysReminder();
    // `SessionRepositoryImpl.endSession` already credited the streak
    // transactionally, before this call returned (FR-036, Principle IV).
    await _pursueAssessment(updated);
  }

  /// The explicit "ask for the solution" control (T110). The **first**
  /// ask is an ordinary turn — nothing warns or blocks it, because
  /// nothing is released yet (`releaseSolution()` needs a *second* ask,
  /// `worker/src/lib/turn-cap.ts`). A **second** ask is not sendable from
  /// here at all: FR-021 requires the warning appear *before* that
  /// request is sent, so this routes to [ConfirmSolutionRelease] instead
  /// of sending, and only [confirmSolutionRelease] — reachable from that
  /// one state — actually sends it.
  Future<void> requestSolution() async {
    final Session session = _currentSession;
    if (session.solutionRequestCount >= 1) {
      emit(DailySessionState.confirmSolutionRelease(session));
      return;
    }
    await _sendSolutionRequest(session);
  }

  /// The only call path that can send a second solution request — FR-021's
  /// warning is unskippable because [ConfirmSolutionRelease] is the only
  /// state this method does anything from.
  Future<void> confirmSolutionRelease() async {
    final DailySessionState current = state;
    if (current is! ConfirmSolutionRelease) {
      return;
    }
    await _sendSolutionRequest(current.session);
  }

  /// Backs out of [ConfirmSolutionRelease] without sending anything.
  void cancelSolutionRelease() {
    final DailySessionState current = state;
    if (current is! ConfirmSolutionRelease) {
      return;
    }
    emit(DailySessionState.composing(current.session, null));
  }

  Future<void> _sendSolutionRequest(Session session) async {
    emit(DailySessionState.sending(session, _solutionRequestText));
    await _runSend(
      session,
      _solutionRequestText,
      InputMode.text,
      solutionRequestCount: session.solutionRequestCount + 1,
    );
  }

  /// The streak the share card prints. Read on demand rather than carried
  /// in state: it changes once a day, at `endSession`, and every reader of
  /// it is a screen that has just been opened.
  Future<int> currentStreakLength() async => (await _streakRepository.current()).currentLength;

  /// Whether the Verdict screen should ask for notifications. True once
  /// per install, and only while they are blocked.
  Future<bool> takeNotificationNudge() async => await _settingsRepository?.takeNotificationNudge() ?? false;

  /// The nudge's accept. Arms the default reminder when none is set, so a
  /// grant has something to deliver, and asks for the permission. Android
  /// shows no dialog once it has been refused, so that case falls through
  /// to its settings page.
  Future<void> enableDailyReminder() async {
    final SettingsRepository? settings = _settingsRepository;
    if (settings == null) {
      return;
    }
    final bool allowed;
    if (await settings.reminderTime() == null) {
      allowed = await settings.setReminderTime(ReminderTime.defaultTime);
      // Today's session is already done (FR-048b), so the first one is
      // tomorrow's even when the default time is still ahead today.
      await settings.cancelTodaysReminder();
    } else {
      allowed = await settings.requestNotificationPermission();
    }
    if (!allowed) {
      await settings.openNotificationSettings();
    }
  }

  /// The Verdict screen's "read the editorial" tap — no network call, the
  /// assessment is already in hand (data-model.md §5: `editorial` is the
  /// only private content the app ever holds).
  void revealAssessment() {
    final DailySessionState current = state;
    if (current is! Verdict) {
      return;
    }
    emit(DailySessionState.revealed(current.session, current.assessment));
  }

  /// Back out of the editorial to the verdict it was opened from. The
  /// assessment screens are reached with `go`, not `push` — there is no
  /// stack under them to pop, so system back closed the app instead of
  /// going anywhere (found on a physical device). Moving the state back
  /// is what moves the route back, since `DailySessionShell._routeFor`
  /// owns navigation for this flow.
  void hideEditorial() {
    final DailySessionState current = state;
    if (current is! Revealed) {
      return;
    }
    emit(DailySessionState.verdict(current.session, current.assessment));
  }

  /// Resets the judged session on the relay and removes its local transcript.
  /// The current verdict remains visible when reset fails so the learner does
  /// not lose the assessment they already received.
  Future<Result<void>> practiceAgain() async {
    final DailySessionState current = state;
    final Session? session = switch (current) {
      Reading(:final session) => session,
      Composing(:final session) => session,
      Recording(:final session) => session,
      Recognising(:final session) => session,
      VoiceUploadFailed(:final session) => session,
      ReviewingTranscript(:final session) => session,
      Sending(:final session) => session,
      Streaming(:final session) => session,
      WrappingUp(:final session) => session,
      FinishOffered(:final session) => session,
      PullingHint(:final session) => session,
      CapReached(:final session) => session,
      ConfirmSolutionRelease(:final session) => session,
      Judging(:final session) => session,
      Verdict(:final session) => session,
      Revealed(:final session) => session,
      SessionClosed(:final session) => session,
      Failure(:final session) => session,
      Opening() || ProblemUnavailable() => null,
      RecognitionUnavailable(:final session) => session,
    };
    if (session == null) {
      return const Err(RelayError.transport());
    }
    final Result<void> result = await _sessionRepository.resetForPracticeAgain(session);
    if (result case Ok<void>()) {
      emit(const DailySessionState.opening());
      await open(problemId: session.problem.id);
    }
    return result;
  }

  /// FR-031: local only, no upload, no consent prompt (FR-031b forbids
  /// asking for consent the app will not act on). Reachable from either
  /// [Verdict] or [Revealed] — dispute must be one tap away on every
  /// assessment screen, not only the first one shown (FR-031, Principle IV).
  Future<void> disputeAssessment() async {
    final DailySessionState current = state;
    if (current is! Verdict && current is! Revealed) {
      return;
    }
    final Session session = current is Verdict ? current.session : (current as Revealed).session;
    final Assessment assessment = current is Verdict ? current.assessment : (current as Revealed).assessment;

    await _assessmentRepository.recordDispute(session.id);
    final Session disputed = session.copyWith(disputed: true);
    emit(
      current is Revealed
          ? DailySessionState.revealed(disputed, assessment)
          : DailySessionState.verdict(disputed, assessment),
    );
  }

  /// [SessionClosed]'s one affordance: this install already holds the
  /// verdict for a session a stray turn or hint just found closed
  /// (FR-034 scenario 4) — show it rather than leave the learner at a
  /// dead end.
  Future<void> openClosedAssessment() async {
    final DailySessionState current = state;
    if (current is! SessionClosed) {
      return;
    }
    final Assessment? assessment = await _assessmentRepository.forSession(current.session.id);
    if (assessment == null) {
      // Closed with nothing stored means the judge request never landed —
      // going after it is the only thing this button could usefully do,
      // and returning silently made it a dead control.
      await _pursueAssessment(current.session);
      return;
    }
    emit(DailySessionState.verdict(current.session, assessment));
  }

  Future<void> _pursueAssessment(Session session) async {
    emit(DailySessionState.judging(session));
    final Result<Assessment> result = await _assessmentRepository.request(session);
    switch (result) {
      case Ok<Assessment>(:final value):
        emit(DailySessionState.verdict(session, value));
      case Err<Assessment>(:final error):
        emit(DailySessionState.failure(session, error));
        if (error case RateLimited(:final retryAfter)) {
          _scheduleRateLimitRetry(retryAfter);
        }
    }
  }

  /// Reattaches a freshly-read [Session] to whichever of [Composing],
  /// [WrappingUp], or [CapReached] the learner was in before a hint pull —
  /// pulling a hint changes only the session's counters, never which of
  /// those three the learner was looking at.
  DailySessionState _reattachSession(DailySessionState previous, Session session) => switch (previous) {
        Composing(:final draft) => DailySessionState.composing(session, draft),
        WrappingUp() => DailySessionState.wrappingUp(session),
        FinishOffered() => DailySessionState.finishOffered(session),
        CapReached() => DailySessionState.capReached(session),
        _ => DailySessionState.composing(session, null),
      };

  /// Finish on the finish-offer card (feature 005): the same end as the
  /// app-bar control, with the offer credited in analytics.
  Future<void> acceptFinishOffer() async {
    final DailySessionState current = state;
    if (current is! FinishOffered) {
      return;
    }
    await endSessionUser();
  }

  /// Keep going on the finish-offer card. Hides the offer for the rest of
  /// this session and returns to wherever the turn count puts the learner.
  void dismissFinishOffer() {
    final DailySessionState current = state;
    if (current is! FinishOffered) {
      return;
    }
    final Session session = current.session;
    _finishOfferDismissedFor = session.id;
    final RuntimeConfig? config = _configOrNull;
    emit(
      config != null && session.counters.turnIndex >= config.chat.wrapUpAtTurn
          ? DailySessionState.wrappingUp(session)
          : DailySessionState.composing(session, null),
    );
  }

  /// D2: re-sends the clip a transient failure kept, without making the
  /// learner speak again. A second transient failure lands back in
  /// [VoiceUploadFailed], so Try again can be tapped any number of times.
  Future<void> retryVoiceUpload() async {
    final DailySessionState current = state;
    final CloudVoiceRepository? repo = _cloudVoiceRepository;
    if (current is! VoiceUploadFailed || repo == null) {
      return;
    }
    emit(DailySessionState.recognising(current.session));
    final RecognitionEvent event = await repo.retryUpload();
    if (isClosed) {
      return;
    }
    _onRecognitionEvent(event);
  }

  /// D2: gives up on the kept clip and returns to the composer.
  Future<void> discardVoiceClip() async {
    final DailySessionState current = state;
    final CloudVoiceRepository? repo = _cloudVoiceRepository;
    if (current is! VoiceUploadFailed || repo == null) {
      return;
    }
    await repo.discardPending();
    if (isClosed) {
      return;
    }
    emit(DailySessionState.composing(current.session, null, null));
  }

  @override
  Future<void> close() {
    _recognitionSub?.cancel();
    // Leaving the session deletes a recording in progress or a held clip.
    if (_cloudActive || _cloudVoiceRepository?.hasPendingClip == true) {
      unawaited(_cloudVoiceRepository?.cancel());
    }
    _stopRecordingTicker();
    _draftSaveDebounce?.cancel();
    _rateLimitRetryTimer?.cancel();
    return super.close();
  }

  // --- internals ---------------------------------------------------

  Session get _currentSession => switch (state) {
        Opening() => throw StateError('DailySessionCubit used before open() resolved'),
        ProblemUnavailable() => throw StateError('DailySessionCubit has no session: no problem available'),
        Reading(:final session) => session,
        Composing(:final session) => session,
        Recording(:final session) => session,
        Recognising(:final session) => session,
        VoiceUploadFailed(:final session) => session,
        ReviewingTranscript(:final session) => session,
        Sending(:final session) => session,
        Streaming(:final session) => session,
        PullingHint(:final session) => session,
        WrappingUp(:final session) => session,
        FinishOffered(:final session) => session,
        CapReached(:final session) => session,
        ConfirmSolutionRelease(:final session) => session,
        Judging(:final session) => session,
        Verdict(:final session) => session,
        Revealed(:final session) => session,
        SessionClosed(:final session) => session,
        Failure(:final session) => session,
        RecognitionUnavailable(:final session) => session,
      };

  /// The id of the learner row this failure parked, so a retry moves that
  /// row rather than appending a copy of it. Falls back to `null` — a
  /// fresh insert, the old behaviour — if the row cannot be identified,
  /// which is better than resending nothing.
  Future<String?> _failedTurnId(Session session, String text) async {
    try {
      final List<Message> messages =
          await _sessionRepository.watchMessages(session.id).first;
      for (final Message m in messages.reversed) {
        if (m.role == TurnRole.user &&
            m.delivery == Delivery.failedRetryable &&
            m.text == text) {
          return m.id;
        }
      }
    } catch (_) {
      // A repository that cannot enumerate messages must not stop a retry.
    }
    return null;
  }

  Future<void> _runSend(
    Session session,
    String text,
    InputMode mode, {
    int? solutionRequestCount,
    String? retryMessageId,
  }) async {
    String partial = '';
    try {
      await for (final TurnEvent event in _sessionRepository.sendTurn(
        session,
        text,
        mode,
        solutionRequestCount: solutionRequestCount,
        retryMessageId: retryMessageId,
        finishOfferDismissed: _finishOfferDismissedFor == session.id,
      )) {
        switch (event) {
          case TurnEventToken(:final text):
            partial += text;
            emit(DailySessionState.streaming(session, partial));
          case TurnEventMeta(:final counters):
            _onTurnMeta(session: session, counters: counters);
        }
      }
    } on MissingMetaFailure {
      emit(DailySessionState.failure(session, const RelayError.unclearRetry()));
    } on RelayException catch (e) {
      if (e.error is SessionAlreadyJudged) {
        // FR-034 scenario 4: a turn or hint landed after the verdict was
        // already delivered (a race, or a resumed stale session). Told
        // the session is closed rather than shown a bare failure —
        // distinct from `Failure` because "retry the same text" is not a
        // coherent next action once the session is over.
        emit(DailySessionState.sessionClosed(session));
        return;
      }
      // TRIAL_CONSUMED and TRIAL_UNAVAILABLE are neither an error nor an
      // outage — both route straight into key entry
      // (`DailySessionShell._routeFor`).
      emit(DailySessionState.failure(session, e.error));
      // RATE_LIMITED reads as the conversation catching up, not a
      // failure the learner acts on (FR-045a) — "the same turn resumes
      // automatically once the wait elapses" is `RelayError.rateLimited`'s
      // own contract, so this Cubit is what has to make that literally
      // true rather than leaving an unactionable `Failure` on screen.
      if (e.error case RateLimited(:final retryAfter)) {
        _scheduleRateLimitRetry(retryAfter);
      }
    } catch (_) {
      emit(DailySessionState.failure(session, const RelayError.transport()));
    }
  }

  /// RATE_LIMITED's contract is "the same action resumes by itself once the
  /// wait elapses" (FR-045a). Shared by the turn path and the judge path:
  /// the judge path had no timer at all, so a rate-limited Finish sat on a
  /// failure with no button and nothing pending (found on a physical
  /// device, 2026-10-11).
  void _scheduleRateLimitRetry(Duration retryAfter) {
    _rateLimitRetryTimer?.cancel();
    _rateLimitRetryTimer = Timer(retryAfter, () {
      if (!isClosed) {
        unawaited(retry());
      }
    });
  }

  void _onTurnMeta({
    required Session session,
    required ServerCounters counters,
  }) {
    final Session updated = session.copyWith(counters: counters);
    _pendingSendText = null;
    _pendingSendMode = null;

    // Cap first (an authoritative server signal that this was the
    // terminal turn), then the wrap-up threshold. Because `turnIndex`
    // only ever advances by exactly one accepted turn at a time, and
    // `wrap_up_at_turn < chat.turn_cap` by config convention, every turn
    // strictly between the two thresholds already emitted `WrappingUp`
    // before this one can emit `CapReached` — SC-017's "no learner
    // reaches the cap un-nudged" (T077).
    if (counters.sessionEnded == 'cap') {
      // On the trial path `DailySessionShell._routeFor` sends a
      // `CapReached` to `/keys/wall`, "shown only after a completed
      // session" (FR-005a); this cap *is* that completion.
      emit(DailySessionState.capReached(updated));
      return;
    }
    // The finish offer outranks the wrap-up nudge: both offer Finish, and
    // this one says why (feature 005).
    if (counters.readyToFinish && _finishOfferDismissedFor != session.id) {
      emit(DailySessionState.finishOffered(updated));
      return;
    }
    final RuntimeConfig? config = _configOrNull;
    // No config means no wrap-up nudge for this one turn, not a thrown
    // getter. The cap branch above is relay-driven and still holds, so the
    // learner cannot overrun anything; they simply miss the nudge until the
    // repair above lands.
    if (config != null && counters.turnIndex >= config.chat.wrapUpAtTurn) {
      emit(DailySessionState.wrappingUp(updated));
      return;
    }
    emit(DailySessionState.composing(updated, null));
  }

  void _onRecognitionEvent(RecognitionEvent event) {
    switch (event) {
      case PartialTextEvent(:final text):
        final DailySessionState current = state;
        if (current is Recording) {
          emit(current.copyWith(partialText: text));
        }
      case LevelEvent(:final level):
        final DailySessionState current = state;
        if (current is Recording) {
          final List<double> levels = <double>[...current.levels, level];
          if (levels.length > _maxLevelSamples) {
            levels.removeAt(0);
          }
          emit(current.copyWith(levels: levels));
        }
      case FinalTextEvent(:final text):
        _stopRecordingTicker();
        final Session session = _currentSession;
        if (text.trim().isEmpty) {
          // US1 scenario: an empty recognition result. Nothing was
          // heard, nothing is composed, nothing is sent — the same
          // `err_empty_turn` intent as a too-short typed turn, but there
          // is no draft to review, so this returns straight to
          // composing rather than opening a review step on nothing.
          emit(DailySessionState.composing(session, null));
          return;
        }
        unawaited(_openReviewWithRepair(session, text));
      case RecognitionErrorEvent(:final reason) when reason == CloudVoiceFailure.retryable:
        // D2: the clip is still held; offer Try again instead of a re-record.
        _stopRecordingTicker();
        emit(DailySessionState.voiceUploadFailed(_currentSession));
      case RecognitionErrorEvent(:final reason) when CloudVoiceFailure.isCloud(reason):
        // D4: a rejected clip asks the learner to say it again; a missing
        // permission or an unavailable or exhausted service says the phone's
        // own recognition takes over (the repository now answers on-device).
        _stopRecordingTicker();
        emit(
          DailySessionState.composing(
            _currentSession,
            null,
            reason == CloudVoiceFailure.rejected ? cloudVoiceFailedNotice : cloudVoiceFallbackNotice,
          ),
        );
      case RecognitionErrorEvent() when event.isLanguageUnavailable:
        // FR-011a: the recogniser does not cover the language being
        // spoken. There is no in-app fix, but it has its own screen and
        // must never be reported as "nothing was heard".
        _stopRecordingTicker();
        emit(
          DailySessionState.recognitionUnavailable(
            _currentSession,
            RecognitionAvailability.languageUnavailable,
          ),
        );
      case RecognitionErrorEvent(:final permanent):
        if (permanent) {
          _recoverInterruptedRecording(_currentSession);
        }
      // Transient errors: the listen session continues on its own.
    }
  }

  /// The stream closed with no final result at all — a call, another
  /// app taking the mic, or the OS tearing the session down mid-record.
  /// Nothing was ever composed, so returning to `Composing` loses
  /// nothing (SC-005's "zero recordings and zero composed turns lost").
  void _onRecognitionInterrupted(Session session) {
    final DailySessionState current = state;
    if (current is Recording || current is Recognising) {
      _recoverInterruptedRecording(session);
    }
  }

  /// A listen session ended without a `finalText`: a call took the mic,
  /// the app was backgrounded, or — by far the most common on Android —
  /// the platform's own pause timeout fired while the learner was
  /// thinking. Whatever had already been recognised goes to the review
  /// step exactly as a normal transcript would, so a pause costs a pause
  /// and not the turn (FR-013b, SC-005). Only a session that heard
  /// *nothing* returns to the composer, and it says so rather than
  /// leaving the screen to flash and vanish.
  void _recoverInterruptedRecording(Session session) {
    final DailySessionState current = state;
    final String heard = current is Recording ? current.partialText.trim() : '';
    _stopRecordingTicker();
    if (heard.isEmpty) {
      emit(DailySessionState.composing(session, null, nothingHeardNotice));
      return;
    }
    unawaited(_openReviewWithRepair(session, heard));
  }

  /// plan.md §The hold window. Opens the review step with the repaired
  /// transcript if repair answered inside `repair.timeout_ms`, and with the
  /// raw transcript otherwise. Never throws, never blocks longer than that.
  Future<void> _openReviewWithRepair(Session session, String rawText) async {
    final TranscriptRepairRepository? repo = _transcriptRepairRepository;
    final RepairConfig? repairConfig = _configOrNull?.repair;
    final int denseChars = rawText.replaceAll(RegExp(r'\s'), '').length;
    final bool eligible = repo != null &&
        repairConfig != null &&
        repairConfig.enabled &&
        session.path == SessionPath.keyed &&
        denseChars >= repairConfig.minChars;

    if (!eligible) {
      _emitReview(session, Draft(text: rawText, recognised: rawText, inputMode: InputMode.voice));
      return;
    }

    emit(DailySessionState.recognising(session));
    bool opened = false;
    final Future<String?> pending = repo.repair(session: session, transcript: rawText);
    unawaited(pending.then((String? repaired) {
      if (opened) _applyLateRepair(session, rawText, repaired);
    }));
    final String? inTime = await pending.timeout(
      Duration(milliseconds: repairConfig.timeoutMs),
      onTimeout: () => null,
    );
    opened = true;
    final bool changed = inTime != null && inTime != rawText;
    _emitReview(
      session,
      Draft(
        text: changed ? inTime : rawText,
        recognised: rawText,
        repaired: changed ? inTime : null,
        inputMode: InputMode.voice,
      ),
    );
  }

  /// FR-015. A repair that lands after the review opened is applied ONLY if
  /// this is still the same session's review step and the learner has not
  /// touched the text. Otherwise it is dropped, silently.
  void _applyLateRepair(Session session, String rawText, String? repaired) {
    if (repaired == null || repaired == rawText) return;
    final DailySessionState current = state;
    if (current is! ReviewingTranscript) return;
    if (current.session.id != session.id) return;
    if (current.draft.recognised != rawText) return;
    if (current.draft.text != current.draft.recognised) return;
    _emitReview(
      session,
      Draft(text: repaired, recognised: rawText, repaired: repaired, inputMode: InputMode.voice),
    );
  }

  void _emitReview(Session session, Draft draft) {
    emit(DailySessionState.reviewingTranscript(session, draft));
    unawaited(_sessionRepository.saveDraft(session, draft));
  }

  /// A sentinel the screen resolves against the ARB, so the Cubit stays
  /// free of `AppLocalizations` (which needs a `BuildContext`).
  static const String nothingHeardNotice = 'nothing_heard';

  /// A cloud clip could not be used (rejected): "please say it again".
  static const String cloudVoiceFailedNotice = 'cloud_voice_failed';

  /// A cloud limit was hit (voice off, Groq's limit, the device's seconds
  /// used up, or mic permission missing): "say it again, your phone's
  /// recognition will take it from here".
  static const String cloudVoiceFallbackNotice = 'cloud_voice_fallback';

  void _onRecordingTick() {
    final DailySessionState current = state;
    if (current is! Recording) {
      return;
    }
    final Duration elapsed = _recordingStopwatch.elapsed;
    emit(current.copyWith(elapsed: elapsed, warned: _activeCap - elapsed <= _recordingWarningBefore));
    if (elapsed >= _activeCap) {
      // Emitted first: the cloud stop switches the state to Recognising, and
      // that must not be overwritten by this tick's Recording copy. The state
      // guard above keeps later ticks from stopping a second time.
      unawaited(stopRecording());
    }
  }

  void _stopRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    _recordingStopwatch.stop();
  }

  String _trimAtSentenceBoundary(String text, int maxChars) {
    final String window = text.substring(0, maxChars);
    final int boundary = <int>[
      window.lastIndexOf('. '),
      window.lastIndexOf('! '),
      window.lastIndexOf('? '),
    ].reduce((int a, int b) => a > b ? a : b);
    if (boundary <= 0) {
      return window;
    }
    return window.substring(0, boundary + 1);
  }
}

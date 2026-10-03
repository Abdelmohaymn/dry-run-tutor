import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/errors/error_copy.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/errors/result.dart';
import '../../../core/models/wire_enums.dart';
import '../../../core/text/markdown_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../chat/domain/hint_rung.dart';
import '../../chat/domain/message.dart';
import '../../chat/domain/session.dart';
import '../../chat/domain/session_repository.dart';
import '../../chat/domain/turn_event.dart';
import '../../chat/presentation/widgets/composer.dart';
import '../../chat/presentation/widgets/top_fade.dart';
import '../../chat/presentation/widgets/typing_indicator.dart';
import '../../voice/domain/mic_rationale_repository.dart';
import '../../voice/domain/recognition_availability.dart';
import '../../voice/domain/recognition_event.dart';
import '../../voice/domain/recognition_service.dart';
import '../../voice/presentation/widgets/waveform.dart';
import '../domain/install_repository.dart';

/// `/welcome/practice` — a real run through the daily loop, on a warm-up
/// problem, before today's real one is touched.
///
/// The tutor here is the tutor. It reads what the learner actually said
/// and answers it, because the scripted version could not: it replied by
/// turn number, so a learner who said "sort it and take the last" was
/// told "that is the idea — walk the list once" and then congratulated on
/// an answer they had not given. A walkthrough that agrees with something
/// you did not say teaches less than no walkthrough.
///
/// Its turns come out of the taster, not out of a second allowance
/// (`worker/migrations/0003_practice_turns.sql`): one row per install,
/// `practice_turn_cap` turns for the walkthrough, and the taster itself
/// still unclaimed when the learner arrives at today's problem.
///
/// There is no Finish and no assessment — /v1/trial refuses `mode=judge`
/// for the warm-up. The walkthrough teaches the conversation and stops.
///
/// **The scripted lines survive as the offline fallback.** A first launch
/// with no connection still gets a walkthrough; it just cannot be a
/// conversation. Those lines are written to assert nothing about what the
/// learner said, for the reason above.
///
/// The two replies are chosen by turn number, not by what was said —
/// there is no model here to read it. So neither line may agree with,
/// grade, or restate the learner's answer: an earlier script opened with
/// "that is the idea" and went on to say "once each", which a learner who
/// answered "sort it and take the last" read as the tutor agreeing with an
/// approach they had not described. A scripted reply can only ever be
/// about the *loop* — what gets asked next, and what it costs.
///
/// It speaks, because a walkthrough of a voice-first app that cannot be
/// spoken to teaches the wrong thing — the mic is the product, and a first
/// run that never touches it leaves the one affordance that matters
/// untried. FR-014 still holds: the microphone rationale is shown before
/// the first recording attempt, here as a sheet rather than a screen, and
/// the system permission dialog only ever follows it. Typing stays a peer,
/// for a learner who cannot speak now or at all (FR-053).
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.recognitionService,
    required this.micRationaleRepository,
    required this.installRepository,
    required this.sessionRepository,
    this.onLeave,
    this.typedOnly = false,
    super.key,
  });

  final RecognitionService recognitionService;
  final MicRationaleRepository micRationaleRepository;

  /// Opens and drives the warm-up session. The same repository the real
  /// conversation uses — the walkthrough is not a simulation of the app.
  final SessionRepository sessionRepository;

  /// Only for clearing the practice-pending flag on the way out. The
  /// walkthrough is over once it is left — by either exit — and leaving
  /// the flag set would send the next launch straight back here.
  final InstallRepository installRepository;

  /// Web demo only: replaces the go_router exit. Null in the app.
  final VoidCallback? onLeave;

  /// Web demo only: no mic, the composer is typing only. False in the app.
  final bool typedOnly;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_Line> _lines = <_Line>[];
  bool _thinking = false;
  bool _hintUsed = false;

  StreamSubscription<RecognitionEvent>? _recognitionSub;
  bool _recording = false;

  /// Whether what is sitting in the composer got there from the mic. The
  /// wire wants to know which it was (`InputMode`), and the composer
  /// itself cannot say — the recognised draft is written into the same
  /// field the learner types in, deliberately, because reviewing it there
  /// is the step the walkthrough is teaching.
  bool _draftFromVoice = false;
  bool _recognitionUnavailable = false;
  List<double> _levels = const <double>[];
  String _partial = '';

  /// How many learner turns have landed.
  int _turns = 0;

  /// The live walkthrough runs to the relay's own cap. The offline one
  /// stops at two, because two authored replies is all it has — padding
  /// it out by repeating the last line would teach that the tutor does
  /// not listen, which is the exact impression this screen was changed to
  /// stop giving.
  ///
  /// Never while a reply is still on its way: the count goes up the moment
  /// the learner sends, and closing on that showed the end card over a
  /// last reply that had not arrived yet (or then failed).
  bool get _done => !_inFlight && _turns >= (_session == null ? _scriptedTurns : _practiceTurnCap);

  /// A learner turn has been sent and its reply has not finished.
  bool _inFlight = false;

  /// The live warm-up session, or null when the walkthrough is running on
  /// its offline script — no manifest warm-up, or the open failed.
  Session? _session;

  @override
  void initState() {
    super.initState();
    unawaited(_openSession());
  }

  /// Opens the warm-up session, then puts the opener up. Ordered that way
  /// so the first frame with words on it is already the frame the learner
  /// can answer into — an opener that appears and *then* silently changes
  /// mode reads as a glitch.
  Future<void> _openSession() async {
    Session? session;
    try {
      session = await widget.sessionRepository.openOrResumePractice();
    } catch (_) {
      // Offline, or a relay without the warm-up. The script below is the
      // designed fallback, not an error state — say nothing about it.
    }
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _session = session;
      _turns = session?.counters.turnIndex ?? 0;
      if (_lines.isEmpty) {
        _lines.add(_Line.tutor(l10n.practiceTutorOpener));
      }
    });
  }

  @override
  void dispose() {
    unawaited(_recognitionSub?.cancel());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// FR-014: the rationale precedes the first recording attempt this
  /// install ever makes, and the system dialog only follows it. Shown as a
  /// sheet because this is a walkthrough — a full screen here would be the
  /// interruption the real flow can afford and this one cannot.
  Future<bool> _ensureMicRationale() async {
    if (await widget.micRationaleRepository.hasBeenShown()) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool? proceed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppTokens.surface,
      // Scrollable: the rationale is a paragraph, and on a short screen at
      // a large text size it is taller than the sheet's default height.
      builder: (BuildContext sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.micRationaleTitle, style: context.appTypography.sansHeadline),
            const SizedBox(height: 14),
            Text(l10n.micRationaleBody, style: context.appTypography.sansBody),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(l10n.micRationaleContinue),
              ),
            ),
          ],
        ),
      ),
    );
    if (proceed != true) {
      return false;
    }
    await Permission.microphone.request();
    await widget.micRationaleRepository.markShown();
    return true;
  }

  Future<void> _startRecording() async {
    if (!await _ensureMicRationale()) {
      return;
    }
    final RecognitionAvailability availability = await widget.recognitionService.availability();
    if (!mounted) {
      return;
    }
    if (availability != RecognitionAvailability.available) {
      // FR-011a's condition, in miniature: say so and leave the keyboard,
      // which is already on screen, as the way through.
      setState(() => _recognitionUnavailable = true);
      return;
    }
    setState(() {
      _recording = true;
      _levels = const <double>[];
      _partial = '';
    });
    await _recognitionSub?.cancel();
    _recognitionSub = widget.recognitionService.listen().listen(
      _onRecognitionEvent,
      onDone: _onRecognitionDone,
    );
  }

  void _onRecognitionEvent(RecognitionEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case PartialTextEvent(:final text):
        setState(() => _partial = text);
      case LevelEvent(:final level):
        setState(() {
          final List<double> levels = <double>[..._levels, level];
          if (levels.length > 40) {
            levels.removeAt(0);
          }
          _levels = levels;
        });
      case FinalTextEvent(:final text):
        _finishRecording(text);
      case RecognitionErrorEvent():
        _finishRecording(_partial);
    }
  }

  void _onRecognitionDone() => _finishRecording(_partial);

  /// The recognised words land in the composer rather than being sent, so
  /// the mandatory review step (Principle V) is part of what the
  /// walkthrough teaches rather than something the real loop springs later.
  void _finishRecording(String text) {
    if (!mounted || !_recording) {
      return;
    }
    unawaited(_recognitionSub?.cancel());
    setState(() {
      _recording = false;
      _levels = const <double>[];
      _partial = '';
      if (text.trim().isNotEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.collapsed(offset: text.length);
        _draftFromVoice = true;
      }
    });
  }

  Future<void> _stopRecording() => widget.recognitionService.stop();

  Future<void> _cancelRecording() async {
    await widget.recognitionService.cancel();
    if (mounted) {
      setState(() {
        _recording = false;
        _levels = const <double>[];
        _partial = '';
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _thinking || _inFlight || _done) {
      return;
    }
    final InputMode mode = _draftFromVoice ? InputMode.voice : InputMode.text;
    _controller.clear();
    _draftFromVoice = false;
    setState(() {
      _lines.add(_Line.learner(text));
      _turns++;
      _thinking = true;
      _inFlight = true;
    });
    _scrollToEnd();

    final Session? session = _session;
    if (session == null) {
      await _scriptedReply();
      if (mounted) {
        setState(() => _inFlight = false);
      }
      return;
    }

    // One silent retry when the relay hiccups, so a single flaky provider
    // call does not end in an error line. The relay refunds a turn it never
    // answered, so the retry costs the learner nothing.
    Object? error = await _streamReply(session, text, mode);
    if (error != null && mounted && _isUnclear(error)) {
      error = await _streamReply(session, text, mode, retryMessageId: await _failedTurnId(session, text));
    }
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _thinking = false;
      _inFlight = false;
      if (error != null) {
        // Nothing reached the learner, so the relay refunded the turn.
        // Take back the optimistic count with it, or the last practice
        // turn fails and the run closes on an error.
        _turns = _session?.counters.turnIndex ?? _turns - 1;
        _lines.add(_Line.error(_errorMessage(l10n, error)));
      }
    });
    _scrollToEnd();
  }

  /// Streams one reply into the conversation. Returns the error when the
  /// turn failed before any of the reply arrived, and null otherwise — a
  /// reply cut off midway keeps what it has, the same as the daily chat.
  Future<Object?> _streamReply(Session session, String text, InputMode mode, {String? retryMessageId}) async {
    // The tutor's line is appended empty and grown token by token, the
    // same way the real conversation paints one (FR-018) — the walkthrough
    // is meant to look like the thing it is teaching.
    int? tutorIndex;
    final StringBuffer reply = StringBuffer();
    try {
      await for (final TurnEvent event
          in widget.sessionRepository.sendTurn(session, text, mode, retryMessageId: retryMessageId)) {
        if (!mounted) {
          return null;
        }
        switch (event) {
          case TurnEventToken(:final String text):
            reply.write(text);
            setState(() {
              _thinking = false;
              if (tutorIndex == null) {
                _lines.add(_Line.tutor(reply.toString()));
                tutorIndex = _lines.length - 1;
              } else {
                _lines[tutorIndex!] = _Line.tutor(reply.toString());
              }
            });
            _scrollToEnd();
          case TurnEventMeta(:final counters):
            setState(() {
              _session = session.copyWith(counters: counters);
              _turns = counters.turnIndex;
            });
        }
      }
    } catch (error) {
      return tutorIndex == null ? error : null;
    }
    return null;
  }

  bool _isUnclear(Object error) => error is! RelayException || error.error is UnclearRetry;

  /// The learner's row the failed attempt left behind, so the retry moves
  /// that row back to sending instead of appending the words a second time.
  Future<String?> _failedTurnId(Session session, String text) async {
    try {
      final List<Message> messages = await widget.sessionRepository.watchMessages(session.id).first;
      for (final Message m in messages.reversed) {
        if (m.role == TurnRole.user && m.delivery == Delivery.failedRetryable && m.text == text) {
          return m.id;
        }
      }
    } catch (_) {
      // Not being able to find the row is no reason to skip the retry.
    }
    return null;
  }

  /// Whatever went wrong, said in the app's own words. A non-relay
  /// failure (a stream that ended without its `meta`) is reported as the
  /// same "try that again" the real conversation uses — the walkthrough
  /// has no separate vocabulary for going wrong.
  String _errorMessage(AppLocalizations l10n, Object error) {
    final RelayError relayError =
        error is RelayException ? error.error : const RelayError.unclearRetry();
    final ErrorCopy copy = resolveErrorCopy(l10n, relayError);
    return '${copy.message}\n${l10n.errorCodeLabel(copy.code)}';
  }

  /// The offline walkthrough. Deliberately says nothing about what the
  /// learner just wrote — nothing here has read it.
  Future<void> _scriptedReply() async {
    // A beat, so the typing indicator is something the learner sees rather
    // than a frame that flickers past. The real tutor takes far longer.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() {
      _thinking = false;
      _lines.add(_Line.tutor(_turns == 1 ? l10n.practiceTutorReply1 : l10n.practiceTutorReply2));
    });
    _scrollToEnd();
  }

  Future<void> _pullHint() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Session? session = _session;
    if (session == null) {
      setState(() {
        _hintUsed = true;
        _lines.add(_Line.hint(l10n.practiceHintText));
      });
      _scrollToEnd();
      return;
    }
    setState(() => _hintUsed = true);
    final Result<HintRung> result = await widget.sessionRepository.pullHint(session);
    if (!mounted) {
      return;
    }
    setState(() {
      switch (result) {
        case Ok<HintRung>(:final HintRung value):
          _lines.add(_Line.hint(value.text));
        case Err<HintRung>():
          // A hint that did not arrive is not worth an error bubble in a
          // walkthrough — the authored rung teaches the same affordance.
          _lines.add(_Line.hint(l10n.practiceHintText));
      }
    });
    _scrollToEnd();
  }

  /// The single exit. Both the skip action and the finished card come
  /// through here, so there is one place that clears the flag rather
  /// than two that have to agree.
  Future<void> _leaveForToday() async {
    if (widget.onLeave != null) {
      widget.onLeave!();
      return;
    }
    await widget.installRepository.setPracticePending(false);
    if (!mounted) {
      return;
    }
    context.go(AppRoute.daily.path);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return PopScope(
      // The carousel hands off with `go`, not `push`, so this screen is
      // the whole stack and a system back would pop into nothing — which
      // Android reads as "close the app". Found on a device: back from
      // the walkthrough killed it outright. Back means the same thing the
      // Skip action does, so it goes through the same exit and clears the
      // same flag.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(_leaveForToday());
        }
      },
      child: _build(context, l10n),
    );
  }

  Widget _build(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.practiceTitle),
        toolbarHeight: 48,
        actions: <Widget>[
          // Present from the first frame, including once the walkthrough
          // is done: this is an offer, and a learner who has decided it
          // is not for them should not have to finish it to leave.
          TextButton(onPressed: _leaveForToday, child: Text(l10n.practiceSkipAction)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Card(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // The real warm-up when there is a session, the
                    // authored copy when the walkthrough is offline. Same
                    // problem either way — the manifest entry was written
                    // from these two strings.
                    Text(
                      _session?.problem.title ?? l10n.practiceProblemTitle,
                      style: context.appTypography.sansHeadline,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _session?.problem.statement ?? l10n.practiceProblemStatement,
                      style: context.appTypography.sansBody,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TopFade(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _lines.length + (_thinking ? 1 : 0),
                  itemBuilder: (BuildContext context, int index) {
                    if (index >= _lines.length) {
                      return const _Bubble(role: _Role.tutor, pending: true);
                    }
                    final _Line line = _lines[index];
                    return _Bubble(role: line.role, text: line.text);
                  },
                ),
              ),
            ),
            if (_done)
              _Finished(onStart: _leaveForToday)
            else ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: _hintUsed ? null : _pullHint,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: Text(l10n.hintActionLabel),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ),
              ),
              if (_recording)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_partial.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _partial,
                            style: context.appTypography.sansBody.copyWith(color: AppTokens.muted),
                          ),
                        ),
                      Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: _cancelRecording,
                            tooltip: l10n.recordingCancelLabel,
                            icon: const Icon(Icons.close, color: AppTokens.muted),
                          ),
                          Expanded(
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTokens.surface2,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppTokens.accentBorder),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    l10n.recordingListeningLabel,
                                    style: context.appTypography.sansCaption.copyWith(color: AppTokens.muted),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Waveform(levels: _levels, height: 26)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _stopRecording,
                            tooltip: l10n.recordingStopLabel,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: AppTokens.accentDim,
                              foregroundColor: AppTokens.accent,
                            ),
                            icon: const Icon(Icons.check, size: 22),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  // The same widget the daily chat uses, so the row the
                  // walkthrough teaches is the row the learner meets
                  // afterwards — mic on the right, becoming send the
                  // moment there is text. The controller is owned here
                  // because the recognised draft is written straight back
                  // into this field (practice has no separate review
                  // screen); the mic hides only when recognition is
                  // unavailable (FR-011a).
                  child: Composer(
                    controller: _controller,
                    showMic: !widget.typedOnly && !_recognitionUnavailable,
                    onMicTap: _startRecording,
                    onSubmit: (_) => _send(),
                  ),
                ),
              if (!widget.typedOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    _recognitionUnavailable
                        ? l10n.practiceRecognitionUnavailableNotice
                        : (_recording ? l10n.practiceTypedNotice : l10n.practiceMicHint),
                    style: context.appTypography.sansCaption.copyWith(
                      color: AppTokens.faint,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Turns the walkthrough gets, mirroring the relay's own
/// `trial.practice_turn_cap`. The server is what actually bounds it; this
/// is what closes the composer at the same moment rather than letting the
/// learner type into a turn that will be refused.
const int _practiceTurnCap = 5;

/// Turns the offline fallback has authored replies for.
const int _scriptedTurns = 2;

enum _Role { learner, tutor, hint, error }

class _Line {
  const _Line(this.role, this.text);

  const _Line.learner(String text) : this(_Role.learner, text);
  const _Line.tutor(String text) : this(_Role.tutor, text);
  const _Line.hint(String text) : this(_Role.hint, text);
  const _Line.error(String text) : this(_Role.error, text);

  final _Role role;
  final String text;
}

/// The same shape as the real conversation's bubbles — the point of the
/// walkthrough is that nothing about the real screen is a surprise.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.role, this.text, this.pending = false});

  final _Role role;
  final String? text;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isLearner = role == _Role.learner;
    final String label = switch (role) {
      _Role.learner => l10n.messageListYouLabel,
      _Role.tutor => l10n.messageListTutorLabel,
      _Role.hint => l10n.hintMessageLabel(1, 1),
      _Role.error => l10n.messageListTutorLabel,
    };
    return Align(
      alignment: isLearner ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isLearner ? AppTokens.surface3 : AppTokens.surface2,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: context.appTypography.monoLabel),
            const SizedBox(height: 6),
            if (pending)
              const TypingIndicator()
            else if (isLearner)
              Text(text!, style: context.appTypography.sansBody)
            else
              MarkdownText(text!),
          ],
        ),
      ),
    );
  }
}

class _Finished extends StatelessWidget {
  const _Finished({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTokens.accentDim,
        border: Border.all(color: AppTokens.accentBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.practiceDoneTitle,
            style: context.appTypography.sansHeadline.copyWith(color: AppTokens.accent),
          ),
          const SizedBox(height: 6),
          Text(l10n.practiceDoneBody, style: context.appTypography.sansCaption),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onStart, child: Text(l10n.practiceStartTodayAction)),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/recognition_availability.dart';
import '../domain/recognition_event.dart';
import '../domain/recognition_service.dart';
import '../domain/spoken_language.dart';
import '../domain/spoken_language_repository.dart';
import 'on_device_recognizer_channel.dart';
import 'transcript_assembler.dart';

/// `speech_to_text` is the whole implementation: `partialResults: true`
/// gives both the recognised text and the sound level stream the waveform
/// needs, so there is no file, no buffer, and no byte of audio anywhere in
/// this class (FR-011) — enforced structurally by `no_io_in_voice_feature`
/// over this directory.
///
/// `onDevice` is deliberately **false**. Setting it true makes the plugin
/// call `SpeechRecognizer.createOnDeviceSpeechRecognizer()`, which binds
/// the *system* on-device recogniser — on ColorOS/OPPO/realme that is an
/// `oemminimal` build of Android System Intelligence that ships no speech
/// packs and never downloads any, so every locale failed with
/// `LANGUAGE_PACK_ERROR` and voice was dead on the whole device family
/// (found on a physical device, 2026-08-28). `false` binds the system
/// default recognition service instead, which needs no pack and handles
/// any language the platform supports.
///
/// The trade: Android's own documentation says this API "is likely to
/// stream audio to remote servers to perform speech recognition". Audio
/// therefore MAY leave the device. Constitution VII was amended to say so,
/// and the mic-rationale copy states it plainly rather than claiming an
/// on-device guarantee the platform will not give us.
/// The one language the app currently speaks.
///
/// Everything multilingual — [SpokenLanguage], the picker, the
/// `SpokenLanguageRepository`, `setLanguage` — is still here and still
/// wired; the app simply pins one language rather than asking, because
/// every other surface (the problem statements, the tutor, the
/// assessment) is English-only, and offering to listen in a language the
/// tutor cannot answer in is a promise the app does not keep. Flip
/// [PinnedSpokenLanguage.pinned] to false to hand the choice back.
class PinnedSpokenLanguage {
  const PinnedSpokenLanguage({
    required this.pinned,
    required this.languageCode,
    required this.regionCode,
  });

  final bool pinned;
  final String languageCode;
  final String? regionCode;
}

const PinnedSpokenLanguage spokenLanguage = PinnedSpokenLanguage(
  pinned: true,
  languageCode: 'en',
  regionCode: 'us',
);

class RecognitionServiceImpl implements RecognitionService {
  RecognitionServiceImpl({
    required SpokenLanguageRepository languages,
    SpeechToText? speech,
    OnDeviceRecognizerChannel? channel,
  })  : _languages = languages,
        _speech = speech ?? SpeechToText(),
        _channel = channel ?? const OnDeviceRecognizerChannel();

  /// FR-013a's 90-second cap.
  static const Duration _listenFor = Duration(seconds: 90);

  /// How long a silence is allowed to run before Android ends the listen
  /// session. Left unset, the platform applies its own ~2-second default,
  /// which ended the recording the first time a learner paused to think —
  /// making FR-013a's 90-second cap and its 75-second warning unreachable
  /// in practice (found on a physical device). Matching `_listenFor` hands
  /// the cap back to the timer that is supposed to own it.
  static const Duration _pauseFor = Duration(seconds: 90);

  final SpeechToText _speech;
  final OnDeviceRecognizerChannel _channel;
  final SpokenLanguageRepository _languages;

  StreamController<RecognitionEvent>? _controller;
  bool _initialized = false;

  /// Holds the session's transcript together across the pauses Android
  /// uses to end one utterance and start the next. See
  /// [TranscriptAssembler]: without it, pausing to think erased whatever
  /// had been said before the pause.
  final TranscriptAssembler _transcript = TranscriptAssembler();

  /// The locales to try, in order, for the learner's own language.
  ///
  /// More than one is needed because `locales()` is a *claim*, not ground
  /// truth: an `en-EG` device lists `en_EG` as supported and can still fail
  /// at listen time with `error_language_not_supported`. The only reliable
  /// way to find one that works is to try it.
  List<String> _localeCandidates = const <String>[];
  bool _localesResolved = false;
  int _candidateIndex = 0;

  /// Android reports a terminal error AFTER the `done` status, not before
  /// (observed on device: listening -> notListening -> done -> onError).
  /// Closing the stream the instant `done` arrived therefore threw that
  /// error away. This holds the close open just long enough for a trailing
  /// error to land and be acted on.
  Timer? _closeGrace;
  static const Duration _trailingErrorGrace = Duration(milliseconds: 400);

  /// How many locales to try before letting the platform choose for
  /// itself. See `_resolveLocaleCandidates`.
  static const int _maxLocaleProbes = 3;

  @override
  Future<RecognitionAvailability> availability() async {
    // Only "is there a recogniser at all". On-device availability is
    // deliberately not consulted: the default recognition service needs no
    // language pack, so a device with no packs is still perfectly able to
    // recognise speech. Asking `isOnDeviceRecognitionAvailable` here is
    // what previously sent a fully capable phone to the unavailable screen.
    final (bool recognitionAvailable, _) = await _channel.check();
    if (!recognitionAvailable) {
      return RecognitionAvailability.unsupported;
    }
    return await _ensureInitialized()
        ? RecognitionAvailability.available
        : RecognitionAvailability.unsupported;
  }

  /// Every locale in the learner's language the recogniser lists, best
  /// guess first: the device's own locale, then `en-US`, then `en-GB`.
  ///
  /// Still needed on the default recogniser, because a device locale can be
  /// a region the service does not itself recognise (`en-EG` here). An
  /// empty result just means "let the platform choose", not a failure.
  Future<List<String>> _resolveLocaleCandidates() async {
    if (_localesResolved) {
      return _localeCandidates;
    }
    _localesResolved = true;
    // An explicit choice (FR-011b) is the whole answer: the recogniser
    // takes one language per session, so probing regions of a language the
    // learner has told us they are not speaking only wastes their time.
    //
    // Ignored while [spokenLanguage] is pinned — the picker is not on
    // screen, so a value here could only be a stale one from an earlier
    // build, and honouring it would send an English-only app listening in
    // a language nothing else in it speaks.
    if (!spokenLanguage.pinned) {
      final String? chosen = await _languages.read();
      if (chosen != null) {
        return _localeCandidates = <String>[chosen];
      }
    }
    try {
      final List<LocaleName> installed = await _speech.locales();
      if (installed.isEmpty) {
        return _localeCandidates = const <String>[];
      }
      final Locale device = PlatformDispatcher.instance.locale;
      final String language =
          spokenLanguage.pinned ? spokenLanguage.languageCode : device.languageCode.toLowerCase();
      final String? region =
          spokenLanguage.pinned ? spokenLanguage.regionCode : device.countryCode?.toLowerCase();

      String normalise(String id) => id.replaceAll('-', '_').toLowerCase();

      final List<String> sameLanguage = installed
          .map((LocaleName l) => l.localeId)
          .where((String id) => normalise(id).split('_').first == language)
          .toList();

      // Most-likely-installed first among the rest. Not a guess about this
      // device so much as about which packs Google ships by default.
      const List<String> preferredRegions = <String>['us', 'gb'];
      int rank(String id) {
        final List<String> parts = normalise(id).split('_');
        final String r = parts.length > 1 ? parts[1] : '';
        if (region != null && r == region) {
          return 0;
        }
        final int preferred = preferredRegions.indexOf(r);
        return preferred >= 0 ? 1 + preferred : 99;
      }

      sameLanguage.sort((String a, String b) => rank(a).compareTo(rank(b)));
      // Capped deliberately. Each failed probe costs the learner about half
      // a second of a mic that visibly does nothing, and a recogniser that
      // rejects the device locale, en-US and en-GB alike is not going to be
      // won over by a fourth region.
      return _localeCandidates = sameLanguage.take(_maxLocaleProbes).toList();
    } catch (_) {
      // The plugin could not enumerate locales. Not evidence the language
      // is missing, so this lets the platform pick rather than sending the
      // learner to the language-pack screen on no evidence.
      return _localeCandidates = const <String>[];
    }
  }

  @override
  Future<List<SpokenLanguage>> supportedLanguages() async {
    // Three sources, in order of how likely each is to be what the learner
    // wants, deduplicated by locale:
    //   1. the languages this device is configured for — their own,
    //   2. what the recogniser claims to support,
    //   3. every locale the platform knows, so the search can find one the
    //      first two missed.
    // (3) exists because (2) is demonstrably incomplete: it omits Arabic on
    // a device where `ar-EG` recognises Arabic perfectly (verified on
    // device, 2026-08-28). Offering a language the recogniser cannot do is
    // not a silent failure — it reaches FR-011a's screen, which says so.
    final List<SpokenLanguage> ordered = <SpokenLanguage>[];
    final Set<String> seen = <String>{};
    String key(String id) => id.replaceAll('-', '_').toLowerCase();

    void add(String localeId, String name) {
      if (seen.add(key(localeId))) {
        ordered.add(SpokenLanguage(localeId: localeId, name: name));
      }
    }

    for (final (String localeId, String name) in await _channel.deviceLocales()) {
      add(localeId, name);
    }
    if (await _ensureInitialized()) {
      try {
        for (final LocaleName l in await _speech.locales()) {
          add(l.localeId, l.name);
        }
      } catch (_) {
        // The plugin could not enumerate. The other two sources stand.
      }
    }
    for (final (String localeId, String name) in await _channel.allLocales()) {
      add(localeId, name);
    }
    return ordered;
  }

  @override
  Future<SpokenLanguage?> currentLanguage() async {
    final List<SpokenLanguage> all = await supportedLanguages();
    if (all.isEmpty) {
      return null;
    }
    // What the next listen will really use: the learner's choice if they
    // made one, otherwise the head of the device-locale probe.
    final String? chosen = await _languages.read() ?? (await _resolveLocaleCandidates()).firstOrNull;
    if (chosen == null) {
      return null;
    }
    String normalise(String id) => id.replaceAll('-', '_').toLowerCase();
    for (final SpokenLanguage language in all) {
      if (normalise(language.localeId) == normalise(chosen)) {
        return language;
      }
    }
    return null;
  }

  @override
  Future<void> setLanguage(String localeId) async {
    await _languages.write(localeId);
    // The probe order is only a guess at the learner's language; an
    // explicit choice replaces it outright rather than being ranked
    // against it.
    _localeCandidates = <String>[localeId];
    _localesResolved = true;
    _candidateIndex = 0;
  }

  @override
  Stream<RecognitionEvent> listen() {
    final StreamController<RecognitionEvent> controller = StreamController<RecognitionEvent>.broadcast();
    _controller = controller;
    // Nothing carries over between recordings — a new listen session is a
    // new transcript, never a continuation of the last one.
    _transcript.reset();
    _closeGrace?.cancel();
    unawaited(_startListening(controller));
    return controller.stream;
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  Future<void> _startListening(StreamController<RecognitionEvent> controller) async {
    final bool ok = await _ensureInitialized();
    if (!ok) {
      controller.add(const RecognitionErrorEvent('initialize_failed', permanent: true));
      await controller.close();
      return;
    }
    await _resolveLocaleCandidates();
    _candidateIndex = 0;
    await _listenWithCurrentLocale(controller);
  }

  Future<void> _listenWithCurrentLocale(StreamController<RecognitionEvent> controller) async {
    final String? localeId =
        _candidateIndex < _localeCandidates.length ? _localeCandidates[_candidateIndex] : null;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!identical(controller, _controller)) {
          return;
        }
        // Three result types, not two. `partial` revises the utterance
        // being spoken; `intermediate` is the platform closing one
        // utterance at a pause while the session keeps running, and is
        // the piece that used to be treated as a plain partial — which
        // is what made the next utterance overwrite it instead of
        // following it.
        switch (result.resultTypeValue) {
          case ResultType.partial:
            _transcript.openUtterance(result.recognizedWords);
            controller.add(PartialTextEvent(_transcript.text));
          case ResultType.intermediate:
            _transcript.closeUtterance(result.recognizedWords);
            controller.add(PartialTextEvent(_transcript.text));
          case ResultType.finalResult:
            _transcript.closeUtterance(result.recognizedWords);
            controller.add(FinalTextEvent(_transcript.text));
        }
      },
      onSoundLevelChange: (double level) {
        if (identical(controller, _controller)) {
          controller.add(LevelEvent(_normaliseLevel(level)));
        }
      },
      // `localeId` is the learner's own language, resolved against what
      // the recogniser actually lists rather than left unset. Leaving it
      // unset means the device locale verbatim, and a region the service
      // does not know — `en-EG` — fails outright instead of recognising
      // the English being spoken.
      listenOptions: SpeechListenOptions(
        // See the class doc. `true` binds a recogniser that is empty on a
        // large share of Android devices; audio may reach Google either way
        // and Constitution VII is written around that.
        onDevice: false,
        partialResults: true,
        listenFor: _listenFor,
        pauseFor: _pauseFor,
        localeId: localeId,
      ),
    );
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) {
      return true;
    }
    _initialized = await _speech.initialize(onError: _onSpeechError, onStatus: _onSpeechStatus);
    return _initialized;
  }

  void _onSpeechError(SpeechRecognitionError error) {
    // A trailing error cancels the pending close: this IS the outcome of
    // the session that just ended, and acting on it is the whole point.
    _closeGrace?.cancel();
    final StreamController<RecognitionEvent>? controller = _controller;
    if (controller == null || controller.isClosed) {
      return;
    }

    const Set<String> languageErrors = <String>{
      'error_language_not_supported',
      'error_language_unavailable',
    };
    if (languageErrors.contains(error.errorMsg)) {
      // The recogniser rejected the locale we asked for, though
      // `locales()` listed it. Try the next region in the same language.
      if (_candidateIndex + 1 < _localeCandidates.length) {
        _candidateIndex++;
        unawaited(_listenWithCurrentLocale(controller));
        return;
      }
      // Every region in this language has been tried. That is FR-011a's
      // `languageUnavailable`, and it must reach the learner as such
      // rather than as "nothing was heard".
      controller.add(RecognitionErrorEvent(error.errorMsg, permanent: true));
      unawaited(controller.close());
      _controller = null;
      return;
    }

    controller.add(RecognitionErrorEvent(error.errorMsg, permanent: error.permanent));
    if (error.permanent) {
      unawaited(controller.close());
      _controller = null;
    }
  }

  void _onSpeechStatus(String status) {
    // Only `done` ends the session. The plugin defines `notListening` as
    // "no longer listening to the microphone after a timeout, stop or
    // cancel" — the mic is off but the final result has NOT been delivered
    // yet, and `done` is the status that means it has. Closing on
    // `notListening` ended the listen session the moment Android stopped
    // capturing, popping the recording screen and dropping the transcript.
    if (status != 'done') {
      return;
    }
    final StreamController<RecognitionEvent>? controller = _controller;
    if (controller == null) {
      return;
    }
    // ...and `done` is not the last word either: Android delivers a
    // terminal error AFTER it (listening -> notListening -> done ->
    // onError, observed on device). Closing here and now discarded that
    // error, so a device with no pack for its own locale reported
    // "nothing was heard" instead of offering the language-pack fix.
    // The close is deferred just far enough for that error to arrive;
    // `_onSpeechError` cancels it and takes over when one does.
    _closeGrace?.cancel();
    _closeGrace = Timer(_trailingErrorGrace, () {
      if (identical(_controller, controller) && !controller.isClosed) {
        unawaited(controller.close());
        _controller = null;
      }
    });
  }

  /// Android's `onSoundLevelChange` values are not documented as bounded
  /// (research.md R-002 notes the plugin's own docs say as much); this
  /// rescales a soft empirical ceiling down to the `0.0`–`1.0` range the
  /// waveform widget expects rather than exposing the raw platform units.
  double _normaliseLevel(double raw) => (raw / 10).clamp(0.0, 1.0);
}

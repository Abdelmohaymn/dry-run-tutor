import 'recognition_availability.dart';
import 'recognition_event.dart';
import 'spoken_language.dart';

/// The voice feature's one interface (contracts/repositories.md). **There
/// is no method that returns audio, and no method that writes a file** —
/// that absence is the implementation of Constitution VII and FR-011, and
/// `no_io_in_voice_feature` (`tools/lints/`) asserts no filesystem or HTTP
/// dependency ever reaches `lib/features/voice/`.
abstract interface class RecognitionService {
  /// `available` | `languageUnavailable` | `unsupported`. Drives FR-011a's
  /// unavailable screen.
  Future<RecognitionAvailability> availability();

  /// Every language the platform recogniser will accept, for FR-011b's
  /// picker. Empty when it cannot be asked — the picker hides itself
  /// rather than offering an empty list.
  Future<List<SpokenLanguage>> supportedLanguages();

  /// The language the next [listen] will actually use, so the picker can
  /// show what is in force rather than what was merely chosen.
  Future<SpokenLanguage?> currentLanguage();

  /// Chooses the language for every subsequent [listen] (FR-011b).
  Future<void> setLanguage(String localeId);

  /// Starts one listen session. `partialText` events update the live
  /// transcript, `level` feeds the waveform (research.md R-002), and the
  /// stream closes after a `finalText` or an [RecognitionErrorEvent] with
  /// `permanent: true`.
  Stream<RecognitionEvent> listen();

  /// Ends the session normally, causing a final result to be emitted.
  Future<void> stop();

  /// Ends the session with no final result — used when the review step is
  /// abandoned for a re-record (FR-012b) rather than a send.
  Future<void> cancel();
}

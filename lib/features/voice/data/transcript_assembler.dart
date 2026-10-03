/// Assembles one listen session's transcript out of the pieces Android
/// delivers, because the recogniser does not deliver one.
///
/// **Android restarts its transcript at every pause.** A learner who says
/// "hello my name is", thinks for a moment, then says "Reiner Braun" gets
/// two *utterances* from the platform, not one: the recogniser closes the
/// first when the silence starts and its next partial result begins again
/// from an empty string. `speech_to_text` passes that through verbatim, so
/// forwarding `recognizedWords` straight to the screen showed the second
/// utterance alone and silently threw the first away — the learner watched
/// their own sentence disappear for pausing to think, which is exactly
/// what an interview rehearsal asks them to do.
///
/// The boundary is not guessed. `ResultType.intermediate` is the plugin's
/// name for "the platform set `final_result` on a *partial*", which is the
/// engine saying it has closed one utterance while the session continues.
/// Every closed utterance is kept; only the utterance still being spoken
/// is ever replaced.
class TranscriptAssembler {
  final List<String> _closed = <String>[];
  String _open = '';

  /// A revised partial for the utterance still being spoken. Replaces the
  /// open utterance rather than adding to it — within one utterance the
  /// recogniser re-sends the whole thing each time, and rewrites earlier
  /// words as later ones give it context.
  void openUtterance(String text) {
    _open = text;
  }

  /// The recogniser has closed an utterance with [text] — either at a
  /// pause (`intermediate`) or at the end of the session (`finalResult`).
  /// The open utterance becomes this, and nothing after it can revise it.
  void closeUtterance(String text) {
    _open = '';
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    // A session that ends on a pause closes the same utterance twice: once
    // as `intermediate` when the silence began, then again as
    // `finalResult` when `stop()` found nothing new to transcribe. Keeping
    // both would say it twice.
    if (_closed.isNotEmpty && _closed.last == trimmed) {
      return;
    }
    _closed.add(trimmed);
  }

  /// Everything heard so far this session: the closed utterances in order,
  /// then whatever is being said now.
  String get text => <String>[..._closed, _open]
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .join(' ');

  /// Starts a new listen session. Nothing carries over between recordings.
  void reset() {
    _closed.clear();
    _open = '';
  }
}

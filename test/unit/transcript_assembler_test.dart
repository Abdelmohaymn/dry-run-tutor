// Pausing to think used to erase everything said before the pause.
// Android closes an utterance when the silence starts and begins its next
// partial result from an empty string, so "hello my name is ... Reiner
// Braun" reached the review step as "Reiner Braun" alone — on an app whose
// whole point is thinking out loud in an interview.
import 'package:dry_run/features/voice/data/transcript_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TranscriptAssembler assembler;

  setUp(() => assembler = TranscriptAssembler());

  test('a pause mid-sentence keeps what came before it', () {
    // What the platform actually delivers: partials build the first
    // utterance, `intermediate` closes it when the learner stops to think,
    // and the partials that follow start again from nothing.
    assembler.openUtterance('hello');
    assembler.openUtterance('hello my name');
    assembler.openUtterance('hello my name is');
    assembler.closeUtterance('hello my name is');

    assembler.openUtterance('Reiner');
    assembler.openUtterance('Reiner Braun');
    assembler.closeUtterance('Reiner Braun');

    expect(assembler.text, 'hello my name is Reiner Braun');
  });

  test('the utterance being spoken is revised, not appended to', () {
    // Within one utterance the recogniser re-sends the whole thing and
    // rewrites earlier words as later ones give it context. Treating each
    // partial as new text would stutter every word.
    assembler.openUtterance('reiner');
    assembler.openUtterance('reiner brown');
    assembler.openUtterance('Reiner Braun');

    expect(assembler.text, 'Reiner Braun');
  });

  test('a closed utterance is never revised by what follows', () {
    assembler.closeUtterance('hello my name is');
    assembler.openUtterance('Reiner');

    expect(assembler.text, 'hello my name is Reiner');
  });

  test('ending on a pause does not say the last utterance twice', () {
    // `stop()` after a silence closes the same utterance a second time:
    // once as `intermediate` when the silence began, then as
    // `finalResult` with nothing new to add.
    assembler.closeUtterance('hello my name is');
    assembler.closeUtterance('hello my name is');

    expect(assembler.text, 'hello my name is');
  });

  test('a final result that heard nothing keeps everything already said', () {
    // The regression this replaces: an empty final reached the Cubit as
    // "nothing was heard" and threw a whole answer away.
    assembler.openUtterance('hello my name is');
    assembler.closeUtterance('hello my name is');
    assembler.closeUtterance('');

    expect(assembler.text, 'hello my name is');
  });

  test('several pauses in one answer all survive', () {
    assembler.closeUtterance('I would use a hash map');
    assembler.closeUtterance('to turn the search into a lookup');
    assembler.openUtterance('so it is linear');

    expect(
      assembler.text,
      'I would use a hash map to turn the search into a lookup so it is linear',
    );
  });

  test('utterances are joined with exactly one space, whatever padding they arrive with', () {
    assembler.closeUtterance('  hello my name is  ');
    assembler.openUtterance('  Reiner Braun ');

    expect(assembler.text, 'hello my name is Reiner Braun');
  });

  test('an empty session is empty, not a stray space', () {
    expect(assembler.text, isEmpty);
    assembler.openUtterance('');
    expect(assembler.text, isEmpty);
  });

  test('a new recording starts from nothing', () {
    assembler.closeUtterance('hello my name is');
    assembler.openUtterance('Reiner');
    assembler.reset();

    expect(assembler.text, isEmpty);
    assembler.openUtterance('a different answer entirely');
    expect(assembler.text, 'a different answer entirely');
  });
}

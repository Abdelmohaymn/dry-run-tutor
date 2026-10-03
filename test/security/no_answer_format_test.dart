// FR-017 / Principle I: the app MUST NOT offer code entry, multiple-choice, or
// any tap-to-answer format. The learner reasons out loud; there is no control
// anywhere in the product that lets them *pick* or *type in* an answer.
//
// This is a structural assertion against source, the peer of `host_allowlist_test.dart`
// (FR-004) and `no_audio_path_test.dart` (FR-011): a prohibition that no runtime
// test can prove, because the failure mode is a widget that simply exists.
//
// Two things are checked:
//
//   1. No selection control appears anywhere in `lib/`. A radio, checkbox,
//      dropdown or segmented control is the multiple-choice format by
//      definition, whatever it is labelled.
//   2. Every text input in `lib/` is on a short, named allowlist. Free text is
//      not itself banned — the product has five legitimate uses of it — but a
//      *sixth* must fail this test and force a deliberate decision, because a
//      code-entry field is exactly what an unreviewed `TextField` becomes.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Selection controls. Present anywhere under `lib/`, each of these is a
/// tap-to-answer affordance, so none of them has a permitted use.
const List<String> _bannedSelectionWidgets = <String>[
  'RadioListTile',
  'CheckboxListTile',
  'Radio<',
  'RadioGroup',
  'DropdownButton',
  'DropdownMenu',
  'ToggleButtons',
  'SegmentedButton',
  'CupertinoSegmentedControl',
  'CupertinoSlidingSegmentedControl',
];

/// Text-input constructors. Allowed only in the files listed in
/// [_textInputAllowlist], and nowhere else.
const List<String> _textInputWidgets = <String>[
  'TextField(',
  'TextFormField(',
  'CupertinoTextField(',
  'EditableText(',
];

/// The complete set of text inputs the product is allowed to have, with the
/// reason each one is not an answer field. Adding a file here is a deliberate
/// act; the test exists so that it cannot happen by accident.
const Map<String, String> _textInputAllowlist = <String, String>{
  // The typed alternative to speaking (FR-012). Prose addressed to the tutor,
  // the same content the microphone would have produced — not an answer slot.
  // The field now lives in the composer itself rather than behind a link;
  // `text_composer.dart` is the same input in its earlier, unrouted form.
  'lib/features/chat/presentation/widgets/composer.dart':
      'the daily composer’s typed turn — prose to the tutor, the typed twin of a spoken one',
  'lib/features/chat/presentation/widgets/text_composer.dart':
      'the "or type instead" composer — prose to the tutor, the typed twin of a spoken turn',
  // The review step, where a misheard transcript is corrected before sending.
  // Two files, one step: the review now happens in the conversation
  // (`inline_review.dart`); `review_screen.dart` is the same step's
  // no-longer-routed full-screen form.
  'lib/features/transcript/presentation/review_screen.dart':
      'transcript correction before send',
  'lib/features/chat/presentation/widgets/inline_review.dart':
      'transcript correction before send, in the conversation',
  // A provider API key, not conversation content.
  // One form, shared by `/keys/entry` and `/settings/key`.
  'lib/features/keys/presentation/key_entry_form.dart': 'provider key entry',
  // The onboarding walkthrough's composer. Scripted and entirely local —
  // no session, no relay, no turn — and it is the same kind of prose the
  // real composer takes, not an answer slot.
  'lib/features/onboarding/presentation/practice_screen.dart':
      'the practice walkthrough’s typed turn — prose to a scripted tutor',
  // FR-011b's language search box: filters a list of locales, sends nothing.
  'lib/features/voice/presentation/widgets/spoken_language_picker.dart':
      'search box over the spoken-language list',
};

void main() {
  late List<File> dartFiles;

  setUpAll(() {
    final Directory libDir = Directory('${Directory.current.path}${Platform.pathSeparator}lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ must exist');
    dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        // Generated localisations carry no widgets of their own.
        .where((File f) => !_relativePath(f).startsWith('lib/l10n/generated/'))
        .toList();
    expect(dartFiles, isNotEmpty);
  });

  test('no multiple-choice or tap-to-answer selection control exists in lib/', () {
    final List<String> violations = <String>[];

    for (final File file in dartFiles) {
      final String source = _sourceWithoutComments(file.readAsStringSync());
      for (final String widget in _bannedSelectionWidgets) {
        if (source.contains(widget)) {
          violations.add('${_relativePath(file)}: uses $widget');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'FR-017 forbids any tap-to-answer format:\n${violations.join('\n')}',
    );
  });

  test('every text input in lib/ is one of the seven the product is allowed', () {
    final List<String> violations = <String>[];

    for (final File file in dartFiles) {
      final String relative = _relativePath(file);
      if (_textInputAllowlist.containsKey(relative)) {
        continue;
      }
      final String source = _sourceWithoutComments(file.readAsStringSync());
      for (final String widget in _textInputWidgets) {
        if (source.contains(widget)) {
          violations.add('$relative: constructs $widget');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'FR-017: a new text input must be justified and added to '
          '_textInputAllowlist, or it is a code-entry field:\n${violations.join('\n')}',
    );
  });

  test('the allowlist names only files that still exist', () {
    // A stale entry would silently widen the check, so the allowlist has to be
    // kept honest in both directions.
    final List<String> missing = _textInputAllowlist.keys
        .where((String path) => !File('${Directory.current.path}${Platform.pathSeparator}$path').existsSync())
        .toList();
    expect(missing, isEmpty, reason: 'allowlisted files no longer exist: ${missing.join(', ')}');
  });
}

String _relativePath(File file) {
  return file.path
      .substring(Directory.current.path.length + 1)
      .replaceAll(Platform.pathSeparator, '/');
}

/// Strips `//` and `/* */` comments so that a widget named only in prose — as
/// this very file names them — never trips the scan.
String _sourceWithoutComments(String source) {
  return source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');
}

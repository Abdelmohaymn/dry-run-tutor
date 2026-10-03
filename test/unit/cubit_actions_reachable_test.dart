// Every public action on `DailySessionCubit` must be reachable from the UI.
//
// This guards a failure mode the suite has now missed twice, both found only
// by a human using the app on a real device:
//
//   * hints returned 400 for every learner, because the tests posted a
//     synthetic turn rather than the shape the app actually sends;
//   * `requestSolution()` was written, unit-tested, and given a finished
//     confirmation screen and router entry — and **no widget ever called it**,
//     so a stuck learner had no way to ask for the answer and the Socratic
//     tutor appeared to just repeat itself forever (2026-09-03).
//
// Both are the same shape: the behaviour is correct and covered, and the
// route into it does not exist. A bloc_test proves a method works when
// called; nothing proved anything calls it.
//
// So: parse the cubit's public methods and assert each name appears somewhere
// in `lib/` outside the cubit itself. This is deliberately crude — it proves
// a reference exists, not that it is reachable in the right state — but it is
// enough to catch a control that was never wired at all.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Methods that are legitimately not called from anywhere else in `lib/`.
const Map<String, String> _notCalledFromUi = <String, String>{
  // Cubit lifecycle, called by the framework.
  'close': 'BlocBase override, invoked by flutter_bloc',
};

void main() {
  test('every public DailySessionCubit action is referenced somewhere in lib/', () {
    final String root = Directory.current.path;
    final String cubitPath =
        '$root/lib/features/chat/presentation/daily_session_cubit.dart'.replaceAll('/', Platform.pathSeparator);
    final File cubitFile = File(cubitPath);
    expect(cubitFile.existsSync(), isTrue, reason: 'the cubit must exist at $cubitPath');

    final String cubitSource = cubitFile.readAsStringSync();

    // Public members declared at class-body indentation: two spaces, a return
    // type, a lower-case name, then an argument list.
    final RegExp declaration = RegExp(
      r'^  (?:Future<[^>]*>|Stream<[^>]*>|void|bool|int|String|[A-Z][A-Za-z0-9_<>, ?]*)\s+'
      r'([a-z][A-Za-z0-9]*)\s*\(',
      multiLine: true,
    );

    final Set<String> methods = declaration
        .allMatches(cubitSource)
        .map((RegExpMatch m) => m.group(1)!)
        .where((String name) => !_notCalledFromUi.containsKey(name))
        .toSet();

    expect(
      methods,
      contains('requestSolution'),
      reason: 'the regex must still find the method whose absence prompted this test',
    );

    final List<File> otherDartFiles = Directory('$root${Platform.pathSeparator}lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .where((File f) => f.path != cubitFile.path)
        // Generated unions mention every state name; they prove nothing about
        // a call site, so they cannot satisfy the check.
        .where((File f) => !f.path.endsWith('.freezed.dart'))
        .where((File f) => !f.path.endsWith('.g.dart'))
        .toList();

    final String allOtherSource =
        otherDartFiles.map((File f) => f.readAsStringSync()).join('\n');

    final List<String> unreferenced = methods
        .where((String name) => !RegExp('\\.$name\\s*\\(|\\.$name\\b').hasMatch(allOtherSource))
        .toList()
      ..sort();

    expect(
      unreferenced,
      isEmpty,
      reason: 'These DailySessionCubit actions are not called from anywhere in lib/. '
          'Either wire a control to them or record why in _notCalledFromUi:\n'
          '${unreferenced.join('\n')}',
    );
  });
}

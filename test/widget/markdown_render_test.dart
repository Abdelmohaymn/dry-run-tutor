// The editorial is authored Markdown and the judge's feedback and the
// tutor's turns use the same conventions — all three were painted into a
// plain `Text`, so a learner read `**The move:**` with the asterisks in
// it. What matters is twofold: the markers must not survive into the
// rendered text, and the text between them must.
import 'package:dry_run/core/text/markdown_text.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything the widget actually paints, flattened.
String _rendered(WidgetTester tester) {
  final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
  final StringBuffer buffer = StringBuffer();
  for (final Text text in texts) {
    buffer.write(text.textSpan?.toPlainText() ?? text.data ?? '');
    buffer.write('\n');
  }
  return buffer.toString();
}

Future<void> _pump(WidgetTester tester, String source) {
  return tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(body: SingleChildScrollView(child: MarkdownText(source))),
    ),
  );
}

void main() {
  testWidgets('bold markers are consumed, the words they wrap are kept', (WidgetTester tester) async {
    await _pump(tester, '**The move: turn a search into a lookup.**');

    final String rendered = _rendered(tester);
    expect(rendered, contains('The move: turn a search into a lookup.'));
    expect(rendered, isNot(contains('**')));
  });

  testWidgets('bold text is actually bold, not just unmarked', (WidgetTester tester) async {
    await _pump(tester, 'plain **strong** plain');

    final Text text = tester.widget<Text>(find.byType(Text).first);
    final List<InlineSpan> children = (text.textSpan! as TextSpan).children!;
    final TextSpan strong = children.whereType<TextSpan>().firstWhere(
          (TextSpan s) => s.style?.fontWeight == FontWeight.w700,
        );
    expect(strong.toPlainText(), 'strong');
  });

  testWidgets('italics, inline code and headings all lose their markers', (
    WidgetTester tester,
  ) async {
    await _pump(tester, '## Why it matters\n\nUse a *hash map* and call `target - value`.');

    final String rendered = _rendered(tester);
    expect(rendered, contains('Why it matters'));
    expect(rendered, contains('hash map'));
    expect(rendered, contains('target - value'));
    expect(rendered, isNot(contains('##')));
    expect(rendered, isNot(contains('`')));
  });

  testWidgets('bullets render as list rows with the dash removed', (WidgetTester tester) async {
    await _pump(tester, '- first point\n- second point');

    final String rendered = _rendered(tester);
    expect(rendered, contains('first point'));
    expect(rendered, contains('second point'));
    expect(rendered, isNot(contains('- first')));
  });

  testWidgets('an unbalanced marker degrades to the literal character', (
    WidgetTester tester,
  ) async {
    // Content is never dropped to keep the parser tidy.
    await _pump(tester, 'a * b and 5 ** 2');

    expect(_rendered(tester), contains('a * b and 5 ** 2'));
  });

  testWidgets('a fenced block keeps its code verbatim', (WidgetTester tester) async {
    await _pump(tester, 'before\n\n```\nfor (x in xs) { }\n```\n\nafter');

    final String rendered = _rendered(tester);
    expect(rendered, contains('for (x in xs) { }'));
    expect(rendered, isNot(contains('```')));
  });
}

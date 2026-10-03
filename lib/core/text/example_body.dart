import 'math_notation.dart';

/// One worked example, rendered as the body of a chat message.
///
/// Examples are delivered into the conversation the way hint rungs are —
/// on the learner's own ask, one at a time, labelled "Example 1 of 3" by
/// the bubble itself. So the body carries no "Input:"/"Output:" headings:
/// the arrow says which is which in any language, the bubble's own label
/// says what this is, and nothing learner-facing ends up as an English
/// literal baked into a database row.
///
/// Markdown, because that is what a tutor bubble renders: the input and
/// output are code-shaped and get backticks, the explanation is prose.
String renderExampleBody(String input, String output, String? explanation) {
  final StringBuffer buffer = StringBuffer()
    ..write('`${MathNotation.format(input)}`')
    ..write('  →  ')
    ..write('`${MathNotation.format(output)}`');
  if (explanation != null && explanation.trim().isNotEmpty) {
    buffer.write('\n\n${MathNotation.format(explanation)}');
  }
  return buffer.toString();
}

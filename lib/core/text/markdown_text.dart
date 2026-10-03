import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Renders the small slice of Markdown the relay actually emits.
///
/// The editorial is authored as Markdown (`problem.schema.json`:
/// "Markdown for the reveal"), the judge's `feedback` and the tutor's
/// streamed turns use the same conventions, and every one of them was
/// being painted into a plain `Text` — so a learner read `**The move:**`
/// with the asterisks still in it. A dependency was not added for this:
/// what has to render is bold, italic, inline code, fenced code, headings
/// and bullets, which is what this file does and nothing more.
///
/// Unknown syntax degrades to the literal text rather than being dropped
/// — content is never withheld to keep a parser tidy.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.data, {
    this.style,
    this.selectable = false,
    super.key,
  });

  final String data;

  /// The prose base. Defaults to `context.appTypography.sansBody`.
  final TextStyle? style;

  /// The reveal wants selectable prose; a chat bubble does not.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ?? context.appTypography.sansBody;
    final List<_Block> blocks = _parseBlocks(data);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : blocks[i].spacingAbove),
            child: _buildBlock(context, blocks[i], base),
          ),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, _Block block, TextStyle base) {
    final AppTypography type = context.appTypography;
    switch (block.kind) {
      case _BlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTokens.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTokens.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _text(block.text, type.monoBody),
          ),
        );
      case _BlockKind.heading:
        final TextStyle headingStyle = switch (block.level) {
          1 => type.sansHeadline.copyWith(fontSize: 20),
          2 => type.sansHeadline,
          _ => type.sansHeadline.copyWith(fontSize: 15),
        };
        return _richText(context, block.text, headingStyle);
      case _BlockKind.bullet:
        return Padding(
          padding: EdgeInsets.only(left: 4.0 + block.indent * 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: block.marker.isEmpty ? 14 : 22,
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: block.marker.isEmpty
                      ? _text('•', base.copyWith(color: AppTokens.faint))
                      : _text(block.marker, base.copyWith(color: AppTokens.faint)),
                ),
              ),
              Expanded(child: _richText(context, block.text, base)),
            ],
          ),
        );
      case _BlockKind.rule:
        return const Divider(color: AppTokens.border, height: 1);
      case _BlockKind.quote:
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppTokens.border2, width: 2)),
          ),
          child: _richText(context, block.text, base.copyWith(color: AppTokens.muted)),
        );
      case _BlockKind.paragraph:
        return _richText(context, block.text, base);
    }
  }

  Widget _richText(BuildContext context, String source, TextStyle base) {
    final List<InlineSpan> spans = _inlineSpans(source, base, context.appTypography.monoBody);
    final TextSpan span = TextSpan(children: spans, style: base);
    return selectable
        ? SelectableText.rich(span, style: base)
        : Text.rich(span, style: base);
  }

  // A literal here is copy nobody authored — a bullet glyph and the raw
  // code a block already carries — so it never routes through the ARB.
  Widget _text(String value, TextStyle style) => Text(value, style: style);
}

enum _BlockKind { paragraph, heading, bullet, code, quote, rule }

class _Block {
  const _Block(this.kind, this.text, {this.level = 0, this.marker = '', this.indent = 0});

  final _BlockKind kind;
  final String text;
  final int level;

  /// `1.` for an ordered item, empty for a plain bullet.
  final String marker;
  final int indent;

  double get spacingAbove => switch (kind) {
        _BlockKind.bullet => 4,
        _BlockKind.heading => 14,
        _BlockKind.rule => 12,
        _ => 10,
      };
}

final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _bulletPattern = RegExp(r'^(\s*)[-*+•]\s+(.*)$');
final RegExp _orderedPattern = RegExp(r'^(\s*)(\d+[.)])\s+(.*)$');
final RegExp _rulePattern = RegExp(r'^\s*([-*_])\1{2,}\s*$');
final RegExp _quotePattern = RegExp(r'^\s*>\s?(.*)$');
final RegExp _fencePattern = RegExp(r'^\s*```');

List<_Block> _parseBlocks(String source) {
  final List<String> lines = source.replaceAll('\r\n', '\n').split('\n');
  final List<_Block> blocks = <_Block>[];
  final List<String> paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) {
      return;
    }
    blocks.add(_Block(_BlockKind.paragraph, paragraph.join(' ').trim()));
    paragraph.clear();
  }

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];

    if (_fencePattern.hasMatch(line)) {
      flushParagraph();
      final List<String> code = <String>[];
      i++;
      while (i < lines.length && !_fencePattern.hasMatch(lines[i])) {
        code.add(lines[i]);
        i++;
      }
      blocks.add(_Block(_BlockKind.code, code.join('\n')));
      continue;
    }

    if (line.trim().isEmpty) {
      flushParagraph();
      continue;
    }

    if (_rulePattern.hasMatch(line)) {
      flushParagraph();
      blocks.add(const _Block(_BlockKind.rule, ''));
      continue;
    }

    final Match? heading = _headingPattern.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(_Block(_BlockKind.heading, heading[2]!.trim(), level: heading[1]!.length));
      continue;
    }

    final Match? ordered = _orderedPattern.firstMatch(line);
    if (ordered != null) {
      flushParagraph();
      blocks.add(
        _Block(
          _BlockKind.bullet,
          ordered[3]!.trim(),
          marker: ordered[2]!,
          indent: ordered[1]!.length ~/ 2,
        ),
      );
      continue;
    }

    final Match? bullet = _bulletPattern.firstMatch(line);
    if (bullet != null) {
      flushParagraph();
      blocks.add(
        _Block(_BlockKind.bullet, bullet[2]!.trim(), indent: bullet[1]!.length ~/ 2),
      );
      continue;
    }

    final Match? quote = _quotePattern.firstMatch(line);
    if (quote != null) {
      flushParagraph();
      blocks.add(_Block(_BlockKind.quote, quote[1]!.trim()));
      continue;
    }

    paragraph.add(line.trim());
  }
  flushParagraph();
  return blocks;
}

/// CommonMark's flanking rules, in the only two places they matter here:
/// a marker followed by whitespace does not open emphasis, and one
/// preceded by whitespace does not close it. Without them `5 ** 2` and
/// `a * b` — arithmetic, which the tutor writes constantly — are read as
/// emphasis and the operators silently vanish.
bool _opensEmphasis(String source, int afterMarker) =>
    afterMarker < source.length && !_isSpace(source[afterMarker]);

int _closingMarker(String source, String marker, int from) {
  int at = source.indexOf(marker, from);
  while (at > 0 && _isSpace(source[at - 1])) {
    at = source.indexOf(marker, at + 1);
  }
  return at;
}

bool _isSpace(String char) => char.trim().isEmpty;

/// `**bold**`, `__bold__`, `*em*`, `_em_`, and `` `code` ``, scanned by
/// hand rather than by regex: an unbalanced marker has to fall through as
/// the literal character it is, which a single alternation pattern cannot
/// express without dropping text.
List<InlineSpan> _inlineSpans(String source, TextStyle base, TextStyle codeStyle) {
  final List<InlineSpan> spans = <InlineSpan>[];
  final StringBuffer buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) {
      return;
    }
    spans.add(TextSpan(text: buffer.toString()));
    buffer.clear();
  }

  int i = 0;
  while (i < source.length) {
    final String char = source[i];

    if (char == '\\' && i + 1 < source.length) {
      buffer.write(source[i + 1]);
      i += 2;
      continue;
    }

    if (char == '`') {
      final int close = source.indexOf('`', i + 1);
      if (close > i + 1) {
        flush();
        spans.add(
          TextSpan(
            text: source.substring(i + 1, close),
            style: codeStyle.copyWith(
              fontSize: base.fontSize,
              color: AppTokens.accent,
              backgroundColor: AppTokens.surface2,
            ),
          ),
        );
        i = close + 1;
        continue;
      }
    }

    final bool strongMark = (char == '*' || char == '_') &&
        i + 1 < source.length &&
        source[i + 1] == char;
    if (strongMark && _opensEmphasis(source, i + 2)) {
      final String marker = char * 2;
      final int close = _closingMarker(source, marker, i + 2);
      if (close > i + 2) {
        flush();
        spans.add(
          TextSpan(
            children: _inlineSpans(source.substring(i + 2, close), base, codeStyle),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
        i = close + marker.length;
        continue;
      }
    }

    if ((char == '*' || char == '_') && _opensEmphasis(source, i + 1)) {
      final int close = _closingMarker(source, char, i + 1);
      // A lone `_` inside a word (`snake_case`) is not emphasis.
      final bool wordInternal = char == '_' &&
          i > 0 &&
          RegExp(r'\w').hasMatch(source[i - 1]);
      if (!wordInternal && close > i + 1 && !source.substring(i + 1, close).contains('\n')) {
        flush();
        spans.add(
          TextSpan(
            children: _inlineSpans(source.substring(i + 1, close), base, codeStyle),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
        i = close + 1;
        continue;
      }
    }

    buffer.write(char);
    i++;
  }

  flush();
  return spans;
}

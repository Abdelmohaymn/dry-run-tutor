import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';

/// Tap-to-fix chips matching recognised tokens against the problem's
/// `glossaryTerms`, so "hash mop" → "hashmap" is one tap (FR-012a). This
/// is what stops the mandatory review from making voice slower than
/// typing (SC-016).
class GlossaryChips extends StatelessWidget {
  const GlossaryChips({required this.draftText, required this.glossaryTerms, required this.onApply, super.key});

  final String draftText;
  final List<String> glossaryTerms;

  /// Called with the whole updated draft text and the term that was
  /// applied.
  final void Function(String updatedText, String appliedTerm) onApply;

  @override
  Widget build(BuildContext context) {
    final List<GlossaryChipMatch> matches = findGlossaryChipMatches(draftText, glossaryTerms);
    if (matches.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final GlossaryChipMatch match in matches)
          ActionChip(
            label: Text(match.term, style: context.appTypography.monoLabel),
            backgroundColor: AppTokens.surface2,
            side: const BorderSide(color: AppTokens.border),
            onPressed: () {
              final String updated = draftText.replaceRange(match.start, match.end, match.term);
              onApply(updated, match.term);
            },
          ),
      ],
    );
  }
}

/// One candidate correction: replacing `[start, end)` in the draft with
/// [term] fixes a likely mishearing.
@immutable
class GlossaryChipMatch {
  const GlossaryChipMatch({required this.term, required this.start, required this.end});

  final String term;
  final int start;
  final int end;
}

/// A word-window edit-distance heuristic, not an NLP dependency — the
/// locked stack has none, and this is cheap enough to run on every
/// keystroke. Considers 1- and 2-word windows of [text] against each of
/// [glossaryTerms], and returns at most one (the closest) match per term.
@visibleForTesting
List<GlossaryChipMatch> findGlossaryChipMatches(String text, List<String> glossaryTerms) {
  final List<RegExpMatch> words = RegExp(r'\S+').allMatches(text).toList(growable: false);
  final List<GlossaryChipMatch> matches = <GlossaryChipMatch>[];

  for (final String term in glossaryTerms) {
    final String normalisedTerm = _normalise(term);
    if (normalisedTerm.isEmpty) {
      continue;
    }
    GlossaryChipMatch? best;
    int bestDistance = 1 << 30;

    for (int windowSize = 1; windowSize <= 2; windowSize++) {
      for (int i = 0; i + windowSize <= words.length; i++) {
        final RegExpMatch first = words[i];
        final RegExpMatch last = words[i + windowSize - 1];
        final String windowText = text.substring(first.start, last.end);
        final String normalisedWindow = _normalise(windowText);
        if (normalisedWindow.isEmpty || normalisedWindow == normalisedTerm) {
          continue;
        }
        final int distance = _levenshtein(normalisedWindow, normalisedTerm);
        final int threshold = (normalisedTerm.length * 0.34).ceil().clamp(1, 3);
        if (distance <= threshold && distance < bestDistance) {
          bestDistance = distance;
          best = GlossaryChipMatch(term: term, start: first.start, end: last.end);
        }
      }
    }
    if (best != null) {
      matches.add(best);
    }
  }
  return matches;
}

String _normalise(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

int _levenshtein(String a, String b) {
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length;
  }
  if (b.isEmpty) {
    return a.length;
  }
  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  List<int> current = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    current[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = <int>[current[j - 1] + 1, previous[j] + 1, previous[j - 1] + cost]
          .reduce((int x, int y) => x < y ? x : y);
    }
    final List<int> swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

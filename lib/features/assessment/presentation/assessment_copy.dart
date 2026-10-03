import 'package:flutter/material.dart' show Color;

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/models/wire_enums.dart';
import '../../../core/theme/tokens.dart';

/// A hedged word alongside its hue — never hue alone (design-tokens.md:
/// "Verdict chip — hue *and* a word", FR-030). No branch here reaches for
/// [AppTokens.red]: a verdict is never "wrong" on this screen, whatever
/// the enum backing it is named.
class VerdictCopy {
  const VerdictCopy({required this.word, required this.hue});
  final String word;
  final Color hue;
}

/// Exhaustive over [Verdict] — a twelfth tier added to the catalogue is a
/// compile error here, the same discipline `error_copy.dart` applies to
/// [RelayError] (SC-008, FR-044's sibling for the assessment surface).
VerdictCopy resolveVerdictCopy(AppLocalizations l10n, Verdict verdict) => switch (verdict) {
      Verdict.strongPass => VerdictCopy(word: l10n.verdictStrongPass, hue: AppTokens.accent),
      Verdict.pass => VerdictCopy(word: l10n.verdictPass, hue: AppTokens.accent),
      Verdict.borderline => VerdictCopy(word: l10n.verdictBorderline, hue: AppTokens.amber),
      Verdict.fail => VerdictCopy(word: l10n.verdictFail, hue: AppTokens.amber),
      Verdict.unclear => VerdictCopy(word: l10n.verdictUnclear, hue: AppTokens.muted),
    };

/// How closely the conversation matched an authored approach —
/// `matchedApproach: 'none'` is a designed state (Principle II), not an
/// error, and gets its own honest sentence rather than a blank.
String resolveMatchedVerdictCopy(AppLocalizations l10n, MatchedVerdict matched) => switch (matched) {
      MatchedVerdict.optimal => l10n.matchedApproachOptimal,
      MatchedVerdict.acceptable => l10n.matchedApproachAcceptable,
      MatchedVerdict.suboptimal => l10n.matchedApproachSuboptimal,
      MatchedVerdict.wrong => l10n.matchedApproachWrong,
      MatchedVerdict.none => l10n.matchedApproachNone,
    };

/// An authored insight or approach key, made readable.
///
/// The judge returns `insights_hit` / `insights_missed` and
/// `matched_approach` as **keys** — `scan_in_array_order` — because that
/// is what the ground truth is indexed by and what the coverage repair in
/// `judge-postprocess.ts` matches on. The assessment screen was painting
/// those keys straight into the list, so a learner read
/// `two_pointer_no_copy` where a sentence belonged (found on a physical
/// device, 2026-09-04).
///
/// Nothing better is available client-side: the insight `text` is
/// judge-facing and never leaves the server (FR-003), so there is no
/// authored learner-facing phrasing to reach for. Making the key readable
/// is the honest fix — it shows exactly what the judge scored, in words,
/// and invents nothing.
String humaniseInsightKey(String key) {
  final List<String> words = key.split('_').where((String w) => w.isNotEmpty).toList();
  if (words.isEmpty) {
    return key;
  }
  final String first = words.first;
  return <String>[
    '${first[0].toUpperCase()}${first.substring(1)}',
    ...words.skip(1),
  ].join(' ');
}

/// `Complexity.assessment` — `correct` | `mismatched` | `not_stated`, off
/// the wire rather than a closed Dart enum (data-model.md §5), so this
/// falls back rather than throwing on a value the app has not seen yet.
String resolveComplexityCopy(AppLocalizations l10n, String assessment) => switch (assessment) {
      'correct' => l10n.complexityMatch,
      'mismatched' => l10n.complexityMismatch,
      'not_stated' => l10n.complexityNotStated,
      _ => l10n.complexityNotStated,
    };

import 'package:equatable/equatable.dart';

import '../../../core/models/wire_enums.dart';
import 'complexity.dart';

/// A read-only projection of the `/v1/judge` response
/// (data-model.md §5, §9). **Nothing here is ever constructed
/// client-side** (Principle II) — every field is a field of the wire
/// response, and `matchedApproach: 'none'` is a designed state the judge
/// returns rather than an error the app improvises.
class Assessment extends Equatable {
  const Assessment({
    required this.sessionId,
    required this.matchedApproach,
    required this.matchedVerdict,
    required this.insightsHit,
    required this.insightsAssisted,
    required this.insightsMissed,
    required this.wrongTurnsTaken,
    required this.complexity,
    required this.verdict,
    required this.confidence,
    required this.feedback,
    required this.editorial,
    this.revealAtIndex,
  });

  final String sessionId;

  /// An authored approach key, or `"none"`.
  final String matchedApproach;
  final MatchedVerdict matchedVerdict;
  final List<String> insightsHit;

  /// The subset of [insightsHit] the learner reached by accepting an idea
  /// the tutor put into words ("with a nudge", PLAN_07 D11).
  final List<String> insightsAssisted;
  final List<String> insightsMissed;
  final List<String> wrongTurnsTaken;
  final Complexity complexity;

  /// Post-override — the server's `mapVerdict()` already won over the
  /// model. The app displays this; it never re-derives it.
  final Verdict verdict;
  final double confidence;
  final String feedback;

  /// Markdown for the reveal — the only path by which private content is
  /// ever released (FR-032, 001 FR-022).
  final String editorial;

  /// Set only when the session ended by a solution request (FR-033): the
  /// turn index the learner had reached when they asked, so the
  /// assessment (and its copy) can say plainly it covers only the work
  /// before that point.
  final int? revealAtIndex;

  @override
  List<Object?> get props => <Object?>[
        sessionId,
        matchedApproach,
        matchedVerdict,
        insightsHit,
        insightsAssisted,
        insightsMissed,
        wrongTurnsTaken,
        complexity,
        verdict,
        confidence,
        feedback,
        editorial,
        revealAtIndex,
      ];
}

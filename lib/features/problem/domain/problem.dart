import 'package:equatable/equatable.dart';

/// `problem.schema.json#/$defs/PublicHalf` — field for field, and nothing
/// else (data-model.md §2, §9). Reference approaches, key insights, wrong
/// turns, follow-ups, and editorials are server-side only (Constitution
/// VI); a field on this class that is not in `PublicHalf` is a contract
/// violation.
/// One worked example: a concrete input, the answer for it, and — when
/// authored — a sentence on why. Public content: an example says what the
/// question *means*, never how to answer it, so nothing here comes near
/// the private half's approaches, insights, or editorial.
class ProblemExample extends Equatable {
  const ProblemExample({required this.input, required this.output, this.explanation});

  final String input;
  final String output;
  final String? explanation;

  @override
  List<Object?> get props => <Object?>[input, output, explanation];
}

class Problem extends Equatable {
  const Problem({
    required this.schemaVersion,
    required this.id,
    this.date,
    required this.title,
    required this.ramp,
    this.difficulty,
    required this.tags,
    required this.source,
    required this.statement,
    required this.constraints,
    this.examples = const <ProblemExample>[],
    required this.estSpeakSeconds,
    required this.collections,
    required this.glossaryTerms,
    required this.hintCount,
  });

  final int schemaVersion;
  final String id;
  final String? date;
  final String title;

  /// `easy` | `medium` | `hard`.
  final String ramp;
  final int? difficulty;
  final List<String> tags;
  final String source;
  final String statement;
  final List<String> constraints;

  /// Optional and often empty — a problem authored without examples is a
  /// designed state, not a gap, and the app simply does not offer the
  /// control for one.
  final List<ProblemExample> examples;
  final int estSpeakSeconds;
  final List<String> collections;

  /// What transcript review's tap-to-fix chips match against (FR-012a).
  final List<String> glossaryTerms;

  /// Build-injected, never authored (data-model.md §2) — lets the app
  /// render "Hint n of `hintCount`" and disable the control at the end for
  /// a problem the learner has not opened yet.
  final int hintCount;

  @override
  List<Object?> get props => <Object?>[
        schemaVersion,
        id,
        date,
        title,
        ramp,
        difficulty,
        tags,
        source,
        statement,
        constraints,
        examples,
        estSpeakSeconds,
        collections,
        glossaryTerms,
        hintCount,
      ];
}

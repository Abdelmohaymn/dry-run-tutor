import 'package:equatable/equatable.dart';

import '../../../core/models/wire_enums.dart';
import '../../problem/domain/problem.dart';
import 'server_counters.dart';

/// One attempt, one problem, one day (data-model.md §3, §9). Anchored in
/// Drift by `SessionRepositoryImpl`, not owned by any Cubit's lifetime, so
/// the conversation survives both an app kill (FR-024) and a push to the
/// key-entry route and back (FR-007a) from the same mechanism.
class Session extends Equatable {
  const Session({
    required this.id,
    required this.problem,
    required this.day,
    required this.path,
    required this.status,
    this.providerId,
    required this.counters,
    this.summary,
    required this.isRepeat,
    required this.disputed,
    required this.solutionRequestCount,
  });

  final String id;
  final Problem problem;

  /// `YYYY-MM-DD`, trusted time.
  final String day;
  final SessionPath path;
  final SessionStatus status;

  /// The `X-Provider` sent, keyed path only.
  final String? providerId;

  /// Last known SERVER truth. Never computed here (FR-019).
  final ServerCounters counters;

  /// The last `meta.summary`, replayed verbatim on the next request.
  final String? summary;

  /// FR-035c. Never read by the presentation layer (FR-035b) — local only,
  /// for later analysis.
  final bool isRepeat;

  final bool disputed;
  final int solutionRequestCount;

  Session copyWith({
    SessionPath? path,
    SessionStatus? status,
    String? providerId,
    ServerCounters? counters,
    String? summary,
    bool clearSummary = false,
    bool? disputed,
    int? solutionRequestCount,
  }) {
    return Session(
      id: id,
      problem: problem,
      day: day,
      path: path ?? this.path,
      status: status ?? this.status,
      providerId: providerId ?? this.providerId,
      counters: counters ?? this.counters,
      summary: clearSummary ? null : (summary ?? this.summary),
      isRepeat: isRepeat,
      disputed: disputed ?? this.disputed,
      solutionRequestCount: solutionRequestCount ?? this.solutionRequestCount,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        problem,
        day,
        path,
        status,
        providerId,
        counters,
        summary,
        isRepeat,
        disputed,
        solutionRequestCount,
      ];
}

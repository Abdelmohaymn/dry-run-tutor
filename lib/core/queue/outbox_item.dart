import 'package:equatable/equatable.dart';

import '../models/wire_enums.dart';

/// A pure-Dart projection of one `Outbox` row (data-model.md §6) — what
/// `OutboxRepository` and `OutboxDrainBloc` speak, so neither ever imports
/// Drift directly.
class OutboxItem extends Equatable {
  const OutboxItem({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.payload,
    required this.solutionRequestCountAtEnqueue,
    required this.attempts,
    required this.nextEligibleAt,
    this.lastErrorCode,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final OutboxKind kind;

  /// The request body, verbatim, as it will be replayed — a `chatTurn`
  /// row's `ChatRequestDto.toJson()`, a `judge` row's `JudgeRequestDto.toJson()`.
  final Map<String, Object?> payload;

  /// `Sessions.solutionRequestCount` as it stood when this row was
  /// enqueued — **not** including whatever this row itself might grant.
  /// Principle III: a replayed row can never carry a higher solution
  /// count than the row it replaces; the drain worker checks this against
  /// the session's *current* count before sending (data-model.md §6).
  final int solutionRequestCountAtEnqueue;

  final int attempts;
  final DateTime nextEligibleAt;
  final String? lastErrorCode;
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        sessionId,
        kind,
        payload,
        solutionRequestCountAtEnqueue,
        attempts,
        nextEligibleAt,
        lastErrorCode,
        createdAt,
      ];
}

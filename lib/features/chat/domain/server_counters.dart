import 'package:equatable/equatable.dart';

/// The `meta` frame, whole (data-model.md §9). **The only source of these
/// numbers** — `turnIndex`, `turnsRemaining`, `hintsRevealed`, and
/// `hintsRemaining` are never computed by the app (FR-019). This entity
/// has one writer, the `meta` frame parser in `SessionRepositoryImpl`,
/// which is what makes "the app never computes a counter" a property of
/// the type graph rather than a rule someone has to remember
/// (research.md R-007).
///
/// The subtle case this guards: a hint pull advances [hintsRevealed]
/// while leaving [turnIndex] unchanged, so any app-side "turns used"
/// arithmetic would drift the first time a learner asks for a hint.
class ServerCounters extends Equatable {
  const ServerCounters({
    required this.turnIndex,
    required this.turnsRemaining,
    required this.hintsRevealed,
    required this.hintsRemaining,
    required this.sessionEnded,
    required this.leakBlocked,
    this.readyToFinish = false,
  });

  /// A session that has not sent a first turn yet.
  static const ServerCounters initial = ServerCounters(
    turnIndex: 0,
    turnsRemaining: 0,
    hintsRevealed: 0,
    hintsRemaining: 0,
    sessionEnded: null,
    leakBlocked: false,
  );

  final int turnIndex;
  final int turnsRemaining;
  final int hintsRevealed;
  final int hintsRemaining;

  /// `user` | `cap` | `solution` | `null` (not ended yet). Server-derived
  /// only.
  final String? sessionEnded;

  /// `true` means the reply this frame accompanies is a fallback
  /// redirect, not the tutor's real answer — rendered as conversation,
  /// never as a glitch.
  final bool leakBlocked;

  /// The relay's finish check says the learner has explained every
  /// required key insight (feature 005). Only ever offers; never ends the
  /// session. `false` when no check ran.
  final bool readyToFinish;

  @override
  List<Object?> get props => <Object?>[
        turnIndex,
        turnsRemaining,
        hintsRevealed,
        hintsRemaining,
        sessionEnded,
        leakBlocked,
        readyToFinish,
      ];
}

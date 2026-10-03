import 'package:equatable/equatable.dart';

import '../../problem/domain/problem.dart';

/// `DailyRepository.forToday()`'s result (contracts/repositories.md). FR-040
/// excludes withdrawn problems; FR-035b/c is why [isRepeat] exists at all —
/// recorded for later analysis, never read by the presentation layer.
class DailySelection extends Equatable {
  const DailySelection({required this.problem, required this.isRepeat});

  final Problem problem;
  final bool isRepeat;

  @override
  List<Object?> get props => <Object?>[problem, isRepeat];
}

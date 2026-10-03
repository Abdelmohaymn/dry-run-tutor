import 'package:equatable/equatable.dart';

/// `openapi.yaml#Assessment.complexity`, read-only (Principle II) — one
/// column, verbatim, on `Assessments.complexityJson` (data-model.md §5).
class Complexity extends Equatable {
  const Complexity({
    this.userClaimedTime,
    this.userClaimedSpace,
    required this.referenceTime,
    required this.referenceSpace,
    required this.assessment,
  });

  final String? userClaimedTime;
  final String? userClaimedSpace;
  final String referenceTime;
  final String referenceSpace;

  /// `correct` | `mismatched` | `not_stated`.
  final String assessment;

  @override
  List<Object?> get props => <Object?>[
        userClaimedTime,
        userClaimedSpace,
        referenceTime,
        referenceSpace,
        assessment,
      ];
}

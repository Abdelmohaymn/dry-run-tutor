import 'package:freezed_annotation/freezed_annotation.dart';

part 'trusted_instant.freezed.dart';

/// Which tier of the chain produced a [TrustedInstant] (research.md
/// R-003).
enum TrustedTimeSourceKind {
  /// Tier one: a fresh read off Play Services TrustedTime this call.
  trustedTime,

  /// Tier two: derived from the most recent relay `Date:` header, via a
  /// monotonic delta since it was captured.
  serverDate,

  /// Tier three: no fresh anchor at all, or a reboot was detected
  /// (`SystemClock.elapsedRealtime()` went backwards relative to the
  /// stored anchor) — the last resort, always [TrustedInstant.isStale].
  monotonicAnchor,
}

/// A moment in trusted time. `source` and `isStale` are what FR-047c and
/// FR-038 branch on: a stale instant never unlocks a new day and never
/// revokes a day already credited.
@freezed
sealed class TrustedInstant with _$TrustedInstant {
  const factory TrustedInstant({
    required DateTime utc,
    required TrustedTimeSourceKind source,
    required bool isStale,
  }) = _TrustedInstant;
}

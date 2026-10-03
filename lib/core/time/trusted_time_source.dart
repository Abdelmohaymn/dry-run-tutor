import 'trusted_instant.dart';

/// The one interface anything outside `core/time` may depend on for "what
/// time is it". `DateTime.now()` is banned everywhere else by the
/// `no_wall_clock` custom lint (Principle IX) — this is the replacement.
abstract interface class TrustedTimeSource {
  /// The current trusted instant, via the three-tier chain (research.md
  /// R-003): Play Services TrustedTime, then the relay's last `Date:`
  /// header, then the last known anchor plus a monotonic delta. Never
  /// throws; a total absence of any anchor is represented by
  /// `TrustedInstant.isStale == true`, not an exception.
  Future<TrustedInstant> now();

  /// The current trusted calendar day, `YYYY-MM-DD`. Used everywhere a
  /// "which day is this" decision is made — the daily selection, the
  /// streak, session `day` — so that decision is never made twice with
  /// two different notions of "today".
  Future<String> today();
}

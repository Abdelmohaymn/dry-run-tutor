/// Whether the mic rationale screen (prototype screen 9) has ever been
/// shown on this install. Shown **at first record, never at launch**
/// (FR-014) — this is what makes "first" mean once, not every time.
abstract interface class MicRationaleRepository {
  Future<bool> hasBeenShown();
  Future<void> markShown();
}

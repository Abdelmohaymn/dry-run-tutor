/// The learner's chosen recognition language (FR-011b).
///
/// The platform recogniser accepts **one** language per listen session —
/// there is no auto-detection and no code-switching to be had from it — so
/// a learner who speaks a language other than their device's needs a way
/// to say so. `null` means "not chosen", which leaves the existing
/// device-locale probe in charge.
abstract interface class SpokenLanguageRepository {
  Future<String?> read();

  Future<void> write(String localeId);
}

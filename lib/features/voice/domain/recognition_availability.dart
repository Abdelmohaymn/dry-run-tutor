/// What `RecognitionService.availability()` reports (contracts/repositories.md).
///
/// `unsupported` and `languageUnavailable` both route to
/// `recognition_unavailable_screen.dart` (FR-011a); the difference is only
/// in which explanation the screen offers. Neither has an in-app fix — the
/// app uses the platform's default recogniser, which needs no language
/// pack, so there is nothing for the learner to install. The keyboard is
/// the answer in both cases.
enum RecognitionAvailability {
  available,

  /// A recogniser exists, but not for the language being spoken.
  languageUnavailable,

  /// No recognition service on the device at all.
  unsupported,
}

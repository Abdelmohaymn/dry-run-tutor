/// The product's name, and every identifier derived from it.
///
/// **This is the single place to change the app's name.** Everything in
/// `lib/` that says "Dry Run" — window title, notification channel, share
/// card, the age gate and the wall — reads it from here, and the three
/// learner-facing strings that mention the name take it as an `{appName}`
/// placeholder rather than baking it into `app_en.arb`. Renaming the product
/// is an edit to this file plus the two platform-side duplicates listed
/// below, which no Dart constant can reach:
///
///  * `android/app/src/main/res/values/strings.xml` → `app_name`, which the
///    launcher and every system dialog (the microphone permission prompt
///    above all) render before a single line of Dart has run.
///  * `android/app/build.gradle.kts` → `namespace`, `defaultConfig.applicationId`
///    and the `deepLinkScheme` placeholder, and the Kotlin package under
///    `android/app/src/main/kotlin/`. These are frozen the moment the first
///    bundle reaches Play and cannot be changed afterwards — see `SHIP.md`.
///
/// [packageId] and [deepLinkScheme] must stay in step with those Android
/// values by hand; `test/unit/brand_test.dart` asserts they do.
abstract final class AppBrand {
  /// The product name, as a learner reads it. Title case, with the space.
  static const String name = 'Dry Run';

  /// The Android `namespace` and Kotlin package.
  static const String androidNamespace = 'app.dryrun';

  /// The `applicationId`. Permanent once published.
  static const String packageId = 'app.dryrun.tutor';

  /// The deep-link scheme: `<scheme>://p/<problem_id>`.
  static const String deepLinkScheme = 'dryruntutor';

  /// Prefix for platform method channels. Must match `CHANNEL_NAME` in the
  /// Kotlin sources. In-process, so it is the namespace, NOT the
  /// applicationId.
  static const String channelPrefix = androidNamespace;

  /// The landing site. Where the update wall sends a learner when the
  /// relay has not named a store listing (`update_url`).
  static const String websiteUrl = 'https://dry-run-tutor-site.example.workers.dev/';

  /// The on-device Drift database file, without extension.
  static const String databaseName = 'dry_run';

  /// The local-notification channel id. Changing this **orphans the
  /// existing channel** on every installed device: the learner's own
  /// notification settings for the old id stay behind and the new channel
  /// arrives at default importance. Only change it alongside a migration.
  static const String notificationChannelId = 'dryrun_default';

  /// Basename for the shared streak image.
  static const String shareImageName = 'dry-run.png';
}

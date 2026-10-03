import 'reminder_time.dart';

/// `/settings`, `/settings/reminder`, `/settings/wipe` (contracts/routes.md,
/// FR-006, FR-048a, FR-039f).
abstract interface class SettingsRepository {
  /// `null` when no reminder is currently scheduled.
  Future<ReminderTime?> reminderTime();

  /// Schedules the one local daily reminder at [time], cancelling
  /// whatever was scheduled before (FR-048a). `null` cancels it outright.
  ///
  /// Returns whether the reminder can actually appear: on Android 13+ a
  /// scheduled notification with no `POST_NOTIFICATIONS` grant is accepted
  /// and then silently dropped, so "scheduled" and "will be seen" are two
  /// different facts and the screen has to be told which it got.
  Future<bool> setReminderTime(ReminderTime? time);

  /// Whether the app may post notifications right now. Read-only — it
  /// never raises the system prompt, so opening the screen to look does
  /// not put a dialog in the learner's way.
  Future<bool> notificationsAllowed();

  /// Raises Android's own permission prompt and reports the answer.
  ///
  /// Called the instant the learner switches the reminder on, not when
  /// they save: the switch is the moment the request has a reason they can
  /// see, and asking later meant a learner could leave the screen believing
  /// a reminder was set that the system would never show.
  Future<bool> requestNotificationPermission();

  /// Opens Android's settings page for this app.
  ///
  /// Android stops showing the permission dialog once it has been refused,
  /// so a learner whose notifications are already blocked cannot be asked
  /// again from inside the app — this is the only route left, and without
  /// it the screen could state the problem and offer no way out of it.
  Future<void> openNotificationSettings();

  /// True exactly once per install, and only while notifications are
  /// blocked: the first daily verdict is the moment a learner has a reason
  /// to want tomorrow's problem, so that is when the app asks. Every call
  /// after the first answers false, whatever the permission says.
  Future<bool> takeNotificationNudge();

  /// FR-048b: cancels *today's* reminder without touching tomorrow's —
  /// called the moment a session completes.
  Future<void> cancelTodaysReminder();

  /// Whether Android will let the reminder be set for a precise moment.
  ///
  /// False means it is still scheduled and will still arrive — inside an
  /// hour-wide window Android picks, which for a time the learner chose
  /// themselves is worth telling them about.
  Future<bool> exactAlarmsAllowed();

  /// Opens Android's "Alarms & reminders" page for this app.
  ///
  /// `SCHEDULE_EXACT_ALARM` has no runtime dialog — this page is the only
  /// thing that can change the answer, so the screen has to leave the app
  /// to ask.
  Future<void> openExactAlarmSettings();

  /// Re-arms the pending reminder at launch.
  ///
  /// The reminder is a one-shot (FR-048b needs a skippable occurrence,
  /// which a repeating alarm cannot give), so without this it fires once
  /// and never again — and an Android reboot drops it even before that.
  /// A reminder still in the future is restored to the same instant, not
  /// recomputed, so a skip survives a relaunch.
  Future<void> restoreReminder();

  /// FR-039f: every retained table except the install identity row
  /// (preserving it is what keeps a wipe from restoring the taster —
  /// data-model.md §1), secure storage, and preferences, in one action.
  /// Also cancels every pending local notification.
  Future<void> wipeAllData();
}

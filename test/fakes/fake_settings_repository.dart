import 'package:dry_run/features/settings/domain/reminder_time.dart';
import 'package:dry_run/features/settings/domain/settings_repository.dart';

/// A plain, scriptable fake — no `flutter_local_notifications`, no
/// platform channel. [permissionGranted] is what an Android 13+ device
/// would answer, and it is the difference between a reminder that is
/// scheduled and one that will actually be seen.
class FakeSettingsRepository implements SettingsRepository {
  ReminderTime? scheduled;
  bool permissionGranted = true;
  int permissionRequests = 0;
  int settingsOpened = 0;
  int wipes = 0;
  int reminderRestores = 0;
  bool exactAlarmsGranted = true;
  int exactAlarmSettingsOpened = 0;
  bool notificationNudgeTaken = false;

  @override
  Future<ReminderTime?> reminderTime() async => scheduled;

  @override
  Future<bool> setReminderTime(ReminderTime? time) async {
    scheduled = time;
    if (time == null) {
      return true;
    }
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<bool> notificationsAllowed() async => permissionGranted;

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> openNotificationSettings() async {
    settingsOpened++;
  }

  @override
  Future<bool> takeNotificationNudge() async {
    if (notificationNudgeTaken) {
      return false;
    }
    notificationNudgeTaken = true;
    return !permissionGranted;
  }

  @override
  Future<bool> exactAlarmsAllowed() async => exactAlarmsGranted;

  @override
  Future<void> openExactAlarmSettings() async {
    exactAlarmSettingsOpened++;
  }

  @override
  Future<void> cancelTodaysReminder() async {}

  @override
  Future<void> restoreReminder() async {
    reminderRestores++;
  }

  @override
  Future<void> wipeAllData() async {
    wipes++;
  }
}

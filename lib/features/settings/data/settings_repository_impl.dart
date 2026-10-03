import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../keys/domain/key_repository.dart';
import '../domain/reminder_time.dart';
import '../domain/settings_repository.dart';

const String _reminderHourKey = 'settings.reminder_hour';
const String _reminderMinuteKey = 'settings.reminder_minute';

/// The exact instant the pending one-shot is armed for, so `restoreReminder`
/// can put it back after a relaunch or reboot without recomputing it — and
/// so without quietly undoing an FR-048b skip.
const String _reminderNextMsKey = 'settings.reminder_next_ms';

/// Set the first time [SettingsRepositoryImpl.takeNotificationNudge] is
/// asked, so the popup after the first daily verdict never comes back.
const String _notificationNudgeTakenKey = 'settings.notification_nudge_taken';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required AppDatabase database,
    required KeyRepository keyRepository,
    required NotificationService notificationService,
    required SharedPreferences prefs,
  })  : _database = database,
        _keyRepository = keyRepository,
        _notificationService = notificationService,
        _prefs = prefs;

  final AppDatabase _database;
  final KeyRepository _keyRepository;
  final NotificationService _notificationService;
  final SharedPreferences _prefs;

  @override
  Future<ReminderTime?> reminderTime() async {
    final int? hour = _prefs.getInt(_reminderHourKey);
    final int? minute = _prefs.getInt(_reminderMinuteKey);
    if (hour == null || minute == null) {
      return null;
    }
    return ReminderTime(hour: hour, minute: minute);
  }

  @override
  Future<bool> setReminderTime(ReminderTime? time) async {
    if (time == null) {
      await _prefs.remove(_reminderHourKey);
      await _prefs.remove(_reminderMinuteKey);
      await _prefs.remove(_reminderNextMsKey);
      await _notificationService.cancelReminder();
      return true;
    }
    // Asked here, at the one moment the permission has a reason the
    // learner can see. Scheduling proceeds either way — the preference is
    // theirs, and a grant given later in Android's own settings makes the
    // already-scheduled reminder start appearing — but the caller is told
    // the truth about whether it will be seen.
    final bool allowed = await _notificationService.ensurePermission();
    await _prefs.setInt(_reminderHourKey, time.hour);
    await _prefs.setInt(_reminderMinuteKey, time.minute);
    final DateTime next = await _notificationService.scheduleReminder(hour: time.hour, minute: time.minute);
    await _prefs.setInt(_reminderNextMsKey, next.millisecondsSinceEpoch);
    return allowed;
  }

  @override
  Future<bool> notificationsAllowed() => _notificationService.permissionGranted();

  @override
  Future<bool> requestNotificationPermission() => _notificationService.ensurePermission();

  @override
  Future<void> openNotificationSettings() => openAppSettings();

  @override
  Future<bool> takeNotificationNudge() async {
    if (_prefs.getBool(_notificationNudgeTakenKey) ?? false) {
      return false;
    }
    await _prefs.setBool(_notificationNudgeTakenKey, true);
    return !await _notificationService.permissionGranted();
  }

  @override
  Future<bool> exactAlarmsAllowed() => _notificationService.canScheduleExact();

  @override
  Future<void> openExactAlarmSettings() => _notificationService.requestExactAlarms();

  @override
  Future<void> cancelTodaysReminder() async {
    final ReminderTime? time = await reminderTime();
    if (time == null) {
      return;
    }
    // Re-schedules for tomorrow rather than cancelling outright — FR-048b
    // ends *today's* reminder, not the reminder itself.
    final DateTime next = await _notificationService.scheduleReminder(
      hour: time.hour,
      minute: time.minute,
      dayOffset: 1,
    );
    await _prefs.setInt(_reminderNextMsKey, next.millisecondsSinceEpoch);
  }

  @override
  Future<void> restoreReminder() async {
    final ReminderTime? time = await reminderTime();
    if (time == null) {
      return;
    }
    final int? pendingMs = _prefs.getInt(_reminderNextMsKey);
    if (pendingMs != null) {
      final DateTime pending = DateTime.fromMillisecondsSinceEpoch(pendingMs);
      if (pending.isAfter(DateTime.now())) {
        // Still in the future: re-arm the *same* instant. Recomputing here
        // would move an FR-048b "skip today" back onto today the first time
        // the learner reopened the app.
        await _notificationService.scheduleReminderAt(pending);
        return;
      }
    }
    // It has fired, or the device was off when it was due. Either way the
    // next occurrence is the one to arm — this is the only thing that makes
    // a one-shot reminder a daily one.
    final DateTime next = await _notificationService.scheduleReminder(hour: time.hour, minute: time.minute);
    await _prefs.setInt(_reminderNextMsKey, next.millisecondsSinceEpoch);
  }

  @override
  Future<void> wipeAllData() async {
    await _database.wipeAllExceptInstallIdentity();
    await _keyRepository.delete();
    await _notificationService.cancelAll();
    // `InstallIdentity` lives in Drift, untouched above — nothing here
    // needs to preserve a specific preferences key to keep FR-039f's
    // "does not reset install identity" true, so every preference,
    // reminder included, is cleared without exception.
    await _prefs.clear();
  }
}

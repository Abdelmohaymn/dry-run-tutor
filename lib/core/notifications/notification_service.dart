import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../config/brand.dart';

/// The one local-notification surface in the app. No push service
/// anywhere — every notification here is generated on-device
/// (FR-048a/b/c). Three callers: `OutboxDrainBloc` (a queued assessment
/// delivered while the app wasn't watching, T141), the daily reminder
/// (Phase 11, T156), and `SettingsRepositoryImpl.wipeAllData` (T157).
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    AppBrand.notificationChannelId,
    AppBrand.name,
    channelDescription: 'Assessment and reminder notifications',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: android));
    // `zonedSchedule` (the reminder, T156) needs a `tz.Location`, and
    // this app has no device-timezone-name plugin (research.md keeps the
    // dependency list resolved and closed). `tz.local` is **not** the
    // platform's zone — `initializeTimeZones()` sets it to `Etc/UTC` and
    // only `setLocalLocation` ever moves it — so everything here
    // schedules against `tz.UTC` explicitly and converts the learner's
    // wall clock with `DateTime.toUtc()`, which does use the device's
    // real offset and its DST rules. See `scheduleReminder`.
    tz_data.initializeTimeZones();
  }

  /// FR-048c: a queued assessment was delivered while the app wasn't in
  /// the foreground to show it directly.
  Future<void> notifyAssessmentReady() async {
    await _plugin.show(
      id: _assessmentReadyNotificationId,
      title: 'Today’s assessment is ready',
      body: 'Your conversation caught up while you were away — see how it went.',
      notificationDetails: const NotificationDetails(android: _androidDetails),
    );
  }

  /// Schedules the next occurrence of [hour]:[minute] as a **one-shot**,
  /// not a repeating alarm — `flutter_local_notifications`'
  /// `matchDateTimeComponents` repeat has no way to skip a single
  /// occurrence, and FR-048b needs exactly that (today's reminder
  /// cancelled without touching tomorrow's). [dayOffset] pushes the
  /// target date forward — `1` is what FR-048b's "skip today" uses.
  ///
  /// Because it is a one-shot, something has to arm the *next* one:
  /// `SettingsRepositoryImpl.restoreReminder()`, at every launch. The
  /// moment returned here is what it persists, so a relaunch before the
  /// reminder is due restores the same instant rather than moving it (a
  /// re-arm must never quietly undo an FR-048b skip).
  ///
  /// The target is built in the device's own wall clock and converted
  /// with `toUtc()`. It is **not** built with `tz.TZDateTime(tz.local,
  /// ...)`: `tz.local` is `Etc/UTC` here (see `init`), so that spelling
  /// read the learner's 21:00 as 21:00 UTC and fired the reminder a full
  /// UTC-offset late — three hours, in Africa/Cairo, which on an evening
  /// reminder lands it after midnight on the wrong day. Reported as "the
  /// test notification arrives but the scheduled one never does"
  /// (2026-09-18).
  Future<DateTime> scheduleReminder({required int hour, required int minute, int dayOffset = 0}) async {
    final DateTime now = DateTime.now();
    // Day arithmetic through the `DateTime` constructor, not
    // `add(Duration(days: 1))`: a duration adds 24 elapsed hours, which
    // moves the wall clock by an hour across a DST boundary. Africa/Cairo
    // has two of those a year.
    DateTime target = DateTime(now.year, now.month, now.day + dayOffset, hour, minute);
    if (!target.isAfter(now)) {
      target = DateTime(now.year, now.month, target.day + 1, hour, minute);
    }
    await scheduleReminderAt(target);
    return target;
  }

  /// Arms the one-shot for an exact [target] already chosen by an earlier
  /// `scheduleReminder`. Used to restore a pending reminder across a
  /// relaunch or reboot without recomputing — and so without losing a
  /// skip.
  Future<void> scheduleReminderAt(DateTime target) async {
    await _plugin.cancel(id: _reminderNotificationId);
    await _plugin.zonedSchedule(
      id: _reminderNotificationId,
      title: 'Today’s problem is ready',
      body: 'One problem, talked through out loud — a few minutes is enough.',
      scheduledDate: tz.TZDateTime.from(target.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(android: _androidDetails),
      androidScheduleMode: await _scheduleMode(),
    );
  }

  /// Exact when the OS allows it, inexact when it doesn't.
  ///
  /// This used to be `inexactAllowWhileIdle` unconditionally, on the
  /// reasoning that a daily nudge inside its OS-batched window was not a
  /// regression. On a real device that window is an **hour**
  /// (`dumpsys alarm`: `windowLength 3600000`), and the alarm set for
  /// 23:22 had still not been delivered when the learner gave up looking
  /// for it. A reminder the learner picked a time for is the one kind of
  /// notification where an hour of slack is the whole failure.
  ///
  /// Not exact unconditionally either: `exactAllowWhileIdle` throws
  /// `PlatformException('exact_alarms_not_permitted')` when the grant is
  /// missing, and a learner who declines it should still get a slightly
  /// late reminder rather than none at all.
  Future<AndroidScheduleMode> _scheduleMode() async {
    return await canScheduleExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Whether Android will let this app set an alarm for a precise moment.
  ///
  /// Granted by default below Android 13; denied by default from 13 up,
  /// where `SCHEDULE_EXACT_ALARM` is not a runtime dialog at all — only
  /// [requestExactAlarms] can move it, by sending the learner to a system
  /// settings page.
  Future<bool> canScheduleExact() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    return await android.canScheduleExactNotifications() ?? false;
  }

  /// Opens Android's "Alarms & reminders" page for this app.
  ///
  /// There is no in-app dialog for `SCHEDULE_EXACT_ALARM` — the platform
  /// only offers this settings page — so this leaves the app, and the
  /// answer is whatever [canScheduleExact] says when the learner comes
  /// back, not a value this call returns.
  Future<void> requestExactAlarms() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  /// Asks Android 13+ for `POST_NOTIFICATIONS` and reports whether the
  /// app may now post at all.
  ///
  /// **Nothing ever called this.** `POST_NOTIFICATIONS` was declared in
  /// the manifest and never requested at runtime, so on any Android 13 or
  /// newer device every notification this class posted — the daily
  /// reminder and FR-048c's queued-assessment nudge alike — was accepted
  /// by the plugin, scheduled, and then dropped by the system with no
  /// error anywhere. Reported as "I don't receive daily notifications"
  /// (2026-09-04); it was never a scheduling bug.
  ///
  /// Asked at the moment the learner turns the reminder on, which is the
  /// only moment the permission has a reason the learner can see. Returns
  /// true on the platforms and versions where no grant is needed.
  Future<bool> ensurePermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    if (await android.areNotificationsEnabled() ?? false) {
      return true;
    }
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Whether the app may post notifications right now — read, never
  /// asked, so the settings screen can state the truth without throwing a
  /// system dialog at a learner who only opened the screen to look.
  Future<bool> permissionGranted() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }
    return await android.areNotificationsEnabled() ?? false;
  }

  Future<void> cancelReminder() => _plugin.cancel(id: _reminderNotificationId);

  /// T157: every pending local notification, wipe included.
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// A fixed id: at most one assessment is ever pending at a time, so a
/// second delivery replaces rather than stacks the first.
const int _assessmentReadyNotificationId = 1;

/// A fixed id: exactly one reminder is ever pending at a time — the next
/// occurrence, always rescheduled rather than stacked.
const int _reminderNotificationId = 2;

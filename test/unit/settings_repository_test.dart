// T154/T157: FR-039f's wipe preserves `InstallIdentity` — the one table
// `wipeAllExceptInstallIdentity` deliberately doesn't touch — because
// that row, not anything in preferences, is what keeps a wipe from also
// resetting install identity and, with it, restoring the taster
// (data-model.md §1). Every other retained table, including
// `StreakDays`, is cleared, and the stored key is deleted.
//
// `NotificationService` wraps `flutter_local_notifications`' platform
// channel directly; this test mocks that channel (the plugin's own
// documented pattern) rather than adding a second abstraction layer just
// for testability, matching this project's line elsewhere that native
// platform-channel correctness is verified on hardware, not simulated
// here (tasks.md's "Notes").
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/notifications/notification_service.dart';
import 'package:dry_run/features/keys/domain/learner_key.dart';
import 'package:dry_run/features/settings/data/settings_repository_impl.dart';
import 'package:dry_run/features/settings/domain/reminder_time.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_key_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel notificationsChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  late AppDatabase db;
  late FakeKeyRepository keyRepository;
  late SettingsRepositoryImpl repository;
  late List<MethodCall> notificationCalls;

  /// The `scheduleMode` the last `zonedSchedule` asked Android for.
  String lastScheduleMode() {
    final MethodCall call = notificationCalls.lastWhere((MethodCall c) => c.method == 'zonedSchedule');
    final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
    final Map<Object?, Object?> platform = args['platformSpecifics']! as Map<Object?, Object?>;
    return platform['scheduleMode']! as String;
  }

  /// The instant the last `zonedSchedule` armed, as a local `DateTime`.
  ///
  /// The plugin serializes `scheduledDateTime` as a wall clock in
  /// `timeZoneName`'s zone, not as an instant — so reading the hour off it
  /// directly is exactly the mistake that caused the bug these tests cover.
  DateTime lastScheduledInstant() {
    final MethodCall call = notificationCalls.lastWhere((MethodCall c) => c.method == 'zonedSchedule');
    final Map<Object?, Object?> args = call.arguments as Map<Object?, Object?>;
    expect(
      args['timeZoneName'],
      'Etc/UTC',
      reason: 'this app never calls setLocalLocation, so it schedules against UTC explicitly',
    );
    return DateTime.parse('${args['scheduledDateTime']}Z').toLocal();
  }

  /// What the mocked platform reports for `areNotificationsEnabled` and
  /// answers to `requestNotificationsPermission` — the two states an
  /// Android 13+ device can be in when a reminder is switched on.
  bool notificationsEnabled = false;
  bool permissionGrantResult = true;

  /// What the mocked platform answers for `canScheduleExactNotifications`.
  /// Android 13+ says false until the learner grants it on a system page.
  bool exactAlarmsAllowed = true;

  setUp(() async {
    notificationCalls = <MethodCall>[];
    notificationsEnabled = false;
    permissionGrantResult = true;
    exactAlarmsAllowed = true;
    // No platform-plugin registration happens under `flutter test` the
    // way it does in a real app run — this is that registration's test
    // equivalent, the plugin's own documented seam for it.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      notificationsChannel,
      (MethodCall call) async {
        notificationCalls.add(call);
        if (call.method == 'initialize') {
          return true;
        }
        if (call.method == 'areNotificationsEnabled') {
          return notificationsEnabled;
        }
        if (call.method == 'requestNotificationsPermission') {
          return permissionGrantResult;
        }
        if (call.method == 'canScheduleExactNotifications') {
          return exactAlarmsAllowed;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    keyRepository = FakeKeyRepository();
    final NotificationService notificationService = NotificationService();
    await notificationService.init();
    repository = SettingsRepositoryImpl(
      database: db,
      keyRepository: keyRepository,
      notificationService: notificationService,
      prefs: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      notificationsChannel,
      null,
    );
    await db.close();
  });

  // FR-048a. POST_NOTIFICATIONS was declared in the manifest and never
  // requested at runtime, so on Android 13+ every reminder this app
  // scheduled was accepted and then dropped by the system — the learner
  // saw nothing and there was no error anywhere to find (2026-09-04).
  test('enabling a reminder asks for the notification permission', () async {
    await repository.setReminderTime(const ReminderTime(hour: 8, minute: 30));

    expect(
      notificationCalls.map((MethodCall c) => c.method),
      contains('requestNotificationsPermission'),
    );
    expect(
      notificationCalls.map((MethodCall c) => c.method),
      contains('zonedSchedule'),
      reason: 'the reminder is still scheduled — a grant given later makes it appear',
    );
  });

  test('a permission the learner already granted is not asked for again', () async {
    notificationsEnabled = true;

    await repository.setReminderTime(const ReminderTime(hour: 8, minute: 30));

    expect(
      notificationCalls.map((MethodCall c) => c.method),
      isNot(contains('requestNotificationsPermission')),
    );
  });

  test('a refused permission is reported, not swallowed', () async {
    permissionGrantResult = false;

    final bool allowed = await repository.setReminderTime(const ReminderTime(hour: 8, minute: 30));

    expect(
      allowed,
      isFalse,
      reason: 'the screen has to be able to tell "scheduled" from "will be seen"',
    );
  });

  test('cancelling a reminder asks for nothing', () async {
    await repository.setReminderTime(null);

    expect(
      notificationCalls.map((MethodCall c) => c.method),
      isNot(contains('requestNotificationsPermission')),
    );
  });

  test('reminderTime()/setReminderTime() round-trip through preferences', () async {
    expect(await repository.reminderTime(), isNull);

    await repository.setReminderTime(const ReminderTime(hour: 8, minute: 30));
    expect(await repository.reminderTime(), const ReminderTime(hour: 8, minute: 30));

    await repository.setReminderTime(null);
    expect(await repository.reminderTime(), isNull);
  });

  // The bug that made the reminder look broken on a real device
  // (2026-09-18): the target was built with `tz.TZDateTime(tz.local, ...)`,
  // and `tz.local` is `Etc/UTC` unless `setLocalLocation` is called, which
  // nothing in this app does. A learner in Africa/Cairo (UTC+3) who asked
  // for 20:00 got an alarm for 20:00 UTC — 23:00 their time, and for an
  // evening reminder often the wrong day entirely. The test notification
  // used `show`, not `zonedSchedule`, so it arrived and hid the problem.
  test('the reminder is scheduled in the device wall clock, not UTC', () async {
    await repository.setReminderTime(const ReminderTime(hour: 20, minute: 0));

    final DateTime fires = lastScheduledInstant();

    expect(fires.hour, 20, reason: '20:00 means 20:00 where the learner is');
    expect(fires.minute, 0);
    expect(
      fires.isAfter(DateTime.now()),
      isTrue,
      reason: 'the next occurrence, never one already past',
    );
  });

  // A one-shot alarm fires once. Nothing re-armed it, so even a correctly
  // scheduled reminder was a single notification, not a daily one.
  test('restoreReminder arms the next occurrence once the last one has fired', () async {
    await repository.setReminderTime(const ReminderTime(hour: 20, minute: 0));

    // Stand where the app does the morning after: the pending instant is
    // in the past.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'settings.reminder_next_ms',
      DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    notificationCalls.clear();

    await repository.restoreReminder();

    // The call happening at all is the point: before this, nothing re-armed
    // the one-shot and the reminder was a single notification for life.
    final DateTime nextFires = lastScheduledInstant();
    expect(nextFires.hour, 20);
    expect(nextFires.minute, 0);
    expect(nextFires.isAfter(DateTime.now()), isTrue, reason: 'the next occurrence, not the one that fired');
  });

  // FR-048b: finishing a session skips *today*. Re-arming at the next
  // launch must not put it back.
  test('restoreReminder keeps a skipped reminder skipped', () async {
    await repository.setReminderTime(const ReminderTime(hour: 20, minute: 0));
    await repository.cancelTodaysReminder();
    final DateTime skippedFires = lastScheduledInstant();
    notificationCalls.clear();

    await repository.restoreReminder();

    final DateTime restoredFires = lastScheduledInstant();
    expect(restoredFires, skippedFires, reason: 'the same instant, not recomputed back onto today');
  });

  test('restoreReminder does nothing when no reminder is set', () async {
    await repository.restoreReminder();

    expect(notificationCalls.map((MethodCall c) => c.method), isNot(contains('zonedSchedule')));
  });

  // The second half of the 2026-09-18 report. Once the target time was
  // right, the reminder still didn't appear: `inexactAllowWhileIdle` maps
  // to `setAndAllowWhileIdle`, and `dumpsys alarm` on the device showed
  // Android had given it `windowLength 3600000` — an hour in which it may
  // deliver whenever it likes. For a time the learner picked themselves,
  // that is the whole failure.
  test('the reminder asks for an exact alarm when Android permits one', () async {
    exactAlarmsAllowed = true;

    await repository.setReminderTime(const ReminderTime(hour: 20, minute: 0));

    expect(lastScheduleMode(), 'exactAllowWhileIdle');
  });

  // Not exact unconditionally: `zonedSchedule` throws
  // `exact_alarms_not_permitted` without the grant, and a learner who
  // declines should get a late reminder, not none.
  test('a refused exact-alarm grant falls back rather than throwing', () async {
    exactAlarmsAllowed = false;

    await repository.setReminderTime(const ReminderTime(hour: 20, minute: 0));

    expect(lastScheduleMode(), 'inexactAllowWhileIdle');
    expect(await repository.exactAlarmsAllowed(), isFalse, reason: 'the screen can say so');
  });

  // Granting it later must actually take effect — `restoreReminder` re-reads
  // the permission every launch, so the next re-arm upgrades itself.
  test('restoreReminder upgrades to an exact alarm once the grant arrives', () async {
    exactAlarmsAllowed = false;
    await repository.setReminderTime(const ReminderTime(hour: 20, minute: 0));
    expect(lastScheduleMode(), 'inexactAllowWhileIdle');

    exactAlarmsAllowed = true;
    notificationCalls.clear();
    await repository.restoreReminder();

    expect(lastScheduleMode(), 'exactAllowWhileIdle');
  });

  test('wipeAllData preserves InstallIdentity and clears every other table, the key, and preferences', () async {
    await db.installDao.write(
      InstallIdentityCompanion.insert(installUuid: 'uuid-1', installId: 'install-1', mintedAt: DateTime.utc(2026)),
    );
    await db.into(db.streakDays).insert(StreakDaysCompanion.insert(day: '2026-01-01', creditedAt: DateTime.utc(2026)));
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            problemId: 'vp-1',
            day: '2026-01-01',
            path: SessionPath.trial,
            status: SessionStatus.complete,
            startedAt: DateTime.utc(2026),
          ),
        );
    keyRepository.storedKey = const LearnerKey(providerId: 'groq', value: 'gsk_secret');
    await repository.setReminderTime(const ReminderTime(hour: 7, minute: 0));

    await repository.wipeAllData();

    final InstallIdentityRow? identity = await db.installDao.read();
    expect(identity?.installId, 'install-1', reason: 'install identity must survive a wipe (FR-039f)');

    expect(await db.streakDao.completedDates(), isEmpty);
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(keyRepository.storedKey, isNull, reason: 'the key must be deleted from secure storage');
    expect(await repository.reminderTime(), isNull, reason: 'preferences are cleared too');
  });
}

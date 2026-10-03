import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../domain/reminder_time.dart';
import '../domain/settings_repository.dart';

/// `/settings/reminder` (FR-048a): one local daily reminder, defaulting
/// to the morning, cancelled the moment that day's session completes
/// (FR-048b, wired in `DailySessionCubit.endSessionUser`).
///
/// The screen now says whether the reminder can actually appear, and can
/// fire one on demand. Both exist because of the same defect: nothing ever
/// requested Android 13+'s `POST_NOTIFICATIONS`, so a learner could set a
/// reminder, be told nothing was wrong, and never see one — with no way to
/// tell a missing permission from a missing schedule without waiting a
/// day (reported 2026-09-04).
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> with WidgetsBindingObserver {
  bool _loaded = false;
  bool _enabled = false;
  bool _allowed = true;
  bool _exact = true;
  ReminderTime _time = ReminderTime.defaultTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// `SCHEDULE_EXACT_ALARM` is granted on a system page, not in a dialog,
  /// so the learner comes back to this screen having changed an answer it
  /// has no other way of hearing about. Re-reading on resume is what keeps
  /// the notice from still claiming a problem they just fixed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final SettingsRepository settings = sl<SettingsRepository>();
    final bool allowed = await settings.notificationsAllowed();
    final bool exact = await settings.exactAlarmsAllowed();
    if (!mounted) {
      return;
    }
    setState(() {
      _allowed = allowed;
      _exact = exact;
    });
  }

  Future<void> _load() async {
    final SettingsRepository settings = sl<SettingsRepository>();
    final ReminderTime? existing = await settings.reminderTime();
    final bool allowed = await settings.notificationsAllowed();
    final bool exact = await settings.exactAlarmsAllowed();
    if (!mounted) {
      return;
    }
    setState(() {
      _loaded = true;
      _enabled = existing != null;
      _allowed = allowed;
      _exact = exact;
      _time = existing ?? ReminderTime.defaultTime;
    });
  }

  /// Writes the current switch and time straight through.
  ///
  /// There is no Save button. A reminder is one switch and one time, and a
  /// screen that holds both hostage behind a third tap can be left in a
  /// state that looks set and is not — which is the failure this whole
  /// screen exists to prevent. Every change is the change, so the notice
  /// below always describes what is actually scheduled.
  ///
  /// `setReminderTime` raises Android's permission prompt itself when the
  /// reminder is being turned on, which is why the switch no longer asks
  /// separately: this is still the one moment the request has a reason the
  /// learner can see.
  Future<void> _persist() async {
    await sl<SettingsRepository>().setReminderTime(_enabled ? _time : null);
    // Read back rather than trusting the return: the same refresh runs on
    // resume, so both paths report permission state the one way.
    await _refreshPermissions();
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _enabled = value);
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reminderScreenTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderScreenTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.reminderScreenBody, style: context.appTypography.sansBody),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.reminderEnabledToggle, style: context.appTypography.sansBody),
                value: _enabled,
                onChanged: _onToggle,
              ),
              if (_enabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.reminderTimeLabel, style: context.appTypography.sansBody),
                  trailing: Text(
                    TimeOfDay(hour: _time.hour, minute: _time.minute).format(context),
                    style: context.appTypography.monoBody,
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute),
                    );
                    if (picked == null) {
                      return;
                    }
                    setState(() => _time = ReminderTime(hour: picked.hour, minute: picked.minute));
                    await _persist();
                  },
                ),
              if (_enabled) ...<Widget>[
                const SizedBox(height: 8),
                _Notice(
                  text: _allowed
                      ? l10n.reminderScheduledNotice(
                          TimeOfDay(hour: _time.hour, minute: _time.minute).format(context),
                        )
                      : l10n.reminderPermissionDeniedNotice,
                  hue: _allowed ? AppTokens.accent : AppTokens.amber,
                  icon: _allowed ? Icons.check_circle_outline : Icons.error_outline,
                ),
                if (!_allowed)
                  // Android stops showing its own dialog once the
                  // permission has been refused, so from here the app
                  // cannot ask again — it can only take the learner to the
                  // one place that can still change the answer.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => sl<SettingsRepository>().openNotificationSettings(),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.reminderOpenSettingsAction),
                    ),
                  ),
                // Only once notifications themselves are allowed: an
                // hour of drift is not the learner's problem yet if
                // nothing can be posted at all.
                if (_allowed && !_exact) ...<Widget>[
                  const SizedBox(height: 8),
                  _Notice(
                    text: l10n.reminderInexactNotice,
                    hue: AppTokens.amber,
                    icon: Icons.schedule,
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => sl<SettingsRepository>().openExactAlarmSettings(),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.reminderExactAlarmAction),
                    ),
                  ),
                ],
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.reminderPermissionNeededNotice,
                    style: context.appTypography.sansCaption.copyWith(color: AppTokens.faint),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One status line, hue paired with a glyph — never hue alone.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.hue, required this.icon});

  final String text;
  final Color hue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: Icon(icon, size: 16, color: hue),
        ),
        Expanded(
          child: Text(text, style: context.appTypography.sansCaption.copyWith(color: hue)),
        ),
      ],
    );
  }
}

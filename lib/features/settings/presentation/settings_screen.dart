import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import 'backend_badge.dart';

/// `/settings` — three rows, each its own screen (FR-006, FR-048a,
/// FR-039f). The prototype draws no settings screen at all (spec.md's
/// "screens the prototype does not draw"); built in the same tokens and
/// one-thing-per-row discipline as the rest.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsScreenTitle),
        actions: const <Widget>[
          Padding(padding: EdgeInsets.only(right: 16), child: Center(child: BackendBadge())),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: Text(l10n.settingsKeyManagementLabel, style: context.appTypography.sansBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.settingsKey.path),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.settingsReminderLabel, style: context.appTypography.sansBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.settingsReminder.path),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.settingsWipeLabel, style: context.appTypography.sansBody),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoute.settingsWipe.path),
            ),
          ],
        ),
      ),
    );
  }
}

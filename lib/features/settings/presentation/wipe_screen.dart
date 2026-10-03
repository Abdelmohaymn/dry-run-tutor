import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/settings_repository.dart';

/// `/settings/wipe` (FR-039f): one action, a clear warning that the
/// streak ends, and honest that a wipe restores neither the taster nor
/// install identity — `SettingsRepositoryImpl.wipeAllData` preserves
/// `InstallIdentity` deliberately, and this screen says so rather than
/// promising a clean slate the app cannot deliver.
class WipeScreen extends StatefulWidget {
  const WipeScreen({super.key});

  @override
  State<WipeScreen> createState() => _WipeScreenState();
}

class _WipeScreenState extends State<WipeScreen> {
  bool _wiping = false;

  /// The last step before an irreversible delete. Kept as a dialog rather
  /// than a second screen so the choice sits directly on top of the
  /// warning it is about, and defaults to cancelling: a barrier tap or a
  /// system back both dismiss it with nothing deleted.
  Future<void> _confirmThenWipe() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(l10n.wipeConfirmDialogTitle),
            content: Text(l10n.wipeConfirmDialogBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.wipeCancelAction),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.wipeConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _wipe();
  }

  Future<void> _wipe() async {
    setState(() => _wiping = true);
    await sl<SettingsRepository>().wipeAllData();
    if (!mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.wipeDoneNotice)));
    context.go(AppRoute.daily.path);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.wipeScreenTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l10n.wipeScreenWarning, style: context.appTypography.sansBody),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: _wiping ? null : _confirmThenWipe,
                  child: _wiping
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.wipeConfirmAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

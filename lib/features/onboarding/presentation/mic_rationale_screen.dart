import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/presentation/daily_session_cubit.dart';

/// Prototype screen 9. Shown **at first record, never at launch**
/// (FR-014), and gates `permission_handler` behind it — the system
/// permission dialog only appears after this screen, never before. Leads
/// with on-device recognition as a genuine claim, and states plainly that
/// conversation *text* (not audio) reaches the provider (Principle VII).
class MicRationaleScreen extends StatelessWidget {
  const MicRationaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.micRationaleTitle, style: context.appTypography.sansHeadline),
              const SizedBox(height: 16),
              Text(l10n.micRationaleBody, style: context.appTypography.sansBody),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _continue(context),
                  child: Text(l10n.micRationaleContinue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _continue(BuildContext context) async {
    await Permission.microphone.request();
    if (!context.mounted) {
      return;
    }
    // No explicit navigation here: DailySessionShell's BlocListener routes
    // to `/session/record` the moment `startRecording()` emits `Recording`
    // — an explicit pop racing that would risk undoing it.
    final DailySessionCubit cubit = context.read<DailySessionCubit>();
    await cubit.confirmMicRationaleSeen();
    await cubit.startRecording();
  }
}

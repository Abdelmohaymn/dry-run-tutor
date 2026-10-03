import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'daily_session_cubit.dart';
import 'daily_session_state.dart';

/// FR-021 — the **only** route a second solution request can be sent
/// from. There is no other call path into
/// `DailySessionCubit.confirmSolutionRelease()`, which is what makes this
/// warning unskippable rather than a dialog someone could dismiss past.
class ConfirmSolutionScreen extends StatelessWidget {
  const ConfirmSolutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // Reached with `go`, like every screen in this flow, so system back
    // had nothing to pop and closed the app. Backing out here means
    // "don't release the solution" — the same thing the Cancel button
    // means, routed through the same Cubit call so it cannot diverge.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          context.read<DailySessionCubit>().cancelSolutionRelease();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.confirmSolutionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: () => context.read<DailySessionCubit>().cancelSolutionRelease(),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<DailySessionCubit, DailySessionState>(
          builder: (BuildContext context, DailySessionState state) {
            if (state is! ConfirmSolutionRelease) {
              return const SizedBox.shrink();
            }
            final DailySessionCubit cubit = context.read<DailySessionCubit>();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(l10n.confirmSolutionWarning, style: context.appTypography.sansBody),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cubit.cancelSolutionRelease,
                          child: Text(l10n.confirmSolutionCancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: cubit.confirmSolutionRelease,
                          child: Text(l10n.confirmSolutionProceed),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

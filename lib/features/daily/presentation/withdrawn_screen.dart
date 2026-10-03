import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../problem/domain/problem_repository.dart';

/// `/withdrawn` (contracts/routes.md, FR-040) — "usually invisible: a
/// swap, not a screen". Reached only when `DailyRepository.forToday()`
/// found no non-withdrawn problem cached at all: every candidate is in
/// `killed_problem_ids`. Retries the manifest fetch and returns to `/`,
/// where a fresh session attempt runs again — this screen carries no
/// selection logic of its own to get wrong.
class WithdrawnScreen extends StatefulWidget {
  const WithdrawnScreen({required this.problemRepository, super.key});

  final ProblemRepository problemRepository;

  @override
  State<WithdrawnScreen> createState() => _WithdrawnScreenState();
}

class _WithdrawnScreenState extends State<WithdrawnScreen> {
  bool _retrying = false;

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
              Text(l10n.withdrawnTitle, style: context.appTypography.sansHeadline),
              const SizedBox(height: 16),
              Text(l10n.withdrawnBody, style: context.appTypography.sansBody),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _retrying ? null : () => _retry(context),
                  child: _retrying
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.withdrawnRetryAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retry(BuildContext context) async {
    setState(() => _retrying = true);
    try {
      await widget.problemRepository.prefetchManifest();
    } catch (_) {
      // FR-046-style fail open: staying on this screen with the button
      // re-enabled is the retry, not an error dialog.
    }
    if (!context.mounted) {
      return;
    }
    setState(() => _retrying = false);
    context.go(AppRoute.daily.path);
  }
}

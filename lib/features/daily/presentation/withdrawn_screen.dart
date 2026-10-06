import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../problem/domain/problem_repository.dart';

/// `/withdrawn` (contracts/routes.md, FR-040) — "usually invisible: a
/// swap, not a screen". Reached only when `DailyRepository.forToday()`
/// found no problem to serve: every candidate is withdrawn, or the relay
/// was unreachable with nothing cached. Returns to `/`, where a fresh
/// session attempt asks the relay again — this screen carries no
/// selection logic of its own to get wrong.
class WithdrawnScreen extends StatefulWidget {
  const WithdrawnScreen({required this.problemRepository, super.key});

  final ProblemRepository problemRepository;

  @override
  State<WithdrawnScreen> createState() => _WithdrawnScreenState();
}

class _WithdrawnScreenState extends State<WithdrawnScreen> {
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
                  onPressed: () => context.go(AppRoute.daily.path),
                  child: Text(l10n.withdrawnRetryAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

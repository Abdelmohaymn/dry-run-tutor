import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/brand.dart';

/// `/keys/wall` (prototype screen 10, FR-005a). Reached **only** after a
/// completed session — `DailySessionShell._routeFor` is the one place
/// that decides "completed" (a trial-path `CapReached`), so this screen
/// itself has no completion logic of its own to get wrong. Leads with
/// "you cannot be charged" before anything else, because that is the
/// one fact most likely to stop someone from continuing.
class WallScreen extends StatelessWidget {
  const WallScreen({super.key});

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
              Text(l10n.wallCannotBeCharged, style: context.appTypography.sansHeadline),
              const SizedBox(height: 16),
              Text(l10n.wallBody(AppBrand.name), style: context.appTypography.sansBody),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // `push`, so backing out of the form returns to this
                  // wall — which still explains the situation — rather
                  // than to an empty stack that closes the app.
                  onPressed: () => context.push(AppRoute.keysEntry.path),
                  child: Text(l10n.wallAddKey),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.go(AppRoute.daily.path),
                  child: Text(l10n.wallNotNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

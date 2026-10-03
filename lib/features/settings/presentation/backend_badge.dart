import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import '../../../core/config/flavor.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Which backend the settings badge announces.
enum BackendBadgeKind { devApi, prodApi }

/// Decides what the settings badge says, or `null` for no badge.
///
/// The relay is chosen by `config/*.json`, not by the Android flavor, so the
/// two axes can disagree. The badge is hidden only in the shipped combination
/// (a non-dev app on the prod relay); every other pairing says which relay it
/// is talking to.
BackendBadgeKind? backendBadgeKindFor({
  required String? androidFlavor,
  required Flavor backend,
}) {
  if (androidFlavor != 'dev' && backend == Flavor.prod) {
    return null;
  }
  return backend == Flavor.dev
      ? BackendBadgeKind.devApi
      : BackendBadgeKind.prodApi;
}

/// A small pill naming the relay this build talks to. Renders nothing in the
/// shipped build.
class BackendBadge extends StatelessWidget {
  const BackendBadge({super.key, this.androidFlavor = appFlavor, this.backend});

  final String? androidFlavor;
  final Flavor? backend;

  @override
  Widget build(BuildContext context) {
    final BackendBadgeKind? kind = backendBadgeKindFor(
      androidFlavor: androidFlavor,
      backend: backend ?? currentFlavor,
    );
    if (kind == null) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final (Color hue, Color dim, Color border, String label) = switch (kind) {
      BackendBadgeKind.devApi => (
        AppTokens.amber,
        AppTokens.amberDim,
        AppTokens.amberBorder,
        l10n.settingsBackendDevApi,
      ),
      BackendBadgeKind.prodApi => (
        AppTokens.accent,
        AppTokens.accentDim,
        AppTokens.accentBorder,
        l10n.settingsBackendProdApi,
      ),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: dim,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: context.appTypography.monoCaption.copyWith(color: hue),
        ),
      ),
    );
  }
}

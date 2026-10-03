import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../config/brand.dart';

/// `/update` (FR-048): `updateGuard` redirects here only when
/// `package_info_plus`'s installed version is below a config the app
/// actually has (`app_router.dart`'s `resolveAppRedirect` — an
/// unreachable config never produces this wall). A direct route to the
/// store listing the relay names in `update_url`, or the landing site
/// when it names none: there is no way to dismiss this screen back into
/// the app.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({this.updateUrl, super.key});

  /// `update_url` from the cached config. Null, or anything that is not
  /// an https URL, means [AppBrand.websiteUrl].
  final String? updateUrl;

  /// The URL the button opens, exposed for tests.
  @visibleForTesting
  Uri get target {
    final Uri? configured = updateUrl == null ? null : Uri.tryParse(updateUrl!);
    if (configured != null && configured.scheme == 'https' && configured.host.isNotEmpty) {
      return configured;
    }
    return Uri.parse(AppBrand.websiteUrl);
  }

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
              Text(l10n.updateRequiredTitle, style: context.appTypography.sansHeadline),
              const SizedBox(height: 16),
              Text(l10n.updateRequiredBody(AppBrand.name), style: context.appTypography.sansBody),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openStore,
                  child: Text(l10n.updateRequiredAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }
}

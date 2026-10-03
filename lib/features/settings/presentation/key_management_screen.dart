import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../keys/domain/key_repository.dart';
import '../../keys/domain/learner_key.dart';
import '../../keys/presentation/key_entry_form.dart';

/// `/settings/key` (FR-006): view, add, replace, delete. Reached with a
/// session already open or already ended — never mid-funnel — so, unlike
/// `/keys/entry`, this screen owns its own `KeyEntryCubit` rather than
/// sharing `DailySessionCubit`'s: there is no trial→keyed handover to
/// perform here (T094 already covers that path), only a stored
/// credential being swapped for a different one.
class KeyManagementScreen extends StatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  State<KeyManagementScreen> createState() => _KeyManagementScreenState();
}

class _KeyManagementScreenState extends State<KeyManagementScreen> {
  Future<LearnerKey?>? _keyFuture;
  bool _replacing = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _keyFuture = sl<KeyRepository>().read();
  }

  void _reload() {
    setState(() {
      _replacing = false;
      _keyFuture = sl<KeyRepository>().read();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_replacing ? l10n.keyEntryTitle : l10n.keyManagementTitle)),
      body: SafeArea(
        child: FutureBuilder<LearnerKey?>(
          future: _keyFuture,
          builder: (BuildContext context, AsyncSnapshot<LearnerKey?> snapshot) {
            if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final LearnerKey? key = snapshot.data;
            if (_replacing) {
              return KeyEntryForm(onSaved: (_, _) => _reload());
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_notice != null) ...<Widget>[
                    Text(_notice!, style: context.appTypography.sansCaption),
                    const SizedBox(height: 16),
                  ],
                  if (key == null) ...<Widget>[
                    Text(l10n.keyManagementNoKey, style: context.appTypography.sansBody),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => _replacing = true),
                        child: Text(l10n.keyManagementAddAction),
                      ),
                    ),
                  ] else ...<Widget>[
                    Text(
                      l10n.keyManagementProviderLabel(providerDisplayNames[key.providerId] ?? key.providerId),
                      style: context.appTypography.sansBody,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => _replacing = true),
                        child: Text(l10n.keyManagementReplaceAction),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          await sl<KeyRepository>().delete();
                          setState(() => _notice = l10n.keyManagementDeletedNotice);
                          _reload();
                        },
                        child: Text(l10n.keyManagementDeleteAction),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

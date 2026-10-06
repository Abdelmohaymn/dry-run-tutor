import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/remote_config_repository.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/errors/error_copy.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../domain/key_repository.dart';
import 'key_entry_cubit.dart';
import 'key_entry_state.dart';

/// Where a learner gets a free key for each offered provider — the app
/// never holds a provider base URL (contracts/relay-client.md), but a
/// signup page is not a routing decision and naming one here does not
/// violate that.
const Map<String, String> _freeKeyUrls = <String, String>{
  'groq': 'https://console.groq.com/keys',
  'gemini': 'https://aistudio.google.com/apikey',
  'nebius': 'https://tokenfactory.nebius.com',
};

const Map<String, String> providerDisplayNames = <String, String>{
  'groq': 'Groq',
  'gemini': 'Gemini',
  'nebius': 'Nebius',
};

/// The provider picker, disclosure, free-key link and key field shared by
/// `/keys/entry` and `/settings/key`, so a learner adding a key from
/// Settings sees which providers are accepted exactly as the funnel
/// shows them. Owns its `KeyEntryCubit`; [onSaved] runs once the key
/// has passed its probe and been stored.
class KeyEntryForm extends StatelessWidget {
  const KeyEntryForm({super.key, required this.onSaved});

  final void Function(BuildContext context, String providerId) onSaved;

  @override
  Widget build(BuildContext context) {
    final List<String> providers =
        sl<RemoteConfigRepository>().cached()?.keyedProviders ??
        const <String>[];
    return BlocProvider<KeyEntryCubit>(
      create: (_) => KeyEntryCubit(
        keyRepository: sl<KeyRepository>(),
        providers: providers,
      ),
      child: _KeyEntryFormView(onSaved: onSaved),
    );
  }
}

class _KeyEntryFormView extends StatefulWidget {
  const _KeyEntryFormView({required this.onSaved});

  final void Function(BuildContext context, String providerId) onSaved;

  @override
  State<_KeyEntryFormView> createState() => _KeyEntryFormViewState();
}

class _KeyEntryFormViewState extends State<_KeyEntryFormView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return BlocConsumer<KeyEntryCubit, KeyEntryState>(
      listener: (BuildContext context, KeyEntryState state) {
        if (state is KeyEntrySaved) {
          widget.onSaved(context, state.providerId);
        }
      },
      builder: (BuildContext context, KeyEntryState state) {
        if (state is KeyEntrySaved) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<String> providers = switch (state) {
          KeyEntryEntering(:final providers) => providers,
          KeyEntryProbing(:final providers) => providers,
          KeyEntryRejected(:final providers) => providers,
          KeyEntrySaved() => const <String>[],
        };
        final String providerId = switch (state) {
          KeyEntryEntering(:final providerId) => providerId,
          KeyEntryProbing(:final providerId) => providerId,
          KeyEntryRejected(:final providerId) => providerId,
          KeyEntrySaved(:final providerId) => providerId,
        };
        final bool probing = state is KeyEntryProbing;

        if (providers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.keyEntryNoProviders,
              style: context.appTypography.sansBody,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.keyEntryIntro, style: context.appTypography.sansBody),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final String id in providers)
                    ChoiceChip(
                      label: Text(providerDisplayNames[id] ?? id),
                      selected: providerId == id,
                      onSelected: probing
                          ? null
                          : (_) => context.read<KeyEntryCubit>().selectProvider(
                              id,
                            ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.keyEntryDisclosure(
                  providerDisplayNames[providerId] ?? providerId,
                ),
                style: context.appTypography.sansCaption,
              ),
              if (_freeKeyUrls[providerId] != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () =>
                        launchUrl(Uri.parse(_freeKeyUrls[providerId]!)),
                    child: Text(
                      l10n.keyEntryGetFreeKey(
                        providerDisplayNames[providerId] ?? providerId,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                enabled: !probing,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.keyEntryFieldLabel),
                onChanged: (String v) =>
                    context.read<KeyEntryCubit>().updateValue(v),
              ),
              if (state is KeyEntryRejected) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  resolveErrorCopy(l10n, state.error).message,
                  style: context.appTypography.sansCaption,
                ),
                Text(
                  l10n.errorCodeLabel(state.error.code),
                  style: context.appTypography.sansCaption.copyWith(color: AppTokens.faint),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: probing || _controller.text.isEmpty
                      ? null
                      : () => context.read<KeyEntryCubit>().submit(),
                  child: probing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.keyEntrySave),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

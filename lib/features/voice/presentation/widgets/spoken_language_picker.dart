import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../chat/presentation/daily_session_cubit.dart';
import '../../domain/spoken_language.dart';

/// FR-011b: one tap to say which language you are about to speak.
///
/// The platform recogniser accepts a single language per listen session
/// and offers no auto-detection, so a learner whose spoken language is not
/// their device language has no other way to be understood — found on a
/// physical device, where Arabic went unrecognised until asked for by name
/// (2026-08-28).
///
/// It sits beside the mic rather than in Settings deliberately: the choice
/// belongs at the moment of speaking, and switching back is one tap.
///
/// **Dormant.** Nothing builds this today: the app speaks English only
/// (`RecognitionServiceImpl.spokenLanguage`), because the problems, the
/// tutor and the assessment are all English, and offering to listen in a
/// language the tutor cannot answer in is a promise the app does not keep.
/// The widget, its sheet, `SpokenLanguage`, the repository and the Cubit's
/// three methods are all kept intact and working — restoring the choice is
/// unpinning that constant and passing this back to `Composer`'s
/// `languagePicker`.
class SpokenLanguagePicker extends StatefulWidget {
  const SpokenLanguagePicker({super.key});

  @override
  State<SpokenLanguagePicker> createState() => _SpokenLanguagePickerState();
}

class _SpokenLanguagePickerState extends State<SpokenLanguagePicker> {
  SpokenLanguage? _current;
  List<SpokenLanguage> _all = const <SpokenLanguage>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final DailySessionCubit cubit = context.read<DailySessionCubit>();
    final List<SpokenLanguage> all = await cubit.spokenLanguages();
    final SpokenLanguage? current = await cubit.currentSpokenLanguage();
    if (!mounted) {
      return;
    }
    setState(() {
      _all = all;
      _current = current;
    });
  }

  Future<void> _pick() async {
    final DailySessionCubit cubit = context.read<DailySessionCubit>();
    final SpokenLanguage? chosen = await showModalBottomSheet<SpokenLanguage>(
      context: context,
      showDragHandle: true,
      // The list is long by design — every locale the platform knows — so
      // it needs the full sheet and room for the keyboard above it.
      isScrollControlled: true,
      builder: (BuildContext sheetContext) =>
          _LanguageSheet(languages: _all, current: _current),
    );
    if (chosen == null) {
      return;
    }
    await cubit.setSpokenLanguage(chosen.localeId);
    if (!mounted) {
      return;
    }
    setState(() => _current = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final SpokenLanguage? current = _current;
    // Nothing useful to offer until the recogniser has answered, and a
    // single-language device has no choice to make.
    if (current == null || _all.length < 2) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: _pick,
      icon: const Icon(Icons.language, size: 16, color: AppTokens.faint),
      label: Text(
        current.name,
        style: context.appTypography.sansCaption.copyWith(color: AppTokens.faint),
      ),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    );
  }
}

/// The picker's list, with search. Separate from [SpokenLanguagePicker] so
/// typing rebuilds only the sheet.
class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.languages, required this.current});

  final List<SpokenLanguage> languages;
  final SpokenLanguage? current;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String query = _query.trim().toLowerCase();
    // Matching the locale tag too, so "ar" or "en-GB" finds a language as
    // readily as its name does.
    final List<SpokenLanguage> shown = query.isEmpty
        ? widget.languages
        : widget.languages
            .where((SpokenLanguage l) =>
                l.name.toLowerCase().contains(query) ||
                l.localeId.toLowerCase().replaceAll('_', '-').contains(query))
            .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.spokenLanguageSheetTitle,
                  style: context.appTypography.sansHeadline,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: false,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l10n.spokenLanguageSearchHint,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        l10n.spokenLanguageNoMatches,
                        style: context.appTypography.sansBody.copyWith(color: AppTokens.faint),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (BuildContext context, int index) {
                        final SpokenLanguage language = shown[index];
                        return ListTile(
                          title: Text(language.name),
                          subtitle: Text(language.localeId),
                          trailing: language.localeId == widget.current?.localeId
                              ? const Icon(Icons.check, color: AppTokens.accent)
                              : null,
                          onTap: () => Navigator.of(context).pop(language),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

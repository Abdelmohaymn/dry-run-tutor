import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../chat/presentation/daily_session_cubit.dart';
import 'key_entry_form.dart';

/// `/keys/entry` (prototype screen 11, FR-005b/d, FR-008a/e). Inside the
/// daily session's `ShellRoute` so `DailySessionCubit` survives the
/// visit — the trial→keyed handover (FR-007a/b) and mid-session
/// `InvalidKey` re-entry (FR-005c) both need the same conversation to
/// still be there when this screen pops.
class KeyEntryScreen extends StatelessWidget {
  const KeyEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // This screen is always *pushed* now — from the wall, from
    // `_FailureNotice`, and from `showKeyPrompt` — so there is normally
    // something to pop back to. `PopScope` is the guarantee rather than
    // the mechanism: reached with an empty stack, back must still land
    // on the conversation and never close the app. Adding a key is
    // optional (FR-005a's "Not now"), so leaving without one is a
    // legitimate outcome and needs no confirmation.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          _leave(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.keyEntryTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: l10n.backAction,
            onPressed: () => _leave(context),
          ),
        ),
        body: SafeArea(child: KeyEntryForm(onSaved: _onSaved)),
      ),
    );
  }

  /// Back out of key entry without saving. Pops to whatever pushed this
  /// — the conversation, or the wall — and falls back to the daily
  /// screen rather than letting an empty stack close the app.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoute.daily.path);
    }
  }

  void _onSaved(BuildContext context, String providerId) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    unawaited(context.read<DailySessionCubit>().promoteToKeyed(providerId));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.keyEntryAllowanceGrew)));
    context.go(AppRoute.daily.path);
  }
}

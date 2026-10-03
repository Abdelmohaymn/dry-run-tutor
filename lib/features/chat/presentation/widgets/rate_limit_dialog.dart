import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/relay_error.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../daily_session_cubit.dart';
import '../daily_session_state.dart';

/// Whether [state] is a turn held back by the provider's per-minute limit.
bool isRateLimited(DailySessionState state) =>
    state is Failure && state.error is RateLimited;

/// RATE_LIMITED on the learner's own key, said in a popup over the
/// conversation. It replaced a full "catching up" screen that never said
/// the limit was the key's. `DailySessionCubit` resends the turn by
/// itself once [retryAfter] has passed, and the popup closes on its own
/// as soon as the state moves off that failure.
Future<void> showRateLimitDialog(BuildContext context, Duration retryAfter) {
  final DailySessionCubit cubit = context.read<DailySessionCubit>();
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final int seconds = math.max(1, (retryAfter.inMilliseconds / 1000).ceil());
  bool closed = false;
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      void close() {
        // Once only: a second pop would take the conversation with it.
        if (closed) return;
        closed = true;
        Navigator.of(dialogContext).pop();
      }

      return BlocListener<DailySessionCubit, DailySessionState>(
        bloc: cubit,
        listenWhen: (_, DailySessionState current) => !isRateLimited(current),
        listener: (_, _) => close(),
        child: AlertDialog(
          title: Text(l10n.rateLimitTitle),
          content: Text(l10n.rateLimitBody(seconds)),
          actions: <Widget>[
            FilledButton(onPressed: close, child: Text(l10n.rateLimitOkAction)),
          ],
        ),
      );
    },
  ).whenComplete(() => closed = true);
}

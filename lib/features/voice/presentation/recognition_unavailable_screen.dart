import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/presentation/daily_session_cubit.dart';
import '../../chat/presentation/daily_session_state.dart';
import '../domain/recognition_availability.dart';

/// FR-011a: says why recognition is unavailable and permits the keyboard
/// **only while this condition holds**.
///
/// There is no "open settings" route, deliberately. The app uses the
/// platform's default recogniser, which needs no language pack, so there is
/// nothing the learner could install to fix either case. An earlier version
/// offered that button; on ColorOS it opened "Digital assistant app", which
/// fixes nothing — a button that cannot work is worse than no button.
class RecognitionUnavailableScreen extends StatelessWidget {
  const RecognitionUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<DailySessionCubit, DailySessionState>(
          builder: (BuildContext context, DailySessionState state) {
            if (state is! RecognitionUnavailable) {
              return const SizedBox.shrink();
            }
            final bool languageUnavailable =
                state.reason == RecognitionAvailability.languageUnavailable;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageUnavailable
                        ? l10n.recognitionUnavailableTitleLanguage
                        : l10n.recognitionUnavailableTitleUnsupported,
                    style: context.appTypography.sansHeadline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    languageUnavailable
                        ? l10n.recognitionUnavailableBodyLanguage
                        : l10n.recognitionUnavailableBodyUnsupported,
                    style: context.appTypography.sansBody,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () =>
                        context.read<DailySessionCubit>().dismissRecognitionUnavailable(),
                    child: Text(l10n.recognitionUnavailableTypeInstead),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

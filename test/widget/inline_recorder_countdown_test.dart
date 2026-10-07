// Cloud voice (plan T8.4): the inline recorder counts down to the clip limit
// and says the clip is being recorded for upload; without a limit it keeps the
// on-device count-up and "Listening" label.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/presentation/widgets/inline_recorder.dart';
import 'package:dry_run/features/voice/presentation/widgets/waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _pumpRecorder(
  WidgetTester tester, {
  required Duration elapsed,
  Duration? limit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InlineRecorder(
          elapsed: elapsed,
          limit: limit,
          levels: const <double>[0.1, 0.4, 0.2],
          warned: false,
          partialText: '',
          onStop: () {},
          onCancel: () {},
        ),
      ),
    ),
  );
  return AppLocalizations.of(tester.element(find.byType(InlineRecorder)))!;
}

void main() {
  testWidgets('with a 60s limit and 15s elapsed it counts down to 0:45 and shows the cloud label', (
    WidgetTester tester,
  ) async {
    final AppLocalizations l10n = await _pumpRecorder(
      tester,
      elapsed: const Duration(seconds: 15),
      limit: const Duration(seconds: 60),
    );

    expect(find.text(formatElapsed(const Duration(seconds: 45))), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    expect(find.text('0:15'), findsNothing);
    expect(find.text(l10n.recordingCloudLabel), findsOneWidget);
    expect(find.text(l10n.recordingListeningLabel), findsNothing);
  });

  testWidgets('past the limit the countdown stops at 0:00', (WidgetTester tester) async {
    await _pumpRecorder(
      tester,
      elapsed: const Duration(seconds: 70),
      limit: const Duration(seconds: 60),
    );

    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('without a limit it counts up and shows the Listening label', (WidgetTester tester) async {
    final AppLocalizations l10n = await _pumpRecorder(tester, elapsed: const Duration(seconds: 15));

    expect(find.text('0:15'), findsOneWidget);
    expect(find.text(l10n.recordingListeningLabel), findsOneWidget);
    expect(find.text(l10n.recordingCloudLabel), findsNothing);
  });
}

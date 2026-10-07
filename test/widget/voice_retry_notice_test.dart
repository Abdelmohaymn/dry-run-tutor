// Cloud voice (plan T8.4, decision D2): after a retryable upload failure the
// daily screen offers "Try again" and "Discard recording", and shows no error
// code line. Driven through the real cubit and a fake cloud repository.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_screen.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_cloud_voice_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_streak_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Two Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'Given an array of integers, return indices of the two numbers that add up to target.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

Session _session() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.keyed,
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

void main() {
  late FakeCloudVoiceRepository cloud;
  late DailySessionCubit cubit;
  late AppLocalizations l10n;

  setUp(() {
    cloud = FakeCloudVoiceRepository()..clipLimitToReturn = const Duration(seconds: 60);
    cubit = DailySessionCubit(
      sessionRepository: FakeSessionRepository()..initialSession = _session(),
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
          trial: TrialConfig(turnCap: 4),
          keyedProviders: <String>['groq'],
        ),
      micRationaleRepository: FakeMicRationaleRepository(),
      cloudVoiceRepository: cloud,
    );
  });

  tearDown(() => cubit.close());

  /// Mounts the daily screen and drives the real cubit into [VoiceUploadFailed].
  Future<void> pumpFailedUpload(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<DailySessionCubit>.value(value: cubit, child: const DailyScreen()),
      ),
    );
    await cubit.open();
    await tester.pump();
    await cubit.startRecording();
    await cubit.stopRecording();
    cloud.emitRetryable();
    await tester.pump();
    await tester.pump();
    l10n = AppLocalizations.of(tester.element(find.byType(DailyScreen)))!;
  }

  testWidgets('shows the retry title and body with no error code line', (WidgetTester tester) async {
    await pumpFailedUpload(tester);

    expect(cubit.state, isA<VoiceUploadFailed>());
    expect(find.text(l10n.recordingCloudRetryTitle), findsOneWidget);
    expect(find.text(l10n.recordingCloudRetryBody), findsOneWidget);
    expect(find.widgetWithText(FilledButton, l10n.retryAction), findsOneWidget);
    expect(find.widgetWithText(TextButton, l10n.recordingCloudDiscardAction), findsOneWidget);
    // The error-code line belongs to the generic failure notice, not this one.
    expect(find.textContaining('VOICE_'), findsNothing);
    expect(find.textContaining('Error code'), findsNothing);
  });

  testWidgets('Try again calls retryVoiceUpload and re-uploads the saved clip', (WidgetTester tester) async {
    await pumpFailedUpload(tester);
    cloud.retryResults.add(const FinalTextEvent('use a hashmap'));

    await tester.tap(find.widgetWithText(FilledButton, l10n.retryAction));
    await tester.pump();
    await tester.pump();

    expect(cloud.retryUploadCalls, 1);
    expect(cubit.state, isA<ReviewingTranscript>());
  });

  testWidgets('Discard recording calls discardVoiceClip and returns to the composer', (
    WidgetTester tester,
  ) async {
    await pumpFailedUpload(tester);

    await tester.tap(find.widgetWithText(TextButton, l10n.recordingCloudDiscardAction));
    await tester.pump();
    await tester.pump();

    expect(cloud.discardPendingCalls, 1);
    expect(cubit.state, isA<Composing>());
    expect(find.text(l10n.recordingCloudRetryTitle), findsNothing);
  });
}

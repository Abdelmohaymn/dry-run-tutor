import 'dart:async';

import 'package:dry_run/features/voice/domain/recognition_availability.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:dry_run/features/voice/domain/recognition_service.dart';
import 'package:dry_run/features/voice/domain/spoken_language.dart';

/// A plain, scriptable fake — no `speech_to_text`, no platform channel.
/// Tests drive recognition by calling [emit]; [listen] hands back the
/// same broadcast stream every call, mirroring how a real listen session
/// is expected to be used (one active session at a time).
class FakeRecognitionService implements RecognitionService {
  RecognitionAvailability availabilityToReturn = RecognitionAvailability.available;
  bool closeOnDone = false;

  final StreamController<RecognitionEvent> _controller = StreamController<RecognitionEvent>.broadcast();
  int stopCalls = 0;
  int cancelCalls = 0;
  int availabilityCalls = 0;

  @override
  Future<RecognitionAvailability> availability() async {
    availabilityCalls++;
    return availabilityToReturn;
  }

  List<SpokenLanguage> languagesToReturn = const <SpokenLanguage>[];
  SpokenLanguage? currentLanguageToReturn;
  final List<String> languagesSet = <String>[];

  @override
  Future<List<SpokenLanguage>> supportedLanguages() async => languagesToReturn;

  @override
  Future<SpokenLanguage?> currentLanguage() async => currentLanguageToReturn;

  @override
  Future<void> setLanguage(String localeId) async {
    languagesSet.add(localeId);
  }

  @override
  Stream<RecognitionEvent> listen() => _controller.stream;

  void emit(RecognitionEvent event) => _controller.add(event);

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  Future<void> dispose() => _controller.close();
}

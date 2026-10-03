import 'dart:async';

import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/transcript/domain/transcript_repair_repository.dart';

/// A plain, scriptable fake — no mocktail, no relay. Each call to [repair]
/// creates a new [Completer] the test controls the timing of via
/// [pendingCompleters], so a test can simulate a slow or fast repair
/// response without a real clock.
class FakeTranscriptRepairRepository implements TranscriptRepairRepository {
  final List<Completer<String?>> pendingCompleters = <Completer<String?>>[];
  final List<Session> callsForSession = <Session>[];
  int callCount = 0;

  @override
  Future<String?> repair({required Session session, required String transcript}) {
    callCount++;
    callsForSession.add(session);
    final Completer<String?> completer = Completer<String?>();
    pendingCompleters.add(completer);
    return completer.future;
  }
}

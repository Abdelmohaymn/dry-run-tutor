import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/dao/outbox_dao.dart';
import '../models/wire_enums.dart';
import '../time/trusted_time_source.dart';
import 'outbox_item.dart';
import 'outbox_repository.dart';

class OutboxRepositoryImpl implements OutboxRepository {
  OutboxRepositoryImpl({
    required OutboxDao outboxDao,
    required TrustedTimeSource timeSource,
    Uuid? uuid,
  })  : _outboxDao = outboxDao,
        _timeSource = timeSource,
        _uuid = uuid ?? const Uuid();

  final OutboxDao _outboxDao;
  final TrustedTimeSource _timeSource;
  final Uuid _uuid;

  @override
  Future<void> enqueue({
    required String sessionId,
    required OutboxKind kind,
    required Map<String, Object?> payload,
    required int solutionRequestCountAtEnqueue,
  }) async {
    final DateTime now = (await _timeSource.now()).utc;
    return _outboxDao.enqueue(
      OutboxCompanion.insert(
        id: _uuid.v4(),
        sessionId: sessionId,
        kind: kind,
        payload: jsonEncode(payload),
        solutionRequestCountAtEnqueue: solutionRequestCountAtEnqueue,
        // Eligible immediately — the drain worker itself decides whether
        // there is actually a connection to send over (research.md R-010).
        nextEligibleAt: now,
        createdAt: now,
      ),
    );
  }

  @override
  Future<List<OutboxItem>> due(DateTime trustedNow) async {
    final List<OutboxData> rows = await _outboxDao.due(trustedNow);
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<OutboxItem>> forSession(String sessionId) async {
    final List<OutboxData> rows = await _outboxDao.forSession(sessionId);
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> markAttempted({
    required String id,
    required DateTime nextEligibleAt,
    String? lastErrorCode,
  }) {
    return _outboxDao.markAttempted(id: id, nextEligibleAt: nextEligibleAt, lastErrorCode: lastErrorCode);
  }

  @override
  Future<void> incrementAttempts(String id) => _outboxDao.incrementAttempts(id);

  @override
  Future<void> remove(String id) => _outboxDao.remove(id);

  OutboxItem _toDomain(OutboxData row) => OutboxItem(
        id: row.id,
        sessionId: row.sessionId,
        kind: row.kind,
        payload: jsonDecode(row.payload) as Map<String, Object?>,
        solutionRequestCountAtEnqueue: row.solutionRequestCountAtEnqueue,
        attempts: row.attempts,
        nextEligibleAt: row.nextEligibleAt,
        lastErrorCode: row.lastErrorCode,
        createdAt: row.createdAt,
      );
}

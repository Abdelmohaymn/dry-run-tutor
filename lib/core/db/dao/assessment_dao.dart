import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'assessment_dao.g.dart';

/// Data access for the one assessment a session ever gets. `rawJson` is
/// kept verbatim alongside the mapped columns (FR-039e) — every write is
/// an upsert because `AssessmentRepositoryImpl.request` may legitimately
/// be called again after a transport failure that never reached the
/// relay at all.
@DriftAccessor(tables: [Assessments])
class AssessmentDao extends DatabaseAccessor<AppDatabase> with _$AssessmentDaoMixin {
  AssessmentDao(super.db);

  Future<AssessmentRow?> forSession(String sessionId) {
    return (select(assessments)..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();
  }

  Future<void> upsert(AssessmentsCompanion entry) {
    return into(assessments).insertOnConflictUpdate(entry);
  }

  Future<void> deleteForSession(String sessionId) {
    return (delete(assessments)..where((t) => t.sessionId.equals(sessionId))).go();
  }
}

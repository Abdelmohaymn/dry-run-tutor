// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assessment_dao.dart';

// ignore_for_file: type=lint
mixin _$AssessmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedProblemsTable get cachedProblems => attachedDatabase.cachedProblems;
  $SessionsTable get sessions => attachedDatabase.sessions;
  $AssessmentsTable get assessments => attachedDatabase.assessments;
  AssessmentDaoManager get managers => AssessmentDaoManager(this);
}

class AssessmentDaoManager {
  final _$AssessmentDaoMixin _db;
  AssessmentDaoManager(this._db);
  $$CachedProblemsTableTableManager get cachedProblems =>
      $$CachedProblemsTableTableManager(
        _db.attachedDatabase,
        _db.cachedProblems,
      );
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$AssessmentsTableTableManager get assessments =>
      $$AssessmentsTableTableManager(_db.attachedDatabase, _db.assessments);
}

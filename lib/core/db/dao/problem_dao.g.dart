// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem_dao.dart';

// ignore_for_file: type=lint
mixin _$ProblemDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedProblemsTable get cachedProblems => attachedDatabase.cachedProblems;
  ProblemDaoManager get managers => ProblemDaoManager(this);
}

class ProblemDaoManager {
  final _$ProblemDaoMixin _db;
  ProblemDaoManager(this._db);
  $$CachedProblemsTableTableManager get cachedProblems =>
      $$CachedProblemsTableTableManager(
        _db.attachedDatabase,
        _db.cachedProblems,
      );
}

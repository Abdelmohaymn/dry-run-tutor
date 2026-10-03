// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedProblemsTable get cachedProblems => attachedDatabase.cachedProblems;
  $SessionsTable get sessions => attachedDatabase.sessions;
  $DraftsTable get drafts => attachedDatabase.drafts;
  SessionDaoManager get managers => SessionDaoManager(this);
}

class SessionDaoManager {
  final _$SessionDaoMixin _db;
  SessionDaoManager(this._db);
  $$CachedProblemsTableTableManager get cachedProblems =>
      $$CachedProblemsTableTableManager(
        _db.attachedDatabase,
        _db.cachedProblems,
      );
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db.attachedDatabase, _db.sessions);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db.attachedDatabase, _db.drafts);
}

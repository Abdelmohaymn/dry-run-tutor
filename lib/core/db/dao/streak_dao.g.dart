// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'streak_dao.dart';

// ignore_for_file: type=lint
mixin _$StreakDaoMixin on DatabaseAccessor<AppDatabase> {
  $StreakDaysTable get streakDays => attachedDatabase.streakDays;
  StreakDaoManager get managers => StreakDaoManager(this);
}

class StreakDaoManager {
  final _$StreakDaoMixin _db;
  StreakDaoManager(this._db);
  $$StreakDaysTableTableManager get streakDays =>
      $$StreakDaysTableTableManager(_db.attachedDatabase, _db.streakDays);
}

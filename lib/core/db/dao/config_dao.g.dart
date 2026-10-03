// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_dao.dart';

// ignore_for_file: type=lint
mixin _$ConfigDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedConfigTable get cachedConfig => attachedDatabase.cachedConfig;
  ConfigDaoManager get managers => ConfigDaoManager(this);
}

class ConfigDaoManager {
  final _$ConfigDaoMixin _db;
  ConfigDaoManager(this._db);
  $$CachedConfigTableTableManager get cachedConfig =>
      $$CachedConfigTableTableManager(_db.attachedDatabase, _db.cachedConfig);
}

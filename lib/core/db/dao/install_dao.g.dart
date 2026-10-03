// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'install_dao.dart';

// ignore_for_file: type=lint
mixin _$InstallDaoMixin on DatabaseAccessor<AppDatabase> {
  $InstallIdentityTable get installIdentity => attachedDatabase.installIdentity;
  InstallDaoManager get managers => InstallDaoManager(this);
}

class InstallDaoManager {
  final _$InstallDaoMixin _db;
  InstallDaoManager(this._db);
  $$InstallIdentityTableTableManager get installIdentity =>
      $$InstallIdentityTableTableManager(
        _db.attachedDatabase,
        _db.installIdentity,
      );
}

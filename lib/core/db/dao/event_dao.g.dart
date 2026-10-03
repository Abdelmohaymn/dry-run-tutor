// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_dao.dart';

// ignore_for_file: type=lint
mixin _$EventDaoMixin on DatabaseAccessor<AppDatabase> {
  $BufferedEventsTable get bufferedEvents => attachedDatabase.bufferedEvents;
  EventDaoManager get managers => EventDaoManager(this);
}

class EventDaoManager {
  final _$EventDaoMixin _db;
  EventDaoManager(this._db);
  $$BufferedEventsTableTableManager get bufferedEvents =>
      $$BufferedEventsTableTableManager(
        _db.attachedDatabase,
        _db.bufferedEvents,
      );
}

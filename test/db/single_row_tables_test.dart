// `install_identity` and `cached_config` hold exactly one row each, and
// both key on `id INTEGER ... PRIMARY KEY` — which SQLite treats as an
// alias for the rowid. A rowid ignores the column's DEFAULT, so an insert
// that left `id` out was handed `max(rowid) + 1`: `insertOnConflictUpdate`
// had nothing to conflict with and appended instead of replacing.
//
// Two rows then made `getSingleOrNull()` throw `StateError: Too many
// elements` on every read, for good. That read sits under
// `ensureIdentity()`, which sits under every relay call the app makes, so
// on a real device it surfaced as "No connection." on the hint control
// and a dead analytics drain — with the network perfectly fine.
import 'package:dry_run/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('install_identity stays one row', () {
    test('a second write replaces the first rather than appending', () async {
      for (final String id in <String>['install-a', 'install-b']) {
        await db.installDao.write(
          InstallIdentityCompanion.insert(
            installUuid: 'uuid-1',
            installId: id,
            mintedAt: DateTime.utc(2026, 1, 1),
          ),
        );
      }

      expect((await db.select(db.installIdentity).get()).length, 1);
      expect((await db.installDao.read())!.installId, 'install-b');
    });

    test('read survives a database that already holds duplicates', () async {
      // The state a device reached before the id was pinned. The read must
      // answer rather than throw: migration 5 cleans this up, but a read
      // that cannot survive it is one bad write away from bricking the app.
      await db.customStatement(
        "INSERT INTO install_identity (id, install_uuid, install_id, minted_at) "
        "VALUES (1, 'uuid-1', 'first', 1000), (2, 'uuid-1', 'second', 2000)",
      );

      expect((await db.installDao.read())!.installId, 'first');
    });

    test('no row at all is null, not a throw', () async {
      expect(await db.installDao.read(), isNull);
    });
  });

  group('cached_config stays one row', () {
    Future<void> writeConfig(String json, DateTime at) => db.configDao.write(
          CachedConfigCompanion.insert(json: json, fetchedAt: at),
        );

    test('every fetch replaces the row rather than stacking one per launch', () async {
      // The original failure exactly: one write per successful
      // `/v1/config`, so the second launch of a fresh install was enough.
      await writeConfig('{"v":1}', DateTime.utc(2026, 1, 1));
      await writeConfig('{"v":2}', DateTime.utc(2026, 1, 2));
      await writeConfig('{"v":3}', DateTime.utc(2026, 1, 3));

      expect((await db.select(db.cachedConfig).get()).length, 1);
      expect((await db.configDao.read())!.json, '{"v":3}');
    });

    test('read returns the freshest of a duplicated pair', () async {
      await db.customStatement(
        "INSERT INTO cached_config (id, json, etag, fetched_at) "
        "VALUES (1, '{\"v\":1}', NULL, 1000), (2, '{\"v\":2}', NULL, 2000)",
      );

      expect((await db.configDao.read())!.json, '{"v":2}');
    });

    test('no row at all is null, not a throw', () async {
      expect(await db.configDao.read(), isNull);
    });
  });
}

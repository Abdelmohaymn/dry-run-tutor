import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/network/dto/install_dto.dart';
import 'package:dry_run/features/onboarding/data/install_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_device_id_platform.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

const String _hash = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

void main() {
  late AppDatabase db;
  late MockRelayClient relay;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relay = MockRelayClient();
    when(() => relay.install(any())).thenAnswer(
      (_) async => InstallResponseDto(installId: '$_hash.sig'),
    );
  });
  tearDown(() => db.close());

  Future<InstallRepositoryImpl> build(FakeDeviceIdPlatform platform) async {
    return InstallRepositoryImpl(
      relayClient: relay,
      installDao: db.installDao,
      prefs: await SharedPreferences.getInstance(),
      timeSource: FakeTrustedTimeSource(),
      deviceIdPlatform: platform,
    );
  }

  test('no stored identity: registers with the Android ID and keeps only the hash', () async {
    final InstallRepositoryImpl repo = await build(FakeDeviceIdPlatform());

    final Result<dynamic> result = await repo.ensureIdentity();

    expect(result, isA<Ok<dynamic>>());
    verify(() => relay.install('abc123def4567890')).called(1);
    final InstallIdentityRow stored = (await db.installDao.read())!;
    expect(stored.installUuid, _hash);
    expect(stored.installId, '$_hash.sig');
  });

  test('a stored identity is returned without calling the relay', () async {
    final InstallRepositoryImpl repo = await build(FakeDeviceIdPlatform());
    await repo.ensureIdentity();
    clearInteractions(relay);

    final Result<dynamic> result = await repo.ensureIdentity();

    expect(result, isA<Ok<dynamic>>());
    verifyNever(() => relay.install(any()));
  });

  test('no Android ID: Err(badRequest) and no relay call', () async {
    final InstallRepositoryImpl repo = await build(FakeDeviceIdPlatform(id: null));

    final Result<dynamic> result = await repo.ensureIdentity();

    expect(result, isA<Err<dynamic>>());
    expect((result as Err<dynamic>).error, const RelayError.badRequest());
    verifyNever(() => relay.install(any()));
    expect(await db.installDao.read(), isNull);
  });
}

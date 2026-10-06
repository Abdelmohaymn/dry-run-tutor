import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/dao/install_dao.dart';
import '../../../core/device/device_id_platform.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/dto/install_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/time/trusted_time_source.dart';
import '../domain/install_identity.dart';
import '../domain/install_repository.dart';

const String _welcomeSeenKey = 'onboarding.welcome_seen';

/// Set the moment the carousel hands off to the walkthrough, not when the
/// walkthrough completes — a learner who closes the app mid-practice has
/// still not seen it, and this flag is what says so on the next launch.
const String _practicePendingKey = 'onboarding.practice_pending';

class InstallRepositoryImpl implements InstallRepository {
  InstallRepositoryImpl({
    required RelayClient relayClient,
    required InstallDao installDao,
    required SharedPreferences prefs,
    required TrustedTimeSource timeSource,
    required DeviceIdPlatform deviceIdPlatform,
  })  : _relayClient = relayClient,
        _installDao = installDao,
        _prefs = prefs,
        _timeSource = timeSource,
        _deviceIdPlatform = deviceIdPlatform;

  final RelayClient _relayClient;
  final InstallDao _installDao;
  final SharedPreferences _prefs;
  final TrustedTimeSource _timeSource;
  final DeviceIdPlatform _deviceIdPlatform;

  @override
  Future<Result<InstallIdentity>> ensureIdentity() async {
    final InstallIdentityRow? existing = await _installDao.read();
    if (existing != null) {
      return Ok(InstallIdentity(installId: existing.installId, installUuid: existing.installUuid));
    }

    final String? deviceId = await _deviceIdPlatform.androidId();
    if (deviceId == null) {
      return const Err(RelayError.badRequest());
    }

    try {
      final InstallResponseDto response = await _relayClient.install(deviceId);
      // The relay answers with `<device_hash>.<sig>`; only the hash is kept.
      // The raw Android ID is never stored or logged.
      final String deviceHash = response.installId.split('.').first;
      await _installDao.write(
        InstallIdentityCompanion.insert(
          installUuid: deviceHash,
          installId: response.installId,
          mintedAt: (await _timeSource.now()).utc,
        ),
      );
      return Ok(InstallIdentity(installId: response.installId, installUuid: deviceHash));
    } on RelayException catch (e) {
      return Err(e.error);
    } catch (_) {
      return const Err(RelayError.transport());
    }
  }

  @override
  Future<bool> isWelcomeSeen() async => _prefs.getBool(_welcomeSeenKey) ?? false;

  @override
  Future<void> markWelcomeSeen() async {
    await _prefs.setBool(_welcomeSeenKey, true);
  }

  @override
  Future<bool> isPracticePending() async => _prefs.getBool(_practicePendingKey) ?? false;

  @override
  Future<void> setPracticePending(bool pending) async {
    await _prefs.setBool(_practicePendingKey, pending);
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/dao/install_dao.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/dto/install_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/time/trusted_time_source.dart';
import '../domain/install_identity.dart';
import '../domain/install_repository.dart';

/// `SharedPreferences` key holding a uuid that has been minted and posted
/// but not yet confirmed by the relay — read back by [ensureIdentity] so a
/// retry after a failed `POST /v1/install` sends the *same* uuid rather
/// than farming a fresh taster each attempt (FR-001).
const String _pendingUuidKey = 'onboarding.pending_install_uuid';
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
    Uuid? uuid,
  })  : _relayClient = relayClient,
        _installDao = installDao,
        _prefs = prefs,
        _timeSource = timeSource,
        _uuid = uuid ?? const Uuid();

  final RelayClient _relayClient;
  final InstallDao _installDao;
  final SharedPreferences _prefs;
  final TrustedTimeSource _timeSource;
  final Uuid _uuid;

  @override
  Future<Result<InstallIdentity>> ensureIdentity() async {
    final InstallIdentityRow? existing = await _installDao.read();
    if (existing != null) {
      return Ok(InstallIdentity(installId: existing.installId, installUuid: existing.installUuid));
    }

    final String installUuid = _prefs.getString(_pendingUuidKey) ?? _uuid.v4();
    await _prefs.setString(_pendingUuidKey, installUuid);

    try {
      final InstallResponseDto response = await _relayClient.install(installUuid);
      await _installDao.write(
        InstallIdentityCompanion.insert(
          installUuid: installUuid,
          installId: response.installId,
          mintedAt: (await _timeSource.now()).utc,
        ),
      );
      return Ok(InstallIdentity(installId: response.installId, installUuid: installUuid));
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

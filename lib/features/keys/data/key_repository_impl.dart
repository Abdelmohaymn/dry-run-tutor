import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/dto/chat_dto.dart';
import '../../../core/network/dto/turn_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/network/sse_parser.dart';
import '../../onboarding/domain/install_identity.dart';
import '../../onboarding/domain/install_repository.dart';
import '../../problem/domain/problem.dart';
import '../../problem/domain/problem_repository.dart';
import '../domain/key_repository.dart';
import '../domain/learner_key.dart';
import 'secure_key_store.dart';

const String _providerKey = 'keys.provider_id';
const String _valueKey = 'keys.value';

/// `key_check` requests still need a non-empty `messages` array to pass the
/// wire schema. The relay ignores the text.
const String _probeMessage = 'Checking that this key works before saving it.';

/// Checks a candidate key with `key_check: true` on `POST /v1/chat`. The
/// relay makes one tiny call on the candidate key's own provider
/// allowance, never the app's trial pool, and spends no turn. Before
/// `key_check` existed, the check was a full tutor turn on the first
/// available problem, often today's, so saving a key cost the learner a
/// turn (found on device 2026-09-25).
class KeyRepositoryImpl implements KeyRepository {
  KeyRepositoryImpl({
    required SecureKeyStore store,
    required RelayClient relayClient,
    required InstallRepository installRepository,
    required ProblemRepository problemRepository,
    required RemoteConfigRepository configRepository,
  })  : _store = store,
        _relayClient = relayClient,
        _installRepository = installRepository,
        _problemRepository = problemRepository,
        _configRepository = configRepository;

  final SecureKeyStore _store;
  final RelayClient _relayClient;
  final InstallRepository _installRepository;
  final ProblemRepository _problemRepository;
  final RemoteConfigRepository _configRepository;

  @override
  Future<LearnerKey?> read() async {
    final String? providerId = await _store.read(_providerKey);
    final String? value = await _store.read(_valueKey);
    if (providerId == null || value == null) {
      return null;
    }
    return LearnerKey(providerId: providerId, value: value);
  }

  @override
  Future<Result<void>> saveAndValidate(LearnerKey key) async {
    final Result<void> probe = await _probe(key);
    if (probe is Err<void>) {
      return probe;
    }
    await _store.write(_providerKey, key.providerId);
    await _store.write(_valueKey, key.value);
    return const Ok(null);
  }

  @override
  Future<void> delete() async {
    await _store.delete(_providerKey);
    await _store.delete(_valueKey);
  }

  @override
  List<String> offeredProviders(RuntimeConfig config) => config.keyedProviders;

  Future<Result<void>> _probe(LearnerKey key) async {
    final Result<InstallIdentity> identity = await _installRepository.ensureIdentity();
    if (identity is Err<InstallIdentity>) {
      return Err(identity.error);
    }
    final String installId = (identity as Ok<InstallIdentity>).value.installId;

    final RuntimeConfig config = _configRepository.cached() ?? await _configRepository.load();
    final Problem? problem = await _anyProbeProblem(config);
    if (problem == null) {
      // Nothing cached to probe against yet — cannot happen on the real
      // funnel (a key is only ever entered from within an already-open
      // session), but fails closed rather than persisting an unverified
      // key.
      return const Err(RelayError.transport());
    }

    final ChatRequestDto request = ChatRequestDto(
      problemId: problem.id,
      messages: <TurnDto>[TurnDto(role: 'user', text: _probeMessage)],
      keyCheck: true,
    );

    try {
      await for (final SseFrame frame in _relayClient.chat(
        installId: installId,
        request: request,
        userKey: key.value,
        providerId: key.providerId,
      )) {
        if (frame is MetaFrame) {
          return const Ok(null);
        }
      }
      return const Err(RelayError.unclearRetry());
    } on MissingMetaFailure {
      return const Err(RelayError.unclearRetry());
    } on RelayException catch (e) {
      return Err(e.error);
    } catch (_) {
      return const Err(RelayError.transport());
    }
  }

  Future<Problem?> _anyProbeProblem(RuntimeConfig config) async {
    final List<Problem> available = await _problemRepository.available(config);
    if (available.isEmpty) {
      return null;
    }
    final List<Problem> sorted = List<Problem>.of(available)
      ..sort((Problem a, Problem b) => a.id.compareTo(b.id));
    return sorted.first;
  }
}

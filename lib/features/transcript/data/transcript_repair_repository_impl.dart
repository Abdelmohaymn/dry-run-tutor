import '../../../core/errors/result.dart';
import '../../../core/models/wire_enums.dart';
import '../../../core/network/dto/repair_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../chat/domain/session.dart';
import '../../keys/domain/key_repository.dart';
import '../../keys/domain/learner_key.dart';
import '../../onboarding/domain/install_identity.dart';
import '../../onboarding/domain/install_repository.dart';
import '../domain/transcript_repair_repository.dart';

class TranscriptRepairRepositoryImpl implements TranscriptRepairRepository {
  TranscriptRepairRepositoryImpl({
    required RelayClient relayClient,
    required KeyRepository keyRepository,
    required InstallRepository installRepository,
  })  : _relayClient = relayClient,
        _keyRepository = keyRepository,
        _installRepository = installRepository;

  final RelayClient _relayClient;
  final KeyRepository _keyRepository;
  final InstallRepository _installRepository;

  @override
  Future<String?> repair({required Session session, required String transcript}) async {
    // The trial path never calls — repair is structurally unavailable there
    // (research.md R-009).
    if (session.path != SessionPath.keyed) return null;

    try {
      final LearnerKey? key = await _keyRepository.read();
      if (key == null) return null;

      final Result<InstallIdentity> identity = await _installRepository.ensureIdentity();
      if (identity is Err<InstallIdentity>) return null;
      final String installId = (identity as Ok<InstallIdentity>).value.installId;

      final RepairResponseDto response = await _relayClient.repair(
        installId: installId,
        request: RepairRequestDto(problemId: session.problem.id, transcript: transcript),
        userKey: key.value,
        providerId: key.providerId,
      );
      return response.changed ? response.repaired : null;
    } catch (_) {
      return null;
    }
  }
}

import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/features/onboarding/domain/install_identity.dart';
import 'package:dry_run/features/onboarding/domain/install_repository.dart';

class FakeInstallRepository implements InstallRepository {
  /// Defaults to *seen*, so every existing router test keeps asserting the
  /// guard it was written for rather than the welcome redirect. The
  /// welcome guard's own tests set it false explicitly.
  bool welcomeSeen = true;
  bool practicePending = false;
  InstallIdentity identity = const InstallIdentity(installId: 'fake-install-id', installUuid: 'fake-uuid');

  @override
  Future<Result<InstallIdentity>> ensureIdentity() async => Ok(identity);

  @override
  Future<bool> isWelcomeSeen() async => welcomeSeen;

  @override
  Future<void> markWelcomeSeen() async {
    welcomeSeen = true;
  }

  @override
  Future<bool> isPracticePending() async => practicePending;

  @override
  Future<void> setPracticePending(bool pending) async {
    practicePending = pending;
  }
}

import 'package:equatable/equatable.dart';

/// The install's whole identity (data-model.md §1, FR-001): no account, no
/// sign-in, no PII. `installUuid` is minted on device once; `installId` is
/// the relay's signed confirmation of it, sent as `X-Install-Id` on every
/// later authenticated call.
class InstallIdentity extends Equatable {
  const InstallIdentity({required this.installId, required this.installUuid});

  final String installId;
  final String installUuid;

  @override
  List<Object?> get props => <Object?>[installId, installUuid];
}

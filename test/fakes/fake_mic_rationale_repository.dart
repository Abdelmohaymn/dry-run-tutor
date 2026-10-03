import 'package:dry_run/features/voice/domain/mic_rationale_repository.dart';

class FakeMicRationaleRepository implements MicRationaleRepository {
  bool shown = true;

  @override
  Future<bool> hasBeenShown() async => shown;

  @override
  Future<void> markShown() async {
    shown = true;
  }
}

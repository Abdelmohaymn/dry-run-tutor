import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/relay_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TRIAL_IP_LIMIT maps to its own variant, not trialUnavailable', () {
    final RelayError error = mapErrorEnvelope(
      <String, Object?>{
        'error': <String, Object?>{'code': 'TRIAL_IP_LIMIT', 'message': 'x', 'retryable': false},
      },
      requestProblemId: 'vp-0001',
      callKind: RelayCallKind.chat,
    );
    expect(error, isA<TrialIpLimited>());
    expect(error.code, 'TRIAL_IP_LIMIT');
  });
}

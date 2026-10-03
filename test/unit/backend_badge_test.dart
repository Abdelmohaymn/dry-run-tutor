// The settings badge names the relay a build talks to. It hides only in the
// shipped pairing (a non-dev app on the prod relay); every other pairing of
// Android flavor and backend says which relay it is.
import 'package:dry_run/core/config/flavor.dart';
import 'package:dry_run/features/settings/presentation/backend_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<(String?, Flavor, BackendBadgeKind?)> cases =
      <(String?, Flavor, BackendBadgeKind?)>[
        ('dev', Flavor.dev, BackendBadgeKind.devApi),
        ('dev', Flavor.prod, BackendBadgeKind.prodApi),
        ('prod', Flavor.dev, BackendBadgeKind.devApi),
        ('prod', Flavor.prod, null),
        (null, Flavor.dev, BackendBadgeKind.devApi),
        (null, Flavor.prod, null),
      ];

  for (final (String? androidFlavor, Flavor backend, BackendBadgeKind? want)
      in cases) {
    test('flavor $androidFlavor on backend ${backend.name} -> $want', () {
      expect(
        backendBadgeKindFor(androidFlavor: androidFlavor, backend: backend),
        want,
      );
    });
  }
}

// T158 (Polish), SC-015: greyscale legibility through `golden_harness.dart`.
// Full 21-screen coverage needs live state for most routes (a session mid-
// conversation, an assessment, a streak) that is exercised correctly
// elsewhere (widget tests per feature) but is substantial harness work to
// duplicate here; this file covers every screen that renders from **no**
// live Cubit state — the ones a fresh install or a static settings visit
// actually reaches — as the first slice, verified against real font
// rendering rather than left unbuilt. The rest is tracked as follow-up in
// VERIFICATION.md; CI is what confirms these baselines actually match the
// runner Flutter resolves at PR time, not this sandbox alone.
import 'package:dry_run/core/router/placeholder_screen.dart';
import 'package:dry_run/core/update/update_required_screen.dart';
import 'package:dry_run/features/daily/presentation/withdrawn_screen.dart';
import 'package:dry_run/features/keys/presentation/wall_screen.dart';
import 'package:dry_run/features/onboarding/presentation/seeding_screen.dart';
import 'package:dry_run/features/settings/presentation/settings_screen.dart';
import 'package:dry_run/features/settings/presentation/wipe_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_problem_repository.dart';
import 'golden_harness.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  testWidgets('/keys/wall (prototype screen 10)', (WidgetTester tester) async {
    await tester.pumpWidget(goldenHarness(const WallScreen()));
    await expectLater(find.byType(WallScreen), matchesGoldenFile('goldens/wall_screen.png'));
  });

  testWidgets('/update — force update', (WidgetTester tester) async {
    await tester.pumpWidget(goldenHarness(const UpdateRequiredScreen()));
    await expectLater(find.byType(UpdateRequiredScreen), matchesGoldenFile('goldens/update_required_screen.png'));
  });

  testWidgets('/settings', (WidgetTester tester) async {
    await tester.pumpWidget(goldenHarness(const SettingsScreen()));
    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('goldens/settings_screen.png'));
  });

  testWidgets('/settings/wipe', (WidgetTester tester) async {
    await tester.pumpWidget(goldenHarness(const WipeScreen()));
    await expectLater(find.byType(WipeScreen), matchesGoldenFile('goldens/wipe_screen.png'));
  });

  testWidgets('/seeding — first-launch waiting screen', (WidgetTester tester) async {
    final _MockConnectivity connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());
    await tester.pumpWidget(
      goldenHarness(
        SeedingScreen(
          installRepository: FakeInstallRepository(),
          configRepository: FakeRemoteConfigRepository(),
          problemRepository: FakeProblemRepository(),
          connectivity: connectivity,
        ),
      ),
    );
    // Not `pumpAndSettle`: the screen carries its own indefinite spinner
    // while the (fake, never-succeeding) seed attempt is outstanding.
    await tester.pump();
    await expectLater(find.byType(SeedingScreen), matchesGoldenFile('goldens/seeding_screen.png'));
  });

  testWidgets('/withdrawn', (WidgetTester tester) async {
    await tester.pumpWidget(goldenHarness(WithdrawnScreen(problemRepository: FakeProblemRepository())));
    await expectLater(find.byType(WithdrawnScreen), matchesGoldenFile('goldens/withdrawn_screen.png'));
  });

  testWidgets('a route not yet built — placeholder greyscale sanity check', (WidgetTester tester) async {
    await tester.pumpWidget(goldenHarness(const PlaceholderScreen(routeName: 'example')));
    await expectLater(find.byType(PlaceholderScreen), matchesGoldenFile('goldens/placeholder_screen.png'));
  });
}

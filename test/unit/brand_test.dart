// The product name lives in one Dart constant (`AppBrand`), but three of its
// derived identifiers also exist on the Android side, where no Dart constant
// can reach them: the launcher label, the applicationId/namespace, the Kotlin
// package, and the deep-link scheme. A rename that updates `brand.dart` and
// misses one of those does not fail to compile — it ships a wrong launcher
// label, or a deep link that silently resolves to nothing.
//
// The Android side now has two flavors, `dev` and `prod`. `dev` adds an
// applicationId suffix, its own launcher label ("<name> Dev") and its own
// deep-link scheme, so the two can be installed side by side. The prod values
// live in `defaultConfig`/`main`; the dev overrides live in the `dev`
// productFlavor and `android/app/src/dev`. Both sets are asserted here.
//
// This is the structural peer of `no_answer_format_test.dart` (T166) and
// `cubit_actions_reachable_test.dart` (T169): assert across the boundary the
// type system cannot see.
import 'dart:io';

import 'package:dry_run/core/config/brand.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_test/flutter_test.dart';

String _read(String path) {
  final File file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist');
  return file.readAsStringSync();
}

void main() {
  test('strings.xml app_name matches AppBrand.name', () {
    final String xml = _read('android/app/src/main/res/values/strings.xml');
    expect(
      xml,
      contains('<string name="app_name">${AppBrand.name}</string>'),
      reason: 'The launcher label is rendered before Dart runs, so it cannot read AppBrand. '
          'Change it by hand whenever AppBrand.name changes.',
    );
  });

  test('dev strings.xml app_name is "<name> Dev"', () {
    final String xml = _read('android/app/src/dev/res/values/strings.xml');
    expect(
      xml,
      contains('<string name="app_name">${AppBrand.name} Dev</string>'),
      reason: 'The dev flavor overrides the launcher label so both apps can be told apart.',
    );
  });

  test('build.gradle.kts identity matches AppBrand', () {
    final String gradle = _read('android/app/build.gradle.kts');
    expect(gradle, contains('applicationId = "${AppBrand.prodPackageId}"'));
    expect(gradle, contains('namespace = "${AppBrand.androidNamespace}"'));
    expect(gradle, contains('applicationIdSuffix = "${AppBrand.devApplicationIdSuffix}"'));
    expect(
      gradle,
      contains('manifestPlaceholders["deepLinkScheme"] = "${AppBrand.devDeepLinkScheme}"'),
    );
    expect(
      gradle,
      contains('manifestPlaceholders["deepLinkScheme"] = "${AppBrand.prodDeepLinkScheme}"'),
    );
  });

  test('the Kotlin sources declare AppBrand.androidNamespace as their package', () {
    final Directory kotlinRoot = Directory('android/app/src/main/kotlin');
    final List<File> sources = kotlinRoot
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.kt'))
        .toList();
    expect(sources, isNotEmpty, reason: 'the platform channels must still exist');

    for (final File source in sources) {
      expect(
        source.readAsStringSync(),
        contains('package ${AppBrand.androidNamespace}'),
        reason: '${source.path} is not in the ${AppBrand.androidNamespace} package',
      );
    }
  });

  test('the Kotlin method channels are namespaced by AppBrand.channelPrefix', () {
    // Every `MethodChannel(...)` the Dart side opens is built from
    // `AppBrand.channelPrefix`; the Kotlin end hardcodes its own string. A
    // mismatch is a MissingPluginException at runtime on a real device only.
    expect(AppBrand.channelPrefix, 'app.dryrun');
    for (final String channel in <String>['trusted_time', 'on_device_recognizer']) {
      final bool declared = Directory('android/app/src/main/kotlin')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.kt'))
          .any((File f) => f.readAsStringSync().contains('"${AppBrand.channelPrefix}/$channel"'));
      expect(
        declared,
        isTrue,
        reason: 'No Kotlin source declares the channel "${AppBrand.channelPrefix}/$channel"',
      );
    }
  });

  test('AndroidManifest takes the deep-link scheme from the flavor placeholder', () {
    final String manifest = _read('android/app/src/main/AndroidManifest.xml');
    expect(
      manifest,
      contains('android:scheme="\${deepLinkScheme}"'),
      reason: 'app_router.dart routes ${AppBrand.deepLinkScheme}://p/<id>; '
          'without the manifest filter nothing ever reaches it.',
    );
  });

  test('AppBrand identity follows the Android flavor', () {
    // `flutter test` runs as `dev` (default-flavor); under `--flavor prod` the
    // same assertions must hold, so nothing here hardcodes one flavor.
    expect(AppBrand.isDevApp, appFlavor == 'dev');
    expect(
      AppBrand.packageId,
      AppBrand.isDevApp ? AppBrand.devPackageId : AppBrand.prodPackageId,
    );
    expect(
      AppBrand.deepLinkScheme,
      AppBrand.isDevApp ? AppBrand.devDeepLinkScheme : AppBrand.prodDeepLinkScheme,
    );
    expect(AppBrand.devPackageId, 'app.dryrun.dev');
    expect(AppBrand.prodPackageId, 'app.dryrun');
    expect(AppBrand.channelPrefix, 'app.dryrun');
  });

  test('pubspec name matches the Dart package AppBrand implies', () {
    // `package:dry_run/...` is what every import in lib/ and test/ says; the
    // pubspec is where that name is actually defined.
    expect(_read('pubspec.yaml'), contains('name: ${AppBrand.databaseName}'));
  });
}

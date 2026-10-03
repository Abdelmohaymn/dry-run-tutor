// The update wall's button opens the store the relay names in
// `update_url`, and falls back to the landing site for anything else.
import 'package:dry_run/core/config/brand.dart';
import 'package:dry_run/core/update/update_required_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens the configured https store listing', () {
    const UpdateRequiredScreen screen =
        UpdateRequiredScreen(updateUrl: 'https://dry-run.en.uptodown.com/android');
    expect(screen.target.toString(), 'https://dry-run.en.uptodown.com/android');
  });

  test('falls back to the landing site when the relay names no store', () {
    expect(const UpdateRequiredScreen().target.toString(), AppBrand.websiteUrl);
  });

  test('falls back to the landing site for a non-https or malformed url', () {
    for (final String url in <String>['http://example.com/', 'market://details?id=app.dryrun', 'not a url', '']) {
      expect(UpdateRequiredScreen(updateUrl: url).target.toString(), AppBrand.websiteUrl, reason: url);
    }
  });
}

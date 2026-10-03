// Option 3 of the 2026-10-02 error-handling pass: an error nobody expected
// shows a popup with a code the learner can send back, instead of a frozen
// screen with nothing to report.
import 'package:dry_run/core/errors/crash_reporter.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashReport', () {
    test('the same bug gets the same code', () {
      final StackTrace stack = StackTrace.fromString('#0 foo (package:dry_run/a.dart:1:1)\n#1 bar');
      final CrashReport a = CrashReport.from(StateError('x'), stack, appVersion: '1.0.2');
      final CrashReport b = CrashReport.from(StateError('y'), stack, appVersion: '1.0.2');
      expect(a.code, b.code);
      expect(a.code, matches(RegExp(r'^APP-[0-9A-F]{6}$')));
    });

    test('a different error type gets a different code', () {
      final StackTrace stack = StackTrace.fromString('#0 foo (package:dry_run/a.dart:1:1)');
      final CrashReport a = CrashReport.from(StateError('x'), stack, appVersion: '1.0.2');
      final CrashReport b = CrashReport.from(ArgumentError('x'), stack, appVersion: '1.0.2');
      expect(a.code, isNot(b.code));
    });

    test('details carry version and code, and never a key', () {
      final CrashReport crash = CrashReport.from(
        StateError('bad key gsk_abcdefghijklmnopqrstuvwxyz0123 and AIzaSyA1234567890abcdefghijklmnop'),
        StackTrace.empty,
        appVersion: '1.0.2',
      );
      expect(crash.details, contains('Version: 1.0.2'));
      expect(crash.details, contains('Code: ${crash.code}'));
      expect(crash.details, isNot(contains('gsk_abcdefghijklmnopqrstuvwxyz0123')));
      expect(crash.details, isNot(contains('AIzaSyA1234567890abcdefghijklmnop')));
    });
  });

  testWidgets('an unexpected error shows the popup with its code, and Copy details copies them', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    final CrashReporter reporter = CrashReporter(navigatorKey: navigatorKey, appVersion: '1.0.2', showPopup: true);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final StateError error = StateError('boom');
    final CrashReport expected = CrashReport.from(error, StackTrace.empty, appVersion: '1.0.2');
    reporter.report(error, StackTrace.empty);
    reporter.report(StateError('second'), StackTrace.empty); // one popup at a time
    await tester.pumpAndSettle();

    expect(find.text('Something broke'), findsOneWidget);
    expect(find.textContaining(expected.code), findsOneWidget);

    await tester.tap(find.text('Copy details'));
    await tester.pumpAndSettle();
    expect(copied, contains(expected.code));
    expect(find.text('Something broke'), findsNothing);
  });
}

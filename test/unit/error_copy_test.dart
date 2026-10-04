// SC-008 / FR-044: every relay error code produces a distinct, actionable
// message — none shares a key with another variant, and none resolves to
// an empty string. This test enumerates every branch of the sealed
// `RelayError` union by hand (Dart has no runtime reflection over sealed
// subtypes) precisely so that adding a twelfth variant to the union
// without adding it here is a visible gap, not a silent one — the
// `resolveErrorCopy` switch itself already refuses to compile without a
// branch for every variant, and this test is the second lock on the same
// door: it catches a branch that compiles but was wired to a placeholder.
import 'package:dry_run/core/errors/error_copy.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  final List<RelayError> everyVariant = <RelayError>[
    RelayError.rateLimited(retryAfter: const Duration(seconds: 5)),
    const RelayError.invalidKey(),
    const RelayError.quotaExhausted(),
    const RelayError.unclearRetry(),
    const RelayError.turnCapReached(),
    const RelayError.trialConsumed(),
    RelayError.sessionAlreadyJudged(ctx: JudgedContext.repeatJudge),
    RelayError.sessionAlreadyJudged(ctx: JudgedContext.turnAfterVerdict),
    const RelayError.emptyTurn(),
    const RelayError.trialUnavailable(),
    const RelayError.trialIpLimited(),
    RelayError.problemKilled(problemId: 'vp-0001'),
    const RelayError.badRequest(),
    const RelayError.transport(),
  ];

  test('every variant resolves to a non-empty message', () {
    for (final RelayError error in everyVariant) {
      final ErrorCopy copy = resolveErrorCopy(l10n, error);
      expect(
        copy.message.trim(),
        isNotEmpty,
        reason: '$error resolved to an empty message',
      );
    }
  });

  test('no two variants share a message', () {
    final List<String> messages =
        everyVariant.map((RelayError e) => resolveErrorCopy(l10n, e).message).toList();
    expect(
      messages.toSet(),
      hasLength(messages.length),
      reason: 'two RelayError variants resolved to the same ARB string',
    );
  });

  test('every variant carries a next action', () {
    for (final RelayError error in everyVariant) {
      final ErrorCopy copy = resolveErrorCopy(l10n, error);
      expect(copy.nextAction, isNotNull);
    }
  });

  test(
    'SESSION_ALREADY_JUDGED splits into err_already_judged_repeat and err_session_closed',
    () {
      final ErrorCopy repeat = resolveErrorCopy(
        l10n,
        RelayError.sessionAlreadyJudged(ctx: JudgedContext.repeatJudge),
      );
      final ErrorCopy closed = resolveErrorCopy(
        l10n,
        RelayError.sessionAlreadyJudged(ctx: JudgedContext.turnAfterVerdict),
      );
      expect(repeat.message, l10n.errAlreadyJudgedRepeat);
      expect(closed.message, l10n.errSessionClosed);
      expect(repeat.message, isNot(closed.message));
    },
  );

  test('no connection offers a Try again button, not a silent wait', () {
    final ErrorCopy copy = resolveErrorCopy(l10n, const RelayError.transport());
    expect(copy.message, l10n.errOfflineQueued);
    expect(copy.nextAction, ErrorNextAction.retryWhenOnline);
  });

  test('every variant carries its catalogue code for support requests', () {
    final List<String> codes =
        everyVariant.map((RelayError e) => resolveErrorCopy(l10n, e).code).toList();
    expect(codes.every((String c) => RegExp(r'^[A-Z_]+$').hasMatch(c)), isTrue, reason: '$codes');
    expect(resolveErrorCopy(l10n, const RelayError.emptyTurn()).code, 'EMPTY_TURN');
    expect(resolveErrorCopy(l10n, const RelayError.transport()).code, 'NETWORK');
    // The two SESSION_ALREADY_JUDGED contexts share one wire code; every
    // other variant has its own.
    expect(codes.toSet(), hasLength(codes.length - 1));
  });
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Bans `DateTime.now()` outside `lib/core/time/` (Principle IX).
///
/// `TrustedTimeSource` is the only sanctioned way to ask "what time is it".
/// A direct `DateTime.now()` call anywhere else reads the device wall
/// clock, which a learner can move by hand to game the streak (FR-038) or
/// to unlock a day early (FR-047c) — the whole point of trusted time is
/// that no such code path exists.
class NoWallClock extends DartLintRule {
  const NoWallClock() : super(code: _code);

  static const _code = LintCode(
    name: 'no_wall_clock',
    problemMessage: 'DateTime.now() reads the device clock directly; use TrustedTimeSource instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!_isLintable(resolver.path)) {
      return;
    }

    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'now') {
        return;
      }
      final Expression? target = node.target;
      if (target == null || target.toString() != 'DateTime') {
        return;
      }
      reporter.atNode(node, _code);
    });
  }

  /// Only `lib/`, and never `lib/core/time/` — the one place trusted time
  /// is actually implemented and is allowed to read platform clocks.
  static bool _isLintable(String path) {
    final String normalized = path.replaceAll('\\', '/');
    if (!normalized.contains('/lib/')) {
      return false;
    }
    return !normalized.contains('/lib/core/time/');
  }
}

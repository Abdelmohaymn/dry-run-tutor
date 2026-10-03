import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Bans a bare string literal as the child of a `Text(...)` widget under
/// `lib/features/` or `lib/shared/`; every learner-facing string must
/// resolve through an ARB key so it exists in `lib/l10n/app_en.arb` from
/// the first commit (FR-052).
///
/// Scoped deliberately to `Text(...)`'s own argument rather than every
/// string literal in the codebase — a lint that also flagged route paths,
/// Drift column names, and analytics event names would be noise a reviewer
/// learns to ignore, which defeats the point. `Text.rich` is exempted: its
/// children are `TextSpan`s already built from resolved strings elsewhere.
class NoStringLiteralsInWidgets extends DartLintRule {
  const NoStringLiteralsInWidgets() : super(code: _code);

  static const _code = LintCode(
    name: 'no_string_literals_in_widgets',
    problemMessage: 'Learner-facing text must come from AppLocalizations, not a string literal.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String normalized = resolver.path.replaceAll('\\', '/');
    final bool inScope = normalized.contains('/lib/features/') || normalized.contains('/lib/shared/');
    if (!inScope) {
      return;
    }

    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Text') {
        return;
      }
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) {
        return;
      }
      final Expression first = args.first;
      if (first is SimpleStringLiteral || first is StringInterpolation) {
        reporter.atNode(first, _code);
      }
    });
  }
}

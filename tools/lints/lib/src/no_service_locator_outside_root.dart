import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Bans `sl<T>()` outside `core/di/service_locator.dart`, `main()`, and
/// `BlocProvider(create: ...)`.
///
/// `get_it` is wired at exactly one place (`core/di/service_locator.dart`
/// itself, where every registration closure legitimately resolves its own
/// constructor dependencies with `sl<T>()`) and resolved at exactly two
/// others: the composition root in `main()`, and the `create:` callback of
/// the `BlocProvider` that owns a Cubit at the route that pushes it.
/// Anywhere else, a Cubit or repository reaching for `sl` directly is what
/// turns `get_it` into the anti-pattern the constitution warns against —
/// it also breaks `bloc_test`'s ability to construct a Cubit from a plain
/// fake with no locator set up.
class NoServiceLocatorOutsideRoot extends DartLintRule {
  const NoServiceLocatorOutsideRoot() : super(code: _code);

  static const _code = LintCode(
    name: 'no_service_locator_outside_root',
    problemMessage:
        'sl<T>() may only be called from core/di/service_locator.dart, main(), or a BlocProvider(create:) callback.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final String normalized = resolver.path.replaceAll('\\', '/');
    if (!normalized.contains('/lib/') || normalized.endsWith('/lib/core/di/service_locator.dart')) {
      return;
    }

    context.registry.addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      if (node.function.toString() != 'sl') {
        return;
      }
      if (_isInAllowedContext(node)) {
        return;
      }
      reporter.atNode(node, _code);
    });
  }

  static bool _isInAllowedContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionDeclaration && current.name.lexeme == 'main') {
        return true;
      }
      if (current is NamedExpression && current.name.label.name == 'create') {
        final AstNode? argumentList = current.parent;
        final AstNode? creation = argumentList?.parent;
        if (creation is InstanceCreationExpression &&
            creation.constructorName.type.toString().contains('BlocProvider')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

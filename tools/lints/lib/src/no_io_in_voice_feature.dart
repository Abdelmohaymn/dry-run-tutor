import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Bans `dart:io`, `path_provider`, and HTTP client imports under
/// `lib/features/voice/` — the import-boundary half of Constitution VII
/// and FR-011 ("no audio pipeline at all").
///
/// `speech_to_text` hands the feature text and a sound-level stream; there
/// is nothing here that should ever need a file or a socket. This lint is
/// what turns that absence into a property of the codebase rather than a
/// promise kept by review — a filesystem or network import appearing under
/// this directory is a design violation, not a style nit.
class NoIoInVoiceFeature extends DartLintRule {
  const NoIoInVoiceFeature() : super(code: _code);

  static const _code = LintCode(
    name: 'no_io_in_voice_feature',
    problemMessage: 'lib/features/voice/ may not import dart:io, path_provider, or an HTTP client.',
  );

  static const List<String> _bannedExact = <String>['dart:io'];

  static const List<String> _bannedPackagePrefixes = <String>[
    'package:path_provider/',
    'package:dio/',
    'package:http/',
  ];

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.path.replaceAll('\\', '/').contains('/lib/features/voice/')) {
      return;
    }

    context.registry.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) {
        return;
      }
      final bool banned = _bannedExact.contains(uri) ||
          _bannedPackagePrefixes.any((String prefix) => uri.startsWith(prefix));
      if (banned) {
        reporter.atNode(node, _code);
      }
    });
  }
}

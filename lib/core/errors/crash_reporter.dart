import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../network/redacting_log_interceptor.dart';

/// The last line of error handling: anything the app did not expect — a
/// bug, not a relay error — lands here instead of freezing the screen
/// silently. Relay errors never reach this; they have their own copy and
/// code (`error_copy.dart`).
///
/// The learner sees a short code and can copy the details to send back.
/// The same bug always gets the same code (it is a hash of the error type
/// and the first stack frame), so two testers reporting `APP-3F2A1C` are
/// reporting the same thing.
class CrashReporter {
  CrashReporter({
    required this.navigatorKey,
    required this.appVersion,
    this.showPopup = !kDebugMode,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String appVersion;

  /// Off in debug builds: there the red error screen and the console
  /// already say everything, and a popup per layout overflow would be noise.
  final bool showPopup;

  bool _dialogOpen = false;

  void install() {
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previous?.call(details);
      if (!details.silent) {
        report(details.exception, details.stack);
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('Uncaught: $error\n$stack');
      report(error, stack);
      return true;
    };
  }

  void report(Object error, StackTrace? stack) {
    if (!showPopup || _dialogOpen) {
      return;
    }
    final CrashReport crash = CrashReport.from(error, stack, appVersion: appVersion);
    // Never show a dialog in the middle of a build or layout pass that just
    // threw; wait for the frame to finish.
    WidgetsBinding.instance.addPostFrameCallback((_) => _show(crash));
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _show(CrashReport crash) async {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null || _dialogOpen) {
      return;
    }
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => CrashDialog(crash: crash),
      );
    } finally {
      _dialogOpen = false;
    }
  }
}

/// What the learner can copy and send. Redacted the same way log lines
/// are, so a key that ended up in an exception message never leaves.
class CrashReport {
  const CrashReport({required this.code, required this.details});

  factory CrashReport.from(Object error, StackTrace? stack, {required String appVersion, DateTime? now}) {
    final List<String> frames =
        (stack?.toString() ?? '').split('\n').where((String l) => l.trim().isNotEmpty).take(8).toList();
    final String type = error.runtimeType.toString();
    final String code = 'APP-${_hash('$type ${frames.isEmpty ? '' : frames.first}')}';
    final String details = <String>[
      'Code: $code',
      'Version: $appVersion',
      'Time: ${(now ?? DateTime.now()).toUtc().toIso8601String()}',
      'Error: $type',
      _redact(error.toString()),
      ...frames.map(_redact),
    ].join('\n');
    return CrashReport(code: code, details: details);
  }

  final String code;
  final String details;

  static final RegExp _googleKey = RegExp(r'AIza[0-9A-Za-z_\-]{20,}');

  static String _redact(String input) =>
      RedactingLogInterceptor.redact(input).replaceAll(_googleKey, '[REDACTED]');

  /// FNV-1a, 24 bits: short enough to read out, stable across runs.
  static String _hash(String input) {
    int hash = 0x811c9dc5;
    for (final int unit in input.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return (hash & 0xffffff).toRadixString(16).toUpperCase().padLeft(6, '0');
  }
}

class CrashDialog extends StatelessWidget {
  const CrashDialog({required this.crash, super.key});

  final CrashReport crash;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.crashTitle),
      content: Text(l10n.crashBody(crash.code)),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: crash.details));
            if (context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.crashCopied)));
              Navigator.of(context).pop();
            }
          },
          child: Text(l10n.crashCopyAction),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.crashCloseAction),
        ),
      ],
    );
  }
}

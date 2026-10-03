// Long-pressing a chat message offers Copy, and Copy puts the message's
// raw text on the clipboard.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/domain/message.dart';
import 'package:dry_run/features/chat/presentation/widgets/message_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _tutorText = 'Try a **hash map** first.';

void main() {
  testWidgets('long press on a message offers Copy and copies its text', (WidgetTester tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: MessageList(
            messages: <Message>[
              Message(
                id: 'm-1',
                seq: 1,
                role: TurnRole.tutor,
                text: _tutorText,
                kind: MessageKind.turn,
                delivery: Delivery.sent,
              ),
            ],
            hintCount: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(MessageList)))!;

    await tester.longPress(find.textContaining('hash map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.messageCopyAction));
    await tester.pumpAndSettle();

    expect(copied, _tutorText);
    expect(find.text(l10n.messageCopiedNotice), findsOneWidget);
  });
}

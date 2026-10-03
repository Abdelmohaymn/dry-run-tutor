import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/text/markdown_text.dart';
import '../../chat/presentation/daily_session_cubit.dart';
import '../../chat/presentation/daily_session_state.dart';
import 'dispute_action.dart';

/// Prototype screen 7: the editorial, reached only from [Verdict] — the
/// router itself is what makes "never shown before the assessment is
/// delivered" (FR-032) structural: there is no `Assessments` row, there is
/// no route in.
///
/// `editorial` is authored Markdown (`problem.schema.json`: "Markdown for
/// the reveal") and was being painted as plain prose, so the learner read
/// `**The move:**` with the asterisks in it. It is rendered properly now
/// by `core/text/markdown_text.dart` — a small in-repo renderer rather
/// than a new dependency, which keeps `plan.md`'s resolved dependency set
/// (T001) intact.
class RevealScreen extends StatelessWidget {
  const RevealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // Same as the verdict: reached with `go`, so back has to be told
    // where to go. Backing out of the editorial returns to the verdict it
    // was opened from — moving the *state* back, since the shell owns
    // navigation for this flow.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          context.read<DailySessionCubit>().hideEditorial();
          context.go(AppRoute.sessionVerdict.path);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.revealScreenTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.backAction,
          onPressed: () {
            context.read<DailySessionCubit>().hideEditorial();
            context.go(AppRoute.sessionVerdict.path);
          },
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<DailySessionCubit, DailySessionState>(
          builder: (BuildContext context, DailySessionState state) {
            if (state is! Revealed) {
              return const SizedBox.shrink();
            }
            final DailySessionCubit cubit = context.read<DailySessionCubit>();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                MarkdownText(state.assessment.editorial, selectable: true),
                const SizedBox(height: 24),
                DisputeAction(disputed: state.session.disputed, onPressed: cubit.disputeAssessment),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}

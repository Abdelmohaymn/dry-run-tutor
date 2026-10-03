import 'package:flutter/material.dart';

import '../../../core/analytics/analytics_client.dart';
import '../../../core/analytics/event_name.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../assessment/domain/assessment.dart';
import '../../assessment/domain/assessment_repository.dart';
import '../../chat/domain/session.dart';
import '../../chat/domain/session_repository.dart';
import '../../streak/domain/streak_repository.dart';
import '../../streak/presentation/share_card.dart';

/// The current day's completed session and assessment, reachable in ≤3
/// taps (SC-013) and offering **no second problem** (FR-039) — there is
/// no button here that leads anywhere but back, because there is nothing
/// else today to offer.
class ReviewDayScreen extends StatefulWidget {
  const ReviewDayScreen({
    required this.sessionRepository,
    required this.assessmentRepository,
    required this.streakRepository,
    required this.analyticsClient,
    super.key,
  });

  final SessionRepository sessionRepository;
  final AssessmentRepository assessmentRepository;
  final StreakRepository streakRepository;
  final AnalyticsClient analyticsClient;

  @override
  State<ReviewDayScreen> createState() => _ReviewDayScreenState();
}

class _ReviewDayScreenState extends State<ReviewDayScreen> {
  Session? _session;
  Assessment? _assessment;
  int _streakLength = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Session session = await widget.sessionRepository.openOrResumeToday();
    final Assessment? assessment = await widget.assessmentRepository.forSession(session.id);
    final int streakLength = (await widget.streakRepository.current()).currentLength;
    if (mounted) {
      setState(() {
        _session = session;
        _assessment = assessment;
        _streakLength = streakLength;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reviewDayScreenTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final Session? session = _session;
    final Assessment? assessment = _assessment;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewDayScreenTitle)),
      body: SafeArea(
        child: session == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(session.problem.title, style: context.appTypography.sansHeadline),
                  const SizedBox(height: 16),
                  if (assessment != null) ...<Widget>[
                    ShareCard(
                      assessment: assessment,
                      streakLength: _streakLength,
                      problemTitle: session.problem.title,
                      onShared: () => widget.analyticsClient.emit(EventName.shareCardShared),
                    ),
                  ] else
                    Text(l10n.capReachedBody, style: context.appTypography.sansCaption),
                ],
              ),
      ),
    );
  }
}

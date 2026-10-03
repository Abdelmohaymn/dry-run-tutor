import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/time/trusted_time_source.dart';
import '../domain/streak.dart';
import '../domain/streak_repository.dart';

/// Prototype screen 8: a contribution heatmap in **four luminance steps,
/// not four hues** (FR-039a) — ordered in greyscale by construction, so
/// `test/golden/`'s saturation-zero filter is what actually enforces this
/// rather than a design review note (SC-015).
class StreakScreen extends StatefulWidget {
  const StreakScreen({required this.streakRepository, required this.timeSource, super.key});

  final StreakRepository streakRepository;
  final TrustedTimeSource timeSource;

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  Streak? _streak;
  String? _today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Streak streak = await widget.streakRepository.current();
    final String today = await widget.timeSource.today();
    if (mounted) {
      setState(() {
        _streak = streak;
        _today = today;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Streak? streak = _streak;
    final String? today = _today;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.streakScreenTitle)),
      body: SafeArea(
        child: streak == null || today == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(
                    l10n.streakCountLabel(streak.currentLength),
                    style: context.appTypography.monoBody.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 20),
                  _Heatmap(streak: streak, today: today),
                  const SizedBox(height: 20),
                  Text(
                    l10n.streakPerInstallNotice,
                    style: context.appTypography.sansCaption.copyWith(color: AppTokens.muted),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => context.push(AppRoute.sessionReviewDay.path),
                    child: Text(l10n.streakReviewTodayAction),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.streak, required this.today});

  final Streak streak;
  final String today;

  static const int _weeks = 16;

  @override
  Widget build(BuildContext context) {
    final DateTime todayUtc = _parseYmd(today);
    // Sunday-aligned columns, most recent week last.
    final int daysSinceSunday = todayUtc.weekday % 7;
    final DateTime gridEnd = todayUtc.add(Duration(days: 6 - daysSinceSunday));
    final DateTime gridStart = gridEnd.subtract(Duration(days: _weeks * 7 - 1));

    return Semantics(
      label: 'Contribution heatmap, ${streak.currentLength} day streak',
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: <Widget>[
          for (int i = 0; i < _weeks * 7; i++) _cell(gridStart.add(Duration(days: i)), todayUtc),
        ],
      ),
    );
  }

  Widget _cell(DateTime date, DateTime todayUtc) {
    final Color colour = _colourFor(date, todayUtc);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
    );
  }

  Color _colourFor(DateTime date, DateTime todayUtc) {
    if (date.isAfter(todayUtc)) {
      // Not reached yet — the emptiest tier, never rendered as "missed".
      return AppTokens.surface;
    }
    final String ymd = _formatYmd(date);
    if (!streak.completedDates.contains(ymd)) {
      return AppTokens.surface2;
    }
    final bool inCurrentRun = todayUtc.difference(date).inDays < streak.currentLength;
    return inCurrentRun ? AppTokens.accent : AppTokens.accentDim;
  }

  DateTime _parseYmd(String ymd) {
    final List<String> parts = ymd.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  String _formatYmd(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

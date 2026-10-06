import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/domain/reminder_time.dart';
import '../../settings/domain/settings_repository.dart';
import '../domain/install_repository.dart';
import 'widgets/onboarding_art.dart';

/// `/welcome` — the one place the app explains itself.
///
/// Everything here was learned the hard way from a first real session on a
/// device: the learner did not know the tutor never says "correct", did not
/// know hints and examples cost nothing, did not know the assessment only
/// arrives when *they* end the session, and never saw a notification
/// because nothing had asked for the permission. None of that is
/// discoverable from a chat screen, and none of it is the learner's fault.
///
/// Two of the slides do something rather than say something — the reminder
/// is armed here, permission and all, because the one moment a learner
/// will agree to a daily notification is the moment they are being told
/// what it is for.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    required this.installRepository,
    required this.settingsRepository,
    super.key,
  });

  final InstallRepository installRepository;
  final SettingsRepository settingsRepository;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  /// null = not asked yet on this screen.
  bool? _remindersOn;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Order matters: the reason to be here at all leads, because a learner
  // who does not buy the premise will not read six slides of mechanics.
  List<_Slide> _slides(AppLocalizations l10n) => <_Slide>[
        _Slide(OnboardingArt.mind, l10n.welcomeSlide1Title, l10n.welcomeSlide1Body),
        _Slide(OnboardingArt.speak, l10n.welcomeSlide2Title, l10n.welcomeSlide2Body),
        _Slide(OnboardingArt.daily, l10n.welcomeSlide3Title, l10n.welcomeSlide3Body),
        _Slide(OnboardingArt.asks, l10n.welcomeSlide4Title, l10n.welcomeSlide4Body),
        _Slide(OnboardingArt.finish, l10n.welcomeSlide5Title, l10n.welcomeSlide5Body),
        _Slide(
          OnboardingArt.remind,
          l10n.welcomeSlide6Title,
          l10n.welcomeSlide6Body,
          action: _reminderAction,
        ),
        _Slide(OnboardingArt.key, l10n.welcomeSlide7Title, l10n.welcomeSlide7Body),
        _Slide(OnboardingArt.share, l10n.welcomeSlide8Title, l10n.welcomeSlide8Body),
      ];

  Widget _reminderAction(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return switch (_remindersOn) {
      null => FilledButton.icon(
          onPressed: _enableReminders,
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: Text(l10n.welcomeEnableRemindersAction),
        ),
      true => _Confirmation(
          text: l10n.welcomeRemindersOnNotice,
          hue: AppTokens.accent,
          icon: Icons.check_circle_outline,
        ),
      false => _Confirmation(
          text: l10n.welcomeRemindersBlockedNotice,
          hue: AppTokens.amber,
          icon: Icons.error_outline,
        ),
    };
  }

  Future<void> _enableReminders() async {
    // `setReminderTime` asks for the permission itself and reports whether
    // the reminder can actually appear — "scheduled" and "will be seen"
    // are two different facts on Android 13+.
    final bool allowed = await widget.settingsRepository.setReminderTime(ReminderTime.defaultTime);
    if (mounted) {
      setState(() => _remindersOn = allowed);
    }
  }

  Future<void> _finish(String destination) async {
    await widget.installRepository.markWelcomeSeen();
    // Recorded before the navigation, so a learner who closes the app on
    // the walkthrough's first frame is still returned to it. Cleared by
    // the walkthrough itself, whether they finish it or skip it.
    await widget.installRepository.setPracticePending(
      destination == AppRoute.welcomePractice.path,
    );
    if (mounted) {
      context.go(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<_Slide> slides = _slides(l10n);
    final bool onLast = _page == slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                // Skipping goes to the practice offer, not out of
                // onboarding entirely: the walkthrough is the part that
                // teaches by doing, and it is one tap from here either way.
                onPressed: () => _controller.jumpToPage(slides.length - 1),
                child: Text(l10n.welcomeSkipAction),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (int page) => setState(() => _page = page),
                itemBuilder: (BuildContext context, int index) => _SlideView(slide: slides[index]),
              ),
            ),
            _Dots(count: slides.length, current: _page),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: onLast
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _finish(AppRoute.welcomePractice.path),
                            child: Text(l10n.welcomeTryAction),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _finish(AppRoute.daily.path),
                          child: Text(l10n.welcomeSkipPracticeAction),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        ),
                        child: Text(l10n.welcomeNextAction),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide(this.art, this.title, this.body, {this.action});

  final OnboardingArt art;
  final String title;
  final String body;

  /// A slide that *does* something rather than only saying it.
  final Widget Function(BuildContext context)? action;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          OnboardingIllustration(art: slide.art),
          const SizedBox(height: 28),
          Text(
            slide.title,
            style: context.appTypography.sansHeadline.copyWith(
              fontSize: 32,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: context.appTypography.sansBody.copyWith(
              fontSize: 17,
              color: AppTokens.muted,
              height: 1.55,
            ),
          ),
          if (slide.action case final Widget Function(BuildContext) action) ...<Widget>[
            const SizedBox(height: 24),
            action(context),
          ],
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current ? AppTokens.accent : AppTokens.border2,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.text, required this.hue, required this.icon});

  final String text;
  final Color hue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 8),
          child: Icon(icon, size: 16, color: hue),
        ),
        Expanded(
          child: Text(text, style: context.appTypography.sansCaption.copyWith(color: hue)),
        ),
      ],
    );
  }
}

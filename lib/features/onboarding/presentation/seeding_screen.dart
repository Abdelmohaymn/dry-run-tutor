import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/remote_config_repository.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../../core/theme/app_theme.dart';
import '../../problem/domain/problem_repository.dart';
import '../domain/install_repository.dart';

/// `/seeding` (FR-047a/b, SC-022): the first-launch waiting screen
/// `seedGuard` redirects to when there is no cached config **and** no
/// cached problem at all. Explains what it is fetching and why, in plain
/// words, and retries entirely on its own as connectivity changes —
/// **no error dialog, no bare retry button, no blank screen at any
/// point**. Runs the same best-effort bootstrap sequence `main()` runs
/// once (install → config → manifest prefetch), because a first attempt
/// with no network at all leaves those repositories exactly where
/// `main()` left them: this screen is what keeps trying.
class SeedingScreen extends StatefulWidget {
  const SeedingScreen({
    required this.installRepository,
    required this.configRepository,
    required this.problemRepository,
    this.connectivity,
    super.key,
  });

  final InstallRepository installRepository;
  final RemoteConfigRepository configRepository;
  final ProblemRepository problemRepository;

  /// Injectable for `test/widget/seeding_screen_test.dart`'s fake
  /// connectivity stream; defaults to the real plugin at runtime.
  final Connectivity? connectivity;

  @override
  State<SeedingScreen> createState() => _SeedingScreenState();
}

/// Retry cadence. The screen's own copy promises it keeps trying, and a
/// connectivity subscription alone does not deliver that: a device that
/// was online the whole time and failed for some other reason never
/// emits an event to retry on.
const Duration _retryInterval = Duration(seconds: 10);

/// Ticks an outstanding attempt may span before the next one starts
/// anyway. Every network call underneath has a `dio` timeout, so an
/// attempt this old is stuck on something that is not a socket — a
/// platform channel whose reply never comes, a database that will not
/// open — and waiting on it is waiting forever.
///
/// The bound is counted in ticks of the timer above rather than kept as
/// a `Timeout` on the attempt itself, deliberately: this screen must own
/// exactly one timer, so that disposing it leaves nothing pending behind
/// a future that is never going to complete.
const int _staleAttemptTicks = 3;

class _SeedingScreenState extends State<SeedingScreen> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retryTimer;
  bool _attempting = false;
  bool _seeded = false;
  int _ticksWhileAttempting = 0;

  /// Bumped by every attempt that starts. An abandoned attempt that does
  /// eventually return compares its own generation against this before
  /// touching shared state, so a straggler cannot unlatch the attempt
  /// that replaced it.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _attemptSeed();
    _retryTimer = Timer.periodic(_retryInterval, (_) => unawaited(_onRetryTick()));
    _connectivitySub = (widget.connectivity ?? Connectivity()).onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.any((ConnectivityResult r) => r != ConnectivityResult.none)) {
        _attemptSeed();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRetryTick() async {
    if (_seeded) {
      return;
    }
    // Read first, attempt second. An abandoned attempt is still running
    // somewhere, and one of them landing a cache is exactly the outcome
    // this screen is waiting for — but nothing else will ever look,
    // because the code that looks lives after an `await` on a call that
    // is not going to return.
    if (await _leaveIfReady()) {
      return;
    }
    if (_attempting) {
      _ticksWhileAttempting++;
      if (_ticksWhileAttempting < _staleAttemptTicks) {
        return;
      }
      // Abandoned, not cancelled — there is no cancelling an outstanding
      // platform-channel call. It is left to finish into a generation
      // that no longer matters.
      _attempting = false;
    }
    _attemptSeed();
  }

  Future<void> _attemptSeed() async {
    if (_attempting || _seeded) {
      return;
    }
    _attempting = true;
    _ticksWhileAttempting = 0;
    final int generation = ++_generation;
    try {
      await _bootstrap();
    } catch (_) {
      // Nothing here is a precondition: whatever did land is what the
      // readiness check below reads, and the next tick tries the rest.
    } finally {
      if (generation == _generation) {
        // In a `finally`, so a throw releases the latch too. Left set it
        // would silence the timer and the connectivity stream both, and
        // this screen has no other way out.
        _attempting = false;
      }
    }

    await _leaveIfReady();
  }

  /// Leaves for today's problem if either cache is now populated, and
  /// reports whether it did. Either one is enough — FR-047's condition
  /// for this screen is that *neither* exists.
  Future<bool> _leaveIfReady() async {
    if (_seeded) {
      return true;
    }
    bool ready;
    try {
      ready =
          widget.configRepository.cached() != null || await widget.problemRepository.hasAnyCached();
    } catch (_) {
      ready = false;
    }
    if (!mounted || !ready || _seeded) {
      return false;
    }
    _seeded = true;
    _retryTimer?.cancel();
    context.go(AppRoute.daily.path);
    return true;
  }

  Future<void> _bootstrap() async {
    try {
      await widget.installRepository.ensureIdentity();
    } catch (_) {
      // Best-effort, same as main()'s launch sequence — a config or
      // problem cache landing on its own is still enough to leave.
    }
    try {
      await widget.configRepository.load();
    } catch (_) {
      // FR-046 fail-open: load() only rethrows with no cache and no
      // network at all, which is exactly the condition keeping this
      // screen up.
    }
    try {
      await widget.problemRepository.fetchPractice();
    } catch (_) {
      // Same best-effort as above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(l10n.seedingTitle, style: context.appTypography.sansHeadline),
              const SizedBox(height: 16),
              Text(l10n.seedingBody, style: context.appTypography.sansBody),
            ],
          ),
        ),
      ),
    );
  }
}

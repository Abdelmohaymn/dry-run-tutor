import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/models/wire_enums.dart' show MatchedVerdict;
import '../../assessment/domain/assessment.dart';
import '../../assessment/domain/complexity.dart';
import '../../assessment/presentation/assessment_copy.dart';
import '../../../core/config/brand.dart';

/// The shareable result: a rich card image, and a short invitation as the
/// message text beside it.
///
/// The two carry deliberately different things, which is the whole design
/// here. **The text** is what lands in a chat thread as words, so it is
/// two lines a friend can act on — the reason to care and the ask, then
/// the link. The streak stays on the card only. It says nothing about the problem or the verdict, because
/// those describe how one person did on something the reader has not seen,
/// and a score is not an invitation.
///
/// **The card** is the thing they look at, so it carries the detail: the
/// problem, how it went, the approach landed on, and its complexity.
/// Detail is welcome in a picture and noise in a sentence. The opener and
/// the invitation stay off it for the same reason in reverse — they are
/// what the words in the thread are *for*, and repeating them inside the
/// picture is the message talking over itself.
///
/// Two **DEPARTURES from FR-039b**, both from watching real shares land:
///
///   * "3 of 4 key insights reached" is gone from both. It reads as a
///     score out of four, the one thing FR-022a is careful never to do
///     anywhere else in the product.
///   * The `dryrun://` deep link is gone. No chat app linkifies a
///     custom scheme, so it was inert characters; the problem's title took
///     its place on the card, where it is the one genuinely interesting
///     fact about the day.
///
/// What FR-039b was really protecting is untouched: the payload is still
/// text, still readable and copy-pasteable, and nothing on either half
/// encodes meaning in colour alone — the verdict is a word first and a hue
/// second, exactly as on the assessment screen.
/// The words that land in the chat thread, as distinct from what the card
/// image shows.
///
/// A top-level function so the split the class comment describes is
/// testable: the one thing most likely to be undone by a later edit is
/// someone folding the card's detail back into the message.
String shareMessageText(AppLocalizations l10n) => <String>[
      l10n.shareCardOpener,
      '',
      l10n.shareCardInvite,
      '',
      // Full https URL so chat apps turn it into a tappable link.
      AppBrand.websiteUrl,
    ].join('\n');

/// The landing site without its scheme or trailing slash, for the card
/// image, where nothing is tappable and `https://` is only width.
String get shareCardSiteLabel => Uri.parse(AppBrand.websiteUrl).host;

class ShareCard extends StatefulWidget {
  const ShareCard({
    required this.assessment,
    required this.streakLength,
    required this.problemTitle,
    required this.onShared,
    super.key,
  });

  final Assessment assessment;
  final int streakLength;

  /// What the day was actually about. The line the dead deep link used to
  /// occupy.
  final String problemTitle;

  /// Emits `share_card_shared`. A callback rather than an `AnalyticsClient`
  /// so this widget can sit on the verdict screen, which reaches analytics
  /// through the session Cubit and holds no client of its own.
  final VoidCallback onShared;

  @override
  State<ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<ShareCard> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _sharing = false;

  String _cardText(AppLocalizations l10n) => shareMessageText(l10n);

  /// The learner's own complexity, and only that — never "matches the
  /// reference", which says nothing to anyone who has not seen the
  /// reference. Nothing stated means no row: filling it from the reference
  /// put the editorial's O(1) on the card of a learner who talked about
  /// béchamel the whole session (found on device).
  static String? complexityLine(AppLocalizations l10n, Complexity complexity) {
    final String time = (complexity.userClaimedTime ?? '').trim();
    final String space = (complexity.userClaimedSpace ?? '').trim();
    if (time.isEmpty && space.isEmpty) {
      return null;
    }
    if (space.isEmpty) {
      return time;
    }
    if (time.isEmpty) {
      return space;
    }
    return l10n.shareCardComplexityLine(time, space);
  }

  /// The rendered card, at 3x so it stays sharp when a chat app scales it.
  ///
  /// Returns null rather than throwing on any failure — the boundary can
  /// legitimately not be painted yet, and a share that silently falls back
  /// to text is far better than one that fails.
  Future<Uint8List?> _renderPng() async {
    try {
      final RenderObject? object = _boundaryKey.currentContext?.findRenderObject();
      if (object is! RenderRepaintBoundary) {
        return null;
      }
      final ui.Image image = await object.toImage(pixelRatio: 3);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _share(String text) async {
    setState(() => _sharing = true);
    final Uint8List? png = await _renderPng();
    // `XFile.fromData` rather than a temp file: `path_provider` is not a
    // dependency of this project and share_plus writes the bytes to its
    // own cache for us.
    final List<XFile> files = png == null
        ? const <XFile>[]
        : <XFile>[XFile.fromData(png, mimeType: 'image/png', name: AppBrand.shareImageName)];
    await SharePlus.instance.share(ShareParams(text: text, files: files));
    widget.onShared();
    if (mounted) {
      setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String text = _cardText(l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RepaintBoundary(
          key: _boundaryKey,
          child: _CardFace(
            assessment: widget.assessment,
            streakLength: widget.streakLength,
            problemTitle: widget.problemTitle,
            complexity: complexityLine(l10n, widget.assessment.complexity),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sharing ? null : () => _share(text),
          icon: const Icon(Icons.share),
          label: Text(l10n.shareCardAction),
        ),
      ],
    );
  }
}

/// The card itself, kept a pure widget of its inputs so the same tree is
/// what the learner sees and what gets rasterised — a preview that could
/// differ from the shared image would be worse than no preview.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.assessment,
    required this.streakLength,
    required this.problemTitle,
    required this.complexity,
  });

  final Assessment assessment;
  final int streakLength;
  final String problemTitle;
  final String? complexity;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final VerdictCopy verdict = resolveVerdictCopy(l10n, assessment.verdict);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Opaque, not the page ground: a transparent boundary rasterises
        // to a card that is unreadable on a light chat background.
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.border2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            problemTitle,
            style: context.appTypography.sansHeadline.copyWith(fontSize: 22, height: 1.2),
          ),
          const SizedBox(height: 12),
          // Hue AND a word, here as everywhere (design-tokens.md, FR-030).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: verdict.hue.withValues(alpha: 0.14),
              border: Border.all(color: verdict.hue.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              verdict.word,
              style: context.appTypography.sansHeadline.copyWith(color: verdict.hue, fontSize: 16),
            ),
          ),
          // `matched_approach: "none"` is a designed state, not a gap —
          // an approach the catalogue does not list. There is nothing to
          // name in that case, so the row is simply absent.
          if (assessment.matchedVerdict != MatchedVerdict.none) ...<Widget>[
            const SizedBox(height: 16),
            _Field(
              label: l10n.shareCardApproachLabel,
              value: humaniseInsightKey(assessment.matchedApproach),
            ),
          ],
          if (complexity case final String complexity) ...<Widget>[
            const SizedBox(height: 12),
            _Field(label: l10n.verdictComplexityLabel, value: complexity),
          ],
          const SizedBox(height: 18),
          const Divider(color: AppTokens.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Icon(Icons.local_fire_department, size: 16, color: AppTokens.amber),
              const SizedBox(width: 6),
              Text(
                l10n.shareCardStreakLine(streakLength),
                style: context.appTypography.monoBody.copyWith(color: AppTokens.amber),
              ),
              const Spacer(),
              Text(
                l10n.appTitle(AppBrand.name),
                style: context.appTypography.monoCaption.copyWith(color: AppTokens.faint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            shareCardSiteLabel,
            style: context.appTypography.monoCaption.copyWith(color: AppTokens.faint),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: context.appTypography.monoLabel.copyWith(color: AppTokens.faint)),
        const SizedBox(height: 2),
        Text(value, style: context.appTypography.monoBody),
      ],
    );
  }
}

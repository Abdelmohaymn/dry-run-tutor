import 'package:equatable/equatable.dart';

/// The device's cloud-voice allowance as last reported by the relay
/// (`POST /v1/stt` 200 body), persisted per UTC day so a same-day relaunch
/// knows how many seconds are left without a new endpoint.
class VoiceQuota extends Equatable {
  const VoiceQuota({required this.date, required this.secondsLeft, required this.maxClipSeconds});

  /// The UTC day (`YYYY-MM-DD`) this count applies to.
  final String date;

  /// Seconds of cloud transcription left for [date]. Never negative.
  final int secondsLeft;

  /// The longest single clip the relay accepts, in seconds.
  final int maxClipSeconds;

  @override
  List<Object?> get props => [date, secondsLeft, maxClipSeconds];
}

import 'package:record/record.dart';

/// Thin seam over the `record` package so the cloud voice repository can be
/// tested without a platform channel.
abstract interface class AudioRecorderPort {
  /// Checks (and requests, if needed) the microphone permission.
  Future<bool> hasPermission();

  /// Starts recording to [path].
  Future<void> start(String path);

  /// Input level while recording, normalised to 0.0 (silence) .. 1.0 (loud).
  Stream<double> levels();

  /// Stops recording and returns the file path, or null if nothing was
  /// recorded.
  Future<String?> stop();

  /// Stops recording and deletes the file.
  Future<void> cancel();

  /// Releases the underlying recorder.
  Future<void> dispose();
}

/// [AudioRecorderPort] backed by the `record` package.
///
/// Speech-tuned AAC-LC in an m4a container: 16 kHz mono at 32 kbps keeps a
/// 120 s clip around 480 KB.
class RecordAudioRecorder implements AudioRecorderPort {
  RecordAudioRecorder([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 32000,
    sampleRate: 16000,
    numChannels: 1,
  );

  static const Duration _levelInterval = Duration(milliseconds: 100);

  /// Floor of the dBFS range mapped onto 0.0 .. 1.0.
  static const double _floorDb = 60;

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(_config, path: path);

  @override
  Stream<double> levels() => _recorder
      .onAmplitudeChanged(_levelInterval)
      .map(
        (amplitude) =>
            ((amplitude.current + _floorDb) / _floorDb).clamp(0.0, 1.0),
      );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

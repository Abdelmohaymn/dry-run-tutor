import 'dart:async';
import 'dart:io';

import 'package:dry_run/features/cloud_voice/data/audio_recorder_port.dart';

/// Scriptable [AudioRecorderPort] for cloud-voice tests. It touches the real
/// file system (a small file under the path it is given), so the repository's
/// read and delete paths are exercised for real; only the microphone is fake.
class FakeAudioRecorderPort implements AudioRecorderPort {
  /// What [hasPermission] answers.
  bool permission = true;

  /// What [stop] returns. Null means "use the path given to [start]" (the
  /// normal case); [stopReturnsNull] forces a null result instead.
  bool stopReturnsNull = false;

  /// The bytes [stop] writes to the file, so "byte-identical" can be proved.
  List<int> clipBytes = const <int>[1, 2, 3, 4, 5, 6, 7, 8];

  /// Throw from [start] to script a recorder failure.
  Object? startError;

  /// Drives [levels]; push values with `levelController.add(...)`.
  final StreamController<double> levelController =
      StreamController<double>.broadcast();

  String? startedPath;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  bool disposed = false;

  /// How long [cancel] takes, like a real recorder releasing the mic.
  Duration cancelLatency = Duration.zero;

  /// Every start / stop / cancel, in the order each finished.
  final List<String> calls = <String>[];

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String path) async {
    startCalls++;
    calls.add('start');
    if (startError != null) throw startError!;
    startedPath = path;
    // The recorder creates the file as soon as it starts. Like the real one
    // after `cancel()`, nothing here cleans it up on its own: the repository
    // is what must delete it.
    await File(path).writeAsBytes(const <int>[0]);
  }

  @override
  Stream<double> levels() => levelController.stream;

  @override
  Future<String?> stop() async {
    stopCalls++;
    calls.add('stop');
    final String? path = startedPath;
    if (stopReturnsNull || path == null) return null;
    await File(path).writeAsBytes(clipBytes);
    return path;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    await Future<void>.delayed(cancelLatency);
    calls.add('cancel');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await levelController.close();
  }
}

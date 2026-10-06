import 'package:dry_run/core/device/device_id_platform.dart';

class FakeDeviceIdPlatform implements DeviceIdPlatform {
  FakeDeviceIdPlatform({this.id = 'abc123def4567890'});

  final String? id;

  @override
  Future<String?> androidId() async => id;
}

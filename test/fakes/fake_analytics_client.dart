import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/analytics/event_name.dart';

class FakeAnalyticsClient implements AnalyticsClient {
  final List<(EventName, Map<String, Object>?)> emitted = <(EventName, Map<String, Object>?)>[];

  @override
  void emit(EventName name, {Map<String, Object>? props}) {
    emitted.add((name, props));
  }
}

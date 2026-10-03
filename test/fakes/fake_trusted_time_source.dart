import 'package:dry_run/core/time/trusted_instant.dart';
import 'package:dry_run/core/time/trusted_time_source.dart';

class FakeTrustedTimeSource implements TrustedTimeSource {
  DateTime utc = DateTime.utc(2026, 1, 1, 9);

  @override
  Future<TrustedInstant> now() async =>
      TrustedInstant(utc: utc, source: TrustedTimeSourceKind.trustedTime, isStale: false);

  @override
  Future<String> today() async {
    final DateTime u = utc;
    final String year = u.year.toString().padLeft(4, '0');
    final String month = u.month.toString().padLeft(2, '0');
    final String day = u.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

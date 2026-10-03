import 'package:dio/dio.dart';

/// Captures the `Date:` header off every successful relay response, so
/// ordinary app traffic keeps the trusted-time anchor fresh for free —
/// tier two of `TrustedTimeSource`'s three-tier chain (research.md R-003).
///
/// This interceptor only observes; it never blocks or rewrites a request,
/// and a response with no `Date:` header (or a malformed one) is silently
/// ignored rather than treated as a failure — the anchor simply does not
/// advance that time, which is what "last known anchor" already expects.
class ServerDateInterceptor extends Interceptor {
  ServerDateInterceptor({required this.onServerDate});

  /// Called with the parsed `Date:` header of every successful response.
  final void Function(DateTime serverDate) onServerDate;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final String? dateHeader = response.headers.value('date');
    if (dateHeader != null) {
      final DateTime? parsed = DateTime.tryParse(dateHeader) ?? _tryParseHttpDate(dateHeader);
      if (parsed != null) {
        onServerDate(parsed.toUtc());
      }
    }
    handler.next(response);
  }

  /// `Date:` headers are RFC 7231 IMF-fixdate
  /// (`Wed, 21 Oct 2026 07:28:00 GMT`), which [DateTime.tryParse] does not
  /// accept. [HttpDate.parse] does, but pulls in `dart:io`, which
  /// `features/voice/` must never import and which this file has no
  /// reason to depend on either — so it is parsed by hand here instead.
  static DateTime? _tryParseHttpDate(String value) {
    // "Wed, 21 Oct 2026 07:28:00 GMT"
    final RegExp httpDate = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    );
    final RegExpMatch? match = httpDate.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final int day = int.parse(match.group(1)!);
    final int month = months.indexOf(match.group(2)!) + 1;
    final int year = int.parse(match.group(3)!);
    final int hour = int.parse(match.group(4)!);
    final int minute = int.parse(match.group(5)!);
    final int second = int.parse(match.group(6)!);
    if (month == 0) {
      return null;
    }
    return DateTime.utc(year, month, day, hour, minute, second);
  }
}

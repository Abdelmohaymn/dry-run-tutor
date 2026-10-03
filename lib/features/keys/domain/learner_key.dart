/// A learner's own provider key. Never persisted outside secure storage —
/// not in Drift, not in `shared_preferences`, not in a log line, not in an
/// analytics event, not in an error message (FR-003, Principle VI).
///
/// `toString()` is overridden to redact [value] so the cheapest possible
/// mistake — an accidental string interpolation into a log call — cannot
/// leak it.
class LearnerKey {
  const LearnerKey({required this.providerId, required this.value});

  final String providerId;
  final String value;

  @override
  String toString() => 'LearnerKey(providerId: $providerId, value: <redacted>)';
}

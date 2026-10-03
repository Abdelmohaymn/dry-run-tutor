/// Why a session ended — `meta.session_ended`'s three values, plus the
/// caller's intent when `endSession` is invoked with no cap or solution
/// release in play. Sent to `/v1/judge` as `ended_by` (contracts/relay-client.md).
enum EndedBy { user, cap, solution }

extension EndedByWire on EndedBy {
  /// The exact wire value `/v1/judge`'s `ended_by` and `Sessions.sessionEnded`
  /// expect.
  String get wireName => switch (this) {
        EndedBy.user => 'user',
        EndedBy.cap => 'cap',
        EndedBy.solution => 'solution',
      };
}

/// The reverse of [EndedByWire.wireName] — how `DailySessionCubit` picks
/// which reason to hand `endSession` (T111). `meta.session_ended` only
/// ever arrives as `cap` or `solution` (`worker/src/lib/chat-core.ts`
/// never produces `"user"` — a session the learner closes voluntarily,
/// before either threshold, has no server opinion on why), so anything
/// else — including `null`, an in-progress session — defaults to
/// [EndedBy.user]: the learner's own choice is what is left once the
/// server hasn't already ended it for them.
EndedBy endedByFromSessionEnded(String? sessionEnded) => switch (sessionEnded) {
      'cap' => EndedBy.cap,
      'solution' => EndedBy.solution,
      _ => EndedBy.user,
    };

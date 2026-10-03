/// `OutboxDrainBloc`'s state — `idle → draining(n) → waiting(until)`
/// (data-model.md §11's "other unions"). Plain, hand-written rather than
/// freezed: nothing outside this file switches on it exhaustively, and a
/// background worker's own state has no UI-equality requirement the way a
/// Cubit's does.
sealed class OutboxDrainState {
  const OutboxDrainState();
}

class OutboxIdle extends OutboxDrainState {
  const OutboxIdle();
}

class OutboxDraining extends OutboxDrainState {
  const OutboxDraining(this.remaining);
  final int remaining;
}

class OutboxWaiting extends OutboxDrainState {
  const OutboxWaiting(this.until);
  final DateTime until;
}

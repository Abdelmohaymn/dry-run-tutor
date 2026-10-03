import '../../../core/errors/result.dart';
import 'install_identity.dart';

/// `POST /v1/install`, called exactly once and reused for the lifetime of
/// the installation (contracts/relay-client.md, data-model.md §1).
abstract interface class InstallRepository {
  /// Idempotent: returns the existing identity if one is already stored,
  /// otherwise mints a uuid and confirms it with the relay. **Never
  /// re-mints a uuid on failure** — an app that did would farm tasters
  /// (FR-001, feature 001 research.md R-009). A retry after a failed call
  /// reuses the same pending uuid rather than generating a fresh one.
  Future<Result<InstallIdentity>> ensureIdentity();

  /// Whether the welcome carousel has been through once. Gated by a
  /// router redirect rather than a per-screen check, so "every entry
  /// point" stays a finite, enumerable list.
  Future<bool> isWelcomeSeen();

  Future<void> markWelcomeSeen();

  /// Whether the learner chose the walkthrough and has not yet reached
  /// the end of it. Persisted rather than held in the route, so closing
  /// the app part-way through does not silently drop them into today's
  /// real problem — the one thing the walkthrough exists to stand in
  /// front of.
  Future<bool> isPracticePending();

  /// Set when the carousel hands off to the walkthrough, cleared when the
  /// walkthrough is finished or skipped. Idempotent either way.
  Future<void> setPracticePending(bool pending);
}

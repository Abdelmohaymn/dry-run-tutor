import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/analytics/analytics_client.dart';
import '../../../core/analytics/event_name.dart';
import '../../../core/errors/result.dart';
import '../domain/key_repository.dart';
import '../domain/learner_key.dart';
import 'key_entry_state.dart';

/// Drives `key_entry_screen.dart` (prototype screen 11). `submit()` is
/// the whole point of this Cubit: `KeyRepository.saveAndValidate` probes
/// before persisting (FR-005b), and a rejection re-emits [KeyEntryState]
/// with the same [providers]/[providerId]/[value] the learner already
/// had — nothing typed is ever lost to a bad key (US2 scenario 5).
class KeyEntryCubit extends Cubit<KeyEntryState> {
  KeyEntryCubit({required KeyRepository keyRepository, required List<String> providers, required AnalyticsClient analyticsClient})
      : _keyRepository = keyRepository,
        _analyticsClient = analyticsClient,
        super(
          KeyEntryState.entering(
            providers: providers,
            providerId: providers.isEmpty ? '' : providers.first,
            value: '',
          ),
        ) {
    if (providers.isNotEmpty) {
      _analyticsClient.emit(EventName.keyEntryStarted, props: <String, Object>{'provider': providers.first});
    }
  }

  final KeyRepository _keyRepository;
  final AnalyticsClient _analyticsClient;

  void selectProvider(String providerId) {
    final KeyEntryState current = state;
    final String value = current is KeyEntryEntering
        ? current.value
        : current is KeyEntryRejected
            ? current.value
            : '';
    final List<String> providers = _providersOf(current);
    emit(KeyEntryState.entering(providers: providers, providerId: providerId, value: value));
    _analyticsClient.emit(EventName.keyEntryStarted, props: <String, Object>{'provider': providerId});
  }

  void updateValue(String value) {
    final KeyEntryState current = state;
    if (current is! KeyEntryEntering) {
      return;
    }
    emit(current.copyWith(value: value));
  }

  /// Probes [providerId]/[value] against the relay and persists only on
  /// success. Returns the resolved [KeyEntryState] so the screen can act
  /// on the outcome (promote the open session, show a snackbar) without
  /// racing a `BlocListener` — the caller already awaited this call.
  Future<KeyEntryState> submit() async {
    final KeyEntryState current = state;
    final String providerId = _providerIdOf(current);
    final String value = _valueOf(current);
    final List<String> providers = _providersOf(current);

    emit(KeyEntryState.probing(providers: providers, providerId: providerId, value: value));
    final Result<void> result = await _keyRepository.saveAndValidate(
      LearnerKey(providerId: providerId, value: value),
    );
    switch (result) {
      case Ok<void>():
        _analyticsClient.emit(EventName.keySaved, props: <String, Object>{'provider': providerId});
        final KeyEntryState saved = KeyEntryState.saved(providerId: providerId);
        emit(saved);
        return saved;
      case Err<void>(:final error):
        final KeyEntryState rejected = KeyEntryState.rejected(
          providers: providers,
          providerId: providerId,
          value: value,
          error: error,
        );
        emit(rejected);
        return rejected;
    }
  }

  String _providerIdOf(KeyEntryState s) => switch (s) {
        KeyEntryEntering(:final providerId) => providerId,
        KeyEntryProbing(:final providerId) => providerId,
        KeyEntrySaved(:final providerId) => providerId,
        KeyEntryRejected(:final providerId) => providerId,
      };

  String _valueOf(KeyEntryState s) => switch (s) {
        KeyEntryEntering(:final value) => value,
        KeyEntryProbing(:final value) => value,
        KeyEntrySaved() => '',
        KeyEntryRejected(:final value) => value,
      };

  List<String> _providersOf(KeyEntryState s) => switch (s) {
        KeyEntryEntering(:final providers) => providers,
        KeyEntryProbing(:final providers) => providers,
        KeyEntrySaved() => const <String>[],
        KeyEntryRejected(:final providers) => providers,
      };
}

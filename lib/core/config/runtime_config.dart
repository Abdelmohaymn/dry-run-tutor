import 'package:equatable/equatable.dart';

import '../network/dto/config_dto.dart';

/// `chat.{turn_cap, wrap_up_at_turn, min_turn_chars}` — the three chat
/// quota levers the app is allowed to read (FR-008c).
class ChatConfig extends Equatable {
  const ChatConfig({
    required this.turnCap,
    required this.wrapUpAtTurn,
    required this.minTurnChars,
  });

  final int turnCap;
  final int wrapUpAtTurn;
  final int minTurnChars;

  @override
  List<Object?> get props => <Object?>[turnCap, wrapUpAtTurn, minTurnChars];
}

/// `trial.turn_cap` — the only field of `trial` the app reads.
/// `trial.pool` is server business (research.md R-005).
class TrialConfig extends Equatable {
  const TrialConfig({required this.turnCap});

  final int turnCap;

  @override
  List<Object?> get props => <Object?>[turnCap];
}

/// `repair.{enabled, min_chars, timeout_ms}` — the three repair levers the
/// app is allowed to read (FR-008c). Null means repair is off.
class RepairConfig extends Equatable {
  const RepairConfig({
    required this.enabled,
    required this.minChars,
    required this.timeoutMs,
  });

  final bool enabled;
  final int minChars;
  final int timeoutMs;

  @override
  List<Object?> get props => <Object?>[enabled, minChars, timeoutMs];
}


/// `rotation` — the global daily pointer (FR-035d). Present means the
/// relay decides which problem every install gets today; absent means the
/// per-install fallback in `DailyRepositoryImpl`.
class RotationConfig extends Equatable {
  const RotationConfig({required this.startProblemId, required this.anchorDate});

  /// The problem served on [anchorDate] itself.
  final String startProblemId;

  /// `YYYY-MM-DD`, UTC.
  final String anchorDate;

  @override
  List<Object?> get props => <Object?>[startProblemId, anchorDate];
}

/// A read-only projection of `config.schema.json`, restricted to exactly
/// the keys FR-008c permits the app to read: `min_supported_version`, `update_url`,
/// `killed_problem_ids`, `content_manifest_url`,
/// `chat.{turn_cap,wrap_up_at_turn,min_turn_chars}`, `trial.turn_cap`,
/// `keyed_providers`, `rotation`.
///
/// **Deliberately has no field for `model`, `provider`, `providers`,
/// `trim`, or `trial.pool`.** Those are server business; FR-008c forbids
/// exposing model names or routing state, and giving this class a getter
/// for them would invite exactly that. `RemoteConfigRepository` keeps the
/// raw response body verbatim alongside this projection so an unread key
/// is not silently dropped from what is *retained* — only from what the
/// app can act on. No default is compiled in beyond what the seeding
/// screen needs to render (Principle X.3) — every value here always comes
/// from a real `ConfigDto`.
class RuntimeConfig extends Equatable {
  const RuntimeConfig({
    required this.minSupportedVersion,
    required this.killedProblemIds,
    required this.contentManifestUrl,
    required this.chat,
    required this.trial,
    required this.keyedProviders,
    this.updateUrl,
    this.repair,
    this.rotation,
  });

  factory RuntimeConfig.fromDto(ConfigDto dto) {
    return RuntimeConfig(
      minSupportedVersion: dto.minSupportedVersion,
      updateUrl: dto.updateUrl,
      killedProblemIds: List<String>.unmodifiable(dto.killedProblemIds),
      contentManifestUrl: dto.contentManifestUrl,
      chat: ChatConfig(
        turnCap: dto.chat.turnCap,
        wrapUpAtTurn: dto.chat.wrapUpAtTurn,
        minTurnChars: dto.chat.minTurnChars,
      ),
      trial: TrialConfig(turnCap: dto.trial.turnCap),
      keyedProviders: List<String>.unmodifiable(dto.keyedProviders ?? const <String>[]),
      repair: dto.repair == null
          ? null
          : RepairConfig(
              enabled: dto.repair!.enabled,
              minChars: dto.repair!.minChars,
              timeoutMs: dto.repair!.timeoutMs,
            ),
      rotation: dto.rotation == null
          ? null
          : RotationConfig(
              startProblemId: dto.rotation!.startProblemId,
              anchorDate: dto.rotation!.anchorDate,
            ),
    );
  }

  final String minSupportedVersion;

  /// The store listing the update wall opens. Null means the landing site.
  final String? updateUrl;

  final List<String> killedProblemIds;
  final String contentManifestUrl;
  final ChatConfig chat;
  final TrialConfig trial;

  /// In the order key entry should offer them (FR-008a/b).
  final List<String> keyedProviders;

  /// Null means repair is off (feature 004's pre-feature behaviour).
  final RepairConfig? repair;

  /// Null means the relay is not driving the rotation.
  final RotationConfig? rotation;

  @override
  List<Object?> get props => <Object?>[
        minSupportedVersion,
        updateUrl,
        killedProblemIds,
        contentManifestUrl,
        chat,
        trial,
        keyedProviders,
        repair,
        rotation,
      ];
}

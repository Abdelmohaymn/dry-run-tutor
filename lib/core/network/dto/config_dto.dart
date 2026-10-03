import 'package:json_annotation/json_annotation.dart';

part 'config_dto.g.dart';

/// `config.schema.json#/properties/chat` — only the three keys the app is
/// allowed to read.
@JsonSerializable(fieldRename: FieldRename.snake)
class ChatConfigDto {
  ChatConfigDto({
    required this.turnCap,
    required this.wrapUpAtTurn,
    required this.minTurnChars,
  });

  factory ChatConfigDto.fromJson(Map<String, dynamic> json) => _$ChatConfigDtoFromJson(json);

  final int turnCap;
  final int wrapUpAtTurn;
  final int minTurnChars;

  Map<String, dynamic> toJson() => _$ChatConfigDtoToJson(this);
}

/// `config.schema.json#/properties/trial` — only `turn_cap`.
/// `ground_truth_tier`, `condense`, `daily_session_cap`, and `pool` are
/// server business the app has no reason to read and does not declare a
/// field for.
@JsonSerializable(fieldRename: FieldRename.snake)
class TrialConfigDto {
  TrialConfigDto({required this.turnCap});

  factory TrialConfigDto.fromJson(Map<String, dynamic> json) => _$TrialConfigDtoFromJson(json);

  final int turnCap;

  Map<String, dynamic> toJson() => _$TrialConfigDtoToJson(this);
}

/// `config.schema.json#/properties/repair` — only the three keys the app
/// needs to decide whether to call and how long to hold the review step.
/// **No field for `model`, `max_input_chars`, `max_output_ratio` or
/// `min_word_overlap`** (FR-008c) — the guards are server business.
@JsonSerializable(fieldRename: FieldRename.snake)
class RepairConfigDto {
  RepairConfigDto({
    required this.enabled,
    required this.minChars,
    required this.timeoutMs,
  });

  factory RepairConfigDto.fromJson(Map<String, dynamic> json) => _$RepairConfigDtoFromJson(json);

  final bool enabled;
  final int minChars;
  final int timeoutMs;

  Map<String, dynamic> toJson() => _$RepairConfigDtoToJson(this);
}

/// `config.schema.json#/properties/rotation` — the global daily pointer.
/// Absent means the relay is not driving the rotation and each install
/// walks its own un-attempted problems.
@JsonSerializable(fieldRename: FieldRename.snake)
class RotationConfigDto {
  RotationConfigDto({required this.startProblemId, required this.anchorDate});

  factory RotationConfigDto.fromJson(Map<String, dynamic> json) =>
      _$RotationConfigDtoFromJson(json);

  final String startProblemId;

  /// `YYYY-MM-DD`, UTC — the day the pointer sits on [startProblemId].
  final String anchorDate;

  Map<String, dynamic> toJson() => _$RotationConfigDtoToJson(this);
}

/// `GET /v1/config` response, restricted to the keys FR-008c permits the
/// app to read: `min_supported_version`, `update_url`, `killed_problem_ids`,
/// `content_manifest_url`, `chat.*`, `trial.turn_cap`, `keyed_providers`,
/// `repair.*` (feature 004, three fields only), `rotation`.
///
/// **This class has no field for `model`, `provider`, `providers`,
/// `trim`, or `trial.pool`.** `json_serializable`'s generated `fromJson`
/// silently ignores unknown keys by default, so those five stay
/// unreadable by construction rather than by convention — there is no
/// getter to reach for even by accident. `RemoteConfigRepository` stores
/// the *raw* response body verbatim alongside this parsed projection, so
/// an unread key is not silently dropped from what is retained — only
/// from what the app can act on.
@JsonSerializable(fieldRename: FieldRename.snake)
class ConfigDto {
  ConfigDto({
    required this.minSupportedVersion,
    required this.killedProblemIds,
    required this.contentManifestUrl,
    required this.chat,
    required this.trial,
    this.updateUrl,
    this.keyedProviders,
    this.repair,
    this.rotation,
  });

  factory ConfigDto.fromJson(Map<String, dynamic> json) => _$ConfigDtoFromJson(json);

  final String minSupportedVersion;

  /// Absent means the update button falls back to the landing site.
  final String? updateUrl;

  final List<String> killedProblemIds;
  final String contentManifestUrl;
  final ChatConfigDto chat;
  final TrialConfigDto trial;

  /// Absent means the single (unread) `provider` value applied — see
  /// research.md R-005. When present, in the order key entry should
  /// offer them.
  final List<String>? keyedProviders;

  /// Absent means repair is off (feature 004's pre-feature behaviour).
  final RepairConfigDto? repair;

  /// Absent means no operator-driven rotation — the per-install fallback.
  final RotationConfigDto? rotation;

  Map<String, dynamic> toJson() => _$ConfigDtoToJson(this);
}

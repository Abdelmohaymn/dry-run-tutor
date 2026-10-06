# Contract — App-side interfaces (006)

What the Flutter app exposes or consumes after this feature. File:line refs
are to the tree before the change.

## 1. Device-id platform channel

Channel: `'${AppBrand.channelPrefix}/device_id'` → `app.dryrun/device_id`.
Method: `androidId` → `String?`.

### Kotlin — new `android/app/src/main/kotlin/app/dryrun/DeviceIdChannel.kt`

Copy the shape of `TrustedTimeChannel.kt` (`attach`/`detach`/`onMethodCall`):

- `CHANNEL_NAME = "app.dryrun/device_id"`, `METHOD_ANDROID_ID = "androidId"`.
- `onMethodCall`: `"androidId"` →
  `result.success(Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID))`
  (may be `null`); anything else → `result.notImplemented()`.
- Wire into `MainActivity.kt`: a `private val deviceIdChannel = DeviceIdChannel(this)`
  field, `attach(...)` in `configureFlutterEngine`, `detach()` in `cleanUpFlutterEngine`.
- No permission and no Gradle dependency needed.

### Dart — new `lib/core/device/device_id_platform.dart`

Copy the shape of `lib/core/time/trusted_time_platform.dart`:

```dart
abstract interface class DeviceIdPlatform {
  /// Android's per-app `Settings.Secure.ANDROID_ID`, or null when the
  /// platform returns none, the channel is missing, or it times out.
  Future<String?> androidId();
}

class MethodChannelDeviceIdPlatform implements DeviceIdPlatform { ... }
```

- `const MethodChannel('${AppBrand.channelPrefix}/device_id')`, a 5 s timeout,
  `invokeMethod<String>('androidId')`; catch `PlatformException`,
  `MissingPluginException`, `TimeoutException` → `null`. Return `null` for a
  blank string too.
- Register in `lib/core/di/service_locator.dart` next to `TrustedTimePlatform`
  (`:62-64`): `sl.registerLazySingleton<DeviceIdPlatform>(() => MethodChannelDeviceIdPlatform());`
- `test/unit/brand_test.dart:59-76`: add `'device_id'` to the channel-name list.
- New `test/fakes/fake_device_id_platform.dart`: `FakeDeviceIdPlatform({this.id = 'abc123def4567890'})`.

## 2. `InstallRepositoryImpl.ensureIdentity()`

File `lib/features/onboarding/data/install_repository_impl.dart`.

- Constructor: replace `Uuid? uuid` with `required DeviceIdPlatform deviceIdPlatform`.
  Delete `_pendingUuidKey` (`:18`) and every use of it. Keep the other prefs keys.
- New body:

```
existing = await _installDao.read();
if (existing != null) return Ok(InstallIdentity(installId: existing.installId, installUuid: existing.installUuid));
deviceId = await _deviceIdPlatform.androidId();
if (deviceId == null) return const Err(RelayError.badRequest());
try {
  response = await _relayClient.install(deviceId);
  deviceHash = response.installId.split('.').first;
  await _installDao.write(InstallIdentityCompanion.insert(installUuid: deviceHash, installId: response.installId, mintedAt: (await _timeSource.now()).utc));
  return Ok(InstallIdentity(installId: response.installId, installUuid: deviceHash));
} on RelayException catch (e) { return Err(e.error); } catch (_) { return const Err(RelayError.transport()); }
```

- The raw Android ID is never written to Drift, SharedPreferences, or a log.
- Update the DI registration in `service_locator.dart` to pass
  `deviceIdPlatform: sl<DeviceIdPlatform>()` and drop `uuid:`.
- New `test/unit/install_repository_test.dart` (none exists today):
  (a) no row → calls `relayClient.install('abc123def4567890')`, stores
  `installUuid` = the part before `.`; (b) existing row → no relay call;
  (c) platform returns null → `Err(RelayError.badRequest())`, no relay call.

## 3. `RelayClient` (`lib/core/network/relay_client.dart`)

| Method | Change |
|---|---|
| `install(String installUuid)` `:63-70` | → `install(String deviceId)`; body `InstallRequestDto(platform: 'android', deviceId: deviceId)` |
| `manifest({path})` `:95-103` | **delete** |
| `sendEvents(...)` `:187-193` | **delete** |
| — | **new** `Future<DailyResponseDto> daily({required String installId, required String date})` → `GET /v1/daily?date=$date` with `_headers(installId: installId)` |
| — | **new** `Future<PracticeResponseDto> practice()` → `GET /v1/practice`, no install header |

Copy `manifest()`'s body shape: `_dio.get<Map<String, dynamic>>(path, queryParameters: …, options: Options(headers: …))`
and `on DioException catch (e) { throw RelayException(_mapTransportOrEnvelope(e, requestProblemId: '', callKind: RelayCallKind.chat)); }`.
A `409 PROBLEM_KILLED` then surfaces as `RelayError.problemKilled(problemId: '')`
(`relay_error.dart:63`); offline as `RelayError.transport()`.

DTOs:

- `lib/core/network/dto/install_dto.dart`: `InstallRequestDto{String platform; String deviceId}`
  (snake case → `platform`, `device_id`). `InstallResponseDto` unchanged.
- `lib/core/network/dto/problem_dto.dart`: delete `ManifestDto` (`:80-94`).
  Add `DailyResponseDto{String date; PublicHalfDto problem}` and
  `PracticeResponseDto{PublicHalfDto problem}` (both
  `@JsonSerializable(fieldRename: FieldRename.snake)`). Keep `PublicHalfDto`
  as is — the Worker sends the manifest entry verbatim, so
  `disallowUnrecognizedKeys: true` still holds.
- Delete `lib/core/network/dto/event_dto.dart` (+ `.g.dart`).
- Run `dart run build_runner build --delete-conflicting-outputs` and commit
  the regenerated `*.g.dart` files (they are tracked).

## 4. `ProblemRepository` (`lib/features/problem/domain/problem_repository.dart`)

New interface (replaces `:11-29`):

```dart
abstract interface class ProblemRepository {
  /// GET /v1/daily for [date]; caches the problem with manifestDate = date.
  /// Throws RelayException on any relay failure.
  Future<Problem> fetchDaily(String date);

  /// The problem cached for [date] by an earlier fetchDaily, or null.
  Future<Problem?> cachedForDate(String date);

  /// GET /v1/practice; caches the warm-up (manifestDate = null).
  /// Throws RelayException on failure.
  Future<void> fetchPractice();

  Future<Problem?> byId(String problemId);

  /// Cached, not killed, not the warm-up. Now used only by the key-check
  /// probe fallback.
  Future<List<Problem>> available(RuntimeConfig config);

  Future<Problem?> practiceProblem();
  Future<bool> hasAnyCached();
}
```

`ProblemRepositoryImpl`:

- Constructor: add `required InstallRepository installRepository` (for the
  `X-Install-Id` of `fetchDaily`) and **remove** `configRepository` — its only
  use (`:37`) is inside `prefetchManifest`. Update the DI registration and the
  direct constructions in `test/unit/daily_repository_test.dart`,
  `leak_blocked_test.dart:104`, `counter_projection_test.dart:84`,
  `summary_covers_test.dart:99`.
- Delete `prefetchManifest()` and `_prefetchWindowDays`.
- Extract the `CachedProblemsCompanion.insert(...)` mapping (`:55-78`) into
  `CachedProblemsCompanion _companion(PublicHalfDto dto, {required String? servedFor, required DateTime fetchedAt})`
  with `manifestDate: Value(servedFor)`.
- `fetchDaily(date)`: `ensureIdentity()` (on `Err(e)` throw `RelayException(e)`),
  `relayClient.daily(installId:, date:)`, upsert `_companion(resp.problem, servedFor: resp.date, ...)`,
  return `_toDomain` of the stored row.
- `fetchPractice()`: `relayClient.practice()`, upsert with `servedFor: null`.
- `cachedForDate(date)`: `problemDao.byManifestDate(date)` → `_toDomain`.

## 5. `DailyRepositoryImpl.forToday()`

New body for `lib/features/daily/data/daily_repository_impl.dart:27-74`
(delete `_pointerPick` `:76-103` and the `RotationConfig` import):

```
config = _configRepository.cached() ?? await _configRepository.load();
today = await _timeSource.today();
completed = await _sessionDao.completedProblemIds();

cached = await _problemRepository.cachedForDate(today);
if (cached != null && !config.killedProblemIds.contains(cached.id)) {
  return DailySelection(problem: cached, isRepeat: completed.contains(cached.id));
}
try {
  problem = await _problemRepository.fetchDaily(today);
  return DailySelection(problem: problem, isRepeat: completed.contains(problem.id));
} on RelayException {
  // PROBLEM_KILLED (everything withdrawn) and offline-with-nothing-cached
  // both land on the existing "no problem" state (FR-020).
  throw const NoProblemAvailableException();
}
```

- Constructor unchanged (problemRepository, sessionDao, configRepository, timeSource).
- `DailySessionCubit.open()` already maps `NoProblemAvailableException` →
  `DailySessionState.problemUnavailable()` (`daily_session_cubit.dart:181`);
  `/withdrawn`'s retry re-enters the daily route, which refetches.
- Known copy gap (follow-up, not this feature): offline-on-a-new-day shows
  the withdrawn copy.

## 6. Call sites of the removed `prefetchManifest()`

| Site | Replace with |
|---|---|
| `lib/main.dart:87` | `await sl<ProblemRepository>().fetchPractice();` (same try/catch) |
| `lib/features/onboarding/presentation/seeding_screen.dart:183` | `await problemRepository.fetchPractice();` (same try/catch) |
| `lib/features/daily/presentation/withdrawn_screen.dart:61` | delete the call (and its try/catch); keep `context.go(AppRoute.daily.path)` |
| `lib/features/keys/data/key_repository_impl.dart:123-131` `_anyProbeProblem` | `practiceProblem()` first; if null, lowest-id of `available(config)`; if still null, the existing `Err(RelayError.transport())`. After a fresh install the cache may hold only the warm-up, so `available()` alone would fail the key check |

## 7. Remote config (`lib/core/network/dto/config_dto.dart`, `lib/core/config/runtime_config.dart`)

- `ConfigDto`: delete `contentManifestUrl` (`:96`, `:113`) and `rotation`
  (`:101`, `:127`); delete `RotationConfigDto` (`:63-76`).
- `RuntimeConfig`: delete `contentManifestUrl` (`:130`), `rotation` (`:141`),
  the `fromDto` mapping (`:115-120`), and `RotationConfig` (`:54-65`).
- The Worker still sends `content_manifest_url`; json_serializable ignores it.
- `test/unit/remote_config_test.dart`: remove `content_manifest_url` and
  `rotation` from fixtures; delete the rotation round-trip test (`:122-136`).

## 8. Analytics removal

Delete:

- `lib/core/analytics/` (whole directory)
- `lib/core/db/dao/event_dao.dart`, `lib/core/network/dto/event_dto.dart` (+ generated)
- `test/unit/analytics_contract_test.dart`, `test/unit/analytics_drain_test.dart`,
  `test/unit/analytics_payload_test.dart`, `test/fakes/fake_analytics_client.dart`

Remove every `emit(EventName…)` / `_analyticsClient?.emit` call (30 sites):

| File | Lines |
|---|---|
| `lib/features/chat/presentation/daily_session_cubit.dart` | 186, 399, 530, 532, 609, 617, 681, 718, 749, 788, 821, 837, 947, 952, 957, 989, 1000, 1006, 1027, 1031, 1042 |
| `lib/features/keys/presentation/key_entry_cubit.dart` | 27, 43, 70 |
| `lib/features/onboarding/presentation/welcome_screen.dart` | 59, 125 |
| `lib/main.dart` | 42 (+ the `'analytics.has_launched_before'` prefs read/write around :36) |
| `lib/core/config/remote_config_repository.dart` | 133 (+ the nullable `analyticsClient` param `:45,59`) |
| `lib/core/queue/outbox_drain_bloc.dart` | 114 |
| `lib/features/daily/presentation/review_day_screen.dart` | 88 |

Remove the `AnalyticsClient` parameter/field and its plumbing:

- `service_locator.dart:119-134` (registration) and `:223` (`OutboxDrainBloc(analyticsClient: …)`)
- `main.dart:117` (`buildAppRouter(analyticsClient: …)`)
- `app_router.dart:37` (import), `:85` (param), `:129`, `:212`, `:237`
- `daily_session_shell.dart:40,51,63`; `daily_session_cubit.dart:68,77,88`
- `welcome_screen.dart:32,38`; `review_day_screen.dart:23,30`
- `key_entry_cubit.dart:16`; `key_entry_form.dart:52`
- `outbox_drain_bloc.dart:49,60,79`

Watch for side effects hidden in an emit's arguments: if an `emit(...)` call
is the only use of a local (e.g. a computed prop), delete that local too —
`unused_local_variable` is an analyzer **error** in `analysis_options.yaml`.

`ShareCard.onShared` exists only to emit `shareCardShared`. Remove it end to end:

- `share_card.dart`: the `required this.onShared` param (`:72`), field (`:86`), and the `widget.onShared();` call (`:148`).
- `daily_session_cubit.dart:681`: delete `recordShare()`.
- `verdict_screen.dart:268` and `review_day_screen.dart:88`: drop the `onShared:` argument.
- `test/widget/share_and_retry_test.dart:52`: drop `onShared: _noop` (and `_noop` if now unused).

Tests: remove `analyticsClient: FakeAnalyticsClient()` (36 constructions in
30 files — `grep -rln FakeAnalyticsClient test integration_test`) and every
assertion on `.emitted` (`leak_blocked_test:192`, `key_entry_cubit_test:32-34`,
`finish_offer_test:110`, `hint_test:196-197,302-303`,
`session_cubit_send_turn_test:128-131`). If a test's **only** assertion was on
`.emitted`, delete that test case. `test/security/no_key_leak_test.dart`:
drop the `AnalyticsClientImpl` construction (`:192-199`) and
`buffered_events` from `_dumpEveryTable` (`:213-226`).

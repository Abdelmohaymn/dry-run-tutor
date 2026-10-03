import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/dao/problem_dao.dart';
import '../../../core/network/dto/problem_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/time/trusted_instant.dart';
import '../../../core/time/trusted_time_source.dart';
import '../domain/problem.dart';
import '../domain/problem_repository.dart';

/// FR-035a's "far enough ahead that today is readable offline" target.
const int _prefetchWindowDays = 14;

class ProblemRepositoryImpl implements ProblemRepository {
  ProblemRepositoryImpl({
    required RelayClient relayClient,
    required ProblemDao problemDao,
    required TrustedTimeSource timeSource,
    required RemoteConfigRepository configRepository,
  })  : _relayClient = relayClient,
        _problemDao = problemDao,
        _timeSource = timeSource,
        _configRepository = configRepository;

  final RelayClient _relayClient;
  final ProblemDao _problemDao;
  final TrustedTimeSource _timeSource;
  final RemoteConfigRepository _configRepository;

  @override
  Future<void> prefetchManifest() async {
    final RuntimeConfig config = _configRepository.cached() ?? await _configRepository.load();
    final ManifestDto manifest = await _relayClient.manifest(path: config.contentManifestUrl);
    final TrustedInstant now = await _timeSource.now();
    final DateTime today = DateTime.utc(now.utc.year, now.utc.month, now.utc.day);
    final DateTime windowEnd = today.add(const Duration(days: _prefetchWindowDays));

    final List<CachedProblemsCompanion> toStore = <CachedProblemsCompanion>[];
    for (final PublicHalfDto dto in manifest.problems) {
      if (config.killedProblemIds.contains(dto.id)) {
        continue;
      }
      final DateTime? problemDate = dto.date == null ? null : DateTime.tryParse('${dto.date}T00:00:00Z');
      // Dateless problems are evergreen (the repeat pool); dated ones are
      // stored only within the prefetch window.
      if (problemDate != null && problemDate.isAfter(windowEnd)) {
        continue;
      }
      toStore.add(
        CachedProblemsCompanion.insert(
          problemId: dto.id,
          schemaVersion: dto.schemaVersion,
          title: dto.title,
          ramp: dto.ramp,
          difficulty: Value(dto.difficulty),
          tags: dto.tags,
          source: dto.source,
          statement: dto.statement,
          constraints: dto.constraints,
          examplesJson: Value(
            dto.examples == null
                ? null
                : jsonEncode(
                    dto.examples!.map((ProblemExampleDto e) => e.toJson()).toList(growable: false),
                  ),
          ),
          estSpeakSeconds: dto.estSpeakSeconds,
          collections: dto.collections ?? const <String>[],
          glossaryTerms: dto.glossaryTerms,
          hintCount: dto.hintCount ?? 0,
          manifestDate: Value(dto.date),
          fetchedAt: now.utc,
        ),
      );
    }
    await _problemDao.upsertAll(toStore);
  }

  @override
  Future<Problem?> byId(String problemId) async {
    final CachedProblem? row = await _problemDao.byId(problemId);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Problem>> available(RuntimeConfig config) async {
    final List<CachedProblem> rows = await _problemDao.all();
    return rows
        .where((CachedProblem r) => !config.killedProblemIds.contains(r.problemId))
        // The warm-up is a real problem in the manifest — the relay has to
        // resolve it like any other to run a live practice turn — but it is
        // not one of the days. Without this it is simply another candidate
        // for `DailyRepository`'s rotation, and a learner's real problem for
        // the day is the one they were just walked through.
        .where((CachedProblem r) => !r.collections.contains(practiceCollection))
        .map(_toDomain)
        .toList(growable: false);
  }

  @override
  Future<Problem?> practiceProblem() async {
    final List<CachedProblem> rows = await _problemDao.all();
    for (final CachedProblem row in rows) {
      if (row.collections.contains(practiceCollection)) {
        return _toDomain(row);
      }
    }
    return null;
  }

  @override
  Future<bool> hasAnyCached() async {
    final List<CachedProblem> rows = await _problemDao.all();
    return rows.isNotEmpty;
  }

  Problem _toDomain(CachedProblem row) => Problem(
        schemaVersion: row.schemaVersion,
        id: row.problemId,
        date: row.manifestDate,
        title: row.title,
        ramp: row.ramp,
        difficulty: row.difficulty,
        tags: row.tags,
        source: row.source,
        statement: row.statement,
        constraints: row.constraints,
        examples: _decodeExamples(row.examplesJson),
        estSpeakSeconds: row.estSpeakSeconds,
        collections: row.collections,
        glossaryTerms: row.glossaryTerms,
        hintCount: row.hintCount,
      );

  /// Malformed cached JSON degrades to "this problem has no examples"
  /// rather than taking the daily loop down with it — the examples are an
  /// aid, and nothing else on the screen depends on them.
  static List<ProblemExample> _decodeExamples(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <ProblemExample>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ProblemExample>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> e) => ProblemExample(
              input: e['input'] as String? ?? '',
              output: e['output'] as String? ?? '',
              explanation: e['explanation'] as String?,
            ),
          )
          .toList(growable: false);
    } on FormatException {
      return const <ProblemExample>[];
    }
  }
}

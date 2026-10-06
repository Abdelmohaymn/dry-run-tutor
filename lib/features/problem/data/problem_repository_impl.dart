import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/config/runtime_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/dao/problem_dao.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/dto/problem_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/time/trusted_time_source.dart';
import '../../onboarding/domain/install_identity.dart';
import '../../onboarding/domain/install_repository.dart';
import '../domain/problem.dart';
import '../domain/problem_repository.dart';

class ProblemRepositoryImpl implements ProblemRepository {
  ProblemRepositoryImpl({
    required RelayClient relayClient,
    required ProblemDao problemDao,
    required TrustedTimeSource timeSource,
    required InstallRepository installRepository,
  })  : _relayClient = relayClient,
        _problemDao = problemDao,
        _timeSource = timeSource,
        _installRepository = installRepository;

  final RelayClient _relayClient;
  final ProblemDao _problemDao;
  final TrustedTimeSource _timeSource;
  final InstallRepository _installRepository;

  @override
  Future<Problem> fetchDaily(String date) async {
    final InstallIdentity identity = switch (await _installRepository.ensureIdentity()) {
      Ok<InstallIdentity>(:final value) => value,
      Err<InstallIdentity>(:final error) => throw RelayException(error),
    };
    final DailyResponseDto response = await _relayClient.daily(
      installId: identity.installId,
      date: date,
    );
    final DateTime now = (await _timeSource.now()).utc;
    await _problemDao.upsertAll(<CachedProblemsCompanion>[
      _companion(response.problem, servedFor: response.date, fetchedAt: now),
    ]);
    final CachedProblem row = (await _problemDao.byId(response.problem.id))!;
    return _toDomain(row);
  }

  @override
  Future<Problem?> cachedForDate(String date) async {
    final CachedProblem? row = await _problemDao.byManifestDate(date);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> fetchPractice() async {
    final PracticeResponseDto response = await _relayClient.practice();
    final DateTime now = (await _timeSource.now()).utc;
    await _problemDao.upsertAll(<CachedProblemsCompanion>[
      _companion(response.problem, servedFor: null, fetchedAt: now),
    ]);
  }

  CachedProblemsCompanion _companion(
    PublicHalfDto dto, {
    required String? servedFor,
    required DateTime fetchedAt,
  }) {
    return CachedProblemsCompanion.insert(
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
      // The UTC date `/v1/daily` served this problem for; null for the
      // warm-up, which belongs to no day.
      manifestDate: Value(servedFor),
      fetchedAt: fetchedAt,
    );
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $InstallIdentityTable extends InstallIdentity
    with TableInfo<$InstallIdentityTable, InstallIdentityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstallIdentityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _installUuidMeta = const VerificationMeta(
    'installUuid',
  );
  @override
  late final GeneratedColumn<String> installUuid = GeneratedColumn<String>(
    'install_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _installIdMeta = const VerificationMeta(
    'installId',
  );
  @override
  late final GeneratedColumn<String> installId = GeneratedColumn<String>(
    'install_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mintedAtMeta = const VerificationMeta(
    'mintedAt',
  );
  @override
  late final GeneratedColumn<DateTime> mintedAt = GeneratedColumn<DateTime>(
    'minted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, installUuid, installId, mintedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'install_identity';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstallIdentityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('install_uuid')) {
      context.handle(
        _installUuidMeta,
        installUuid.isAcceptableOrUnknown(
          data['install_uuid']!,
          _installUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installUuidMeta);
    }
    if (data.containsKey('install_id')) {
      context.handle(
        _installIdMeta,
        installId.isAcceptableOrUnknown(data['install_id']!, _installIdMeta),
      );
    } else if (isInserting) {
      context.missing(_installIdMeta);
    }
    if (data.containsKey('minted_at')) {
      context.handle(
        _mintedAtMeta,
        mintedAt.isAcceptableOrUnknown(data['minted_at']!, _mintedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_mintedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstallIdentityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstallIdentityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      installUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}install_uuid'],
      )!,
      installId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}install_id'],
      )!,
      mintedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}minted_at'],
      )!,
    );
  }

  @override
  $InstallIdentityTable createAlias(String alias) {
    return $InstallIdentityTable(attachedDatabase, alias);
  }
}

class InstallIdentityRow extends DataClass
    implements Insertable<InstallIdentityRow> {
  final int id;
  final String installUuid;
  final String installId;
  final DateTime mintedAt;
  const InstallIdentityRow({
    required this.id,
    required this.installUuid,
    required this.installId,
    required this.mintedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['install_uuid'] = Variable<String>(installUuid);
    map['install_id'] = Variable<String>(installId);
    map['minted_at'] = Variable<DateTime>(mintedAt);
    return map;
  }

  InstallIdentityCompanion toCompanion(bool nullToAbsent) {
    return InstallIdentityCompanion(
      id: Value(id),
      installUuid: Value(installUuid),
      installId: Value(installId),
      mintedAt: Value(mintedAt),
    );
  }

  factory InstallIdentityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstallIdentityRow(
      id: serializer.fromJson<int>(json['id']),
      installUuid: serializer.fromJson<String>(json['installUuid']),
      installId: serializer.fromJson<String>(json['installId']),
      mintedAt: serializer.fromJson<DateTime>(json['mintedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'installUuid': serializer.toJson<String>(installUuid),
      'installId': serializer.toJson<String>(installId),
      'mintedAt': serializer.toJson<DateTime>(mintedAt),
    };
  }

  InstallIdentityRow copyWith({
    int? id,
    String? installUuid,
    String? installId,
    DateTime? mintedAt,
  }) => InstallIdentityRow(
    id: id ?? this.id,
    installUuid: installUuid ?? this.installUuid,
    installId: installId ?? this.installId,
    mintedAt: mintedAt ?? this.mintedAt,
  );
  InstallIdentityRow copyWithCompanion(InstallIdentityCompanion data) {
    return InstallIdentityRow(
      id: data.id.present ? data.id.value : this.id,
      installUuid: data.installUuid.present
          ? data.installUuid.value
          : this.installUuid,
      installId: data.installId.present ? data.installId.value : this.installId,
      mintedAt: data.mintedAt.present ? data.mintedAt.value : this.mintedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstallIdentityRow(')
          ..write('id: $id, ')
          ..write('installUuid: $installUuid, ')
          ..write('installId: $installId, ')
          ..write('mintedAt: $mintedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, installUuid, installId, mintedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstallIdentityRow &&
          other.id == this.id &&
          other.installUuid == this.installUuid &&
          other.installId == this.installId &&
          other.mintedAt == this.mintedAt);
}

class InstallIdentityCompanion extends UpdateCompanion<InstallIdentityRow> {
  final Value<int> id;
  final Value<String> installUuid;
  final Value<String> installId;
  final Value<DateTime> mintedAt;
  const InstallIdentityCompanion({
    this.id = const Value.absent(),
    this.installUuid = const Value.absent(),
    this.installId = const Value.absent(),
    this.mintedAt = const Value.absent(),
  });
  InstallIdentityCompanion.insert({
    this.id = const Value.absent(),
    required String installUuid,
    required String installId,
    required DateTime mintedAt,
  }) : installUuid = Value(installUuid),
       installId = Value(installId),
       mintedAt = Value(mintedAt);
  static Insertable<InstallIdentityRow> custom({
    Expression<int>? id,
    Expression<String>? installUuid,
    Expression<String>? installId,
    Expression<DateTime>? mintedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (installUuid != null) 'install_uuid': installUuid,
      if (installId != null) 'install_id': installId,
      if (mintedAt != null) 'minted_at': mintedAt,
    });
  }

  InstallIdentityCompanion copyWith({
    Value<int>? id,
    Value<String>? installUuid,
    Value<String>? installId,
    Value<DateTime>? mintedAt,
  }) {
    return InstallIdentityCompanion(
      id: id ?? this.id,
      installUuid: installUuid ?? this.installUuid,
      installId: installId ?? this.installId,
      mintedAt: mintedAt ?? this.mintedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (installUuid.present) {
      map['install_uuid'] = Variable<String>(installUuid.value);
    }
    if (installId.present) {
      map['install_id'] = Variable<String>(installId.value);
    }
    if (mintedAt.present) {
      map['minted_at'] = Variable<DateTime>(mintedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstallIdentityCompanion(')
          ..write('id: $id, ')
          ..write('installUuid: $installUuid, ')
          ..write('installId: $installId, ')
          ..write('mintedAt: $mintedAt')
          ..write(')'))
        .toString();
  }
}

class $CachedProblemsTable extends CachedProblems
    with TableInfo<$CachedProblemsTable, CachedProblem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedProblemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _problemIdMeta = const VerificationMeta(
    'problemId',
  );
  @override
  late final GeneratedColumn<String> problemId = GeneratedColumn<String>(
    'problem_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 60),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rampMeta = const VerificationMeta('ramp');
  @override
  late final GeneratedColumn<String> ramp = GeneratedColumn<String>(
    'ramp',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($CachedProblemsTable.$convertertags);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementMeta = const VerificationMeta(
    'statement',
  );
  @override
  late final GeneratedColumn<String> statement = GeneratedColumn<String>(
    'statement',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  constraints = GeneratedColumn<String>(
    'constraints',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($CachedProblemsTable.$converterconstraints);
  static const VerificationMeta _examplesJsonMeta = const VerificationMeta(
    'examplesJson',
  );
  @override
  late final GeneratedColumn<String> examplesJson = GeneratedColumn<String>(
    'examples_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estSpeakSecondsMeta = const VerificationMeta(
    'estSpeakSeconds',
  );
  @override
  late final GeneratedColumn<int> estSpeakSeconds = GeneratedColumn<int>(
    'est_speak_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  collections = GeneratedColumn<String>(
    'collections',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($CachedProblemsTable.$convertercollections);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  glossaryTerms = GeneratedColumn<String>(
    'glossary_terms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($CachedProblemsTable.$converterglossaryTerms);
  static const VerificationMeta _hintCountMeta = const VerificationMeta(
    'hintCount',
  );
  @override
  late final GeneratedColumn<int> hintCount = GeneratedColumn<int>(
    'hint_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestDateMeta = const VerificationMeta(
    'manifestDate',
  );
  @override
  late final GeneratedColumn<String> manifestDate = GeneratedColumn<String>(
    'manifest_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    problemId,
    schemaVersion,
    title,
    ramp,
    difficulty,
    tags,
    source,
    statement,
    constraints,
    examplesJson,
    estSpeakSeconds,
    collections,
    glossaryTerms,
    hintCount,
    manifestDate,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_problems';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedProblem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('problem_id')) {
      context.handle(
        _problemIdMeta,
        problemId.isAcceptableOrUnknown(data['problem_id']!, _problemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_problemIdMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('ramp')) {
      context.handle(
        _rampMeta,
        ramp.isAcceptableOrUnknown(data['ramp']!, _rampMeta),
      );
    } else if (isInserting) {
      context.missing(_rampMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('statement')) {
      context.handle(
        _statementMeta,
        statement.isAcceptableOrUnknown(data['statement']!, _statementMeta),
      );
    } else if (isInserting) {
      context.missing(_statementMeta);
    }
    if (data.containsKey('examples_json')) {
      context.handle(
        _examplesJsonMeta,
        examplesJson.isAcceptableOrUnknown(
          data['examples_json']!,
          _examplesJsonMeta,
        ),
      );
    }
    if (data.containsKey('est_speak_seconds')) {
      context.handle(
        _estSpeakSecondsMeta,
        estSpeakSeconds.isAcceptableOrUnknown(
          data['est_speak_seconds']!,
          _estSpeakSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estSpeakSecondsMeta);
    }
    if (data.containsKey('hint_count')) {
      context.handle(
        _hintCountMeta,
        hintCount.isAcceptableOrUnknown(data['hint_count']!, _hintCountMeta),
      );
    } else if (isInserting) {
      context.missing(_hintCountMeta);
    }
    if (data.containsKey('manifest_date')) {
      context.handle(
        _manifestDateMeta,
        manifestDate.isAcceptableOrUnknown(
          data['manifest_date']!,
          _manifestDateMeta,
        ),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {problemId};
  @override
  CachedProblem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedProblem(
      problemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem_id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      ramp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ramp'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}difficulty'],
      ),
      tags: $CachedProblemsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      statement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statement'],
      )!,
      constraints: $CachedProblemsTable.$converterconstraints.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}constraints'],
        )!,
      ),
      examplesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}examples_json'],
      ),
      estSpeakSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}est_speak_seconds'],
      )!,
      collections: $CachedProblemsTable.$convertercollections.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}collections'],
        )!,
      ),
      glossaryTerms: $CachedProblemsTable.$converterglossaryTerms.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}glossary_terms'],
        )!,
      ),
      hintCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hint_count'],
      )!,
      manifestDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_date'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedProblemsTable createAlias(String alias) {
    return $CachedProblemsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterconstraints =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertercollections =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterglossaryTerms =
      const StringListConverter();
}

class CachedProblem extends DataClass implements Insertable<CachedProblem> {
  final String problemId;
  final int schemaVersion;
  final String title;
  final String ramp;
  final int? difficulty;
  final List<String> tags;
  final String source;
  final String statement;
  final List<String> constraints;

  /// `PublicHalf.examples`, held as the manifest's own JSON rather than
  /// through a converter: the shape is a list of objects, not the list of
  /// strings `StringListConverter` covers, and encoding it here would put
  /// a `features/` domain type inside `core/db`. Nullable — the field is
  /// optional in the manifest, and every row written before schema v2 has
  /// none.
  final String? examplesJson;
  final int estSpeakSeconds;
  final List<String> collections;
  final List<String> glossaryTerms;
  final int hintCount;
  final String? manifestDate;
  final DateTime fetchedAt;
  const CachedProblem({
    required this.problemId,
    required this.schemaVersion,
    required this.title,
    required this.ramp,
    this.difficulty,
    required this.tags,
    required this.source,
    required this.statement,
    required this.constraints,
    this.examplesJson,
    required this.estSpeakSeconds,
    required this.collections,
    required this.glossaryTerms,
    required this.hintCount,
    this.manifestDate,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['problem_id'] = Variable<String>(problemId);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['title'] = Variable<String>(title);
    map['ramp'] = Variable<String>(ramp);
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = Variable<int>(difficulty);
    }
    {
      map['tags'] = Variable<String>(
        $CachedProblemsTable.$convertertags.toSql(tags),
      );
    }
    map['source'] = Variable<String>(source);
    map['statement'] = Variable<String>(statement);
    {
      map['constraints'] = Variable<String>(
        $CachedProblemsTable.$converterconstraints.toSql(constraints),
      );
    }
    if (!nullToAbsent || examplesJson != null) {
      map['examples_json'] = Variable<String>(examplesJson);
    }
    map['est_speak_seconds'] = Variable<int>(estSpeakSeconds);
    {
      map['collections'] = Variable<String>(
        $CachedProblemsTable.$convertercollections.toSql(collections),
      );
    }
    {
      map['glossary_terms'] = Variable<String>(
        $CachedProblemsTable.$converterglossaryTerms.toSql(glossaryTerms),
      );
    }
    map['hint_count'] = Variable<int>(hintCount);
    if (!nullToAbsent || manifestDate != null) {
      map['manifest_date'] = Variable<String>(manifestDate);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedProblemsCompanion toCompanion(bool nullToAbsent) {
    return CachedProblemsCompanion(
      problemId: Value(problemId),
      schemaVersion: Value(schemaVersion),
      title: Value(title),
      ramp: Value(ramp),
      difficulty: difficulty == null && nullToAbsent
          ? const Value.absent()
          : Value(difficulty),
      tags: Value(tags),
      source: Value(source),
      statement: Value(statement),
      constraints: Value(constraints),
      examplesJson: examplesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(examplesJson),
      estSpeakSeconds: Value(estSpeakSeconds),
      collections: Value(collections),
      glossaryTerms: Value(glossaryTerms),
      hintCount: Value(hintCount),
      manifestDate: manifestDate == null && nullToAbsent
          ? const Value.absent()
          : Value(manifestDate),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedProblem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedProblem(
      problemId: serializer.fromJson<String>(json['problemId']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      title: serializer.fromJson<String>(json['title']),
      ramp: serializer.fromJson<String>(json['ramp']),
      difficulty: serializer.fromJson<int?>(json['difficulty']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      source: serializer.fromJson<String>(json['source']),
      statement: serializer.fromJson<String>(json['statement']),
      constraints: serializer.fromJson<List<String>>(json['constraints']),
      examplesJson: serializer.fromJson<String?>(json['examplesJson']),
      estSpeakSeconds: serializer.fromJson<int>(json['estSpeakSeconds']),
      collections: serializer.fromJson<List<String>>(json['collections']),
      glossaryTerms: serializer.fromJson<List<String>>(json['glossaryTerms']),
      hintCount: serializer.fromJson<int>(json['hintCount']),
      manifestDate: serializer.fromJson<String?>(json['manifestDate']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'problemId': serializer.toJson<String>(problemId),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'title': serializer.toJson<String>(title),
      'ramp': serializer.toJson<String>(ramp),
      'difficulty': serializer.toJson<int?>(difficulty),
      'tags': serializer.toJson<List<String>>(tags),
      'source': serializer.toJson<String>(source),
      'statement': serializer.toJson<String>(statement),
      'constraints': serializer.toJson<List<String>>(constraints),
      'examplesJson': serializer.toJson<String?>(examplesJson),
      'estSpeakSeconds': serializer.toJson<int>(estSpeakSeconds),
      'collections': serializer.toJson<List<String>>(collections),
      'glossaryTerms': serializer.toJson<List<String>>(glossaryTerms),
      'hintCount': serializer.toJson<int>(hintCount),
      'manifestDate': serializer.toJson<String?>(manifestDate),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedProblem copyWith({
    String? problemId,
    int? schemaVersion,
    String? title,
    String? ramp,
    Value<int?> difficulty = const Value.absent(),
    List<String>? tags,
    String? source,
    String? statement,
    List<String>? constraints,
    Value<String?> examplesJson = const Value.absent(),
    int? estSpeakSeconds,
    List<String>? collections,
    List<String>? glossaryTerms,
    int? hintCount,
    Value<String?> manifestDate = const Value.absent(),
    DateTime? fetchedAt,
  }) => CachedProblem(
    problemId: problemId ?? this.problemId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    title: title ?? this.title,
    ramp: ramp ?? this.ramp,
    difficulty: difficulty.present ? difficulty.value : this.difficulty,
    tags: tags ?? this.tags,
    source: source ?? this.source,
    statement: statement ?? this.statement,
    constraints: constraints ?? this.constraints,
    examplesJson: examplesJson.present ? examplesJson.value : this.examplesJson,
    estSpeakSeconds: estSpeakSeconds ?? this.estSpeakSeconds,
    collections: collections ?? this.collections,
    glossaryTerms: glossaryTerms ?? this.glossaryTerms,
    hintCount: hintCount ?? this.hintCount,
    manifestDate: manifestDate.present ? manifestDate.value : this.manifestDate,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedProblem copyWithCompanion(CachedProblemsCompanion data) {
    return CachedProblem(
      problemId: data.problemId.present ? data.problemId.value : this.problemId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      title: data.title.present ? data.title.value : this.title,
      ramp: data.ramp.present ? data.ramp.value : this.ramp,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      tags: data.tags.present ? data.tags.value : this.tags,
      source: data.source.present ? data.source.value : this.source,
      statement: data.statement.present ? data.statement.value : this.statement,
      constraints: data.constraints.present
          ? data.constraints.value
          : this.constraints,
      examplesJson: data.examplesJson.present
          ? data.examplesJson.value
          : this.examplesJson,
      estSpeakSeconds: data.estSpeakSeconds.present
          ? data.estSpeakSeconds.value
          : this.estSpeakSeconds,
      collections: data.collections.present
          ? data.collections.value
          : this.collections,
      glossaryTerms: data.glossaryTerms.present
          ? data.glossaryTerms.value
          : this.glossaryTerms,
      hintCount: data.hintCount.present ? data.hintCount.value : this.hintCount,
      manifestDate: data.manifestDate.present
          ? data.manifestDate.value
          : this.manifestDate,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedProblem(')
          ..write('problemId: $problemId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('title: $title, ')
          ..write('ramp: $ramp, ')
          ..write('difficulty: $difficulty, ')
          ..write('tags: $tags, ')
          ..write('source: $source, ')
          ..write('statement: $statement, ')
          ..write('constraints: $constraints, ')
          ..write('examplesJson: $examplesJson, ')
          ..write('estSpeakSeconds: $estSpeakSeconds, ')
          ..write('collections: $collections, ')
          ..write('glossaryTerms: $glossaryTerms, ')
          ..write('hintCount: $hintCount, ')
          ..write('manifestDate: $manifestDate, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    problemId,
    schemaVersion,
    title,
    ramp,
    difficulty,
    tags,
    source,
    statement,
    constraints,
    examplesJson,
    estSpeakSeconds,
    collections,
    glossaryTerms,
    hintCount,
    manifestDate,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedProblem &&
          other.problemId == this.problemId &&
          other.schemaVersion == this.schemaVersion &&
          other.title == this.title &&
          other.ramp == this.ramp &&
          other.difficulty == this.difficulty &&
          other.tags == this.tags &&
          other.source == this.source &&
          other.statement == this.statement &&
          other.constraints == this.constraints &&
          other.examplesJson == this.examplesJson &&
          other.estSpeakSeconds == this.estSpeakSeconds &&
          other.collections == this.collections &&
          other.glossaryTerms == this.glossaryTerms &&
          other.hintCount == this.hintCount &&
          other.manifestDate == this.manifestDate &&
          other.fetchedAt == this.fetchedAt);
}

class CachedProblemsCompanion extends UpdateCompanion<CachedProblem> {
  final Value<String> problemId;
  final Value<int> schemaVersion;
  final Value<String> title;
  final Value<String> ramp;
  final Value<int?> difficulty;
  final Value<List<String>> tags;
  final Value<String> source;
  final Value<String> statement;
  final Value<List<String>> constraints;
  final Value<String?> examplesJson;
  final Value<int> estSpeakSeconds;
  final Value<List<String>> collections;
  final Value<List<String>> glossaryTerms;
  final Value<int> hintCount;
  final Value<String?> manifestDate;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedProblemsCompanion({
    this.problemId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.title = const Value.absent(),
    this.ramp = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.tags = const Value.absent(),
    this.source = const Value.absent(),
    this.statement = const Value.absent(),
    this.constraints = const Value.absent(),
    this.examplesJson = const Value.absent(),
    this.estSpeakSeconds = const Value.absent(),
    this.collections = const Value.absent(),
    this.glossaryTerms = const Value.absent(),
    this.hintCount = const Value.absent(),
    this.manifestDate = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedProblemsCompanion.insert({
    required String problemId,
    required int schemaVersion,
    required String title,
    required String ramp,
    this.difficulty = const Value.absent(),
    required List<String> tags,
    required String source,
    required String statement,
    required List<String> constraints,
    this.examplesJson = const Value.absent(),
    required int estSpeakSeconds,
    required List<String> collections,
    required List<String> glossaryTerms,
    required int hintCount,
    this.manifestDate = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : problemId = Value(problemId),
       schemaVersion = Value(schemaVersion),
       title = Value(title),
       ramp = Value(ramp),
       tags = Value(tags),
       source = Value(source),
       statement = Value(statement),
       constraints = Value(constraints),
       estSpeakSeconds = Value(estSpeakSeconds),
       collections = Value(collections),
       glossaryTerms = Value(glossaryTerms),
       hintCount = Value(hintCount),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedProblem> custom({
    Expression<String>? problemId,
    Expression<int>? schemaVersion,
    Expression<String>? title,
    Expression<String>? ramp,
    Expression<int>? difficulty,
    Expression<String>? tags,
    Expression<String>? source,
    Expression<String>? statement,
    Expression<String>? constraints,
    Expression<String>? examplesJson,
    Expression<int>? estSpeakSeconds,
    Expression<String>? collections,
    Expression<String>? glossaryTerms,
    Expression<int>? hintCount,
    Expression<String>? manifestDate,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (problemId != null) 'problem_id': problemId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (title != null) 'title': title,
      if (ramp != null) 'ramp': ramp,
      if (difficulty != null) 'difficulty': difficulty,
      if (tags != null) 'tags': tags,
      if (source != null) 'source': source,
      if (statement != null) 'statement': statement,
      if (constraints != null) 'constraints': constraints,
      if (examplesJson != null) 'examples_json': examplesJson,
      if (estSpeakSeconds != null) 'est_speak_seconds': estSpeakSeconds,
      if (collections != null) 'collections': collections,
      if (glossaryTerms != null) 'glossary_terms': glossaryTerms,
      if (hintCount != null) 'hint_count': hintCount,
      if (manifestDate != null) 'manifest_date': manifestDate,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedProblemsCompanion copyWith({
    Value<String>? problemId,
    Value<int>? schemaVersion,
    Value<String>? title,
    Value<String>? ramp,
    Value<int?>? difficulty,
    Value<List<String>>? tags,
    Value<String>? source,
    Value<String>? statement,
    Value<List<String>>? constraints,
    Value<String?>? examplesJson,
    Value<int>? estSpeakSeconds,
    Value<List<String>>? collections,
    Value<List<String>>? glossaryTerms,
    Value<int>? hintCount,
    Value<String?>? manifestDate,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedProblemsCompanion(
      problemId: problemId ?? this.problemId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      title: title ?? this.title,
      ramp: ramp ?? this.ramp,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      statement: statement ?? this.statement,
      constraints: constraints ?? this.constraints,
      examplesJson: examplesJson ?? this.examplesJson,
      estSpeakSeconds: estSpeakSeconds ?? this.estSpeakSeconds,
      collections: collections ?? this.collections,
      glossaryTerms: glossaryTerms ?? this.glossaryTerms,
      hintCount: hintCount ?? this.hintCount,
      manifestDate: manifestDate ?? this.manifestDate,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (problemId.present) {
      map['problem_id'] = Variable<String>(problemId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (ramp.present) {
      map['ramp'] = Variable<String>(ramp.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $CachedProblemsTable.$convertertags.toSql(tags.value),
      );
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (statement.present) {
      map['statement'] = Variable<String>(statement.value);
    }
    if (constraints.present) {
      map['constraints'] = Variable<String>(
        $CachedProblemsTable.$converterconstraints.toSql(constraints.value),
      );
    }
    if (examplesJson.present) {
      map['examples_json'] = Variable<String>(examplesJson.value);
    }
    if (estSpeakSeconds.present) {
      map['est_speak_seconds'] = Variable<int>(estSpeakSeconds.value);
    }
    if (collections.present) {
      map['collections'] = Variable<String>(
        $CachedProblemsTable.$convertercollections.toSql(collections.value),
      );
    }
    if (glossaryTerms.present) {
      map['glossary_terms'] = Variable<String>(
        $CachedProblemsTable.$converterglossaryTerms.toSql(glossaryTerms.value),
      );
    }
    if (hintCount.present) {
      map['hint_count'] = Variable<int>(hintCount.value);
    }
    if (manifestDate.present) {
      map['manifest_date'] = Variable<String>(manifestDate.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedProblemsCompanion(')
          ..write('problemId: $problemId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('title: $title, ')
          ..write('ramp: $ramp, ')
          ..write('difficulty: $difficulty, ')
          ..write('tags: $tags, ')
          ..write('source: $source, ')
          ..write('statement: $statement, ')
          ..write('constraints: $constraints, ')
          ..write('examplesJson: $examplesJson, ')
          ..write('estSpeakSeconds: $estSpeakSeconds, ')
          ..write('collections: $collections, ')
          ..write('glossaryTerms: $glossaryTerms, ')
          ..write('hintCount: $hintCount, ')
          ..write('manifestDate: $manifestDate, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _problemIdMeta = const VerificationMeta(
    'problemId',
  );
  @override
  late final GeneratedColumn<String> problemId = GeneratedColumn<String>(
    'problem_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cached_problems (problem_id)',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SessionPath, String> path =
      GeneratedColumn<String>(
        'path',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SessionPath>($SessionsTable.$converterpath);
  @override
  late final GeneratedColumnWithTypeConverter<SessionStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SessionStatus>($SessionsTable.$converterstatus);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _solutionRequestCountMeta =
      const VerificationMeta('solutionRequestCount');
  @override
  late final GeneratedColumn<int> solutionRequestCount = GeneratedColumn<int>(
    'solution_request_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isRepeatMeta = const VerificationMeta(
    'isRepeat',
  );
  @override
  late final GeneratedColumn<bool> isRepeat = GeneratedColumn<bool>(
    'is_repeat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_repeat" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPracticeMeta = const VerificationMeta(
    'isPractice',
  );
  @override
  late final GeneratedColumn<bool> isPractice = GeneratedColumn<bool>(
    'is_practice',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_practice" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _disputedMeta = const VerificationMeta(
    'disputed',
  );
  @override
  late final GeneratedColumn<bool> disputed = GeneratedColumn<bool>(
    'disputed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("disputed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _disputedAtMeta = const VerificationMeta(
    'disputedAt',
  );
  @override
  late final GeneratedColumn<DateTime> disputedAt = GeneratedColumn<DateTime>(
    'disputed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _turnIndexMeta = const VerificationMeta(
    'turnIndex',
  );
  @override
  late final GeneratedColumn<int> turnIndex = GeneratedColumn<int>(
    'turn_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _turnsRemainingMeta = const VerificationMeta(
    'turnsRemaining',
  );
  @override
  late final GeneratedColumn<int> turnsRemaining = GeneratedColumn<int>(
    'turns_remaining',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hintsRevealedMeta = const VerificationMeta(
    'hintsRevealed',
  );
  @override
  late final GeneratedColumn<int> hintsRevealed = GeneratedColumn<int>(
    'hints_revealed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hintsRemainingMeta = const VerificationMeta(
    'hintsRemaining',
  );
  @override
  late final GeneratedColumn<int> hintsRemaining = GeneratedColumn<int>(
    'hints_remaining',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionEndedMeta = const VerificationMeta(
    'sessionEnded',
  );
  @override
  late final GeneratedColumn<String> sessionEnded = GeneratedColumn<String>(
    'session_ended',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    problemId,
    day,
    path,
    status,
    providerId,
    summary,
    solutionRequestCount,
    isRepeat,
    isPractice,
    disputed,
    disputedAt,
    startedAt,
    completedAt,
    turnIndex,
    turnsRemaining,
    hintsRevealed,
    hintsRemaining,
    sessionEnded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('problem_id')) {
      context.handle(
        _problemIdMeta,
        problemId.isAcceptableOrUnknown(data['problem_id']!, _problemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_problemIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('solution_request_count')) {
      context.handle(
        _solutionRequestCountMeta,
        solutionRequestCount.isAcceptableOrUnknown(
          data['solution_request_count']!,
          _solutionRequestCountMeta,
        ),
      );
    }
    if (data.containsKey('is_repeat')) {
      context.handle(
        _isRepeatMeta,
        isRepeat.isAcceptableOrUnknown(data['is_repeat']!, _isRepeatMeta),
      );
    }
    if (data.containsKey('is_practice')) {
      context.handle(
        _isPracticeMeta,
        isPractice.isAcceptableOrUnknown(data['is_practice']!, _isPracticeMeta),
      );
    }
    if (data.containsKey('disputed')) {
      context.handle(
        _disputedMeta,
        disputed.isAcceptableOrUnknown(data['disputed']!, _disputedMeta),
      );
    }
    if (data.containsKey('disputed_at')) {
      context.handle(
        _disputedAtMeta,
        disputedAt.isAcceptableOrUnknown(data['disputed_at']!, _disputedAtMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('turn_index')) {
      context.handle(
        _turnIndexMeta,
        turnIndex.isAcceptableOrUnknown(data['turn_index']!, _turnIndexMeta),
      );
    }
    if (data.containsKey('turns_remaining')) {
      context.handle(
        _turnsRemainingMeta,
        turnsRemaining.isAcceptableOrUnknown(
          data['turns_remaining']!,
          _turnsRemainingMeta,
        ),
      );
    }
    if (data.containsKey('hints_revealed')) {
      context.handle(
        _hintsRevealedMeta,
        hintsRevealed.isAcceptableOrUnknown(
          data['hints_revealed']!,
          _hintsRevealedMeta,
        ),
      );
    }
    if (data.containsKey('hints_remaining')) {
      context.handle(
        _hintsRemainingMeta,
        hintsRemaining.isAcceptableOrUnknown(
          data['hints_remaining']!,
          _hintsRemainingMeta,
        ),
      );
    }
    if (data.containsKey('session_ended')) {
      context.handle(
        _sessionEndedMeta,
        sessionEnded.isAcceptableOrUnknown(
          data['session_ended']!,
          _sessionEndedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      problemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem_id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      path: $SessionsTable.$converterpath.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}path'],
        )!,
      ),
      status: $SessionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      solutionRequestCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}solution_request_count'],
      )!,
      isRepeat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_repeat'],
      )!,
      isPractice: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_practice'],
      )!,
      disputed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}disputed'],
      )!,
      disputedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}disputed_at'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      turnIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turn_index'],
      )!,
      turnsRemaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}turns_remaining'],
      ),
      hintsRevealed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hints_revealed'],
      )!,
      hintsRemaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hints_remaining'],
      ),
      sessionEnded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_ended'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SessionPath, String, String> $converterpath =
      const EnumNameConverter<SessionPath>(SessionPath.values);
  static JsonTypeConverter2<SessionStatus, String, String> $converterstatus =
      const EnumNameConverter<SessionStatus>(SessionStatus.values);
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String problemId;
  final String day;
  final SessionPath path;
  final SessionStatus status;
  final String? providerId;
  final String? summary;
  final int solutionRequestCount;
  final bool isRepeat;

  /// The onboarding walkthrough's session. Its own row rather than a
  /// special case elsewhere: the walkthrough is a real conversation on a
  /// real problem, it just is not one of the days. `todaysSession()`
  /// filters on this, because it reads with `getSingleOrNull()` and a
  /// walkthrough taken on the same day as today's problem would otherwise
  /// be a second row for that day — a throw, not a wrong answer.
  final bool isPractice;
  final bool disputed;
  final DateTime? disputedAt;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int turnIndex;
  final int? turnsRemaining;
  final int hintsRevealed;
  final int? hintsRemaining;
  final String? sessionEnded;
  const SessionRow({
    required this.id,
    required this.problemId,
    required this.day,
    required this.path,
    required this.status,
    this.providerId,
    this.summary,
    required this.solutionRequestCount,
    required this.isRepeat,
    required this.isPractice,
    required this.disputed,
    this.disputedAt,
    required this.startedAt,
    this.completedAt,
    required this.turnIndex,
    this.turnsRemaining,
    required this.hintsRevealed,
    this.hintsRemaining,
    this.sessionEnded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['problem_id'] = Variable<String>(problemId);
    map['day'] = Variable<String>(day);
    {
      map['path'] = Variable<String>($SessionsTable.$converterpath.toSql(path));
    }
    {
      map['status'] = Variable<String>(
        $SessionsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || providerId != null) {
      map['provider_id'] = Variable<String>(providerId);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['solution_request_count'] = Variable<int>(solutionRequestCount);
    map['is_repeat'] = Variable<bool>(isRepeat);
    map['is_practice'] = Variable<bool>(isPractice);
    map['disputed'] = Variable<bool>(disputed);
    if (!nullToAbsent || disputedAt != null) {
      map['disputed_at'] = Variable<DateTime>(disputedAt);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['turn_index'] = Variable<int>(turnIndex);
    if (!nullToAbsent || turnsRemaining != null) {
      map['turns_remaining'] = Variable<int>(turnsRemaining);
    }
    map['hints_revealed'] = Variable<int>(hintsRevealed);
    if (!nullToAbsent || hintsRemaining != null) {
      map['hints_remaining'] = Variable<int>(hintsRemaining);
    }
    if (!nullToAbsent || sessionEnded != null) {
      map['session_ended'] = Variable<String>(sessionEnded);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      problemId: Value(problemId),
      day: Value(day),
      path: Value(path),
      status: Value(status),
      providerId: providerId == null && nullToAbsent
          ? const Value.absent()
          : Value(providerId),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      solutionRequestCount: Value(solutionRequestCount),
      isRepeat: Value(isRepeat),
      isPractice: Value(isPractice),
      disputed: Value(disputed),
      disputedAt: disputedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(disputedAt),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      turnIndex: Value(turnIndex),
      turnsRemaining: turnsRemaining == null && nullToAbsent
          ? const Value.absent()
          : Value(turnsRemaining),
      hintsRevealed: Value(hintsRevealed),
      hintsRemaining: hintsRemaining == null && nullToAbsent
          ? const Value.absent()
          : Value(hintsRemaining),
      sessionEnded: sessionEnded == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionEnded),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      problemId: serializer.fromJson<String>(json['problemId']),
      day: serializer.fromJson<String>(json['day']),
      path: $SessionsTable.$converterpath.fromJson(
        serializer.fromJson<String>(json['path']),
      ),
      status: $SessionsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      providerId: serializer.fromJson<String?>(json['providerId']),
      summary: serializer.fromJson<String?>(json['summary']),
      solutionRequestCount: serializer.fromJson<int>(
        json['solutionRequestCount'],
      ),
      isRepeat: serializer.fromJson<bool>(json['isRepeat']),
      isPractice: serializer.fromJson<bool>(json['isPractice']),
      disputed: serializer.fromJson<bool>(json['disputed']),
      disputedAt: serializer.fromJson<DateTime?>(json['disputedAt']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      turnIndex: serializer.fromJson<int>(json['turnIndex']),
      turnsRemaining: serializer.fromJson<int?>(json['turnsRemaining']),
      hintsRevealed: serializer.fromJson<int>(json['hintsRevealed']),
      hintsRemaining: serializer.fromJson<int?>(json['hintsRemaining']),
      sessionEnded: serializer.fromJson<String?>(json['sessionEnded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'problemId': serializer.toJson<String>(problemId),
      'day': serializer.toJson<String>(day),
      'path': serializer.toJson<String>(
        $SessionsTable.$converterpath.toJson(path),
      ),
      'status': serializer.toJson<String>(
        $SessionsTable.$converterstatus.toJson(status),
      ),
      'providerId': serializer.toJson<String?>(providerId),
      'summary': serializer.toJson<String?>(summary),
      'solutionRequestCount': serializer.toJson<int>(solutionRequestCount),
      'isRepeat': serializer.toJson<bool>(isRepeat),
      'isPractice': serializer.toJson<bool>(isPractice),
      'disputed': serializer.toJson<bool>(disputed),
      'disputedAt': serializer.toJson<DateTime?>(disputedAt),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'turnIndex': serializer.toJson<int>(turnIndex),
      'turnsRemaining': serializer.toJson<int?>(turnsRemaining),
      'hintsRevealed': serializer.toJson<int>(hintsRevealed),
      'hintsRemaining': serializer.toJson<int?>(hintsRemaining),
      'sessionEnded': serializer.toJson<String?>(sessionEnded),
    };
  }

  SessionRow copyWith({
    String? id,
    String? problemId,
    String? day,
    SessionPath? path,
    SessionStatus? status,
    Value<String?> providerId = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    int? solutionRequestCount,
    bool? isRepeat,
    bool? isPractice,
    bool? disputed,
    Value<DateTime?> disputedAt = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    int? turnIndex,
    Value<int?> turnsRemaining = const Value.absent(),
    int? hintsRevealed,
    Value<int?> hintsRemaining = const Value.absent(),
    Value<String?> sessionEnded = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    problemId: problemId ?? this.problemId,
    day: day ?? this.day,
    path: path ?? this.path,
    status: status ?? this.status,
    providerId: providerId.present ? providerId.value : this.providerId,
    summary: summary.present ? summary.value : this.summary,
    solutionRequestCount: solutionRequestCount ?? this.solutionRequestCount,
    isRepeat: isRepeat ?? this.isRepeat,
    isPractice: isPractice ?? this.isPractice,
    disputed: disputed ?? this.disputed,
    disputedAt: disputedAt.present ? disputedAt.value : this.disputedAt,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    turnIndex: turnIndex ?? this.turnIndex,
    turnsRemaining: turnsRemaining.present
        ? turnsRemaining.value
        : this.turnsRemaining,
    hintsRevealed: hintsRevealed ?? this.hintsRevealed,
    hintsRemaining: hintsRemaining.present
        ? hintsRemaining.value
        : this.hintsRemaining,
    sessionEnded: sessionEnded.present ? sessionEnded.value : this.sessionEnded,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      problemId: data.problemId.present ? data.problemId.value : this.problemId,
      day: data.day.present ? data.day.value : this.day,
      path: data.path.present ? data.path.value : this.path,
      status: data.status.present ? data.status.value : this.status,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      summary: data.summary.present ? data.summary.value : this.summary,
      solutionRequestCount: data.solutionRequestCount.present
          ? data.solutionRequestCount.value
          : this.solutionRequestCount,
      isRepeat: data.isRepeat.present ? data.isRepeat.value : this.isRepeat,
      isPractice: data.isPractice.present
          ? data.isPractice.value
          : this.isPractice,
      disputed: data.disputed.present ? data.disputed.value : this.disputed,
      disputedAt: data.disputedAt.present
          ? data.disputedAt.value
          : this.disputedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      turnIndex: data.turnIndex.present ? data.turnIndex.value : this.turnIndex,
      turnsRemaining: data.turnsRemaining.present
          ? data.turnsRemaining.value
          : this.turnsRemaining,
      hintsRevealed: data.hintsRevealed.present
          ? data.hintsRevealed.value
          : this.hintsRevealed,
      hintsRemaining: data.hintsRemaining.present
          ? data.hintsRemaining.value
          : this.hintsRemaining,
      sessionEnded: data.sessionEnded.present
          ? data.sessionEnded.value
          : this.sessionEnded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('problemId: $problemId, ')
          ..write('day: $day, ')
          ..write('path: $path, ')
          ..write('status: $status, ')
          ..write('providerId: $providerId, ')
          ..write('summary: $summary, ')
          ..write('solutionRequestCount: $solutionRequestCount, ')
          ..write('isRepeat: $isRepeat, ')
          ..write('isPractice: $isPractice, ')
          ..write('disputed: $disputed, ')
          ..write('disputedAt: $disputedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('turnIndex: $turnIndex, ')
          ..write('turnsRemaining: $turnsRemaining, ')
          ..write('hintsRevealed: $hintsRevealed, ')
          ..write('hintsRemaining: $hintsRemaining, ')
          ..write('sessionEnded: $sessionEnded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    problemId,
    day,
    path,
    status,
    providerId,
    summary,
    solutionRequestCount,
    isRepeat,
    isPractice,
    disputed,
    disputedAt,
    startedAt,
    completedAt,
    turnIndex,
    turnsRemaining,
    hintsRevealed,
    hintsRemaining,
    sessionEnded,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.problemId == this.problemId &&
          other.day == this.day &&
          other.path == this.path &&
          other.status == this.status &&
          other.providerId == this.providerId &&
          other.summary == this.summary &&
          other.solutionRequestCount == this.solutionRequestCount &&
          other.isRepeat == this.isRepeat &&
          other.isPractice == this.isPractice &&
          other.disputed == this.disputed &&
          other.disputedAt == this.disputedAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.turnIndex == this.turnIndex &&
          other.turnsRemaining == this.turnsRemaining &&
          other.hintsRevealed == this.hintsRevealed &&
          other.hintsRemaining == this.hintsRemaining &&
          other.sessionEnded == this.sessionEnded);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> problemId;
  final Value<String> day;
  final Value<SessionPath> path;
  final Value<SessionStatus> status;
  final Value<String?> providerId;
  final Value<String?> summary;
  final Value<int> solutionRequestCount;
  final Value<bool> isRepeat;
  final Value<bool> isPractice;
  final Value<bool> disputed;
  final Value<DateTime?> disputedAt;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> turnIndex;
  final Value<int?> turnsRemaining;
  final Value<int> hintsRevealed;
  final Value<int?> hintsRemaining;
  final Value<String?> sessionEnded;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.problemId = const Value.absent(),
    this.day = const Value.absent(),
    this.path = const Value.absent(),
    this.status = const Value.absent(),
    this.providerId = const Value.absent(),
    this.summary = const Value.absent(),
    this.solutionRequestCount = const Value.absent(),
    this.isRepeat = const Value.absent(),
    this.isPractice = const Value.absent(),
    this.disputed = const Value.absent(),
    this.disputedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.turnIndex = const Value.absent(),
    this.turnsRemaining = const Value.absent(),
    this.hintsRevealed = const Value.absent(),
    this.hintsRemaining = const Value.absent(),
    this.sessionEnded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String problemId,
    required String day,
    required SessionPath path,
    required SessionStatus status,
    this.providerId = const Value.absent(),
    this.summary = const Value.absent(),
    this.solutionRequestCount = const Value.absent(),
    this.isRepeat = const Value.absent(),
    this.isPractice = const Value.absent(),
    this.disputed = const Value.absent(),
    this.disputedAt = const Value.absent(),
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.turnIndex = const Value.absent(),
    this.turnsRemaining = const Value.absent(),
    this.hintsRevealed = const Value.absent(),
    this.hintsRemaining = const Value.absent(),
    this.sessionEnded = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       problemId = Value(problemId),
       day = Value(day),
       path = Value(path),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? problemId,
    Expression<String>? day,
    Expression<String>? path,
    Expression<String>? status,
    Expression<String>? providerId,
    Expression<String>? summary,
    Expression<int>? solutionRequestCount,
    Expression<bool>? isRepeat,
    Expression<bool>? isPractice,
    Expression<bool>? disputed,
    Expression<DateTime>? disputedAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? turnIndex,
    Expression<int>? turnsRemaining,
    Expression<int>? hintsRevealed,
    Expression<int>? hintsRemaining,
    Expression<String>? sessionEnded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (problemId != null) 'problem_id': problemId,
      if (day != null) 'day': day,
      if (path != null) 'path': path,
      if (status != null) 'status': status,
      if (providerId != null) 'provider_id': providerId,
      if (summary != null) 'summary': summary,
      if (solutionRequestCount != null)
        'solution_request_count': solutionRequestCount,
      if (isRepeat != null) 'is_repeat': isRepeat,
      if (isPractice != null) 'is_practice': isPractice,
      if (disputed != null) 'disputed': disputed,
      if (disputedAt != null) 'disputed_at': disputedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (turnIndex != null) 'turn_index': turnIndex,
      if (turnsRemaining != null) 'turns_remaining': turnsRemaining,
      if (hintsRevealed != null) 'hints_revealed': hintsRevealed,
      if (hintsRemaining != null) 'hints_remaining': hintsRemaining,
      if (sessionEnded != null) 'session_ended': sessionEnded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? problemId,
    Value<String>? day,
    Value<SessionPath>? path,
    Value<SessionStatus>? status,
    Value<String?>? providerId,
    Value<String?>? summary,
    Value<int>? solutionRequestCount,
    Value<bool>? isRepeat,
    Value<bool>? isPractice,
    Value<bool>? disputed,
    Value<DateTime?>? disputedAt,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? turnIndex,
    Value<int?>? turnsRemaining,
    Value<int>? hintsRevealed,
    Value<int?>? hintsRemaining,
    Value<String?>? sessionEnded,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      problemId: problemId ?? this.problemId,
      day: day ?? this.day,
      path: path ?? this.path,
      status: status ?? this.status,
      providerId: providerId ?? this.providerId,
      summary: summary ?? this.summary,
      solutionRequestCount: solutionRequestCount ?? this.solutionRequestCount,
      isRepeat: isRepeat ?? this.isRepeat,
      isPractice: isPractice ?? this.isPractice,
      disputed: disputed ?? this.disputed,
      disputedAt: disputedAt ?? this.disputedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      turnIndex: turnIndex ?? this.turnIndex,
      turnsRemaining: turnsRemaining ?? this.turnsRemaining,
      hintsRevealed: hintsRevealed ?? this.hintsRevealed,
      hintsRemaining: hintsRemaining ?? this.hintsRemaining,
      sessionEnded: sessionEnded ?? this.sessionEnded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (problemId.present) {
      map['problem_id'] = Variable<String>(problemId.value);
    }
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(
        $SessionsTable.$converterpath.toSql(path.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $SessionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (solutionRequestCount.present) {
      map['solution_request_count'] = Variable<int>(solutionRequestCount.value);
    }
    if (isRepeat.present) {
      map['is_repeat'] = Variable<bool>(isRepeat.value);
    }
    if (isPractice.present) {
      map['is_practice'] = Variable<bool>(isPractice.value);
    }
    if (disputed.present) {
      map['disputed'] = Variable<bool>(disputed.value);
    }
    if (disputedAt.present) {
      map['disputed_at'] = Variable<DateTime>(disputedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (turnIndex.present) {
      map['turn_index'] = Variable<int>(turnIndex.value);
    }
    if (turnsRemaining.present) {
      map['turns_remaining'] = Variable<int>(turnsRemaining.value);
    }
    if (hintsRevealed.present) {
      map['hints_revealed'] = Variable<int>(hintsRevealed.value);
    }
    if (hintsRemaining.present) {
      map['hints_remaining'] = Variable<int>(hintsRemaining.value);
    }
    if (sessionEnded.present) {
      map['session_ended'] = Variable<String>(sessionEnded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('problemId: $problemId, ')
          ..write('day: $day, ')
          ..write('path: $path, ')
          ..write('status: $status, ')
          ..write('providerId: $providerId, ')
          ..write('summary: $summary, ')
          ..write('solutionRequestCount: $solutionRequestCount, ')
          ..write('isRepeat: $isRepeat, ')
          ..write('isPractice: $isPractice, ')
          ..write('disputed: $disputed, ')
          ..write('disputedAt: $disputedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('turnIndex: $turnIndex, ')
          ..write('turnsRemaining: $turnsRemaining, ')
          ..write('hintsRevealed: $hintsRevealed, ')
          ..write('hintsRemaining: $hintsRemaining, ')
          ..write('sessionEnded: $sessionEnded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TurnRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TurnRole>($MessagesTable.$converterrole);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 8000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MessageKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MessageKind>($MessagesTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<Delivery, String> delivery =
      GeneratedColumn<String>(
        'delivery',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Delivery>($MessagesTable.$converterdelivery);
  static const VerificationMeta _recognisedDraftMeta = const VerificationMeta(
    'recognisedDraft',
  );
  @override
  late final GeneratedColumn<String> recognisedDraft = GeneratedColumn<String>(
    'recognised_draft',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InputMode?, String> inputMode =
      GeneratedColumn<String>(
        'input_mode',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<InputMode?>($MessagesTable.$converterinputModen);
  static const VerificationMeta _coveredBySummaryMeta = const VerificationMeta(
    'coveredBySummary',
  );
  @override
  late final GeneratedColumn<bool> coveredBySummary = GeneratedColumn<bool>(
    'covered_by_summary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("covered_by_summary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    seq,
    role,
    body,
    kind,
    delivery,
    recognisedDraft,
    inputMode,
    coveredBySummary,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('recognised_draft')) {
      context.handle(
        _recognisedDraftMeta,
        recognisedDraft.isAcceptableOrUnknown(
          data['recognised_draft']!,
          _recognisedDraftMeta,
        ),
      );
    }
    if (data.containsKey('covered_by_summary')) {
      context.handle(
        _coveredBySummaryMeta,
        coveredBySummary.isAcceptableOrUnknown(
          data['covered_by_summary']!,
          _coveredBySummaryMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      role: $MessagesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      kind: $MessagesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      delivery: $MessagesTable.$converterdelivery.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}delivery'],
        )!,
      ),
      recognisedDraft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recognised_draft'],
      ),
      inputMode: $MessagesTable.$converterinputModen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}input_mode'],
        ),
      ),
      coveredBySummary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}covered_by_summary'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TurnRole, String, String> $converterrole =
      const EnumNameConverter<TurnRole>(TurnRole.values);
  static JsonTypeConverter2<MessageKind, String, String> $converterkind =
      const EnumNameConverter<MessageKind>(MessageKind.values);
  static JsonTypeConverter2<Delivery, String, String> $converterdelivery =
      const EnumNameConverter<Delivery>(Delivery.values);
  static JsonTypeConverter2<InputMode, String, String> $converterinputMode =
      const EnumNameConverter<InputMode>(InputMode.values);
  static JsonTypeConverter2<InputMode?, String?, String?> $converterinputModen =
      JsonTypeConverter2.asNullable($converterinputMode);
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final String id;
  final String sessionId;
  final int seq;
  final TurnRole role;
  final String body;
  final MessageKind kind;
  final Delivery delivery;
  final String? recognisedDraft;
  final InputMode? inputMode;
  final bool coveredBySummary;
  final DateTime createdAt;
  const MessageRow({
    required this.id,
    required this.sessionId,
    required this.seq,
    required this.role,
    required this.body,
    required this.kind,
    required this.delivery,
    this.recognisedDraft,
    this.inputMode,
    required this.coveredBySummary,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['seq'] = Variable<int>(seq);
    {
      map['role'] = Variable<String>($MessagesTable.$converterrole.toSql(role));
    }
    map['text'] = Variable<String>(body);
    {
      map['kind'] = Variable<String>($MessagesTable.$converterkind.toSql(kind));
    }
    {
      map['delivery'] = Variable<String>(
        $MessagesTable.$converterdelivery.toSql(delivery),
      );
    }
    if (!nullToAbsent || recognisedDraft != null) {
      map['recognised_draft'] = Variable<String>(recognisedDraft);
    }
    if (!nullToAbsent || inputMode != null) {
      map['input_mode'] = Variable<String>(
        $MessagesTable.$converterinputModen.toSql(inputMode),
      );
    }
    map['covered_by_summary'] = Variable<bool>(coveredBySummary);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      seq: Value(seq),
      role: Value(role),
      body: Value(body),
      kind: Value(kind),
      delivery: Value(delivery),
      recognisedDraft: recognisedDraft == null && nullToAbsent
          ? const Value.absent()
          : Value(recognisedDraft),
      inputMode: inputMode == null && nullToAbsent
          ? const Value.absent()
          : Value(inputMode),
      coveredBySummary: Value(coveredBySummary),
      createdAt: Value(createdAt),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      seq: serializer.fromJson<int>(json['seq']),
      role: $MessagesTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      body: serializer.fromJson<String>(json['body']),
      kind: $MessagesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      delivery: $MessagesTable.$converterdelivery.fromJson(
        serializer.fromJson<String>(json['delivery']),
      ),
      recognisedDraft: serializer.fromJson<String?>(json['recognisedDraft']),
      inputMode: $MessagesTable.$converterinputModen.fromJson(
        serializer.fromJson<String?>(json['inputMode']),
      ),
      coveredBySummary: serializer.fromJson<bool>(json['coveredBySummary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'seq': serializer.toJson<int>(seq),
      'role': serializer.toJson<String>(
        $MessagesTable.$converterrole.toJson(role),
      ),
      'body': serializer.toJson<String>(body),
      'kind': serializer.toJson<String>(
        $MessagesTable.$converterkind.toJson(kind),
      ),
      'delivery': serializer.toJson<String>(
        $MessagesTable.$converterdelivery.toJson(delivery),
      ),
      'recognisedDraft': serializer.toJson<String?>(recognisedDraft),
      'inputMode': serializer.toJson<String?>(
        $MessagesTable.$converterinputModen.toJson(inputMode),
      ),
      'coveredBySummary': serializer.toJson<bool>(coveredBySummary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageRow copyWith({
    String? id,
    String? sessionId,
    int? seq,
    TurnRole? role,
    String? body,
    MessageKind? kind,
    Delivery? delivery,
    Value<String?> recognisedDraft = const Value.absent(),
    Value<InputMode?> inputMode = const Value.absent(),
    bool? coveredBySummary,
    DateTime? createdAt,
  }) => MessageRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    seq: seq ?? this.seq,
    role: role ?? this.role,
    body: body ?? this.body,
    kind: kind ?? this.kind,
    delivery: delivery ?? this.delivery,
    recognisedDraft: recognisedDraft.present
        ? recognisedDraft.value
        : this.recognisedDraft,
    inputMode: inputMode.present ? inputMode.value : this.inputMode,
    coveredBySummary: coveredBySummary ?? this.coveredBySummary,
    createdAt: createdAt ?? this.createdAt,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      seq: data.seq.present ? data.seq.value : this.seq,
      role: data.role.present ? data.role.value : this.role,
      body: data.body.present ? data.body.value : this.body,
      kind: data.kind.present ? data.kind.value : this.kind,
      delivery: data.delivery.present ? data.delivery.value : this.delivery,
      recognisedDraft: data.recognisedDraft.present
          ? data.recognisedDraft.value
          : this.recognisedDraft,
      inputMode: data.inputMode.present ? data.inputMode.value : this.inputMode,
      coveredBySummary: data.coveredBySummary.present
          ? data.coveredBySummary.value
          : this.coveredBySummary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seq: $seq, ')
          ..write('role: $role, ')
          ..write('body: $body, ')
          ..write('kind: $kind, ')
          ..write('delivery: $delivery, ')
          ..write('recognisedDraft: $recognisedDraft, ')
          ..write('inputMode: $inputMode, ')
          ..write('coveredBySummary: $coveredBySummary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    seq,
    role,
    body,
    kind,
    delivery,
    recognisedDraft,
    inputMode,
    coveredBySummary,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.seq == this.seq &&
          other.role == this.role &&
          other.body == this.body &&
          other.kind == this.kind &&
          other.delivery == this.delivery &&
          other.recognisedDraft == this.recognisedDraft &&
          other.inputMode == this.inputMode &&
          other.coveredBySummary == this.coveredBySummary &&
          other.createdAt == this.createdAt);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> seq;
  final Value<TurnRole> role;
  final Value<String> body;
  final Value<MessageKind> kind;
  final Value<Delivery> delivery;
  final Value<String?> recognisedDraft;
  final Value<InputMode?> inputMode;
  final Value<bool> coveredBySummary;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.seq = const Value.absent(),
    this.role = const Value.absent(),
    this.body = const Value.absent(),
    this.kind = const Value.absent(),
    this.delivery = const Value.absent(),
    this.recognisedDraft = const Value.absent(),
    this.inputMode = const Value.absent(),
    this.coveredBySummary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String sessionId,
    required int seq,
    required TurnRole role,
    required String body,
    required MessageKind kind,
    required Delivery delivery,
    this.recognisedDraft = const Value.absent(),
    this.inputMode = const Value.absent(),
    this.coveredBySummary = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       seq = Value(seq),
       role = Value(role),
       body = Value(body),
       kind = Value(kind),
       delivery = Value(delivery),
       createdAt = Value(createdAt);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? seq,
    Expression<String>? role,
    Expression<String>? body,
    Expression<String>? kind,
    Expression<String>? delivery,
    Expression<String>? recognisedDraft,
    Expression<String>? inputMode,
    Expression<bool>? coveredBySummary,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (seq != null) 'seq': seq,
      if (role != null) 'role': role,
      if (body != null) 'text': body,
      if (kind != null) 'kind': kind,
      if (delivery != null) 'delivery': delivery,
      if (recognisedDraft != null) 'recognised_draft': recognisedDraft,
      if (inputMode != null) 'input_mode': inputMode,
      if (coveredBySummary != null) 'covered_by_summary': coveredBySummary,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? seq,
    Value<TurnRole>? role,
    Value<String>? body,
    Value<MessageKind>? kind,
    Value<Delivery>? delivery,
    Value<String?>? recognisedDraft,
    Value<InputMode?>? inputMode,
    Value<bool>? coveredBySummary,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      seq: seq ?? this.seq,
      role: role ?? this.role,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      delivery: delivery ?? this.delivery,
      recognisedDraft: recognisedDraft ?? this.recognisedDraft,
      inputMode: inputMode ?? this.inputMode,
      coveredBySummary: coveredBySummary ?? this.coveredBySummary,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $MessagesTable.$converterrole.toSql(role.value),
      );
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $MessagesTable.$converterkind.toSql(kind.value),
      );
    }
    if (delivery.present) {
      map['delivery'] = Variable<String>(
        $MessagesTable.$converterdelivery.toSql(delivery.value),
      );
    }
    if (recognisedDraft.present) {
      map['recognised_draft'] = Variable<String>(recognisedDraft.value);
    }
    if (inputMode.present) {
      map['input_mode'] = Variable<String>(
        $MessagesTable.$converterinputModen.toSql(inputMode.value),
      );
    }
    if (coveredBySummary.present) {
      map['covered_by_summary'] = Variable<bool>(coveredBySummary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seq: $seq, ')
          ..write('role: $role, ')
          ..write('body: $body, ')
          ..write('kind: $kind, ')
          ..write('delivery: $delivery, ')
          ..write('recognisedDraft: $recognisedDraft, ')
          ..write('inputMode: $inputMode, ')
          ..write('coveredBySummary: $coveredBySummary, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftsTable extends Drafts with TableInfo<$DraftsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recognisedMeta = const VerificationMeta(
    'recognised',
  );
  @override
  late final GeneratedColumn<String> recognised = GeneratedColumn<String>(
    'recognised',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repairedMeta = const VerificationMeta(
    'repaired',
  );
  @override
  late final GeneratedColumn<String> repaired = GeneratedColumn<String>(
    'repaired',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InputMode, String> inputMode =
      GeneratedColumn<String>(
        'input_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<InputMode>($DraftsTable.$converterinputMode);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    body,
    recognised,
    repaired,
    inputMode,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['text']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('recognised')) {
      context.handle(
        _recognisedMeta,
        recognised.isAcceptableOrUnknown(data['recognised']!, _recognisedMeta),
      );
    }
    if (data.containsKey('repaired')) {
      context.handle(
        _repairedMeta,
        repaired.isAcceptableOrUnknown(data['repaired']!, _repairedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      recognised: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recognised'],
      ),
      repaired: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repaired'],
      ),
      inputMode: $DraftsTable.$converterinputMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}input_mode'],
        )!,
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DraftsTable createAlias(String alias) {
    return $DraftsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InputMode, String, String> $converterinputMode =
      const EnumNameConverter<InputMode>(InputMode.values);
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String sessionId;
  final String body;
  final String? recognised;
  final String? repaired;
  final InputMode inputMode;
  final DateTime updatedAt;
  const DraftRow({
    required this.sessionId,
    required this.body,
    this.recognised,
    this.repaired,
    required this.inputMode,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || recognised != null) {
      map['recognised'] = Variable<String>(recognised);
    }
    if (!nullToAbsent || repaired != null) {
      map['repaired'] = Variable<String>(repaired);
    }
    {
      map['input_mode'] = Variable<String>(
        $DraftsTable.$converterinputMode.toSql(inputMode),
      );
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DraftsCompanion toCompanion(bool nullToAbsent) {
    return DraftsCompanion(
      sessionId: Value(sessionId),
      body: Value(body),
      recognised: recognised == null && nullToAbsent
          ? const Value.absent()
          : Value(recognised),
      repaired: repaired == null && nullToAbsent
          ? const Value.absent()
          : Value(repaired),
      inputMode: Value(inputMode),
      updatedAt: Value(updatedAt),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      body: serializer.fromJson<String>(json['body']),
      recognised: serializer.fromJson<String?>(json['recognised']),
      repaired: serializer.fromJson<String?>(json['repaired']),
      inputMode: $DraftsTable.$converterinputMode.fromJson(
        serializer.fromJson<String>(json['inputMode']),
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'body': serializer.toJson<String>(body),
      'recognised': serializer.toJson<String?>(recognised),
      'repaired': serializer.toJson<String?>(repaired),
      'inputMode': serializer.toJson<String>(
        $DraftsTable.$converterinputMode.toJson(inputMode),
      ),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DraftRow copyWith({
    String? sessionId,
    String? body,
    Value<String?> recognised = const Value.absent(),
    Value<String?> repaired = const Value.absent(),
    InputMode? inputMode,
    DateTime? updatedAt,
  }) => DraftRow(
    sessionId: sessionId ?? this.sessionId,
    body: body ?? this.body,
    recognised: recognised.present ? recognised.value : this.recognised,
    repaired: repaired.present ? repaired.value : this.repaired,
    inputMode: inputMode ?? this.inputMode,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DraftRow copyWithCompanion(DraftsCompanion data) {
    return DraftRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      body: data.body.present ? data.body.value : this.body,
      recognised: data.recognised.present
          ? data.recognised.value
          : this.recognised,
      repaired: data.repaired.present ? data.repaired.value : this.repaired,
      inputMode: data.inputMode.present ? data.inputMode.value : this.inputMode,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('sessionId: $sessionId, ')
          ..write('body: $body, ')
          ..write('recognised: $recognised, ')
          ..write('repaired: $repaired, ')
          ..write('inputMode: $inputMode, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, body, recognised, repaired, inputMode, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.sessionId == this.sessionId &&
          other.body == this.body &&
          other.recognised == this.recognised &&
          other.repaired == this.repaired &&
          other.inputMode == this.inputMode &&
          other.updatedAt == this.updatedAt);
}

class DraftsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> sessionId;
  final Value<String> body;
  final Value<String?> recognised;
  final Value<String?> repaired;
  final Value<InputMode> inputMode;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DraftsCompanion({
    this.sessionId = const Value.absent(),
    this.body = const Value.absent(),
    this.recognised = const Value.absent(),
    this.repaired = const Value.absent(),
    this.inputMode = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftsCompanion.insert({
    required String sessionId,
    required String body,
    this.recognised = const Value.absent(),
    this.repaired = const Value.absent(),
    required InputMode inputMode,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       body = Value(body),
       inputMode = Value(inputMode),
       updatedAt = Value(updatedAt);
  static Insertable<DraftRow> custom({
    Expression<String>? sessionId,
    Expression<String>? body,
    Expression<String>? recognised,
    Expression<String>? repaired,
    Expression<String>? inputMode,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (body != null) 'text': body,
      if (recognised != null) 'recognised': recognised,
      if (repaired != null) 'repaired': repaired,
      if (inputMode != null) 'input_mode': inputMode,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? body,
    Value<String?>? recognised,
    Value<String?>? repaired,
    Value<InputMode>? inputMode,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DraftsCompanion(
      sessionId: sessionId ?? this.sessionId,
      body: body ?? this.body,
      recognised: recognised ?? this.recognised,
      repaired: repaired ?? this.repaired,
      inputMode: inputMode ?? this.inputMode,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (recognised.present) {
      map['recognised'] = Variable<String>(recognised.value);
    }
    if (repaired.present) {
      map['repaired'] = Variable<String>(repaired.value);
    }
    if (inputMode.present) {
      map['input_mode'] = Variable<String>(
        $DraftsTable.$converterinputMode.toSql(inputMode.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('body: $body, ')
          ..write('recognised: $recognised, ')
          ..write('repaired: $repaired, ')
          ..write('inputMode: $inputMode, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssessmentsTable extends Assessments
    with TableInfo<$AssessmentsTable, AssessmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssessmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _matchedApproachMeta = const VerificationMeta(
    'matchedApproach',
  );
  @override
  late final GeneratedColumn<String> matchedApproach = GeneratedColumn<String>(
    'matched_approach',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MatchedVerdict, String>
  matchedVerdict = GeneratedColumn<String>(
    'matched_verdict',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<MatchedVerdict>($AssessmentsTable.$convertermatchedVerdict);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  insightsHit = GeneratedColumn<String>(
    'insights_hit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($AssessmentsTable.$converterinsightsHit);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
  insightsAssisted = GeneratedColumn<String>(
    'insights_assisted',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<String>?>($AssessmentsTable.$converterinsightsAssistedn);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  insightsMissed = GeneratedColumn<String>(
    'insights_missed',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($AssessmentsTable.$converterinsightsMissed);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  wrongTurnsTaken = GeneratedColumn<String>(
    'wrong_turns_taken',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($AssessmentsTable.$converterwrongTurnsTaken);
  static const VerificationMeta _complexityJsonMeta = const VerificationMeta(
    'complexityJson',
  );
  @override
  late final GeneratedColumn<String> complexityJson = GeneratedColumn<String>(
    'complexity_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Verdict, String> verdict =
      GeneratedColumn<String>(
        'verdict',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Verdict>($AssessmentsTable.$converterverdict);
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feedbackMeta = const VerificationMeta(
    'feedback',
  );
  @override
  late final GeneratedColumn<String> feedback = GeneratedColumn<String>(
    'feedback',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 320),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editorialMeta = const VerificationMeta(
    'editorial',
  );
  @override
  late final GeneratedColumn<String> editorial = GeneratedColumn<String>(
    'editorial',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revealAtIndexMeta = const VerificationMeta(
    'revealAtIndex',
  );
  @override
  late final GeneratedColumn<int> revealAtIndex = GeneratedColumn<int>(
    'reveal_at_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    matchedApproach,
    matchedVerdict,
    insightsHit,
    insightsAssisted,
    insightsMissed,
    wrongTurnsTaken,
    complexityJson,
    verdict,
    confidence,
    feedback,
    editorial,
    revealAtIndex,
    rawJson,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assessments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssessmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('matched_approach')) {
      context.handle(
        _matchedApproachMeta,
        matchedApproach.isAcceptableOrUnknown(
          data['matched_approach']!,
          _matchedApproachMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_matchedApproachMeta);
    }
    if (data.containsKey('complexity_json')) {
      context.handle(
        _complexityJsonMeta,
        complexityJson.isAcceptableOrUnknown(
          data['complexity_json']!,
          _complexityJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_complexityJsonMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('feedback')) {
      context.handle(
        _feedbackMeta,
        feedback.isAcceptableOrUnknown(data['feedback']!, _feedbackMeta),
      );
    } else if (isInserting) {
      context.missing(_feedbackMeta);
    }
    if (data.containsKey('editorial')) {
      context.handle(
        _editorialMeta,
        editorial.isAcceptableOrUnknown(data['editorial']!, _editorialMeta),
      );
    } else if (isInserting) {
      context.missing(_editorialMeta);
    }
    if (data.containsKey('reveal_at_index')) {
      context.handle(
        _revealAtIndexMeta,
        revealAtIndex.isAcceptableOrUnknown(
          data['reveal_at_index']!,
          _revealAtIndexMeta,
        ),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rawJsonMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  AssessmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssessmentRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      matchedApproach: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matched_approach'],
      )!,
      matchedVerdict: $AssessmentsTable.$convertermatchedVerdict.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}matched_verdict'],
        )!,
      ),
      insightsHit: $AssessmentsTable.$converterinsightsHit.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}insights_hit'],
        )!,
      ),
      insightsAssisted: $AssessmentsTable.$converterinsightsAssistedn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}insights_assisted'],
        ),
      ),
      insightsMissed: $AssessmentsTable.$converterinsightsMissed.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}insights_missed'],
        )!,
      ),
      wrongTurnsTaken: $AssessmentsTable.$converterwrongTurnsTaken.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}wrong_turns_taken'],
        )!,
      ),
      complexityJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}complexity_json'],
      )!,
      verdict: $AssessmentsTable.$converterverdict.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}verdict'],
        )!,
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      feedback: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feedback'],
      )!,
      editorial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}editorial'],
      )!,
      revealAtIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reveal_at_index'],
      ),
      rawJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_json'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}received_at'],
      )!,
    );
  }

  @override
  $AssessmentsTable createAlias(String alias) {
    return $AssessmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MatchedVerdict, String, String>
  $convertermatchedVerdict = const EnumNameConverter<MatchedVerdict>(
    MatchedVerdict.values,
  );
  static TypeConverter<List<String>, String> $converterinsightsHit =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterinsightsAssisted =
      const StringListConverter();
  static TypeConverter<List<String>?, String?> $converterinsightsAssistedn =
      NullAwareTypeConverter.wrap($converterinsightsAssisted);
  static TypeConverter<List<String>, String> $converterinsightsMissed =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterwrongTurnsTaken =
      const StringListConverter();
  static JsonTypeConverter2<Verdict, String, String> $converterverdict =
      const EnumNameConverter<Verdict>(Verdict.values);
}

class AssessmentRow extends DataClass implements Insertable<AssessmentRow> {
  final String sessionId;
  final String matchedApproach;
  final MatchedVerdict matchedVerdict;
  final List<String> insightsHit;

  /// Added in v7 (PLAN_07 D12): nullable with no backfill — `null` reads
  /// as empty, which is true of every assessment judged before it existed.
  final List<String>? insightsAssisted;
  final List<String> insightsMissed;
  final List<String> wrongTurnsTaken;
  final String complexityJson;
  final Verdict verdict;
  final double confidence;
  final String feedback;
  final String editorial;
  final int? revealAtIndex;
  final String rawJson;
  final DateTime receivedAt;
  const AssessmentRow({
    required this.sessionId,
    required this.matchedApproach,
    required this.matchedVerdict,
    required this.insightsHit,
    this.insightsAssisted,
    required this.insightsMissed,
    required this.wrongTurnsTaken,
    required this.complexityJson,
    required this.verdict,
    required this.confidence,
    required this.feedback,
    required this.editorial,
    this.revealAtIndex,
    required this.rawJson,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['matched_approach'] = Variable<String>(matchedApproach);
    {
      map['matched_verdict'] = Variable<String>(
        $AssessmentsTable.$convertermatchedVerdict.toSql(matchedVerdict),
      );
    }
    {
      map['insights_hit'] = Variable<String>(
        $AssessmentsTable.$converterinsightsHit.toSql(insightsHit),
      );
    }
    if (!nullToAbsent || insightsAssisted != null) {
      map['insights_assisted'] = Variable<String>(
        $AssessmentsTable.$converterinsightsAssistedn.toSql(insightsAssisted),
      );
    }
    {
      map['insights_missed'] = Variable<String>(
        $AssessmentsTable.$converterinsightsMissed.toSql(insightsMissed),
      );
    }
    {
      map['wrong_turns_taken'] = Variable<String>(
        $AssessmentsTable.$converterwrongTurnsTaken.toSql(wrongTurnsTaken),
      );
    }
    map['complexity_json'] = Variable<String>(complexityJson);
    {
      map['verdict'] = Variable<String>(
        $AssessmentsTable.$converterverdict.toSql(verdict),
      );
    }
    map['confidence'] = Variable<double>(confidence);
    map['feedback'] = Variable<String>(feedback);
    map['editorial'] = Variable<String>(editorial);
    if (!nullToAbsent || revealAtIndex != null) {
      map['reveal_at_index'] = Variable<int>(revealAtIndex);
    }
    map['raw_json'] = Variable<String>(rawJson);
    map['received_at'] = Variable<DateTime>(receivedAt);
    return map;
  }

  AssessmentsCompanion toCompanion(bool nullToAbsent) {
    return AssessmentsCompanion(
      sessionId: Value(sessionId),
      matchedApproach: Value(matchedApproach),
      matchedVerdict: Value(matchedVerdict),
      insightsHit: Value(insightsHit),
      insightsAssisted: insightsAssisted == null && nullToAbsent
          ? const Value.absent()
          : Value(insightsAssisted),
      insightsMissed: Value(insightsMissed),
      wrongTurnsTaken: Value(wrongTurnsTaken),
      complexityJson: Value(complexityJson),
      verdict: Value(verdict),
      confidence: Value(confidence),
      feedback: Value(feedback),
      editorial: Value(editorial),
      revealAtIndex: revealAtIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(revealAtIndex),
      rawJson: Value(rawJson),
      receivedAt: Value(receivedAt),
    );
  }

  factory AssessmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssessmentRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      matchedApproach: serializer.fromJson<String>(json['matchedApproach']),
      matchedVerdict: $AssessmentsTable.$convertermatchedVerdict.fromJson(
        serializer.fromJson<String>(json['matchedVerdict']),
      ),
      insightsHit: serializer.fromJson<List<String>>(json['insightsHit']),
      insightsAssisted: serializer.fromJson<List<String>?>(
        json['insightsAssisted'],
      ),
      insightsMissed: serializer.fromJson<List<String>>(json['insightsMissed']),
      wrongTurnsTaken: serializer.fromJson<List<String>>(
        json['wrongTurnsTaken'],
      ),
      complexityJson: serializer.fromJson<String>(json['complexityJson']),
      verdict: $AssessmentsTable.$converterverdict.fromJson(
        serializer.fromJson<String>(json['verdict']),
      ),
      confidence: serializer.fromJson<double>(json['confidence']),
      feedback: serializer.fromJson<String>(json['feedback']),
      editorial: serializer.fromJson<String>(json['editorial']),
      revealAtIndex: serializer.fromJson<int?>(json['revealAtIndex']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'matchedApproach': serializer.toJson<String>(matchedApproach),
      'matchedVerdict': serializer.toJson<String>(
        $AssessmentsTable.$convertermatchedVerdict.toJson(matchedVerdict),
      ),
      'insightsHit': serializer.toJson<List<String>>(insightsHit),
      'insightsAssisted': serializer.toJson<List<String>?>(insightsAssisted),
      'insightsMissed': serializer.toJson<List<String>>(insightsMissed),
      'wrongTurnsTaken': serializer.toJson<List<String>>(wrongTurnsTaken),
      'complexityJson': serializer.toJson<String>(complexityJson),
      'verdict': serializer.toJson<String>(
        $AssessmentsTable.$converterverdict.toJson(verdict),
      ),
      'confidence': serializer.toJson<double>(confidence),
      'feedback': serializer.toJson<String>(feedback),
      'editorial': serializer.toJson<String>(editorial),
      'revealAtIndex': serializer.toJson<int?>(revealAtIndex),
      'rawJson': serializer.toJson<String>(rawJson),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
    };
  }

  AssessmentRow copyWith({
    String? sessionId,
    String? matchedApproach,
    MatchedVerdict? matchedVerdict,
    List<String>? insightsHit,
    Value<List<String>?> insightsAssisted = const Value.absent(),
    List<String>? insightsMissed,
    List<String>? wrongTurnsTaken,
    String? complexityJson,
    Verdict? verdict,
    double? confidence,
    String? feedback,
    String? editorial,
    Value<int?> revealAtIndex = const Value.absent(),
    String? rawJson,
    DateTime? receivedAt,
  }) => AssessmentRow(
    sessionId: sessionId ?? this.sessionId,
    matchedApproach: matchedApproach ?? this.matchedApproach,
    matchedVerdict: matchedVerdict ?? this.matchedVerdict,
    insightsHit: insightsHit ?? this.insightsHit,
    insightsAssisted: insightsAssisted.present
        ? insightsAssisted.value
        : this.insightsAssisted,
    insightsMissed: insightsMissed ?? this.insightsMissed,
    wrongTurnsTaken: wrongTurnsTaken ?? this.wrongTurnsTaken,
    complexityJson: complexityJson ?? this.complexityJson,
    verdict: verdict ?? this.verdict,
    confidence: confidence ?? this.confidence,
    feedback: feedback ?? this.feedback,
    editorial: editorial ?? this.editorial,
    revealAtIndex: revealAtIndex.present
        ? revealAtIndex.value
        : this.revealAtIndex,
    rawJson: rawJson ?? this.rawJson,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  AssessmentRow copyWithCompanion(AssessmentsCompanion data) {
    return AssessmentRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      matchedApproach: data.matchedApproach.present
          ? data.matchedApproach.value
          : this.matchedApproach,
      matchedVerdict: data.matchedVerdict.present
          ? data.matchedVerdict.value
          : this.matchedVerdict,
      insightsHit: data.insightsHit.present
          ? data.insightsHit.value
          : this.insightsHit,
      insightsAssisted: data.insightsAssisted.present
          ? data.insightsAssisted.value
          : this.insightsAssisted,
      insightsMissed: data.insightsMissed.present
          ? data.insightsMissed.value
          : this.insightsMissed,
      wrongTurnsTaken: data.wrongTurnsTaken.present
          ? data.wrongTurnsTaken.value
          : this.wrongTurnsTaken,
      complexityJson: data.complexityJson.present
          ? data.complexityJson.value
          : this.complexityJson,
      verdict: data.verdict.present ? data.verdict.value : this.verdict,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      feedback: data.feedback.present ? data.feedback.value : this.feedback,
      editorial: data.editorial.present ? data.editorial.value : this.editorial,
      revealAtIndex: data.revealAtIndex.present
          ? data.revealAtIndex.value
          : this.revealAtIndex,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentRow(')
          ..write('sessionId: $sessionId, ')
          ..write('matchedApproach: $matchedApproach, ')
          ..write('matchedVerdict: $matchedVerdict, ')
          ..write('insightsHit: $insightsHit, ')
          ..write('insightsAssisted: $insightsAssisted, ')
          ..write('insightsMissed: $insightsMissed, ')
          ..write('wrongTurnsTaken: $wrongTurnsTaken, ')
          ..write('complexityJson: $complexityJson, ')
          ..write('verdict: $verdict, ')
          ..write('confidence: $confidence, ')
          ..write('feedback: $feedback, ')
          ..write('editorial: $editorial, ')
          ..write('revealAtIndex: $revealAtIndex, ')
          ..write('rawJson: $rawJson, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    matchedApproach,
    matchedVerdict,
    insightsHit,
    insightsAssisted,
    insightsMissed,
    wrongTurnsTaken,
    complexityJson,
    verdict,
    confidence,
    feedback,
    editorial,
    revealAtIndex,
    rawJson,
    receivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssessmentRow &&
          other.sessionId == this.sessionId &&
          other.matchedApproach == this.matchedApproach &&
          other.matchedVerdict == this.matchedVerdict &&
          other.insightsHit == this.insightsHit &&
          other.insightsAssisted == this.insightsAssisted &&
          other.insightsMissed == this.insightsMissed &&
          other.wrongTurnsTaken == this.wrongTurnsTaken &&
          other.complexityJson == this.complexityJson &&
          other.verdict == this.verdict &&
          other.confidence == this.confidence &&
          other.feedback == this.feedback &&
          other.editorial == this.editorial &&
          other.revealAtIndex == this.revealAtIndex &&
          other.rawJson == this.rawJson &&
          other.receivedAt == this.receivedAt);
}

class AssessmentsCompanion extends UpdateCompanion<AssessmentRow> {
  final Value<String> sessionId;
  final Value<String> matchedApproach;
  final Value<MatchedVerdict> matchedVerdict;
  final Value<List<String>> insightsHit;
  final Value<List<String>?> insightsAssisted;
  final Value<List<String>> insightsMissed;
  final Value<List<String>> wrongTurnsTaken;
  final Value<String> complexityJson;
  final Value<Verdict> verdict;
  final Value<double> confidence;
  final Value<String> feedback;
  final Value<String> editorial;
  final Value<int?> revealAtIndex;
  final Value<String> rawJson;
  final Value<DateTime> receivedAt;
  final Value<int> rowid;
  const AssessmentsCompanion({
    this.sessionId = const Value.absent(),
    this.matchedApproach = const Value.absent(),
    this.matchedVerdict = const Value.absent(),
    this.insightsHit = const Value.absent(),
    this.insightsAssisted = const Value.absent(),
    this.insightsMissed = const Value.absent(),
    this.wrongTurnsTaken = const Value.absent(),
    this.complexityJson = const Value.absent(),
    this.verdict = const Value.absent(),
    this.confidence = const Value.absent(),
    this.feedback = const Value.absent(),
    this.editorial = const Value.absent(),
    this.revealAtIndex = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssessmentsCompanion.insert({
    required String sessionId,
    required String matchedApproach,
    required MatchedVerdict matchedVerdict,
    required List<String> insightsHit,
    this.insightsAssisted = const Value.absent(),
    required List<String> insightsMissed,
    required List<String> wrongTurnsTaken,
    required String complexityJson,
    required Verdict verdict,
    required double confidence,
    required String feedback,
    required String editorial,
    this.revealAtIndex = const Value.absent(),
    required String rawJson,
    required DateTime receivedAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       matchedApproach = Value(matchedApproach),
       matchedVerdict = Value(matchedVerdict),
       insightsHit = Value(insightsHit),
       insightsMissed = Value(insightsMissed),
       wrongTurnsTaken = Value(wrongTurnsTaken),
       complexityJson = Value(complexityJson),
       verdict = Value(verdict),
       confidence = Value(confidence),
       feedback = Value(feedback),
       editorial = Value(editorial),
       rawJson = Value(rawJson),
       receivedAt = Value(receivedAt);
  static Insertable<AssessmentRow> custom({
    Expression<String>? sessionId,
    Expression<String>? matchedApproach,
    Expression<String>? matchedVerdict,
    Expression<String>? insightsHit,
    Expression<String>? insightsAssisted,
    Expression<String>? insightsMissed,
    Expression<String>? wrongTurnsTaken,
    Expression<String>? complexityJson,
    Expression<String>? verdict,
    Expression<double>? confidence,
    Expression<String>? feedback,
    Expression<String>? editorial,
    Expression<int>? revealAtIndex,
    Expression<String>? rawJson,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (matchedApproach != null) 'matched_approach': matchedApproach,
      if (matchedVerdict != null) 'matched_verdict': matchedVerdict,
      if (insightsHit != null) 'insights_hit': insightsHit,
      if (insightsAssisted != null) 'insights_assisted': insightsAssisted,
      if (insightsMissed != null) 'insights_missed': insightsMissed,
      if (wrongTurnsTaken != null) 'wrong_turns_taken': wrongTurnsTaken,
      if (complexityJson != null) 'complexity_json': complexityJson,
      if (verdict != null) 'verdict': verdict,
      if (confidence != null) 'confidence': confidence,
      if (feedback != null) 'feedback': feedback,
      if (editorial != null) 'editorial': editorial,
      if (revealAtIndex != null) 'reveal_at_index': revealAtIndex,
      if (rawJson != null) 'raw_json': rawJson,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssessmentsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? matchedApproach,
    Value<MatchedVerdict>? matchedVerdict,
    Value<List<String>>? insightsHit,
    Value<List<String>?>? insightsAssisted,
    Value<List<String>>? insightsMissed,
    Value<List<String>>? wrongTurnsTaken,
    Value<String>? complexityJson,
    Value<Verdict>? verdict,
    Value<double>? confidence,
    Value<String>? feedback,
    Value<String>? editorial,
    Value<int?>? revealAtIndex,
    Value<String>? rawJson,
    Value<DateTime>? receivedAt,
    Value<int>? rowid,
  }) {
    return AssessmentsCompanion(
      sessionId: sessionId ?? this.sessionId,
      matchedApproach: matchedApproach ?? this.matchedApproach,
      matchedVerdict: matchedVerdict ?? this.matchedVerdict,
      insightsHit: insightsHit ?? this.insightsHit,
      insightsAssisted: insightsAssisted ?? this.insightsAssisted,
      insightsMissed: insightsMissed ?? this.insightsMissed,
      wrongTurnsTaken: wrongTurnsTaken ?? this.wrongTurnsTaken,
      complexityJson: complexityJson ?? this.complexityJson,
      verdict: verdict ?? this.verdict,
      confidence: confidence ?? this.confidence,
      feedback: feedback ?? this.feedback,
      editorial: editorial ?? this.editorial,
      revealAtIndex: revealAtIndex ?? this.revealAtIndex,
      rawJson: rawJson ?? this.rawJson,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (matchedApproach.present) {
      map['matched_approach'] = Variable<String>(matchedApproach.value);
    }
    if (matchedVerdict.present) {
      map['matched_verdict'] = Variable<String>(
        $AssessmentsTable.$convertermatchedVerdict.toSql(matchedVerdict.value),
      );
    }
    if (insightsHit.present) {
      map['insights_hit'] = Variable<String>(
        $AssessmentsTable.$converterinsightsHit.toSql(insightsHit.value),
      );
    }
    if (insightsAssisted.present) {
      map['insights_assisted'] = Variable<String>(
        $AssessmentsTable.$converterinsightsAssistedn.toSql(
          insightsAssisted.value,
        ),
      );
    }
    if (insightsMissed.present) {
      map['insights_missed'] = Variable<String>(
        $AssessmentsTable.$converterinsightsMissed.toSql(insightsMissed.value),
      );
    }
    if (wrongTurnsTaken.present) {
      map['wrong_turns_taken'] = Variable<String>(
        $AssessmentsTable.$converterwrongTurnsTaken.toSql(
          wrongTurnsTaken.value,
        ),
      );
    }
    if (complexityJson.present) {
      map['complexity_json'] = Variable<String>(complexityJson.value);
    }
    if (verdict.present) {
      map['verdict'] = Variable<String>(
        $AssessmentsTable.$converterverdict.toSql(verdict.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (feedback.present) {
      map['feedback'] = Variable<String>(feedback.value);
    }
    if (editorial.present) {
      map['editorial'] = Variable<String>(editorial.value);
    }
    if (revealAtIndex.present) {
      map['reveal_at_index'] = Variable<int>(revealAtIndex.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssessmentsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('matchedApproach: $matchedApproach, ')
          ..write('matchedVerdict: $matchedVerdict, ')
          ..write('insightsHit: $insightsHit, ')
          ..write('insightsAssisted: $insightsAssisted, ')
          ..write('insightsMissed: $insightsMissed, ')
          ..write('wrongTurnsTaken: $wrongTurnsTaken, ')
          ..write('complexityJson: $complexityJson, ')
          ..write('verdict: $verdict, ')
          ..write('confidence: $confidence, ')
          ..write('feedback: $feedback, ')
          ..write('editorial: $editorial, ')
          ..write('revealAtIndex: $revealAtIndex, ')
          ..write('rawJson: $rawJson, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OutboxKind>($OutboxTable.$converterkind);
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _solutionRequestCountAtEnqueueMeta =
      const VerificationMeta('solutionRequestCountAtEnqueue');
  @override
  late final GeneratedColumn<int> solutionRequestCountAtEnqueue =
      GeneratedColumn<int>(
        'solution_request_count_at_enqueue',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextEligibleAtMeta = const VerificationMeta(
    'nextEligibleAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextEligibleAt =
      GeneratedColumn<DateTime>(
        'next_eligible_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    kind,
    payload,
    solutionRequestCountAtEnqueue,
    attempts,
    nextEligibleAt,
    lastErrorCode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('solution_request_count_at_enqueue')) {
      context.handle(
        _solutionRequestCountAtEnqueueMeta,
        solutionRequestCountAtEnqueue.isAcceptableOrUnknown(
          data['solution_request_count_at_enqueue']!,
          _solutionRequestCountAtEnqueueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_solutionRequestCountAtEnqueueMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_eligible_at')) {
      context.handle(
        _nextEligibleAtMeta,
        nextEligibleAt.isAcceptableOrUnknown(
          data['next_eligible_at']!,
          _nextEligibleAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextEligibleAtMeta);
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      kind: $OutboxTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      solutionRequestCountAtEnqueue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}solution_request_count_at_enqueue'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextEligibleAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_eligible_at'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxKind, String, String> $converterkind =
      const EnumNameConverter<OutboxKind>(OutboxKind.values);
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String id;
  final String sessionId;
  final OutboxKind kind;
  final String payload;
  final int solutionRequestCountAtEnqueue;
  final int attempts;
  final DateTime nextEligibleAt;
  final String? lastErrorCode;
  final DateTime createdAt;
  const OutboxData({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.payload,
    required this.solutionRequestCountAtEnqueue,
    required this.attempts,
    required this.nextEligibleAt,
    this.lastErrorCode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    {
      map['kind'] = Variable<String>($OutboxTable.$converterkind.toSql(kind));
    }
    map['payload'] = Variable<String>(payload);
    map['solution_request_count_at_enqueue'] = Variable<int>(
      solutionRequestCountAtEnqueue,
    );
    map['attempts'] = Variable<int>(attempts);
    map['next_eligible_at'] = Variable<DateTime>(nextEligibleAt);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      kind: Value(kind),
      payload: Value(payload),
      solutionRequestCountAtEnqueue: Value(solutionRequestCountAtEnqueue),
      attempts: Value(attempts),
      nextEligibleAt: Value(nextEligibleAt),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      kind: $OutboxTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      payload: serializer.fromJson<String>(json['payload']),
      solutionRequestCountAtEnqueue: serializer.fromJson<int>(
        json['solutionRequestCountAtEnqueue'],
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextEligibleAt: serializer.fromJson<DateTime>(json['nextEligibleAt']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'kind': serializer.toJson<String>(
        $OutboxTable.$converterkind.toJson(kind),
      ),
      'payload': serializer.toJson<String>(payload),
      'solutionRequestCountAtEnqueue': serializer.toJson<int>(
        solutionRequestCountAtEnqueue,
      ),
      'attempts': serializer.toJson<int>(attempts),
      'nextEligibleAt': serializer.toJson<DateTime>(nextEligibleAt),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith({
    String? id,
    String? sessionId,
    OutboxKind? kind,
    String? payload,
    int? solutionRequestCountAtEnqueue,
    int? attempts,
    DateTime? nextEligibleAt,
    Value<String?> lastErrorCode = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxData(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    solutionRequestCountAtEnqueue:
        solutionRequestCountAtEnqueue ?? this.solutionRequestCountAtEnqueue,
    attempts: attempts ?? this.attempts,
    nextEligibleAt: nextEligibleAt ?? this.nextEligibleAt,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      solutionRequestCountAtEnqueue: data.solutionRequestCountAtEnqueue.present
          ? data.solutionRequestCountAtEnqueue.value
          : this.solutionRequestCountAtEnqueue,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextEligibleAt: data.nextEligibleAt.present
          ? data.nextEligibleAt.value
          : this.nextEligibleAt,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write(
            'solutionRequestCountAtEnqueue: $solutionRequestCountAtEnqueue, ',
          )
          ..write('attempts: $attempts, ')
          ..write('nextEligibleAt: $nextEligibleAt, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    kind,
    payload,
    solutionRequestCountAtEnqueue,
    attempts,
    nextEligibleAt,
    lastErrorCode,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.solutionRequestCountAtEnqueue ==
              this.solutionRequestCountAtEnqueue &&
          other.attempts == this.attempts &&
          other.nextEligibleAt == this.nextEligibleAt &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<OutboxKind> kind;
  final Value<String> payload;
  final Value<int> solutionRequestCountAtEnqueue;
  final Value<int> attempts;
  final Value<DateTime> nextEligibleAt;
  final Value<String?> lastErrorCode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.solutionRequestCountAtEnqueue = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextEligibleAt = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String id,
    required String sessionId,
    required OutboxKind kind,
    required String payload,
    required int solutionRequestCountAtEnqueue,
    this.attempts = const Value.absent(),
    required DateTime nextEligibleAt,
    this.lastErrorCode = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       kind = Value(kind),
       payload = Value(payload),
       solutionRequestCountAtEnqueue = Value(solutionRequestCountAtEnqueue),
       nextEligibleAt = Value(nextEligibleAt),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? kind,
    Expression<String>? payload,
    Expression<int>? solutionRequestCountAtEnqueue,
    Expression<int>? attempts,
    Expression<DateTime>? nextEligibleAt,
    Expression<String>? lastErrorCode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (solutionRequestCountAtEnqueue != null)
        'solution_request_count_at_enqueue': solutionRequestCountAtEnqueue,
      if (attempts != null) 'attempts': attempts,
      if (nextEligibleAt != null) 'next_eligible_at': nextEligibleAt,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<OutboxKind>? kind,
    Value<String>? payload,
    Value<int>? solutionRequestCountAtEnqueue,
    Value<int>? attempts,
    Value<DateTime>? nextEligibleAt,
    Value<String?>? lastErrorCode,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      solutionRequestCountAtEnqueue:
          solutionRequestCountAtEnqueue ?? this.solutionRequestCountAtEnqueue,
      attempts: attempts ?? this.attempts,
      nextEligibleAt: nextEligibleAt ?? this.nextEligibleAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $OutboxTable.$converterkind.toSql(kind.value),
      );
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (solutionRequestCountAtEnqueue.present) {
      map['solution_request_count_at_enqueue'] = Variable<int>(
        solutionRequestCountAtEnqueue.value,
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextEligibleAt.present) {
      map['next_eligible_at'] = Variable<DateTime>(nextEligibleAt.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write(
            'solutionRequestCountAtEnqueue: $solutionRequestCountAtEnqueue, ',
          )
          ..write('attempts: $attempts, ')
          ..write('nextEligibleAt: $nextEligibleAt, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreakDaysTable extends StreakDays
    with TableInfo<$StreakDaysTable, StreakDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditedAtMeta = const VerificationMeta(
    'creditedAt',
  );
  @override
  late final GeneratedColumn<DateTime> creditedAt = GeneratedColumn<DateTime>(
    'credited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, creditedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<StreakDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('credited_at')) {
      context.handle(
        _creditedAtMeta,
        creditedAt.isAcceptableOrUnknown(data['credited_at']!, _creditedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_creditedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  StreakDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakDay(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      creditedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}credited_at'],
      )!,
    );
  }

  @override
  $StreakDaysTable createAlias(String alias) {
    return $StreakDaysTable(attachedDatabase, alias);
  }
}

class StreakDay extends DataClass implements Insertable<StreakDay> {
  final String day;
  final DateTime creditedAt;
  const StreakDay({required this.day, required this.creditedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['credited_at'] = Variable<DateTime>(creditedAt);
    return map;
  }

  StreakDaysCompanion toCompanion(bool nullToAbsent) {
    return StreakDaysCompanion(day: Value(day), creditedAt: Value(creditedAt));
  }

  factory StreakDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakDay(
      day: serializer.fromJson<String>(json['day']),
      creditedAt: serializer.fromJson<DateTime>(json['creditedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'creditedAt': serializer.toJson<DateTime>(creditedAt),
    };
  }

  StreakDay copyWith({String? day, DateTime? creditedAt}) => StreakDay(
    day: day ?? this.day,
    creditedAt: creditedAt ?? this.creditedAt,
  );
  StreakDay copyWithCompanion(StreakDaysCompanion data) {
    return StreakDay(
      day: data.day.present ? data.day.value : this.day,
      creditedAt: data.creditedAt.present
          ? data.creditedAt.value
          : this.creditedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakDay(')
          ..write('day: $day, ')
          ..write('creditedAt: $creditedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, creditedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakDay &&
          other.day == this.day &&
          other.creditedAt == this.creditedAt);
}

class StreakDaysCompanion extends UpdateCompanion<StreakDay> {
  final Value<String> day;
  final Value<DateTime> creditedAt;
  final Value<int> rowid;
  const StreakDaysCompanion({
    this.day = const Value.absent(),
    this.creditedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StreakDaysCompanion.insert({
    required String day,
    required DateTime creditedAt,
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       creditedAt = Value(creditedAt);
  static Insertable<StreakDay> custom({
    Expression<String>? day,
    Expression<DateTime>? creditedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (creditedAt != null) 'credited_at': creditedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StreakDaysCompanion copyWith({
    Value<String>? day,
    Value<DateTime>? creditedAt,
    Value<int>? rowid,
  }) {
    return StreakDaysCompanion(
      day: day ?? this.day,
      creditedAt: creditedAt ?? this.creditedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (creditedAt.present) {
      map['credited_at'] = Variable<DateTime>(creditedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakDaysCompanion(')
          ..write('day: $day, ')
          ..write('creditedAt: $creditedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedConfigTable extends CachedConfig
    with TableInfo<$CachedConfigTable, CachedConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, json, etag, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_config';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedConfigData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedConfigData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedConfigTable createAlias(String alias) {
    return $CachedConfigTable(attachedDatabase, alias);
  }
}

class CachedConfigData extends DataClass
    implements Insertable<CachedConfigData> {
  final int id;
  final String json;
  final String? etag;
  final DateTime fetchedAt;
  const CachedConfigData({
    required this.id,
    required this.json,
    this.etag,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedConfigCompanion toCompanion(bool nullToAbsent) {
    return CachedConfigCompanion(
      id: Value(id),
      json: Value(json),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedConfigData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedConfigData(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      etag: serializer.fromJson<String?>(json['etag']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'etag': serializer.toJson<String?>(etag),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedConfigData copyWith({
    int? id,
    String? json,
    Value<String?> etag = const Value.absent(),
    DateTime? fetchedAt,
  }) => CachedConfigData(
    id: id ?? this.id,
    json: json ?? this.json,
    etag: etag.present ? etag.value : this.etag,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedConfigData copyWithCompanion(CachedConfigCompanion data) {
    return CachedConfigData(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      etag: data.etag.present ? data.etag.value : this.etag,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedConfigData(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, etag, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedConfigData &&
          other.id == this.id &&
          other.json == this.json &&
          other.etag == this.etag &&
          other.fetchedAt == this.fetchedAt);
}

class CachedConfigCompanion extends UpdateCompanion<CachedConfigData> {
  final Value<int> id;
  final Value<String> json;
  final Value<String?> etag;
  final Value<DateTime> fetchedAt;
  const CachedConfigCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.etag = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  CachedConfigCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    this.etag = const Value.absent(),
    required DateTime fetchedAt,
  }) : json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedConfigData> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<String>? etag,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (etag != null) 'etag': etag,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  CachedConfigCompanion copyWith({
    Value<int>? id,
    Value<String>? json,
    Value<String?>? etag,
    Value<DateTime>? fetchedAt,
  }) {
    return CachedConfigCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      etag: etag ?? this.etag,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedConfigCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $InstallIdentityTable installIdentity = $InstallIdentityTable(
    this,
  );
  late final $CachedProblemsTable cachedProblems = $CachedProblemsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $DraftsTable drafts = $DraftsTable(this);
  late final $AssessmentsTable assessments = $AssessmentsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $StreakDaysTable streakDays = $StreakDaysTable(this);
  late final $CachedConfigTable cachedConfig = $CachedConfigTable(this);
  late final Index sessionsProblemDay = Index(
    'sessions_problem_day',
    'CREATE UNIQUE INDEX sessions_problem_day ON sessions (problem_id, day)',
  );
  late final Index messagesSessionSeq = Index(
    'messages_session_seq',
    'CREATE UNIQUE INDEX messages_session_seq ON messages (session_id, seq)',
  );
  late final InstallDao installDao = InstallDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final ProblemDao problemDao = ProblemDao(this as AppDatabase);
  late final StreakDao streakDao = StreakDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  late final ConfigDao configDao = ConfigDao(this as AppDatabase);
  late final AssessmentDao assessmentDao = AssessmentDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    installIdentity,
    cachedProblems,
    sessions,
    messages,
    drafts,
    assessments,
    outbox,
    streakDays,
    cachedConfig,
    sessionsProblemDay,
    messagesSessionSeq,
  ];
}

typedef $$InstallIdentityTableCreateCompanionBuilder =
    InstallIdentityCompanion Function({
      Value<int> id,
      required String installUuid,
      required String installId,
      required DateTime mintedAt,
    });
typedef $$InstallIdentityTableUpdateCompanionBuilder =
    InstallIdentityCompanion Function({
      Value<int> id,
      Value<String> installUuid,
      Value<String> installId,
      Value<DateTime> mintedAt,
    });

class $$InstallIdentityTableFilterComposer
    extends Composer<_$AppDatabase, $InstallIdentityTable> {
  $$InstallIdentityTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installUuid => $composableBuilder(
    column: $table.installUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get mintedAt => $composableBuilder(
    column: $table.mintedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstallIdentityTableOrderingComposer
    extends Composer<_$AppDatabase, $InstallIdentityTable> {
  $$InstallIdentityTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installUuid => $composableBuilder(
    column: $table.installUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installId => $composableBuilder(
    column: $table.installId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get mintedAt => $composableBuilder(
    column: $table.mintedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstallIdentityTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstallIdentityTable> {
  $$InstallIdentityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get installUuid => $composableBuilder(
    column: $table.installUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get installId =>
      $composableBuilder(column: $table.installId, builder: (column) => column);

  GeneratedColumn<DateTime> get mintedAt =>
      $composableBuilder(column: $table.mintedAt, builder: (column) => column);
}

class $$InstallIdentityTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstallIdentityTable,
          InstallIdentityRow,
          $$InstallIdentityTableFilterComposer,
          $$InstallIdentityTableOrderingComposer,
          $$InstallIdentityTableAnnotationComposer,
          $$InstallIdentityTableCreateCompanionBuilder,
          $$InstallIdentityTableUpdateCompanionBuilder,
          (
            InstallIdentityRow,
            BaseReferences<
              _$AppDatabase,
              $InstallIdentityTable,
              InstallIdentityRow
            >,
          ),
          InstallIdentityRow,
          PrefetchHooks Function()
        > {
  $$InstallIdentityTableTableManager(
    _$AppDatabase db,
    $InstallIdentityTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstallIdentityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstallIdentityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstallIdentityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> installUuid = const Value.absent(),
                Value<String> installId = const Value.absent(),
                Value<DateTime> mintedAt = const Value.absent(),
              }) => InstallIdentityCompanion(
                id: id,
                installUuid: installUuid,
                installId: installId,
                mintedAt: mintedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String installUuid,
                required String installId,
                required DateTime mintedAt,
              }) => InstallIdentityCompanion.insert(
                id: id,
                installUuid: installUuid,
                installId: installId,
                mintedAt: mintedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstallIdentityTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstallIdentityTable,
      InstallIdentityRow,
      $$InstallIdentityTableFilterComposer,
      $$InstallIdentityTableOrderingComposer,
      $$InstallIdentityTableAnnotationComposer,
      $$InstallIdentityTableCreateCompanionBuilder,
      $$InstallIdentityTableUpdateCompanionBuilder,
      (
        InstallIdentityRow,
        BaseReferences<
          _$AppDatabase,
          $InstallIdentityTable,
          InstallIdentityRow
        >,
      ),
      InstallIdentityRow,
      PrefetchHooks Function()
    >;
typedef $$CachedProblemsTableCreateCompanionBuilder =
    CachedProblemsCompanion Function({
      required String problemId,
      required int schemaVersion,
      required String title,
      required String ramp,
      Value<int?> difficulty,
      required List<String> tags,
      required String source,
      required String statement,
      required List<String> constraints,
      Value<String?> examplesJson,
      required int estSpeakSeconds,
      required List<String> collections,
      required List<String> glossaryTerms,
      required int hintCount,
      Value<String?> manifestDate,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedProblemsTableUpdateCompanionBuilder =
    CachedProblemsCompanion Function({
      Value<String> problemId,
      Value<int> schemaVersion,
      Value<String> title,
      Value<String> ramp,
      Value<int?> difficulty,
      Value<List<String>> tags,
      Value<String> source,
      Value<String> statement,
      Value<List<String>> constraints,
      Value<String?> examplesJson,
      Value<int> estSpeakSeconds,
      Value<List<String>> collections,
      Value<List<String>> glossaryTerms,
      Value<int> hintCount,
      Value<String?> manifestDate,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

final class $$CachedProblemsTableReferences
    extends BaseReferences<_$AppDatabase, $CachedProblemsTable, CachedProblem> {
  $$CachedProblemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SessionsTable, List<SessionRow>>
  _sessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessions,
    aliasName: $_aliasNameGenerator(
      db.cachedProblems.problemId,
      db.sessions.problemId,
    ),
  );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager($_db, $_db.sessions).filter(
      (f) =>
          f.problemId.problemId.sqlEquals($_itemColumn<String>('problem_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CachedProblemsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedProblemsTable> {
  $$CachedProblemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get problemId => $composableBuilder(
    column: $table.problemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ramp => $composableBuilder(
    column: $table.ramp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statement => $composableBuilder(
    column: $table.statement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get constraints => $composableBuilder(
    column: $table.constraints,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get examplesJson => $composableBuilder(
    column: $table.examplesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estSpeakSeconds => $composableBuilder(
    column: $table.estSpeakSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get collections => $composableBuilder(
    column: $table.collections,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get glossaryTerms => $composableBuilder(
    column: $table.glossaryTerms,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get hintCount => $composableBuilder(
    column: $table.hintCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestDate => $composableBuilder(
    column: $table.manifestDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sessionsRefs(
    Expression<bool> Function($$SessionsTableFilterComposer f) f,
  ) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.problemId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.problemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CachedProblemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedProblemsTable> {
  $$CachedProblemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get problemId => $composableBuilder(
    column: $table.problemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ramp => $composableBuilder(
    column: $table.ramp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statement => $composableBuilder(
    column: $table.statement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get constraints => $composableBuilder(
    column: $table.constraints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examplesJson => $composableBuilder(
    column: $table.examplesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estSpeakSeconds => $composableBuilder(
    column: $table.estSpeakSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collections => $composableBuilder(
    column: $table.collections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get glossaryTerms => $composableBuilder(
    column: $table.glossaryTerms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintCount => $composableBuilder(
    column: $table.hintCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestDate => $composableBuilder(
    column: $table.manifestDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedProblemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedProblemsTable> {
  $$CachedProblemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get problemId =>
      $composableBuilder(column: $table.problemId, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get ramp =>
      $composableBuilder(column: $table.ramp, builder: (column) => column);

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get statement =>
      $composableBuilder(column: $table.statement, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get constraints =>
      $composableBuilder(
        column: $table.constraints,
        builder: (column) => column,
      );

  GeneratedColumn<String> get examplesJson => $composableBuilder(
    column: $table.examplesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estSpeakSeconds => $composableBuilder(
    column: $table.estSpeakSeconds,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get collections =>
      $composableBuilder(
        column: $table.collections,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get glossaryTerms =>
      $composableBuilder(
        column: $table.glossaryTerms,
        builder: (column) => column,
      );

  GeneratedColumn<int> get hintCount =>
      $composableBuilder(column: $table.hintCount, builder: (column) => column);

  GeneratedColumn<String> get manifestDate => $composableBuilder(
    column: $table.manifestDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.problemId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.problemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CachedProblemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedProblemsTable,
          CachedProblem,
          $$CachedProblemsTableFilterComposer,
          $$CachedProblemsTableOrderingComposer,
          $$CachedProblemsTableAnnotationComposer,
          $$CachedProblemsTableCreateCompanionBuilder,
          $$CachedProblemsTableUpdateCompanionBuilder,
          (CachedProblem, $$CachedProblemsTableReferences),
          CachedProblem,
          PrefetchHooks Function({bool sessionsRefs})
        > {
  $$CachedProblemsTableTableManager(
    _$AppDatabase db,
    $CachedProblemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedProblemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedProblemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedProblemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> problemId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> ramp = const Value.absent(),
                Value<int?> difficulty = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> statement = const Value.absent(),
                Value<List<String>> constraints = const Value.absent(),
                Value<String?> examplesJson = const Value.absent(),
                Value<int> estSpeakSeconds = const Value.absent(),
                Value<List<String>> collections = const Value.absent(),
                Value<List<String>> glossaryTerms = const Value.absent(),
                Value<int> hintCount = const Value.absent(),
                Value<String?> manifestDate = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedProblemsCompanion(
                problemId: problemId,
                schemaVersion: schemaVersion,
                title: title,
                ramp: ramp,
                difficulty: difficulty,
                tags: tags,
                source: source,
                statement: statement,
                constraints: constraints,
                examplesJson: examplesJson,
                estSpeakSeconds: estSpeakSeconds,
                collections: collections,
                glossaryTerms: glossaryTerms,
                hintCount: hintCount,
                manifestDate: manifestDate,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String problemId,
                required int schemaVersion,
                required String title,
                required String ramp,
                Value<int?> difficulty = const Value.absent(),
                required List<String> tags,
                required String source,
                required String statement,
                required List<String> constraints,
                Value<String?> examplesJson = const Value.absent(),
                required int estSpeakSeconds,
                required List<String> collections,
                required List<String> glossaryTerms,
                required int hintCount,
                Value<String?> manifestDate = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedProblemsCompanion.insert(
                problemId: problemId,
                schemaVersion: schemaVersion,
                title: title,
                ramp: ramp,
                difficulty: difficulty,
                tags: tags,
                source: source,
                statement: statement,
                constraints: constraints,
                examplesJson: examplesJson,
                estSpeakSeconds: estSpeakSeconds,
                collections: collections,
                glossaryTerms: glossaryTerms,
                hintCount: hintCount,
                manifestDate: manifestDate,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CachedProblemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<
                      CachedProblem,
                      $CachedProblemsTable,
                      SessionRow
                    >(
                      currentTable: table,
                      referencedTable: $$CachedProblemsTableReferences
                          ._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CachedProblemsTableReferences(
                            db,
                            table,
                            p0,
                          ).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.problemId == item.problemId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CachedProblemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedProblemsTable,
      CachedProblem,
      $$CachedProblemsTableFilterComposer,
      $$CachedProblemsTableOrderingComposer,
      $$CachedProblemsTableAnnotationComposer,
      $$CachedProblemsTableCreateCompanionBuilder,
      $$CachedProblemsTableUpdateCompanionBuilder,
      (CachedProblem, $$CachedProblemsTableReferences),
      CachedProblem,
      PrefetchHooks Function({bool sessionsRefs})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      required String problemId,
      required String day,
      required SessionPath path,
      required SessionStatus status,
      Value<String?> providerId,
      Value<String?> summary,
      Value<int> solutionRequestCount,
      Value<bool> isRepeat,
      Value<bool> isPractice,
      Value<bool> disputed,
      Value<DateTime?> disputedAt,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      Value<int> turnIndex,
      Value<int?> turnsRemaining,
      Value<int> hintsRevealed,
      Value<int?> hintsRemaining,
      Value<String?> sessionEnded,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String> problemId,
      Value<String> day,
      Value<SessionPath> path,
      Value<SessionStatus> status,
      Value<String?> providerId,
      Value<String?> summary,
      Value<int> solutionRequestCount,
      Value<bool> isRepeat,
      Value<bool> isPractice,
      Value<bool> disputed,
      Value<DateTime?> disputedAt,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int> turnIndex,
      Value<int?> turnsRemaining,
      Value<int> hintsRevealed,
      Value<int?> hintsRemaining,
      Value<String?> sessionEnded,
      Value<int> rowid,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, SessionRow> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CachedProblemsTable _problemIdTable(_$AppDatabase db) =>
      db.cachedProblems.createAlias(
        $_aliasNameGenerator(
          db.sessions.problemId,
          db.cachedProblems.problemId,
        ),
      );

  $$CachedProblemsTableProcessedTableManager get problemId {
    final $_column = $_itemColumn<String>('problem_id')!;

    final manager = $$CachedProblemsTableTableManager(
      $_db,
      $_db.cachedProblems,
    ).filter((f) => f.problemId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_problemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MessagesTable, List<MessageRow>>
  _messagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.messages,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.messages.sessionId),
  );

  $$MessagesTableProcessedTableManager get messagesRefs {
    final manager = $$MessagesTableTableManager(
      $_db,
      $_db.messages,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DraftsTable, List<DraftRow>> _draftsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.drafts,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.drafts.sessionId),
  );

  $$DraftsTableProcessedTableManager get draftsRefs {
    final manager = $$DraftsTableTableManager(
      $_db,
      $_db.drafts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_draftsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AssessmentsTable, List<AssessmentRow>>
  _assessmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.assessments,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.assessments.sessionId),
  );

  $$AssessmentsTableProcessedTableManager get assessmentsRefs {
    final manager = $$AssessmentsTableTableManager(
      $_db,
      $_db.assessments,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_assessmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OutboxTable, List<OutboxData>> _outboxRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.outbox,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.outbox.sessionId),
  );

  $$OutboxTableProcessedTableManager get outboxRefs {
    final manager = $$OutboxTableTableManager(
      $_db,
      $_db.outbox,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_outboxRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SessionPath, SessionPath, String> get path =>
      $composableBuilder(
        column: $table.path,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<SessionStatus, SessionStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get solutionRequestCount => $composableBuilder(
    column: $table.solutionRequestCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRepeat => $composableBuilder(
    column: $table.isRepeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPractice => $composableBuilder(
    column: $table.isPractice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get disputed => $composableBuilder(
    column: $table.disputed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get disputedAt => $composableBuilder(
    column: $table.disputedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnIndex => $composableBuilder(
    column: $table.turnIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get turnsRemaining => $composableBuilder(
    column: $table.turnsRemaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hintsRevealed => $composableBuilder(
    column: $table.hintsRevealed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hintsRemaining => $composableBuilder(
    column: $table.hintsRemaining,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionEnded => $composableBuilder(
    column: $table.sessionEnded,
    builder: (column) => ColumnFilters(column),
  );

  $$CachedProblemsTableFilterComposer get problemId {
    final $$CachedProblemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.problemId,
      referencedTable: $db.cachedProblems,
      getReferencedColumn: (t) => t.problemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedProblemsTableFilterComposer(
            $db: $db,
            $table: $db.cachedProblems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> messagesRefs(
    Expression<bool> Function($$MessagesTableFilterComposer f) f,
  ) {
    final $$MessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableFilterComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> draftsRefs(
    Expression<bool> Function($$DraftsTableFilterComposer f) f,
  ) {
    final $$DraftsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableFilterComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assessmentsRefs(
    Expression<bool> Function($$AssessmentsTableFilterComposer f) f,
  ) {
    final $$AssessmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assessments,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssessmentsTableFilterComposer(
            $db: $db,
            $table: $db.assessments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> outboxRefs(
    Expression<bool> Function($$OutboxTableFilterComposer f) f,
  ) {
    final $$OutboxTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outbox,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutboxTableFilterComposer(
            $db: $db,
            $table: $db.outbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get solutionRequestCount => $composableBuilder(
    column: $table.solutionRequestCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRepeat => $composableBuilder(
    column: $table.isRepeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPractice => $composableBuilder(
    column: $table.isPractice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get disputed => $composableBuilder(
    column: $table.disputed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get disputedAt => $composableBuilder(
    column: $table.disputedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnIndex => $composableBuilder(
    column: $table.turnIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get turnsRemaining => $composableBuilder(
    column: $table.turnsRemaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintsRevealed => $composableBuilder(
    column: $table.hintsRevealed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintsRemaining => $composableBuilder(
    column: $table.hintsRemaining,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionEnded => $composableBuilder(
    column: $table.sessionEnded,
    builder: (column) => ColumnOrderings(column),
  );

  $$CachedProblemsTableOrderingComposer get problemId {
    final $$CachedProblemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.problemId,
      referencedTable: $db.cachedProblems,
      getReferencedColumn: (t) => t.problemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedProblemsTableOrderingComposer(
            $db: $db,
            $table: $db.cachedProblems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SessionPath, String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SessionStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get solutionRequestCount => $composableBuilder(
    column: $table.solutionRequestCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isRepeat =>
      $composableBuilder(column: $table.isRepeat, builder: (column) => column);

  GeneratedColumn<bool> get isPractice => $composableBuilder(
    column: $table.isPractice,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get disputed =>
      $composableBuilder(column: $table.disputed, builder: (column) => column);

  GeneratedColumn<DateTime> get disputedAt => $composableBuilder(
    column: $table.disputedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get turnIndex =>
      $composableBuilder(column: $table.turnIndex, builder: (column) => column);

  GeneratedColumn<int> get turnsRemaining => $composableBuilder(
    column: $table.turnsRemaining,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hintsRevealed => $composableBuilder(
    column: $table.hintsRevealed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hintsRemaining => $composableBuilder(
    column: $table.hintsRemaining,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionEnded => $composableBuilder(
    column: $table.sessionEnded,
    builder: (column) => column,
  );

  $$CachedProblemsTableAnnotationComposer get problemId {
    final $$CachedProblemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.problemId,
      referencedTable: $db.cachedProblems,
      getReferencedColumn: (t) => t.problemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CachedProblemsTableAnnotationComposer(
            $db: $db,
            $table: $db.cachedProblems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> messagesRefs<T extends Object>(
    Expression<T> Function($$MessagesTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.messages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> draftsRefs<T extends Object>(
    Expression<T> Function($$DraftsTableAnnotationComposer a) f,
  ) {
    final $$DraftsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.drafts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DraftsTableAnnotationComposer(
            $db: $db,
            $table: $db.drafts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assessmentsRefs<T extends Object>(
    Expression<T> Function($$AssessmentsTableAnnotationComposer a) f,
  ) {
    final $$AssessmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assessments,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssessmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.assessments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> outboxRefs<T extends Object>(
    Expression<T> Function($$OutboxTableAnnotationComposer a) f,
  ) {
    final $$OutboxTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outbox,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OutboxTableAnnotationComposer(
            $db: $db,
            $table: $db.outbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (SessionRow, $$SessionsTableReferences),
          SessionRow,
          PrefetchHooks Function({
            bool problemId,
            bool messagesRefs,
            bool draftsRefs,
            bool assessmentsRefs,
            bool outboxRefs,
          })
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> problemId = const Value.absent(),
                Value<String> day = const Value.absent(),
                Value<SessionPath> path = const Value.absent(),
                Value<SessionStatus> status = const Value.absent(),
                Value<String?> providerId = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int> solutionRequestCount = const Value.absent(),
                Value<bool> isRepeat = const Value.absent(),
                Value<bool> isPractice = const Value.absent(),
                Value<bool> disputed = const Value.absent(),
                Value<DateTime?> disputedAt = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> turnIndex = const Value.absent(),
                Value<int?> turnsRemaining = const Value.absent(),
                Value<int> hintsRevealed = const Value.absent(),
                Value<int?> hintsRemaining = const Value.absent(),
                Value<String?> sessionEnded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                problemId: problemId,
                day: day,
                path: path,
                status: status,
                providerId: providerId,
                summary: summary,
                solutionRequestCount: solutionRequestCount,
                isRepeat: isRepeat,
                isPractice: isPractice,
                disputed: disputed,
                disputedAt: disputedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                turnIndex: turnIndex,
                turnsRemaining: turnsRemaining,
                hintsRevealed: hintsRevealed,
                hintsRemaining: hintsRemaining,
                sessionEnded: sessionEnded,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String problemId,
                required String day,
                required SessionPath path,
                required SessionStatus status,
                Value<String?> providerId = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int> solutionRequestCount = const Value.absent(),
                Value<bool> isRepeat = const Value.absent(),
                Value<bool> isPractice = const Value.absent(),
                Value<bool> disputed = const Value.absent(),
                Value<DateTime?> disputedAt = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> turnIndex = const Value.absent(),
                Value<int?> turnsRemaining = const Value.absent(),
                Value<int> hintsRevealed = const Value.absent(),
                Value<int?> hintsRemaining = const Value.absent(),
                Value<String?> sessionEnded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                problemId: problemId,
                day: day,
                path: path,
                status: status,
                providerId: providerId,
                summary: summary,
                solutionRequestCount: solutionRequestCount,
                isRepeat: isRepeat,
                isPractice: isPractice,
                disputed: disputed,
                disputedAt: disputedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                turnIndex: turnIndex,
                turnsRemaining: turnsRemaining,
                hintsRevealed: hintsRevealed,
                hintsRemaining: hintsRemaining,
                sessionEnded: sessionEnded,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                problemId = false,
                messagesRefs = false,
                draftsRefs = false,
                assessmentsRefs = false,
                outboxRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (messagesRefs) db.messages,
                    if (draftsRefs) db.drafts,
                    if (assessmentsRefs) db.assessments,
                    if (outboxRefs) db.outbox,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (problemId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.problemId,
                                    referencedTable: $$SessionsTableReferences
                                        ._problemIdTable(db),
                                    referencedColumn: $$SessionsTableReferences
                                        ._problemIdTable(db)
                                        .problemId,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (messagesRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $SessionsTable,
                          MessageRow
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._messagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).messagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (draftsRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $SessionsTable,
                          DraftRow
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._draftsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).draftsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (assessmentsRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $SessionsTable,
                          AssessmentRow
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._assessmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).assessmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (outboxRefs)
                        await $_getPrefetchedData<
                          SessionRow,
                          $SessionsTable,
                          OutboxData
                        >(
                          currentTable: table,
                          referencedTable: $$SessionsTableReferences
                              ._outboxRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).outboxRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, $$SessionsTableReferences),
      SessionRow,
      PrefetchHooks Function({
        bool problemId,
        bool messagesRefs,
        bool draftsRefs,
        bool assessmentsRefs,
        bool outboxRefs,
      })
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String sessionId,
      required int seq,
      required TurnRole role,
      required String body,
      required MessageKind kind,
      required Delivery delivery,
      Value<String?> recognisedDraft,
      Value<InputMode?> inputMode,
      Value<bool> coveredBySummary,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> seq,
      Value<TurnRole> role,
      Value<String> body,
      Value<MessageKind> kind,
      Value<Delivery> delivery,
      Value<String?> recognisedDraft,
      Value<InputMode?> inputMode,
      Value<bool> coveredBySummary,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$MessagesTableReferences
    extends BaseReferences<_$AppDatabase, $MessagesTable, MessageRow> {
  $$MessagesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions
      .createAlias($_aliasNameGenerator(db.messages.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TurnRole, TurnRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MessageKind, MessageKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Delivery, Delivery, String> get delivery =>
      $composableBuilder(
        column: $table.delivery,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get recognisedDraft => $composableBuilder(
    column: $table.recognisedDraft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InputMode?, InputMode, String> get inputMode =>
      $composableBuilder(
        column: $table.inputMode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get coveredBySummary => $composableBuilder(
    column: $table.coveredBySummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get delivery => $composableBuilder(
    column: $table.delivery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recognisedDraft => $composableBuilder(
    column: $table.recognisedDraft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputMode => $composableBuilder(
    column: $table.inputMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get coveredBySummary => $composableBuilder(
    column: $table.coveredBySummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TurnRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MessageKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Delivery, String> get delivery =>
      $composableBuilder(column: $table.delivery, builder: (column) => column);

  GeneratedColumn<String> get recognisedDraft => $composableBuilder(
    column: $table.recognisedDraft,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<InputMode?, String> get inputMode =>
      $composableBuilder(column: $table.inputMode, builder: (column) => column);

  GeneratedColumn<bool> get coveredBySummary => $composableBuilder(
    column: $table.coveredBySummary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (MessageRow, $$MessagesTableReferences),
          MessageRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<TurnRole> role = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<MessageKind> kind = const Value.absent(),
                Value<Delivery> delivery = const Value.absent(),
                Value<String?> recognisedDraft = const Value.absent(),
                Value<InputMode?> inputMode = const Value.absent(),
                Value<bool> coveredBySummary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                sessionId: sessionId,
                seq: seq,
                role: role,
                body: body,
                kind: kind,
                delivery: delivery,
                recognisedDraft: recognisedDraft,
                inputMode: inputMode,
                coveredBySummary: coveredBySummary,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int seq,
                required TurnRole role,
                required String body,
                required MessageKind kind,
                required Delivery delivery,
                Value<String?> recognisedDraft = const Value.absent(),
                Value<InputMode?> inputMode = const Value.absent(),
                Value<bool> coveredBySummary = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                seq: seq,
                role: role,
                body: body,
                kind: kind,
                delivery: delivery,
                recognisedDraft: recognisedDraft,
                inputMode: inputMode,
                coveredBySummary: coveredBySummary,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$MessagesTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$MessagesTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, $$MessagesTableReferences),
      MessageRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$DraftsTableCreateCompanionBuilder =
    DraftsCompanion Function({
      required String sessionId,
      required String body,
      Value<String?> recognised,
      Value<String?> repaired,
      required InputMode inputMode,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DraftsTableUpdateCompanionBuilder =
    DraftsCompanion Function({
      Value<String> sessionId,
      Value<String> body,
      Value<String?> recognised,
      Value<String?> repaired,
      Value<InputMode> inputMode,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DraftsTableReferences
    extends BaseReferences<_$AppDatabase, $DraftsTable, DraftRow> {
  $$DraftsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions
      .createAlias($_aliasNameGenerator(db.drafts.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recognised => $composableBuilder(
    column: $table.recognised,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repaired => $composableBuilder(
    column: $table.repaired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InputMode, InputMode, String> get inputMode =>
      $composableBuilder(
        column: $table.inputMode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recognised => $composableBuilder(
    column: $table.recognised,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repaired => $composableBuilder(
    column: $table.repaired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputMode => $composableBuilder(
    column: $table.inputMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftsTable> {
  $$DraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get recognised => $composableBuilder(
    column: $table.recognised,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repaired =>
      $composableBuilder(column: $table.repaired, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InputMode, String> get inputMode =>
      $composableBuilder(column: $table.inputMode, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftsTable,
          DraftRow,
          $$DraftsTableFilterComposer,
          $$DraftsTableOrderingComposer,
          $$DraftsTableAnnotationComposer,
          $$DraftsTableCreateCompanionBuilder,
          $$DraftsTableUpdateCompanionBuilder,
          (DraftRow, $$DraftsTableReferences),
          DraftRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$DraftsTableTableManager(_$AppDatabase db, $DraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> recognised = const Value.absent(),
                Value<String?> repaired = const Value.absent(),
                Value<InputMode> inputMode = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion(
                sessionId: sessionId,
                body: body,
                recognised: recognised,
                repaired: repaired,
                inputMode: inputMode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String body,
                Value<String?> recognised = const Value.absent(),
                Value<String?> repaired = const Value.absent(),
                required InputMode inputMode,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DraftsCompanion.insert(
                sessionId: sessionId,
                body: body,
                recognised: recognised,
                repaired: repaired,
                inputMode: inputMode,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DraftsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$DraftsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$DraftsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftsTable,
      DraftRow,
      $$DraftsTableFilterComposer,
      $$DraftsTableOrderingComposer,
      $$DraftsTableAnnotationComposer,
      $$DraftsTableCreateCompanionBuilder,
      $$DraftsTableUpdateCompanionBuilder,
      (DraftRow, $$DraftsTableReferences),
      DraftRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$AssessmentsTableCreateCompanionBuilder =
    AssessmentsCompanion Function({
      required String sessionId,
      required String matchedApproach,
      required MatchedVerdict matchedVerdict,
      required List<String> insightsHit,
      Value<List<String>?> insightsAssisted,
      required List<String> insightsMissed,
      required List<String> wrongTurnsTaken,
      required String complexityJson,
      required Verdict verdict,
      required double confidence,
      required String feedback,
      required String editorial,
      Value<int?> revealAtIndex,
      required String rawJson,
      required DateTime receivedAt,
      Value<int> rowid,
    });
typedef $$AssessmentsTableUpdateCompanionBuilder =
    AssessmentsCompanion Function({
      Value<String> sessionId,
      Value<String> matchedApproach,
      Value<MatchedVerdict> matchedVerdict,
      Value<List<String>> insightsHit,
      Value<List<String>?> insightsAssisted,
      Value<List<String>> insightsMissed,
      Value<List<String>> wrongTurnsTaken,
      Value<String> complexityJson,
      Value<Verdict> verdict,
      Value<double> confidence,
      Value<String> feedback,
      Value<String> editorial,
      Value<int?> revealAtIndex,
      Value<String> rawJson,
      Value<DateTime> receivedAt,
      Value<int> rowid,
    });

final class $$AssessmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AssessmentsTable, AssessmentRow> {
  $$AssessmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias(
        $_aliasNameGenerator(db.assessments.sessionId, db.sessions.id),
      );

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssessmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AssessmentsTable> {
  $$AssessmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get matchedApproach => $composableBuilder(
    column: $table.matchedApproach,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MatchedVerdict, MatchedVerdict, String>
  get matchedVerdict => $composableBuilder(
    column: $table.matchedVerdict,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get insightsHit => $composableBuilder(
    column: $table.insightsHit,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get insightsAssisted => $composableBuilder(
    column: $table.insightsAssisted,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get insightsMissed => $composableBuilder(
    column: $table.insightsMissed,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get wrongTurnsTaken => $composableBuilder(
    column: $table.wrongTurnsTaken,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get complexityJson => $composableBuilder(
    column: $table.complexityJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Verdict, Verdict, String> get verdict =>
      $composableBuilder(
        column: $table.verdict,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedback => $composableBuilder(
    column: $table.feedback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editorial => $composableBuilder(
    column: $table.editorial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revealAtIndex => $composableBuilder(
    column: $table.revealAtIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssessmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssessmentsTable> {
  $$AssessmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get matchedApproach => $composableBuilder(
    column: $table.matchedApproach,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchedVerdict => $composableBuilder(
    column: $table.matchedVerdict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insightsHit => $composableBuilder(
    column: $table.insightsHit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insightsAssisted => $composableBuilder(
    column: $table.insightsAssisted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insightsMissed => $composableBuilder(
    column: $table.insightsMissed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrongTurnsTaken => $composableBuilder(
    column: $table.wrongTurnsTaken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get complexityJson => $composableBuilder(
    column: $table.complexityJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedback => $composableBuilder(
    column: $table.feedback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editorial => $composableBuilder(
    column: $table.editorial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revealAtIndex => $composableBuilder(
    column: $table.revealAtIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssessmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssessmentsTable> {
  $$AssessmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get matchedApproach => $composableBuilder(
    column: $table.matchedApproach,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MatchedVerdict, String> get matchedVerdict =>
      $composableBuilder(
        column: $table.matchedVerdict,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get insightsHit =>
      $composableBuilder(
        column: $table.insightsHit,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>?, String>
  get insightsAssisted => $composableBuilder(
    column: $table.insightsAssisted,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get insightsMissed =>
      $composableBuilder(
        column: $table.insightsMissed,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<String>, String> get wrongTurnsTaken =>
      $composableBuilder(
        column: $table.wrongTurnsTaken,
        builder: (column) => column,
      );

  GeneratedColumn<String> get complexityJson => $composableBuilder(
    column: $table.complexityJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Verdict, String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get feedback =>
      $composableBuilder(column: $table.feedback, builder: (column) => column);

  GeneratedColumn<String> get editorial =>
      $composableBuilder(column: $table.editorial, builder: (column) => column);

  GeneratedColumn<int> get revealAtIndex => $composableBuilder(
    column: $table.revealAtIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssessmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssessmentsTable,
          AssessmentRow,
          $$AssessmentsTableFilterComposer,
          $$AssessmentsTableOrderingComposer,
          $$AssessmentsTableAnnotationComposer,
          $$AssessmentsTableCreateCompanionBuilder,
          $$AssessmentsTableUpdateCompanionBuilder,
          (AssessmentRow, $$AssessmentsTableReferences),
          AssessmentRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AssessmentsTableTableManager(_$AppDatabase db, $AssessmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssessmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssessmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssessmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> matchedApproach = const Value.absent(),
                Value<MatchedVerdict> matchedVerdict = const Value.absent(),
                Value<List<String>> insightsHit = const Value.absent(),
                Value<List<String>?> insightsAssisted = const Value.absent(),
                Value<List<String>> insightsMissed = const Value.absent(),
                Value<List<String>> wrongTurnsTaken = const Value.absent(),
                Value<String> complexityJson = const Value.absent(),
                Value<Verdict> verdict = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> feedback = const Value.absent(),
                Value<String> editorial = const Value.absent(),
                Value<int?> revealAtIndex = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<DateTime> receivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssessmentsCompanion(
                sessionId: sessionId,
                matchedApproach: matchedApproach,
                matchedVerdict: matchedVerdict,
                insightsHit: insightsHit,
                insightsAssisted: insightsAssisted,
                insightsMissed: insightsMissed,
                wrongTurnsTaken: wrongTurnsTaken,
                complexityJson: complexityJson,
                verdict: verdict,
                confidence: confidence,
                feedback: feedback,
                editorial: editorial,
                revealAtIndex: revealAtIndex,
                rawJson: rawJson,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String matchedApproach,
                required MatchedVerdict matchedVerdict,
                required List<String> insightsHit,
                Value<List<String>?> insightsAssisted = const Value.absent(),
                required List<String> insightsMissed,
                required List<String> wrongTurnsTaken,
                required String complexityJson,
                required Verdict verdict,
                required double confidence,
                required String feedback,
                required String editorial,
                Value<int?> revealAtIndex = const Value.absent(),
                required String rawJson,
                required DateTime receivedAt,
                Value<int> rowid = const Value.absent(),
              }) => AssessmentsCompanion.insert(
                sessionId: sessionId,
                matchedApproach: matchedApproach,
                matchedVerdict: matchedVerdict,
                insightsHit: insightsHit,
                insightsAssisted: insightsAssisted,
                insightsMissed: insightsMissed,
                wrongTurnsTaken: wrongTurnsTaken,
                complexityJson: complexityJson,
                verdict: verdict,
                confidence: confidence,
                feedback: feedback,
                editorial: editorial,
                revealAtIndex: revealAtIndex,
                rawJson: rawJson,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AssessmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$AssessmentsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$AssessmentsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AssessmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssessmentsTable,
      AssessmentRow,
      $$AssessmentsTableFilterComposer,
      $$AssessmentsTableOrderingComposer,
      $$AssessmentsTableAnnotationComposer,
      $$AssessmentsTableCreateCompanionBuilder,
      $$AssessmentsTableUpdateCompanionBuilder,
      (AssessmentRow, $$AssessmentsTableReferences),
      AssessmentRow,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String id,
      required String sessionId,
      required OutboxKind kind,
      required String payload,
      required int solutionRequestCountAtEnqueue,
      Value<int> attempts,
      required DateTime nextEligibleAt,
      Value<String?> lastErrorCode,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<OutboxKind> kind,
      Value<String> payload,
      Value<int> solutionRequestCountAtEnqueue,
      Value<int> attempts,
      Value<DateTime> nextEligibleAt,
      Value<String?> lastErrorCode,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$OutboxTableReferences
    extends BaseReferences<_$AppDatabase, $OutboxTable, OutboxData> {
  $$OutboxTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions
      .createAlias($_aliasNameGenerator(db.outbox.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxKind, OutboxKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get solutionRequestCountAtEnqueue => $composableBuilder(
    column: $table.solutionRequestCountAtEnqueue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextEligibleAt => $composableBuilder(
    column: $table.nextEligibleAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get solutionRequestCountAtEnqueue => $composableBuilder(
    column: $table.solutionRequestCountAtEnqueue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextEligibleAt => $composableBuilder(
    column: $table.nextEligibleAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get solutionRequestCountAtEnqueue => $composableBuilder(
    column: $table.solutionRequestCountAtEnqueue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextEligibleAt => $composableBuilder(
    column: $table.nextEligibleAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, $$OutboxTableReferences),
          OutboxData,
          PrefetchHooks Function({bool sessionId})
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<OutboxKind> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> solutionRequestCountAtEnqueue = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> nextEligibleAt = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                id: id,
                sessionId: sessionId,
                kind: kind,
                payload: payload,
                solutionRequestCountAtEnqueue: solutionRequestCountAtEnqueue,
                attempts: attempts,
                nextEligibleAt: nextEligibleAt,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required OutboxKind kind,
                required String payload,
                required int solutionRequestCountAtEnqueue,
                Value<int> attempts = const Value.absent(),
                required DateTime nextEligibleAt,
                Value<String?> lastErrorCode = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                id: id,
                sessionId: sessionId,
                kind: kind,
                payload: payload,
                solutionRequestCountAtEnqueue: solutionRequestCountAtEnqueue,
                attempts: attempts,
                nextEligibleAt: nextEligibleAt,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$OutboxTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$OutboxTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$OutboxTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, $$OutboxTableReferences),
      OutboxData,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$StreakDaysTableCreateCompanionBuilder =
    StreakDaysCompanion Function({
      required String day,
      required DateTime creditedAt,
      Value<int> rowid,
    });
typedef $$StreakDaysTableUpdateCompanionBuilder =
    StreakDaysCompanion Function({
      Value<String> day,
      Value<DateTime> creditedAt,
      Value<int> rowid,
    });

class $$StreakDaysTableFilterComposer
    extends Composer<_$AppDatabase, $StreakDaysTable> {
  $$StreakDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creditedAt => $composableBuilder(
    column: $table.creditedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StreakDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $StreakDaysTable> {
  $$StreakDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creditedAt => $composableBuilder(
    column: $table.creditedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StreakDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreakDaysTable> {
  $$StreakDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<DateTime> get creditedAt => $composableBuilder(
    column: $table.creditedAt,
    builder: (column) => column,
  );
}

class $$StreakDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StreakDaysTable,
          StreakDay,
          $$StreakDaysTableFilterComposer,
          $$StreakDaysTableOrderingComposer,
          $$StreakDaysTableAnnotationComposer,
          $$StreakDaysTableCreateCompanionBuilder,
          $$StreakDaysTableUpdateCompanionBuilder,
          (
            StreakDay,
            BaseReferences<_$AppDatabase, $StreakDaysTable, StreakDay>,
          ),
          StreakDay,
          PrefetchHooks Function()
        > {
  $$StreakDaysTableTableManager(_$AppDatabase db, $StreakDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<DateTime> creditedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StreakDaysCompanion(
                day: day,
                creditedAt: creditedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required DateTime creditedAt,
                Value<int> rowid = const Value.absent(),
              }) => StreakDaysCompanion.insert(
                day: day,
                creditedAt: creditedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StreakDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StreakDaysTable,
      StreakDay,
      $$StreakDaysTableFilterComposer,
      $$StreakDaysTableOrderingComposer,
      $$StreakDaysTableAnnotationComposer,
      $$StreakDaysTableCreateCompanionBuilder,
      $$StreakDaysTableUpdateCompanionBuilder,
      (StreakDay, BaseReferences<_$AppDatabase, $StreakDaysTable, StreakDay>),
      StreakDay,
      PrefetchHooks Function()
    >;
typedef $$CachedConfigTableCreateCompanionBuilder =
    CachedConfigCompanion Function({
      Value<int> id,
      required String json,
      Value<String?> etag,
      required DateTime fetchedAt,
    });
typedef $$CachedConfigTableUpdateCompanionBuilder =
    CachedConfigCompanion Function({
      Value<int> id,
      Value<String> json,
      Value<String?> etag,
      Value<DateTime> fetchedAt,
    });

class $$CachedConfigTableFilterComposer
    extends Composer<_$AppDatabase, $CachedConfigTable> {
  $$CachedConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedConfigTable> {
  $$CachedConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedConfigTable> {
  $$CachedConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedConfigTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedConfigTable,
          CachedConfigData,
          $$CachedConfigTableFilterComposer,
          $$CachedConfigTableOrderingComposer,
          $$CachedConfigTableAnnotationComposer,
          $$CachedConfigTableCreateCompanionBuilder,
          $$CachedConfigTableUpdateCompanionBuilder,
          (
            CachedConfigData,
            BaseReferences<_$AppDatabase, $CachedConfigTable, CachedConfigData>,
          ),
          CachedConfigData,
          PrefetchHooks Function()
        > {
  $$CachedConfigTableTableManager(_$AppDatabase db, $CachedConfigTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => CachedConfigCompanion(
                id: id,
                json: json,
                etag: etag,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String json,
                Value<String?> etag = const Value.absent(),
                required DateTime fetchedAt,
              }) => CachedConfigCompanion.insert(
                id: id,
                json: json,
                etag: etag,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedConfigTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedConfigTable,
      CachedConfigData,
      $$CachedConfigTableFilterComposer,
      $$CachedConfigTableOrderingComposer,
      $$CachedConfigTableAnnotationComposer,
      $$CachedConfigTableCreateCompanionBuilder,
      $$CachedConfigTableUpdateCompanionBuilder,
      (
        CachedConfigData,
        BaseReferences<_$AppDatabase, $CachedConfigTable, CachedConfigData>,
      ),
      CachedConfigData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$InstallIdentityTableTableManager get installIdentity =>
      $$InstallIdentityTableTableManager(_db, _db.installIdentity);
  $$CachedProblemsTableTableManager get cachedProblems =>
      $$CachedProblemsTableTableManager(_db, _db.cachedProblems);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$DraftsTableTableManager get drafts =>
      $$DraftsTableTableManager(_db, _db.drafts);
  $$AssessmentsTableTableManager get assessments =>
      $$AssessmentsTableTableManager(_db, _db.assessments);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$StreakDaysTableTableManager get streakDays =>
      $$StreakDaysTableTableManager(_db, _db.streakDays);
  $$CachedConfigTableTableManager get cachedConfig =>
      $$CachedConfigTableTableManager(_db, _db.cachedConfig);
}

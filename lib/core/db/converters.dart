import 'dart:convert';

import 'package:drift/drift.dart';

export '../models/wire_enums.dart';

/// Converts a `List<String>` to and from the JSON text stored in a text
/// column. Used for every repeated-string field mirrored off
/// `problem.schema.json#PublicHalf` (tags, constraints, collections,
/// glossaryTerms) and off the assessment (insightsHit, insightsMissed,
/// wrongTurnsTaken).
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) {
      return const <String>[];
    }
    final Object? decoded = jsonDecode(fromDb);
    if (decoded is! List) {
      return const <String>[];
    }
    return decoded.map((Object? e) => e.toString()).toList(growable: false);
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

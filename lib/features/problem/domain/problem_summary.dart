class ProblemSummary {
  const ProblemSummary({required this.id, required this.title, this.difficulty, required this.tags});

  final String id;
  final String title;
  final int? difficulty;
  final List<String> tags;
}

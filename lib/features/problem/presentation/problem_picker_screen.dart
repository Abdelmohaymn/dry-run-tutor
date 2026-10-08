import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_route.dart';
import '../../chat/presentation/daily_session_cubit.dart';
import '../domain/problem_repository.dart';
import '../domain/problem_summary.dart';

class ProblemPickerScreen extends StatefulWidget {
  const ProblemPickerScreen({required this.problemRepository, super.key});

  final ProblemRepository problemRepository;

  @override
  State<ProblemPickerScreen> createState() => _ProblemPickerScreenState();
}

class _ProblemPickerScreenState extends State<ProblemPickerScreen> {
  late final Future<List<ProblemSummary>> _problems = widget.problemRepository.fetchProblems();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.problemPickerTitle)),
      body: FutureBuilder<List<ProblemSummary>>(
        future: _problems,
        builder: (BuildContext context, AsyncSnapshot<List<ProblemSummary>> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errUnclearRetry));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<ProblemSummary> problems = snapshot.data!;
          return ListView.builder(
            itemCount: problems.length,
            itemBuilder: (BuildContext context, int index) {
              final ProblemSummary problem = problems[index];
              return ListTile(
                title: Text(problem.title),
                subtitle: Text(problem.difficulty?.toString() ?? ''),
                onTap: () async {
                  await context.read<DailySessionCubit>().open(problemId: problem.id);
                  if (context.mounted) context.go(AppRoute.daily.path);
                },
              );
            },
          );
        },
      ),
    );
  }
}

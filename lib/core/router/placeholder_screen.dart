import 'package:flutter/material.dart';

/// Stands in for every route not yet built, so Phase 2's checkpoint — the
/// app launches to an empty shell over all 21 routes — is genuinely
/// reachable rather than a promise the router can't keep. Each user story
/// phase replaces its own routes' placeholders with the real screen; this
/// widget carries no learner-facing copy, so it is exempt from the
/// `no_string_literals_in_widgets` ARB rule (FR-052) by directory scope —
/// nothing rendered here ever ships.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.routeName, super.key});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Not yet built: $routeName'),
      ),
    );
  }
}

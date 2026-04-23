import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/teacher_bottom_nav.dart';

/// Shell scaffold that wraps all teacher screens with a persistent bottom nav bar.
/// Used by ShellRoute in the GoRouter configuration.
class TeacherShellScaffold extends StatelessWidget {
  final Widget child;

  const TeacherShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const TeacherBottomNav(),
    );
  }
}

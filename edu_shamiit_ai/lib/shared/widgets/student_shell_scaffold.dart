import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/student_bottom_nav.dart';

/// Shell scaffold that wraps all student screens with a persistent bottom nav bar.
/// Used by ShellRoute in the GoRouter configuration.
class StudentShellScaffold extends StatelessWidget {
  final Widget child;

  const StudentShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const StudentBottomNav(),
    );
  }
}

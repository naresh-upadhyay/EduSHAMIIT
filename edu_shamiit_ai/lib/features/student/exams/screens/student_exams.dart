import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';

/// Student Exams Screen - Shows upcoming and past exams
class StudentExamsScreen extends StatelessWidget {
  const StudentExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      appBar: AppBar(
        backgroundColor: StudentColors.surface,
        elevation: 0,
        title: const Text(
          'Exams',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: StudentColors.text,
          ),
        ),
      ),
      body: const Center(
        child: Text('Exams screen - Coming soon'),
      ),
    );
  }
}
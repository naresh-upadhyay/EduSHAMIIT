import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class ExamSubmissionScreen extends ConsumerStatefulWidget {
  final String examId;
  final bool autoSubmitted;
  const ExamSubmissionScreen(
      {super.key, required this.examId, this.autoSubmitted = false});

  @override
  ConsumerState<ExamSubmissionScreen> createState() =>
      _ExamSubmissionScreenState();
}

class _ExamSubmissionScreenState extends ConsumerState<ExamSubmissionScreen> {
  bool _isLoading = true;
  final String _receiptToken = 'TX-EXAM-2026-9874A';
  late String _timestamp;

  @override
  void initState() {
    super.initState();
    _timestamp = DateTime.now().toString().substring(0, 19);
    _processSubmission();
  }

  Future<void> _processSubmission() async {
    // Simulating secure submission processing on Supabase/PostgreSQL
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: _isLoading ? _buildLoadingState() : _buildSuccessState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Color(0xFF134E4A)),
        const SizedBox(height: 24),
        const Text(
          'Securing Submission...',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.autoSubmitted
              ? 'Proctor limit reached. Auto-submitting answers...'
              : 'Uploading final answer sheets and locks...',
          style: const TextStyle(fontSize: 12, color: StudentColors.text2),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded,
            color: StudentColors.success, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Examination Submitted!',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.autoSubmitted
              ? 'Auto-submitted by System Lock'
              : 'Manually submitted by Student',
          style: TextStyle(
            fontSize: 11,
            color: widget.autoSubmitted ? Colors.red : StudentColors.text3,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),

        // Receipt Card Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StudentColors.border),
          ),
          child: Column(
            children: [
              _buildReceiptRow('Receipt Code', _receiptToken,
                  isMonospace: true),
              const Divider(height: 20),
              _buildReceiptRow('Timestamp', _timestamp),
              const Divider(height: 20),
              _buildReceiptRow('Lock Status', 'LOCKED & SEALED',
                  valueColor: Colors.blue),
              const Divider(height: 20),
              _buildReceiptRow('Evaluated Status', 'Pending Grading',
                  valueColor: Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Return to Exams Route trigger
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Redirect to student exams list
              context.pushReplacement('/student/exams');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF134E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Return to Exams'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              context.go('/student/dashboard');
            },
            child: const Text('Return to Home Dashboard'),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value,
      {Color? valueColor, bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: StudentColors.text2)),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontFamily: isMonospace ? 'monospace' : null,
            fontWeight: FontWeight.bold,
            color: valueColor ?? StudentColors.text,
          ),
        ),
      ],
    );
  }
}

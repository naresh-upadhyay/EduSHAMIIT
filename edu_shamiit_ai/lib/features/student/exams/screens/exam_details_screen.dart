import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';

class ExamDetailsScreen extends ConsumerStatefulWidget {
  final String examId;
  const ExamDetailsScreen({super.key, required this.examId});

  @override
  ConsumerState<ExamDetailsScreen> createState() => _ExamDetailsScreenState();
}

class _ExamDetailsScreenState extends ConsumerState<ExamDetailsScreen> {
  final StudentApiService _apiService = StudentApiService();
  Map<String, dynamic>? _examData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExamDetails();
  }

  Future<void> _loadExamDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final data = await _apiService.getOnlineExamDetails(widget.examId);
      setState(() {
        _examData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatExamDateTime(String? rawTimeStr) {
    if (rawTimeStr == null) return 'TBD';
    try {
      final dt = DateTime.parse(rawTimeStr).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final String period = dt.hour >= 12 ? 'PM' : 'AM';
      final int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final String minutes = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year} at $hour:$minutes $period';
    } catch (_) {
      return rawTimeStr;
    }
  }

  List<String> _getInstructions(String? instructions, bool camera, bool mic) {
    if (instructions != null && instructions.trim().isNotEmpty) {
      return instructions
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }
    // Dynamic fallbacks based on proctoring config
    final list = <String>[];
    list.add('Ensure you have a stable high-speed internet connection before beginning.');
    if (camera) {
      list.add('Keep your face in focus of the web camera at all times. The proctoring system flags suspicious movements.');
    }
    if (mic) {
      list.add('Ensure you are in a quiet room. Ambient sound and background voices will be recorded and analyzed.');
    }
    list.add('Leaving the exam screen or switching tabs will trigger security warnings. 5 warnings result in auto-submission.');
    list.add('Ensure you have physical rough sheets. You will need to upload your subjective answers in image/PDF format.');
    return list;
  }

  void _showPasscodeDialog(BuildContext context, bool isOnline) {
    final TextEditingController passcodeController = TextEditingController();
    bool isVerifying = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: Color(0xFF134E4A), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Passcode Required',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This exam is secured. Please enter the access passcode provided by your instructor to unlock it.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passcodeController,
                    obscureText: true,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      labelText: 'Exam Passcode',
                      labelStyle: const TextStyle(color: Color(0xFF134E4A), fontSize: 13, fontWeight: FontWeight.w600),
                      hintText: 'Enter access code',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13, letterSpacing: 0),
                      prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF134E4A), size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF134E4A), width: 1.5),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dialogError!,
                            style: const TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = passcodeController.text.trim();
                          if (code.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Please enter the passcode';
                            });
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            dialogError = null;
                          });
                          try {
                            final res = await _apiService.verifyExamPasscode(widget.examId, code);
                            if (res['success'] == true) {
                              if (context.mounted) {
                                Navigator.pop(context); // Close dialog
                                context.push('/student/exams/verify/${widget.examId}?passcode=$code');
                              }
                            } else {
                              setDialogState(() {
                                isVerifying = false;
                                dialogError = res['message'] ?? 'Incorrect passcode. Try again.';
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isVerifying = false;
                              dialogError = 'Connection error. Please retry.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF134E4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Unlock & Join', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF134E4A)),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('Exam Guidelines'.tr(ref), style: const TextStyle(color: Colors.white, fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF134E4A),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => safeGoBack(context, '/student/exams'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'Failed to load exam details: $_error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadExamDetails,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF134E4A), foregroundColor: Colors.white),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dataPayload = _examData?['data'] ?? _examData ?? {};
    final exam = dataPayload['exam'] as Map<String, dynamic>? ?? {};
    final questions = dataPayload['questions'] as List<dynamic>? ?? [];
    final submission = dataPayload['submission'] as Map<String, dynamic>?;

    final title = exam['title'] ?? 'Online Examination';
    final subject = (exam['subjects'] as Map<String, dynamic>?)?['name'] ?? exam['subject'] ?? 'General';
    final teacherName = (exam['profiles'] as Map<String, dynamic>?)?['full_name'] ?? 'Course Instructor';
    final durationMins = exam['duration_minutes'] ?? 90;
    final totalMarks = exam['total_marks'] ?? 100;
    final passingMarks = exam['passing_marks'] ?? 40;
    final isOnline = (exam['exam_type'] ?? 'online').toString().toLowerCase() == 'online';
    final venue = exam['venue'] ?? (isOnline ? 'Online Portal' : 'Classroom');
    final hasPasscode = exam['has_passcode'] as bool? ?? false;

    // Proctor locks
    final camera = exam['camera_required'] as bool? ?? true;
    final mic = exam['mic_required'] as bool? ?? true;

    final startTimeStr = _formatExamDateTime(exam['start_time']?.toString() ?? exam['exam_date']?.toString());
    final instructionLines = _getInstructions(exam['instructions'] as String?, camera, mic);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Exam Guidelines'.tr(ref),
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF134E4A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/student/exams'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Exam Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF134E4A), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF134E4A).withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isOnline ? 'Online Exam' : 'Offline Exam',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (hasPasscode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amberAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 10),
                                SizedBox(width: 4),
                                Text(
                                  'Passcode Locked',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        const Text(
                          '📐',
                          style: TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Teacher: $teacherName',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Parameter Grid Card
              const Text(
                'Exam Details',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: StudentColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: StudentColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Subject', subject, Icons.book_outlined),
                    const Divider(height: 24),
                    _buildDetailRow('Duration', '$durationMins Minutes', Icons.hourglass_top),
                    const Divider(height: 24),
                    _buildDetailRow('Total Questions', '${questions.length}', Icons.quiz_outlined),
                    const Divider(height: 24),
                    _buildDetailRow('Total Marks', '$totalMarks Marks', Icons.stars_outlined),
                    const Divider(height: 24),
                    _buildDetailRow('Passing Marks', '$passingMarks Marks', Icons.verified_user_outlined),
                    const Divider(height: 24),
                    _buildDetailRow('Venue / Mode', venue, Icons.location_on_outlined),
                    const Divider(height: 24),
                    _buildDetailRow('Start Time', startTimeStr, Icons.play_circle_outline),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Academic Instructions Card
              const Text(
                'Academic Integrity Rules',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: StudentColors.text,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFEE2E2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: instructionLines.map((instruction) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🛑', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              instruction,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF991B1B),
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading PDF guidelines...')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Guidelines'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF134E4A),
                        side: const BorderSide(color: Color(0xFF134E4A)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: submission != null && (submission['status'] == 'submitted' || submission['status'] == 'graded')
                          ? null
                          : () {
                              if (isOnline) {
                                if (hasPasscode) {
                                  _showPasscodeDialog(context, isOnline);
                                } else {
                                  context.push('/student/exams/verify/${widget.examId}');
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('This is an offline exam. Please report to the classroom venue.')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF134E4A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        submission != null && (submission['status'] == 'submitted' || submission['status'] == 'graded')
                            ? 'Submitted'
                            : (((submission != null && submission['status'] == 'active') || dataPayload['session'] != null)
                                ? 'Resume Exam'
                                : (hasPasscode ? 'Unlock & Join' : 'Start Exam')),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF134E4A), size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: StudentColors.text2,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? StudentColors.text,
          ),
        ),
      ],
    );
  }
}

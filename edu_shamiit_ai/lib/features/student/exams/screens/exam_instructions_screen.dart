import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';

class ExamInstructionsScreen extends ConsumerStatefulWidget {
  final String examId;
  final String? passcode;
  const ExamInstructionsScreen({super.key, required this.examId, this.passcode});

  @override
  ConsumerState<ExamInstructionsScreen> createState() => _ExamInstructionsScreenState();
}

class _ExamInstructionsScreenState extends ConsumerState<ExamInstructionsScreen> {
  final StudentApiService _apiService = StudentApiService();
  Map<String, dynamic>? _examData;
  bool _isLoading = true;
  String? _error;

  // Multi-item checklist for premium verification
  bool _checkedQuietSpace = false;
  bool _checkedMonitoring = false;
  bool _checkedViolations = false;
  bool _checkedHonorCode = false;

  bool get _allChecked =>
      _checkedQuietSpace && _checkedMonitoring && _checkedViolations && _checkedHonorCode;

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
          title: const Text('Final Instructions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF134E4A),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => safeGoBack(context, '/student/exams/verify/${widget.examId}'),
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
    final title = exam['title'] ?? 'Online Examination';
    final durationMins = exam['duration_minutes'] ?? 90;
    
    // Proctor Settings
    final camera = exam['camera_required'] as bool? ?? true;
    final mic = exam['mic_required'] as bool? ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Final Instructions',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            final query = widget.passcode != null ? '?passcode=${widget.passcode}' : '';
            safeGoBack(context, '/student/exams/verify/${widget.examId}$query');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Alert Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFEF3C7)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('⚠️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Proctored Environment Active',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Upon launching the exam, the system will switch to a secured test taking mode. AI analysis will monitor webcam and window visibility status.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Exam Title Summary Block
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Duration: $durationMins Minutes • Total Questions: ${dataPayload['questions']?.length ?? 0}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Instruction Sections
                    const Text(
                      'Exam Regulations Checklist',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: StudentColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStepItem(
                      '1',
                      'Timer & Submission Policy',
                      'The exam has a strict countdown timer of $durationMins minutes. When the timer reaches zero, your responses are auto-submitted and locked immediately.',
                    ),
                    _buildStepItem(
                      '2',
                      'Navigation Rules',
                      'You can navigate questions using the sidebar palette or next/previous buttons. Answer drafts are auto-saved locally every 15 seconds.',
                    ),
                    _buildStepItem(
                      '3',
                      'AI Proctoring Monitoring',
                      '${camera ? "📸 Webcam tracking" : "Camera tracking"} and ${mic ? "🎤 audio capture" : "audio capture"} are enabled. Focus loss, switching tabs, or resizing windows counts as a proctor warning (max 3 warnings).',
                    ),
                    _buildStepItem(
                      '4',
                      'Subjective File Uploads',
                      'For descriptive/subjective questions, upload snapshots of your handwritten sheets before clicking final submit.',
                    ),
                    const SizedBox(height: 16),

                    // Declaration checklist
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Integrity Agreement Checklist',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: StudentColors.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: StudentColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildCheckboxTile(
                            'I am sitting in a quiet, well-lit private space and will remain alone throughout the test.',
                            _checkedQuietSpace,
                            (val) => setState(() => _checkedQuietSpace = val ?? false),
                          ),
                          const Divider(height: 16),
                          _buildCheckboxTile(
                            'I understand that my webcam and microphone must remain active and in focus at all times.',
                            _checkedMonitoring,
                            (val) => setState(() => _checkedMonitoring = val ?? false),
                          ),
                          const Divider(height: 16),
                          _buildCheckboxTile(
                            'I agree that window blur (leaving fullscreen, opening devtools, switching tabs) will result in warnings.',
                            _checkedViolations,
                            (val) => setState(() => _checkedViolations = val ?? false),
                          ),
                          const Divider(height: 16),
                          _buildCheckboxTile(
                            'Academic Honor: I certify that I will answer questions without using smart devices, textbooks, or notes.',
                            _checkedHonorCode,
                            (val) => setState(() => _checkedHonorCode = val ?? false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // Bottom Action bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _allChecked
                      ? () {
                          final query = widget.passcode != null ? '?passcode=${widget.passcode}' : '';
                          context.push('/student/exams/live/${widget.examId}$query');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF134E4A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Begin Examination Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(String index, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                index,
                style: const TextStyle(
                  color: Color(0xFF4338CA),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: StudentColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: StudentColors.text2,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxTile(String text, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          activeColor: const Color(0xFF134E4A),
          onChanged: onChanged,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 8.0),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: StudentColors.text2,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

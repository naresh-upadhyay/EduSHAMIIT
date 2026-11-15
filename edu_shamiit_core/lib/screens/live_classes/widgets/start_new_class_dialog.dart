import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/live_class_management_provider.dart';
import '../services/live_class_api_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/role_provider.dart';

class StartNewClassDialog extends ConsumerStatefulWidget {
  const StartNewClassDialog({super.key});

  @override
  ConsumerState<StartNewClassDialog> createState() => _StartNewClassDialogState();
}

class _StartNewClassDialogState extends ConsumerState<StartNewClassDialog> {
  int _currentStep = 0;

  // Step 1: Academic Info
  String _selectedAcademicYear = '2026 - 2027';
  String _selectedAcademicSession = 'Annual Session (Full Year)';
  String _selectedClass = 'Class 10';
  String? _selectedClassId;
  String _selectedSection = '10-A';
  String _selectedSubject = 'Mathematics';

  // Step 2: Class Info
  final _topicCtrl = TextEditingController(text: 'Quadratic Equations – Part 2');
  final _descCtrl = TextEditingController(text: 'Completing the square and word problems applications');
  final _chapterCtrl = TextEditingController(text: 'Chapter 4: Quadratic Equations');
  final _objectivesCtrl = TextEditingController(text: 'Understand completing the square method and solve real-world projectile trajectory problems.');
  String _selectedTeacher = 'King Doe (Super Admin)';
  String _selectedCoTeacher = 'None';

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    final user = authState.userData;
    final userName = (user?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (user!['full_name'] as String).trim()
        : (authState.role == UserRole.superAdmin ? 'King Doe' : 'Teacher');
    _selectedTeacher = '$userName (${authState.role == UserRole.superAdmin ? "Super Admin" : "Teacher"})';

    final state = ref.read(liveClassManagementProvider);
    final sessions = state.academicSessions;
    if (sessions.isNotEmpty) {
      _selectedAcademicYear = LiveClassApiService.resolveCurrentFinancialYear(sessions);
    }

    final classes = state.dropdownsData?.classes ?? [];
    if (classes.isNotEmpty) {
      final defaultCls = classes.firstWhere((c) => c.name.contains('10'), orElse: () => classes.first);
      _selectedClass = defaultCls.name;
      _selectedClassId = defaultCls.id;

      final sections = (state.dropdownsData?.sections ?? []).where((s) => s.classId == _selectedClassId).toList();
      if (sections.isNotEmpty) {
        _selectedSection = sections.first.name;
      }
    }

    final subjects = state.dropdownsData?.subjects ?? [];
    if (subjects.isNotEmpty) {
      _selectedSubject = subjects.first.name;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEnrolledStudents();
    });
  }

  // Step 3: Students
  String _studentScope = 'all'; // all, selected, custom
  final Set<String> _selectedStudents = {};
  List<Map<String, dynamic>> _dynamicStudents = [];
  bool _isLoadingStudents = false;

  Future<void> _loadEnrolledStudents() async {
    if (!mounted) return;
    setState(() => _isLoadingStudents = true);
    final state = ref.read(liveClassManagementProvider);
    final matchCls = (state.dropdownsData?.classes ?? [])
        .where((c) => c.name == _selectedClass || c.id == _selectedClassId)
        .firstOrNull;
    final matchSec = (state.dropdownsData?.sections ?? [])
        .where((s) => s.name == _selectedSection && (matchCls == null || s.classId == matchCls.id))
        .firstOrNull;

    final list = await ref.read(liveClassManagementProvider.notifier).fetchEnrolledStudents(
      classId: matchCls?.id,
      sectionId: matchSec?.id,
    );
    if (mounted) {
      setState(() {
        _dynamicStudents = list;
        _isLoadingStudents = false;
        _selectedStudents.clear();
        for (final s in list) {
          final idOrRoll = (s['roll_number'] ?? s['id'] ?? s['user_id'] ?? '').toString();
          if (idOrRoll.isNotEmpty) _selectedStudents.add(idOrRoll);
        }
      });
    }
  }

  // Step 4: Schedule
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 45);
  int _durationMinutes = 45;

  // Step 5: Meeting Configuration
  bool _enableRecording = true;
  bool _enableWaitingRoom = false;
  bool _allowStudentCam = true;
  bool _allowStudentMic = true;
  final bool _allowScreenSharing = true;
  bool _allowChat = true;
  final bool _allowReactions = true;
  bool _enablePolls = true;
  bool _enableQA = true;
  bool _enableWhiteboard = true;
  final int _maxParticipants = 45;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _topicCtrl.dispose();
    _descCtrl.dispose();
    _chapterCtrl.dispose();
    _objectivesCtrl.dispose();
    super.dispose();
  }

  void _calculateDuration() {
    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    if (endMin > startMin) {
      setState(() => _durationMinutes = endMin - startMin);
    }
  }

  Future<void> _submitClass({bool startImmediately = false}) async {
    setState(() => _isSubmitting = true);
    try {
      final scheduledDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final payload = {
        'title': _topicCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'class_section': '$_selectedClass - ${_selectedSection.replaceAll('Section ', '')}',
        'subject': _selectedSubject,
        'chapter': _chapterCtrl.text.trim(),
        'learning_objectives': _objectivesCtrl.text.trim(),
        'teacher_name': _selectedTeacher,
        'co_teacher_name': _selectedCoTeacher,
        'scheduled_at': scheduledDateTime.toIso8601String(),
        'meeting_duration': _durationMinutes,
        'enable_recording': _enableRecording,
        'waiting_room_enabled': _enableWaitingRoom,
        'allow_student_cam': _allowStudentCam,
        'allow_student_mic': _allowStudentMic,
        'allow_student_share': _allowScreenSharing,
        'allow_chat': _allowChat,
        'allow_reactions': _allowReactions,
        'max_participants': _maxParticipants,
        'start_immediately': startImmediately,
      };

      await ref.read(liveClassManagementProvider.notifier).createInstantClass(payload);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              startImmediately
                  ? 'Class created and started live! Room code generated.'
                  : 'Live Class successfully scheduled for ${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year} at ${_startTime.format(context)}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error creating class: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF).withValues(alpha: isDark ? 0.15 : 1.0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_to_queue_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start New Live Class',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                      Text(
                        'Step ${_currentStep + 1} of 6: ${_stepTitles[_currentStep]}',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Stepper progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: List.generate(6, (index) {
                  final isDone = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDone || isCurrent
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (index < 5) const SizedBox(width: 6),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Footer action buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      if (_currentStep == 5) ...[
                        OutlinedButton(
                          onPressed: _isSubmitting ? null : () => _submitClass(startImmediately: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save as Draft'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : () => _submitClass(startImmediately: true),
                          icon: const Icon(Icons.videocam_rounded, size: 16),
                          label: const Text('Start Immediately'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : () => _submitClass(startImmediately: false),
                          icon: const Icon(Icons.schedule_send_rounded, size: 16),
                          label: const Text('Schedule Class'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _currentStep++),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text('Continue'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _stepTitles = [
    'Academic Information',
    'Class Information',
    'Enrolled Students',
    'Class Schedule & Time',
    'Meeting Configuration',
    'Review & Confirm',
  ];

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1AcademicInfo();
      case 1:
        return _buildStep2ClassInfo();
      case 2:
        return _buildStep3Students();
      case 3:
        return _buildStep4Schedule();
      case 4:
        return _buildStep5Configuration();
      case 5:
        return _buildStep6Review();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1AcademicInfo() {
    final state = ref.watch(liveClassManagementProvider);
    final sessions = state.academicSessions.isNotEmpty
        ? state.academicSessions
        : ['2026 - 2027', '2025 - 2026', '2024 - 2025', '2027 - 2028'];
    final classes = state.dropdownsData?.classes ?? [];
    final classNames = classes.map((c) => c.name).toList();
    if (!classNames.contains(_selectedClass) && classNames.isNotEmpty) {
      _selectedClass = classNames.first;
      _selectedClassId = classes.first.id;
    }

    final currentClassId = classes.where((c) => c.name == _selectedClass).firstOrNull?.id ?? _selectedClassId;
    final availableSections = (state.dropdownsData?.sections ?? [])
        .where((s) => currentClassId == null || s.classId == currentClassId)
        .map((s) => s.name)
        .toList();
    final effectiveSections = availableSections.isNotEmpty ? availableSections : ['10-A', '10-B', '10-C', '10-D'];
    if (!effectiveSections.contains(_selectedSection)) {
      _selectedSection = effectiveSections.first;
    }

    final availableSubjects = (state.dropdownsData?.subjects ?? [])
        .where((s) {
          if (s.className == null || s.className!.isEmpty) return true;
          final clsNum = _selectedClass.replaceAll(RegExp(r'[^0-9]'), '');
          return s.className!.contains(_selectedClass) || (clsNum.isNotEmpty && s.className!.contains(clsNum));
        })
        .map((s) => s.name)
        .toSet()
        .toList();
    final effectiveSubjects = availableSubjects.isNotEmpty
        ? availableSubjects
        : ((state.dropdownsData?.subjects ?? []).map((s) => s.name).toSet().toList().isNotEmpty
            ? (state.dropdownsData?.subjects ?? []).map((s) => s.name).toSet().toList()
            : ['Mathematics', 'Physics', 'Chemistry', 'Science', 'English', 'Biology']);
    if (!effectiveSubjects.contains(_selectedSubject)) {
      _selectedSubject = effectiveSubjects.first;
    }

    final termSessions = ['Annual Session (Full Year)', 'Term 1 (Apr - Sep)', 'Term 2 (Oct - Mar)'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Institutional Academic Mapping', 'Assign live session to formal curriculum cohort'),
        const SizedBox(height: 14),
        _buildDropdown('Academic Year', _selectedAcademicYear, sessions, (v) => setState(() => _selectedAcademicYear = v!)),
        const SizedBox(height: 12),
        _buildDropdown('Academic Session / Term', _selectedAcademicSession, termSessions, (v) => setState(() => _selectedAcademicSession = v!)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Class',
                _selectedClass,
                classNames.isNotEmpty ? classNames : ['Class 10', 'Class 11', 'Class 12'],
                (v) {
                  if (v != null) {
                    setState(() {
                      _selectedClass = v;
                      final match = classes.where((c) => c.name == v).firstOrNull;
                      _selectedClassId = match?.id;
                      final newSections = (state.dropdownsData?.sections ?? [])
                          .where((s) => match == null || s.classId == match.id)
                          .map((s) => s.name)
                          .toList();
                      if (newSections.isNotEmpty) {
                        _selectedSection = newSections.first;
                      }
                      _loadEnrolledStudents();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildDropdown(
                'Section',
                _selectedSection,
                effectiveSections,
                (v) {
                  if (v != null) {
                    setState(() => _selectedSection = v);
                    _loadEnrolledStudents();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildDropdown('Subject', _selectedSubject, effectiveSubjects, (v) => setState(() => _selectedSubject = v!)),
      ],
    );
  }

  Widget _buildStep2ClassInfo() {
    final state = ref.watch(liveClassManagementProvider);
    final teachers = state.dropdownsData?.teachers ?? [];
    final teacherOptions = {
      _selectedTeacher,
      ...teachers.map((t) => t.role != null && t.role!.isNotEmpty ? '${t.fullName} (${t.role})' : t.fullName),
    }.toList();
    final coTeachers = ['None', ...teachers.map((t) => t.role != null && t.role!.isNotEmpty ? '${t.fullName} (${t.role})' : t.fullName)];
    if (!coTeachers.contains(_selectedCoTeacher)) {
      _selectedCoTeacher = 'None';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Lesson Topic & Objectives', 'Define lesson outline and instructional leadership'),
        const SizedBox(height: 14),
        _buildTextField('Session Topic *', _topicCtrl, 'e.g. Quadratic Equations – Part 2'),
        const SizedBox(height: 12),
        _buildTextField('Description', _descCtrl, 'Detailed lesson overview...', maxLines: 2),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField('Chapter / Unit', _chapterCtrl, 'e.g. Chapter 4')),
            const SizedBox(width: 14),
            Expanded(child: _buildTextField('Learning Objectives', _objectivesCtrl, 'Key takeaway competencies')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDropdown('Primary Host / Teacher', _selectedTeacher, teacherOptions, (v) => setState(() => _selectedTeacher = v!))),
            const SizedBox(width: 14),
            Expanded(child: _buildDropdown('Co-host / Assistant', _selectedCoTeacher, coTeachers, (v) => setState(() => _selectedCoTeacher = v!))),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Students() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Eligible Student Participants', 'Manage who can join this online classroom'),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              label: Text('All Section Students (${_dynamicStudents.length})'),
              selected: _studentScope == 'all',
              onSelected: (_) => setState(() => _studentScope = 'all'),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('Selected Cohort / Remedial'),
              selected: _studentScope == 'selected',
              onSelected: (_) => setState(() => _studentScope = 'selected'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_isLoadingStudents)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_dynamicStudents.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('No students found for this class & section assignment.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _dynamicStudents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = _dynamicStudents[index];
                final roll = (s['roll_number'] ?? '${index + 1}').toString();
                final name = (s['name'] ?? 'Student').toString();
                final status = (s['status'] ?? 'Enrolled').toString();
                final id = (s['id'] ?? roll).toString();
                final isSelected = _selectedStudents.contains(id) || _selectedStudents.contains(roll);

                return CheckboxListTile(
                  value: _studentScope == 'all' ? true : isSelected,
                  enabled: _studentScope == 'selected',
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedStudents.add(id);
                        _selectedStudents.add(roll);
                      } else {
                        _selectedStudents.remove(id);
                        _selectedStudents.remove(roll);
                      }
                    });
                  },
                  title: Text('$name (Roll: $roll)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('Status: $status', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  secondary: CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: Text(
                      roll.length >= 2 ? roll.substring(roll.length - 2) : roll,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStep4Schedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Session Timing & Duration', 'Set date, time slot, and check timetable conflicts'),
        const SizedBox(height: 14),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _scheduledDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _scheduledDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 10),
                Text('Date: ${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                const Text('Change', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _startTime);
                  if (picked != null) {
                    setState(() => _startTime = picked);
                    _calculateDuration();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('Start: ${_startTime.format(context)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _endTime);
                  if (picked != null) {
                    setState(() => _endTime = picked);
                    _calculateDuration();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('End: ${_endTime.format(context)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text('Duration: $_durationMinutes minutes. No timetable conflict detected for this class slot.', style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Configuration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Conferencing & Security Rules', 'Configure in-meeting permissions and recording'),
        const SizedBox(height: 10),
        SwitchListTile(
          title: const Text('Enable Cloud Recording', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Store recording automatically and publish in Recordings tab after session', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _enableRecording,
          onChanged: (v) => setState(() => _enableRecording = v),
        ),
        SwitchListTile(
          title: const Text('Enable Waiting Room', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Host or co-host must admit participants before they enter', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _enableWaitingRoom,
          onChanged: (v) => setState(() => _enableWaitingRoom = v),
        ),
        SwitchListTile(
          title: const Text('Allow Student Microphones', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Students can unmute themselves during discussion', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _allowStudentMic,
          onChanged: (v) => setState(() => _allowStudentMic = v),
        ),
        SwitchListTile(
          title: const Text('Allow Student Webcams', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Students can stream video for proctored engagement', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _allowStudentCam,
          onChanged: (v) => setState(() => _allowStudentCam = v),
        ),
        SwitchListTile(
          title: const Text('Enable In-Class Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Participants can post questions and chat with instructor', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _allowChat,
          onChanged: (v) => setState(() => _allowChat = v),
        ),
        SwitchListTile(
          title: const Text('Enable Live Polls & Q&A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Allow teacher to launch polls and upvoted student questions', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _enablePolls,
          onChanged: (v) => setState(() {
            _enablePolls = v;
            _enableQA = v;
          }),
        ),
        SwitchListTile(
          title: const Text('Enable Interactive Whiteboard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: const Text('Provide shared digital canvas for collaborative diagrams', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          value: _enableWhiteboard,
          onChanged: (v) => setState(() => _enableWhiteboard = v),
        ),
      ],
    );
  }

  Widget _buildStep6Review() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Review Session Details', 'Verify all configurations before creating'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildReviewRow('Academic Class', '$_selectedClass - $_selectedSection ($_selectedAcademicYear)'),
              _buildReviewRow('Subject', _selectedSubject),
              _buildReviewRow('Session Topic', _topicCtrl.text.trim()),
              _buildReviewRow('Instructor', _selectedTeacher),
              _buildReviewRow('Scheduled Slot', '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year} ${_startTime.format(context)} - ${_endTime.format(context)} ($_durationMinutes min)'),
              _buildReviewRow('Cloud Recording', _enableRecording ? 'Enabled (Auto upload)' : 'Disabled'),
              _buildReviewRow('Student Mic / Cam', _allowStudentMic && _allowStudentCam ? 'Enabled' : 'Restricted'),
              _buildReviewRow('Interactive Tools', '${_enablePolls ? 'Polls, ' : ''}${_enableQA ? 'Q&A, ' : ''}${_enableWhiteboard ? 'Whiteboard' : 'Disabled'}'),
              _buildReviewRow('Participant Cap', '$_maxParticipants students maximum'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 11, color: textSecondary)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final uniqueItems = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && !uniqueItems.contains(trimmed)) {
        uniqueItems.add(trimmed);
      }
    }
    final effectiveValue = uniqueItems.contains(value.trim())
        ? value.trim()
        : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
              items: uniqueItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }
}

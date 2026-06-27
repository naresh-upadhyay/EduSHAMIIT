import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class CreateExamScreen extends ConsumerStatefulWidget {
  final String? examId;
  const CreateExamScreen({super.key, this.examId});

  @override
  ConsumerState<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends ConsumerState<CreateExamScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  int _currentStep = 0;

  // Form Fields State
  final _formKey = GlobalKey<FormState>();
  final _examNameController = TextEditingController();
  final _descController = TextEditingController();
  final _syllabusController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _venueController = TextEditingController(text: 'Online Portal');
  final _durationController = TextEditingController(text: '90');
  final _totalMarksController = TextEditingController(text: '100');

  String _selectedSubject = 'Mathematics';
  String _selectedType = 'Unit Test';
  String _examType = 'online'; // 'online' or 'offline'
  String _status = 'draft';

  // Toggle Settings States (AI proctoring configurations)
  bool _negativeMarking = false;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;
  bool _allowCalculator = false;
  bool _cameraRequired = true;
  bool _micRequired = true;
  bool _autoSubmitOnTimer = true;

  // Dynamic lists loaded from API
  List<TeacherSubject> _subjects = [];
  List<TeacherMyClass> _classes = [];
  bool _isLoadingData = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchDynamicData();
  }

  String? _selectedSubjectId;
  List<String> _selectedClasses = [];

  Future<void> _fetchDynamicData() async {
    try {
      final results = await Future.wait([
        _apiService.getSubjects(allSubjects: true),
        _apiService.getMyClasses(),
      ]);

      setState(() {
        _subjects = results[0] as List<TeacherSubject>;
        _classes = results[1] as List<TeacherMyClass>;

        if (_subjects.isNotEmpty) {
          _selectedSubject = _subjects.first.name;
          _selectedSubjectId = _subjects.first.id;
        }
        if (_classes.isNotEmpty) {
          final first = _classes.first;
          final sec = first.section.trim();
          final label = (sec.isEmpty || first.name.contains('-$sec'))
              ? first.name
              : '${first.name}-$sec';
          _selectedClasses = [label];
        } else {
          _selectedClasses = [];
        }
      });
    } catch (e) {
      debugPrint('Error loading dynamic dropdown dropdowns: $e');
    }

    if (widget.examId != null) {
      await _loadExistingExam();
    } else {
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadExistingExam() async {
    try {
      final exams = await _apiService.getExams();
      final exam = exams.firstWhere((e) => e.id == widget.examId);

      setState(() {
        _examNameController.text = exam.title;
        _descController.text = exam.syllabus ?? '';
        _syllabusController.text = exam.syllabus ?? '';
        _instructionsController.text = exam.instructions ?? '';
        _durationController.text =
            exam.duration.replaceAll(RegExp(r'[^0-9]'), '');
        _totalMarksController.text = exam.totalMarks.toString();
        _selectedSubject = exam.subject;

        if (exam.class_.isNotEmpty) {
          _selectedClasses =
              exam.class_.split(',').map((c) => c.trim()).toList();
        } else {
          _selectedClasses = [];
        }

        String cat = exam.examCategory;
        if (cat.toLowerCase() == 'term') cat = 'Mid Term';
        if (cat.toLowerCase() == 'unit') cat = 'Unit Test';
        if (cat.toLowerCase() == 'quiz') cat = 'Practice Test';
        if (cat.toLowerCase() == 'final') cat = 'Final Exam';

        final allowedCategories = [
          'Practice Test',
          'Weekly Test',
          'Unit Test',
          'Mock Test',
          'Mid Term',
          'Final Exam'
        ];
        if (!allowedCategories.contains(cat)) {
          final match = allowedCategories.firstWhere(
            (c) => c.toLowerCase() == cat.toLowerCase(),
            orElse: () => 'Unit Test',
          );
          cat = match;
        }
        _selectedType = cat;
        _examType =
            exam.examType.toLowerCase() == 'online' ? 'online' : 'offline';
        _venueController.text = exam.roomNumber ?? 'Online Portal';

        // Settings / Proctoring locks
        _negativeMarking = exam.negativeMarking;
        _shuffleQuestions = exam.shuffleQuestions;
        _shuffleOptions = exam.shuffleOptions;
        _allowCalculator = exam.allowCalculator;
        _cameraRequired = exam.cameraRequired;
        _micRequired = exam.micRequired;
        _autoSubmitOnTimer = exam.autoSubmitOnTimer;
        _status = exam.status;

        // Find matching subject ID from the loaded subjects list
        if (_subjects.isNotEmpty) {
          final match = _subjects.firstWhere((sub) => sub.name == exam.subject,
              orElse: () => _subjects.first);
          _selectedSubjectId = match.id;
        }

        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exam details: $e')),
      );
    }
  }

  String _getDropdownValue(String status) {
    final s = status.toLowerCase();
    if (s == 'scheduled' || s == 'ready') {
      return 'scheduled';
    }
    if (['new', 'in_progress', 'published', 'completed'].contains(s)) {
      return s;
    }
    return 'new';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.examId != null ? 'Edit Exam' : 'Create Online Exam',
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/teacher/exams'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Horizontal Stepper Bar
              _buildStepperIndicator(),

              // Step workspace contents
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildStepContent(),
                  ),
                ),
              ),

              // Step Navigation Action Footer
              _buildStepNavFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStepNode(0, 'Basic Info'),
          _buildStepConnector(),
          _buildStepNode(1, 'Specifications'),
          _buildStepConnector(),
          _buildStepNode(2, 'Security Lock'),
        ],
      ),
    );
  }

  Widget _buildStepNode(int index, String label) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF10B981)
                : (isActive ? const Color(0xFF6366F1) : Colors.grey.shade100),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? const Color(0xFF4338CA) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive || isDone ? Colors.white : Colors.grey,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isActive || isDone ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepBasicInfo();
      case 1:
        return _buildStepSpecs();
      case 2:
        return _buildStepSecurity();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStepBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Exam Title',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _examNameController,
          decoration: InputDecoration(
            hintText: 'e.g. Physics Mid Term Term 2',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
        ),
        const SizedBox(height: 16),
        const Text('Syllabus',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _syllabusController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'e.g. Chapters 1-4, Electromagnetism',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Instructions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _instructionsController,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'e.g. No calculator allowed, keep camera on.',
          ),
        ),
        if (widget.examId != null) ...[
          const SizedBox(height: 16),
          const Text('Exam Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _getDropdownValue(_status),
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'new', child: Text('New')),
              DropdownMenuItem(
                  value: 'in_progress', child: Text('In progress')),
              DropdownMenuItem(
                  value: 'scheduled', child: Text('Ready (Scheduled)')),
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(value: 'completed', child: Text('Completed')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _status = v;
                });
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStepSpecs() {
    // Dynamic subject lists or fallback
    final subjectNames = _subjects.map((s) => s.name).toSet().toList();
    if (subjectNames.isEmpty) {
      subjectNames.addAll(
          ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English']);
    }
    if (!subjectNames.contains(_selectedSubject)) {
      _selectedSubject = subjectNames.first;
    }

    // Dynamic class lists
    final classNames = _classes
        .map((c) {
          final section = c.section.trim();
          if (section.isEmpty || c.name.contains('-$section')) return c.name;
          return '${c.name}-$section';
        })
        .toSet()
        .toList();

    // Ensure at least one class is selected
    if (_selectedClasses.isEmpty && classNames.isNotEmpty) {
      _selectedClasses = [classNames.first];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subject',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    items: subjectNames
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedSubject = v!;
                        if (_subjects.isNotEmpty) {
                          final match = _subjects.firstWhere(
                              (sub) => sub.name == v,
                              orElse: () => _subjects.first);
                          _selectedSubjectId = match.id;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target Classes',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: classNames.map((c) {
                        final isSelected = _selectedClasses.contains(c);
                        return FilterChip(
                          label: Text(c),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedClasses.add(c);
                              } else {
                                if (_selectedClasses.length > 1) {
                                  _selectedClasses.remove(c);
                                }
                              }
                            });
                          },
                          selectedColor:
                              const Color(0xFF6366F1).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF6366F1),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF4338CA)
                                : Colors.black87,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duration (Mins)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v == null || int.tryParse(v) == null
                        ? 'Must be a valid integer'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Marks',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _totalMarksController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v == null || int.tryParse(v) == null
                        ? 'Must be a valid integer'
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exam Format',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _examType,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    items: const [
                      DropdownMenuItem(
                          value: 'online', child: Text('🖥️ Online Exam')),
                      DropdownMenuItem(
                          value: 'offline',
                          child: Text('📝 Offline Pen-Paper')),
                    ],
                    onChanged: (v) => setState(() {
                      _examType = v!;
                      if (_examType == 'online') {
                        _venueController.text = 'Online Portal';
                      } else if (_venueController.text == 'Online Portal') {
                        _venueController.text = 'Classroom 1';
                      }
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    items: [
                      'Practice Test',
                      'Weekly Test',
                      'Unit Test',
                      'Mock Test',
                      'Mid Term',
                      'Final Exam'
                    ]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_examType == 'offline') ...[
          const SizedBox(height: 16),
          const Text('Exam Location / Venue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _venueController,
            decoration: InputDecoration(
              hintText: 'e.g. Auditorium Hall, Room 10B',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => _examType == 'offline' && (v == null || v.isEmpty)
                ? 'Venue is required for offline exams'
                : null,
          ),
        ],
      ],
    );
  }

  Widget _buildStepSecurity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AI Proctoring Locks',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF4338CA))),
        const SizedBox(height: 12),
        _buildToggleTile(
            'Camera Permission Lock',
            'Student must verify and stream face camera.',
            _cameraRequired,
            (v) => setState(() => _cameraRequired = v)),
        _buildToggleTile(
            'Microphone Sound Monitor',
            'Monitor room noise parameters during exam.',
            _micRequired,
            (v) => setState(() => _micRequired = v)),
        _buildToggleTile(
            'Force Fullscreen Auto-Submit',
            'Exiting fullscreen mode counts as proctor violation.',
            _autoSubmitOnTimer,
            (v) => setState(() => _autoSubmitOnTimer = v)),
        const Divider(height: 24),
        const Text('Scoring & Presentation Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        _buildToggleTile(
            'Negative Marking',
            'Deduct marks for incorrect answers.',
            _negativeMarking,
            (v) => setState(() => _negativeMarking = v)),
        _buildToggleTile(
            'Shuffle Question Sequences',
            'Randomize order of questions per student.',
            _shuffleQuestions,
            (v) => setState(() => _shuffleQuestions = v)),
        _buildToggleTile(
            'Shuffle Option Choices',
            'Randomize choices order per question.',
            _shuffleOptions,
            (v) => setState(() => _shuffleOptions = v)),
        _buildToggleTile(
            'Calculator Widget',
            'Provide a floating calculator overlay.',
            _allowCalculator,
            (v) => setState(() => _allowCalculator = v)),
      ],
    );
  }

  Widget _buildToggleTile(
      String title, String desc, bool val, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(desc,
            style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        value: val,
        activeThumbColor: const Color(0xFF6366F1),
        contentPadding: EdgeInsets.zero,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStepNavFooter() {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == 2;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isFirst)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: _isSaving
                ? null
                : () {
                    if (_formKey.currentState!.validate()) {
                      if (!isLast) {
                        setState(() => _currentStep++);
                      } else {
                        _saveDraftAndNavigate();
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(isLast
                    ? (widget.examId != null
                        ? 'Save Changes'
                        : 'Save & Build Paper')
                    : 'Next Step'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraftAndNavigate() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final payload = {
        'title': _examNameController.text,
        'syllabus': _syllabusController.text,
        'status': _status,
        'instructions': _instructionsController.text,
        'duration_minutes': int.tryParse(_durationController.text) ?? 90,
        'total_marks': int.tryParse(_totalMarksController.text) ?? 100,
        'exam_type': _examType,
        'exam_category': _selectedType,
        'venue':
            _examType == 'online' ? 'Online Portal' : _venueController.text,
        'subject': _selectedSubject,
        'class': _selectedClasses.join(', '),
        'target_classes': _selectedClasses,
        'negative_marking': _negativeMarking,
        'shuffle_questions': _shuffleQuestions,
        'shuffle_options': _shuffleOptions,
        'allow_calculator': _allowCalculator,
        'camera_required': _cameraRequired,
        'mic_required': _micRequired,
        'auto_submit_on_timer': _autoSubmitOnTimer,
      };

      if (widget.examId != null) {
        await _apiService.updateExam(widget.examId!, payload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 Exam details updated successfully!')),
        );
        context.pushReplacement('/teacher/exams');
      } else {
        final newExam = await _apiService.createExam(
          title: _examNameController.text,
          subject: _selectedSubject,
          targetClasses: _selectedClasses,
          duration: _durationController.text,
          totalMarks: int.tryParse(_totalMarksController.text) ?? 100,
          examType: _examType,
          examCategory: _selectedType,
          syllabus: _syllabusController.text,
          roomNumber:
              _examType == 'online' ? 'Online Portal' : _venueController.text,
          status: 'draft',
          instructions: _instructionsController.text,
          negativeMarking: _negativeMarking,
          shuffleQuestions: _shuffleQuestions,
          shuffleOptions: _shuffleOptions,
          allowCalculator: _allowCalculator,
          cameraRequired: _cameraRequired,
          micRequired: _micRequired,
          autoSubmitOnTimer: _autoSubmitOnTimer,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '🎉 Exam configuration created! Proceeding to Paper Builder.')),
        );
        context.pushReplacement(
            '/teacher/exams/paper-builder?examId=${newExam.id}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving exam: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
}

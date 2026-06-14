import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';

class AssignExamScreen extends ConsumerStatefulWidget {
  final String examId;
  const AssignExamScreen({super.key, required this.examId});

  @override
  ConsumerState<AssignExamScreen> createState() => _AssignExamScreenState();
}

class _AssignExamScreenState extends ConsumerState<AssignExamScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  
  // Data loading states
  TeacherExam? _exam;
  List<TeacherMyClass> _classes = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Target Selection States
  List<String> _selectedClasses = [];
  String _selectedBatch = 'All Students';
  
  // Student selection state variables
  List<StudentDirectoryEntry> _allStudents = [];
  List<StudentDirectoryEntry> _filteredStudents = [];
  List<String> _targetedStudentIds = [];
  bool _isFetchingStudents = false;
  String _studentSearchQuery = '';
  final _studentSearchController = TextEditingController();
  
  // Visibility States
  String _visibilityMode = 'Immediate'; // Immediate, Scheduled, Hidden
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 10, minute: 0);

  // Exam Schedule
  DateTime? _examDate;
  TimeOfDay? _examStartTime;

  // Security passcode
  bool _requirePassword = false;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _apiService.getExams(),
        _apiService.getMyClasses(),
      ]);

      final exams = results[0] as List<TeacherExam>;
      _classes = results[1] as List<TeacherMyClass>;

      _exam = exams.firstWhere((e) => e.id == widget.examId);

      if (_classes.isNotEmpty) {
        if (_exam!.class_.isNotEmpty) {
          _selectedClasses = _exam!.class_.split(',').map((c) => c.trim()).toList();
        } else {
          _selectedClasses = [_classes.first.name];
        }
      } else {
        _selectedClasses = ['X-A'];
      }

      if (_exam != null) {
        _selectedBatch = _exam!.scope ?? 'All Students';
        _targetedStudentIds = (_exam!.targetStudents ?? []).map((s) => s.toString()).toList();
        if (_exam!.passcode != null && _exam!.passcode!.trim().isNotEmpty) {
          _requirePassword = true;
          _passwordController.text = _exam!.passcode!;
        } else {
          _requirePassword = false;
          _passwordController.text = '';
        }

        if (_exam!.startTime != null) {
          final localStart = _exam!.startTime!.toLocal();
          _examDate = localStart;
          _examStartTime = TimeOfDay(hour: localStart.hour, minute: localStart.minute);
        } else {
          _examDate = DateTime.now().add(const Duration(days: 1));
          _examStartTime = const TimeOfDay(hour: 9, minute: 0);
        }

        if ((_exam!.status == 'scheduled' || _exam!.status == 'ready') && _exam!.releaseTime != null) {
          _visibilityMode = 'Scheduled';
          _scheduledDate = _exam!.releaseTime!.toLocal();
          _scheduledTime = TimeOfDay.fromDateTime(_exam!.releaseTime!.toLocal());
        } else if (_exam!.status == 'published') {
          _visibilityMode = 'Immediate';
        } else {
          _visibilityMode = 'Immediate';
        }

        if (_selectedBatch != 'All Students') {
          await _fetchStudentsForSelectedClasses();
        }
      }
    } catch (e) {
      debugPrint('Error loading assignment data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchStudentsForSelectedClasses() async {
    if (_selectedClasses.isEmpty) {
      setState(() {
        _allStudents = [];
        _filteredStudents = [];
      });
      return;
    }
    setState(() {
      _isFetchingStudents = true;
    });
    try {
      final Set<String> uniqueIds = {};
      final List<StudentDirectoryEntry> combined = [];
      for (final cls in _selectedClasses) {
        try {
          final classStudents = await _apiService.getStudentsForClass(cls);
          for (final s in classStudents) {
            if (!uniqueIds.contains(s.id)) {
              uniqueIds.add(s.id);
              combined.add(s);
            }
          }
        } catch (err) {
          debugPrint('Error loading students for class $cls: $err');
        }
      }
      setState(() {
        _allStudents = combined;
        _filterStudentsList();
      });
    } catch (e) {
      debugPrint('Error fetching combined students: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingStudents = false;
        });
      }
    }
  }

  void _filterStudentsList() {
    final query = _studentSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredStudents = List.from(_allStudents);
    } else {
      _filteredStudents = _allStudents.where((s) {
        return s.name.toLowerCase().contains(query) ||
            s.rollNo.toLowerCase().contains(query);
      }).toList();
    }
  }

  Widget _buildTargetStudentsSection() {
    if (_selectedBatch == 'All Students') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Students (${_targetedStudentIds.length} selected)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (!_isFetchingStudents && _allStudents.isNotEmpty)
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _targetedStudentIds = _allStudents.map((s) => s.id).toList();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Select All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _targetedStudentIds.clear();
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _studentSearchController,
            onChanged: (v) {
              setState(() {
                _studentSearchQuery = v;
                _filterStudentsList();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by name or roll number...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
              suffixIcon: _studentSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _studentSearchController.clear();
                        setState(() {
                          _studentSearchQuery = '';
                          _filterStudentsList();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_isFetchingStudents)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
              ),
            )
          else if (_allStudents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: Colors.grey.shade400, size: 36),
                  const SizedBox(height: 8),
                  const Text(
                    'No students found in the selected class sections.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_filteredStudents.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              alignment: Alignment.center,
              child: const Text(
                'No matching students found.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filteredStudents.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final student = _filteredStudents[index];
                  final isSelected = _targetedStudentIds.contains(student.id);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                      backgroundImage: student.profileImageUrl != null
                          ? NetworkImage(student.profileImageUrl!)
                          : null,
                      child: student.profileImageUrl == null
                          ? Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF64748B),
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      'Roll No: ${student.rollNo} • Class: ${student.class_}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _targetedStudentIds.remove(student.id);
                          } else {
                            _targetedStudentIds.add(student.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              isSelected ? 'Selected' : 'Add',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    DateTime initial = _scheduledDate;
    final today = DateTime(now.year, now.month, now.day);
    final initialDateOnly = DateTime(initial.year, initial.month, initial.day);
    
    if (initialDateOnly.isBefore(today)) {
      initial = now;
    }
    
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _scheduledTime,
      );
      if (time != null) {
        setState(() {
          _scheduledDate = date;
          _scheduledTime = time;
        });
      }
    }
  }

  Future<void> _selectExamDateTime() async {
    final now = DateTime.now();
    DateTime initial = _examDate ?? now.add(const Duration(days: 1));
    final today = DateTime(now.year, now.month, now.day);
    final initialDateOnly = DateTime(initial.year, initial.month, initial.day);
    
    if (initialDateOnly.isBefore(today)) {
      initial = now.add(const Duration(days: 1));
    }
    
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _examStartTime ?? const TimeOfDay(hour: 9, minute: 0),
      );
      if (time != null) {
        setState(() {
          _examDate = date;
          _examStartTime = time;
        });
      }
    }
  }

  Future<void> _confirmAssignment() async {
    if (_selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one class section'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (_examDate == null || _examStartTime == null) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select the exam start date and time'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_selectedBatch != 'All Students' && _targetedStudentIds.isEmpty) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one student for the targeted scope'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_requirePassword && _passwordController.text.trim().isEmpty) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an exam passcode'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final String status = _visibilityMode == 'Immediate'
          ? 'published'
          : _visibilityMode == 'Scheduled'
              ? 'ready'
              : (_exam?.status ?? 'new');

      final DateTime now = DateTime.now();
      
      int durationMins = 90;
      if (_exam != null) {
        final digits = _exam!.duration.replaceAll(RegExp(r'[^0-9]'), '');
        durationMins = int.tryParse(digits) ?? 90;
      }

      final DateTime startDateTime = DateTime(
        _examDate!.year,
        _examDate!.month,
        _examDate!.day,
        _examStartTime!.hour,
        _examStartTime!.minute,
      );
      final DateTime endDateTime = startDateTime.add(Duration(minutes: durationMins));

      // Calculate release time
      DateTime? releaseDateTime;
      if (_visibilityMode == 'Scheduled') {
        releaseDateTime = DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          _scheduledTime.hour,
          _scheduledTime.minute,
        );
        if (releaseDateTime.isAfter(startDateTime) || releaseDateTime.isAtSameMomentAs(startDateTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Publish date and time must be earlier than the exam start date and time.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
      } else if (_visibilityMode == 'Immediate') {
        releaseDateTime = now;
      }

      final Map<String, dynamic> updates = {
        'status': status,
        'target_classes': _selectedClasses,
        'class': _selectedClasses.join(', '),
        'venue': _exam?.examType.toLowerCase() == 'online' ? 'Online Portal' : _exam?.roomNumber ?? 'Classroom',
        'exam_date': _examDate!.toIso8601String().split('T')[0],
        'start_time': startDateTime.toUtc().toIso8601String(),
        'end_time': endDateTime.toUtc().toIso8601String(),
        'scope': _selectedBatch,
        'passcode': _requirePassword ? _passwordController.text.trim() : null,
        'target_students': _selectedBatch == 'All Students' ? null : _targetedStudentIds,
        'release_time': releaseDateTime?.toUtc().toIso8601String(),
      };

      if (_requirePassword && _passwordController.text.trim().isNotEmpty) {
        final prefix = 'Passcode: ${_passwordController.text.trim()}\n';
        updates['instructions'] = prefix;
      }

      await _apiService.updateExam(widget.examId, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Exam successfully ${status == 'published' ? 'published' : 'scheduled'} and assigned!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        context.go('/teacher/exams');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning exam: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collect unique class names from the backend class list
    final classNames = _classes.map((c) => c.name).toSet().toList();
    if (classNames.isEmpty) {
      classNames.addAll(['IX-A', 'IX-B', 'X-A', 'X-B', 'XI-A', 'XII-A']);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assign Examination',
          style: TextStyle(
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
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step Info Box
                              _buildInfoBanner(),
                              const SizedBox(height: 20),

                              // Exam Summary Card
                              if (_exam != null) _buildExamSummaryCard(),
                              const SizedBox(height: 24),

                              // Section 1: Assignees Target
                              const Text(
                                'Assign To Target Audience',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Target Class Sections',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
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
                                              if (_selectedBatch != 'All Students') {
                                                _fetchStudentsForSelectedClasses();
                                              }
                                            },
                                            selectedColor: const Color(0xFF6366F1).withOpacity(0.18),
                                            checkmarkColor: const Color(0xFF6366F1),
                                            backgroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              side: BorderSide(
                                                color: isSelected
                                                    ? const Color(0xFF6366F1)
                                                    : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? const Color(0xFF4338CA)
                                                  : const Color(0xFF475569),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    DropdownButtonFormField<String>(
                                      value: _selectedBatch,
                                      decoration: const InputDecoration(
                                        labelText: 'Batch / Scope',
                                        labelStyle: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF64748B),
                                        ),
                                        border: UnderlineInputBorder(),
                                      ),
                                      items: ['All Students', 'Remedial Batch', 'Selective Group']
                                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedBatch = v!;
                                        });
                                        if (_selectedBatch != 'All Students') {
                                          _fetchStudentsForSelectedClasses();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              _buildTargetStudentsSection(),
                              const SizedBox(height: 24),

                              // Section 2: Access Protection Settings
                              const Text(
                                'Access Protection Settings',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      title: const Text(
                                        'Require Passcode',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Students must input a password before commencing checks.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      value: _requirePassword,
                                      activeColor: const Color(0xFF6366F1),
                                      onChanged: (v) => setState(() => _requirePassword = v),
                                    ),
                                    if (_requirePassword) ...[
                                      const SizedBox(height: 16),
                                      TextField(
                                        controller: _passwordController,
                                        decoration: InputDecoration(
                                          labelText: 'Exam Password Code',
                                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Section 3: Exam Schedule Details
                              const Text(
                                'Exam Schedule Details',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Exam Date & Start Time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: _selectExamDateTime,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.event_note,
                                              size: 16,
                                              color: Color(0xFF475569),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _examDate != null && _examStartTime != null
                                                  ? 'Exam: ${_examDate!.toString().split(' ')[0]} at ${_examStartTime!.format(context)}'
                                                  : 'Choose Exam Date & Start Time',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Divider(height: 1),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Visibility Release Schedule',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    RadioListTile<String>(
                                      title: const Text(
                                        'Immediate Release',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Available immediately for student access.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      value: 'Immediate',
                                      groupValue: _visibilityMode,
                                      activeColor: const Color(0xFF6366F1),
                                      onChanged: (v) => setState(() => _visibilityMode = v!),
                                    ),
                                    const Divider(height: 1, indent: 16, endIndent: 16),
                                    RadioListTile<String>(
                                      title: const Text(
                                        'Scheduled Release',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'Hidden until the configured calendar date.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                      value: 'Scheduled',
                                      groupValue: _visibilityMode,
                                      activeColor: const Color(0xFF6366F1),
                                      onChanged: (v) => setState(() => _visibilityMode = v!),
                                    ),
                                    if (_visibilityMode == 'Scheduled') ...[
                                      const SizedBox(height: 16),
                                      InkWell(
                                        onTap: _selectDateTime,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFC7D2FE)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_rounded,
                                                size: 16,
                                                color: Color(0xFF4338CA),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Scheduled: ${_scheduledDate.toString().split(' ')[0]} at ${_scheduledTime.format(context)}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF4338CA),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom Action bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _confirmAssignment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Publish and Schedule Exam',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isSaving)
                    Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Center(
                        child: Card(
                          margin: EdgeInsets.symmetric(horizontal: 40),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                ),
                                SizedBox(width: 20),
                                Text(
                                  'Scheduling and releasing...',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
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

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: const Row(
        children: [
          Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF4338CA)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Final Step: Assign this question paper draft to one or multiple class sections and release schedules.',
              style: TextStyle(fontSize: 12, color: Color(0xFF3730A3), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _exam!.examType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    _exam!.duration,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _exam!.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: AppFonts.heading,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Subject: ${_exam!.subject}',
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          const Divider(height: 24, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Marks: ${_exam!.totalMarks}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _exam!.examType.toLowerCase() == 'online'
                      ? const Color(0xFF10B981)
                      : Colors.orange.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _exam!.examType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_academic/shared/widgets/azure_grid.dart';

class TeacherAttendance extends ConsumerStatefulWidget {
  const TeacherAttendance({super.key});

  @override
  ConsumerState<TeacherAttendance> createState() => _TeacherAttendanceState();
}

class _TeacherAttendanceState extends ConsumerState<TeacherAttendance> {
  final TeacherApiService _apiService = TeacherApiService();

  String _selectedClass = '10A';
  List<String> _classes = [];

  List<TeacherTimetablePeriod> _allTimetablePeriods = [];
  List<TeacherTimetablePeriod> _classPeriods = [];
  TeacherTimetablePeriod? _selectedPeriod; // null means Entire Day

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _studentsData = [];
  bool _isLoading = true;
  String? _error;
  bool _isSubmitting = false;
  String _studentSearchQuery = '';

  String _classLabel(TeacherMyClass c) {
    final section = c.section.trim();
    if (section.isEmpty || c.name.contains('-$section')) return c.name;
    return '${c.name}-$section';
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch teacher classes
      final classes = await _apiService.getMyClasses();
      setState(() {
        _classes = classes.map(_classLabel).toSet().toList();
        if (_classes.isNotEmpty) {
          _selectedClass = _classes.first;
        }
      });

      // 2. Fetch timetable slots for selected date
      await _loadTimetable();

      // 3. Fetch students & existing attendance
      await _fetchStudentsAndAttendance();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTimetable() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final slots = await _apiService.getTimetable(date: dateStr);
      setState(() {
        _allTimetablePeriods = slots;
        _filterPeriodsForClass();
      });
    } catch (_) {
      setState(() {
        _allTimetablePeriods = [];
        _classPeriods = [];
        _selectedPeriod = null;
      });
    }
  }

  void _filterPeriodsForClass() {
    final classLower = _selectedClass.toLowerCase().trim();
    _classPeriods = _allTimetablePeriods.where((p) {
      final slotClassLower = p.class_.toLowerCase().trim();
      return slotClassLower == classLower ||
          slotClassLower.replaceAll('-', '') == classLower.replaceAll('-', '');
    }).toList();

    _classPeriods.sort((a, b) => a.startTime.compareTo(b.startTime));

    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) ==
        DateFormat('yyyy-MM-dd').format(_selectedDate);
    if (isToday) {
      _selectedPeriod = _getCurrentActivePeriod();
    } else {
      _selectedPeriod = null;
    }
  }

  String _normalizeTimeStr(String t) {
    final parts = t.split(':');
    if (parts.isEmpty) return '00:00:00';
    final h = parts[0].padLeft(2, '0');
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final s = parts.length > 2 ? parts[2].padLeft(2, '0') : '00';
    return '$h:$m:$s';
  }

  TeacherTimetablePeriod? _getCurrentActivePeriod() {
    final now = DateTime.now();
    final nowTimeStr = DateFormat('HH:mm:ss').format(now);
    for (final p in _classPeriods) {
      final start = _normalizeTimeStr(p.startTime);
      final end = _normalizeTimeStr(p.endTime);
      if (nowTimeStr.compareTo(start) >= 0 && nowTimeStr.compareTo(end) <= 0) {
        return p;
      }
    }
    return null;
  }

  Future<void> _fetchStudentsAndAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final subjectId = _selectedPeriod?.subjectId;

      final records = await _apiService.fetchAttendance(
        classId: _selectedClass,
        date: dateStr,
        subjectId: subjectId,
      );

      setState(() {
        _studentsData = records.map((e) {
          // Preserve null status as 'unmarked' so refresh shows correct saved state
          return {
            'student_id': e['student_id'],
            'name': e['name'],
            'roll_no': e['roll_no'] ?? '',
            'status':
                e['status'] ?? 'unmarked', // 'unmarked' = not yet set in DB
            'remarks': e['remarks'] ?? '',
            'avatar_url': e['avatar_url'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onClassChanged(String newClass) async {
    setState(() {
      _selectedClass = newClass;
    });
    _filterPeriodsForClass();
    await _fetchStudentsAndAttendance();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0EA5E9),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadTimetable();
      await _fetchStudentsAndAttendance();
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var s in _studentsData) {
        s['status'] = status;
      }
    });
  }

  Future<void> _submitAttendance() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final subjectId = _selectedPeriod?.subjectId;

      final recordsToSend = _studentsData.map((s) {
        // If teacher never touched a student, default their status to 'present'
        final effectiveStatus =
            (s['status'] == 'unmarked') ? 'present' : s['status'];
        return {
          'student_id': s['student_id'],
          'status': effectiveStatus,
          'remarks': s['remarks'].toString().isEmpty ? null : s['remarks'],
        };
      }).toList();

      await _apiService.markAttendance(
        classId: _selectedClass,
        date: dateStr,
        subjectId: subjectId,
        attendanceRecords: recordsToSend,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Attendance saved successfully!'.tr(ref)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving attendance: $e'),
            backgroundColor: const Color(0xFFF43F5E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showRemarksDialog(Map<String, dynamic> student) {
    final controller = TextEditingController(text: student['remarks'] ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Remarks for ${student['name']}',
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'e.g. Late due to transport, Sick leave, etc.',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  student['remarks'] = controller.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeStr(String timeStr) {
    if (timeStr.isEmpty) return '';
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1];
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$displayHour:$minute $ampm';
    }
    return timeStr;
  }

  TeacherTimetablePeriod? getDropdownValue() {
    if (_selectedPeriod == null) return null;
    for (final p in _classPeriods) {
      if (p.id == _selectedPeriod!.id ||
          (p.startTime == _selectedPeriod!.startTime &&
              p.endTime == _selectedPeriod!.endTime)) {
        return p;
      }
    }
    return null;
  }

  List<DropdownMenuItem<TeacherTimetablePeriod?>> _buildDropdownItems() {
    final items = <DropdownMenuItem<TeacherTimetablePeriod?>>[];
    items.add(const DropdownMenuItem<TeacherTimetablePeriod?>(
      value: null,
      child: Text('Entire Day'),
    ));
    for (final p in _classPeriods) {
      items.add(DropdownMenuItem<TeacherTimetablePeriod?>(
        value: p,
        child: Text(
          '${_formatTimeStr(p.startTime)} - ${_formatTimeStr(p.endTime)}: ${p.subject} (P${p.periodNumber})',
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final presents =
        _studentsData.where((s) => s['status'] == 'present').length;
    final absents = _studentsData.where((s) => s['status'] == 'absent').length;
    final lates = _studentsData.where((s) => s['status'] == 'late').length;
    final voids = _studentsData.where((s) => s['status'] == 'void').length;
    final total = _studentsData.length;
    final pct = total > 0 ? (((presents + lates) / total) * 100).toInt() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Premium warm white background
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 950;

          if (_isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9)));
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Color(0xFFF43F5E)),
                  const SizedBox(height: 16),
                  Text('Error: $_error',
                      style: const TextStyle(color: Color(0xFFF43F5E))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInitialData,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9)),
                    child: Text('Retry'.tr(ref)),
                  ),
                ],
              ),
            );
          }

          return isDesktop
              ? _buildDesktopLayout(
                  context, pct, presents, absents, lates, voids)
              : _buildMobileLayout(
                  context, pct, presents, absents, lates, voids);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, int pct, int presents,
      int absents, int lates, int voids) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel - Settings, Stats, Save Button
        Container(
          width: 340,
          decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                )
              ]),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button & Title
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Color(0xFF0F172A), size: 18),
                        onPressed: () =>
                            safeGoBack(context, '/teacher/dashboard'),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Attendance Hub',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date Picker Card
                  const Text(
                    'DATE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Color(0xFF0EA5E9), size: 18),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy')
                                .format(_selectedDate),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Class Selector Wrap
                  const Text(
                    'CLASS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _classes.map((cls) {
                      final isSelected = _selectedClass == cls;
                      return GestureDetector(
                        onTap: () => _onClassChanged(cls),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0EA5E9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            cls,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Smart Dropdown Selector
                  const Text(
                    'ATTENDANCE PERIOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TeacherTimetablePeriod?>(
                        value: getDropdownValue(),
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF0F172A)),
                        dropdownColor: Colors.white,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedPeriod = newValue;
                          });
                          _fetchStudentsAndAttendance();
                        },
                        items: _buildDropdownItems(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),

                  // Stats Section
                  const Text(
                    'LIVE STATS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Overall score:',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat('Present', presents, Colors.green),
                            _buildMiniStat('Absent', absents, Colors.red),
                            _buildMiniStat('Late', lates, Colors.orange),
                            _buildMiniStat('Void', voids, Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickActionBtn('All Present', Colors.green,
                          () => _markAll('present')),
                      _buildQuickActionBtn(
                          'All Absent', Colors.red, () => _markAll('absent')),
                      _buildQuickActionBtn(
                          'All Void', Colors.grey, () => _markAll('void')),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAttendance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Records',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right Panel - AzureGrid Table
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AzureGrid<Map<String, dynamic>>(
              title: 'Student Roster',
              items: _studentsData,
              columns: _buildGridColumns(),
              searchMatcher: (s) => '${s['name']} ${s['roll_no']}',
              onRefresh: _fetchStudentsAndAttendance,
              mobileCardBuilder: (context, s) => _buildStudentCard(s, compact: false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, int pct, int presents,
      int absents, int lates, int voids) {
    final filteredStudents = _studentsData.where((s) {
      if (_studentSearchQuery.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final roll = (s['roll_no'] ?? '').toString().toLowerCase();
      return name.contains(_studentSearchQuery.toLowerCase()) ||
          roll.contains(_studentSearchQuery.toLowerCase());
    }).toList();

    // Build the collapsible header content
    final header = _buildMobileHeader(context);
    final statsRow = _buildMobileStatsRow(presents, absents, lates, voids, pct);
    final classChips = _classes.isNotEmpty
        ? _buildMobileClassChips()
        : const SizedBox.shrink();
    final quickActions = _buildMobileQuickActions();
    final searchBar = _buildMobileSearchBar();

    return CustomScrollView(
      slivers: [
        // Collapsible gradient header
        SliverAppBar(
          expandedHeight: 160,
          floating: false,
          pinned: true,
          snap: false,
          backgroundColor: const Color(0xFF0369A1),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: header,
          ),
          // Collapsed app bar title row (visible when scrolled)
          title: Row(
            children: [
              GestureDetector(
                onTap: () => safeGoBack(context, '/teacher/dashboard'),
                child: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Attendance Hub',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _fetchStudentsAndAttendance,
                child: const Icon(Icons.refresh, color: Colors.white, size: 22),
              ),
            ],
          ),
          titleSpacing: 12,
        ),

        // Body content as sliver list
        SliverToBoxAdapter(
          child: Column(
            children: [
              classChips,
              const SizedBox(height: 4),
              statsRow,
              quickActions,
              searchBar,
            ],
          ),
        ),

        // Student list
        filteredStudents.isEmpty
            ? const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No students found',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        index == 0 ? 4 : 0,
                        16,
                        index == filteredStudents.length - 1 ? 4 : 0,
                      ),
                      child: _buildStudentCard(filteredStudents[index],
                          compact: false),
                    );
                  },
                  childCount: filteredStudents.length,
                ),
              ),

        // Save button + bottom padding (above bottom nav)
        SliverToBoxAdapter(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Attendance Records',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 20),
                onPressed: () => safeGoBack(context, '/teacher/dashboard'),
              ),
              const Text(
                'Attendance Hub',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _fetchStudentsAndAttendance,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Date & Period Picker Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 9)),
                              Text(
                                DateFormat('EEE, MMM d').format(_selectedDate),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 24, width: 1, color: Colors.white24),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      const Icon(Icons.track_changes,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Period / Slot',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 9)),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<TeacherTimetablePeriod?>(
                                value: getDropdownValue(),
                                dropdownColor: const Color(0xFF0369A1),
                                icon: const Icon(Icons.keyboard_arrow_down,
                                    color: Colors.white),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                isExpanded: true,
                                onChanged: (newValue) {
                                  setState(() => _selectedPeriod = newValue);
                                  _fetchStudentsAndAttendance();
                                },
                                items: _buildDropdownItems(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileClassChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _classes.length,
          itemBuilder: (context, index) {
            final cls = _classes[index];
            final isSelected = _selectedClass == cls;
            return GestureDetector(
              onTap: () => _onClassChanged(cls),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0EA5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  cls,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF0369A1),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileStatsRow(
      int presents, int absents, int lates, int voids, int pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMiniStat('Present', presents, Colors.green),
            _buildMiniStat('Absent', absents, Colors.red),
            _buildMiniStat('Late', lates, Colors.orange),
            _buildMiniStat('Void', voids, Colors.grey),
            Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
            Column(
              children: [
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text('Attendance',
                    style: TextStyle(color: Colors.grey, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => _markAll('present'),
            icon: const Icon(Icons.check, size: 14, color: Colors.green),
            label: const Text('All Present',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () => _markAll('absent'),
            icon: const Icon(Icons.close, size: 14, color: Colors.red),
            label: const Text('All Absent',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () => _markAll('void'),
            icon: const Icon(Icons.block, size: 14, color: Colors.grey),
            label: const Text('All Void',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: SizedBox(
        height: 40,
        child: TextField(
          onChanged: (val) {
            setState(() => _studentSearchQuery = val);
          },
          decoration: InputDecoration(
            hintText: 'Search student...',
            prefixIcon:
                const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  List<AzureGridColumn<Map<String, dynamic>>> _buildGridColumns() {
    return [
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Roll No',
        width: 80.0,
        compare: (a, b) => (a['roll_no'] ?? '').toString().compareTo((b['roll_no'] ?? '').toString()),
        cellBuilder: (s) => Text(s['roll_no'] ?? ''),
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Student Name',
        width: 200.0,
        compare: (a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()),
        cellBuilder: (s) {
          final isUnmarked = s['status'] == 'unmarked';
          return Text(
            s['name'] ?? '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUnmarked ? Colors.orange.shade700 : const Color(0xFF0F172A),
            ),
          );
        },
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Attendance Status',
        width: 180.0,
        compare: (a, b) => (a['status'] ?? '').toString().compareTo((b['status'] ?? '').toString()),
        cellBuilder: (s) => Row(
          children: [
            _buildStatusButton('present', 'P', Colors.green, s['status'] == 'present', s, true),
            const SizedBox(width: 4),
            _buildStatusButton('absent', 'A', Colors.red, s['status'] == 'absent', s, true),
            const SizedBox(width: 4),
            _buildStatusButton('late', 'L', Colors.orange, s['status'] == 'late', s, true),
            const SizedBox(width: 4),
            _buildStatusButton('void', 'V', Colors.grey, s['status'] == 'void', s, true),
          ],
        ),
      ),
      AzureGridColumn<Map<String, dynamic>>(
        label: 'Remarks',
        width: 220.0,
        cellBuilder: (s) => Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                size: 14,
                color: s['remarks'].toString().isNotEmpty ? const Color(0xFF0EA5E9) : Colors.grey,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _showRemarksDialog(s),
              tooltip: 'Edit Remarks',
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s['remarks'] ?? '',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildStudentCard(Map<String, dynamic> student,
      {bool compact = false}) {
    final status = student['status'] ?? 'unmarked';
    final hasRemarks = student['remarks'].toString().isNotEmpty;
    final isUnmarked = status == 'unmarked';

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: isUnmarked ? const Color(0xFFFFF8F0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnmarked ? const Color(0xFFFFD0A0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Roll No badge
          Container(
            width: compact ? 26 : 30,
            height: compact ? 26 : 30,
            decoration: BoxDecoration(
              color: isUnmarked
                  ? const Color(0xFFFF9500).withValues(alpha: 0.12)
                  : const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                student['roll_no'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isUnmarked
                      ? const Color(0xFFFF9500)
                      : const Color(0xFF0EA5E9),
                  fontSize: compact ? 11 : 12,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 12),

          // Name and optional remarks badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  student['name'] ?? '',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isUnmarked)
                  Text(
                    'Tap to mark',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.orange.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (hasRemarks) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 9, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          student['remarks'],
                          style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 9,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Remarks icon button
          IconButton(
            icon: Icon(
              Icons.chat_bubble_outline,
              size: compact ? 16 : 18,
              color: hasRemarks ? const Color(0xFF0EA5E9) : Colors.grey,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _showRemarksDialog(student),
          ),
          SizedBox(width: compact ? 8 : 12),

          // Status Button Group (P, A, L, V)
          Row(
            children: [
              _buildStatusButton('present', 'P', Colors.green,
                  status == 'present', student, compact),
              const SizedBox(width: 3),
              _buildStatusButton('absent', 'A', Colors.red, status == 'absent',
                  student, compact),
              const SizedBox(width: 3),
              _buildStatusButton('late', 'L', Colors.orange, status == 'late',
                  student, compact),
              const SizedBox(width: 3),
              _buildStatusButton(
                  'void', 'V', Colors.grey, status == 'void', student, compact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String statusKey, String label, Color color,
      bool isSelected, Map<String, dynamic> student, bool compact) {
    final double size = compact ? 22 : 26;
    return GestureDetector(
      onTap: () {
        setState(() {
          student['status'] = statusKey;
        });
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 4 : 6),
          border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : color.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 11,
            ),
          ),
        ),
      ),
    );
  }
}

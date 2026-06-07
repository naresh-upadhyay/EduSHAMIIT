import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherStudentDirectory extends ConsumerStatefulWidget {
  const TeacherStudentDirectory({super.key});

  @override
  ConsumerState<TeacherStudentDirectory> createState() =>
      _TeacherStudentDirectoryState();
}

class _TeacherStudentDirectoryState
    extends ConsumerState<TeacherStudentDirectory> {
  final TeacherApiService _apiService = TeacherApiService();

  String _selectedClass = 'All';
  List<String> _classes = ['All'];
  Map<String, int> _classCounts = {};
  List<StudentDirectoryEntry> _allStudents = [];
  List<StudentDirectoryEntry> _students = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  String _classLabel(TeacherMyClass c) {
    final section = c.section.trim();
    if (section.isEmpty || c.name.contains('-$section')) return c.name;
    return '${c.name}-$section';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load classes
      final classes = await _apiService.getMyClasses();
      final Map<String, int> counts = {};
      int total = 0;
      for (final c in classes) {
        final label = _classLabel(c);
        counts[label] = (counts[label] ?? 0) + c.studentCount;
        total += c.studentCount;
      }
      counts['All'] = total;

      setState(() {
        _classes = ['All', ...counts.keys.where((k) => k != 'All')];
        _classCounts = counts;
      });

      // Load students
      await _loadStudents();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final search =
          _searchController.text.isEmpty ? null : _searchController.text;
      final students = await _apiService.getStudentDirectory(
        classId: null,
        search: search,
      );

      final Map<String, int> counts = {for (final c in _classes) c: 0};
      for (final s in students) {
        final classLabel = s.class_;
        if (counts.containsKey(classLabel)) {
          counts[classLabel] = counts[classLabel]! + 1;
        } else {
          final normalizedLabel =
              classLabel.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
          String? matchedKey;
          for (final key in counts.keys) {
            final normalizedKey =
                key.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
            if (normalizedKey == normalizedLabel) {
              matchedKey = key;
              break;
            }
          }
          if (matchedKey != null) {
            counts[matchedKey] = counts[matchedKey]! + 1;
          }
        }
      }
      counts['All'] = students.length;

      setState(() {
        _allStudents = students;
        _classCounts = counts;
        if (_selectedClass == 'All') {
          _students = students;
        } else {
          _students = students.where((s) {
            if (s.class_ == _selectedClass) return true;
            final normalizedS =
                s.class_.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
            final normalizedSel =
                _selectedClass.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
            return normalizedS == normalizedSel;
          }).toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getGradeString(double? avgMarks) {
    if (avgMarks == null || avgMarks == 0.0) return 'N/A';
    if (avgMarks >= 90) return 'A+ (${avgMarks.toStringAsFixed(1)}%)';
    if (avgMarks >= 80) return 'A (${avgMarks.toStringAsFixed(1)}%)';
    if (avgMarks >= 70) return 'B+ (${avgMarks.toStringAsFixed(1)}%)';
    if (avgMarks >= 60) return 'B (${avgMarks.toStringAsFixed(1)}%)';
    if (avgMarks >= 50) return 'C (${avgMarks.toStringAsFixed(1)}%)';
    if (avgMarks >= 40) return 'D (${avgMarks.toStringAsFixed(1)}%)';
    return 'F (${avgMarks.toStringAsFixed(1)}%)';
  }

  LinearGradient _getAvatarGradient(int index) {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[index % gradients.length];
  }

  Future<void> _makePhoneCall(StudentDirectoryEntry student) async {
    final phone = student.phone ?? student.parentPhone;
    if (phone == null || phone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No phone number available for this student or parent.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');

    try {
      if (!await launchUrl(uri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch dialer for number: $phone'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making phone call: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showStudentProfile(StudentDirectoryEntry student, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final avatarGrad = _getAvatarGradient(index);
        final initials = student.name
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join();
        final isWarning = (student.avgMarks != null &&
                student.avgMarks! > 0.0 &&
                student.avgMarks! < 50.0) ||
            (student.attendancePct != null &&
                student.attendancePct! > 0.0 &&
                student.attendancePct! < 75.0);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Avatar & Name Info
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: avatarGrad,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: AppFonts.heading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name + (isWarning ? ' ⚠️' : ''),
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Class ${student.class_} · Roll ${student.rollNo} · ${student.avgMarks?.toStringAsFixed(0) ?? '0'}% Avg',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Call & Message buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _makePhoneCall(student);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0F2FE),
                        foregroundColor: const Color(0xFF0369A1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '📞 Call',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context
                            .push('/teacher/messaging?chat_id=${student.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFECFDF5),
                        foregroundColor: const Color(0xFF047857),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '💬 Message',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Performance Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STUDENT PERFORMANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPerformanceRow(
                      'Current Grade',
                      _getGradeString(student.avgMarks),
                      valueColor: (student.avgMarks ?? 0) >= 50.0
                          ? const Color(0xFF059669)
                          : const Color(0xFFEF4444),
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildPerformanceRow(
                      'Attendance',
                      student.attendancePct != null
                          ? '${student.attendancePct!.toStringAsFixed(0)}%'
                          : '0%',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildPerformanceRow(
                      'Class Rank',
                      '#${student.classRank ?? 1} of ${student.classTotal ?? 18}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Close button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF92400E), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () =>
                          safeGoBack(context, '/teacher/dashboard'),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Student Directory',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_students.length} Students',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: '🔍 Search students by name, roll no...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => _loadStudents(),
              ),
            ),
          ),

          // Class filter chips
          if (_classes.length > 1)
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final class_ = _classes[index];
                  final isSelected = _selectedClass == class_;
                  final count = _classCounts[class_] ?? 0;
                  final displayLabel = "$class_ ($count)";

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedClass = class_;
                        if (_selectedClass == 'All') {
                          _students = _allStudents;
                        } else {
                          _students = _allStudents.where((s) {
                            if (s.class_ == _selectedClass) return true;
                            final normalizedS = s.class_
                                .replaceAll(RegExp(r'[\s-]'), '')
                                .toLowerCase();
                            final normalizedSel = _selectedClass
                                .replaceAll(RegExp(r'[\s-]'), '')
                                .toLowerCase();
                            return normalizedS == normalizedSel;
                          }).toList();
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD97706)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFDE68A), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(
                  child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFD97706)))),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error',
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Retry'.tr(ref)),
                    ),
                  ],
                ),
              ),
            ),

          // Students list
          if (!_isLoading && _error == null)
            Expanded(
              child: _students.isEmpty
                  ? Center(
                      child: Text(
                        'No students found'.tr(ref),
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        return _buildStudentTile(_students[index], index);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentDirectoryEntry student, int index) {
    final avatarGrad = _getAvatarGradient(index);
    final initials = student.name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join();

    // Warning state: average score < 50% or attendance < 75%
    // If the stats are 0, they might not be set or loaded yet, let's treat average marks > 0 and < 50 or attendance > 0 and < 75
    // But wait, the mockup has Sanjay Mehta with 42% avg. Let's make the warning trigger whenever they are strictly below 50 / 75
    final isWarning = (student.avgMarks != null &&
            student.avgMarks! > 0.0 &&
            student.avgMarks! < 50.0) ||
        (student.attendancePct != null &&
            student.attendancePct! > 0.0 &&
            student.attendancePct! < 75.0);

    return GestureDetector(
      onTap: () => _showStudentProfile(student, index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isWarning ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isWarning ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: avatarGrad,
              ),
              alignment: Alignment.center,
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppFonts.heading,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name + (isWarning ? ' ⚠️' : ''),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${student.class_} · Roll ${student.rollNo} · ${student.avgMarks?.toStringAsFixed(0) ?? '0'}% Avg',
                    style: TextStyle(
                      fontSize: 10,
                      color: isWarning
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF94A3B8),
                      fontWeight:
                          isWarning ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Call
                GestureDetector(
                  onTap: () {
                    _makePhoneCall(student);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isWarning
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '📞',
                      style: TextStyle(
                        fontSize: 14,
                        color: isWarning
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Message
                GestureDetector(
                  onTap: () {
                    context.push('/teacher/messaging?chat_id=${student.id}');
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '💬',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

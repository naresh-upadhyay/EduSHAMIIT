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
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class TeacherStudentDirectory extends ConsumerStatefulWidget {
  const TeacherStudentDirectory({super.key});

  @override
  ConsumerState<TeacherStudentDirectory> createState() =>
      _TeacherStudentDirectoryState();
}

class _TeacherStudentDirectoryState
    extends ConsumerState<TeacherStudentDirectory> {
  final TeacherApiService _apiService = TeacherApiService();

  List<String> _classes = [];
  List<StudentDirectoryEntry> _allStudents = [];
  bool _isLoading = true;
  String? _error;

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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load classes
      final classes = await _apiService.getMyClasses();
      final loadedClasses = classes.map((c) => _classLabel(c)).toSet().toList();

      setState(() {
        _classes = loadedClasses;
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
      final students = await _apiService.getStudentDirectory(
        classId: null,
        search: null,
        limit: 500,
      );

      setState(() {
        _allStudents = students;
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

  List<AzureGridColumn<StudentDirectoryEntry>> _buildGridColumns() {
    return [
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Roll No',
        width: 80.0,
        compare: (a, b) => a.rollNo.compareTo(b.rollNo),
        cellBuilder: (s) => Text(s.rollNo),
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Student Name',
        width: 180.0,
        compare: (a, b) => a.name.compareTo(b.name),
        cellBuilder: (s) {
          final isWarning = (s.avgMarks != null && s.avgMarks! > 0.0 && s.avgMarks! < 50.0) ||
              (s.attendancePct != null && s.attendancePct! > 0.0 && s.attendancePct! < 75.0);
          return Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFFFEF3C7),
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : '',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name + (isWarning ? ' ⚠️' : ''),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Class',
        width: 90.0,
        compare: (a, b) => a.class_.compareTo(b.class_),
        cellBuilder: (s) => Text(s.class_),
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Email',
        width: 160.0,
        cellBuilder: (s) => Text(s.email ?? 'N/A'),
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Phone',
        width: 110.0,
        cellBuilder: (s) => Text(s.phone ?? s.parentPhone ?? 'N/A'),
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Parent Name',
        width: 120.0,
        cellBuilder: (s) => Text(s.parentName ?? 'N/A'),
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Avg Marks',
        width: 90.0,
        compare: (a, b) => (a.avgMarks ?? 0.0).compareTo(b.avgMarks ?? 0.0),
        cellBuilder: (s) {
          final grade = _getGradeString(s.avgMarks);
          final isWarning = s.avgMarks != null && s.avgMarks! > 0.0 && s.avgMarks! < 50.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isWarning ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              grade,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isWarning ? const Color(0xFFEF4444) : const Color(0xFF059669),
              ),
            ),
          );
        },
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Attendance',
        width: 90.0,
        compare: (a, b) => (a.attendancePct ?? 0.0).compareTo(b.attendancePct ?? 0.0),
        cellBuilder: (s) {
          final pct = s.attendancePct != null ? '${s.attendancePct!.toStringAsFixed(0)}%' : '0%';
          final isWarning = s.attendancePct != null && s.attendancePct! > 0.0 && s.attendancePct! < 75.0;
          return Text(
            pct,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWarning ? const Color(0xFFEF4444) : const Color(0xFF059669),
            ),
          );
        },
      ),
      AzureGridColumn<StudentDirectoryEntry>(
        label: 'Actions',
        width: 110.0,
        cellBuilder: (s) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, size: 14, color: Colors.blue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _makePhoneCall(s),
              tooltip: 'Call Student/Parent',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.message, size: 14, color: Colors.green),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => context.push('/teacher/messaging?chat_id=${s.id}'),
              tooltip: 'Message Student',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.account_circle, size: 14, color: Colors.orange),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                final idx = _allStudents.indexOf(s);
                _showStudentProfile(s, idx >= 0 ? idx : 0);
              },
              tooltip: 'View Profile',
            ),
          ],
        ),
      ),
    ];
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
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
              ],
            ),
          ),

          // Main content using AzureGrid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
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
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: AzureGrid<StudentDirectoryEntry>(
                          title: 'Directory Records',
                          items: _allStudents,
                          columns: _buildGridColumns(),
                          searchMatcher: (s) => '${s.name} ${s.rollNo} ${s.email ?? ""} ${s.phone ?? ""} ${s.parentName ?? ""}',
                          filters: [
                            if (_classes.isNotEmpty)
                              AzureGridFilter<StudentDirectoryEntry>(
                                label: 'Class',
                                options: _classes,
                                filterFn: (s, option) {
                                  if (s.class_ == option) return true;
                                  final normalizedS = s.class_.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
                                  final normalizedSel = option.replaceAll(RegExp(r'[\s-]'), '').toLowerCase();
                                  return normalizedS == normalizedSel;
                                },
                              ),
                            AzureGridFilter<StudentDirectoryEntry>(
                              label: 'Performance',
                              options: ['Good Standing', 'Warning Status'],
                              filterFn: (s, option) {
                                final isWarning = (s.avgMarks != null && s.avgMarks! > 0.0 && s.avgMarks! < 50.0) ||
                                    (s.attendancePct != null && s.attendancePct! > 0.0 && s.attendancePct! < 75.0);
                                if (option == 'Warning Status') return isWarning;
                                return !isWarning;
                              },
                            ),
                          ],
                          onRefresh: _loadStudents,
                          mobileCardBuilder: (context, student) {
                            final index = _allStudents.indexOf(student);
                            return _buildStudentTile(student, index >= 0 ? index : 0);
                          },
                        ),
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

    final isWarning = (student.avgMarks != null &&
            student.avgMarks! > 0.0 &&
            student.avgMarks! < 50.0) ||
        (student.attendancePct != null &&
            student.attendancePct! > 0.0 &&
            student.attendancePct! < 75.0);

    return GestureDetector(
      onTap: () => _showStudentProfile(student, index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isWarning ? const Color(0xFFFEF2F2) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isWarning ? const Color(0xFFFECACA) : const Color(0xFFF1F5F9),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _makePhoneCall(student),
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
                GestureDetector(
                  onTap: () => context.push('/teacher/messaging?chat_id=${student.id}'),
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

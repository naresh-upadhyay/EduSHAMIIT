import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class TeacherGradebook extends ConsumerStatefulWidget {
  const TeacherGradebook({super.key});

  @override
  ConsumerState<TeacherGradebook> createState() => _TeacherGradebookState();
}

class _TeacherGradebookState extends ConsumerState<TeacherGradebook> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedClass = 'X-A';
  String _selectedAssessment = 'All';
  List<String> _classes = [];
  final List<String> _assessments = ['All', 'Term 1', 'Term 2', 'Unit Test 1', 'Unit Test 2'];
  List<GradeRecord> _grades = [];
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
      setState(() {
        _classes = classes.map(_classLabel).toSet().toList();
        if (_classes.isNotEmpty && !_classes.contains(_selectedClass)) {
          _selectedClass = _classes.first;
        }
      });

      // Load grades
      await _loadGrades();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final assessmentType = _selectedAssessment == 'All' ? null : _selectedAssessment;
      final grades = await _apiService.getGradeRecords(
        classId: _selectedClass,
        assessmentType: assessmentType,
      );
      setState(() {
        _grades = grades;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double get _averageMarks {
    if (_grades.isEmpty) return 0.0;
    return _grades.fold<double>(0, (sum, g) => sum + g.marksObtained) / _grades.length;
  }

  String get _averageGrade {
    final avg = _averageMarks;
    if (avg >= 90) return 'A1';
    if (avg >= 80) return 'A1';
    if (avg >= 70) return 'A2';
    if (avg >= 60) return 'B1';
    if (avg >= 50) return 'B2';
    if (avg >= 40) return 'C1';
    return 'C2';
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return Colors.green;
    if (grade.startsWith('B')) return const Color(0xFF3B82F6);
    if (grade.startsWith('C')) return const Color(0xFFF59E0B);
    return Colors.red;
  }

  List<AzureGridColumn<GradeRecord>> _buildGridColumns() {
    return [
      AzureGridColumn<GradeRecord>(
        label: 'Roll No',
        width: 80.0,
        compare: (a, b) => a.rollNo.compareTo(b.rollNo),
        cellBuilder: (g) => Text(g.rollNo),
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Student Name',
        width: 180.0,
        compare: (a, b) => a.studentName.compareTo(b.studentName),
        cellBuilder: (g) => Text(g.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Subject',
        width: 120.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (g) => Text(g.subject),
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Class',
        width: 80.0,
        compare: (a, b) => a.class_.compareTo(b.class_),
        cellBuilder: (g) => Text(g.class_),
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Assessment',
        width: 130.0,
        compare: (a, b) => a.assessmentName.compareTo(b.assessmentName),
        cellBuilder: (g) => Text(g.assessmentName),
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Marks Obtained',
        width: 120.0,
        compare: (a, b) => a.marksObtained.compareTo(b.marksObtained),
        cellBuilder: (g) => Text('${g.marksObtained.toInt()} / ${g.totalMarks}'),
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Grade',
        width: 80.0,
        compare: (a, b) => a.grade.compareTo(b.grade),
        cellBuilder: (g) {
          final color = _getGradeColor(g.grade);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              g.grade,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          );
        },
      ),
      AzureGridColumn<GradeRecord>(
        label: 'Trend',
        width: 100.0,
        compare: (a, b) => a.trend.compareTo(b.trend),
        cellBuilder: (g) {
          final t = g.trend;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                t == 'up' ? Icons.trending_up : t == 'down' ? Icons.trending_down : Icons.remove,
                size: 14,
                color: t == 'up' ? Colors.green : t == 'down' ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                t == 'up' ? 'Improving' : t == 'down' ? 'Declining' : 'Stable',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: t == 'up' ? Colors.green : t == 'down' ? Colors.red : Colors.grey,
                ),
              ),
            ],
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Gradebook',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Filters
          if (_classes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildDropdown('Class', _selectedClass, _classes, (value) {
                      setState(() => _selectedClass = value!);
                      _loadGrades();
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown('Assessment', _selectedAssessment, _assessments, (value) {
                      setState(() => _selectedAssessment = value!);
                      _loadGrades();
                    }),
                  ),
                ],
              ),
            ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: Text('Retry'.tr(ref)),
                    ),
                  ],
                ),
              ),
            ),

          // Stats overview and student list
          if (!_isLoading && _error == null && _grades.isNotEmpty)
            ...[
              // Stats overview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildStatChip('Average', '${_averageMarks.toInt()}%', Colors.blue)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatChip('Grade', _averageGrade, _getGradeColor(_averageGrade))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatChip('Students', '${_grades.length}', Colors.purple)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Student grades list
              Expanded(
                child: Responsive.isWide(context)
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: AzureGrid<GradeRecord>(
                          title: 'Gradebook Roster',
                          items: _grades,
                          columns: _buildGridColumns(),
                          searchMatcher: (grade) => '${grade.studentName} ${grade.rollNo} ${grade.grade} ${grade.subject}',
                          onRefresh: _loadGrades,
                          mobileCardBuilder: (context, grade) => _buildStudentGradeTile(grade),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _grades.length,
                        itemBuilder: (context, index) {
                          return _buildStudentGradeTile(_grades[index]);
                        },
                      ),
              ),
            ],

          // Empty state
          if (!_isLoading && _error == null && _grades.isEmpty)
            Expanded(
              child: Center(
                child: Text('No grades found for this selection'.tr(ref)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGradeTile(GradeRecord grade) {
    final gradeColor = _getGradeColor(grade.grade);
    final trend = grade.trend;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Roll number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                grade.rollNo,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grade.studentName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      trend == 'up' ? Icons.trending_up : trend == 'down' ? Icons.trending_down : Icons.remove,
                      size: 12,
                      color: trend == 'up' ? Colors.green : trend == 'down' ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend == 'up' ? 'Improving' : trend == 'down' ? 'Declining' : 'Stable',
                      style: TextStyle(
                        fontSize: 10,
                        color: trend == 'up' ? Colors.green : trend == 'down' ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Marks
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${grade.marksObtained.toInt()}%',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grade.grade,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: gradeColor,
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

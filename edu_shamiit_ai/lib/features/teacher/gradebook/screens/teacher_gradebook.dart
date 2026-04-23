import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherGradebook extends StatefulWidget {
  const TeacherGradebook({super.key});

  @override
  State<TeacherGradebook> createState() => _TeacherGradebookState();
}

class _TeacherGradebookState extends State<TeacherGradebook> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
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
                      child: const Text('Retry'),
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
                child: ListView.builder(
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
            const Expanded(
              child: Center(
                child: Text('No grades found for this selection'),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
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
                  color: gradeColor.withValues(alpha: 0.1),
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

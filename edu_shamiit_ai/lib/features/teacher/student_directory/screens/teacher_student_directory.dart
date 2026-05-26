import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherStudentDirectory extends ConsumerStatefulWidget {
  const TeacherStudentDirectory({super.key});

  @override
  ConsumerState<TeacherStudentDirectory> createState() => _TeacherStudentDirectoryState();
}

class _TeacherStudentDirectoryState extends ConsumerState<TeacherStudentDirectory> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedClass = 'All';
  List<String> _classes = ['All'];
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
      setState(() {
        _classes = ['All', ...classes.map(_classLabel).toSet()];
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
      final classId = _selectedClass == 'All' ? null : _selectedClass;
      final search = _searchController.text.isEmpty ? null : _searchController.text;
      final students = await _apiService.getStudentDirectory(
        classId: classId,
        search: search,
      );
      setState(() {
        _students = students;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF34D399)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                    ),
                    const SizedBox(width: 12),
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
                const SizedBox(height: 16),
                // Search bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => _loadStudents(),
                  ),
                ),
              ],
            ),
          ),

          // Class filter
          if (_classes.length > 1)
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _classes.length,
                itemBuilder: (context, index) {
                  final class_ = _classes[index];
                  final isSelected = _selectedClass == class_;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedClass = class_);
                      _loadStudents();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        class_,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF10B981),
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

          // Students list
          if (!_isLoading && _error == null)
            Expanded(
              child: _students.isEmpty
                  ? Center(child: Text('No students found'.tr(ref)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        return _buildStudentTile(_students[index]);
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(StudentDirectoryEntry student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            child: Text(
              student.name.split(' ').map((n) => n[0]).take(2).join(),
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Class ${student.class_} • Roll ${student.rollNo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (student.avgMarks != null)
                  Text(
                    'Avg: ${student.avgMarks}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          // Arrow
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}

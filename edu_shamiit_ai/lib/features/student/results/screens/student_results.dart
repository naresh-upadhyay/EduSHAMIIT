import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentResults extends ConsumerStatefulWidget {
  const StudentResults({super.key});

  @override
  ConsumerState<StudentResults> createState() => _StudentResultsState();
}

class _StudentResultsState extends ConsumerState<StudentResults> {
  String _selectedCategory = 'Class Test';
  final List<String> _categories = [
    'Class Test', 'Lab Test', 'Assignment', 'Mid-Term', 'End-Term', 'Overall'
  ];

  Map<String, dynamic>? _resultsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _resultsData = {
        "overall": {
          "avg_score": 91.4,
          "grade": "A+",
          "class_rank": "3rd",
          "total_marks": "548/600",
          "improvement": "+4.2%"
        },
        "subjects": [
          {"name": "Mathematics", "icon": "📐", "score": 95, "max": 100, "grade": "A+", "color": const Color(0xFF4F46E5)},
          {"name": "Physics", "icon": "⚛️", "score": 89, "max": 100, "grade": "A", "color": const Color(0xFF3B82F6)},
          {"name": "Chemistry", "icon": "⚗️", "score": 91, "max": 100, "grade": "A", "color": const Color(0xFF10B981)},
          {"name": "English", "icon": "📖", "score": 90, "max": 100, "grade": "A", "color": const Color(0xFFEF4444)},
          {"name": "Computer Sci.", "icon": "💻", "score": 93, "max": 100, "grade": "A+", "color": const Color(0xFF10B981)},
          {"name": "History", "icon": "📜", "score": 90, "max": 100, "grade": "A", "color": const Color(0xFF8B5CF6)},
        ]
      };
      _isLoading = false;
    });
  }

  Color _getGradeColor(String grade) {
    if (grade == 'A+') return const Color(0xFF059669);
    if (grade == 'A') return const Color(0xFF10B981);
    if (grade == 'B') return const Color(0xFF3B82F6);
    if (grade == 'C') return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getGradeBg(String grade) {
    if (grade == 'A+') return const Color(0xFFECFDF5);
    if (grade == 'A') return const Color(0xFFECFDF5);
    if (grade == 'B') return const Color(0xFFEFF6FF);
    if (grade == 'C') return const Color(0xFFFFF7ED);
    return const Color(0xFFFEF2F2);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final overall = _resultsData!['overall'];
    final subjects = _resultsData!['subjects'] as List;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Results',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showYearPicker(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Year 2026',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 10),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.expand_more, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Category chips
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? StudentColors.primary : Colors.white,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Overall performance card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: StudentColors.primary.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Academic Performance',
                          style: TextStyle(color: StudentColors.text3, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          ).createShader(bounds),
                          child: Text(
                            '${overall['avg_score']}%',
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${overall['grade']} Grade 🏅',
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem('${overall['class_rank']}', 'Class Rank'),
                            _buildStatItem('${overall['total_marks']}', 'Total Marks'),
                            _buildStatItem('${overall['improvement']}', 'vs Last Year'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Subject-wise section
                  Row(
                    children: [
                      Text(
                        'Subject-wise Analytics',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: StudentColors.text,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Subjects list
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: StudentColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: subjects.asMap().entries.map((entry) {
                        final index = entry.key;
                        final subject = entry.value;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _getSubjectBg(subject['name']),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text('${subject['icon']}', style: const TextStyle(fontSize: 18)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Score: ${subject['score']}/${subject['max']}',
                                        style: TextStyle(color: StudentColors.text3, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${subject['score']}',
                                      style: TextStyle(
                                        fontFamily: AppFonts.heading,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: subject['color'],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getGradeBg(subject['grade']),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        subject['grade'],
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: _getGradeColor(subject['grade']),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (index < subjects.length - 1)
                              const Divider(height: 16, thickness: 0.5),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Download button
                  ElevatedButton.icon(
                    onPressed: () => _showDownloadDialog(context),
                    icon: const Text('📥', style: TextStyle(fontSize: 16)),
                    label: const Text('Download Report Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/student/aichat'),
        backgroundColor: const Color(0xFF4F46E5),
        child: const Text('🤖', style: TextStyle(fontSize: 20)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Color _getSubjectBg(String subject) {
    final colors = {
      'Mathematics': const Color(0xFFEEF2FF),
      'Physics': const Color(0xFFEFF6FF),
      'Chemistry': const Color(0xFFECFDF5),
      'English': const Color(0xFFFFF0F0),
      'Computer Sci.': const Color(0xFFEFF6FF),
      'History': const Color(0xFFF0FDF4),
    };
    return colors[subject] ?? const Color(0xFFF8FAFC);
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: StudentColors.text3, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem('🏠', 'Home', false, () => context.go('/student/dashboard')),
          _buildNavItem('📚', 'Courses', false, () => context.go('/student/courses')),
          _buildNavItem('📊', 'Results', true, null),
          _buildNavItem('🏆', 'Achieve', false, () => context.go('/student/achievements')),
          _buildNavItem('👤', 'Profile', false, () => context.go('/student/profile')),
        ],
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  void _showYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Academic Year',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 16),
            _buildYearOption('2026', true),
            _buildYearOption('2025', false),
            _buildYearOption('2024', false),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearOption(String year, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          // Handle year change
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isCurrent ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          foregroundColor: isCurrent ? StudentColors.primary : StudentColors.text,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isCurrent ? const BorderSide(color: Color(0xFF4F46E5), width: 2) : BorderSide(color: Colors.grey.shade200),
          ),
          minimumSize: const Size(double.infinity, 48),
        ),
        child: Text(
          'Year $year ${isCurrent ? '(Current)' : ''}',
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📄', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 8),
            Text(
              'Report Card Ready!',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your consolidated academic ledger for 2026 has been generated',
              style: TextStyle(color: StudentColors.text3, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📥 ReportCard_2026_Arjun.pdf', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF059669))),
                      Text('Size: 312 KB', style: TextStyle(color: StudentColors.text3, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Format: PDF', style: TextStyle(color: StudentColors.text3, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('✅ Download Successfully'),
            ),
          ],
        ),
      ),
    );
  }
}
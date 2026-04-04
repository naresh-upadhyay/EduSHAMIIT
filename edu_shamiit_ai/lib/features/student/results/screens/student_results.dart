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
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Class Test', 'Lab Test', 'Assignment', 'Mid-Term', 'End-Term'];
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
          "total_exams": 12
        },
        "results": [
          {
            "subject": "Mathematics",
            "icon": "📐",
            "exam_category": "Mid-Term",
            "marks_obtained": 95,
            "max_marks": 100,
            "grade": "A+",
            "date": "2026-03-15"
          },
          {
            "subject": "Physics",
            "icon": "⚛️",
            "exam_category": "Mid-Term",
            "marks_obtained": 88,
            "max_marks": 100,
            "grade": "A",
            "date": "2026-03-16"
          },
          {
            "subject": "Chemistry",
            "icon": "⚗️",
            "exam_category": "Mid-Term",
            "marks_obtained": 92,
            "max_marks": 100,
            "grade": "A",
            "date": "2026-03-17"
          },
          {
            "subject": "English",
            "icon": "📚",
            "exam_category": "Mid-Term",
            "marks_obtained": 90,
            "max_marks": 100,
            "grade": "A",
            "date": "2026-03-18"
          },
        ]
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final overall = _resultsData!['overall'];
    final results = _resultsData!['results'] as List;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('2025-26', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _loadResults();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? StudentColors.primary : StudentColors.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : StudentColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Score',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${overall['avg_score']}%',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Grade: ${overall['grade']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${overall['total_exams']}',
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text('Exams', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                final pct = (r['marks_obtained'] / r['max_marks'] * 100).round();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      Text(r['icon'], style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['subject'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('${r['exam_category']} • ${r['date']}', style: TextStyle(color: StudentColors.text3, fontSize: 13)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r['marks_obtained']}/${r['max_marks']}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pct >= 90 ? StudentColors.successBg : (pct >= 75 ? StudentColors.warningBg : StudentColors.errorBg),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              r['grade'],
                              style: TextStyle(
                                color: pct >= 90 ? StudentColors.success : (pct >= 75 ? StudentColors.warning : StudentColors.error),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
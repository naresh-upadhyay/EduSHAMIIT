import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentResults extends ConsumerStatefulWidget {
  const ParentResults({super.key});

  @override
  ConsumerState<ParentResults> createState() => _ParentResultsState();
}

class _ParentResultsState extends ConsumerState<ParentResults> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Mid-Term',
    'End-Term',
    'Class Test'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resultsAsync = ref.watch(parentResultsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Academic Progress'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const ChildSwitcher(),
              ],
            ),
          ),

          // ── Category Filter ──
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: ParentColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? ParentColors.darkText2
                            : ParentColors.text2),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                  },
                );
              },
            ),
          ),

          // ── Body ──
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final results = data['results'] as List<dynamic>? ?? [];
    final overallStats = data['overall_stats'] as Map<String, dynamic>? ?? {};

    final avgScore = (overallStats['avg_score'] as num?)?.toDouble() ?? 0.0;
    final grade = overallStats['grade'] ?? 'N/A';
    final classRank = overallStats['class_rank'] ?? '-';

    // Filter results by category
    final filtered = _selectedCategory == 'All'
        ? results
        : results.where((r) {
            final examTitle =
                ((r as Map<String, dynamic>)['exam_title'] ?? '').toLowerCase();
            return examTitle
                .contains(_selectedCategory.toLowerCase().replaceAll('-', ''));
          }).toList();

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 8, bottom: 16),
        children: [
          // ── Stats Row ──
          Row(
            children: [
              Expanded(
                child: _statCard(
                    'Avg Score'.tr(ref),
                    '${avgScore.toStringAsFixed(1)}%',
                    ParentColors.primary,
                    isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                    'Grade'.tr(ref), grade, _getGradeColor(grade), isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard('Class Rank'.tr(ref), '$classRank',
                    ParentColors.info, isDark),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Results List ──
          Text(
            'Exam Results'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No results found'.tr(ref),
                  style: TextStyle(
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3),
                ),
              ),
            )
          else
            ...filtered.map((r) {
              final result = r as Map<String, dynamic>;
              return _buildResultCard(result, isDark);
            }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark
                ? ParentColors.darkBorder
                : color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? ParentColors.darkText3 : ParentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return ParentColors.success;
    if (grade.startsWith('B')) return ParentColors.info;
    if (grade.startsWith('C')) return ParentColors.warning;
    return ParentColors.error;
  }

  String _getSubjectIcon(String subject) {
    const icons = {
      'Mathematics': '📐',
      'Physics': '⚛️',
      'Chemistry': '⚗️',
      'English': '📖',
      'Computer Science': '💻',
      'Biology': '🧬',
      'History': '📜',
      'Geography': '🌍',
    };
    return icons[subject] ?? '📚';
  }

  Widget _buildResultCard(Map<String, dynamic> result, bool isDark) {
    final subject = result['subject'] ?? 'Unknown';
    final score = result['marks_obtained'] as num? ?? 0;
    final maxMarks = result['max_marks'] as num? ?? 100;
    final examTitle = result['exam_title'] ?? '';
    final pct = maxMarks > 0 ? (score / maxMarks * 100) : 0.0;
    final grade = _getGradeFromPct(pct);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getGradeColor(grade).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getSubjectIcon(subject),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                Text(
                  examTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score/$maxMarks',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ParentColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getGradeColor(grade).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _getGradeColor(grade),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGradeFromPct(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'F';
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load results'.tr(ref),
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentResultsProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

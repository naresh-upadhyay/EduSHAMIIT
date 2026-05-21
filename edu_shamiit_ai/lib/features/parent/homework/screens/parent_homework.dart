import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentHomework extends ConsumerStatefulWidget {
  const ParentHomework({super.key});

  @override
  ConsumerState<ParentHomework> createState() => _ParentHomeworkState();
}

class _ParentHomeworkState extends ConsumerState<ParentHomework> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Pending', 'Submitted', 'Graded'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final homeworkAsync = ref.watch(parentHomeworkProvider);

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
                    'Homework'.tr(ref),
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

          // ── Tab Bar ──
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = index == _selectedTab;
                return ChoiceChip(
                  label: Text(_tabs[index]),
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
                  onSelected: (_) => setState(() => _selectedTab = index),
                );
              },
            ),
          ),

          // ── Body ──
          Expanded(
            child: homeworkAsync.when(
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
    final homework = data['homework'] as List<dynamic>? ?? [];

    final filtered = homework.where((h) {
      final status = (h as Map<String, dynamic>)['status'] ?? 'pending';
      final tabStatus = _tabs[_selectedTab].toLowerCase();
      return status.toLowerCase() == tabStatus;
    }).toList();

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 8, bottom: 16),
        children: [
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text(
                        _selectedTab == 0
                            ? '📝'
                            : _selectedTab == 1
                                ? '✅'
                                : '📊',
                        style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'No ${_tabs[_selectedTab].toLowerCase()} homework'
                          .tr(ref),
                      style: TextStyle(
                          color: isDark
                              ? ParentColors.darkText3
                              : ParentColors.text3),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((h) {
              final hw = h as Map<String, dynamic>;
              return _buildHomeworkCard(hw, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw, bool isDark) {
    final title = hw['title'] ?? 'Homework';
    final subject = hw['subject'] ?? '';
    final dueDate = hw['due_date'] ?? '';
    final status = hw['status'] ?? 'pending';
    final teacherName = hw['teacher_name'] ?? '';
    final grade = hw['grade'];
    final maxMarks = hw['max_marks'];

    final statusColor = status == 'graded'
        ? ParentColors.success
        : status == 'submitted'
            ? ParentColors.info
            : ParentColors.warning;
    final statusIcon = status == 'graded'
        ? '✅'
        : status == 'submitted'
            ? '📤'
            : '📝';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(statusIcon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                if (subject.isNotEmpty)
                  Text(
                    subject,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3,
                    ),
                  ),
                if (teacherName.isNotEmpty)
                  Text(
                    'By: $teacherName',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3,
                    ),
                  ),
                if (dueDate.isNotEmpty)
                  Text(
                    'Due: $dueDate',
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'pending'
                          ? ParentColors.warning
                          : (isDark
                              ? ParentColors.darkText3
                              : ParentColors.text3),
                    ),
                  ),
              ],
            ),
          ),
          if (grade != null && maxMarks != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ParentColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$grade/$maxMarks',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.success),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load homework'.tr(ref),
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
            onPressed: () => ref.invalidate(parentHomeworkProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

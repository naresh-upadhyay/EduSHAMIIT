import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/courses_provider.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class StudentCourses extends ConsumerStatefulWidget {
  const StudentCourses({super.key});

  @override
  ConsumerState<StudentCourses> createState() => _StudentCoursesState();
}

class _StudentCoursesState extends ConsumerState<StudentCourses> {
  @override
  Widget build(BuildContext context) {
    final coursesState = ref.watch(coursesProvider);

    final columns = [
      AzureGridColumn<CourseModel>(
        label: 'Course Name',
        width: 180.0,
        compare: (a, b) => a.name.compareTo(b.name),
        cellBuilder: (course) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: course.color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(child: Text(course.icon, style: const TextStyle(fontSize: 12))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                course.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      AzureGridColumn<CourseModel>(
        label: 'Teacher',
        width: 140.0,
        compare: (a, b) => a.teacher.compareTo(b.teacher),
        cellBuilder: (course) => Text(course.teacher),
      ),
      AzureGridColumn<CourseModel>(
        label: 'Chapters',
        width: 120.0,
        cellBuilder: (course) => Text(course.chapters),
      ),
      AzureGridColumn<CourseModel>(
        label: 'Progress',
        width: 180.0,
        compare: (a, b) => a.progress.compareTo(b.progress),
        cellBuilder: (course) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: course.progress,
                  backgroundColor: StudentColors.border,
                  valueColor: AlwaysStoppedAnimation(course.accentColor),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(course.progress * 100).toInt()}% completed',
              style: const TextStyle(fontSize: 10, color: StudentColors.text3),
            ),
          ],
        ),
      ),
      AzureGridColumn<CourseModel>(
        label: 'Score',
        width: 80.0,
        cellBuilder: (course) => Text(
          course.score,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: course.accentColor,
          ),
        ),
      ),
      AzureGridColumn<CourseModel>(
        label: 'Action',
        width: 180.0,
        cellBuilder: (course) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: ElevatedButton(
                onPressed: () => _playRecording(course),
                style: ElevatedButton.styleFrom(
                  backgroundColor: course.accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('🎥 Play', style: TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 26,
              child: OutlinedButton(
                onPressed: () => _showCourseDetail(course),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Text('Details', style: TextStyle(fontSize: 10, color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Courses',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${coursesState.courses.length} Subjects',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: coursesState.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : coursesState.error != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(child: Text('Error: ${coursesState.error}')),
                        )
                      : Padding(
                          padding: Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
                          child: AzureGrid<CourseModel>(
                            title: 'Subject Courses',
                            items: coursesState.courses,
                            columns: columns,
                            onRefresh: () => ref.read(coursesProvider.notifier).loadCourses(),
                            searchMatcher: (course) => '${course.name} ${course.teacher} ${course.chapters}',
                            mobileCardBuilder: (context, course) => _buildCourseCard(course),
                            disableVerticalScroll: true,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course) {
    return GestureDetector(
      onTap: () => _showCourseDetail(course),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: course.color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(course.icon, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${course.teacher} · ${course.chapters}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: StudentColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  course.score,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: course.accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: course.progress,
                backgroundColor: StudentColors.border,
                valueColor: AlwaysStoppedAnimation(course.accentColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${(course.progress * 100).toInt()}% syllabus completed',
                  style: const TextStyle(
                    fontSize: 9,
                    color: StudentColors.text3,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _playRecording(course),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: course.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('🎥 Play Recording', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _playRecording(CourseModel course) {
    context.go('/student/live-classes?playSubject=${Uri.encodeComponent(course.name)}');
  }

  void _showCourseDetail(CourseModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: StudentColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: StudentColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: course.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(course.icon, style: const TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${course.teacher} · ${course.chapters}',
                          style: const TextStyle(fontSize: 11, color: StudentColors.text3),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    course.score,
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: course.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: course.progress,
                  backgroundColor: StudentColors.border,
                  valueColor: AlwaysStoppedAnimation(course.accentColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(course.progress * 100).toInt()}% syllabus completed',
                style: const TextStyle(fontSize: 11, color: StudentColors.text3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Syllabus Coverage:',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (course.syllabusCoverage.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No syllabus details available.', style: TextStyle(fontSize: 12, color: StudentColors.text3)),
                ),
              ...course.syllabusCoverage.map((item) {
                Color statusColor = StudentColors.success;
                if (item.status == 'warning') statusColor = StudentColors.warning;
                if (item.status == 'error') statusColor = StudentColors.error;
                return _buildCoverageItem(item.topic, item.progress, statusColor);
              }),
              const SizedBox(height: 20),
              const Text(
                'Upcoming Topics:',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (course.upcomingTopics.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('No upcoming topics listed.', style: TextStyle(fontSize: 12, color: StudentColors.text3)),
                ),
              ...course.upcomingTopics.map((topic) => _buildUpcomingTopic(topic)),
              
              if (course.resourcesText.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Resources & Statistics:',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StudentColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StudentColors.info.withAlpha(38)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories, size: 16, color: StudentColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          course.resourcesText,
                          style: const TextStyle(fontSize: 11, color: StudentColors.text2, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final success = await ref.read(coursesProvider.notifier).startLearning(course.id);
                    if (success) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('🎥 Starting video lecture...'.tr(ref)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('▶ Start Learning', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverageItem(String topic, double progress, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            progress >= 1.0 ? Icons.check_circle : progress >= 0.5 ? Icons.remove_circle : Icons.radio_button_unchecked,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              topic,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTopic(String topic) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Text('•', style: TextStyle(fontSize: 16, color: StudentColors.text3)),
          const SizedBox(width: 8),
          Text(
            topic,
            style: const TextStyle(fontSize: 11, color: StudentColors.text2),
          ),
        ],
      ),
    );
  }
}

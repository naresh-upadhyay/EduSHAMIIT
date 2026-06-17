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
        width: 120.0,
        cellBuilder: (course) => SizedBox(
          height: 28,
          child: ElevatedButton(
            onPressed: () => _showCourseDetail(course),
            style: ElevatedButton.styleFrom(
              backgroundColor: course.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            child: const Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
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
                          padding: Responsive.contentPadding(context).copyWith(top: 16, bottom: 80),
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
                  onPressed: () => _showCourseDetail(course),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: course.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCourseDetail(CourseModel course) async {
    await context.push('/student/courses/${course.id}/details');
    if (mounted) {
      ref.read(coursesProvider.notifier).loadCourses();
    }
  }
}

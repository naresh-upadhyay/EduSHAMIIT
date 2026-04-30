import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/courses_provider.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';

class StudentCourses extends ConsumerStatefulWidget {
  const StudentCourses({super.key});

  @override
  ConsumerState<StudentCourses> createState() => _StudentCoursesState();
}

class _StudentCoursesState extends ConsumerState<StudentCourses> {
  @override
  Widget build(BuildContext context) {
    final coursesState = ref.watch(coursesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
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
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${coursesState.courses.length} Subjects',
                    style: const TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ResponsiveContent(
              child: coursesState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : coursesState.error != null
                      ? Center(child: Text('Error: ${coursesState.error}'))
                      : coursesState.courses.isEmpty
                          ? Center(child: Text('No courses available'.tr(ref)))
                          : GridView.builder(
                              padding: Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Responsive.isDesktop(context) ? 3 : Responsive.isTablet(context) ? 2 : 1,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: 160,
                              ),
                              itemCount: coursesState.courses.length,
                              itemBuilder: (context, index) => _buildCourseCard(coursesState.courses[index]),
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('🎥 View', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
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
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: StudentColors.border,
                  borderRadius: BorderRadius.circular(2),
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
              // Sample coverage items (would come from API in real implementation)
              _buildCoverageItem('Algebra', 1.0, StudentColors.success),
              _buildCoverageItem('Trigonometry', 1.0, StudentColors.success),
              _buildCoverageItem('Coordinate Geometry', 0.9, StudentColors.success),
              _buildCoverageItem('Calculus', 0.6, StudentColors.warning),
              _buildCoverageItem('Probability', 0.4, StudentColors.error),
              _buildCoverageItem('Statistics', 0.3, StudentColors.error),
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
              _buildUpcomingTopic('Integration Applications'),
              _buildUpcomingTopic('Probability Distributions'),
              _buildUpcomingTopic('Statistics — Mean, Median, Mode'),
              const SizedBox(height: 20),
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
                        SnackBar(content: Text('🎥 Starting video lecture...'.tr(ref))),
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

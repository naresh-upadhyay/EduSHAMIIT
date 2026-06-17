import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class TeacherCourseItem {
  final String id;
  final String title;
  final String description;
  final String subjectName;
  final String icon;
  final String colorHex;

  TeacherCourseItem({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectName,
    required this.icon,
    required this.colorHex,
  });

  factory TeacherCourseItem.fromJson(Map<String, dynamic> json) {
    final subj = json['subject'] as Map<String, dynamic>? ?? {};
    return TeacherCourseItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      subjectName: subj['name']?.toString() ?? json['title']?.toString() ?? 'Subject',
      icon: subj['icon']?.toString() ?? '📚',
      colorHex: subj['color']?.toString() ?? '#06B6D4',
    );
  }
}

class TeacherClassSubjectsScreen extends ConsumerStatefulWidget {
  final String classId;
  const TeacherClassSubjectsScreen({super.key, required this.classId});

  @override
  ConsumerState<TeacherClassSubjectsScreen> createState() => _TeacherClassSubjectsScreenState();
}

class _TeacherClassSubjectsScreenState extends ConsumerState<TeacherClassSubjectsScreen> {
  bool _isLoading = true;
  List<TeacherCourseItem> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final list = await TeacherApiService().getClassCourses(widget.classId);
      setState(() {
        _courses = list.map((item) => TeacherCourseItem.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      });
    } catch (e) {
      // Handle error gracefully
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF06B6D4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      AzureGridColumn<TeacherCourseItem>(
        label: 'Subject Name',
        width: 200.0,
        compare: (a, b) => a.subjectName.compareTo(b.subjectName),
        cellBuilder: (item) {
          final color = _parseColor(item.colorHex);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    item.icon,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.subjectName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
      AzureGridColumn<TeacherCourseItem>(
        label: 'Description',
        width: 320.0,
        cellBuilder: (item) => Text(
          item.description,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      AzureGridColumn<TeacherCourseItem>(
        label: 'Action',
        width: 140.0,
        cellBuilder: (item) {
          final color = _parseColor(item.colorHex);
          return SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: () => context.push('/teacher/courses/${item.id}/details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              child: Text(
                'View Details'.tr(ref),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: Text(
          'Subjects - ${widget.classId}'.tr(ref),
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/teacher/my-classes'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
          : _courses.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AzureGrid<TeacherCourseItem>(
                              title: 'Class Subjects',
                              items: _courses,
                              columns: columns,
                              onRefresh: _loadCourses,
                              searchMatcher: (item) => '${item.subjectName} ${item.description}',
                              mobileCardBuilder: (context, item) => _buildCourseCard(item),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCourseCard(TeacherCourseItem item) {
    final color = _parseColor(item.colorHex);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      item.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.subjectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => context.push('/teacher/courses/${item.id}/details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'View Details'.tr(ref),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.school, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No subjects or courses assigned to this class yet.'.tr(ref),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:edu_shamiit_academic/core/services/student_api_service.dart';
import 'package:edu_shamiit_core/constants/student_colors.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/utils/l10n.dart';
import 'package:edu_shamiit_core/utils/math_formatter.dart';

class StudentCourseDetailsScreen extends ConsumerStatefulWidget {
  final String courseId;
  const StudentCourseDetailsScreen({super.key, required this.courseId});

  @override
  ConsumerState<StudentCourseDetailsScreen> createState() => _StudentCourseDetailsScreenState();
}

class _StudentCourseDetailsScreenState extends ConsumerState<StudentCourseDetailsScreen> {
  bool _isLoading = true;
  String _courseName = '';
  List<dynamic> _chapters = [];
  Map<String, dynamic>? _selectedTopic;
  String _selectedChapterId = '';

  Future<void> _toggleTopicCompletion() async {
    if (_selectedTopic == null) return;
    final topicId = _selectedTopic!['id'].toString();
    final wasCompleted = _selectedTopic!['completed'] == true;
    final targetCompleted = !wasCompleted;

    // Optimistically update local state
    setState(() {
      _selectedTopic!['completed'] = targetCompleted;
      
      // Update in the chapters list to keep the sidebar in sync
      for (var ch in _chapters) {
        final topics = ch['topics'] as List<dynamic>? ?? [];
        for (var t in topics) {
          if (t['id'].toString() == topicId) {
            t['completed'] = targetCompleted;
            break;
          }
        }
      }
    });

    // Make the API call
    final success = await StudentApiService().toggleTopicProgress(topicId, targetCompleted);

    if (!success && mounted) {
      // Revert state on failure
      setState(() {
        _selectedTopic!['completed'] = wasCompleted;
        for (var ch in _chapters) {
          final topics = ch['topics'] as List<dynamic>? ?? [];
          for (var t in topics) {
            if (t['id'].toString() == topicId) {
              t['completed'] = wasCompleted;
              break;
            }
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update progress. Please check your connection.'.tr(ref)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await StudentApiService().getCourseDetails(widget.courseId);
      final course = details['course'] as Map<String, dynamic>? ?? {};
      _courseName = (course['name'] ?? course['title'] ?? 'Course Details').toString();
      
      final subjectObj = course['subjects'] as Map<String, dynamic>?;
      if (subjectObj != null && _courseName == 'Course Details') {
        _courseName = (subjectObj['name'] ?? 'Course Details').toString();
      }

      _chapters = details['chapters'] as List<dynamic>? ?? [];

      // Auto-select first topic of the first chapter
      if (_chapters.isNotEmpty) {
        final firstChapter = _chapters.first as Map<String, dynamic>;
        final topics = firstChapter['topics'] as List<dynamic>? ?? [];
        if (topics.isNotEmpty) {
          _selectedTopic = topics.first as Map<String, dynamic>;
          _selectedChapterId = firstChapter['id'].toString();
        }
      }
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

  // Find sequential topics to support Next and Previous buttons
  List<Map<String, dynamic>> _getAllTopicsFlat() {
    final List<Map<String, dynamic>> flat = [];
    for (var ch in _chapters) {
      final topics = ch['topics'] as List<dynamic>? ?? [];
      for (var t in topics) {
        flat.add(Map<String, dynamic>.from(t as Map));
      }
    }
    return flat;
  }

  void _navigateToNextTopic(bool goNext) {
    final flat = _getAllTopicsFlat();
    if (flat.isEmpty || _selectedTopic == null) return;
    
    final currentIndex = flat.indexWhere((t) => t['id'] == _selectedTopic!['id']);
    if (currentIndex == -1) return;

    final targetIndex = goNext ? currentIndex + 1 : currentIndex - 1;
    if (targetIndex >= 0 && targetIndex < flat.length) {
      setState(() {
        _selectedTopic = flat[targetIndex];
        // Find corresponding chapter ID
        for (var ch in _chapters) {
          final topics = ch['topics'] as List<dynamic>? ?? [];
          final hasTopic = topics.any((t) => t['id'] == _selectedTopic!['id']);
          if (hasTopic) {
            _selectedChapterId = ch['id'].toString();
            break;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isWide(context);

    Widget sidebarWidget = _buildSidebar();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _courseName,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/student/courses');
            }
          },
        ),
        actions: [
          if (!isWide && !_isLoading && _chapters.isNotEmpty)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
        ],
      ),
      endDrawer: !isWide ? Drawer(child: SafeArea(child: sidebarWidget)) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: StudentColors.primary))
          : _chapters.isEmpty
              ? _buildEmptyState()
              : Row(
                  children: [
                    if (isWide)
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(right: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: sidebarWidget,
                      ),
                    Expanded(
                      child: _buildContentArea(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No chapters or topics yet.'.tr(ref),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Course Contents'.tr(ref),
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, idx) {
                final ch = _chapters[idx];
                final chId = ch['id'].toString();
                final title = ch['title']?.toString() ?? '';
                final desc = ch['description']?.toString() ?? '';
                final topics = ch['topics'] as List<dynamic>? ?? [];

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: PageStorageKey<String>(chId),
                    initiallyExpanded: idx == 0 || chId == _selectedChapterId,
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: desc.isNotEmpty
                        ? Text(
                            desc,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    leading: const Icon(Icons.folder_outlined, color: Color(0xFF4F46E5), size: 20),
                    children: topics.map<Widget>((t) {
                      final topicId = t['id'].toString();
                      final isSelected = _selectedTopic != null && _selectedTopic!['id'] == topicId;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            t['title']?.toString() ?? '',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                              fontSize: 13,
                            ),
                          ),
                          leading: Icon(
                            t['completed'] == true
                                ? Icons.check_circle
                                : (isSelected ? Icons.play_circle_fill : Icons.radio_button_unchecked),
                            color: t['completed'] == true
                                ? Colors.green.shade600
                                : (isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade400),
                            size: 16,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedTopic = Map<String, dynamic>.from(t as Map);
                              _selectedChapterId = chId;
                            });
                            if (!Responsive.isWide(context)) {
                              Navigator.pop(context); // Close Drawer on mobile
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_selectedTopic == null) {
      return Center(
        child: Text(
          'Select a topic from the sidebar to start learning.'.tr(ref),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final title = _selectedTopic!['title']?.toString() ?? '';
    final content = _selectedTopic!['content']?.toString() ?? '';
    final flatTopics = _getAllTopicsFlat();
    final currentIndex = flatTopics.indexWhere((t) => t['id'] == _selectedTopic!['id']);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex != -1 && currentIndex < flatTopics.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic Header Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Topic ${currentIndex + 1} of ${flatTopics.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _selectedTopic!['completed'] == true
                  ? ElevatedButton.icon(
                      onPressed: _toggleTopicCompletion,
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: Text('Completed'.tr(ref)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _toggleTopicCompletion,
                      icon: Icon(Icons.check_circle_outline, size: 16, color: Colors.grey.shade600),
                      label: Text('Mark as Completed'.tr(ref)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.grey.shade700,
                      ),
                    ),
            ],
          ),
        ),
        
        // Topic Content
        Expanded(
          child: Container(
            color: Colors.white,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              child: SingleChildScrollView(
                child: content.trim().isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 64.0),
                          child: Text(
                            'No content available for this topic.'.tr(ref),
                            style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      )
                    : MarkdownBody(
                        data: MathFormatter.cleanMathExpressions(content),
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF334155)),
                          h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.8),
                          h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.6),
                          h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          code: const TextStyle(backgroundColor: Color(0xFFF1F5F9), fontFamily: 'monospace', fontSize: 13, color: Color(0xFF0F172A)),
                          codeblockPadding: const EdgeInsets.all(12),
                          codeblockDecoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        
        // Navigation footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: hasPrev ? () => _navigateToNextTopic(false) : null,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text('Previous'.tr(ref)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: hasPrev ? const Color(0xFF4F46E5) : Colors.grey.shade300),
                  foregroundColor: const Color(0xFF4F46E5),
                ),
              ),
              ElevatedButton.icon(
                onPressed: hasNext ? () => _navigateToNextTopic(true) : null,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Next'.tr(ref)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

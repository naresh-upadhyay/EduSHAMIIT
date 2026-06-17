import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/core/utils/math_formatter.dart';

class TeacherCourseDetailsScreen extends ConsumerStatefulWidget {
  final String courseId;
  const TeacherCourseDetailsScreen({super.key, required this.courseId});

  @override
  ConsumerState<TeacherCourseDetailsScreen> createState() => _TeacherCourseDetailsScreenState();
}

class _TeacherCourseDetailsScreenState extends ConsumerState<TeacherCourseDetailsScreen> {
  bool _isLoading = true;
  String _courseName = '';
  String? _classId;
  List<dynamic> _chapters = [];
  Map<String, dynamic>? _selectedTopic;
  String _selectedChapterId = '';

  // Inline editing state
  bool _isEditingContent = false;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editContentController = TextEditingController();
  bool _isSavingContent = false;

  @override
  void initState() {
    super.initState();
    _loadCourseDetails();
  }

  @override
  void dispose() {
    _editTitleController.dispose();
    _editContentController.dispose();
    super.dispose();
  }

  Future<void> _loadCourseDetails({String? selectTopicId}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final details = await TeacherApiService().getCourseDetails(widget.courseId);
      final course = details['course'] as Map<String, dynamic>? ?? {};
      _courseName = (course['name'] ?? course['title'] ?? 'Course Details').toString();
      
      final subjectObj = course['subjects'] as Map<String, dynamic>?;
      if (subjectObj != null && _courseName == 'Course Details') {
        _courseName = (subjectObj['name'] ?? 'Course Details').toString();
      }

      if (subjectObj != null && subjectObj['class'] != null) {
        _classId = subjectObj['class'].toString();
      }

      _chapters = details['chapters'] as List<dynamic>? ?? [];

      // Auto-select topic
      if (selectTopicId != null) {
        // Find the topic matching selectTopicId
        bool found = false;
        for (var ch in _chapters) {
          final topics = ch['topics'] as List<dynamic>? ?? [];
          for (var t in topics) {
            if (t['id'].toString() == selectTopicId) {
              _selectedTopic = Map<String, dynamic>.from(t as Map);
              _selectedChapterId = ch['id'].toString();
              found = true;
              break;
            }
          }
          if (found) break;
        }
      } else if (_selectedTopic != null) {
        // Keep selected topic if still exists
        bool exists = false;
        for (var ch in _chapters) {
          final topics = ch['topics'] as List<dynamic>? ?? [];
          for (var t in topics) {
            if (t['id'].toString() == _selectedTopic!['id'].toString()) {
              _selectedTopic = Map<String, dynamic>.from(t as Map);
              _selectedChapterId = ch['id'].toString();
              exists = true;
              break;
            }
          }
          if (exists) break;
        }
        if (!exists) {
          _selectedTopic = null;
          _selectedChapterId = '';
        }
      }

      // Default selection if nothing selected yet
      if (_selectedTopic == null && _chapters.isNotEmpty) {
        final firstChapter = _chapters.first as Map<String, dynamic>;
        final topics = firstChapter['topics'] as List<dynamic>? ?? [];
        if (topics.isNotEmpty) {
          _selectedTopic = topics.first as Map<String, dynamic>;
          _selectedChapterId = firstChapter['id'].toString();
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load course details: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.tr(ref)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.tr(ref)),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Premium Dialog UI Helpers ---

  InputDecoration _buildPremiumInputDecoration({
    required String label,
    required IconData prefixIcon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label.tr(ref),
      labelStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 13,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: const Color(0xFF06B6D4),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2E2E38) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3E3E48) : Colors.grey.shade200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF3E3E48) : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF06B6D4),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildPremiumDialogHeader({
    required String title,
    required IconData icon,
    required Color iconBgColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 24,
            color: iconBgColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  // --- Chapter Management Dialogs ---

  void _showAddChapterDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildPremiumDialogHeader(
          title: 'Add Chapter',
          icon: Icons.create_new_folder_outlined,
          iconBgColor: const Color(0xFF06B6D4),
          isDark: isDark,
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: _buildPremiumInputDecoration(
                  label: 'Chapter Title',
                  prefixIcon: Icons.title_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: _buildPremiumInputDecoration(
                  label: 'Description',
                  prefixIcon: Icons.description_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            child: Text('Cancel'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await TeacherApiService().createChapter(widget.courseId, {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                _showSuccessSnackBar('Chapter added successfully');
                _loadCourseDetails();
              } catch (e) {
                _showErrorSnackBar('Failed to add chapter: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Add'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditChapterDialog(Map<String, dynamic> chapter) {
    final titleCtrl = TextEditingController(text: chapter['title']?.toString() ?? '');
    final descCtrl = TextEditingController(text: chapter['description']?.toString() ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildPremiumDialogHeader(
          title: 'Edit Chapter',
          icon: Icons.edit_note_rounded,
          iconBgColor: const Color(0xFF06B6D4),
          isDark: isDark,
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: _buildPremiumInputDecoration(
                  label: 'Chapter Title',
                  prefixIcon: Icons.title_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: _buildPremiumInputDecoration(
                  label: 'Description',
                  prefixIcon: Icons.description_outlined,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            child: Text('Cancel'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await TeacherApiService().updateChapter(chapter['id'].toString(), {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                _showSuccessSnackBar('Chapter updated successfully');
                _loadCourseDetails();
              } catch (e) {
                _showErrorSnackBar('Failed to update chapter: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Save'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChapter(Map<String, dynamic> chapter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildPremiumDialogHeader(
          title: 'Delete Chapter',
          icon: Icons.delete_forever_rounded,
          iconBgColor: Colors.red,
          isDark: isDark,
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete chapter "${chapter['title']}"? This will delete all its topics.'.tr(ref),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            child: Text('Cancel'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TeacherApiService().deleteChapter(chapter['id'].toString());
                _showSuccessSnackBar('Chapter deleted successfully');
                _loadCourseDetails();
              } catch (e) {
                _showErrorSnackBar('Failed to delete chapter: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Delete'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Topic Management Dialogs ---

  void _showAddTopicDialog(String chapterId) {
    final titleCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildPremiumDialogHeader(
          title: 'Add Topic',
          icon: Icons.note_add_outlined,
          iconBgColor: const Color(0xFF06B6D4),
          isDark: isDark,
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: _buildPremiumInputDecoration(
                  label: 'Topic Title',
                  prefixIcon: Icons.title_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            child: Text('Cancel'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final result = await TeacherApiService().createTopic(chapterId, {
                  'title': titleCtrl.text.trim(),
                  'content': '',
                });
                _showSuccessSnackBar('Topic added successfully');
                _loadCourseDetails(selectTopicId: result['id'].toString());
              } catch (e) {
                _showErrorSnackBar('Failed to add topic: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Add'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditTopicTitleDialog(Map<String, dynamic> topic) {
    final titleCtrl = TextEditingController(text: topic['title']?.toString() ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildPremiumDialogHeader(
          title: 'Edit Topic Title',
          icon: Icons.edit_attributes_outlined,
          iconBgColor: const Color(0xFF06B6D4),
          isDark: isDark,
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                decoration: _buildPremiumInputDecoration(
                  label: 'Topic Title',
                  prefixIcon: Icons.title_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            child: Text('Cancel'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await TeacherApiService().updateTopic(topic['id'].toString(), {
                  'title': titleCtrl.text.trim(),
                });
                _showSuccessSnackBar('Topic title updated');
                _loadCourseDetails(selectTopicId: topic['id'].toString());
              } catch (e) {
                _showErrorSnackBar('Failed to update topic: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Save'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTopic(Map<String, dynamic> topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _buildPremiumDialogHeader(
          title: 'Delete Topic',
          icon: Icons.delete_outline_rounded,
          iconBgColor: Colors.red,
          isDark: isDark,
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete topic "${topic['title']}"?'.tr(ref),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            child: Text('Cancel'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await TeacherApiService().deleteTopic(topic['id'].toString());
                _showSuccessSnackBar('Topic deleted successfully');
                _loadCourseDetails();
              } catch (e) {
                _showErrorSnackBar('Failed to delete topic: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text('Delete'.tr(ref), style: const TextStyle(fontFamily: AppFonts.body, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Inline Markdown Content Editor ---

  void _startEditingContent() {
    if (_selectedTopic == null) return;
    setState(() {
      _isEditingContent = true;
      _editTitleController.text = _selectedTopic!['title']?.toString() ?? '';
      _editContentController.text = _selectedTopic!['content']?.toString() ?? '';
    });
  }

  Future<void> _saveContentChanges() async {
    if (_selectedTopic == null) return;
    setState(() {
      _isSavingContent = true;
    });

    try {
      final topicId = _selectedTopic!['id'].toString();
      await TeacherApiService().updateTopic(topicId, {
        'title': _editTitleController.text.trim(),
        'content': _editContentController.text,
      });

      _showSuccessSnackBar('Content saved successfully');
      setState(() {
        _isEditingContent = false;
      });
      await _loadCourseDetails(selectTopicId: topicId);
    } catch (e) {
      _showErrorSnackBar('Failed to save changes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingContent = false;
        });
      }
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
          '$_courseName (Teacher Mode)'.tr(ref),
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else if (_classId != null) {
              context.go('/teacher/my-classes/$_classId/subjects');
            } else {
              context.go('/teacher/my-classes');
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
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
                      child: _isEditingContent ? _buildEditorArea() : _buildContentArea(),
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
          const Icon(Icons.folder_open, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'This course has no chapters or topics yet.'.tr(ref),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddChapterDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Create First Chapter'.tr(ref), style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chapters'.tr(ref),
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF06B6D4)),
                  tooltip: 'Add Chapter'.tr(ref),
                  onPressed: _showAddChapterDialog,
                ),
              ],
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
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16),
                          padding: EdgeInsets.zero,
                          onSelected: (val) {
                            if (val == 'add') {
                              _showAddTopicDialog(chId);
                            } else if (val == 'edit') {
                              _showEditChapterDialog(ch);
                            } else if (val == 'delete') {
                              _confirmDeleteChapter(ch);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'add', child: Text('Add Topic'.tr(ref))),
                            PopupMenuItem(value: 'edit', child: Text('Edit Chapter'.tr(ref))),
                            PopupMenuItem(value: 'delete', child: Text('Delete Chapter'.tr(ref), style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      ],
                    ),
                    subtitle: desc.isNotEmpty
                        ? Text(
                            desc,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    leading: const Icon(Icons.folder_outlined, color: Color(0xFF06B6D4), size: 20),
                    children: topics.map<Widget>((t) {
                      final topicId = t['id'].toString();
                      final isSelected = _selectedTopic != null && _selectedTopic!['id'] == topicId;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFEFF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t['title']?.toString() ?? '',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? const Color(0xFF0891B2) : const Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 14),
                                padding: EdgeInsets.zero,
                                onSelected: (val) {
                                  if (val == 'edit_title') {
                                    _showEditTopicTitleDialog(Map<String, dynamic>.from(t as Map));
                                  } else if (val == 'delete') {
                                    _confirmDeleteTopic(Map<String, dynamic>.from(t as Map));
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'edit_title', child: Text('Rename'.tr(ref))),
                                  PopupMenuItem(value: 'delete', child: Text('Delete'.tr(ref), style: const TextStyle(color: Colors.red))),
                                ],
                              ),
                            ],
                          ),
                          leading: Icon(
                            isSelected ? Icons.play_circle_fill : Icons.radio_button_unchecked,
                            color: isSelected ? const Color(0xFF06B6D4) : Colors.grey.shade400,
                            size: 16,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedTopic = Map<String, dynamic>.from(t as Map);
                              _selectedChapterId = chId;
                              _isEditingContent = false; // reset editor
                            });
                            if (!Responsive.isWide(context)) {
                              Navigator.pop(context);
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
          'Select or add a topic from the sidebar.'.tr(ref),
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final title = _selectedTopic!['title']?.toString() ?? '';
    final content = _selectedTopic!['content']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _startEditingContent,
                icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                label: Text('Edit Content'.tr(ref), style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        
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
                          child: Column(
                            children: [
                              Text(
                                'No content yet.'.tr(ref),
                                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _startEditingContent,
                                icon: const Icon(Icons.add),
                                label: Text('Add Material / Content'.tr(ref)),
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF06B6D4)),
                              ),
                            ],
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
      ],
    );
  }

  Widget _buildEditorArea() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Edit Topic Content'.tr(ref),
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _isSavingContent ? null : () => setState(() => _isEditingContent = false),
                    child: Text('Cancel'.tr(ref)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSavingContent ? null : _saveContentChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: _isSavingContent
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save Changes'.tr(ref)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _editTitleController,
            decoration: InputDecoration(
              labelText: 'Topic Title'.tr(ref),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _editContentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                labelText: 'Content (Markdown Supported)'.tr(ref),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                hintText: 'Enter topic reading material, markdown formatting, code blocks, bullet points etc.'.tr(ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

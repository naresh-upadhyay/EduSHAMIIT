import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'package:edu_shamiit_academic/shared/widgets/azure_grid.dart';

class TeacherAchievementsScreen extends ConsumerStatefulWidget {
  const TeacherAchievementsScreen({super.key});

  @override
  ConsumerState<TeacherAchievementsScreen> createState() =>
      _TeacherAchievementsScreenState();
}

class _TeacherAchievementsScreenState
    extends ConsumerState<TeacherAchievementsScreen>
    with SingleTickerProviderStateMixin {
  final TeacherApiService _apiService = TeacherApiService();

  late TabController _tabController;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedTabIndex = 0; // 0: Task Templates, 1: Classroom Progress

  // Task templates state
  List<dynamic> _tasks = [];

  // Classroom progress state
  List<TeacherMyClass> _classes = [];
  List<dynamic> _studentProgress = [];
  bool _isLoadingProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
      if (_selectedTabIndex == 1 &&
          _studentProgress.isEmpty &&
          !_isLoadingProgress) {
        _loadStudentProgress();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      // Load all task templates
      final tasks = await _apiService.getTeacherTasks();
      // Load classes
      final classes = await _apiService.getMyClasses();

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _classes = classes;
        _isLoading = false;
      });

      if (_selectedTabIndex == 1) {
        _loadStudentProgress();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentProgress() async {
    if (_classes.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _isLoadingProgress = true;
    });
    try {
      final List<dynamic> allProgress = [];
      // Fetch progress for all assigned classes in parallel
      final results = await Future.wait(
          _classes.map((c) => _apiService.getStudentProgress(c.name)));
      for (int i = 0; i < _classes.length; i++) {
        final className = _classes[i].name;
        final list = results[i];
        for (var student in list) {
          if (student is Map<String, dynamic>) {
            student['class_name'] = className;
          }
          allProgress.add(student);
        }
      }
      if (!mounted) return;
      setState(() {
        _studentProgress = allProgress;
        _isLoadingProgress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProgress = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load student progress: $e')),
        );
      });
    }
  }

  Future<void> _handleDeleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task Template'),
        content: const Text(
            'Are you sure you want to delete this task? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.deleteTeacherTask(taskId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted successfully')),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _showTaskFormDialog({Map<String, dynamic>? taskToEdit}) {
    final nameController =
        TextEditingController(text: taskToEdit?['name'] ?? '');
    final descController =
        TextEditingController(text: taskToEdit?['description'] ?? '');
    final criteriaController =
        TextEditingController(text: taskToEdit?['criteria'] ?? '');
    final iconController =
        TextEditingController(text: taskToEdit?['icon'] ?? '🏆');
    final xpController = TextEditingController(
        text: taskToEdit?['xp_reward']?.toString() ?? '100');

    String rarity = taskToEdit?['rarity'] ?? 'common';
    String? targetClass = taskToEdit?['target_class'];

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double dialogWidth =
                MediaQuery.of(context).size.width * 0.85 > 600.0
                    ? 600.0
                    : MediaQuery.of(context).size.width * 0.85;
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gradient Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            taskToEdit == null
                                ? Icons.add_task
                                : Icons.edit_note_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  taskToEdit == null
                                      ? 'Create Task Template'
                                      : 'Edit Task Template',
                                  style: const TextStyle(
                                    fontFamily: AppFonts.heading,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  taskToEdit == null
                                      ? 'Define a new lockable objective for your students'
                                      : 'Modify the existing task criteria and XP rewards',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Form Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Task Title
                              TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: 'Task Title *',
                                  hintText: 'e.g. Science Fair Winner',
                                  prefixIcon:
                                      const Icon(Icons.title_rounded, size: 18),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF06B6D4), width: 2),
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Title is required'
                                        : null,
                              ),
                              const SizedBox(height: 16),

                              // Description
                              TextFormField(
                                controller: descController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Description',
                                  hintText: 'Describe what the task achieves',
                                  prefixIcon: const Icon(
                                      Icons.description_rounded,
                                      size: 18),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF06B6D4), width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Criteria
                              TextFormField(
                                controller: criteriaController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Criteria',
                                  hintText:
                                      'Clear criteria for student success',
                                  prefixIcon:
                                      const Icon(Icons.rule_rounded, size: 18),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF06B6D4), width: 2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Rarity Horizontal Selector
                              const Text(
                                'Select Rarity *',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              _buildRaritySelector(rarity, (selected) {
                                setDialogState(() {
                                  rarity = selected;
                                });
                              }),
                              const SizedBox(height: 20),

                              // XP Reward & Increments
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: xpController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'XP Reward *',
                                            prefixIcon: const Icon(
                                                Icons.star_rounded,
                                                size: 18),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF06B6D4),
                                                  width: 2),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'XP is required';
                                            }
                                            if (int.tryParse(value) == null) {
                                              return 'Must be an integer';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        // Quick XP selection pills
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [50, 100, 250, 500, 1000]
                                              .map((xp) {
                                            return InkWell(
                                              onTap: () {
                                                setDialogState(() {
                                                  xpController.text =
                                                      xp.toString();
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF06B6D4)
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                      color: const Color(
                                                              0xFF06B6D4)
                                                          .withValues(
                                                              alpha: 0.2)),
                                                ),
                                                child: Text(
                                                  '+$xp XP',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF06B6D4)),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Emoji Picker
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          controller: iconController,
                                          decoration: InputDecoration(
                                            labelText: 'Emoji Icon',
                                            prefixIcon: const Icon(
                                                Icons.emoji_emotions_rounded,
                                                size: 18),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF06B6D4),
                                                  width: 2),
                                            ),
                                          ),
                                          validator: (value) =>
                                              value == null || value.isEmpty
                                                  ? 'Icon required'
                                                  : null,
                                        ),
                                        const SizedBox(height: 8),
                                        // Quick Emoji Selector Grid
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            '🏆',
                                            '🔬',
                                            '🎨',
                                            '📚',
                                            '🚀',
                                            '💻',
                                            '🎯',
                                            '🌟',
                                            '🎖️',
                                            '🔥'
                                          ].map((emoji) {
                                            final isSelected =
                                                iconController.text == emoji;
                                            return InkWell(
                                              onTap: () {
                                                setDialogState(() {
                                                  iconController.text = emoji;
                                                });
                                              },
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFF6366F1)
                                                          .withValues(
                                                              alpha: 0.15)
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF6366F1)
                                                        : Colors.grey
                                                            .withValues(
                                                                alpha: 0.2),
                                                  ),
                                                ),
                                                child: Text(emoji,
                                                    style: const TextStyle(
                                                        fontSize: 14)),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Target Class Dropdown
                              DropdownButtonFormField<String?>(
                                initialValue: targetClass,
                                decoration: InputDecoration(
                                  labelText: 'Target Class (Optional)',
                                  prefixIcon:
                                      const Icon(Icons.class_rounded, size: 18),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF06B6D4), width: 2),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem(
                                      value: null, child: Text('All Classes')),
                                  ..._classes
                                      .map((c) => c.name)
                                      .toSet()
                                      .map((className) {
                                    return DropdownMenuItem(
                                        value: className,
                                        child: Text(className));
                                  }),
                                ],
                                onChanged: (val) {
                                  setDialogState(() {
                                    targetClass = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Dialog Actions (Bottom bar)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161F30)
                            : Colors.grey.shade50,
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? const Color(0xFF2E3B4E)
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF06B6D4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            onPressed: () async {
                              if (formKey.currentState?.validate() == true) {
                                final taskData = {
                                  'name': nameController.text.trim(),
                                  'description': descController.text.trim(),
                                  'criteria': criteriaController.text.trim(),
                                  'xp_reward':
                                      int.parse(xpController.text.trim()),
                                  'icon': iconController.text.trim(),
                                  'rarity': rarity,
                                  'target_class': targetClass,
                                };

                                try {
                                  if (taskToEdit == null) {
                                    await _apiService
                                        .createTeacherTask(taskData);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Task template created')));
                                  } else {
                                    await _apiService.updateTeacherTask(
                                        taskToEdit['id'], taskData);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Task template updated')));
                                  }
                                  Navigator.pop(context);
                                  _loadData();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Save failed: $e')));
                                }
                              }
                            },
                            child: const Text('Save Template',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showStudentActionsSheet(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final mainTxt = isDark ? Colors.white : const Color(0xFF0F172A);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Student Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              const Color(0xFF06B6D4).withValues(alpha: 0.2),
                          child: Text(
                            student['name']?[0]?.toUpperCase() ?? 'S',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF06B6D4)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? '',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: mainTxt),
                              ),
                              Text(
                                'Roll No: ${student['roll_number'] ?? 'N/A'} · XP: ${student['xp_points'] ?? 0} · Streak: ${student['learning_streak'] ?? 0}d',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        ElevatedButton.icon(
                          onPressed: () async {
                            final success = await _showPenaltyDialog(student);
                            if (success && context.mounted) {
                              Navigator.pop(context); // close bottom sheet
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            foregroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          icon:
                              const Icon(Icons.warning_amber_rounded, size: 14),
                          label: const Text('Deduct XP',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // List of lockable tasks
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final earnedBadges =
                            (student['earned_badges'] as List<dynamic>? ?? []);
                        final isEarned = earnedBadges.contains(task['id']);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Text(task['icon'] ?? '🏆',
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task['name'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      if (task['description'] != null &&
                                          task['description']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          task['description'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Criteria: ${task['criteria'] ?? 'None'} · +${task['xp_reward']} XP',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isEarned
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '✅ Unlocked',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            final ok = await _apiService
                                                .unlockStudentTask(
                                                    student['id'], task['id']);
                                            if (ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Task "${task['name']}" unlocked for student!')),
                                              );
                                              // update locally
                                              setSheetState(() {
                                                earnedBadges.add(task['id']);
                                                student['xp_points'] =
                                                    (student['xp_points'] ??
                                                            0) +
                                                        (task['xp_reward']
                                                            as int);
                                              });
                                              _loadStudentProgress();
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Unlock failed: $e')),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF06B6D4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Unlock',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white)),
                                      ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _showPenaltyDialog(Map<String, dynamic> student) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apply Penalty',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Student: ${student['name']}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deductions are restricted to a maximum of 50 XP per penalty to ensure fair grading practices.',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Deduction Amount (XP) *',
                    hintText: 'Max 50 XP',
                    prefixIcon:
                        const Icon(Icons.exposure_minus_1_rounded, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final val = int.tryParse(value);
                    if (val == null || val <= 0) {
                      return 'Must be a positive integer';
                    }
                    if (val > 50) return 'Deduction cannot exceed 50 XP';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason *',
                    hintText: 'e.g. Disruption, cheating in exam',
                    prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF06B6D4), width: 2),
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Reason is required'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() == true) {
                  final amount = int.parse(amountController.text.trim());
                  final reason = reasonController.text.trim();

                  try {
                    final ok = await _apiService.applyStudentPenalty(
                        student['id'], amount, reason);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Deducted $amount XP penalty successfully.')),
                      );
                      // Update student score locally
                      setState(() {
                        student['xp_points'] =
                            (student['xp_points'] ?? 0) - amount;
                      });
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Penalty failed: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('Apply Penalty',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _buildRaritySelector(
      String activeRarity, void Function(String) onTap) {
    final rarities = [
      {
        'value': 'common',
        'label': 'Common',
        'color': const Color(0xFF10B981),
        'emoji': '🟢'
      },
      {
        'value': 'uncommon',
        'label': 'Uncommon',
        'color': const Color(0xFF06B6D4),
        'emoji': '🔵'
      },
      {
        'value': 'rare',
        'label': 'Rare',
        'color': const Color(0xFF8B5CF6),
        'emoji': '🟣'
      },
      {
        'value': 'epic',
        'label': 'Epic',
        'color': const Color(0xFFEC4899),
        'emoji': '🔥'
      },
    ];

    return Row(
      children: rarities.map((item) {
        final isSelected = activeRarity == item['value'];
        final color = item['color'] as Color;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => onTap(item['value'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected ? color : Colors.grey.withValues(alpha: 0.2),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item['emoji'] as String,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const headerColorGradient = LinearGradient(
      colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
    );

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(gradient: headerColorGradient),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Achievements & Tasks',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh Data',
                  onPressed: _loadData,
                ),
                if (_selectedTabIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 28),
                    onPressed: () => _showTaskFormDialog(),
                  ),
              ],
            ),
          ),

          // Tab Bar selector
          Container(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '📝 Task Templates'),
                Tab(text: '👥 Student Progress'),
              ],
              labelColor: const Color(0xFF06B6D4),
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
              indicatorColor: const Color(0xFF06B6D4),
              indicatorWeight: 3.0,
              labelStyle: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              unselectedLabelStyle: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.normal,
                  fontSize: 13),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF06B6D4))))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 40)),
                            const SizedBox(height: 12),
                            Text('Error: $_errorMessage',
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: const Color(0xFF06B6D4),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTasksTab(),
                            _buildProgressTab(isDark),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 80.0, horizontal: 20.0),
            child: Center(
              child: Column(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 54)),
                  const SizedBox(height: 16),
                  const Text('No Tasks created yet.',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                      'Click the "+" icon in the top right to create a new task.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () => _showTaskFormDialog(),
                      child: const Text('Create Task')),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AzureGrid<dynamic>(
      title: 'Task Templates',
      items: _tasks,
      searchMatcher: (task) =>
          '${task['name'] ?? ''} ${task['description'] ?? ''} ${task['rarity'] ?? ''}',
      filters: [
        if (_classes.isNotEmpty)
          AzureGridFilter<dynamic>(
            label: 'Class',
            options: _classes.map((c) => c.name).toSet().toList(),
            filterFn: (task, option) =>
                task['target_class'] == option || task['target_class'] == null,
          ),
        AzureGridFilter<dynamic>(
          label: 'Rarity',
          options: const ['Common', 'Uncommon', 'Rare', 'Epic'],
          filterFn: (task, option) =>
              (task['rarity']?.toString().toLowerCase() ?? 'common') ==
              option.toLowerCase(),
        ),
      ],
      columns: [
        AzureGridColumn<dynamic>(
          label: 'Icon & Title',
          width: 220.0,
          compare: (a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''),
          cellBuilder: (task) {
            return Row(
              children: [
                Text(task['icon'] ?? '🏆',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Description',
          width: 260.0,
          cellBuilder: (task) =>
              Text(task['description'] ?? 'No description provided.'),
        ),
        AzureGridColumn<dynamic>(
          label: 'Criteria',
          width: 220.0,
          cellBuilder: (task) => Text(task['criteria'] ?? 'N/A'),
        ),
        AzureGridColumn<dynamic>(
          label: 'Class',
          width: 120.0,
          compare: (a, b) =>
              (a['target_class'] ?? '').compareTo(b['target_class'] ?? ''),
          cellBuilder: (task) {
            final target = task['target_class'];
            if (target == null) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('All Classes',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              );
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                target,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
            );
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Rarity',
          width: 120.0,
          compare: (a, b) => (a['rarity'] ?? '').compareTo(b['rarity'] ?? ''),
          cellBuilder: (task) {
            final rarity = task['rarity']?.toString().toLowerCase() ?? 'common';
            Color color;
            switch (rarity) {
              case 'epic':
                color = const Color(0xFFEC4899);
                break;
              case 'rare':
                color = const Color(0xFF8B5CF6);
                break;
              case 'uncommon':
                color = const Color(0xFF06B6D4);
                break;
              default:
                color = const Color(0xFF10B981);
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                rarity.toUpperCase(),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            );
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'XP Reward',
          width: 120.0,
          compare: (a, b) =>
              (a['xp_reward'] ?? 0).compareTo(b['xp_reward'] ?? 0),
          cellBuilder: (task) {
            return Text(
              '+${task['xp_reward']} XP',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green),
            );
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Actions',
          width: 100.0,
          cellBuilder: (task) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showTaskFormDialog(taskToEdit: task),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _handleDeleteTask(task['id']),
                ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, task) {
        final rarity = task['rarity']?.toString().toUpperCase() ?? 'COMMON';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(task['icon'] ?? '🏆',
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task['name'] ?? '',
                              style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              rarity,
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task['description'] ?? 'No description provided.',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Criteria: ${task['criteria'] ?? 'N/A'}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600),
                      ),
                      if (task['target_class'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Class: ${task['target_class']}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.teal,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      '+${task['xp_reward']} XP',
                      style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 18, color: Colors.blueGrey),
                          onPressed: () =>
                              _showTaskFormDialog(taskToEdit: task),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.redAccent),
                          onPressed: () => _handleDeleteTask(task['id']),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Student list / progress tracking UI
  Widget _buildProgressTab(bool isDark) {
    if (_classes.isEmpty) {
      return const Center(child: Text('No classes assigned.'));
    }

    if (_isLoadingProgress) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF06B6D4)),
        ),
      );
    }

    if (_studentProgress.isEmpty) {
      return const Center(child: Text('No students found in this classroom.'));
    }

    return AzureGrid<dynamic>(
      title: 'Classroom Progress',
      items: _studentProgress,
      searchMatcher: (student) =>
          '${student['name'] ?? ''} ${student['class_name'] ?? ''}',
      filters: [
        if (_classes.isNotEmpty)
          AzureGridFilter<dynamic>(
            label: 'Class',
            options: _classes.map((c) => c.name).toSet().toList(),
            filterFn: (student, option) => student['class_name'] == option,
          ),
      ],
      columns: [
        AzureGridColumn<dynamic>(
          label: 'Student Name',
          width: 220.0,
          compare: (a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''),
          cellBuilder: (student) {
            return Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor:
                      const Color(0xFF06B6D4).withValues(alpha: 0.1),
                  child: Text(
                    student['name']?[0]?.toUpperCase() ?? 'S',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF06B6D4)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    student['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Roll No',
          width: 100.0,
          compare: (a, b) => (a['roll_number']?.toString() ?? '')
              .compareTo(b['roll_number']?.toString() ?? ''),
          cellBuilder: (student) {
            return Text(student['roll_number']?.toString() ?? 'N/A');
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Class',
          width: 100.0,
          compare: (a, b) =>
              (a['class_name'] ?? '').compareTo(b['class_name'] ?? ''),
          cellBuilder: (student) {
            return Text(student['class_name'] ?? 'N/A');
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'XP Points',
          width: 120.0,
          compare: (a, b) =>
              (a['xp_points'] ?? 0).compareTo(b['xp_points'] ?? 0),
          cellBuilder: (student) {
            return Text(
              '${student['xp_points'] ?? 0} XP',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
            );
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Streak',
          width: 100.0,
          compare: (a, b) =>
              (a['learning_streak'] ?? 0).compareTo(b['learning_streak'] ?? 0),
          cellBuilder: (student) {
            final streak = student['learning_streak'] ?? 0;
            if (streak > 0) {
              return Text('🔥 ${streak}d',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold));
            }
            return const Text('-');
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Badges Unlocked',
          width: 150.0,
          compare: (a, b) => (a['earned_badges'] as List<dynamic>? ?? [])
              .length
              .compareTo((b['earned_badges'] as List<dynamic>? ?? []).length),
          cellBuilder: (student) {
            final count =
                (student['earned_badges'] as List<dynamic>? ?? []).length;
            return Text('$count badge(s)');
          },
        ),
        AzureGridColumn<dynamic>(
          label: 'Actions',
          width: 120.0,
          cellBuilder: (student) {
            return ElevatedButton(
              onPressed: () => _showStudentActionsSheet(student),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Manage',
                  style: TextStyle(fontSize: 10, color: Colors.white)),
            );
          },
        ),
      ],
      mobileCardBuilder: (context, student) {
        final earnedBadgesCount =
            (student['earned_badges'] as List<dynamic>? ?? []).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _showStudentActionsSheet(student),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        const Color(0xFF06B6D4).withValues(alpha: 0.1),
                    child: Text(
                      student['name']?[0]?.toUpperCase() ?? 'S',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06B6D4)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student['name'] ?? '',
                          style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Class: ${student['class_name'] ?? 'N/A'} · Roll No: ${student['roll_number'] ?? 'N/A'} · Badges: $earnedBadgesCount',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${student['xp_points'] ?? 0} XP',
                        style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF06B6D4)),
                      ),
                      if ((student['learning_streak'] ?? 0) > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '🔥 ${student['learning_streak']}d streak',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

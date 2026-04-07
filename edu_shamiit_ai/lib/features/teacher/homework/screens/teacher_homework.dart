import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherHomework extends StatefulWidget {
  const TeacherHomework({super.key});

  @override
  State<TeacherHomework> createState() => _TeacherHomeworkState();
}

class _TeacherHomeworkState extends State<TeacherHomework> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedTab = 'Active';
  final List<String> _tabs = ['Active', 'Pending', 'Completed'];
  List<TeacherHomeworkAssignment> _homework = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = _selectedTab.toLowerCase();
      final homework = await _apiService.getHomeworkAssignments(status: status);
      setState(() {
        _homework = homework;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<TeacherHomeworkAssignment> get _filteredHomework {
    switch (_selectedTab) {
      case 'Pending':
        return _homework.where((h) => h.status == 'pending').toList();
      case 'Completed':
        return _homework.where((h) => h.status == 'completed').toList();
      default:
        return _homework.where((h) => h.status == 'active').toList();
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.isNegative) return 'Overdue';
    if (diff.inDays == 0) return 'Due Today';
    if (diff.inDays == 1) return 'Due Tomorrow';
    return 'Due in ${diff.inDays} days';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0F8),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFBE185D), Color(0xFFDB2777)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Homework',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _showCreateHomeworkDialog(),
                ),
              ],
            ),
          ),

          // Tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTab = tab);
                    _loadHomework();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFBE185D) : const Color(0xFFFCE7F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFFBE185D),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadHomework,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Homework list
          if (!_isLoading && _error == null)
            Expanded(
              child: _filteredHomework.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text(
                            'No $_selectedTab homework',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredHomework.length,
                      itemBuilder: (context, index) {
                        return _buildHomeworkCard(_filteredHomework[index]);
                      },
                    ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateHomeworkDialog(),
        backgroundColor: const Color(0xFFBE185D),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Homework',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildHomeworkCard(TeacherHomeworkAssignment homework) {
    final isOverdue = homework.isOverdue;
    final submissionRate = homework.submissionRate;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and class
          Row(
            children: [
              Expanded(
                child: Text(
                  homework.title,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBE185D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  homework.class_,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE185D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            homework.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Meta info
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: isOverdue ? Colors.red : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _getRelativeDate(homework.dueDate),
                style: TextStyle(
                  fontSize: 11,
                  color: isOverdue ? Colors.red : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.people, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${homework.submittedCount}/${homework.totalCount} submitted',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: submissionRate / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverdue ? Colors.red : const Color(0xFFBE185D),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(submissionRate).toInt()}% submitted',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showEditHomeworkDialog(homework),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBE185D)),
                  ),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _viewSubmissions(homework),
                  icon: const Icon(Icons.check_circle, size: 14),
                  label: const Text(
                    'Review',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateHomeworkDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? selectedClass;
    String? selectedSubject;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Homework'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Trigonometry Problems',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter homework details...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Class',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedClass = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedSubject = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    hintText: 'Select date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        // Update the text field
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _createHomework(
                  title: titleController.text,
                  description: descController.text,
                  classId: selectedClass ?? 'X-A',
                  subject: selectedSubject ?? 'Mathematics',
                  dueDate: DateTime.now().add(const Duration(days: 2)),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHomeworkDialog(TeacherHomeworkAssignment homework) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Homework'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: homework.title),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(text: homework.description),
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateHomework(homework);
            },
            child: const Text('Update'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteHomework(homework);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createHomework({
    required String title,
    required String description,
    required String classId,
    required String subject,
    required DateTime dueDate,
  }) async {
    try {
      await _apiService.createHomework(
        title: title,
        description: description,
        classId: classId,
        subject: subject,
        dueDate: dueDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Homework created successfully!')),
        );
        _loadHomework();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _updateHomework(TeacherHomeworkAssignment homework) async {
    try {
      await _apiService.updateHomework(
        homeworkId: homework.id,
        updates: {'status': 'completed'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Homework updated successfully!')),
        );
        _loadHomework();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteHomework(TeacherHomeworkAssignment homework) async {
    try {
      await _apiService.deleteHomework(homework.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Homework deleted successfully!')),
        );
        _loadHomework();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }

  void _viewSubmissions(TeacherHomeworkAssignment homework) {
    // Navigate to submissions screen or show dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing submissions for: ${homework.title}')),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherPaperBuilder extends StatefulWidget {
  const TeacherPaperBuilder({super.key});

  @override
  State<TeacherPaperBuilder> createState() => _TeacherPaperBuilderState();
}

class _TeacherPaperBuilderState extends State<TeacherPaperBuilder> {
  String _selectedClass = 'X-A';
  String _selectedSubject = 'Mathematics';
  final List<String> _classes = ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'];
  final List<String> _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English'];

  final List<Map<String, dynamic>> _questionBank = [
    {'id': '1', 'question': 'What is the formula for sin(A+B)?', 'type': 'Short Answer', 'marks': 2, 'chapter': 'Trigonometry'},
    {'id': '2', 'question': 'Prove that the sum of angles in a triangle is 180°', 'type': 'Long Answer', 'marks': 5, 'chapter': 'Geometry'},
    {'id': '3', 'question': 'Solve: x² + 5x + 6 = 0', 'type': 'Problem Solving', 'marks': 3, 'chapter': 'Algebra'},
    {'id': '4', 'question': 'Define Newton\'s Second Law of Motion', 'type': 'Short Answer', 'marks': 2, 'chapter': 'Laws of Motion'},
    {'id': '5', 'question': 'Calculate the area of a circle with radius 7cm', 'type': 'Problem Solving', 'marks': 3, 'chapter': 'Mensuration'},
  ];

  final List<Map<String, dynamic>> _selectedQuestions = [];

  int get _totalMarks => _selectedQuestions.fold<int>(0, (sum, q) => sum + (q['marks'] as int));

  Map<String, int> get _questionTypeCount {
    final counts = <String, int>{};
    for (var q in _selectedQuestions) {
      final type = q['type'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
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
                  'Paper Builder',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: () => _savePaper(),
                ),
              ],
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildDropdown('Class', _selectedClass, _classes, (value) {
                    setState(() => _selectedClass = value!);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown('Subject', _selectedSubject, _subjects, (value) {
                    setState(() => _selectedSubject = value!);
                  }),
                ),
              ],
            ),
          ),

          // Paper summary
          if (_selectedQuestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    _buildSummaryItem('${_selectedQuestions.length}', 'Questions'),
                    const SizedBox(width: 16),
                    _buildSummaryItem('$_totalMarks', 'Marks'),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: _questionTypeCount.entries.map((e) {
                          return Chip(
                            label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Question bank
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Text(
                              'Question Bank',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => _showAddQuestionDialog(),
                              tooltip: 'Add Question',
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _questionBank.length,
                          itemBuilder: (context, index) {
                            return _buildQuestionItem(_questionBank[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(vertical: 16),
                ),

                // Selected questions
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Selected Questions',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _selectedQuestions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('📄', style: TextStyle(fontSize: 48)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No questions selected',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click questions to add them',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _selectedQuestions.length,
                                itemBuilder: (context, index) {
                                  return _buildSelectedQuestionItem(_selectedQuestions[index], index);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.arrow_drop_down, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF4F46E5),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionItem(Map<String, dynamic> question) {
    final isSelected = _selectedQuestions.any((q) => q['id'] == question['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF4F46E5).withOpacity(0.3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (isSelected) {
                setState(() {
                  _selectedQuestions.removeWhere((q) => q['id'] == question['id']);
                });
              } else {
                setState(() {
                  _selectedQuestions.add(question);
                });
              }
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF4F46E5)),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['question'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        question['type'] as String,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${question['marks']} marks',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '• ${question['chapter']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedQuestionItem(Map<String, dynamic> question, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Text(
            '${index + 1}.',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['question'] as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${question['marks']} marks • ${question['type']}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {
              setState(() {
                _selectedQuestions.removeAt(index);
              });
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Question'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Question',
                  hintText: 'Enter your question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Question Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Short Answer', 'Long Answer', 'Problem Solving', 'Multiple Choice']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Marks',
                  hintText: 'Enter marks',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.star),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Chapter',
                  hintText: 'e.g., Trigonometry',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Question added to bank!')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _savePaper() {
    if (_selectedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select at least one question')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Paper saved successfully!')),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentHomework extends ConsumerStatefulWidget {
  const StudentHomework({super.key});

  @override
  ConsumerState<StudentHomework> createState() => _StudentHomeworkState();
}

class _StudentHomeworkState extends ConsumerState<StudentHomework> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Pending', 'Submitted', 'Graded'];
  List<dynamic> _homework = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomework();
  }

  Future<void> _loadHomework() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _homework = [
        {
          "id": "hw-1",
          "title": "Integration Practice Set — Ch.7",
          "subject": "Mathematics",
          "icon": "📐",
          "problems": "5 problems",
          "due": "Due TODAY 5:00 PM",
          "dueColor": const Color(0xFFEF4444),
          "description": "Solve all 5 problems from page 128-130. Show full working.",
          "details": "<b>Problems:</b><br>1. ∫(x²+3x)dx<br>2. ∫sin(2x)cos(x)dx<br>3. ∫e^x·sin(x)dx<br>4. ∫1/(x²+4)dx<br>5. ∫x·ln(x)dx<br><br><b>Instructions:</b> Show full working for each problem. Use substitution or integration by parts where necessary. Pages 128-130 of NCERT.",
          "reference": "📖 Reference: NCERT Ch.7 Pages 128-130",
          "status": "pending",
          "borderColor": const Color(0xFFEF4444),
          "bgColor": const Color(0xFFEEF2FF),
          "badgeBg": const Color(0xFFFEE2E2),
          "badgeText": "Mathematics",
          "badgeColor": const Color(0xFFEF4444),
        },
        {
          "id": "hw-2",
          "title": "Titration Lab Report — Acid-Base",
          "subject": "Chemistry",
          "icon": "⚗️",
          "problems": "Lab Report",
          "due": "Due: Tomorrow",
          "dueColor": const Color(0xFFD97706),
          "description": "Write a detailed lab report with aim, theory, observations, and conclusion.",
          "details": "<b>Format Required:</b><br>1. Aim of the experiment<br>2. Theory (acid-base neutralization)<br>3. Apparatus & chemicals used<br>4. Procedure with step-by-step instructions<br>5. Observations table (3 readings)<br>6. Calculations with formula<br>7. Result & Conclusion<br>8. Precautions (min 4)",
          "reference": "📄 Template: LabReport_Template.docx",
          "status": "pending",
          "borderColor": const Color(0xFFF59E0B),
          "bgColor": const Color(0xFFFEF3C7),
          "badgeBg": const Color(0xFFFEF3C7),
          "badgeText": "Chemistry",
          "badgeColor": const Color(0xFFD97706),
        },
        {
          "id": "hw-3",
          "title": "Essay: The Role of AI in Education",
          "subject": "English",
          "icon": "📖",
          "problems": "500 Words · Essay",
          "due": "Due: March 30",
          "dueColor": const Color(0xFF059669),
          "description": "Write a 500-word essay with pros, cons and personal perspective.",
          "details": "<b>Requirements:</b><br>• Word count: 500 words minimum<br>• Structure: Introduction, Body (3 paragraphs), Conclusion<br>• Cover: Pros of AI in education, Cons/risks, Your personal perspective<br>• Include at least 2 real-world examples<br>• Use formal academic language<br>• Cite sources if using external references",
          "reference": "📝 Rubric: Grammar 20%, Content 40%, Structure 20%, Originality 20%",
          "status": "pending",
          "borderColor": const Color(0xFF4F46E5),
          "bgColor": const Color(0xFFEEF2FF),
          "badgeBg": const Color(0xFFEEF2FF),
          "badgeText": "English",
          "badgeColor": const Color(0xFF4F46E5),
        },
      ];
      _isLoading = false;
    });
  }

  List<dynamic> get _filteredHomework {
    return _homework.where((hw) => hw['status'] == _tabs[_selectedTab].toLowerCase()).toList();
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
                const Expanded(
                  child: Text(
                    'Homework',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🤖', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 4),
                      Text(
                        'AI Help',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = index == _selectedTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      margin: EdgeInsets.only(right: index < _tabs.length - 1 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFDF2F8) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFFBE185D) : StudentColors.text3,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHomework.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('📝', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'No ${_tabs[_selectedTab].toLowerCase()} homework',
                              style: TextStyle(color: StudentColors.text3, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _filteredHomework.length,
                        itemBuilder: (context, index) {
                          return _buildHomeworkCard(_filteredHomework[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/student/aichat'),
        backgroundColor: const Color(0xFF4F46E5),
        child: const Text('🤖', style: TextStyle(fontSize: 20)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: hw['borderColor'] ?? StudentColors.primary,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: hw['badgeBg'],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hw['badgeText'],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: hw['badgeColor'],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                hw['problems'],
                style: TextStyle(color: StudentColors.text3, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            hw['title'],
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFamily: AppFonts.heading,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hw['description'],
            style: TextStyle(
              fontSize: 11,
              color: StudentColors.text3,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hw['due'],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hw['dueColor'],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showSubmitModal(context, hw),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '📤 Submit',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem('🏠', 'Home', false, () => context.go('/student/dashboard')),
          _buildNavItem('📊', 'Results', false, () => context.go('/student/results')),
          _buildNavItem('📝', 'Homework', true, null),
          _buildNavItem('📅', 'Events', false, () => context.go('/student/events')),
          _buildNavItem('👤', 'Profile', false, () => context.go('/student/profile')),
        ],
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmitModal(BuildContext context, Map<String, dynamic> hw) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '📤 Submit Homework',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF8FAFC),
                ),
                child: Column(
                  children: [
                    const Text('📁', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to upload file',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, DOC, JPG up to 10MB',
                      style: TextStyle(color: StudentColors.text3, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add notes for your teacher (optional)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessModal(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '📤 Submit Assignment',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 8),
            Text(
              'Submitted Successfully!',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your homework has been submitted. Your teacher will review it shortly.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
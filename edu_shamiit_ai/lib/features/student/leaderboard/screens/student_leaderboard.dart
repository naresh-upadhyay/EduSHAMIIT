import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentLeaderboard extends ConsumerStatefulWidget {
  const StudentLeaderboard({super.key});

  @override
  ConsumerState<StudentLeaderboard> createState() => _StudentLeaderboardState();
}

class _StudentLeaderboardState extends ConsumerState<StudentLeaderboard> {
  int _selectedTab = 0; // 0=Class Rank, 1=School Rank

  final List<Map<String, dynamic>> _classRanks = [
    {'rank': 1, 'name': 'Rahul Verma', 'score': '94.2%', 'xp': '3,120 XP', 'avatar': 'R'},
    {'rank': 2, 'name': 'Priya Mehta', 'score': '92.8%', 'xp': '2,680 XP', 'avatar': 'P'},
    {'rank': 3, 'name': 'Arjun Kumar (You)', 'score': '91.4%', 'xp': '2,450 XP', 'avatar': 'A', 'isUser': true},
    {'rank': 4, 'name': 'Sneha Patel', 'score': '89.6%', 'xp': '2,120 XP', 'avatar': 'S'},
    {'rank': 5, 'name': 'Vikram Singh', 'score': '88.2%', 'xp': '1,980 XP', 'avatar': 'V'},
    {'rank': 6, 'name': 'Ananya Gupta', 'score': '87.0%', 'xp': '1,850 XP', 'avatar': 'A'},
    {'rank': 7, 'name': 'Amit Tiwari', 'score': '86.1%', 'xp': '1,780 XP', 'avatar': 'A'},
    {'rank': 8, 'name': 'Kavya Nair', 'score': '85.5%', 'xp': '1,720 XP', 'avatar': 'K'},
  ];

  final List<Map<String, dynamic>> _schoolRanks = [
    {'rank': 14, 'name': 'Divya Sharma (X-B)', 'score': '92.5%', 'xp': '2,600 XP', 'avatar': 'D'},
    {'rank': 15, 'name': 'Rahul Verma (X-C)', 'score': '92.1%', 'xp': '2,550 XP', 'avatar': 'R'},
    {'rank': 16, 'name': 'Nikhil Singh (X-A)', 'score': '91.8%', 'xp': '2,500 XP', 'avatar': 'N'},
    {'rank': 17, 'name': 'Aditi Rao (X-B)', 'score': '91.6%', 'xp': '2,480 XP', 'avatar': 'A'},
    {'rank': 18, 'name': 'Arjun Kumar (You)', 'score': '91.4%', 'xp': '2,450 XP', 'avatar': 'A', 'isUser': true},
    {'rank': 19, 'name': 'Kunal Das (X-C)', 'score': '91.2%', 'xp': '2,400 XP', 'avatar': 'K'},
    {'rank': 20, 'name': 'Megha Iyer (X-A)', 'score': '90.8%', 'xp': '2,350 XP', 'avatar': 'M'},
    {'rank': 21, 'name': 'Siddharth Roy (X-D)', 'score': '90.3%', 'xp': '2,280 XP', 'avatar': 'S'},
  ];

  @override
  Widget build(BuildContext context) {
    final ranks = _selectedTab == 0 ? _classRanks : _schoolRanks;
    final userRank = ranks.firstWhere((r) => r['isUser'] == true);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
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
                  'Leaderboard',
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
                    color: Colors.white15,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🤖 Insights',
                    style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Tab Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildTabChip('🏫 Class Rank', 0),
                const SizedBox(width: 6),
                _buildTabChip('🏛️ School Rank', 1),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                // Your Position Card
                _buildYourPositionCard(userRank),
                
                const SizedBox(height: 12),
                
                // Top 3 Podium
                _buildTop3Podium(ranks),
                
                const SizedBox(height: 16),
                
                // Comparison Chart
                _buildComparisonCard(),
                
                const SizedBox(height: 12),
                
                // Rank List
                ...ranks.where((r) => r['rank'] > 3 && r['isUser'] != true).map((student) => _buildRankCard(student)),
                
                const SizedBox(height: 16),
                
                // AI Motivation
                _buildAIMotivation(),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? StudentColors.error : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : StudentColors.error,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYourPositionCard(Map<String, dynamic> userRank) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Position',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '#${userRank['rank']}',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userRank['name']!,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Class X-A · ${userRank['score']} · ${userRank['xp']}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text(
                    '🥉',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Top 5%',
                    style: TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTop3Podium(List<Map<String, dynamic>> ranks) {
    final top3 = ranks.where((r) => r['rank'] <= 3).toList()
      ..sort((a, b) => a['rank'].compareTo(b['rank']));
    
    // Reorder for podium: 2nd, 1st, 3rd
    final podiumOrder = [1, 0, 2];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: podiumOrder.map((idx) {
        if (idx >= top3.length) return const SizedBox.shrink();
        final student = top3[idx];
        final isUser = student['isUser'] == true;
        final heights = [100.0, 120.0, 80.0]; // 2nd, 1st, 3rd
        final colors = [
          const Color(0xFFC0C0C0), // Silver
          const Color(0xFFFFD700), // Gold
          const Color(0xFFCD7F32), // Bronze
        ];
        
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFFEEF2FF) : StudentColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors[idx], width: 2),
              boxShadow: isUser
                  ? [
                      BoxShadow(
                        color: StudentColors.primary.withOpacity(0.15),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  student['rank'] == 1 ? '🥇' : student['rank'] == 2 ? '🥈' : '🥉',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  student['name']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUser ? StudentColors.primary : StudentColors.text,
                    fontFamily: AppFonts.heading,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  student['score']!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: StudentColors.primary,
                  ),
                ),
                Text(
                  student['xp']!,
                  style: const TextStyle(fontSize: 9, color: StudentColors.text3),
                ),
                const Spacer(),
                Container(
                  height: heights[idx],
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUser
                          ? [StudentColors.primaryLight, const Color(0xFFE0E7FF)]
                          : [colors[idx].withOpacity(0.2), colors[idx].withOpacity(0.1)],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Center(
                    child: Text(
                      '#${student['rank']}',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors[idx],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
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
          const Text(
            '📊 Your Performance vs Class Average',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildComparisonRow('Attendance', 94, 88, StudentColors.primary),
          const SizedBox(height: 8),
          _buildComparisonRow('Avg Score', 91, 78, StudentColors.success),
          const SizedBox(height: 8),
          _buildComparisonRow('XP Points', 78, 62, StudentColors.warning),
          const SizedBox(height: 8),
          _buildComparisonRow('HW on Time', 100, 72, const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, int yours, int avg, Color color) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: StudentColors.text2),
          ),
        ),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: yours / 100,
              backgroundColor: StudentColors.border,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$yours%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'vs $avg%',
          style: const TextStyle(fontSize: 9, color: StudentColors.text3),
        ),
      ],
    );
  }

  Widget _buildRankCard(Map<String, dynamic> student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${student['rank']}',
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: StudentColors.text3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(50%),
            ),
            child: Center(child: Text(student['avatar'], style: const TextStyle(fontSize: 12))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name']!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${student['score']} · ${student['xp']}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIMotivation() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: StudentColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🤖 AI MOTIVATION',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You\'re just 1.4% behind Priya Mehta! Focus on Physics (+5%) and you can reach #2 by next term. Keep your streak going! 🔥',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF4338CA),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
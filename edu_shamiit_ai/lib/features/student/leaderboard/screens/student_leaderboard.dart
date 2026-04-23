import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';

class StudentLeaderboard extends ConsumerStatefulWidget {
  const StudentLeaderboard({super.key});

  @override
  ConsumerState<StudentLeaderboard> createState() => _StudentLeaderboardState();
}

class _StudentLeaderboardState extends ConsumerState<StudentLeaderboard> {
  int _selectedTab = 0; // 0=Class Rank, 1=School Rank

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(leaderboardProvider.notifier).fetchLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardState = ref.watch(leaderboardProvider);
    final entries = leaderboardState.entries;
    final userRank = leaderboardState.userRank;
    final userCgpa = leaderboardState.userCgpa;

    if (leaderboardState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (entries.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: Column(
          children: [
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
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.leaderboard, size: 64, color: StudentColors.text3),
                    SizedBox(height: 16),
                    Text(
                      'No leaderboard data',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: StudentColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Find user entry
    final userEntry = entries.firstWhere(
      (e) => e.studentId == 'current_user', // Would need to match actual user ID
      orElse: () => entries.first,
    );


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
                    color: Colors.white.withValues(alpha: 0.15),
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
                _buildYourPositionCard(userEntry, userRank, userCgpa),
                
                const SizedBox(height: 12),
                
                // Top 3 Podium
                _buildTop3Podium(entries),
                
                const SizedBox(height: 16),
                
                // Comparison Chart
                _buildComparisonCard(),
                
                const SizedBox(height: 12),
                
                // Rank List
                ...entries.where((e) => e.rank > 3 && e.studentId != 'current_user').map((student) => _buildRankCard(student)),
                
                const SizedBox(height: 16),
                
                // AI Motivation
                _buildAIMotivation(userEntry, userRank, entries),
                
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

  Widget _buildYourPositionCard(LeaderboardEntry userEntry, int userRank, double userCgpa) {
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
                '#$userRank',
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
                      userEntry.studentName,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'XP: ${userEntry.xpPoints} · Streak: ${userEntry.learningStreak} days',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Text(
                    '🏆',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CGPA: ${userCgpa.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTop3Podium(List<LeaderboardEntry> entries) {
    final sortedEntries = List<LeaderboardEntry>.from(entries)..sort((a, b) => a.rank.compareTo(b.rank));
    final top3 = sortedEntries.take(3).toList();
    
    // Reorder for podium: 2nd, 1st, 3rd
    final podiumOrder = [1, 0, 2];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: podiumOrder.map((idx) {
        if (idx >= top3.length) return const SizedBox.shrink();
        final student = top3[idx];
        final isUser = student.studentId == 'current_user';
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
                        color: StudentColors.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  student.rank == 1 ? '🥇' : student.rank == 2 ? '🥈' : '🥉',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  student.studentName,
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
                  '${student.xpPoints} XP',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: StudentColors.primary,
                  ),
                ),
                Text(
                  'Streak: ${student.learningStreak}🔥',
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
                          : [colors[idx].withValues(alpha: 0.2), colors[idx].withValues(alpha: 0.1)],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Center(
                    child: Text(
                      '#${student.rank}',
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
            color: Colors.black.withValues(alpha: 0.04),
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

  Widget _buildRankCard(LeaderboardEntry student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            '${student.rank}',
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
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(child: Text(student.studentName[0], style: const TextStyle(fontSize: 12))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.studentName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${student.xpPoints} XP · ${student.learningStreak} day streak',
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

  Widget _buildAIMotivation(LeaderboardEntry userEntry, int userRank, List<LeaderboardEntry> allEntries) {
    // Calculate gap to next rank
    final higherEntries = allEntries.where((e) => e.rank < userRank).toList();
    if (higherEntries.isEmpty) {
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
              'Great job! You\'re in the top ranks. Maintain your streak and keep climbing! 🏆',
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
    final nextRankEntry = higherEntries.reduce((a, b) => a.rank < b.rank ? a : b);
    final gap = nextRankEntry.xpPoints - userEntry.xpPoints;
    
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
          Text(
            'You\'re just $gap XP behind ${nextRankEntry.studentName}! Focus on your studies and you can reach #${nextRankEntry.rank} by next term. Keep your ${userEntry.learningStreak} day streak going! 🔥',
            style: const TextStyle(
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
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';

class StudentAchievements extends StatefulWidget {
  const StudentAchievements({super.key});

  @override
  State<StudentAchievements> createState() => _StudentAchievementsState();
}

class _StudentAchievementsState extends State<StudentAchievements> {
  final StudentApiService _apiService = StudentApiService();
  List<Achievement> _achievements = [];
  List<Achievement> _lockedAchievements = [];
  int _totalXp = 0;
  int _classRank = 0;
  int _schoolRank = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    try {
      // Fetch earned achievements
      final earned = await _apiService.getAchievements(earnedOnly: true);
      // Fetch all achievements (including locked)
      final all = await _apiService.getAchievements();
      final locked = all.where((a) => a.isLocked).toList();
      
      // Calculate total XP
      final totalXp = earned.fold<int>(0, (sum, a) => sum + a.xpReward);
      
      setState(() {
        _achievements = earned;
        _lockedAchievements = locked;
        _totalXp = totalXp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  LinearGradient _getGradientForAchievement(Achievement achievement) {
    switch (achievement.category.toLowerCase()) {
      case 'academic':
        return const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]);
      case 'streak':
        return const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF59E0B)]);
      case 'attendance':
        return const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]);
      case 'science':
        return const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]);
      default:
        return const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]);
    }
  }

  String _getIconForAchievement(Achievement achievement) {
    switch (achievement.category.toLowerCase()) {
      case 'academic':
        return '🏆';
      case 'streak':
        return '🔥';
      case 'attendance':
        return '📅';
      case 'science':
        return '🔬';
      default:
        return '✅';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEB),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF78350F), Color(0xFFB45309)],
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
                  'Achievements',
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

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // XP Card
                  _buildXPCard(),
                  const SizedBox(height: 20),

                  // Badges section header
                  Row(
                    children: [
                      const Text(
                        'Your Badges',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: StudentColors.text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_achievements.length} earned',
                        style: TextStyle(
                          fontSize: 12,
                          color: StudentColors.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Achievements list
                  ..._achievements.map((achievement) => _buildAchievementCard(achievement, context)),
                  
                  const SizedBox(height: 20),

                  // Locked achievements header
                  Row(
                    children: [
                      const Text(
                        'In Progress',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: StudentColors.text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_lockedAchievements.length} locked',
                        style: TextStyle(
                          fontSize: 12,
                          color: StudentColors.text3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Locked achievements list
                  ..._lockedAchievements.map((achievement) => _buildLockedAchievementCard(achievement)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total XP Points',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '2,450',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '🎯 550 XP to next level',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              const Text(
                '🏅 3rd Place',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Class Rank',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '🎖 18th Place',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'School Rank',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, BuildContext ctx) {
    final icon = _getIconForAchievement(achievement);
    final gradient = _getGradientForAchievement(achievement);
    final earnedAtStr = achievement.earnedAt != null 
        ? '${achievement.earnedAt!.day}/${achievement.earnedAt!.month}/${achievement.earnedAt!.year}'
        : 'Recently';
    
    return GestureDetector(
      onTap: () => _showAchievementDetail(achievement, ctx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: StudentColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: StudentColors.text3,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '📅 $earnedAtStr · +${achievement.xpReward} XP',
                    style: TextStyle(
                      fontSize: 9,
                      color: StudentColors.text3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedAchievementCard(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🔒', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: StudentColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: StudentColors.text3,
                  ),
                ),
                const SizedBox(height: 8),
                // Show progress bar (simulated for locked achievements)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.3, // Placeholder progress
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'In progress...',
                  style: TextStyle(
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

  void _showAchievementDetail(Achievement achievement, BuildContext ctx) {
    final icon = _getIconForAchievement(achievement);
    final gradient = _getGradientForAchievement(achievement);
    final earnedAtStr = achievement.earnedAt != null 
        ? '${achievement.earnedAt!.day}/${achievement.earnedAt!.month}/${achievement.earnedAt!.year}'
        : 'Recently';
    
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: StudentColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.colors.first.withOpacity(0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(icon, style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      achievement.title,
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: StudentColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: gradient.colors.first.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '⭐ ${achievement.category}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: gradient.colors.first,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      achievement.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: StudentColors.text2,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDetailBox('📅', 'Earned', earnedAtStr),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDetailBox('⭐', 'XP Earned', '+${achievement.xpReward} XP'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailBox(String icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: StudentColors.text3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: StudentColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
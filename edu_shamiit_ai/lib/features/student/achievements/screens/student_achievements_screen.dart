import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:edu_shamiit_ai/core/providers/profile_provider.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class StudentAchievements extends ConsumerStatefulWidget {
  const StudentAchievements({super.key});

  @override
  ConsumerState<StudentAchievements> createState() =>
      _StudentAchievementsState();
}

class _StudentAchievementsState extends ConsumerState<StudentAchievements>
    with SingleTickerProviderStateMixin {
  final StudentApiService _apiService = StudentApiService();
  late TabController _tabController;

  StudentAchievementsDashboard? _dashboard;
  bool _isLoading = true;
  String _errorMessage = '';
  int _selectedTabIndex = 0; // 0: Badges, 1: Leaderboard, 2: XP Ledger
  int _selectedLeaderboardTab = 0; // 0: Class, 1: School
  String _badgeFilter = 'all'; // 'all', 'unlocked', 'locked'

  // Lazy loaded tab states
  List<LeaderboardEntry> _classLeaderboard = [];
  List<LeaderboardEntry> _schoolLeaderboard = [];
  List<XpTransaction> _xpHistory = [];
  bool _isLoadingLeaderboard = false;
  bool _isLoadingXpHistory = false;
  String _leaderboardError = '';
  String _xpHistoryError = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
      _onTabChanged();
    });
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final data = await _apiService.getAchievementsDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _isLoading = false;
      });
      // Trigger lazy load if we are already on a non-default tab on reload
      _onTabChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onTabChanged() {
    if (_selectedTabIndex == 1) {
      final currentList =
          _selectedLeaderboardTab == 0 ? _classLeaderboard : _schoolLeaderboard;
      if (currentList.isEmpty) {
        _loadLeaderboard();
      }
    } else if (_selectedTabIndex == 2 && _xpHistory.isEmpty) {
      _loadXpHistory();
    }
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLeaderboard = true;
      _leaderboardError = '';
    });
    try {
      final scope = _selectedLeaderboardTab == 0 ? 'class' : 'school';
      final list = await _apiService.getLeaderboard(scope: scope, limit: 100);
      if (!mounted) return;
      setState(() {
        if (_selectedLeaderboardTab == 0) {
          _classLeaderboard = list;
        } else {
          _schoolLeaderboard = list;
        }
        _isLoadingLeaderboard = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _leaderboardError = e.toString().replaceAll('Exception: ', '');
        _isLoadingLeaderboard = false;
      });
    }
  }

  Future<void> _loadXpHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingXpHistory = true;
      _xpHistoryError = '';
    });
    try {
      final list = await _apiService.getXpHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _xpHistory = list;
        _isLoadingXpHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _xpHistoryError = e.toString().replaceAll('Exception: ', '');
        _isLoadingXpHistory = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadDashboard();
    if (_selectedTabIndex == 1) {
      await _loadLeaderboard();
    } else if (_selectedTabIndex == 2) {
      await _loadXpHistory();
    }
  }

  LinearGradient _getRarityGradient(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'epic':
      case 'rare':
        return const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'uncommon':
        return const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'common':
      default:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'epic':
      case 'rare':
        return const Color(0xFF8B5CF6);
      case 'uncommon':
        return const Color(0xFF06B6D4);
      case 'common':
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? StudentColors.darkBackground : StudentColors.background;
    final cardColor =
        isDark ? StudentColors.darkSurface : StudentColors.surface;
    final textColor = isDark ? StudentColors.darkText : StudentColors.text;
    final subTextColor = isDark ? StudentColors.darkText2 : StudentColors.text2;
    final borderColor =
        isDark ? StudentColors.darkBorder : StudentColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(StudentColors.primary)),
                  SizedBox(height: 16),
                  Text(
                    'Loading your achievements...',
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        color: StudentColors.text3),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load Achievements',
                          style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: StudentColors.text3),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadDashboard,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StudentColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Retry',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fixed gradient header
                        _buildHeader(context, isDark),

                        // Stats section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Column(
                            children: [
                              _buildXPCard(
                                  cardColor, textColor, subTextColor, isDark),
                              const SizedBox(height: 12),
                              _buildQuickRanks(
                                  cardColor, textColor, subTextColor, isDark),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),

                        // Sticky tab bar
                        Container(
                          color: bgColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: '🎖️ Badges'),
                              Tab(text: '📊 Leaderboard'),
                              Tab(text: '📜 XP Ledger'),
                            ],
                            labelColor:
                                isDark ? Colors.white : StudentColors.primary,
                            unselectedLabelColor: StudentColors.text3,
                            indicatorColor: StudentColors.primary,
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

                        // Tab content displayed inline
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16,
                              Responsive.isMobile(context) ? 80.0 : 16.0),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _selectedTabIndex == 0
                                ? _buildBadgesTab(cardColor, textColor,
                                    subTextColor, borderColor, isDark)
                                : _selectedTabIndex == 1
                                    ? _buildLeaderboardTab(cardColor, textColor,
                                        subTextColor, borderColor, isDark)
                                    : _buildXpHistoryTab(cardColor, textColor,
                                        subTextColor, borderColor, isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => safeGoBack(context, '/student/dashboard'),
              ),
              const SizedBox(width: 8),
              const Text(
                'Achievements & XP',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
                onPressed: _handleRefresh,
              ),
              const SizedBox(width: 8),
              if (_dashboard != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Text('⚡ ', style: TextStyle(fontSize: 14)),
                      Text(
                        'LVL ${((_dashboard!.xpPoints) / 1000).floor() + 1}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildXPCard(
      Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    final xp = _dashboard?.xpPoints ?? 0;
    final level = (xp / 1000).floor() + 1;
    final prevLevelXp = (level - 1) * 1000;
    final nextLevelXp = level * 1000;
    final xpInCurrentLevel = xp - prevLevelXp;
    final xpNeededForNextLevel = nextLevelXp - xp;
    final double levelProgress = xpInCurrentLevel / 1000.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                StudentColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border:
            Border.all(color: StudentColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL XP POINTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: subTextColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    xp.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},'),
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'LEVEL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        level.toString(),
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level Progression',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor),
              ),
              Text(
                '$xpInCurrentLevel/1000 XP',
                style: TextStyle(
                    fontSize: 11,
                    color: subTextColor,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: levelProgress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔥 Streak: ${_dashboard?.learningStreak ?? 0} Days (Best: ${_dashboard?.bestStreak ?? 0})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
              ),
              Text(
                '🎯 $xpNeededForNextLevel XP to Level ${level + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: StudentColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRanks(
      Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    final classRank = _dashboard?.classRank ?? 1;
    final schoolRank = _dashboard?.schoolRank ?? 1;

    String getRankSuffix(int rank) {
      if (rank >= 11 && rank <= 13) return 'th';
      switch (rank % 10) {
        case 1:
          return 'st';
        case 2:
          return 'nd';
        case 3:
          return 'rd';
        default:
          return 'th';
      }
    }

    Widget buildRankBox(
        String title, int rank, String icon, Color accentColor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    StudentColors.border.withValues(alpha: isDark ? 0.1 : 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: subTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    rank.toString(),
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    getRankSuffix(rank),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rank == 1
                        ? '👑 Leader'
                        : rank <= 3
                            ? '🥉 Podium'
                            : 'Ranked',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: rank <= 3 ? const Color(0xFFF59E0B) : subTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildRankBox('Class Rank', classRank, '🏫', const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        buildRankBox('School Rank', schoolRank, '🌐', const Color(0xFF06B6D4)),
      ],
    );
  }

  // ============================================
  // BADGES TAB
  // ============================================
  Widget _buildBadgesTab(Color cardColor, Color textColor, Color subTextColor,
      Color borderColor, bool isDark) {
    final unlocked = _dashboard?.unlockedAchievements ?? [];
    final locked = _dashboard?.lockedAchievements ?? [];

    List<Achievement> displayList = [];
    if (_badgeFilter == 'all') {
      displayList = [...unlocked, ...locked];
    } else if (_badgeFilter == 'unlocked') {
      displayList = unlocked;
    } else if (_badgeFilter == 'locked') {
      displayList = locked;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterPill('all',
                  'All Badges (${unlocked.length + locked.length})', isDark),
              const SizedBox(width: 8),
              _buildFilterPill(
                  'unlocked', 'Unlocked (${unlocked.length})', isDark),
              const SizedBox(width: 8),
              _buildFilterPill('locked', 'Locked (${locked.length})', isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (displayList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Text(
                'No badges found matching filter.',
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: Responsive.value<int>(
                context,
                mobile: 2,
                tablet: 4,
                desktop: 5,
              ),
              childAspectRatio: Responsive.value<double>(
                context,
                mobile: 0.82,
                tablet: 0.95,
                desktop: 1.0,
              ),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final achievement = displayList[index];
              return _buildAchievementGridCard(
                  achievement, cardColor, textColor, subTextColor, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildFilterPill(String filter, String label, bool isDark) {
    final isSelected = _badgeFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _badgeFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? StudentColors.primary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : StudentColors.text3,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementGridCard(Achievement achievement, Color cardColor,
      Color textColor, Color subTextColor, bool isDark) {
    final rarityGradient = _getRarityGradient(achievement.rarity);
    final rarityColor = _getRarityColor(achievement.rarity);
    final isLocked = achievement.isLocked;

    return GestureDetector(
      onTap: () =>
          _showAchievementDetailSheet(achievement, rarityGradient, rarityColor),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocked
                ? Colors.transparent
                : rarityColor.withValues(alpha: isDark ? 0.3 : 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isLocked
                  ? Colors.transparent
                  : rarityColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? const Color(0xFFF1F5F9)
                            .withValues(alpha: isDark ? 0.1 : 1.0)
                        : Colors.transparent,
                    gradient: isLocked ? null : rarityGradient,
                    shape: BoxShape.circle,
                    boxShadow: isLocked
                        ? null
                        : [
                            BoxShadow(
                              color: rarityColor.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Center(
                    child: Text(
                      isLocked ? '🔒' : (achievement.icon ?? '🏆'),
                      style: TextStyle(fontSize: isLocked ? 20 : 28),
                    ),
                  ),
                ),
                if (isLocked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🔒', style: TextStyle(fontSize: 8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isLocked ? subTextColor : textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: StudentColors.text3,
                height: 1.3,
              ),
            ),
            const Spacer(),
            if (isLocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 4,
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: achievement.progress / 100.0,
                    child: Container(
                      color: rarityColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${achievement.progress.toStringAsFixed(0)}% Done',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: rarityColor,
                ),
              ),
            ] else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${achievement.xpReward} XP',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: rarityColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardScopeButton(int index, String label) {
    final isSelected = _selectedLeaderboardTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedLeaderboardTab = index;
          });
          final list = index == 0 ? _classLeaderboard : _schoolLeaderboard;
          if (list.isEmpty) {
            _loadLeaderboard();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab(Color cardColor, Color textColor,
      Color subTextColor, Color borderColor, bool isDark) {
    final entries =
        _selectedLeaderboardTab == 0 ? _classLeaderboard : _schoolLeaderboard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildLeaderboardScopeButton(0, '🏫 Class Board'),
              _buildLeaderboardScopeButton(1, '🌐 School Board'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingLeaderboard && entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: StudentColors.primary),
            ),
          )
        else if (_leaderboardError.isNotEmpty && entries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text('Failed to load: $_leaderboardError',
                      style: TextStyle(color: textColor, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadLeaderboard,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else
          AzureGrid<LeaderboardEntry>(
            title: _selectedLeaderboardTab == 0
                ? 'Class Leaderboard'
                : 'School Leaderboard',
            items: entries,
            disableVerticalScroll: true,
            searchMatcher: (entry) => entry.fullName,
            filters: _selectedLeaderboardTab == 1
                ? [
                    AzureGridFilter<LeaderboardEntry>(
                      label: 'Class',
                      options: entries.map((e) => e.className).toSet().toList()
                        ..removeWhere((e) => e.isEmpty)
                        ..sort(),
                      filterFn: (entry, option) => entry.className == option,
                    )
                  ]
                : null,
            columns: [
              AzureGridColumn<LeaderboardEntry>(
                label: 'Rank',
                width: 80.0,
                compare: (a, b) => a.rank.compareTo(b.rank),
                cellBuilder: (entry) {
                  if (entry.rank == 1) {
                    return const Text('🥇', style: TextStyle(fontSize: 18));
                  } else if (entry.rank == 2) {
                    return const Text('🥈', style: TextStyle(fontSize: 18));
                  } else if (entry.rank == 3) {
                    return const Text('🥉', style: TextStyle(fontSize: 18));
                  } else {
                    return Text(entry.rank.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold));
                  }
                },
              ),
              AzureGridColumn<LeaderboardEntry>(
                label: 'Student',
                width: 250.0,
                compare: (a, b) => a.fullName.compareTo(b.fullName),
                cellBuilder: (entry) {
                  final myProfileState = ref.watch(profileProvider);
                  final myStudentId = myProfileState.profile?.id ?? '';
                  final isMe = entry.studentId == myStudentId;
                  return Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          entry.fullName.isNotEmpty
                              ? entry.fullName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.fullName + (isMe ? ' (You)' : ''),
                          style: TextStyle(
                            fontWeight:
                                isMe ? FontWeight.bold : FontWeight.normal,
                            color: isMe ? StudentColors.primary : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              AzureGridColumn<LeaderboardEntry>(
                label: 'Class',
                width: 100.0,
                compare: (a, b) => a.className.compareTo(b.className),
                cellBuilder: (entry) =>
                    Text(entry.className.isEmpty ? '-' : entry.className),
              ),
              AzureGridColumn<LeaderboardEntry>(
                label: 'Streak',
                width: 100.0,
                compare: (a, b) => a.learningStreak.compareTo(b.learningStreak),
                cellBuilder: (entry) {
                  if (entry.learningStreak > 0) {
                    return Text('🔥 ${entry.learningStreak}d',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold));
                  }
                  return const Text('-');
                },
              ),
              AzureGridColumn<LeaderboardEntry>(
                label: 'XP',
                width: 100.0,
                compare: (a, b) => a.xpPoints.compareTo(b.xpPoints),
                cellBuilder: (entry) {
                  return Text('${entry.xpPoints} XP',
                      style: const TextStyle(fontWeight: FontWeight.bold));
                },
              ),
            ],
            mobileCardBuilder: (context, entry) {
              final myProfileState = ref.watch(profileProvider);
              final myStudentId = myProfileState.profile?.id ?? '';
              final isMe = entry.studentId == myStudentId;
              Widget rankWidget;
              if (entry.rank == 1) {
                rankWidget = const Text('🥇', style: TextStyle(fontSize: 20));
              } else if (entry.rank == 2) {
                rankWidget = const Text('🥈', style: TextStyle(fontSize: 20));
              } else if (entry.rank == 3) {
                rankWidget = const Text('🥉', style: TextStyle(fontSize: 20));
              } else {
                rankWidget = Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.rank.toString(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: subTextColor),
                  ),
                );
              }

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe
                      ? StudentColors.primary
                          .withValues(alpha: isDark ? 0.2 : 0.05)
                      : cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMe
                        ? StudentColors.primary.withValues(alpha: 0.4)
                        : borderColor.withValues(alpha: isDark ? 0.1 : 0.5),
                    width: isMe ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 32, child: Center(child: rankWidget)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  StudentColors.primary.withValues(alpha: 0.6),
                                  StudentColors.accent.withValues(alpha: 0.6),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              entry.fullName.isNotEmpty
                                  ? entry.fullName[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.fullName + (isMe ? ' (You)' : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isMe
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isMe
                                        ? StudentColors.primary
                                        : textColor,
                                  ),
                                ),
                                if (entry.className.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Class: ${entry.className}',
                                    style: TextStyle(
                                        fontSize: 10, color: subTextColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entry.learningStreak > 0)
                      Text(
                        '🔥 ${entry.learningStreak}d',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B)),
                      )
                    else
                      const Text('-',
                          style: TextStyle(
                              fontSize: 11, color: StudentColors.text3)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${entry.xpPoints} XP',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isMe ? StudentColors.primary : textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildXpHistoryTab(Color cardColor, Color textColor,
      Color subTextColor, Color borderColor, bool isDark) {
    if (_isLoadingXpHistory && _xpHistory.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: StudentColors.primary));
    }

    if (_xpHistoryError.isNotEmpty && _xpHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text('Failed to load history: $_xpHistoryError',
                style: TextStyle(color: textColor, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadXpHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_xpHistory.isEmpty) {
      return const Center(
        child: Text('No XP transactions found.',
            style: TextStyle(fontSize: 13, color: StudentColors.text3)),
      );
    }

    String getSourceEmoji(String source) {
      switch (source.toLowerCase()) {
        case 'exam':
          return '📝';
        case 'homework':
          return '📝';
        case 'attendance':
          return '📅';
        case 'event_participation':
        case 'event_prize':
          return '🎭';
        case 'achievement':
        case 'teacher_task':
          return '🏆';
        case 'manual_penalty':
          return '⚠️';
        default:
          return '⚡';
      }
    }

    return AzureGrid<XpTransaction>(
      title: 'XP Ledger',
      items: _xpHistory,
      disableVerticalScroll: true,
      searchMatcher: (tx) => '${tx.description} ${tx.sourceType}',
      filters: [
        AzureGridFilter<XpTransaction>(
          label: 'Type',
          options: _xpHistory
              .map((tx) => tx.sourceType.replaceAll('_', ' ').toUpperCase())
              .toSet()
              .toList()
            ..sort(),
          filterFn: (tx, option) =>
              tx.sourceType.replaceAll('_', ' ').toUpperCase() == option,
        ),
      ],
      columns: [
        AzureGridColumn<XpTransaction>(
          label: 'Transaction',
          width: 250.0,
          compare: (a, b) => a.description.compareTo(b.description),
          cellBuilder: (tx) {
            return Row(
              children: [
                Text(getSourceEmoji(tx.sourceType),
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tx.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
        AzureGridColumn<XpTransaction>(
          label: 'Source',
          width: 150.0,
          compare: (a, b) => a.sourceType.compareTo(b.sourceType),
          cellBuilder: (tx) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (tx.amount < 0
                        ? StudentColors.error
                        : StudentColors.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tx.sourceType.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: tx.amount < 0
                      ? StudentColors.error
                      : StudentColors.success,
                ),
              ),
            );
          },
        ),
        AzureGridColumn<XpTransaction>(
          label: 'Date',
          width: 120.0,
          compare: (a, b) => a.createdAt.compareTo(b.createdAt),
          cellBuilder: (tx) {
            final formattedDate =
                '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}';
            return Text(formattedDate);
          },
        ),
        AzureGridColumn<XpTransaction>(
          label: 'Amount',
          width: 120.0,
          compare: (a, b) => a.amount.compareTo(b.amount),
          cellBuilder: (tx) {
            final isPenalty = tx.amount < 0;
            final sign = isPenalty ? '' : '+';
            return Text(
              '$sign${tx.amount} XP',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPenalty ? StudentColors.error : StudentColors.success,
              ),
            );
          },
        ),
      ],
      mobileCardBuilder: (context, tx) {
        final isPenalty = tx.amount < 0;
        final sign = isPenalty ? '' : '+';
        final amountColor =
            isPenalty ? StudentColors.error : StudentColors.success;
        final formattedDate =
            '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: borderColor.withValues(alpha: isDark ? 0.1 : 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPenalty
                      ? StudentColors.error.withValues(alpha: 0.1)
                      : StudentColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  getSourceEmoji(tx.sourceType),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tx.sourceType.replaceAll('_', ' ').toUpperCase()} · $formattedDate',
                      style: const TextStyle(
                          fontSize: 9,
                          color: StudentColors.text3,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                '$sign${tx.amount} XP',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: amountColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // DETAILED MODAL BOTTOM SHEET
  // ============================================
  void _showAchievementDetailSheet(
      Achievement achievement, LinearGradient gradient, Color rarityColor) {
    final formattedDate = achievement.earnedAt != null
        ? '${achievement.earnedAt!.day}/${achievement.earnedAt!.month}/${achievement.earnedAt!.year}'
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetColor =
            isDark ? StudentColors.darkSurface : StudentColors.surface;
        final txtColor = isDark ? StudentColors.darkText : StudentColors.text;
        final subTxtColor =
            isDark ? StudentColors.darkText2 : StudentColors.text2;

        return Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottomsheet indicator line
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Badge glow container
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: achievement.isLocked ? null : gradient,
                  color: achievement.isLocked
                      ? const Color(0xFFF1F5F9)
                          .withValues(alpha: isDark ? 0.1 : 1)
                      : null,
                  shape: BoxShape.circle,
                  boxShadow: achievement.isLocked
                      ? null
                      : [
                          BoxShadow(
                            color: rarityColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Text(
                  achievement.isLocked ? '🔒' : (achievement.icon ?? '🏆'),
                  style: TextStyle(fontSize: achievement.isLocked ? 32 : 44),
                ),
              ),
              const SizedBox(height: 18),

              // Title & Description
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: txtColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  achievement.rarity.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: rarityColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subTxtColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Info Row (Criteria, XP Reward)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('🏆 XP Reward',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: StudentColors.text3,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '+${achievement.xpReward} XP',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: rarityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(
                            achievement.isLocked ? '⚡ Status' : '📅 Earned',
                            style: const TextStyle(
                                fontSize: 10,
                                color: StudentColors.text3,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            achievement.isLocked
                                ? '${achievement.progress.toStringAsFixed(0)}% Locked'
                                : (formattedDate ?? 'Recently'),
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: achievement.isLocked
                                  ? Colors.grey
                                  : StudentColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

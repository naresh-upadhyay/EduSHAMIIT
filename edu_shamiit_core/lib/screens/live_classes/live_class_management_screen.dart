import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/tab_url_sync.dart';
import 'providers/live_class_management_provider.dart';
import 'tabs/join_and_conduct_tab.dart';
import 'tabs/recordings_tab.dart';
import 'tabs/white_board_tab.dart';
import 'utils/live_class_theme.dart';

class LiveClassManagementScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const LiveClassManagementScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<LiveClassManagementScreen> createState() => _LiveClassManagementScreenState();
}

class _LiveClassManagementScreenState extends ConsumerState<LiveClassManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final safeTab = widget.initialTabIndex.clamp(0, 2);
      if (safeTab != 0) {
        ref.read(liveClassManagementProvider.notifier).setTab(safeTab);
      }
      ref.read(liveClassManagementProvider.notifier).fetchInitialData();
    });
  }

  @override
  void didUpdateWidget(covariant LiveClassManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      final safeTab = widget.initialTabIndex.clamp(0, 2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveClassManagementProvider.notifier).setTab(safeTab);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveClassManagementProvider);
    final currentTab = state.selectedTabIndex.clamp(0, 2);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Common Top Header Banner
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Subtitle Row
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: LiveClassTheme.primary(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Class Management',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create, schedule, conduct and manage online live classes, recordings and interactive whiteboard',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 16),

                // STRICT SCOPE: 3 PRIMARY TABS
                // 1. Join & Conduct
                // 2. Recordings
                // 3. White Board (Offline Classroom Mode)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPrimaryTab('Join & Conduct', 0, currentTab, isDark),
                      const SizedBox(width: 24),
                      _buildPrimaryTab('Recordings', 1, currentTab, isDark),
                      const SizedBox(width: 24),
                      _buildPrimaryTab('White Board', 2, currentTab, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Tab View
          Expanded(
            child: IndexedStack(
              index: currentTab,
              children: const [
                JoinAndConductTab(),
                RecordingsTab(),
                WhiteBoardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryTab(String label, int index, int currentIndex, bool isDark) {
    final isSelected = index == currentIndex;
    final primaryColor = LiveClassTheme.primary(context);

    return InkWell(
      onTap: () {
        ref.read(liveClassManagementProvider.notifier).setTab(index);
        updateTabUrl('/admin/live-classes', index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Color.lerp(primaryColor, Colors.white, 0.4) ?? primaryColor : primaryColor)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

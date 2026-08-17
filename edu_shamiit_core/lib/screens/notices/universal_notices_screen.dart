import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'providers/notice_provider.dart';
import 'widgets/notice_header_bar.dart';
import 'widgets/notice_tabs_bar.dart';
import 'widgets/notice_filter_bar.dart';
import 'widgets/notice_active_filter_chips.dart';
import 'widgets/notice_table_view.dart';
import 'widgets/notice_card_view.dart';
import 'widgets/notice_analytics_sidebar.dart';
import 'widgets/notice_pagination_bar.dart';

class UniversalNoticesScreen extends ConsumerStatefulWidget {
  const UniversalNoticesScreen({super.key});

  @override
  ConsumerState<UniversalNoticesScreen> createState() => _UniversalNoticesScreenState();
}

class _UniversalNoticesScreenState extends ConsumerState<UniversalNoticesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(noticeProvider.notifier).refreshAll();
    });
  }

  void _openAdvancedFiltersDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final state = ref.watch(noticeProvider);
        final notifier = ref.read(noticeProvider.notifier);

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Advanced Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date Range Picker Button
              OutlinedButton.icon(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (range != null) {
                    notifier.setDateRange(range.start, range.end);
                  }
                },
                icon: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  state.fromDate != null
                      ? 'Date Range Selected'
                      : 'Filter by Date Range',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Reset All Action
              ElevatedButton(
                onPressed: () {
                  notifier.resetFilters();
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                child: const Text('Apply & Reset Filters'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final state = ref.watch(noticeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userRole = authState.userData?['role']?.toString() ?? authState.role.name;
    final currentUserId = authState.userData?['id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isExtraWideDesktop = constraints.maxWidth >= 1400;
            final isMobile = constraints.maxWidth < 768;

            return RefreshIndicator(
              onRefresh: () => ref.read(noticeProvider.notifier).refreshAll(),
              color: const Color(0xFF4F46E5),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 20,
                  vertical: isMobile ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header Bar
                    NoticeHeaderBar(userRole: userRole),

                    // 2. Role-adapted Tabs Bar
                    NoticeTabsBar(userRole: userRole),
                    const SizedBox(height: 14),

                    // 3. Search & Filter Bar
                    NoticeFilterBar(
                      onOpenAdvancedFilters: () => _openAdvancedFiltersDrawer(context),
                    ),

                    // 4. Active Filters Chips
                    const NoticeActiveFilterChips(),
                    const SizedBox(height: 14),

                    // 5. Main Content Area (2-column layout only when screen width >= 1400px, otherwise full-width for perfect readability)
                    if (isExtraWideDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Table / Cards + Pagination
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildNoticeListContent(state, isDark, userRole, currentUserId),
                                const SizedBox(height: 16),
                                const NoticePaginationBar(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Right Column: Analytics & Quick Actions Panel (320px)
                          SizedBox(
                            width: 320,
                            child: NoticeAnalyticsSidebar(userRole: userRole),
                          ),
                        ],
                      )
                    else
                      // Standard Desktop, Laptop, Tablet & Mobile Layout (Full Width Data Grid)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildNoticeListContent(state, isDark, userRole, currentUserId),
                          const SizedBox(height: 16),
                          const NoticePaginationBar(),
                          const SizedBox(height: 24),
                          NoticeAnalyticsSidebar(userRole: userRole),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoticeListContent(NoticeState state, bool isDark, String userRole, String currentUserId) {
    if (state.isLoading) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    if (state.error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: Colors.red),
            const SizedBox(height: 8),
            Text('Error loading notices: ${state.error}', style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(noticeProvider.notifier).fetchNotices(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.notices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_off_outlined, size: 28, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 14),
            Text(
              'No notices found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.hasActiveFilters
                  ? 'Try adjusting your search or active filters.'
                  : 'There are no active notices published in this category yet.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            if (state.hasActiveFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.read(noticeProvider.notifier).resetFilters(),
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }

    if (state.isTableView) {
      return NoticeTableView(
        notices: state.notices,
        userRole: userRole,
        currentUserId: currentUserId,
      );
    } else {
      return NoticeCardView(
        notices: state.notices,
        userRole: userRole,
        currentUserId: currentUserId,
      );
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/book_provider.dart';
import 'providers/member_provider.dart';
import 'providers/circulation_provider.dart';
import 'widgets/book_header_bar.dart';
import 'widgets/book_kpi_cards.dart';
import 'widgets/book_filter_bar.dart';
import 'widgets/book_table.dart';
import 'widgets/book_details_drawer.dart';
import 'widgets/drawers/book_access_drawer.dart';
import 'widgets/member_header_bar.dart';
import 'widgets/member_kpi_cards.dart';
import 'widgets/member_filter_bar.dart';
import 'widgets/member_table.dart';
import 'widgets/member_details_drawer.dart';
import 'widgets/circulation_header_bar.dart';
import 'widgets/circulation_tab_view.dart';
import 'providers/request_provider.dart';
import 'widgets/request_header_bar.dart';
import 'widgets/request_tab_view.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';



class LibraryManagementScreen extends ConsumerStatefulWidget {
  const LibraryManagementScreen({super.key});

  @override
  ConsumerState<LibraryManagementScreen> createState() => _LibraryManagementScreenState();
}

class _LibraryManagementScreenState extends ConsumerState<LibraryManagementScreen> {
  final List<String> _tabs = [
    'Overview',
    'Books',
    'Members',
    'Issue / Return',
    'Requests',
    'Reports',
    'Settings',
  ];


  @override
  Widget build(BuildContext context) {
    final bookState = ref.watch(bookProvider);
    final bookNotifier = ref.read(bookProvider.notifier);
    final memberState = ref.watch(memberProvider);
    final memberNotifier = ref.read(memberProvider.notifier);
    final circulationState = ref.watch(circulationProvider);
    final requestState = ref.watch(requestProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);


    // Show toast / snackbar on book status update
    ref.listen<BookState>(bookProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        bookNotifier.clearNotifications();
      } else if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(next.successMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        bookNotifier.clearNotifications();
      }
    });

    // Show toast / snackbar on member status update
    ref.listen<MemberState>(memberProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        memberNotifier.clearNotifications();
      } else if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(next.successMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        memberNotifier.clearNotifications();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Main Body Layout
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Row (Books, Members, Issue/Return or Requests)
              if (bookState.activeTab == 2)
                const MemberHeaderBar()
              else if (bookState.activeTab == 3)
                const CirculationHeaderBar()
              else if (bookState.activeTab == 4)
                const RequestHeaderBar()
              else
                const BookHeaderBar(),


              // 2. Sub-Navigation Tabs Bar (Overview, Books [8,456], Members [1,284], Issue/Return [268], Requests [18]...)
              _buildSubTabBar(bookState, memberState, circulationState, requestState, bookNotifier, isDark, isDesktop),

              // 3. Tab Content Area
              Expanded(
                child: bookState.activeTab == 1
                    ? _buildBooksTabContent(isDesktop)
                    : (bookState.activeTab == 2
                        ? _buildMembersTabContent(isDesktop)
                        : (bookState.activeTab == 3
                            ? const CirculationTabView()
                            : (bookState.activeTab == 4
                                ? const RequestTabView()
                                : _buildOtherTabPlaceholder(bookState.activeTab, isDark)))),
              ),

            ],
          ),

          // 4A. Right Slide-Over Book Details Drawer
          if (bookState.isDrawerOpen && bookState.selectedBook != null) ...[
            if (!isDesktop)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => bookNotifier.closeDrawer(),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
            const Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: BookDetailsDrawer(),
            ),
          ],

          // 4B. Right Slide-Over Digital Access Management Drawer
          if (bookState.isAccessDrawerOpen && bookState.selectedBook != null) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => bookNotifier.closeAccessDrawer(),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: BookAccessDrawer(book: bookState.selectedBook!),
            ),
          ],

          // 4C. Right Slide-Over Member Details Drawer
          if (memberState.isDrawerOpen && memberState.selectedMember != null) ...[
            if (!isDesktop)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => memberNotifier.closeDrawer(),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
            const Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: MemberDetailsDrawer(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTabBar(
    BookState bookState,
    MemberState memberState,
    CirculationState circulationState,
    RequestState requestState,
    BookNotifier notifier,
    bool isDark,
    bool isDesktop,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16),
        child: Row(
          children: List.generate(_tabs.length, (idx) {
            final isSelected = bookState.activeTab == idx;
            final title = _tabs[idx];

            return InkWell(
              onTap: () => notifier.setActiveTab(idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                    if (idx == 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          bookState.totalRecords > 0
                              ? '${bookState.totalRecords}'
                              : (bookState.searchQuery.isNotEmpty ||
                                      bookState.selectedFormatFilter != 'ALL' ||
                                      bookState.selectedBookType != null ||
                                      bookState.selectedCategory != 'All Categories' ||
                                      bookState.selectedAuthor != 'All Authors' ||
                                      bookState.selectedPublisher != 'All Publishers' ||
                                      bookState.selectedAvailability != 'ALL'
                                  ? '0'
                                  : '${bookState.stats.totalTitles}'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ] else if (idx == 2) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          memberState.totalRecords > 0
                              ? '${memberState.totalRecords}'
                              : '${memberState.stats.totalMembers}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ] else if (idx == 3) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          circulationState.stats.totalTransactions > 0
                              ? '${circulationState.stats.totalTransactions}'
                              : (circulationState.totalTransactions > 0 ? '${circulationState.totalTransactions}' : '0'),

                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ] else if (idx == 4) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          requestState.total > 0
                              ? '${requestState.total}'
                              : '${requestState.kpis.totalRequests}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],

                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }


  Widget _buildBooksTabContent(bool isDesktop) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookKpiCards(),
          BookFilterBar(),
          BookTable(),
          SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildMembersTabContent(bool isDesktop) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemberKpiCards(),
          MemberFilterBar(),
          MemberTable(),
          SizedBox(height: 36),
        ],
      ),
    );
  }


  Widget _buildOtherTabPlaceholder(int tabIndex, bool isDark) {
    final title = _tabs[tabIndex];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.layers_outlined, size: 40, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            Text(
              '$title Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Switch to the "Books", "Members", or "Issue / Return" tab to manage the full library operations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => ref.read(bookProvider.notifier).setActiveTab(1),
                  child: const Text('Go to Books Tab'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => ref.read(bookProvider.notifier).setActiveTab(2),
                  child: const Text('Go to Members Tab'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => ref.read(bookProvider.notifier).setActiveTab(3),
                  child: const Text('Go to Issue / Return Tab'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

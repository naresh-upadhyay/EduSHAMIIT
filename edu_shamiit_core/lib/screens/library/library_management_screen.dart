import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
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
  static const List<Map<String, dynamic>> _tabs = [
    {'title': 'Books', 'tabIndex': 1, 'adminOnly': false},
    {'title': 'Members', 'tabIndex': 2, 'adminOnly': true},
    {'title': 'Issue / Return', 'tabIndex': 3, 'adminOnly': false},
    {'title': 'Requests', 'tabIndex': 4, 'adminOnly': false},
  ];

  @override
  Widget build(BuildContext context) {
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);
    final isNonAdminUser = !isLibraryAdmin;
    final bookState = ref.watch(bookProvider);
    final bookNotifier = ref.read(bookProvider.notifier);
    final memberState = ref.watch(memberProvider);
    final memberNotifier = ref.read(memberProvider.notifier);
    final circulationState = ref.watch(circulationProvider);
    final requestState = ref.watch(requestProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // Auto-clamp users to valid tabs (Books: 1, Members: 2 [admin only], Issue/Return: 3, Requests: 4)
    final validTabs = isNonAdminUser ? const [1, 3, 4] : const [1, 2, 3, 4];
    if (!validTabs.contains(bookState.activeTab)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bookNotifier.setActiveTab(1);
      });
    }

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
              if (bookState.activeTab == 2 && !isNonAdminUser)
                const MemberHeaderBar()
              else if (bookState.activeTab == 3)
                const CirculationHeaderBar()
              else if (bookState.activeTab == 4)
                const RequestHeaderBar()
              else
                const BookHeaderBar(),

              // 2. Sub-Navigation Tabs Bar
              _buildSubTabBar(
                bookState,
                memberState,
                circulationState,
                requestState,
                bookNotifier,
                isNonAdminUser,
                isDark,
                isDesktop,
              ),

              // 3. Tab Content Area
              Expanded(
                child: bookState.activeTab == 1
                    ? _buildBooksTabContent(isDesktop)
                    : (bookState.activeTab == 2 && !isNonAdminUser
                        ? _buildMembersTabContent(isDesktop)
                        : (bookState.activeTab == 3
                            ? const CirculationTabView()
                            : (bookState.activeTab == 4
                                ? const RequestTabView()
                                : _buildBooksTabContent(isDesktop)))),
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
          if (bookState.isAccessDrawerOpen && bookState.selectedBook != null && !isNonAdminUser) ...[
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
          if (memberState.isDrawerOpen && memberState.selectedMember != null && !isNonAdminUser) ...[
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
    bool isNonAdminUser,
    bool isDark,
    bool isDesktop,
  ) {
    final displayedTabs = _tabs.where((tab) {
      if (isNonAdminUser && tab['adminOnly'] == true) return false;
      return true;
    }).toList();

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
          children: displayedTabs.map((tab) {
            final targetIdx = tab['tabIndex'] as int;
            final isSelected = bookState.activeTab == targetIdx;
            final title = tab['title'] as String;

            return InkWell(
              onTap: () => notifier.setActiveTab(targetIdx),
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
                    if (targetIdx == 1) ...[
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
                    ] else if (targetIdx == 2 && !isNonAdminUser) ...[
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
                    ] else if (targetIdx == 3) ...[
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
                    ] else if (targetIdx == 4) ...[
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
          }).toList(),
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
}

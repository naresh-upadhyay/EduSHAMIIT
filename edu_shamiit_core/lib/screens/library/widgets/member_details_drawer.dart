import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member_models.dart';
import '../providers/member_provider.dart';
import 'dialogs/edit_member_dialog.dart';
import 'dialogs/renew_membership_dialog.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class MemberDetailsDrawer extends ConsumerStatefulWidget {
  const MemberDetailsDrawer({super.key});

  @override
  ConsumerState<MemberDetailsDrawer> createState() => _MemberDetailsDrawerState();
}

class _MemberDetailsDrawerState extends ConsumerState<MemberDetailsDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final notifier = ref.read(memberProvider.notifier);
    final member = state.selectedMember;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    if (member == null) return const SizedBox.shrink();

    // Dynamically size drawer based on available screen width
    final drawerWidth = screenWidth < 500 ? screenWidth : (screenWidth < 900 ? 430.0 : 470.0);

    return Container(
      width: drawerWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Drawer Header (Member Details Title + Close X)
          _buildDrawerHeader(member, notifier, isDark),

          // 2. Scrollable Body Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Identity Card (Avatar + Metadata Grid)
                  _buildProfileIdentityCard(member, isDark),

                  const Divider(height: 28),

                  // Current Books Section
                  _buildCurrentBooksSection(state, isDark),

                  const Divider(height: 28),

                  // Outstanding Fines & Overdue Warning
                  _buildOutstandingSection(member, state, isDark),

                  const Divider(height: 28),

                  // Membership Details (with Edit button)
                  _buildMembershipDetailsSection(context, member, isDark),
                ],
              ),
            ),
          ),

          // 3. Bottom Action Bar (Renew, Edit, Suspend/Activate)
          _buildBottomActionBar(context, member, notifier, isDark),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(LibraryMemberModel member, MemberNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Member Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close drawer',
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            onPressed: () => notifier.closeDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileIdentityCard(LibraryMemberModel member, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final memberSince = member.createdAt != null
        ? dateFormat.format(member.createdAt!)
        : (member.membershipStartDate != null ? dateFormat.format(member.membershipStartDate!) : '12 Apr 2025');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar Thumbnail
        _buildLargeAvatar(member, isDark),

        const SizedBox(width: 14),

        // Metadata Columns
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + Status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      member.memberName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusPill(member.status, isDark),
                ],
              ),
              const SizedBox(height: 8),

              _buildMetaRow('Member ID', member.memberCode, isDark),
              _buildMetaRow('Member Type', member.membershipType, isDark),
              _buildMetaRow('Class', member.classOrDepartment, isDark),
              _buildMetaRow('Email', member.email ?? 'aarav.sharma@example.com', isDark),
              _buildMetaRow('Phone', member.phone ?? '+91 98765 43210', isDark),
              _buildMetaRow('Member Since', memberSince, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeAvatar(LibraryMemberModel member, bool isDark) {
    if (member.avatarUrl != null && member.avatarUrl!.startsWith('http')) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          image: DecorationImage(image: NetworkImage(member.avatarUrl!), fit: BoxFit.cover),
        ),
      );
    }

    final initials = member.memberName.trim().isNotEmpty
        ? member.memberName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : 'M';

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBooksSection(MemberState state, bool isDark) {
    final books = state.selectedMemberBooks;
    final count = books.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current Books ($count)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (count > 0)
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View All', style: TextStyle(fontSize: 11.5, color: Color(0xFF6366F1))),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (books.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 20, color: Color(0xFF94A3B8)),
                const SizedBox(width: 10),
                Text(
                  'No books currently issued to this member.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              // Header Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 40, child: Text('Book Title', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                    Expanded(flex: 22, child: Text('Issue Date', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                    Expanded(flex: 22, child: Text('Due Date', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                    SizedBox(width: 48, child: Text('Status', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Books List
              ...books.map((b) => _buildBookItemRow(b, isDark)),
            ],
          ),
      ],
    );
  }

  Widget _buildBookItemRow(MemberBorrowItemModel book, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final issueStr = book.issueDate != null ? dateFormat.format(book.issueDate!) : '16 May 2026';
    final dueStr = book.dueDate != null ? dateFormat.format(book.dueDate!) : '30 May 2026';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: book.isOverdue ? const Color(0xFFEF4444).withValues(alpha: 0.4) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 28,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.auto_stories_rounded, size: 16, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            flex: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (book.accessionNumber != null)
                  Text(
                    book.accessionNumber!,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                  ),
              ],
            ),
          ),

          // Issue Date
          Expanded(
            flex: 22,
            child: Text(
              issueStr,
              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
          ),

          // Due Date
          Expanded(
            flex: 22,
            child: Text(
              dueStr,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: book.isOverdue ? FontWeight.w700 : FontWeight.normal,
                color: book.isOverdue ? const Color(0xFFEF4444) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ),

          // Status Badge
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: book.isOverdue
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  book.isOverdue ? 'Overdue' : 'Issued',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: book.isOverdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingSection(LibraryMemberModel member, MemberState state, bool isDark) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final overdueCount = state.selectedMemberBooks.where((b) => b.isOverdue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Outstanding',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Total Fine Box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Fine',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(member.outstandingFine),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Overdue Books Box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overdue Books',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$overdueCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: overdueCount > 0 ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    if (overdueCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF4444)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        InkWell(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'View Fine History >',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipDetailsSection(BuildContext context, LibraryMemberModel member, bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final validTill = member.membershipExpiryDate != null
        ? dateFormat.format(member.membershipExpiryDate!)
        : '31 Mar 2027';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Membership Details',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (ref.watch(isLibraryAdminProvider))
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => EditMemberDialog(member: member),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: Color(0xFF6366F1)),
                    SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        _buildMetaRow('Membership Type', member.membershipType, isDark),
        _buildMetaRow('Max Books Allowed', '${member.borrowingLimit}', isDark),
        _buildMetaRow('Issue Duration (Days)', '${member.maxIssueDurationDays}', isDark),
        _buildMetaRow('Renewal Allowed', member.renewalAllowed ? 'Yes' : 'No', isDark),
        _buildMetaRow('Membership Valid Till', validTill, isDark),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    LibraryMemberModel member,
    MemberNotifier notifier,
    bool isDark,
  ) {
    if (!ref.watch(isLibraryAdminProvider)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Edit Member Button (Outlined)
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Member', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => EditMemberDialog(member: member),
                );
              },
            ),
          ),
          const SizedBox(width: 10),

          // Renew Membership Button (Solid Purple)
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.autorenew_rounded, size: 17),
              label: const Text('Renew Member', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => RenewMembershipDialog(member: member),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    Color color = const Color(0xFF10B981);
    String label = 'Active';

    if (status.toUpperCase() == 'SUSPENDED') {
      color = const Color(0xFFEF4444);
      label = 'Suspended';
    } else if (status.toUpperCase() == 'INACTIVE') {
      color = const Color(0xFF94A3B8);
      label = 'Inactive';
    } else if (status.toUpperCase() == 'EXPIRED') {
      color = const Color(0xFFF59E0B);
      label = 'Expired';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

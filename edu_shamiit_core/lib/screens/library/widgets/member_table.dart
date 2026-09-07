import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member_models.dart';
import '../providers/member_provider.dart';
import 'dialogs/edit_member_dialog.dart';
import 'dialogs/renew_membership_dialog.dart';
import 'dialogs/suspend_member_dialog.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class MemberTable extends ConsumerStatefulWidget {
  const MemberTable({super.key});

  @override
  ConsumerState<MemberTable> createState() => _MemberTableState();
}

class _MemberTableState extends ConsumerState<MemberTable> {
  final ScrollController _horizontalScrollCtrl = ScrollController();

  @override
  void dispose() {
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final notifier = ref.read(memberProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    // View Toolbar + Main Content Area
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Toolbar: View Mode Toggle (Table vs Cards) + Summary Counter
        Container(
          margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Left Summary Label
              Text(
                'Showing ${state.totalRecords} member${state.totalRecords == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),

              // View Mode Toggle (Table vs Cards)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _viewModeButton('TABLE', Icons.table_rows, state.viewMode == 'TABLE', notifier, isDark),
                    _viewModeButton('CARDS', Icons.grid_view_rounded, state.viewMode == 'CARDS', notifier, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area: Loading / Empty / Loaded Table or Cards
        if (state.isLoading && state.members.isEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 10),
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Loading library members directory...', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          )
        else if (state.members.isEmpty)
          _buildEmptyState(context, state, notifier, isDark, isDesktop)
        else
          state.viewMode == 'CARDS'
              ? _buildSmartCardsGrid(state, notifier, isDark, isDesktop)
              : _buildEnterpriseTable(state, notifier, isDark, isDesktop),
      ],
    );
  }

  Widget _viewModeButton(String mode, IconData icon, bool isSelected, MemberNotifier notifier, bool isDark) {
    return GestureDetector(
      onTap: () => notifier.setViewMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  /// 1. Enterprise Responsive Table View (Fills 100% Screen Width)
  Widget _buildEnterpriseTable(MemberState state, MemberNotifier notifier, bool isDark, bool isDesktop) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isDesktop ? 28 : 16,
        6,
        isDesktop ? 28 : 16,
        24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minTableWidth = 1200.0;
          final tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Scrollbar(
                controller: _horizontalScrollCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTableHeader(state, notifier, isDark),
                        Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ...state.members.map((member) => _buildTableRow(member, state, notifier, isDark)),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              _buildPaginationFooter(context, state, notifier, isDark),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTableHeader(MemberState state, MemberNotifier notifier, bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          // 1. Member ID (flex: 11)
          Expanded(
            flex: 11,
            child: _buildSortableHeader('Member ID', 'member_code', state, notifier),
          ),
          const SizedBox(width: 10),

          // 2. Member Name (flex: 20)
          Expanded(
            flex: 20,
            child: _buildSortableHeader('Member Name', 'member_name', state, notifier),
          ),
          const SizedBox(width: 10),

          // 3. Member Type (flex: 12)
          Expanded(
            flex: 12,
            child: _buildSortableHeader('Member Type', 'member_type', state, notifier),
          ),
          const SizedBox(width: 10),

          // 4. Class / Department (flex: 14)
          Expanded(
            flex: 14,
            child: _buildSortableHeader('Class / Department', 'class', state, notifier),
          ),
          const SizedBox(width: 10),

          // 5. Contact (flex: 20)
          Expanded(
            flex: 20,
            child: _buildHeaderCell('Contact', isDark),
          ),
          const SizedBox(width: 10),

          // 6. Books Issued (flex: 11)
          Expanded(
            flex: 11,
            child: _buildSortableHeader('Books Issued', 'books_issued', state, notifier),
          ),
          const SizedBox(width: 10),

          // 7. Outstanding Fine (flex: 13)
          Expanded(
            flex: 13,
            child: _buildSortableHeader('Outstanding Fine', 'outstanding_fine', state, notifier),
          ),
          const SizedBox(width: 10),

          // 8. Status (flex: 12)
          Expanded(
            flex: 12,
            child: _buildSortableHeader('Status', 'status', state, notifier),
          ),
          const SizedBox(width: 10),

          // 9. Actions (fixed: 110)
          SizedBox(
            width: 110,
            child: _buildHeaderCell('Actions', isDark, alignment: Alignment.centerRight),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, bool isDark, {Alignment alignment = Alignment.centerLeft}) {
    return Align(
      alignment: alignment,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSortableHeader(
    String label,
    String sortKey,
    MemberState state,
    MemberNotifier notifier,
  ) {
    final isCurrent = state.sortBy == sortKey;
    final isAsc = state.sortOrder.toLowerCase() == 'asc';

    return InkWell(
      onTap: () => notifier.setSorting(sortKey),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            isCurrent
                ? (isAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 13,
            color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(LibraryMemberModel member, MemberState state, MemberNotifier notifier, bool isDark) {
    final isDrawerActive = state.selectedMember?.id == member.id && state.isDrawerOpen;
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDrawerActive ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.16 : 0.06) : Colors.transparent,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.03),
          onTap: () => notifier.openMemberDetails(member),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 1. Member ID (flex: 11)
                Expanded(
                  flex: 11,
                  child: Text(
                    member.memberCode,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Member Name + Avatar (flex: 20)
                Expanded(
                  flex: 20,
                  child: Row(
                    children: [
                      _buildAvatar(member, isDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          member.memberName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Member Type (flex: 12)
                Expanded(
                  flex: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildRoleBadge(member.membershipType, isDark),
                  ),
                ),
                const SizedBox(width: 10),

                // 4. Class / Department (flex: 14)
                Expanded(
                  flex: 14,
                  child: Text(
                    member.classOrDepartment,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // 5. Contact (flex: 20)
                Expanded(
                  flex: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        member.email ?? 'No email',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        member.phone ?? 'No phone',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 6. Books Issued (flex: 11)
                Expanded(
                  flex: 11,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: member.booksIssued > 0
                            ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${member.booksIssued}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: member.booksIssued > 0
                              ? const Color(0xFF6366F1)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 7. Outstanding Fine (flex: 13)
                Expanded(
                  flex: 13,
                  child: Text(
                    currencyFormatter.format(member.outstandingFine),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: member.outstandingFine > 0
                          ? const Color(0xFFEF4444)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // 8. Status (flex: 12)
                Expanded(
                  flex: 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildStatusPill(member.status, isDark),
                  ),
                ),
                const SizedBox(width: 10),

                // 9. Actions (fixed width: 110)
                SizedBox(
                  width: 110,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // View Details
                      Tooltip(
                        message: 'View Details',
                        child: IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 17),
                          color: const Color(0xFF6366F1),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => notifier.openMemberDetails(member),
                        ),
                      ),
                      if (isLibraryAdmin) ...[
                        // Edit Parameters
                        Tooltip(
                          message: 'Edit Member',
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => EditMemberDialog(member: member),
                              );
                            },
                          ),
                        ),
                        // More Popup Menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 17,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onSelected: (action) {
                            if (action == 'renew') {
                              showDialog(
                                context: context,
                                builder: (_) => RenewMembershipDialog(member: member),
                              );
                            } else if (action == 'suspend') {
                              showDialog(
                                context: context,
                                builder: (_) => SuspendMemberDialog(member: member),
                              );
                            } else if (action == 'activate') {
                              notifier.activateMember(member.id);
                            } else if (action == 'delete') {
                              _confirmDeleteMember(context, member, notifier);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'renew',
                              child: Row(
                                children: [
                                  Icon(Icons.autorenew_rounded, size: 16, color: Color(0xFF10B981)),
                                  SizedBox(width: 8),
                                  Text('Renew Membership', style: TextStyle(fontSize: 12.5)),
                                ],
                              ),
                            ),
                            if (member.isActive)
                              const PopupMenuItem(
                                value: 'suspend',
                                child: Row(
                                  children: [
                                    Icon(Icons.block_rounded, size: 16, color: Color(0xFFEF4444)),
                                    SizedBox(width: 8),
                                    Text('Suspend Member', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'activate',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                    SizedBox(width: 8),
                                    Text('Activate Member', style: TextStyle(fontSize: 12.5)),
                                  ],
                                ),
                              ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                  SizedBox(width: 8),
                                  Text('Archive / Delete', style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2. Smart Cards Responsive Grid View (Mobile/Tablet and Cards Mode)
  Widget _buildSmartCardsGrid(MemberState state, MemberNotifier notifier, bool isDark, bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 6),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 3;
              if (width < 760) {
                crossAxisCount = 1;
              } else if (width < 1180) {
                crossAxisCount = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 210,
                ),
                itemCount: state.members.length,
                itemBuilder: (context, index) {
                  final member = state.members[index];
                  return _buildMemberCard(member, notifier, isDark);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: _buildPaginationFooter(context, state, notifier, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(LibraryMemberModel member, MemberNotifier notifier, bool isDark) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => notifier.openMemberDetails(member),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Avatar + Name + Code + Status
                Row(
                  children: [
                    _buildAvatar(member, isDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.memberName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            member.memberCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusPill(member.status, isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // Middle: Role Badge + Class/Dept + Contact
                Row(
                  children: [
                    _buildRoleBadge(member.membershipType, isDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.classOrDepartment,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  member.email ?? member.phone ?? 'No contact info',
                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                // Bottom Row: Books Issued + Fines + Action Icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_outlined, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${member.booksIssued} issued',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                      ],
                    ),
                    if (member.outstandingFine > 0)
                      Text(
                        currencyFormatter.format(member.outstandingFine),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF6366F1)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () => notifier.openMemberDetails(member),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(LibraryMemberModel member, bool isDark) {
    if (member.avatarUrl != null && member.avatarUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(member.avatarUrl!),
        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
      );
    }

    final initials = member.memberName.trim().isNotEmpty
        ? member.memberName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : 'M';

    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
      child: Text(
        initials,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
      ),
    );
  }

  Widget _buildRoleBadge(String type, bool isDark) {
    Color badgeColor = const Color(0xFF6366F1); // Student = Purple
    if (type.toLowerCase().contains('teacher') || type.toLowerCase().contains('faculty')) {
      badgeColor = const Color(0xFF10B981); // Emerald
    } else if (type.toLowerCase().contains('staff') || type.toLowerCase().contains('admin')) {
      badgeColor = const Color(0xFFF59E0B); // Amber
    } else if (type.toLowerCase().contains('librarian')) {
      badgeColor = const Color(0xFF3B82F6); // Blue
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: badgeColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusPill(String status, bool isDark) {
    Color color = const Color(0xFF10B981); // Active
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPaginationFooter(
    BuildContext context,
    MemberState state,
    MemberNotifier notifier,
    bool isDark,
  ) {
    final startItem = state.totalRecords == 0 ? 0 : (state.currentPage - 1) * state.pageSize + 1;
    final endItem = (state.currentPage * state.pageSize).clamp(0, state.totalRecords);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // "Showing X to Y of Z members"
          Expanded(
            child: Text(
              'Showing $startItem to $endItem of ${state.totalRecords} members',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),

          // Rows per page dropdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.pageSize,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10 per page')),
                      DropdownMenuItem(value: 25, child: Text('25 per page')),
                      DropdownMenuItem(value: 50, child: Text('50 per page')),
                      DropdownMenuItem(value: 100, child: Text('100 per page')),
                    ],
                    onChanged: (val) {
                      if (val != null) notifier.setPageSize(val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Previous Page Button (<)
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: state.currentPage > 1 ? () => notifier.setPage(state.currentPage - 1) : null,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),

              // Page Numbers
              _buildPageNumbers(state, notifier, isDark),

              // Next Page Button (>)
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: state.currentPage < state.totalPages
                    ? () => notifier.setPage(state.currentPage + 1)
                    : null,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageNumbers(MemberState state, MemberNotifier notifier, bool isDark) {
    final current = state.currentPage;
    final total = state.totalPages;
    final pages = <int>[];

    if (total <= 5) {
      for (int i = 1; i <= total; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      if (current > 3) pages.add(-1); // Ellipsis
      final start = (current - 1).clamp(2, total - 1);
      final end = (current + 1).clamp(2, total - 1);
      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }
      if (current < total - 2) pages.add(-2); // Ellipsis
      if (!pages.contains(total)) pages.add(total);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pages.map((p) {
        if (p < 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(color: Color(0xFF94A3B8))),
          );
        }
        final isSelected = p == current;
        return InkWell(
          onTap: () => notifier.setPage(p),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    MemberState state,
    MemberNotifier notifier,
    bool isDark,
    bool isDesktop,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 28 : 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_alt_outlined, size: 36, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            Text(
              state.searchQuery.isNotEmpty || state.selectedMemberType != 'All Member Types' || state.selectedStatus != 'Status: All' || state.selectedMembershipFilter != 'Membership: All'
                  ? 'No members match your active filters.'
                  : 'No library members found.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              state.searchQuery.isNotEmpty || state.selectedMemberType != 'All Member Types' || state.selectedStatus != 'Status: All' || state.selectedMembershipFilter != 'Membership: All'
                  ? 'Try changing or clearing your search filters.'
                  : 'Add an existing user from the profile directory as a library member to get started.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Reset All Filters'),
              onPressed: notifier.resetFilters,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMember(
    BuildContext context,
    LibraryMemberModel member,
    MemberNotifier notifier,
  ) {
    if (member.booksIssued > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot archive member "${member.memberName}" with ${member.booksIssued} active issued book(s). Return all books first.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Library Member'),
        content: Text('Are you sure you want to archive membership for ${member.memberName} (${member.memberCode})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteMember(member.id);
            },
            child: const Text('Archive Member', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

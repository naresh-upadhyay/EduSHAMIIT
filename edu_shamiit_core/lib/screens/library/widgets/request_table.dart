import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/request_models.dart';
import '../providers/request_provider.dart';
import 'dialogs/process_request_dialog.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';

class RequestTable extends ConsumerWidget {
  final Function(String requestId)? onViewRequest;

  const RequestTable({
    super.key,
    this.onViewRequest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(requestProvider);
    final notifier = ref.read(requestProvider.notifier);
    final isLibraryAdmin = ref.watch(isLibraryAdminProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userData?['id']?.toString() ??
        authState.userData?['profile_id']?.toString() ??
        authState.userData?['user_id']?.toString();

    if (state.isLoading && state.items.isEmpty) {
      return Container(
        height: 350,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text(
              'Loading library requests...',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Container(
        height: 350,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 32),
              const SizedBox(height: 8),
              Text(
                state.errorMessage!,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => notifier.loadRequests(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Container(
        height: 350,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            const Text(
              'No requests found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Try changing search filters or create a new library request.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Responsive Data Table
        LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 1000.0;
            final tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTableHeader(),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                    ...state.items.map((item) => _buildTableRow(context, item, ref, notifier, isLibraryAdmin, currentUserId)),
                  ],
                ),
              ),
            );
          },
        ),

        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

        // Enterprise Table Pagination Footer
        _buildPaginationFooter(context, state, notifier),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFFF8FAFC),
      child: const Row(
        children: [
          Expanded(flex: 12, child: Text('Request ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 22, child: Text('Title / Item', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 12, child: Text('Request Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 18, child: Text('Requested By', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 10, child: Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 11, child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 14, child: Text('Date Requested', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          Expanded(flex: 14, child: Text('Last Updated', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
          SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    BuildContext context,
    LibraryRequestItem item,
    WidgetRef ref,
    RequestNotifier notifier,
    bool isLibraryAdmin,
    String? currentUserId,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy hh:mm a');
    final isPendingWithoutAction = item.status == 'NEW' || item.status == 'PENDING';
    final isCreator = currentUserId != null &&
        item.requesterId != null &&
        currentUserId.trim().isNotEmpty &&
        item.requesterId!.trim().toLowerCase() == currentUserId.trim().toLowerCase();
    final canDelete = isPendingWithoutAction && isCreator;



    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // 1. Request ID (flex: 12)
              Expanded(
                flex: 12,
                child: InkWell(
                  onTap: () {
                    notifier.openRequestDetail(item.id);
                    onViewRequest?.call(item.id);
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        item.requestNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Title / Item (flex: 22)
              Expanded(
                flex: 22,
                child: InkWell(
                  onTap: () {
                    notifier.openRequestDetail(item.id);
                    onViewRequest?.call(item.id);
                  },
                  child: Row(
                    children: [
                      _buildItemThumbnail(item),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (item.author != null && item.author!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 3. Request Type Badge (flex: 12)
              Expanded(
                flex: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTypeBadge(item.requestType),
                ),
              ),
              const SizedBox(width: 10),

              // 4. Requested By (flex: 18)
              Expanded(
                flex: 18,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _getRoleBgColor(item.requesterRole),
                      child: Text(
                        item.requesterName.isNotEmpty ? item.requesterName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getRoleTextColor(item.requesterRole),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.requesterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            item.requesterClass.isNotEmpty && item.requesterClass != 'N/A'
                                ? item.requesterClass
                                : (item.requesterRole.toUpperCase()),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 5. Priority Badge (flex: 10)
              Expanded(
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPriorityBadge(item.priority),
                ),
              ),
              const SizedBox(width: 10),

              // 6. Status Badge (flex: 11)
              Expanded(
                flex: 11,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusBadge(item.status),
                ),
              ),
              const SizedBox(width: 10),

              // 7. Date Requested (flex: 14)
              Expanded(
                flex: 14,
                child: Text(
                  dateFormat.format(item.createdAt),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // 8. Last Updated (flex: 14)
              Expanded(
                flex: 14,
                child: Text(
                  dateFormat.format(item.updatedAt),
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),

              // 9. Actions (width: 130)
              SizedBox(
                width: 130,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'View Request Details',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        notifier.openRequestDetail(item.id);
                        onViewRequest?.call(item.id);
                      },
                    ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Delete Request',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _confirmDeleteRequest(context, item, notifier),
                      ),
                    if (isLibraryAdmin) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF2563EB)),
                        tooltip: 'Process Request Status',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => ProcessRequestDialog(request: item),
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onSelected: (val) async {
                          if (val == 'view') {
                            notifier.openRequestDetail(item.id);
                            onViewRequest?.call(item.id);
                          } else if (val == 'activate') {
                            await notifier.transitionStatus(requestId: item.id, toStatus: 'ACTIVE');
                          } else if (val == 'resolve') {
                            await notifier.transitionStatus(requestId: item.id, toStatus: 'RESOLVED', comment: 'Resource ready for pickup');
                          } else if (val == 'reject') {
                            showDialog(
                              context: context,
                              builder: (ctx) => ProcessRequestDialog(request: item, initialAction: 'REJECT'),
                            );
                          } else if (val == 'cancel') {
                            await notifier.transitionStatus(requestId: item.id, toStatus: 'CANCELED', reason: 'Canceled by staff');
                          } else if (val == 'delete') {
                            _confirmDeleteRequest(context, item, notifier);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF475569)),
                                SizedBox(width: 8),
                                Text('View Details', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          if (item.status == 'NEW' || item.status == 'PENDING') ...[
                            const PopupMenuItem(
                              value: 'activate',
                              child: Row(
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Text('Mark Active', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            if (canDelete)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                    SizedBox(width: 8),
                                    Text('Delete Request', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                                  ],
                                ),
                              ),
                          ],

                          if (item.status == 'ACTIVE' || item.status == 'IN_PROGRESS')
                            const PopupMenuItem(
                              value: 'resolve',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                                  SizedBox(width: 8),
                                  Text('Mark Resolved', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (item.status != 'COMPLETED' && item.status != 'REJECTED' && item.status != 'CANCELED') ...[
                            const PopupMenuItem(
                              value: 'reject',
                              child: Row(
                                children: [
                                  Icon(Icons.block_rounded, size: 16, color: Color(0xFFEF4444)),
                                  SizedBox(width: 8),
                                  Text('Reject Request', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined, size: 16, color: Color(0xFF64748B)),
                                  SizedBox(width: 8),
                                  Text('Cancel Request', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildItemThumbnail(LibraryRequestItem item) {
    if (item.bookCoverUrl != null && item.bookCoverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          item.bookCoverUrl!,
          width: 34,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackTypeIcon(item.requestType),
        ),
      );
    }
    return _buildFallbackTypeIcon(item.requestType);
  }

  Widget _buildFallbackTypeIcon(String type) {
    IconData icon;
    Color bg;
    Color color;

    switch (type.toLowerCase()) {
      case 'e-book':
      case 'ebook':
        icon = Icons.tablet_mac_rounded;
        bg = const Color(0xFFEDE9FE);
        color = const Color(0xFF7C3AED);
        break;
      case 'digital resource':
      case 'digital_resource':
        icon = Icons.folder_zip_rounded;
        bg = const Color(0xFFE0F2FE);
        color = const Color(0xFF0284C7);
        break;
      case 'audiobook':
        icon = Icons.headphones_rounded;
        bg = const Color(0xFFFCE7F3);
        color = const Color(0xFFDB2777);
        break;
      case 'journal / magazine':
        icon = Icons.auto_stories_rounded;
        bg = const Color(0xFFFEF3C7);
        color = const Color(0xFFD97706);
        break;
      default:
        icon = Icons.menu_book_rounded;
        bg = const Color(0xFFEFF6FF);
        color = const Color(0xFF2563EB);
    }

    return Container(
      width: 34,
      height: 46,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color textColor;
    Color border;

    switch (priority.toLowerCase()) {
      case 'urgent':
        bg = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        break;
      case 'high':
        bg = const Color(0xFFFFF1F2);
        textColor = const Color(0xFFE11D48);
        border = const Color(0xFFFFE4E6);
        break;
      case 'medium':
        bg = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        border = const Color(0xFFFDE68A);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        border = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color textColor;
    Color border;
    String label = status.replaceAll('_', ' ');

    switch (status.toUpperCase()) {
      case 'NEW':
      case 'PENDING':
        bg = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        border = const Color(0xFFBFDBFE);
        label = 'New';
        break;
      case 'ACTIVE':
        bg = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF4F46E5);
        border = const Color(0xFFC7D2FE);
        label = 'Active';
        break;
      case 'IN_PROGRESS':
        bg = const Color(0xFFF5F3FF);
        textColor = const Color(0xFF7C3AED);
        border = const Color(0xFFDDD6FE);
        label = 'In Progress';
        break;
      case 'RESOLVED':
        bg = const Color(0xFFECFDF5);
        textColor = const Color(0xFF059669);
        border = const Color(0xFFA7F3D0);
        label = 'Resolved';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFF0FDF4);
        textColor = const Color(0xFF16A34A);
        border = const Color(0xFFBBF7D0);
        label = 'Completed';
        break;
      case 'REJECTED':
        bg = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        border = const Color(0xFFFECACA);
        label = 'Rejected';
        break;
      case 'CANCELED':
      case 'CANCELLED':
        bg = const Color(0xFFF8FAFC);
        textColor = const Color(0xFF64748B);
        border = const Color(0xFFE2E8F0);
        label = 'Cancelled';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        border = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Color _getRoleBgColor(String role) {
    switch (role.toLowerCase()) {
      case 'teacher':
        return const Color(0xFFEDE9FE);
      case 'staff':
      case 'librarian':
        return const Color(0xFFECFDF5);
      case 'parent':
        return const Color(0xFFFEF3C7);
      default:
        return const Color(0xFFEFF6FF);
    }
  }

  Color _getRoleTextColor(String role) {
    switch (role.toLowerCase()) {
      case 'teacher':
        return const Color(0xFF7C3AED);
      case 'staff':
      case 'librarian':
        return const Color(0xFF059669);
      case 'parent':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Widget _buildPaginationFooter(
    BuildContext context,
    RequestState state,
    RequestNotifier notifier,
  ) {
    final startItem = state.total == 0 ? 0 : ((state.page - 1) * state.pageSize) + 1;
    final endItem = (state.page * state.pageSize) > state.total ? state.total : (state.page * state.pageSize);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Items Per Page Dropdown & Total Counter
          Row(
            children: [
              Text(
                'Showing $startItem-$endItem of ${state.total} requests',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: state.pageSize,
                underline: const SizedBox(),
                isDense: true,
                items: [10, 25, 50, 100].map((e) {
                  return DropdownMenuItem<int>(
                    value: e,
                    child: Text(e.toString(), style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) notifier.setPageSize(val);
                },
              ),
            ],
          ),

          // Pagination Next / Prev buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                splashRadius: 18,
                onPressed: state.page > 1 ? () => notifier.setPage(state.page - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${state.page} / ${state.totalPages == 0 ? 1 : state.totalPages}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                splashRadius: 18,
                onPressed: state.page < state.totalPages ? () => notifier.setPage(state.page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteRequest(
    BuildContext context,
    LibraryRequestItem item,
    RequestNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Request',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this library request? This action cannot be undone.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_border_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.requestNumber,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        ),
                        Text(
                          item.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await notifier.deleteRequest(item.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request ${item.requestNumber} deleted successfully.'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorText = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorText.isNotEmpty ? errorText : 'Failed to delete request.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}


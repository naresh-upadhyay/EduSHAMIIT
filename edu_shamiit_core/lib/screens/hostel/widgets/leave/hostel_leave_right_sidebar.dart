import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class HostelLeaveRightSidebar extends ConsumerWidget {
  const HostelLeaveRightSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final awaitingList = state.awaitingApprovalList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---------------------------------------------------------------------
        // AWAITING APPROVAL CARD
        // ---------------------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Awaiting Approval (${state.leaveKpis.pending})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      notifier.setLeaveStatusFilter('PENDING');
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Items
              if (awaitingList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No requests waiting for approval.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                ...awaitingList.take(4).map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: InkWell(
                      onTap: () => notifier.selectLeaveRequestById(item.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFFEFF6FF),
                            backgroundImage: item.studentAvatar != null ? NetworkImage(item.studentAvatar!) : null,
                            child: item.studentAvatar == null
                                ? Text(
                                    item.studentName.isNotEmpty ? item.studentName[0] : 'S',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.studentName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  item.durationSubtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}

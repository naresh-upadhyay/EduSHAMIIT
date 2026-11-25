import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import 'dialogs/generate_invoice_dialog.dart';
import 'dialogs/bulk_invoice_dialog.dart';

class HostelFeeFilterBar extends ConsumerWidget {
  const HostelFeeFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kpis = state.feesKPIs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sub-Tabs Bar matching screenshot (All Fees 356, Paid 284, Partial 48, Overdue 24, Fee Structure)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSubTab(
                context,
                title: 'All Fees',
                count: '${kpis.totalStudents}',
                isSelected: state.feesSubTab == 0,
                onTap: () {
                  notifier.setFeesSubTab(0);
                  notifier.setFeesStatusFilter('All Status');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Paid',
                count: '${kpis.paidStudentsCount}',
                isSelected: state.feesSubTab == 1,
                badgeColor: const Color(0xFF16A34A),
                onTap: () {
                  notifier.setFeesSubTab(1);
                  notifier.setFeesStatusFilter('Paid');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Partial',
                count: '${kpis.pendingStudentsCount}',
                isSelected: state.feesSubTab == 2,
                badgeColor: const Color(0xFFD97706),
                onTap: () {
                  notifier.setFeesSubTab(2);
                  notifier.setFeesStatusFilter('Partial');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Overdue',
                count: '${kpis.overdueStudentsCount}',
                isSelected: state.feesSubTab == 3,
                badgeColor: const Color(0xFFDC2626),
                onTap: () {
                  notifier.setFeesSubTab(3);
                  notifier.setFeesStatusFilter('Overdue');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Fee Structure',
                count: '${state.feePlans.length}',
                isSelected: state.feesSubTab == 4,
                onTap: () {
                  notifier.setFeesSubTab(4);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Invoices',
                count: '${state.invoicesList.length}',
                isSelected: state.feesSubTab == 5,
                badgeColor: const Color(0xFF6366F1),
                onTap: () {
                  notifier.setFeesSubTab(5);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Payments',
                count: '${state.paymentsList.length}',
                isSelected: state.feesSubTab == 6,
                badgeColor: const Color(0xFF059669),
                onTap: () {
                  notifier.setFeesSubTab(6);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Deposit Refunds',
                count: '${state.refundsList.length}',
                isSelected: state.feesSubTab == 7,
                badgeColor: const Color(0xFFD97706),
                onTap: () {
                  notifier.setFeesSubTab(7);
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Search & Controls Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Input
                  _buildSearchField(state, notifier, isDark),
                  const SizedBox(height: 10),
                  // Dropdowns Wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildHostelDropdown(state, notifier, isDark),
                      _buildClassDropdown(state, notifier, isDark),
                      _buildStatusDropdown(state, notifier, isDark),
                      _buildActionButton(context, ref, isDark),
                      _buildMoreMenu(context, ref, isDark),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                // Search Input (Expanded)
                Expanded(
                  flex: 3,
                  child: _buildSearchField(state, notifier, isDark),
                ),
                const SizedBox(width: 10),

                // Hostel Dropdown
                _buildHostelDropdown(state, notifier, isDark),
                const SizedBox(width: 10),

                // Class Dropdown
                _buildClassDropdown(state, notifier, isDark),
                const SizedBox(width: 10),

                // Status Dropdown
                _buildStatusDropdown(state, notifier, isDark),
                const SizedBox(width: 12),

                // Action Button: "+ Generate Invoice"
                _buildActionButton(context, ref, isDark),
                const SizedBox(width: 8),

                // More Menu Icon
                _buildMoreMenu(context, ref, isDark),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubTab(
    BuildContext context, {
    required String title,
    required String count,
    required bool isSelected,
    Color? badgeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.2) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: badgeColor != null
                    ? badgeColor.withValues(alpha: 0.15)
                    : (isSelected
                        ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ?? (isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(HostelState state, HostelNotifier notifier, bool isDark) {
    return SizedBox(
      height: 40,
      child: TextField(
        onChanged: (val) => notifier.setFeesSearch(val),
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search student name, roll number, invoice...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          isDense: true,
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHostelDropdown(HostelState state, HostelNotifier notifier, bool isDark) {
    final hostels = ['All Hostels', 'Boys Hostel A', 'Girls Hostel A', 'Boys Hostel B'];
    final current = hostels.contains(state.feesHostelFilter) ? state.feesHostelFilter : 'All Hostels';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: current,
          isDense: true,
          isExpanded: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          items: hostels.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
          onChanged: (val) {
            if (val != null) notifier.setFeesHostelFilter(val);
          },
        ),
      ),
    );
  }

  Widget _buildClassDropdown(HostelState state, HostelNotifier notifier, bool isDark) {
    final classes = [
      'All Classes',
      'Class 10-A',
      'Class 10-B',
      'Class 11-A',
      'Class 11-B',
      'Class 12-A',
      'Class 12-B',
    ];
    final current = classes.contains(state.feesClassFilter) ? state.feesClassFilter : 'All Classes';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: current,
          isDense: true,
          isExpanded: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) {
            if (val != null) notifier.setFeesClassFilter(val);
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(HostelState state, HostelNotifier notifier, bool isDark) {
    final statuses = ['All Status', 'Paid', 'Partial', 'Overdue', 'Over Paid'];
    final current = statuses.contains(state.feesStatusFilter) ? state.feesStatusFilter : 'All Status';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: current,
          isDense: true,
          isExpanded: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) {
            if (val != null) {
              notifier.setFeesStatusFilter(val);
              if (val == 'All Status') notifier.setFeesSubTab(0);
              if (val == 'Paid') notifier.setFeesSubTab(1);
              if (val == 'Partial') notifier.setFeesSubTab(2);
              if (val == 'Overdue') notifier.setFeesSubTab(3);
            }
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, bool isDark) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const GenerateInvoiceDialog(),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'Generate Invoice',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, WidgetRef ref, bool isDark) {
    final notifier = ref.read(hostelProvider.notifier);

    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (val) async {
          if (val == 'bulk_invoice') {
            showDialog(
              context: context,
              builder: (context) => const BulkInvoiceDialog(),
            );
          } else if (val == 'send_reminders') {
            final state = ref.read(hostelProvider);
            final payload = <String, dynamic>{
              'academic_year': state.selectedAcademicYear,
              'reminder_type': 'OVERDUE',
              'channel': 'EMAIL',
            };
            if (state.selectedFeeAccountIds.isNotEmpty) {
              payload['student_ids'] = state.selectedFeeAccountIds.toList();
            } else {
              final dueStudents = state.studentFeesRoster.where((s) => s.due > 0).map((s) => s.studentId).toList();
              if (dueStudents.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No visible students currently have pending fee dues to remind.'),
                    backgroundColor: Color(0xFF64748B),
                  ),
                );
                return;
              }
              payload['student_ids'] = dueStudents;
            }
            await notifier.sendFeeReminders(payload);
          } else if (val == 'export_csv') {
            final state = ref.read(hostelProvider);
            await notifier.exportFeesCsv(onlySelected: state.selectedFeeAccountIds.isNotEmpty);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'bulk_invoice',
            child: Row(
              children: [
                Icon(Icons.dynamic_feed_rounded, size: 16, color: Color(0xFF7C3AED)),
                SizedBox(width: 8),
                Text('Bulk Generate Invoices', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'send_reminders',
            child: Row(
              children: [
                Icon(Icons.send_rounded, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text('Send Due Reminders', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'export_csv',
            child: Row(
              children: [
                Icon(Icons.download_rounded, size: 16, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Text('Export Fees CSV', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

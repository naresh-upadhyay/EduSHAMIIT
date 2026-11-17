import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/student_fee_provider.dart';
import 'dialogs/generate_student_invoice_dialog.dart';
import 'dialogs/bulk_student_invoice_dialog.dart';
import 'dialogs/collect_student_payment_dialog.dart';
import 'dialogs/edit_student_fee_structure_dialog.dart';

class StudentFeeFilterBar extends ConsumerWidget {
  const StudentFeeFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentFeeProvider);
    final notifier = ref.read(studentFeeProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kpis = state.kpis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Sub-Tabs Bar matching Screenshot exactly
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSubTab(
                context,
                title: 'All Fees',
                count: '${kpis.totalStudents}',
                isSelected: state.subTab == 0,
                onTap: () {
                  notifier.setSubTab(0);
                  notifier.setStatusFilter('All Status');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Paid',
                count: '${kpis.paidStudentsCount}',
                isSelected: state.subTab == 1,
                badgeColor: const Color(0xFF16A34A),
                onTap: () {
                  notifier.setSubTab(1);
                  notifier.setStatusFilter('Paid');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Partial',
                count: '${kpis.pendingStudentsCount}',
                isSelected: state.subTab == 2,
                badgeColor: const Color(0xFFD97706),
                onTap: () {
                  notifier.setSubTab(2);
                  notifier.setStatusFilter('Partial');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Overdue',
                count: '${kpis.overdueStudentsCount}',
                isSelected: state.subTab == 3,
                badgeColor: const Color(0xFFDC2626),
                onTap: () {
                  notifier.setSubTab(3);
                  notifier.setStatusFilter('Overdue');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Fee Structure',
                count: '${state.feeStructures.length}',
                isSelected: state.subTab == 4,
                badgeColor: const Color(0xFF8B5CF6),
                onTap: () {
                  notifier.setSubTab(4);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Invoices',
                count: '${state.invoicesList.length}',
                isSelected: state.subTab == 5,
                badgeColor: const Color(0xFF2563EB),
                onTap: () {
                  notifier.setSubTab(5);
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Payments',
                count: '${state.paymentsList.length}',
                isSelected: state.subTab == 6,
                badgeColor: const Color(0xFF059669),
                onTap: () {
                  notifier.setSubTab(6);
                },
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Bulk Selection Action Toolbar (Appears when rows are checked)
        if (state.selectedStudentIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  '${state.selectedStudentIds.length} Students Selected',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB)),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: const Text('Send Reminders', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final ok = await notifier.executeBulkAction('send_reminder');
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment reminders queued!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final ok = await notifier.executeBulkAction('mark_paid');
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selected invoices marked as Paid!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => notifier.toggleSelectAll(false),
                  child: const Text('Clear Selection', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. Search and Dynamic Filter Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 700;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchField(state, notifier, isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildClassDropdown(state, notifier, isDark)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatusDropdown(state, notifier, isDark)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildActionButton(context, ref, state, isDark)),
                      const SizedBox(width: 6),
                      _buildMoreMenu(context, ref, isDark),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildSearchField(state, notifier, isDark),
                ),
                const SizedBox(width: 10),
                _buildClassDropdown(state, notifier, isDark),
                const SizedBox(width: 10),
                _buildStatusDropdown(state, notifier, isDark),
                const SizedBox(width: 10),
                _buildActionButton(context, ref, state, isDark),
                const SizedBox(width: 6),
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
    required VoidCallback onTap,
    required bool isDark,
    Color? badgeColor,
  }) {
    final effectiveBadgeColor = badgeColor ?? const Color(0xFF2563EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFDBEAFE))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
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
                    ? (isDark ? Colors.white : const Color(0xFF1E40AF))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: effectiveBadgeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: effectiveBadgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search student name, roll number, invoice...',
          hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
        onChanged: notifier.setSearchQuery,
      ),
    );
  }

  Widget _buildClassDropdown(StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    final classes = {'All Classes', ...state.classesList}.toList();
    final effectiveClass = classes.contains(state.selectedClass) ? state.selectedClass : 'All Classes';
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey('fee_filter_class_$effectiveClass'),
          value: effectiveClass,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) {
            if (val != null) notifier.setClassFilter(val);
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(StudentFeeState state, StudentFeeNotifier notifier, bool isDark) {
    const statuses = ['All Status', 'Paid', 'Partial', 'Pending', 'Overdue'];
    final effectiveStatus = statuses.contains(state.selectedStatus) ? state.selectedStatus : 'All Status';
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey('fee_filter_status_$effectiveStatus'),
          value: effectiveStatus,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) {
            if (val != null) notifier.setStatusFilter(val);
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, StudentFeeState state, bool isDark) {
    String label = 'Generate Invoice';
    IconData icon = Icons.add_rounded;
    VoidCallback onTap = () {
      showDialog(
        context: context,
        builder: (ctx) => const GenerateStudentInvoiceDialog(),
      );
    };

    if (state.subTab == 4) {
      label = 'Add Fee Structure';
      icon = Icons.rule_rounded;
      onTap = () {
        showDialog(
          context: context,
          builder: (ctx) => const EditStudentFeeStructureDialog(),
        );
      };
    } else if (state.subTab == 6) {
      label = 'Collect Payment';
      icon = Icons.payment_rounded;
      onTap = () {
        showDialog(
          context: context,
          builder: (ctx) => const CollectStudentPaymentDialog(),
        );
      };
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildMoreMenu(BuildContext context, WidgetRef ref, bool isDark) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'bulk_invoice',
          child: Row(
            children: [
              Icon(Icons.dynamic_feed_rounded, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Bulk Generate Invoices', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export_csv',
          child: Row(
            children: [
              Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Export Roster to CSV', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Refresh Records', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'bulk_invoice') {
          showDialog(
            context: context,
            builder: (ctx) => const BulkStudentInvoiceDialog(),
          );
        } else if (val == 'export_csv') {
          ref.read(studentFeeProvider.notifier).exportCsv();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Downloading Student Fees CSV...'), backgroundColor: Color(0xFF16A34A)),
          );
        } else if (val == 'refresh') {
          ref.read(studentFeeProvider.notifier).loadAllData();
        }
      },
    );
  }
}

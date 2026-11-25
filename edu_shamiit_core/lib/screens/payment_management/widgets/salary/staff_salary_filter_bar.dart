import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/staff_salary_provider.dart';
import 'dialogs/process_staff_payout_dialog.dart';
import 'dialogs/bulk_staff_payroll_dialog.dart';
import 'dialogs/request_salary_advance_dialog.dart';
import 'dialogs/edit_staff_salary_structure_dialog.dart';
import 'dialogs/automated_payroll_dialog.dart';

class StaffSalaryFilterBar extends ConsumerWidget {
  const StaffSalaryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffSalaryProvider);
    final notifier = ref.read(staffSalaryProvider.notifier);
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
                title: 'All Staff',
                count: '${kpis.totalStaff}',
                isSelected: state.subTab == 0,
                onTap: () {
                  notifier.setSubTab(0, statusFilter: 'All Status');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Paid',
                count: '${kpis.paidStaffCount}',
                isSelected: state.subTab == 1,
                badgeColor: const Color(0xFF16A34A),
                onTap: () {
                  notifier.setSubTab(1, statusFilter: 'Paid');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Pending',
                count: '${kpis.pendingStaffCount}',
                isSelected: state.subTab == 2,
                badgeColor: const Color(0xFFD97706),
                onTap: () {
                  notifier.setSubTab(2, statusFilter: 'Pending');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'On Hold',
                count: '${kpis.onHoldStaffCount}',
                isSelected: state.subTab == 3,
                badgeColor: const Color(0xFFDC2626),
                onTap: () {
                  notifier.setSubTab(3, statusFilter: 'On Hold');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildSubTab(
                context,
                title: 'Salary Structures',
                count: '${state.structuresTotal > 0 ? state.structuresTotal : (state.salaryStructures.isNotEmpty ? state.salaryStructures.length : kpis.totalStaff)}',
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
                title: 'Monthly Payslips',
                count: '${state.payslipsTotal > 0 ? state.payslipsTotal : (state.payslipsList.isNotEmpty ? state.payslipsList.length : kpis.paidStaffCount)}',
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
                title: 'Salary Advances',
                count: '${state.advancesTotal > 0 ? state.advancesTotal : state.advancesList.length}',
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

        // 2. Bulk Selection Action Toolbar
        if (state.selectedStaffIds.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Text(
                  '${state.selectedStaffIds.length} Staff Selected',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF16A34A)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 16),
                  label: const Text('Disburse Selected', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final ok = await notifier.executeBulkAction('disburse_selected');
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Salaries disbursed for selected staff!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 16),
                  label: const Text('Hold Selected', style: TextStyle(fontSize: 12)),
                  onPressed: () async {
                    final ok = await notifier.executeBulkAction('hold_selected');
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selected payouts put on hold!'), backgroundColor: Color(0xFFDC2626)),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => notifier.toggleSelectAll(false),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. Search and Dropdown Filter Controls
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchField(state, notifier, isDark),
                  const SizedBox(height: 8),
                  if (state.subTab < 4) ...[
                    Row(
                      children: [
                        Expanded(child: _buildDepartmentDropdown(state, notifier, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildRoleDropdown(state, notifier, isDark)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildStatusDropdown(state, notifier, isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildActionButton(context, ref, state, isDark)),
                        const SizedBox(width: 6),
                        _buildMoreMenu(context, ref, isDark),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        if (state.subTab != 6) ...[
                          Expanded(child: _buildDepartmentDropdown(state, notifier, isDark)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: _buildActionButton(context, ref, state, isDark)),
                        const SizedBox(width: 6),
                        _buildMoreMenu(context, ref, isDark),
                      ],
                    ),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildSearchField(state, notifier, isDark),
                ),
                if (state.subTab != 6) ...[
                  const SizedBox(width: 10),
                  _buildDepartmentDropdown(state, notifier, isDark),
                ],
                if (state.subTab < 4) ...[
                  const SizedBox(width: 10),
                  _buildRoleDropdown(state, notifier, isDark),
                  const SizedBox(width: 10),
                  _buildStatusDropdown(state, notifier, isDark),
                ],
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
    final effectiveBadgeColor = badgeColor ?? const Color(0xFF16A34A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF14532D).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF16A34A)
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
                    ? (isDark ? Colors.white : const Color(0xFF166534))
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

  Widget _buildSearchField(StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    String hint = 'Search staff name, employee ID, role...';
    ValueChanged<String> onChanged = notifier.setSearchQuery;

    if (state.subTab == 4) {
      hint = 'Search configured structures, staff, ID...';
      onChanged = notifier.setStructuresSearch;
    } else if (state.subTab == 5) {
      hint = 'Search payslip #, staff, ID...';
      onChanged = notifier.setPayslipsSearch;
    } else if (state.subTab == 6) {
      hint = 'Search staff, purpose in advances...';
      onChanged = notifier.setAdvancesSearch;
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        key: ValueKey('filter_search_subtab_${state.subTab}'),
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDepartmentDropdown(StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    final departments = {'All Departments', ...state.departmentsList}.toList();
    String currentDept = state.selectedDepartment;
    ValueChanged<String?> onSelect = (val) {
      if (val != null) notifier.setDepartmentFilter(val);
    };

    if (state.subTab == 4) {
      currentDept = state.structuresDept;
      onSelect = (val) {
        if (val != null) notifier.setStructuresDept(val);
      };
    } else if (state.subTab == 5) {
      currentDept = state.payslipsDept;
      onSelect = (val) {
        if (val != null) notifier.setPayslipsDept(val);
      };
    }

    final effectiveDept = departments.contains(currentDept) ? currentDept : 'All Departments';
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
          key: ValueKey('salary_filter_dept_${state.subTab}_$effectiveDept'),
          value: effectiveDept,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: onSelect,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    final roles = {'All Roles', ...state.rolesList}.toList();
    final effectiveRole = roles.contains(state.selectedRole) ? state.selectedRole : 'All Roles';
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
          key: ValueKey('salary_filter_role_$effectiveRole'),
          value: effectiveRole,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All Roles' ? r : r[0].toUpperCase() + r.substring(1)))).toList(),
          onChanged: (val) {
            if (val != null) notifier.setRoleFilter(val);
          },
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(StaffSalaryState state, StaffSalaryNotifier notifier, bool isDark) {
    const statuses = ['All Status', 'Paid', 'Pending', 'On Hold'];
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
        child: AppSearchableDropdown<String>.fromMenuItems(
          key: ValueKey('salary_filter_status_$effectiveStatus'),
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

  Widget _buildActionButton(BuildContext context, WidgetRef ref, StaffSalaryState state, bool isDark) {
    if (state.subTab == 4) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Add Structure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => const EditStaffSalaryStructureDialog(),
          );
        },
      );
    }

    if (state.subTab == 5) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: const Icon(Icons.auto_mode_rounded, size: 18),
        label: const Text('Automate Payroll Run', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => const AutomatedPayrollDialog(),
          );
        },
      );
    }

    if (state.subTab == 6) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: const Icon(Icons.request_quote_rounded, size: 18),
        label: const Text('New Advance Request', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        onPressed: () {
          final firstStaff = state.staffRoster.firstOrNull;
          if (firstStaff != null) {
            showDialog(
              context: context,
              builder: (ctx) => RequestSalaryAdvanceDialog(
                staffId: firstStaff.staffId,
                staffName: firstStaff.staffName,
              ),
            );
          }
        },
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: const Icon(Icons.check_circle_rounded, size: 18),
      label: const Text('Process Payout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => const ProcessStaffPayoutDialog(),
        );
      },
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
          value: 'bulk_payroll',
          child: Row(
            children: [
              Icon(Icons.hub_rounded, size: 18, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Bulk Disburse Month', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export_csv',
          child: Row(
            children: [
              Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Export Salary Sheet (CSV)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Refresh Records', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'bulk_payroll') {
          showDialog(
            context: context,
            builder: (ctx) => const BulkStaffPayrollDialog(),
          );
        } else if (val == 'export_csv') {
          ref.read(staffSalaryProvider.notifier).exportCsv();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Downloading Staff Salary CSV...'), backgroundColor: Color(0xFF16A34A)),
          );
        } else if (val == 'refresh') {
          ref.read(staffSalaryProvider.notifier).loadAllData();
        }
      },
    );
  }
}

import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';
import '../dialogs/maintenance_plan_dialog.dart';

class MaintenancePlansSubview extends ConsumerStatefulWidget {
  const MaintenancePlansSubview({super.key});

  @override
  ConsumerState<MaintenancePlansSubview> createState() => _MaintenancePlansSubviewState();
}

class _MaintenancePlansSubviewState extends ConsumerState<MaintenancePlansSubview> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedFrequency = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateEditPlan([MaintenancePlanItem? plan]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => MaintenancePlanDialog(
        plan: plan,
        onSaved: () => ref.read(maintenanceProvider.notifier).loadPlans(),
      ),
    );
  }

  Future<void> _triggerPlan(MaintenancePlanItem p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Execute Preventive Plan Now'),
        content: Text('Generate live maintenance work orders immediately for plan "${p.title}" across its configured location(s)? Next due date will advance by ${p.frequency}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bolt, size: 16, color: Colors.white),
            label: const Text('Generate Work Orders', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await ref.read(maintenanceProvider.notifier).triggerPlan(p.id);
      if (mounted) {
        final count = res['generated_count'] ?? 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Generated $count work order(s) successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _deletePlan(MaintenancePlanItem p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Maintenance Plan'),
        content: Text('Are you sure you want to delete plan "${p.title}" (${p.planCode})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(maintenanceProvider.notifier).deletePlan(p.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Plan deleted successfully!' : 'Failed to delete plan.'),
            backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final allPlans = state.plans;

    // Filter
    final query = _searchController.text.trim().toLowerCase();
    final filtered = allPlans.where((p) {
      if (_selectedCategory != 'All' && p.category != _selectedCategory) return false;
      if (_selectedFrequency != 'All' && p.frequency != _selectedFrequency) return false;
      if (query.isNotEmpty) {
        final match = p.title.toLowerCase().contains(query) ||
            p.planCode.toLowerCase().contains(query) ||
            (p.vendorName ?? '').toLowerCase().contains(query) ||
            (p.assignedTechnicianName ?? '').toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Table Container
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Preventive Maintenance Plans (${filtered.length})',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final res = await ref.read(maintenanceProvider.notifier).generateDuePreventivePlans();
                              final count = res['generated_count'] ?? 0;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(count > 0 ? '$count due work order(s) generated!' : 'All plans are up to date!'),
                                    backgroundColor: const Color(0xFF059669),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.autorenew_rounded, size: 14),
                            label: const Text('Generate Due Work Orders', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openCreateEditPlan(),
                            icon: const Icon(Icons.add, size: 15, color: Colors.white),
                            label: const Text('Create Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Search & Filter Row
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search plans by code, title, vendor...',
                              hintStyle: TextStyle(fontSize: 12, color: textMuted),
                              prefixIcon: Icon(Icons.search, size: 16, color: textMuted),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<String>.fromMenuItems(
                            value: _selectedCategory,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Categories')),
                              DropdownMenuItem(value: 'HVAC', child: Text('HVAC (AC)')),
                              DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                              DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                              DropdownMenuItem(value: 'AV Equipment', child: Text('AV Equipment')),
                              DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                            ],
                            onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<String>.fromMenuItems(
                            value: _selectedFrequency,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Frequencies')),
                              DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                              DropdownMenuItem(value: 'Every 6 Months', child: Text('Every 6 Months')),
                              DropdownMenuItem(value: 'Quarterly', child: Text('Quarterly')),
                              DropdownMenuItem(value: 'Yearly', child: Text('Yearly')),
                            ],
                            onChanged: (v) => setState(() => _selectedFrequency = v ?? 'All'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.fact_check_outlined, size: 40, color: textMuted),
                              const SizedBox(height: 10),
                              Text('No preventive maintenance plans found.', style: TextStyle(fontSize: 13, color: textMuted)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _openCreateEditPlan(),
                                child: const Text('Create First Plan'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1000),
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 52,
                            horizontalMargin: 12,
                            columnSpacing: 14,
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            ),
                            columns: const [
                              DataColumn(label: Text('Plan Code', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Plan Title', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Category', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Frequency', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Target Locations', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Assigned Vendor & Contact', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Next Due Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                            ],
                            rows: List.generate(filtered.length, (idx) {
                              final p = filtered[idx];
                              final isDue = p.nextDueDate.isBefore(DateTime.now());
                              final locCount = p.targetLocations.isNotEmpty
                                  ? p.targetLocations.length
                                  : (p.roomId != null || p.facilityId != null ? 1 : 0);

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      p.planCode,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 180),
                                      child: Text(
                                        p.title,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(p.category, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: p.frequency.contains('6 Month')
                                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                            : const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.frequency,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: p.frequency.contains('6 Month') ? const Color(0xFF8B5CF6) : const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(locCount > 1 ? Icons.domain_add : Icons.location_on_outlined, size: 14, color: const Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        Text(
                                          locCount > 1
                                              ? '$locCount Locations'
                                              : (p.facilityName ?? p.roomNumber ?? p.buildingName ?? 'Campus Space'),
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textPrimary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(p.vendorName ?? p.assignedTechnicianName ?? p.assignedTeam, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                        if (p.vendorPhone != null && p.vendorPhone!.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.phone, size: 10, color: Color(0xFF10B981)),
                                              const SizedBox(width: 2),
                                              Text(p.vendorPhone!, style: TextStyle(fontSize: 10, color: textMuted)),
                                              if (p.sendVendorEmail) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.mark_email_read_outlined, size: 11, color: Color(0xFF2563EB)),
                                              ],
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: isDue ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        DateFormat('dd MMM yyyy').format(p.nextDueDate),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDue ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: p.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        p.isActive ? 'Active' : 'Paused',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: p.isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.play_circle_outline, size: 17),
                                          tooltip: 'Generate Work Orders Now',
                                          color: const Color(0xFF059669),
                                          onPressed: () => _triggerPlan(p),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                          tooltip: 'Edit Plan',
                                          color: const Color(0xFF2563EB),
                                          onPressed: () => _openCreateEditPlan(p),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                          tooltip: 'Delete Plan',
                                          color: const Color(0xFFEF4444),
                                          onPressed: () => _deletePlan(p),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

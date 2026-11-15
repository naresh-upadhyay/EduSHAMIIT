import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/maintenance_models.dart';
import '../../providers/maintenance_provider.dart';
import 'maintenance_kpis_bar.dart';
import 'maintenance_left_panel.dart';
import 'maintenance_center_panel.dart';
import 'maintenance_right_panel.dart';
import 'dialogs/create_edit_maintenance_dialog.dart';
import 'dialogs/update_maintenance_status_dialog.dart';
import 'dialogs/assign_technician_dialog.dart';
import 'dialogs/maintenance_plan_dialog.dart';
import 'dialogs/maintenance_details_drawer.dart';

class MaintenanceTabView extends ConsumerStatefulWidget {
  const MaintenanceTabView({super.key});

  @override
  ConsumerState<MaintenanceTabView> createState() => _MaintenanceTabViewState();
}

class _MaintenanceTabViewState extends ConsumerState<MaintenanceTabView> {
  bool _isDrawerOpen = false;
  MaintenanceRequestItem? _drawerItem;

  void _openRaiseModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateEditMaintenanceDialog(),
    );
  }

  void _openUpdateStatusModal([MaintenanceRequestItem? item]) {
    final target = item ?? ref.read(maintenanceProvider).inspectedRequest;
    if (target == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateMaintenanceStatusDialog(request: target),
    );
  }

  void _openAssignModal([MaintenanceRequestItem? item]) {
    final target = item ?? ref.read(maintenanceProvider).inspectedRequest;
    if (target == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AssignTechnicianDialog(request: target),
    );
  }

  void _openPlanModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MaintenancePlanDialog(),
    );
  }

  void _openVendorsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final vendors = ref.read(maintenanceProvider).vendors;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        title: Row(
          children: [
            const Icon(Icons.handshake_outlined, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text('Service Vendors & AMC Contracts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: vendors.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Text('No external vendors configured.'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: vendors.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final v = vendors[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(v.vendorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                      subtitle: Text('${v.serviceCategory} • ${v.contractType} (SLA: ${v.slaResponseHours}h)', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                        child: const Text('Active AMC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _inspectRequest(MaintenanceRequestItem item) {
    setState(() {
      _drawerItem = item;
      _isDrawerOpen = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top KPI Summary Cards Row (6 Cards matching screenshot)
                MaintenanceKpisBar(kpis: state.kpis),
                const SizedBox(height: 14),

                // 3-Column Split Area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = constraints.maxWidth;

                      if (screenWidth > 1200) {
                        // Desktop 3-Column Split
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Panel: Raise Request + Views + Filters (~260px)
                            SizedBox(
                              width: 260,
                              child: MaintenanceLeftPanel(
                                onOpenRaiseModal: _openRaiseModal,
                                onOpenPlanModal: _openPlanModal,
                                onOpenVendorsModal: _openVendorsModal,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Center Panel: Requests Table + Analytics (Expanded)
                            Expanded(
                              child: MaintenanceCenterPanel(
                                onOpenNewRequest: _openRaiseModal,
                                onInspectRequest: _inspectRequest,
                                onEditRequest: _openUpdateStatusModal,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Right Panel: Request Details Card + Quick Actions (~280px)
                            SizedBox(
                              width: 280,
                              child: MaintenanceRightPanel(
                                onUpdateStatus: () => _openUpdateStatusModal(),
                                onAssignTechnician: () => _openAssignModal(),
                                onScheduleMaintenance: _openRaiseModal,
                                onCreatePlan: _openPlanModal,
                                onManageAssets: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Opening Campus Assets & Equipment registry...')),
                                  );
                                },
                                onManageVendors: _openVendorsModal,
                              ),
                            ),
                          ],
                        );
                      } else if (screenWidth >= 800) {
                        // Medium / Tablet Screen layout: Left panel + Center panel
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 240,
                              child: MaintenanceLeftPanel(
                                onOpenRaiseModal: _openRaiseModal,
                                onOpenPlanModal: _openPlanModal,
                                onOpenVendorsModal: _openVendorsModal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MaintenanceCenterPanel(
                                onOpenNewRequest: _openRaiseModal,
                                onInspectRequest: _inspectRequest,
                                onEditRequest: _openUpdateStatusModal,
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Mobile Single-Column Layout (< 800px)
                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MaintenanceLeftPanel(
                                onOpenRaiseModal: _openRaiseModal,
                                onOpenPlanModal: _openPlanModal,
                                onOpenVendorsModal: _openVendorsModal,
                              ),
                              const SizedBox(height: 14),
                              MaintenanceCenterPanel(
                                onOpenNewRequest: _openRaiseModal,
                                onInspectRequest: _inspectRequest,
                                onEditRequest: _openUpdateStatusModal,
                              ),
                              const SizedBox(height: 14),
                              MaintenanceRightPanel(
                                onUpdateStatus: () => _openUpdateStatusModal(),
                                onAssignTechnician: () => _openAssignModal(),
                                onScheduleMaintenance: _openRaiseModal,
                                onCreatePlan: _openPlanModal,
                                onManageAssets: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Opening Campus Assets & Equipment registry...')),
                                  );
                                },
                                onManageVendors: _openVendorsModal,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Slide-in Request Details Drawer
          if (_isDrawerOpen && _drawerItem != null)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: Material(
                elevation: 16,
                child: MaintenanceDetailsDrawer(
                  request: _drawerItem!,
                  onClose: () => setState(() => _isDrawerOpen = false),
                  onUpdateStatus: () {
                    final item = _drawerItem!;
                    setState(() => _isDrawerOpen = false);
                    _openUpdateStatusModal(item);
                  },
                  onAssign: () {
                    final item = _drawerItem!;
                    setState(() => _isDrawerOpen = false);
                    _openAssignModal(item);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/hostel_provider.dart';
import 'widgets/hostel_header_bar.dart';
import 'widgets/hostel_kpi_cards.dart';
import 'widgets/hostel_left_tree.dart';
import 'widgets/hostel_center_table.dart';
import 'widgets/hostel_right_inspector.dart';
import 'widgets/dialogs/add_edit_building_dialog.dart';
import 'widgets/overview/hostel_overview_tab.dart';
import 'widgets/students/hostel_students_tab.dart';
import 'widgets/staff/hostel_staff_tab.dart';
import 'widgets/fees/hostel_fees_tab.dart';
import 'widgets/leave/hostel_leave_tab.dart';
import 'widgets/complaints/hostel_complaints_tab.dart';
import 'widgets/reports/hostel_reports_tab.dart';

class HostelManagementScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const HostelManagementScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<HostelManagementScreen> createState() => _HostelManagementScreenState();
}

class _HostelManagementScreenState extends ConsumerState<HostelManagementScreen> {
  int _mobileViewSection = 1; // 0: Structure Tree, 1: Rooms Inventory, 2: Room Details

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(hostelProvider.notifier).selectTab(widget.initialTab.clamp(0, 7));
      }
    });
  }

  @override
  void didUpdateWidget(HostelManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(hostelProvider.notifier).selectTab(widget.initialTab.clamp(0, 7));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for notification messages from notifier and responsive view transitions
    ref.listen<HostelState>(hostelProvider, (prev, next) {
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearNotifications();
      }
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearNotifications();
      }
      if (next.selectedRoomId != null && next.selectedRoomId != prev?.selectedRoomId) {
        if (_mobileViewSection != 2) {
          setState(() => _mobileViewSection = 2);
        }
      }
      if (next.selectedFloorId != null && next.selectedFloorId != prev?.selectedFloorId) {
        if (_mobileViewSection == 0) {
          setState(() => _mobileViewSection = 1);
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Persistent Shared Hostel Header Bar with Tabs & Academic Year Selector
            const HostelHeaderBar(),

            // 2. Main Content Body
            Expanded(
              child: _buildActiveTab(context, state, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context, HostelState state, bool isDark) {
    switch (state.activeTab) {
      case 0:
        // Tab 0: Executive Overview Dashboard
        return const HostelOverviewTab();
      case 1:
        // Tab 1: Rooms & Allocation (Structure tree + room grid + room inspector)
        return _buildRoomsAndAllocationTab(context, state, isDark);
      case 2:
        // Tab 2: Hostel Students
        return const HostelStudentsTab();
      case 3:
        // Tab 3: Staff Management matching Screenshot
        return const HostelStaffTab();
      case 4:
        // Tab 4: Fees & Billing matching Screenshot Pixel-Perfect
        return const HostelFeesTab();
      case 5:
        // Tab 5: Leave & Outing matching Screenshot Pixel-Perfect
        return const HostelLeaveTab();
      case 6:
        // Tab 6: Complaints matching Screenshot Pixel-Perfect
        return const HostelComplaintsTab();
      case 7:
        // Tab 7: Universal Reports & Exports
        return const HostelReportsTab();
      default:
        return const HostelOverviewTab();
    }
  }

  Widget _buildRoomsAndAllocationTab(BuildContext context, HostelState state, bool isDark) {
    if (state.isLoading && state.structureTree.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('Loading hostel structure and room inventory...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 1200;
        final isTablet = screenWidth >= 768 && screenWidth < 1200;
        final isMobile = screenWidth < 768;

        return RefreshIndicator(
          onRefresh: () => ref.read(hostelProvider.notifier).refreshAll(),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 14, isMobile ? 12 : 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top KPI Summary Cards
                const HostelKPICards(),
                const SizedBox(height: 16),

                // If no buildings exist at all (Brand new tenant zero data)
                if (state.structureTree.isEmpty && !state.isLoading)
                  _buildZeroDataState(context, isDark)
                else if (isDesktop)
                  // 3-Column Desktop Layout (width >= 1200px)
                  const SizedBox(
                    height: 840,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: Expandable Searchable Hierarchical Tree (width 330)
                        SizedBox(
                          width: 330,
                          child: HostelLeftTree(),
                        ),
                        SizedBox(width: 14),

                        // CENTER: Room grid/table with filters, search, and bulk actions
                        Expanded(
                          child: HostelCenterTable(),
                        ),
                        SizedBox(width: 14),

                        // RIGHT: Selected Room Inspector with photos, facilities, and students
                        SizedBox(
                          width: 300,
                          child: HostelRightInspector(),
                        ),
                      ],
                    ),
                  )
                else if (isTablet)
                  // 2-Column Tablet Layout (768px <= width < 1200px)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                        height: 750,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 310,
                              child: HostelLeftTree(),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: HostelCenterTable(),
                            ),
                          ],
                        ),
                      ),
                      if (state.selectedRoomDetail != null) ...[
                        const SizedBox(height: 16),
                        const SizedBox(height: 650, child: HostelRightInspector()),
                      ],
                    ],
                  )
                else
                  // Mobile Layout (< 768px): Intuitive Segmented View Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Segmented Bar
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildMobileSegmentItem(
                              icon: Icons.account_tree_outlined,
                              label: 'Structure Tree',
                              index: 0,
                              isDark: isDark,
                            ),
                            _buildMobileSegmentItem(
                              icon: Icons.meeting_room_outlined,
                              label: 'Rooms (${state.rooms.length})',
                              index: 1,
                              isDark: isDark,
                            ),
                            _buildMobileSegmentItem(
                              icon: Icons.info_outline,
                              label: 'Details',
                              index: 2,
                              isDark: isDark,
                              hasBadge: state.selectedRoomDetail != null,
                            ),
                          ],
                        ),
                      ),
                      // Active View Container
                      if (_mobileViewSection == 0)
                        const SizedBox(height: 580, child: HostelLeftTree())
                      else if (_mobileViewSection == 1)
                        const SizedBox(height: 700, child: HostelCenterTable())
                      else
                        state.selectedRoomDetail != null
                            ? const SizedBox(height: 700, child: HostelRightInspector())
                            : Container(
                                height: 280,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.touch_app_outlined, size: 36, color: Color(0xFF94A3B8)),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No Room Selected',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Select a room from the Rooms tab to view its details.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () => setState(() => _mobileViewSection = 1),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      child: const Text('Go to Rooms List', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZeroDataState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_rounded, size: 64, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              'No Hostel Buildings Configured',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Get started by creating your first hostel building and setting up floors and rooms.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const AddEditBuildingDialog(),
                );
              },
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Create First Hostel Building', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSegmentItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
    bool hasBadge = false,
  }) {
    final isSelected = _mobileViewSection == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mobileViewSection = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
              if (hasBadge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

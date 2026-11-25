import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../dialogs/add_edit_building_dialog.dart';
import '../dialogs/add_hostel_student_dialog.dart';
import '../dialogs/add_edit_room_dialog.dart';
import '../leave/create_leave_outing_dialog.dart';
import '../leave/gate_pass_dialog.dart';
import '../complaints/dialogs/raise_complaint_dialog.dart';
import '../common/hostel_unified_kpi_card.dart';
import '../dialogs/hostel_night_attendance_dialog.dart';
import '../dialogs/hostel_mess_menu_dialog.dart';
import '../dialogs/hostel_visitor_log_dialog.dart';
import '../dialogs/hostel_asset_audit_dialog.dart';

class HostelOverviewTab extends ConsumerWidget {
  const HostelOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = state.overviewData;
    final kpis = (data['kpis'] as Map<String, dynamic>?) ?? {};
    final buildings = (data['building_occupancy'] as List<dynamic>?) ?? [];
    final roomTypes = (data['room_types'] as List<dynamic>?) ?? [];
    final movements = (data['recent_movements'] as List<dynamic>?) ?? [];
    final complaints = (data['priority_complaints'] as List<dynamic>?) ?? [];

    if (state.isOverviewLoading && data.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 14),
            Text('Loading hostel executive overview...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.loadOverviewData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Quick Actions Bar
            _buildQuickActionsBar(context, ref, notifier, isDark),
            const SizedBox(height: 16),

            // 2. High-Level Metrics Summary Cards
            _buildMetricsGrid(kpis, notifier, isDark),
            const SizedBox(height: 18),

            // 3. Middle Section: Building Occupancy Breakdown + Room Types Distribution
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildBuildingsOccupancyCard(buildings, notifier, isDark),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _buildRoomTypesCard(roomTypes, notifier, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildBuildingsOccupancyCard(buildings, notifier, isDark),
                      const SizedBox(height: 16),
                      _buildRoomTypesCard(roomTypes, notifier, isDark),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 18),

            // 4. Bottom Section: Live Movements Feed + Priority Complaints
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildRecentMovementsCard(context, movements, notifier, isDark),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: _buildPriorityComplaintsCard(context, complaints, notifier, isDark),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildRecentMovementsCard(context, movements, notifier, isDark),
                      const SizedBox(height: 16),
                      _buildPriorityComplaintsCard(context, complaints, notifier, isDark),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // QUICK ACTIONS BAR
  // ==========================================================================

  Widget _buildQuickActionsBar(
    BuildContext context,
    WidgetRef ref,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, size: 20, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'Quick Operations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                label: 'Admit Resident',
                icon: Icons.person_add_alt_1_rounded,
                bgColor: const Color(0xFF2563EB),
                textColor: Colors.white,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AddHostelStudentDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Add Building',
                icon: Icons.apartment_rounded,
                bgColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                textColor: isDark ? Colors.white : const Color(0xFF334155),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AddEditBuildingDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Add Room',
                icon: Icons.meeting_room_outlined,
                bgColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                textColor: isDark ? Colors.white : const Color(0xFF334155),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AddEditRoomDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Request Movement',
                icon: Icons.departure_board_rounded,
                bgColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                textColor: isDark ? Colors.white : const Color(0xFF334155),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const CreateLeaveOutingDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Verify Gate Pass',
                icon: Icons.qr_code_scanner_rounded,
                bgColor: const Color(0xFF16A34A),
                textColor: Colors.white,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const GatePassDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Lodge Complaint',
                icon: Icons.report_problem_outlined,
                bgColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                textColor: isDark ? Colors.white : const Color(0xFF334155),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const RaiseComplaintDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'View Reports',
                icon: Icons.analytics_outlined,
                bgColor: const Color(0xFF0D9488),
                textColor: Colors.white,
                onTap: () => notifier.selectTab(7),
              ),
              _buildActionButton(
                label: 'Night Roll-Call',
                icon: Icons.bedtime_rounded,
                bgColor: const Color(0xFF6366F1),
                textColor: Colors.white,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const HostelNightAttendanceDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Mess & Dining',
                icon: Icons.restaurant_rounded,
                bgColor: const Color(0xFFEA580C),
                textColor: Colors.white,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const HostelMessMenuDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Visitor Log',
                icon: Icons.badge_rounded,
                bgColor: const Color(0xFF0284C7),
                textColor: Colors.white,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const HostelVisitorLogDialog(),
                  );
                },
              ),
              _buildActionButton(
                label: 'Asset Audit',
                icon: Icons.inventory_2_rounded,
                bgColor: const Color(0xFF8B5CF6),
                textColor: Colors.white,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const HostelAssetAuditDialog(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // METRICS SUMMARY CARDS
  // ==========================================================================

  Widget _buildMetricsGrid(Map<String, dynamic> kpis, HostelNotifier notifier, bool isDark) {
    final occRate = (kpis['occupancy_rate'] as num?)?.toDouble() ?? 0.0;
    final totalBeds = (kpis['total_beds'] as num?)?.toInt() ?? 0;
    final occupiedBeds = (kpis['occupied_beds'] as num?)?.toInt() ?? 0;
    final totalRooms = (kpis['total_rooms'] as num?)?.toInt() ?? 0;
    final totalBuildings = (kpis['total_buildings'] as num?)?.toInt() ?? 0;
    final activeResidents = (kpis['active_residents'] as num?)?.toInt() ?? 0;
    final currentlyOut = (kpis['currently_out'] as num?)?.toInt() ?? 0;
    final openComplaints = (kpis['open_complaints'] as num?)?.toInt() ?? 0;
    final urgentComplaints = (kpis['urgent_complaints'] as num?)?.toInt() ?? 0;
    final recoveryRate = (kpis['recovery_rate'] as num?)?.toDouble() ?? 0.0;
    final totalDues = (kpis['total_dues'] as num?)?.toDouble() ?? 0.0;

    return HostelKpiGrid(
      desktopColumns: 5,
      tabletColumns: 3,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          minHeight: 84.0,
          title: 'Total Occupancy',
          value: '$occupiedBeds / $totalBeds',
          subtitle: '$occRate% Occupied ($totalRooms Rooms in $totalBuildings Hostels)',
          progress: totalBeds > 0 ? (occupiedBeds / totalBeds).clamp(0.0, 1.0) : 0.0,
          badge: '$occRate%',
          badgeColor: const Color(0xFF2563EB),
          icon: Icons.hotel_rounded,
          iconColor: const Color(0xFF2563EB),
          tooltip: 'Hostel bed & room occupancy',
          onTap: () => notifier.selectTab(1),
        ),
        HostelUnifiedKpiCard(
          minHeight: 84.0,
          title: 'Active Residents',
          value: '$activeResidents',
          subtitle: 'Current enrolled hostellers',
          badge: activeResidents > 0 ? '$activeResidents' : null,
          badgeColor: const Color(0xFF16A34A),
          icon: Icons.people_alt_rounded,
          iconColor: const Color(0xFF16A34A),
          tooltip: 'View enrolled students',
          onTap: () => notifier.selectTab(2),
        ),
        HostelUnifiedKpiCard(
          minHeight: 84.0,
          title: 'Campus Movement',
          value: '$currentlyOut Out',
          subtitle: '${kpis['pending_leaves'] ?? 0} Pending Leave Requests',
          badge: currentlyOut > 0 ? '$currentlyOut Out' : null,
          badgeColor: const Color(0xFFD97706),
          icon: Icons.directions_walk_rounded,
          iconColor: const Color(0xFFD97706),
          tooltip: 'Outing and gate pass status',
          onTap: () => notifier.selectTab(5),
        ),
        HostelUnifiedKpiCard(
          minHeight: 84.0,
          title: 'Open Complaints',
          value: '$openComplaints Tickets',
          subtitle: urgentComplaints > 0 ? '$urgentComplaints Urgent Attention' : 'All standard priority',
          badge: urgentComplaints > 0 ? '$urgentComplaints Urgent' : null,
          badgeColor: const Color(0xFFDC2626),
          icon: Icons.build_circle_outlined,
          iconColor: urgentComplaints > 0 ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
          tooltip: 'Active maintenance tickets',
          onTap: () => notifier.selectTab(6),
        ),
        HostelUnifiedKpiCard(
          minHeight: 84.0,
          title: 'Fee Collection',
          value: '$recoveryRate%',
          subtitle: '₹${totalDues.toInt()} Outstanding Dues',
          progress: (recoveryRate / 100.0).clamp(0.0, 1.0),
          badge: '₹${totalDues.toInt()} Due',
          badgeColor: const Color(0xFF059669),
          icon: Icons.account_balance_wallet_outlined,
          iconColor: const Color(0xFF059669),
          tooltip: 'Fee collection recovery and dues',
          onTap: () => notifier.selectTab(4),
        ),
      ],
    );
  }

  // ==========================================================================
  // BUILDINGS OCCUPANCY CARD
  // ==========================================================================

  Widget _buildBuildingsOccupancyCard(
    List<dynamic> buildings,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hostel Buildings & Wing Occupancy',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => notifier.selectTab(1), // Go to Rooms & Allocation
                child: const Text('Manage Rooms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (buildings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No hostel buildings registered yet', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: buildings.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final b = buildings[i] as Map<String, dynamic>;
                final name = b['building_name'] ?? 'Building';
                final code = b['code'] ?? '';
                final policy = b['gender_policy'] ?? 'BOYS';
                final totalBeds = (b['total_beds'] as num?)?.toInt() ?? 0;
                final occupiedBeds = (b['occupied_beds'] as num?)?.toInt() ?? 0;
                final totalRooms = (b['total_rooms'] as num?)?.toInt() ?? 0;
                final rate = (b['occupancy_rate'] as num?)?.toDouble() ?? 0.0;

                final isBoys = policy.toString().toUpperCase().contains('BOY');
                final badgeColor = isBoys ? const Color(0xFF2563EB) : const Color(0xFFEC4899);

                final bId = b['id']?.toString() ?? b['building_id']?.toString() ?? '';

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (bId.isNotEmpty) {
                        notifier.selectBuilding(bId);
                      }
                      notifier.selectTab(1); // Go to Rooms & Allocation with building selected
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '($code)',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      policy.toString().toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$totalRooms Rooms  •  $occupiedBeds / $totalBeds Beds Occupied',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '$rate%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: totalBeds > 0 ? (occupiedBeds / totalBeds).clamp(0.0, 1.0) : 0.0,
                              minHeight: 5,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rate >= 90 ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ROOM TYPES CARD
  // ==========================================================================

  Widget _buildRoomTypesCard(List<dynamic> roomTypes, HostelNotifier notifier, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Room Types & Facilities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (roomTypes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No room types recorded', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roomTypes.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final rt = roomTypes[i] as Map<String, dynamic>;
                final type = rt['room_type'] ?? 'Standard';
                final roomCount = (rt['room_count'] as num?)?.toInt() ?? 0;
                final bedCount = (rt['bed_count'] as num?)?.toInt() ?? 0;
                final occupied = (rt['occupied_beds'] as num?)?.toInt() ?? 0;

                final isFacility = type.toString().toLowerCase().contains('toilet') ||
                    type.toString().toLowerCase().contains('study') ||
                    type.toString().toLowerCase().contains('mess') ||
                    type.toString().toLowerCase().contains('office') ||
                    type.toString().toLowerCase().contains('laundry');

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      notifier.selectTab(1);
                      notifier.setRoomTypeFilter(type);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isFacility ? Icons.meeting_room_outlined : Icons.bed_outlined,
                                size: 16,
                                color: isFacility ? const Color(0xFF059669) : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                type,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                isFacility ? '$roomCount Rooms (Amenity)' : '$roomCount Rooms ($occupied/$bedCount Beds)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RECENT MOVEMENTS CARD
  // ==========================================================================

  Widget _buildRecentMovementsCard(
    BuildContext context,
    List<dynamic> movements,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Movement & Outings Feed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => notifier.selectTab(5), // Go to Leave & Outing
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No active student movements today', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: movements.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final m = movements[i] as Map<String, dynamic>;
                final name = m['student_name'] ?? 'Resident';
                final purpose = m['purpose'] ?? 'General Outing';
                final code = m['gate_pass_code'] ?? '';
                final status = m['status'] ?? 'PENDING';

                Color statusCol = const Color(0xFFD97706);
                if (status == 'APPROVED' || status == 'EXITED') statusCol = const Color(0xFF16A34A);
                if (status == 'RETURNED') statusCol = const Color(0xFF2563EB);
                if (status == 'REJECTED') statusCol = const Color(0xFFDC2626);

                final reqId = m['id']?.toString() ?? m['request_id']?.toString() ?? '';

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      notifier.selectTab(5); // Switch to Leave & Outing tab
                      if (reqId.isNotEmpty) {
                        notifier.selectLeaveRequestById(reqId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusCol.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.badge_outlined, size: 16, color: statusCol),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  purpose,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusCol.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusCol),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(code, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PRIORITY COMPLAINTS CARD
  // ==========================================================================

  Widget _buildPriorityComplaintsCard(
    BuildContext context,
    List<dynamic> complaints,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Urgent & High Priority Maintenance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => notifier.selectTab(6), // Go to Complaints
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (complaints.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No urgent maintenance tickets pending', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: complaints.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final c = complaints[i] as Map<String, dynamic>;
                final ticket = c['ticket_number'] ?? '';
                final title = c['title'] ?? 'Maintenance Issue';
                final room = c['room_number'] ?? '';
                final prio = c['priority'] ?? 'HIGH';

                final isUrgent = prio.toString().toUpperCase() == 'URGENT';
                final prioColor = isUrgent ? const Color(0xFFDC2626) : const Color(0xFFD97706);

                final cId = c['id']?.toString() ?? c['complaint_id']?.toString() ?? '';

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      notifier.selectTab(6); // Switch to Complaints tab
                      if (cId.isNotEmpty) {
                        notifier.selectComplaint(cId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: prioColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.warning_amber_rounded, size: 16, color: prioColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      ticket,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                    ),
                                    if (room.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('•  Room $room', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: prioColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              prio,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: prioColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

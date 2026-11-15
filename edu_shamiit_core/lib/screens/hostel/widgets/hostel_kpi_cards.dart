import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hostel_provider.dart';
import 'common/hostel_unified_kpi_card.dart';

class HostelKPICards extends ConsumerWidget {
  const HostelKPICards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final kpis = state.kpis;

    return HostelKpiGrid(
      desktopColumns: 6,
      tabletColumns: 3,
      mobileColumns: 2,
      spacing: 12.0,
      children: [
        HostelUnifiedKpiCard(
          title: 'Total Buildings',
          value: '${kpis.totalBuildings}',
          subtitle: 'Total hostel buildings',
          icon: Icons.apartment_rounded,
          iconColor: const Color(0xFF2563EB),
          isSelected: state.hostelFilter != 'All Hostels',
          tooltip: 'Hostel buildings inventory',
          onTap: () {
            notifier.setHostelFilter('All Hostels');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Total Floors',
          value: '${kpis.totalFloors}',
          subtitle: 'Across all buildings',
          icon: Icons.layers_rounded,
          iconColor: const Color(0xFF9333EA),
          isSelected: state.floorFilter != 'All Floors',
          tooltip: 'Hostel floors count',
          onTap: () {
            notifier.setFloorFilter('All Floors');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Total Rooms',
          value: '${kpis.totalRooms}',
          subtitle: 'All room types',
          icon: Icons.meeting_room_rounded,
          iconColor: const Color(0xFFDB2777),
          isSelected: state.statusFilter == 'All Status',
          tooltip: 'View all rooms inventory',
          onTap: () {
            notifier.setStatusFilter('All Status');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Occupied Rooms',
          value: '${kpis.occupiedRooms}',
          subtitle: '${kpis.occupancyPercentage}% occupancy',
          badge: '${kpis.occupancyPercentage}%',
          badgeColor: const Color(0xFF16A34A),
          icon: Icons.people_outline_rounded,
          iconColor: const Color(0xFF16A34A),
          isSelected: state.statusFilter == 'Occupied',
          tooltip: 'Filter occupied rooms',
          onTap: () {
            notifier.setStatusFilter('Occupied');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Available Rooms',
          value: '${kpis.availableRooms}',
          subtitle: '${kpis.availablePercentage}% available',
          badge: '${kpis.availablePercentage}%',
          badgeColor: const Color(0xFF0284C7),
          icon: Icons.hotel_rounded,
          iconColor: const Color(0xFF0284C7),
          isSelected: state.statusFilter == 'Available',
          tooltip: 'Filter available rooms',
          onTap: () {
            notifier.setStatusFilter('Available');
          },
        ),
        HostelUnifiedKpiCard(
          title: 'Maintenance',
          value: '${kpis.maintenanceRooms}',
          subtitle: 'Under maintenance',
          badge: kpis.maintenanceRooms > 0 ? '${kpis.maintenanceRooms}' : null,
          badgeColor: const Color(0xFFEA580C),
          icon: Icons.build_rounded,
          iconColor: const Color(0xFFEA580C),
          isSelected: state.statusFilter == 'Maintenance',
          tooltip: 'Filter maintenance rooms',
          onTap: () {
            notifier.setStatusFilter('Maintenance');
          },
        ),
      ],
    );
  }
}

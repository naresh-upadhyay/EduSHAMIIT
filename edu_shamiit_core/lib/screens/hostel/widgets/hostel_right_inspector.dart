import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hostel_models.dart';
import '../providers/hostel_provider.dart';
import 'dialogs/add_edit_room_dialog.dart';
import 'dialogs/add_edit_bed_dialog.dart';
import 'dialogs/add_equipment_dialog.dart';
import 'dialogs/assign_student_dialog.dart';
import 'dialogs/transfer_hostel_student_dialog.dart';
import 'dialogs/hostel_photo_gallery_dialog.dart';

class HostelRightInspector extends ConsumerWidget {
  const HostelRightInspector({super.key});

  Color _statusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'OCCUPIED':
        return const Color(0xFFDCFCE7);
      case 'AVAILABLE':
        return const Color(0xFFDBEAFE);
      case 'MAINTENANCE':
      case 'UNDER_REPAIR':
        return const Color(0xFFFEF3C7);
      case 'OPERATIONAL':
        return const Color(0xFFE0E7FF);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'OCCUPIED':
        return const Color(0xFF15803D);
      case 'AVAILABLE':
        return const Color(0xFF1D4ED8);
      case 'MAINTENANCE':
      case 'UNDER_REPAIR':
        return const Color(0xFFB45309);
      case 'OPERATIONAL':
        return const Color(0xFF4338CA);
      default:
        return const Color(0xFF475569);
    }
  }

  String _formatStatus(String s) {
    if (s.isEmpty) return 'Available';
    final l = s.replaceAll('_', ' ').toLowerCase();
    return l[0].toUpperCase() + l.substring(1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detail = state.selectedRoomDetail;

    if (state.isDetailLoading) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (detail == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                const SizedBox(height: 10),
                Text(
                  'Select a Room',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click on any room to inspect details and facilities.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: Room Details & Edit Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AddEditRoomDialog(
                        roomDetail: detail,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Banner with interactive viewer and upload button
                  Stack(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => HostelPhotoGalleryDialog(
                              roomId: detail.id,
                              roomNumber: detail.roomNumber,
                              initialPhotos: detail.photos,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: detail.photos.isNotEmpty
                              ? Image.network(
                                  detail.photos.first,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => _buildFallbackPhoto(isDark),
                                )
                              : _buildFallbackPhoto(isDark),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => HostelPhotoGalleryDialog(
                                roomId: detail.id,
                                roomNumber: detail.roomNumber,
                                initialPhotos: detail.photos,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera_outlined, size: 12, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  detail.photos.isNotEmpty ? '${detail.photos.length} Photos' : 'Add Photo',
                                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Room Number & Status Badges (Using Wrap to completely prevent RenderFlex overflow)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        detail.roomNumber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _statusBgColor(detail.status),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _formatStatus(detail.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _statusTextColor(detail.status),
                          ),
                        ),
                      ),
                      // Room Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          detail.roomType.toLowerCase().contains('room') ||
                                  detail.roomType.toLowerCase().contains('toilet') ||
                                  detail.roomType.toLowerCase().contains('office') ||
                                  detail.roomType.toLowerCase().contains('bay') ||
                                  detail.roomType.toLowerCase().contains('hall') ||
                                  detail.roomType.toLowerCase().contains('laundry')
                              ? detail.roomType
                              : '${detail.roomType} Room',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Non-residential utility check (Toilet, Washroom, Study Room, Mess, Laundry)
                  Builder(
                    builder: (context) {
                      final typeLower = detail.roomType.toLowerCase();
                      final isNonResidential = typeLower.contains('toilet') ||
                          typeLower.contains('washroom') ||
                          typeLower.contains('study') ||
                          typeLower.contains('mess') ||
                          typeLower.contains('laundry') ||
                          typeLower.contains('gym') ||
                          typeLower.contains('store');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(Icons.apartment_outlined, 'Hostel', detail.hostelName.isNotEmpty ? detail.hostelName : detail.buildingName, isDark),
                          _buildDetailRow(Icons.layers_outlined, 'Floor', detail.floorName, isDark),
                          _buildDetailRow(Icons.meeting_room_outlined, 'Room Type', detail.roomType, isDark),
                          if (!isNonResidential) ...[
                            _buildDetailRow(Icons.hotel_outlined, 'Capacity', '${detail.capacity} Beds', isDark),
                            _buildDetailRow(Icons.people_outline, 'Current Occupancy', '${detail.currentOccupancy} / ${detail.capacity}', isDark),
                            _buildDetailRow(Icons.currency_rupee_rounded, 'Monthly Fee', '₹${detail.monthlyFee.toStringAsFixed(0)}', isDark),
                          ] else ...[
                            _buildDetailRow(Icons.cleaning_services_outlined, 'Facility Class', 'Utility & Common Area', isDark),
                            _buildDetailRow(Icons.verified_outlined, 'Sanitation Status', detail.status, isDark),
                          ],
                          _buildDetailRow(Icons.aspect_ratio_outlined, 'Room Size', '${detail.roomSizeSqm.toStringAsFixed(0)} sq.m', isDark),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Secondary Tabs: Facilities | Students (3) | Maintenance | History
                  Builder(
                    builder: (context) {
                      final typeLower = detail.roomType.toLowerCase();
                      final isNonResidential = typeLower.contains('toilet') ||
                          typeLower.contains('washroom') ||
                          typeLower.contains('study') ||
                          typeLower.contains('mess') ||
                          typeLower.contains('laundry') ||
                          typeLower.contains('gym') ||
                          typeLower.contains('store');

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTabItem(0, 'Facilities (${detail.facilities.length})', state.inspectorTab == 0, notifier, isDark),
                            if (!isNonResidential)
                              _buildTabItem(1, 'Beds (${detail.beds.length})', state.inspectorTab == 1, notifier, isDark),
                            if (!isNonResidential)
                              _buildTabItem(2, 'Students (${detail.students.length})', state.inspectorTab == 2, notifier, isDark),
                            _buildTabItem(3, 'Maintenance (${detail.maintenance.length})', state.inspectorTab == 3, notifier, isDark),
                            _buildTabItem(4, 'History', state.inspectorTab == 4, notifier, isDark),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Tab Contents
                  if (state.inspectorTab == 0) ...[
                    // Facilities Subheader
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Room Facilities (${detail.facilities.length})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AddEquipmentDialog(
                                roomId: detail.id,
                                roomNumber: detail.roomNumber,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                                SizedBox(width: 3),
                                Text(
                                  'Add Facility',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Facilities Grid
                    _buildFacilitiesGrid(context, detail, isDark),
                  ] else if (state.inspectorTab == 1) ...[
                    // Beds Inventory List
                    _buildBedsList(context, detail, notifier, isDark),
                  ] else if (state.inspectorTab == 2) ...[
                    // Students List
                    if (detail.students.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No students currently allocated to this room.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detail.students.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final stu = detail.students[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  child: Text(
                                    stu.fullName.isNotEmpty ? stu.fullName[0].toUpperCase() : 'S',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stu.fullName,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Bed: ${stu.bedCode} • Fee: ${stu.feeStatus}',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                                  padding: EdgeInsets.zero,
                                  onSelected: (action) {
                                    if (action == 'checkout') {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Confirm Check-Out'),
                                          content: Text('Are you sure you want to check out ${stu.fullName}?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                final res = await ref.read(hostelProvider.notifier).service.checkOutStudent(stu.allocationId);
                                                if (res['success'] == true) {
                                                  notifier.showSuccess('Student checked out successfully');
                                                  notifier.fetchRoomDetail(detail.id);
                                                  notifier.fetchRooms();
                                                }
                                              },
                                              child: const Text('Check Out'),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else if (action == 'transfer') {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => TransferHostelStudentDialog(
                                          student: stu.toRosterItem(
                                            hostelId: detail.buildingId,
                                            buildingName: detail.buildingName,
                                            roomId: detail.id,
                                            roomNumber: detail.roomNumber,
                                            floorId: detail.floorId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'transfer', child: Text('Transfer Room / Bed', style: TextStyle(fontSize: 12))),
                                    const PopupMenuItem(value: 'checkout', child: Text('Check Out', style: TextStyle(fontSize: 12, color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ] else if (state.inspectorTab == 3) ...[
                    // Maintenance Tickets
                    if (detail.maintenance.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No active maintenance tickets for this room.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detail.maintenance.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final mt = detail.maintenance[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                notifier.selectTab(6);
                                notifier.setComplaintsSearch(mt.ticketNumber);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(mt.ticketNumber, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFEDD5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(mt.status, style: const TextStyle(fontSize: 10, color: Color(0xFFEA580C), fontWeight: FontWeight.w600)),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(mt.title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ] else ...[
                    // History Tab
                    if (detail.history.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No historical events recorded.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detail.history.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final ev = detail.history[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          ev.eventType.replaceAll('_', ' '),
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                    if (ev.createdAt != null)
                                      Text(
                                        ev.createdAt!.length > 10 ? ev.createdAt!.substring(0, 10) : ev.createdAt!,
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                      ),
                                  ],
                                ),
                                if (ev.studentName.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    ev.studentName,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ],
                                if (ev.reason != null && ev.reason!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(ev.reason!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                                if (ev.performedBy != null && ev.performedBy!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Logged by: ${ev.performedBy!}',
                                    style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],

                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  Builder(
                    builder: (context) {
                      final typeLower = detail.roomType.toLowerCase();
                      final isNonResidential = typeLower.contains('toilet') ||
                          typeLower.contains('washroom') ||
                          typeLower.contains('study') ||
                          typeLower.contains('mess') ||
                          typeLower.contains('laundry') ||
                          typeLower.contains('gym') ||
                          typeLower.contains('store');

                      if (isNonResidential) {
                        return Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AddEquipmentDialog(
                                      roomId: detail.id,
                                      roomNumber: detail.roomNumber,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 15, color: Colors.white),
                                label: const Text('Add Facility / Asset', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                notifier.selectTab(6); // Switch to Complaints tab
                              },
                              icon: const Icon(Icons.build_circle_outlined, size: 14, color: Color(0xFF475569)),
                              label: const Text('Report Issue', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AssignStudentDialog(
                                    preselectedRoomId: detail.id,
                                    room: detail,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_add_alt_1, size: 15, color: Colors.white),
                              label: const Text('Assign Student', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AddEditBedDialog(roomId: detail.id),
                              );
                            },
                            icon: const Icon(Icons.hotel_outlined, size: 14, color: Color(0xFF475569)),
                            label: const Text('Add Bed', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackPhoto(bool isDark) {
    return Container(
      height: 140,
      width: double.infinity,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(Icons.apartment_rounded, size: 48, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, bool isSelected, HostelNotifier notifier, bool isDark) {
    return InkWell(
      onTap: () => notifier.setInspectorTab(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildFacilitiesGrid(BuildContext context, HostelRoomDetail detail, bool isDark) {
    final items = detail.facilities;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 36, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              'No facilities recorded for this room.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddEquipmentDialog(
                    roomId: detail.id,
                    roomNumber: detail.roomNumber,
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Facility / Equipment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3.2,
      ),
      itemBuilder: (context, index) {
        final eq = items[index];
        final condLower = (eq.condition).toLowerCase();
        final isAvailable = condLower == 'good' || condLower == 'working';
        final isUnderRepair = condLower == 'under repair' || condLower == 'under_repair' || condLower == 'faulty';

        final labelText = eq.quantity > 1 ? '${eq.name} (${eq.quantity})' : eq.name;

        return InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AddEquipmentDialog(
                roomId: detail.id,
                roomNumber: detail.roomNumber,
                equipment: eq,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? const Color(0xFFDCFCE7)
                        : (isUnderRepair ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    eq.condition,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isAvailable
                          ? const Color(0xFF15803D)
                          : (isUnderRepair ? const Color(0xFFB45309) : const Color(0xFFEF4444)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBedsList(BuildContext context, HostelRoomDetail detail, HostelNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Beds Inventory (${detail.beds.length})',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AddEditBedDialog(roomId: detail.id),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                    SizedBox(width: 3),
                    Text(
                      'Add Bed',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (detail.beds.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No beds recorded for this room.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: detail.beds.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final bed = detail.beds[index];
              final isOccupied = bed.status.toUpperCase() == 'OCCUPIED';
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isOccupied ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.single_bed_rounded,
                        size: 18,
                        color: isOccupied ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Bed ${bed.bedNumberOrCode}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusBgColor(bed.status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _formatStatus(bed.status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _statusTextColor(bed.status),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOccupied && bed.occupant != null
                                ? 'Occupant: ${bed.occupant!['full_name'] ?? 'Resident'}'
                                : 'Type: ${bed.bedType} • Condition: ${bed.condition}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      tooltip: 'Delete Bed',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        if (isOccupied) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Cannot Delete Occupied Bed'),
                              content: Text('Bed ${bed.bedNumberOrCode} is currently occupied. Please checkout or transfer the resident before deleting this bed.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                              ],
                            ),
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Bed Deletion'),
                              content: Text('Are you sure you want to delete Bed ${bed.bedNumberOrCode}? Room capacity will be reduced accordingly.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await notifier.deleteBed(bed.id, detail.id);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

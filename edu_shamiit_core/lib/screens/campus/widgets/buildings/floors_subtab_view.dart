import 'package:flutter/material.dart';
import '../../models/campus_models.dart';

class FloorsSubtabView extends StatelessWidget {
  final BuildingModel building;
  final List<BuildingFloorModel> floors;
  final bool isLoading;
  final VoidCallback onAddFloor;
  final ValueChanged<BuildingFloorModel> onEditFloor;
  final ValueChanged<BuildingFloorModel> onDeleteFloor;
  final ValueChanged<BuildingFloorModel> onViewRooms;

  const FloorsSubtabView({
    super.key,
    required this.building,
    required this.floors,
    this.isLoading = false,
    required this.onAddFloor,
    required this.onEditFloor,
    required this.onDeleteFloor,
    required this.onViewRooms,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & Add Floor Button Row
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              'Floors in ${building.code} - ${building.name}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAddFloor,
              icon: const Icon(Icons.add, size: 15, color: Colors.white),
              label: const Text('Add Floor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Table container
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : floors.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'No floors added yet. Click "+ Add Floor" to begin.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          columnSpacing: 24,
                          horizontalMargin: 16,
                          columns: const [
                            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Floor Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Total Rooms', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Room Types (Count)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Occupancy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                          ],
                          rows: List.generate(floors.length, (idx) {
                            final floor = floors[idx];
                            final occPct = floor.occupancyPercentage;

                            return DataRow(
                              cells: [
                                DataCell(Text('${idx + 1}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        floor.name,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${floor.totalRooms}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500))),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 240),
                                    child: Text(
                                      floor.roomTypesSummary,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${floor.capacity}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${floor.occupancy} (${occPct.toStringAsFixed(1)}%)',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, size: 16),
                                        color: const Color(0xFF2563EB),
                                        tooltip: 'View Rooms',
                                        onPressed: () => onViewRooms(floor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        color: const Color(0xFF64748B),
                                        tooltip: 'Edit Floor',
                                        onPressed: () => onEditFloor(floor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16),
                                        color: const Color(0xFFEF4444),
                                        tooltip: 'Delete Floor',
                                        onPressed: () => onDeleteFloor(floor),
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
        ),
        const SizedBox(height: 12),

        // Footer Pagination
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing 1 - ${floors.length} of ${floors.length} floors',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPaginationButton(Icons.keyboard_double_arrow_left, null),
                  _buildPaginationButton(Icons.chevron_left, null),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  _buildPaginationButton(Icons.chevron_right, null),
                  _buildPaginationButton(Icons.keyboard_double_arrow_right, null),
                  const SizedBox(width: 14),
                  Text('Rows per page: 10', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 16),
      color: const Color(0xFF64748B),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: onPressed,
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../common/campus_pagination_bar.dart';

class FloorsSubtabView extends StatefulWidget {
  final BuildingModel building;
  final List<BuildingFloorModel> floors;
  final bool isLoading;
  final VoidCallback onAddFloor;
  final ValueChanged<BuildingFloorModel> onEditFloor;
  final ValueChanged<BuildingFloorModel> onDeleteFloor;
  final ValueChanged<BuildingFloorModel> onViewRooms;

  // Pagination & Sorting props
  final int totalFloorsCount;
  final int currentPage;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final String? sortBy;
  final String? sortOrder;
  final void Function(String columnKey, bool ascending)? onSortChanged;

  const FloorsSubtabView({
    super.key,
    required this.building,
    required this.floors,
    this.isLoading = false,
    required this.onAddFloor,
    required this.onEditFloor,
    required this.onDeleteFloor,
    required this.onViewRooms,
    this.totalFloorsCount = 0,
    this.currentPage = 1,
    this.pageSize = 10,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.sortBy,
    this.sortOrder,
    this.onSortChanged,
  });

  @override
  State<FloorsSubtabView> createState() => _FloorsSubtabViewState();
}

class _FloorsSubtabViewState extends State<FloorsSubtabView> {
  int? _sortColIndex = 0;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _syncSortState();
  }

  @override
  void didUpdateWidget(covariant FloorsSubtabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortBy != widget.sortBy || oldWidget.sortOrder != widget.sortOrder) {
      _syncSortState();
    }
  }

  void _syncSortState() {
    _sortAsc = (widget.sortOrder ?? 'asc').toLowerCase() == 'asc';
    switch (widget.sortBy) {
      case 'floor_level':
        _sortColIndex = 0;
        break;
      case 'name':
        _sortColIndex = 1;
        break;
      case 'total_rooms':
        _sortColIndex = 2;
        break;
      case 'capacity':
        _sortColIndex = 4;
        break;
      case 'occupancy':
        _sortColIndex = 5;
        break;
      default:
        _sortColIndex = 0;
    }
  }

  void _handleSort(int colIndex, String colKey, bool asc) {
    setState(() {
      _sortColIndex = colIndex;
      _sortAsc = asc;
    });
    widget.onSortChanged?.call(colKey, asc);
  }

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
              'Floors in ${widget.building.code} - ${widget.building.name}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddFloor,
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: const Text('Add Floor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Table container
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : widget.floors.isEmpty
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
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortColIndex,
                          sortAscending: _sortAsc,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          headingRowHeight: 34,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 35,
                          columnSpacing: 18,
                          horizontalMargin: 12,
                          columns: [
                            DataColumn(
                              label: const Text('# Level', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                              onSort: (idx, asc) => _handleSort(idx, 'floor_level', asc),
                            ),
                            DataColumn(
                              label: const Text('Floor Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                              onSort: (idx, asc) => _handleSort(idx, 'name', asc),
                            ),
                            DataColumn(
                              label: const Text('Total Rooms', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                              onSort: (idx, asc) => _handleSort(idx, 'total_rooms', asc),
                            ),
                            const DataColumn(
                              label: Text('Room Types (Count)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                            ),
                            DataColumn(
                              label: const Text('Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                              onSort: (idx, asc) => _handleSort(idx, 'capacity', asc),
                            ),
                            DataColumn(
                              label: const Text('Occupancy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                              onSort: (idx, asc) => _handleSort(idx, 'occupancy', asc),
                            ),
                            const DataColumn(
                              label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                            ),
                          ],
                          rows: List.generate(widget.floors.length, (idx) {
                            final floor = widget.floors[idx];
                            final occPct = floor.occupancyPercentage;

                            return DataRow(
                              cells: [
                                DataCell(Text('L${floor.floorLevel}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)))),
                                DataCell(
                                  Text(
                                    floor.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                DataCell(Text('${floor.totalRooms}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500))),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 220),
                                    child: Text(
                                      floor.roomTypesSummary,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text('${floor.capacity}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${floor.occupancy} (${occPct.toStringAsFixed(1)}%)',
                                      style: const TextStyle(
                                        fontSize: 10.5,
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
                                        icon: const Icon(Icons.visibility_outlined, size: 15),
                                        color: const Color(0xFF2563EB),
                                        tooltip: 'View Rooms',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () => widget.onViewRooms(floor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                        color: const Color(0xFF64748B),
                                        tooltip: 'Edit Floor',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () => widget.onEditFloor(floor),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 15),
                                        color: const Color(0xFFEF4444),
                                        tooltip: 'Delete Floor',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () => widget.onDeleteFloor(floor),
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
        const SizedBox(height: 8),

        // Powerful Reusable Pagination Bar
        CampusPaginationBar(
          currentPage: widget.currentPage,
          pageSize: widget.pageSize,
          totalCount: widget.totalFloorsCount > 0 ? widget.totalFloorsCount : widget.floors.length,
          itemLabel: 'floors',
          onPageChanged: widget.onPageChanged,
          onPageSizeChanged: widget.onPageSizeChanged,
        ),
      ],
    );
  }
}

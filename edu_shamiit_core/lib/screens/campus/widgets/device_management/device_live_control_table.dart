import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';
import '../common/campus_pagination_bar.dart';

/// Lightweight, high-performance interactive level bar for table cells.
/// Replaces Material Slider to completely eliminate gesture arena collisions,
/// overlay entry leaks, and "child.owner == owner" assertions in scrollable tables.
class CompactInteractiveTrack extends StatelessWidget {
  final double value; // 0 to 100
  final double min;
  final double max;
  final ValueChanged<int> onChanged;
  final Color activeColor;
  final Color inactiveColor;
  final double width;
  final double height;

  const CompactInteractiveTrack({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    required this.onChanged,
    this.activeColor = const Color(0xFF2563EB),
    this.inactiveColor = const Color(0xFFE2E8F0),
    this.width = 75,
    this.height = 16,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    final ratio = (max > min) ? ((clamped - min) / (max - min)).clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final localPos = box.globalToLocal(details.globalPosition);
            final newRatio = (localPos.dx / box.size.width).clamp(0.0, 1.0);
            final newVal = min + (newRatio * (max - min));
            onChanged(newVal.round());
          }
        },
        onHorizontalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final localPos = box.globalToLocal(details.globalPosition);
            final newRatio = (localPos.dx / box.size.width).clamp(0.0, 1.0);
            final newVal = min + (newRatio * (max - min));
            onChanged(newVal.round());
          }
        },
        child: Center(
          child: Container(
            height: 5,
            width: width,
            decoration: BoxDecoration(
              color: inactiveColor,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  left: (ratio * (width - 10)).clamp(0.0, width - 10),
                  top: -2.5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: activeColor, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeviceLiveControlTable extends StatelessWidget {
  final List<DeviceItemModel> devices;
  final bool isLoading;
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Set<String> selectedDeviceIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<bool> onToggleSelectAll;
  final Function(DeviceItemModel) onTogglePower;
  final Function(DeviceItemModel, int) onSetTemperature;
  final Function(DeviceItemModel, String) onSetHvacMode;
  final Function(DeviceItemModel, String) onSetFanSpeed;
  final Function(DeviceItemModel, int) onSetBrightness;
  final Function(DeviceItemModel, String) onSetProjectorInput;
  final Function(DeviceItemModel, int) onSetProjectorVolume;
  final Function(DeviceItemModel, String) onGateControl;
  final Function(DeviceItemModel) onInspectDevice;
  final Function(DeviceItemModel) onDeleteDevice;
  final Function(DeviceItemModel)? onRebootDevice;
  final VoidCallback? onOpenFilters;
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final String? sortColumn;
  final bool sortAscending;
  final ValueChanged<String>? onSortChanged;
  final String? activeLocationBreadcrumb;
  final VoidCallback? onClearLocation;
  final String? activeTypeFilter;
  final VoidCallback? onClearType;
  final String? activeStatusFilter;
  final VoidCallback? onClearStatus;
  final VoidCallback? onResetAllFilters;
  final Function(bool turnOn)? onBulkPowerToggle;
  final VoidCallback? onBulkReboot;
  final VoidCallback? onBulkDelete;
  final VoidCallback? onClearSelection;

  const DeviceLiveControlTable({
    super.key,
    required this.devices,
    required this.isLoading,
    required this.activeTab,
    required this.onTabChanged,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.selectedDeviceIds,
    required this.onToggleSelect,
    required this.onToggleSelectAll,
    required this.onTogglePower,
    required this.onSetTemperature,
    required this.onSetHvacMode,
    required this.onSetFanSpeed,
    required this.onSetBrightness,
    required this.onSetProjectorInput,
    required this.onSetProjectorVolume,
    required this.onGateControl,
    required this.onInspectDevice,
    required this.onDeleteDevice,
    this.onRebootDevice,
    this.onOpenFilters,
    required this.currentPage,
    this.pageSize = 10,
    required this.totalCount,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.sortColumn,
    this.sortAscending = true,
    this.onSortChanged,
    this.activeLocationBreadcrumb,
    this.onClearLocation,
    this.activeTypeFilter,
    this.onClearType,
    this.activeStatusFilter,
    this.onClearStatus,
    this.onResetAllFilters,
    this.onBulkPowerToggle,
    this.onBulkReboot,
    this.onBulkDelete,
    this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tabs = [
      'Live Device Control',
      'By Location',
      'By Type',
      'By Group',
      'By Scene',
    ];

    final isAllSelected = devices.isNotEmpty && selectedDeviceIds.length == devices.length;
    final hasActiveFilters = (activeLocationBreadcrumb != null && activeLocationBreadcrumb!.isNotEmpty) ||
        (activeTypeFilter != null && activeTypeFilter!.isNotEmpty && activeTypeFilter != 'All') ||
        (activeStatusFilter != null && activeStatusFilter!.isNotEmpty && activeStatusFilter != 'All') ||
        searchQuery.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-tabs & Search/Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 5 Tab Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tabs.map((tab) {
                      final isActive = activeTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => onTabChanged(tab),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                   ? theme.colorScheme.primary
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Search & Filter Actions
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 32,
                        child: TextField(
                          onChanged: onSearchChanged,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search device (name, ID, room)...',
                            hintStyle: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onOpenFilters,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: hasActiveFilters
                                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasActiveFilters
                                  ? theme.colorScheme.primary
                                  : (isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.filter_list_rounded,
                                size: 16,
                                color: hasActiveFilters
                                    ? theme.colorScheme.primary
                                    : (isDark ? Colors.white : const Color(0xFF334155)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasActiveFilters
                                      ? theme.colorScheme.primary
                                      : (isDark ? Colors.white : const Color(0xFF334155)),
                                ),
                              ),
                              if (hasActiveFilters) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Active Filter Chips Bar (if filters are active)
          if (hasActiveFilters)
            _buildActiveFiltersBar(context, isDark, theme),

          // Multi-Selection Operations Toolbar (sticky when selectedDeviceIds is non-empty)
          if (selectedDeviceIds.isNotEmpty)
            _buildMultiSelectToolbar(context, isDark, theme),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Content with robust horizontal scroll and zero RenderFlex overflows
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.devices_other, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No devices found matching current filters',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            if (hasActiveFilters) ...[
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: onResetAllFilters,
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Reset All Filters', style: TextStyle(fontSize: 11.5)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final tableWidth = (constraints.maxWidth.isFinite && constraints.maxWidth > 980)
                              ? constraints.maxWidth
                              : 980.0;
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Table Header Row with dynamic database sorting
                                    _buildTableHeader(context, isDark, isAllSelected),
                                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                    // Table Data Rows
                                    ...devices.map((d) {
                                      final isSelected = selectedDeviceIds.contains(d.id);
                                      return _buildDeviceRow(context, d, isSelected, isDark);
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Pagination Footer with Page Size Selector & Full Navigation Controls
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          CampusPaginationBar(
            currentPage: currentPage,
            pageSize: pageSize,
            totalCount: totalCount,
            itemLabel: 'devices',
            pageSizes: const [5, 10, 20, 50, 100],
            onPageChanged: onPageChanged,
            onPageSizeChanged: (newSize) {
              if (onPageSizeChanged != null) {
                onPageSizeChanged!(newSize);
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Active Filters Strip ---
  Widget _buildActiveFiltersBar(BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'Active Filters:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),

            // Location Chip
            if (activeLocationBreadcrumb != null && activeLocationBreadcrumb!.isNotEmpty)
              _buildFilterChip(
                icon: Icons.place_rounded,
                label: activeLocationBreadcrumb!,
                onRemove: onClearLocation,
                isDark: isDark,
              ),

            // Type Chip
            if (activeTypeFilter != null && activeTypeFilter!.isNotEmpty && activeTypeFilter != 'All')
              _buildFilterChip(
                icon: Icons.category_rounded,
                label: 'Type: $activeTypeFilter',
                onRemove: onClearType,
                isDark: isDark,
              ),

            // Status Chip
            if (activeStatusFilter != null && activeStatusFilter!.isNotEmpty && activeStatusFilter != 'All')
              _buildFilterChip(
                icon: Icons.circle,
                label: 'Status: $activeStatusFilter',
                onRemove: onClearStatus,
                isDark: isDark,
              ),

            // Search Query Chip
            if (searchQuery.trim().isNotEmpty)
              _buildFilterChip(
                icon: Icons.search_rounded,
                label: '"$searchQuery"',
                onRemove: () => onSearchChanged(''),
                isDark: isDark,
              ),

            const SizedBox(width: 6),
            InkWell(
              onTap: onResetAllFilters,
              child: Text(
                'Clear All',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback? onRemove,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(8),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Multi-Select Batch Actions Toolbar ---
  Widget _buildMultiSelectToolbar(BuildContext context, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
            : const Color(0xFFEFF6FF),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
            width: 1.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${selectedDeviceIds.length} Selected',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Bulk Turn ON
            ElevatedButton.icon(
              onPressed: () => onBulkPowerToggle?.call(true),
              icon: const Icon(Icons.power_settings_new_rounded, size: 14, color: Colors.white),
              label: const Text('Turn ON', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),

            // Bulk Turn OFF
            ElevatedButton.icon(
              onPressed: () => onBulkPowerToggle?.call(false),
              icon: const Icon(Icons.power_off_rounded, size: 14, color: Colors.white),
              label: const Text('Turn OFF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),

            // Bulk Reboot
            OutlinedButton.icon(
              onPressed: onBulkReboot,
              icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF2563EB)),
              label: const Text('Reboot Selected', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),

            // Bulk Delete
            OutlinedButton.icon(
              onPressed: onBulkDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
              label: const Text('Delete Selected', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),

            // Clear Selection
            InkWell(
              onTap: onClearSelection,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.close_rounded, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(
                      'Deselect All',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Header Row with dynamic Database Sorting ---
  Widget _buildTableHeader(BuildContext context, bool isDark, bool isAllSelected) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      height: 38,
      color: headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Single Selection Checkbox
          SizedBox(
            width: 28,
            child: Checkbox(
              value: isAllSelected,
              onChanged: (val) => onToggleSelectAll(val ?? false),
            ),
          ),
          const SizedBox(width: 8),

          // Device Name (Sortable, column: 'device_name')
          SizedBox(
            width: 160,
            child: _buildSortableHeaderCell(
              label: 'Device Name',
              columnKey: 'device_name',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // Type (Sortable, column: 'type_name')
          SizedBox(
            width: 100,
            child: _buildSortableHeaderCell(
              label: 'Type',
              columnKey: 'type_name',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // Location (Sortable, column: 'location_path')
          SizedBox(
            width: 180,
            child: _buildSortableHeaderCell(
              label: 'Location (Building > Floor > Room)',
              columnKey: 'location_path',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // Status (Sortable, column: 'is_online')
          SizedBox(
            width: 95,
            child: _buildSortableHeaderCell(
              label: 'Status',
              columnKey: 'is_online',
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 8),

          // Control / Current State (Width: 280, non-sortable)
          SizedBox(
            width: 280,
            child: Text(
              'Control / Current State',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Actions (Width: 40, non-sortable)
          SizedBox(
            width: 40,
            child: Text(
              'Actions',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortableHeaderCell({
    required String label,
    required String columnKey,
    required bool isDark,
  }) {
    final isSorted = sortColumn == columnKey;

    return InkWell(
      onTap: onSortChanged != null ? () => onSortChanged!(columnKey) : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSorted
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSorted
                  ? (sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                  : Icons.unfold_more_rounded,
              size: 13,
              color: isSorted
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceRow(
    BuildContext context,
    DeviceItemModel d,
    bool isSelected,
    bool isDark,
  ) {
    final rowBg = isSelected
        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    return Container(
      key: ValueKey('row_${d.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Single Checkbox (No double checkboxes anywhere)
          SizedBox(
            width: 28,
            child: Checkbox(
              key: ValueKey('chk_${d.id}'),
              value: isSelected,
              onChanged: (_) => onToggleSelect(d.id),
            ),
          ),
          const SizedBox(width: 8),

          // Device Name Cell
          SizedBox(
            width: 160,
            child: InkWell(
              onTap: () => onInspectDevice(d),
              borderRadius: BorderRadius.circular(4),
              child: _buildDeviceNameCell(d, isDark),
            ),
          ),
          const SizedBox(width: 8),

          // Type Cell
          SizedBox(
            width: 100,
            child: Text(
              d.typeName,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Location Cell
          SizedBox(
            width: 180,
            child: Text(
              d.locationDisplay,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // Status Badge Cell
          SizedBox(
            width: 95,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusBadge(d.isOnline),
            ),
          ),
          const SizedBox(width: 8),

          // Capability Controls Cell (Width: 280)
          SizedBox(
            width: 280,
            child: _buildCapabilityControls(context, d, isDark),
          ),
          const SizedBox(width: 8),

          // Actions Popup Menu
          SizedBox(
            width: 40,
            child: Center(child: _buildActionsMenu(d)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceNameCell(DeviceItemModel d, bool isDark) {
    IconData icon = Icons.devices;
    Color iconColor = const Color(0xFF2563EB);

    final lowerCode = d.typeCode.toLowerCase();
    if (lowerCode.contains('ac')) {
      icon = Icons.ac_unit_rounded;
      iconColor = const Color(0xFF0284C7);
    } else if (lowerCode.contains('light')) {
      icon = Icons.lightbulb_outline_rounded;
      iconColor = const Color(0xFFEAB308);
    } else if (lowerCode.contains('fan')) {
      icon = Icons.mode_fan_off_rounded;
      iconColor = const Color(0xFF06B6D4);
    } else if (lowerCode.contains('projector')) {
      icon = Icons.videocam_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (lowerCode.contains('gate')) {
      icon = Icons.door_front_door_rounded;
      iconColor = const Color(0xFFF43F5E);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            d.deviceName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityControls(BuildContext context, DeviceItemModel d, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: _buildCapabilityControlsRow(context, d, isDark),
    );
  }

  Widget _buildCapabilityControlsRow(BuildContext context, DeviceItemModel d, bool isDark) {
    final state = d.currentState;
    final isPowerOn = d.powerState;
    final lowerCode = d.typeCode.toLowerCase();

    // Standard Power Toggle Button
    Widget powerToggle = InkWell(
      key: ValueKey('pwr_btn_${d.id}'),
      onTap: () => onTogglePower(d),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4.5),
        decoration: BoxDecoration(
          color: isPowerOn ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isPowerOn ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Icon(
          Icons.power_settings_new_rounded,
          size: 13,
          color: isPowerOn ? const Color(0xFF16A34A) : const Color(0xFF64748B),
        ),
      ),
    );

    num? parseNum(dynamic val) {
      if (val is num) return val;
      if (val is String) return num.tryParse(val);
      if (val is bool) return val ? 1 : 0;
      return null;
    }

    // 1. AC (HVAC) Controls
    if (lowerCode.contains('ac')) {
      final temp = parseNum(state['temperature'])?.toInt() ?? 24;
      final rawMode = state['mode']?.toString() ?? 'Cool';
      final mode = ['Cool', 'Heat', 'Fan', 'Auto', 'Dry'].contains(rawMode) ? rawMode : 'Cool';
      final rawFan = state['fan_speed']?.toString() ?? 'Medium';
      final fanSpeed = ['Low', 'Medium', 'High', 'Auto'].contains(rawFan) ? rawFan : 'Medium';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          powerToggle,
          const SizedBox(width: 6),

          // Temp stepper: - 24°C +
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => onSetTemperature(d, temp - 1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Text('-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                Text(' $temp°C ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: () => onSetTemperature(d, temp + 1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    child: Text('+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),

          // Mode Popup Selector
          PopupMenuButton<String>(
            key: ValueKey('ac_mode_${d.id}'),
            tooltip: 'HVAC Mode',
            initialValue: mode,
            onSelected: (val) => onSetHvacMode(d, val),
            itemBuilder: (context) => ['Cool', 'Heat', 'Fan', 'Auto', 'Dry']
                .map((m) => PopupMenuItem(
                      value: m,
                      height: 32,
                      child: Text(m, style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),

          // Fan Speed Popup Selector
          PopupMenuButton<String>(
            key: ValueKey('ac_fan_${d.id}'),
            tooltip: 'Fan Speed',
            initialValue: fanSpeed,
            onSelected: (val) => onSetFanSpeed(d, val),
            itemBuilder: (context) => ['Low', 'Medium', 'High', 'Auto']
                .map((s) => PopupMenuItem(
                      value: s,
                      height: 32,
                      child: Text(s, style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fanSpeed,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 2. Lighting Controls (Power + Brightness Level Track)
    if (lowerCode.contains('light')) {
      final brightness = parseNum(state['brightness'])?.toDouble() ?? 80.0;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          powerToggle,
          const SizedBox(width: 6),
          const Icon(Icons.wb_sunny_outlined, size: 13, color: Color(0xFFEAB308)),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: Text(
              '${brightness.toInt()}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          CompactInteractiveTrack(
            value: brightness,
            min: 0,
            max: 100,
            width: 80,
            height: 16,
            activeColor: const Color(0xFF2563EB),
            inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            onChanged: (v) => onSetBrightness(d, v),
          ),
        ],
      );
    }

    // 3. Fan Controls (Power + Low/Medium/High segments)
    if (lowerCode.contains('fan')) {
      final speed = state['speed']?.toString() ?? 'Medium';

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          powerToggle,
          const SizedBox(width: 6),
          ...['Low', 'Medium', 'High'].map((s) {
            final isCur = speed == s;
            return Padding(
              key: ValueKey('fan_seg_${d.id}_$s'),
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => onSetFanSpeed(d, s),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCur ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCur ? FontWeight.w700 : FontWeight.w500,
                      color: isCur ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    // 4. Projector Controls (Power + Input HDMI 1 + Volume)
    if (lowerCode.contains('projector')) {
      final rawInput = state['input']?.toString() ?? 'HDMI 1';
      final input = ['HDMI 1', 'HDMI 2', 'Type-C', 'Wireless', 'VGA'].contains(rawInput) ? rawInput : 'HDMI 1';
      final vol = parseNum(state['volume'])?.toDouble() ?? 70.0;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          powerToggle,
          const SizedBox(width: 6),

          // Input Selector Popup
          PopupMenuButton<String>(
            key: ValueKey('proj_inp_${d.id}'),
            tooltip: 'Video Input',
            initialValue: input,
            onSelected: (val) => onSetProjectorInput(d, val),
            itemBuilder: (context) => ['HDMI 1', 'HDMI 2', 'Type-C', 'Wireless', 'VGA']
                .map((i) => PopupMenuItem(
                      value: i,
                      height: 32,
                      child: Text(i, style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    input,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Volume Level Track
          const Icon(Icons.volume_up_rounded, size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 3),
          CompactInteractiveTrack(
            value: vol,
            min: 0,
            max: 100,
            width: 65,
            height: 16,
            activeColor: const Color(0xFF2563EB),
            inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            onChanged: (v) => onSetProjectorVolume(d, v),
          ),
          const SizedBox(width: 3),
          Text('${vol.toInt()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      );
    }

    // 5. Gate Controller (Open / Close / Lock / Unlock buttons)
    if (lowerCode.contains('gate')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Open', 'Close', 'Lock', 'Unlock'].map((action) {
          return Padding(
            key: ValueKey('gate_act_${d.id}_$action'),
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              onTap: () => onGateControl(d, action),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    // Default Fallback: Just power switch
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        powerToggle,
        const SizedBox(width: 6),
        Text(isPowerOn ? 'ON' : 'OFF', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionsMenu(DeviceItemModel d) {
    return PopupMenuButton<String>(
      key: ValueKey('menu_${d.id}'),
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      onSelected: (val) {
        if (val == 'inspect') onInspectDevice(d);
        if (val == 'reboot' && onRebootDevice != null) onRebootDevice!(d);
        if (val == 'delete') onDeleteDevice(d);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'inspect', child: Text('View Details & Telemetry')),
        const PopupMenuItem(value: 'reboot', child: Text('Reboot Hardware')),
        const PopupMenuItem(value: 'delete', child: Text('Delete Device', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}

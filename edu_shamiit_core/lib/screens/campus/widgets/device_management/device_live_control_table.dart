import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

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
  final int totalCount;
  final ValueChanged<int> onPageChanged;

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
    required this.totalCount,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      'Live Device Control',
      'By Location',
      'By Type',
      'By Group',
      'By Scene',
    ];

    final isAllSelected = devices.isNotEmpty && selectedDeviceIds.length == devices.length;

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
                                  ? const Color(0xFF2563EB)
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
                        width: 200,
                        height: 32,
                        child: TextField(
                          onChanged: onSearchChanged,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search device (name, ID, room)...',
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.filter_list_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF334155)),
                              const SizedBox(width: 4),
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
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
                              'No devices found',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
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
                                    // Table Header Row
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

          // Pagination Footer
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${devices.length} of $totalCount devices',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                      ),
                      Text(
                        '$currentPage',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        onPressed: (currentPage * 10 < totalCount) ? () => onPageChanged(currentPage + 1) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context, bool isDark, bool isAllSelected) {
    final headerBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final headerStyle = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );

    return Container(
      height: 38,
      color: headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Selection Checkbox
          SizedBox(
            width: 28,
            child: Checkbox(
              value: isAllSelected,
              onChanged: (val) => onToggleSelectAll(val ?? false),
            ),
          ),
          const SizedBox(width: 8),

          // Device Name (Width: 160)
          SizedBox(
            width: 160,
            child: Text('Device Name', style: headerStyle),
          ),
          const SizedBox(width: 8),

          // Type (Width: 100)
          SizedBox(
            width: 100,
            child: Text('Type', style: headerStyle),
          ),
          const SizedBox(width: 8),

          // Location (Width: 180)
          SizedBox(
            width: 180,
            child: Text('Location (Building > Floor > Room)', style: headerStyle),
          ),
          const SizedBox(width: 8),

          // Status (Width: 85)
          SizedBox(
            width: 85,
            child: Text('Status', style: headerStyle),
          ),
          const SizedBox(width: 8),

          // Control / Current State (Width: 280)
          SizedBox(
            width: 280,
            child: Text('Control / Current State', style: headerStyle),
          ),
          const SizedBox(width: 8),

          // Actions (Width: 40)
          SizedBox(
            width: 40,
            child: Text('Actions', style: headerStyle, textAlign: TextAlign.center),
          ),
        ],
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
          // Single Checkbox
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
            width: 85,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
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

    // 1. AC (HVAC) Controls
    if (lowerCode.contains('ac')) {
      final temp = (state['temperature'] as num?)?.toInt() ?? 24;
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
      final brightness = (state['brightness'] as num?)?.toDouble() ?? 80.0;

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
      final vol = (state['volume'] as num?)?.toDouble() ?? 70.0;

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

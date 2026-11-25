import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class DeviceFilterDialog extends StatefulWidget {
  final String? initialBuilding;
  final String? initialType;
  final String? initialStatus;
  final List<BuildingDeviceBreakdown>? buildings;
  final List<DeviceTypeBreakdown>? types;
  final Function(String? building, String? type, String? status) onApply;

  const DeviceFilterDialog({
    super.key,
    this.initialBuilding,
    this.initialType,
    this.initialStatus,
    this.buildings,
    this.types,
    required this.onApply,
  });

  @override
  State<DeviceFilterDialog> createState() => _DeviceFilterDialogState();
}

class _DeviceFilterDialogState extends State<DeviceFilterDialog> {
  late String _building;
  late String _type;
  late String _status;

  @override
  void initState() {
    super.initState();
    _building = widget.initialBuilding ?? 'All';
    _type = widget.initialType ?? 'All';
    _status = widget.initialStatus ?? 'All';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic building dropdown items
    final buildingItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'All', child: Text('Entire Campus (All Buildings)')),
    ];
    if (widget.buildings != null && widget.buildings!.isNotEmpty) {
      for (final b in widget.buildings!) {
        buildingItems.add(DropdownMenuItem(
          value: b.code,
          child: Text('${b.code} - ${b.name} (${b.totalDevices} devices)'),
        ));
      }
    } else {
      // Fallback
      buildingItems.addAll(const [
        DropdownMenuItem(value: 'B1', child: Text('B1 - Academic Block (A)')),
        DropdownMenuItem(value: 'B2', child: Text('B2 - Science Block')),
        DropdownMenuItem(value: 'B3', child: Text('B3 - Admin Block')),
        DropdownMenuItem(value: 'B4', child: Text('B4 - Library Block')),
        DropdownMenuItem(value: 'B5', child: Text('B5 - Hostel Block')),
        DropdownMenuItem(value: 'B6', child: Text('B6 - Sports Complex')),
      ]);
    }

    // Dynamic device type dropdown items
    final typeItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'All', child: Text('All Device Types')),
    ];
    if (widget.types != null && widget.types!.isNotEmpty) {
      for (final t in widget.types!) {
        final val = t.type.toLowerCase();
        if (!typeItems.any((item) => item.value == val)) {
          typeItems.add(DropdownMenuItem(
            value: val,
            child: Text('${t.type} (${t.count})'),
          ));
        }
      }
    } else {
      typeItems.addAll(const [
        DropdownMenuItem(value: 'ac', child: Text('AC (HVAC)')),
        DropdownMenuItem(value: 'lighting', child: Text('Lighting')),
        DropdownMenuItem(value: 'fan', child: Text('Fans')),
        DropdownMenuItem(value: 'projector', child: Text('Projectors')),
        DropdownMenuItem(value: 'gate', child: Text('Access & Gates')),
        DropdownMenuItem(value: 'power', child: Text('Power & Switches')),
      ]);
    }

    final validBuilding = buildingItems.any((item) => item.value == _building) ? _building : 'All';
    final validType = typeItems.any((item) => item.value == _type) ? _type : 'All';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Filter Campus Devices',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Dynamic Building Selector
            Text('Building / Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(height: 6),
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: validBuilding,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: buildingItems,
              onChanged: (v) => setState(() => _building = v ?? 'All'),
            ),
            const SizedBox(height: 14),

            // Dynamic Device Type Selector
            Text('Device Category / Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(height: 6),
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: validType,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: typeItems,
              onChanged: (v) => setState(() => _type = v ?? 'All'),
            ),
            const SizedBox(height: 14),

            // Status Selector
            Text('Operational / Online Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(height: 6),
            AppSearchableDropdownFormField<String>.fromMenuItems(
              initialValue: ['All', 'online', 'offline'].contains(_status) ? _status : 'All',
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Statuses (Online & Offline)')),
                DropdownMenuItem(value: 'online', child: Text('Online Only')),
                DropdownMenuItem(value: 'offline', child: Text('Offline Only')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'All'),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onApply(null, null, null);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Reset All'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      _building == 'All' ? null : _building,
                      _type == 'All' ? null : _type,
                      _status == 'All' ? null : _status,
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

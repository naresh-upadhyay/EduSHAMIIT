import 'package:flutter/material.dart';

class DeviceFilterDialog extends StatefulWidget {
  final String? initialBuilding;
  final String? initialType;
  final String? initialStatus;
  final Function(String? building, String? type, String? status) onApply;

  const DeviceFilterDialog({
    super.key,
    this.initialBuilding,
    this.initialType,
    this.initialStatus,
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
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Filter Campus Devices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Building Selector
            Text('Building / Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _building,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('Entire Campus (All Buildings)')),
                DropdownMenuItem(value: 'B1', child: Text('B1 - Academic Block')),
                DropdownMenuItem(value: 'B2', child: Text('B2 - Science Block')),
                DropdownMenuItem(value: 'B3', child: Text('B3 - Admin Block')),
                DropdownMenuItem(value: 'B4', child: Text('B4 - Library Block')),
                DropdownMenuItem(value: 'B5', child: Text('B5 - Hostel Block')),
                DropdownMenuItem(value: 'B6', child: Text('B6 - Sports Complex')),
              ],
              onChanged: (v) => setState(() => _building = v ?? 'All'),
            ),
            const SizedBox(height: 14),

            // Device Type Selector
            Text('Device Category / Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Device Types')),
                DropdownMenuItem(value: 'ac', child: Text('AC (HVAC)')),
                DropdownMenuItem(value: 'lighting', child: Text('Lighting')),
                DropdownMenuItem(value: 'fan', child: Text('Fans')),
                DropdownMenuItem(value: 'projector', child: Text('Projectors')),
                DropdownMenuItem(value: 'gate', child: Text('Access & Gates')),
                DropdownMenuItem(value: 'power', child: Text('Power & Switches')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'All'),
            ),
            const SizedBox(height: 14),

            // Status Selector
            Text('Operational / Online Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _status,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Statuses')),
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

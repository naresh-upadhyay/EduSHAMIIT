import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/device_management_provider.dart';

class MapDeviceLocationDialog extends ConsumerStatefulWidget {
  final String? initialDeviceId;
  final String? initialDeviceName;
  final String? initialFloorId;
  final String? initialBuildingId;
  final String? initialRoomId;

  const MapDeviceLocationDialog({
    super.key,
    this.initialDeviceId,
    this.initialDeviceName,
    this.initialFloorId,
    this.initialBuildingId,
    this.initialRoomId,
  });

  @override
  ConsumerState<MapDeviceLocationDialog> createState() => _MapDeviceLocationDialogState();
}

class _MapDeviceLocationDialogState extends ConsumerState<MapDeviceLocationDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedBuildingId;
  late String _selectedFloorId;
  String? _selectedRoomId;
  late String _selectedDeviceId;
  String _mountType = 'Wall';
  double _mountHeight = 2.4;
  final TextEditingController _assetTagController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _mountTypes = ['Wall', 'Ceiling', 'Desk', 'Rack', 'Floor', 'Pole'];

  @override
  void initState() {
    super.initState();
    final prov = ref.read(deviceManagementProvider);
    _selectedBuildingId = widget.initialBuildingId ?? prov.selectedLocationBuildingId ?? '2af829b6-81a4-469a-a91a-71f2bd390fc4';
    _selectedFloorId = widget.initialFloorId ?? prov.selectedLocationFloorId;
    final rooms = prov.selectedLocationDetails?.rooms ?? [];
    _selectedRoomId = widget.initialRoomId ?? (rooms.isNotEmpty ? rooms.first.id : null);
    _selectedDeviceId = widget.initialDeviceId ?? '';
  }

  @override
  void dispose() {
    _assetTagController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deviceManagementProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final details = state.selectedLocationDetails;

    // Available devices from state
    final devicesList = state.devices;
    if (_selectedDeviceId.isEmpty && devicesList.isNotEmpty) {
      _selectedDeviceId = devicesList.first.id;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initialDeviceId != null ? 'Map Device to Space' : 'Map Campus Device',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Assign physical device to authoritative building room & mounting location.',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Device Selection
                        Text(
                          'Select Device',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        if (widget.initialDeviceId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.devices_rounded, color: Color(0xFF2563EB), size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  widget.initialDeviceName ?? widget.initialDeviceId!,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          AppSearchableDropdownFormField<String>.fromMenuItems(
                            initialValue: _selectedDeviceId.isNotEmpty ? _selectedDeviceId : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: devicesList.map((d) {
                              return DropdownMenuItem<String>(
                                value: d.id,
                                child: Text('${d.deviceName} (${d.deviceCode})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDeviceId = val);
                            },
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Building & Floor
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Building',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      details?.buildingName ?? 'Academic Block (A)',
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Floor',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      (details?.title != null && details!.title.contains('>')) ? details.title.split('>').last.trim() : (details?.title ?? 'First Floor (1F)'),
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Room / Space Dropdown
                        Text(
                          'Room / Space',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final rooms = details?.rooms ?? [];
                            final selectedRoomValue = rooms.any((r) => r.id == _selectedRoomId)
                                ? _selectedRoomId
                                : (rooms.isNotEmpty ? rooms.first.id : null);
                            return AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: selectedRoomValue,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              items: rooms.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r.id,
                                  child: Text('${r.roomNumber} (${r.name})', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedRoomId = val),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mount Type & Mount Height
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mount Type',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _mountType,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    items: _mountTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _mountType = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mount Height (meters)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: '2.4',
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      suffixText: 'm',
                                    ),
                                    onChanged: (val) {
                                      _mountHeight = double.tryParse(val) ?? 2.4;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Asset Tag
                        Text(
                          'Asset Tag / Barcode (Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _assetTagController,
                          decoration: InputDecoration(
                            hintText: 'e.g. AST-CAM-101',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Installation Notes
                        Text(
                          'Installation Notes',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'e.g. Near corner north wall with POE cabling',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Mapping...' : 'Confirm Mapping'),
                      onPressed: _isSubmitting ? null : _submitMapping,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitMapping() async {
    if (_selectedDeviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a device to map')));
      return;
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(deviceManagementProvider.notifier);
    final ok = await notifier.mapDevicesToLocation(
      deviceIds: [_selectedDeviceId],
      buildingId: _selectedBuildingId,
      floorId: _selectedFloorId,
      roomId: _selectedRoomId,
      mountType: _mountType,
      mountHeight: _mountHeight,
      assetTag: _assetTagController.text.trim().isNotEmpty ? _assetTagController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    setState(() => _isSubmitting = false);
    if (mounted) {
      if (ok) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device mapped successfully to location!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to map device. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

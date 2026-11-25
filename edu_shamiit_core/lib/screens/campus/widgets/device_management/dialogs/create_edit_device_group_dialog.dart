import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class CreateEditDeviceGroupDialog extends StatefulWidget {
  final Map<String, dynamic>? initialGroup;
  final DeviceGroupItem? initialGroupItem;
  final List<DeviceItemModel> availableDevices;
  final Function(Map<String, dynamic> data) onSave;

  const CreateEditDeviceGroupDialog({
    super.key,
    this.initialGroup,
    this.initialGroupItem,
    this.availableDevices = const [],
    required this.onSave,
  });

  @override
  State<CreateEditDeviceGroupDialog> createState() => _CreateEditDeviceGroupDialogState();
}

class _CreateEditDeviceGroupDialogState extends State<CreateEditDeviceGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _locationController;

  String _selectedType = 'Lighting';
  String _selectedProfile = 'Default Lighting';
  String _selectedStatus = 'active';
  String _selectedColor = '#2563EB';
  String _selectedIcon = 'lightbulb_outline';
  String _deviceSearchQuery = '';
  final Set<String> _selectedDeviceIds = {};

  final List<String> _groupTypes = [
    'Lighting',
    'HVAC (AC)',
    'AV & Display',
    'Security',
    'Network',
    'Environment',
    'Access Control',
    'Composite',
    'Power & Energy',
    'Custom',
  ];

  final List<String> _profiles = [
    'Default Lighting',
    'AC Standard',
    'Projector Base',
    'High Security',
    'Wi-Fi Standard',
    'Fan Standard',
    'Secure Access',
    'Audio Standard',
    'Sensor Standard',
    'Smart Classroom',
    'Custom Profile',
  ];

  final List<String> _colors = [
    '#2563EB',
    '#059669',
    '#D97706',
    '#DC2626',
    '#7C3AED',
    '#0891B2',
    '#475569',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.initialGroupItem;
    final map = widget.initialGroup;

    final name = item?.name ?? map?['name'] ?? '';
    final code = item?.code ?? map?['code'] ?? 'GRP-';
    final desc = item?.description ?? map?['description'] ?? '';
    final loc = item?.locationScope ?? map?['location_scope'] ?? 'Block A > Classrooms';
    final type = item?.groupType ?? map?['group_type'] ?? 'Lighting';
    final profile = item?.profileName ?? map?['profile_name'] ?? 'Default Lighting';
    final status = item?.status ?? map?['status'] ?? 'active';
    final color = item?.color ?? map?['color'] ?? '#2563EB';
    final icon = item?.icon ?? map?['icon'] ?? 'lightbulb_outline';

    _nameController = TextEditingController(text: name);
    _codeController = TextEditingController(text: code);
    _descController = TextEditingController(text: desc);
    _locationController = TextEditingController(text: loc);

    _selectedType = _groupTypes.contains(type) ? type : _groupTypes.first;
    _selectedProfile = _profiles.contains(profile) ? profile : _profiles.first;
    _selectedStatus = status.toLowerCase() == 'inactive' ? 'inactive' : 'active';
    _selectedColor = color;
    _selectedIcon = icon;

    final memberIds = map?['device_ids'] as List? ?? [];
    for (final id in memberIds) {
      _selectedDeviceIds.add(id.toString());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'description': _descController.text.trim(),
      'group_type': _selectedType,
      'location_scope': _locationController.text.trim(),
      'profile_name': _selectedProfile,
      'status': _selectedStatus,
      'color': _selectedColor,
      'icon': _selectedIcon,
      'device_ids': _selectedDeviceIds.toList(),
    };

    widget.onSave(data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.initialGroupItem != null || widget.initialGroup != null;

    final filteredDevices = widget.availableDevices.where((d) {
      if (_deviceSearchQuery.isEmpty) return true;
      final q = _deviceSearchQuery.toLowerCase();
      return d.deviceName.toLowerCase().contains(q) ||
          d.deviceCode.toLowerCase().contains(q) ||
          d.typeName.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.hub_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Device Group' : 'Create Device Group',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Organize devices into logical groups for centralized control and scheduling',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
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
              const Divider(height: 22),

              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name & Code
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Group Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Classroom Lighting - Block A',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Group Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _codeController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. GRP-LGT-BLKA',
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Location & Description
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Location / Scope *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Block A > Classrooms or Academic Block',
                                    prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Location is required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                AppSearchableDropdownFormField<String>.fromMenuItems(
                                  isExpanded: true,
                                  initialValue: _selectedStatus,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'active', child: Text('Active')),
                                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedStatus = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description
                      const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Describe purpose or rules for this logical device group',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Group Type & Control Profile
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Group Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                AppSearchableDropdownFormField<String>.fromMenuItems(
                                  isExpanded: true,
                                  initialValue: _groupTypes.contains(_selectedType) ? _selectedType : _groupTypes.first,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: _groupTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedType = val);
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
                                const Text('Control Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                AppSearchableDropdownFormField<String>.fromMenuItems(
                                  isExpanded: true,
                                  initialValue: _profiles.contains(_selectedProfile) ? _selectedProfile : _profiles.first,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: _profiles.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedProfile = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Group Color Picker
                      Row(
                        children: [
                          const Text('Accent Color:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          ..._colors.map((c) {
                            final isSel = _selectedColor == c;
                            final color = Color(int.parse('FF${c.replaceFirst('#', '')}', radix: 16));
                            return InkWell(
                              onTap: () => setState(() => _selectedColor = c),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? Colors.black : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: isSel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Device Member Selection
                      if (widget.availableDevices.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Assign Member Devices (${_selectedDeviceIds.length} selected)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  if (_selectedDeviceIds.length == widget.availableDevices.length) {
                                    _selectedDeviceIds.clear();
                                  } else {
                                    _selectedDeviceIds.addAll(widget.availableDevices.map((d) => d.id));
                                  }
                                });
                              },
                              child: Text(_selectedDeviceIds.length == widget.availableDevices.length ? 'Deselect All' : 'Select All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          onChanged: (v) => setState(() => _deviceSearchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Filter devices by name, code or type...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: filteredDevices.isEmpty
                              ? const Center(child: Text('No devices match search'))
                              : ListView.builder(
                                  itemCount: filteredDevices.length,
                                  itemBuilder: (context, idx) {
                                    final dev = filteredDevices[idx];
                                    final isChecked = _selectedDeviceIds.contains(dev.id);

                                    return CheckboxListTile(
                                      value: isChecked,
                                      dense: true,
                                      title: Text(dev.deviceName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      subtitle: Text('${dev.typeName} • ${dev.locationDisplay}', style: const TextStyle(fontSize: 10.5)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedDeviceIds.add(dev.id);
                                          } else {
                                            _selectedDeviceIds.remove(dev.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 22),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(isEditing ? 'Save Changes' : 'Create Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

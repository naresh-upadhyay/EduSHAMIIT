import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class CreateEditDeviceProfileDialog extends StatefulWidget {
  final DeviceProfileItem? initialProfile;
  final String? defaultDeviceTypeId;
  final String? defaultDeviceTypeName;
  final List<DeviceTypeDetailItem> availableDeviceTypes;
  final Function(Map<String, dynamic> data) onSave;

  const CreateEditDeviceProfileDialog({
    super.key,
    this.initialProfile,
    this.defaultDeviceTypeId,
    this.defaultDeviceTypeName,
    this.availableDeviceTypes = const [],
    required this.onSave,
  });

  @override
  State<CreateEditDeviceProfileDialog> createState() => _CreateEditDeviceProfileDialogState();
}

class _CreateEditDeviceProfileDialogState extends State<CreateEditDeviceProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _mfgController;
  late TextEditingController _modelController;
  late TextEditingController _versionController;

  String? _selectedDeviceTypeId;
  String _profileType = 'custom';
  String _status = 'active';
  bool _isDefault = false;
  bool _isSaving = false;

  // Default settings
  bool _defaultPower = false;
  double _defaultBrightness = 80;
  double _defaultTemperature = 24.0;
  String _defaultHvacMode = 'Cool';
  String _defaultFanSpeed = 'Medium';
  int _maxWattageLimit = 2500;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _codeController = TextEditingController(text: p?.code ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _mfgController = TextEditingController(text: p?.manufacturer ?? '');
    _modelController = TextEditingController(text: p?.model ?? '');
    _versionController = TextEditingController(text: p?.version ?? '1.0.0');

    _selectedDeviceTypeId = p?.deviceTypeId ?? widget.defaultDeviceTypeId;
    if (_selectedDeviceTypeId == null && widget.availableDeviceTypes.isNotEmpty) {
      _selectedDeviceTypeId = widget.availableDeviceTypes.first.id;
    }

    if (p != null) {
      _profileType = p.profileType;
      _status = p.status;
      _isDefault = p.isDefault;
      if (p.defaultSettings.containsKey('power')) {
        _defaultPower = p.defaultSettings['power'] == true;
      }
      if (p.defaultSettings.containsKey('brightness')) {
        _defaultBrightness = (p.defaultSettings['brightness'] as num?)?.toDouble() ?? 80;
      }
      if (p.defaultSettings.containsKey('temperature')) {
        _defaultTemperature = (p.defaultSettings['temperature'] as num?)?.toDouble() ?? 24.0;
      }
      if (p.defaultSettings.containsKey('hvac_mode')) {
        _defaultHvacMode = p.defaultSettings['hvac_mode']?.toString() ?? 'Cool';
      }
      if (p.defaultSettings.containsKey('fan_speed')) {
        _defaultFanSpeed = p.defaultSettings['fan_speed']?.toString() ?? 'Medium';
      }
      if (p.safetyLimits.containsKey('max_wattage')) {
        _maxWattageLimit = (p.safetyLimits['max_wattage'] as num?)?.toInt() ?? 2500;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _mfgController.dispose();
    _modelController.dispose();
    _versionController.dispose();
    super.dispose();
  }

  void _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeviceTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an associated device type')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final payload = <String, dynamic>{
      'device_type_id': _selectedDeviceTypeId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toLowerCase().replaceAll(' ', '_'),
      'profile_type': _profileType,
      'manufacturer': _mfgController.text.trim().isEmpty ? null : _mfgController.text.trim(),
      'model': _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
      'description': _descController.text.trim(),
      'version': _versionController.text.trim().isEmpty ? '1.0.0' : _versionController.text.trim(),
      'status': _status,
      'is_default': _isDefault,
      'default_settings': {
        'power': _defaultPower,
        'brightness': _defaultBrightness.round(),
        'temperature': _defaultTemperature,
        'hvac_mode': _defaultHvacMode,
        'fan_speed': _defaultFanSpeed,
      },
      'safety_limits': {
        'max_wattage': _maxWattageLimit,
        'min_temp': 16.0,
        'max_temp': 30.0,
      },
    };

    await widget.onSave(payload);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialProfile != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Control Profile: ${widget.initialProfile!.name}' : 'Add New Control Profile',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          widget.defaultDeviceTypeName != null
                              ? 'Target Device Type: ${widget.defaultDeviceTypeName}'
                              : 'Create custom telemetry mappings, safety limits, and default states.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device Type selection
                      if (widget.availableDeviceTypes.isNotEmpty && widget.defaultDeviceTypeId == null) ...[
                        const Text('Associated Device Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDeviceTypeId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: widget.availableDeviceTypes.map((dt) {
                            return DropdownMenuItem<String>(
                              value: dt.id,
                              child: Text('${dt.name} (${dt.categoryName})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedDeviceTypeId = val),
                          validator: (v) => v == null ? 'Please select a device type' : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Profile Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. High Security (24x7), PTZ Control Profile',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Profile name is required' : null,
                                  onChanged: (v) {
                                    if (!isEdit && _codeController.text.isEmpty) {
                                      _codeController.text = v.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Profile Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _codeController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. high_sec_cctv, ptz_ctrl',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Profile code is required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Profile Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _profileType,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'custom', child: Text('Custom Profile')),
                                    DropdownMenuItem(value: 'default', child: Text('Default Profile')),
                                  ],
                                  onChanged: (v) => setState(() => _profileType = v ?? 'custom'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Version', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _versionController,
                                  decoration: InputDecoration(
                                    hintText: '1.0.0',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Purpose and operational parameters of this profile...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hardware Manufacturer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _mfgController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Hikvision, Dahua',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hardware Model', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _modelController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. DS-2CD2143G2-I',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      CheckboxListTile(
                        value: _isDefault,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Make this the Default Profile for this Device Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Newly registered devices will automatically adopt this profile.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        activeColor: const Color(0xFF2563EB),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setState(() => _isDefault = v ?? false),
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),

                      const Text('Default Settings & Safety Limits', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(child: Text('Default Power State', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                  Switch(
                                    value: _defaultPower,
                                    activeThumbColor: const Color(0xFF2563EB),
                                    onChanged: (v) => setState(() => _defaultPower = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Default Brightness', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text('${_defaultBrightness.round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                                    ],
                                  ),
                                  Slider(
                                    value: _defaultBrightness,
                                    min: 0,
                                    max: 100,
                                    divisions: 20,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (v) => setState(() => _defaultBrightness = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      LayoutBuilder(
                        builder: (ctx, sc) {
                          final tempBox = Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Target Climate Temp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFF64748B)),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: _defaultTemperature > 16.0 ? () => setState(() => _defaultTemperature -= 0.5) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${_defaultTemperature.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF64748B)),
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(),
                                      splashRadius: 16,
                                      onPressed: _defaultTemperature < 30.0 ? () => setState(() => _defaultTemperature += 0.5) : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );

                          final wattageBox = Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Max Wattage Threshold', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('$_maxWattageLimit W', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                              ],
                            ),
                          );

                          return sc.maxWidth < 450
                              ? Column(children: [tempBox, const SizedBox(height: 10), wattageBox])
                              : Row(children: [Expanded(child: tempBox), const SizedBox(width: 12), Expanded(child: wattageBox)]);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                color: Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_isSaving ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create Profile')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSaving ? null : _onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

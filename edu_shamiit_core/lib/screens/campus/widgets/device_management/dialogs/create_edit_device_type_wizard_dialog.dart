import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class CreateEditDeviceTypeWizardDialog extends StatefulWidget {
  final DeviceTypeDetailItem? initialType;
  final Function(Map<String, dynamic> data) onSave;

  const CreateEditDeviceTypeWizardDialog({
    super.key,
    this.initialType,
    required this.onSave,
  });

  @override
  State<CreateEditDeviceTypeWizardDialog> createState() => _CreateEditDeviceTypeWizardDialogState();
}

class _CreateEditDeviceTypeWizardDialogState extends State<CreateEditDeviceTypeWizardDialog> {
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _mfgController;
  late TextEditingController _modelsController;
  late TextEditingController _tagsController;
  late TextEditingController _docUrlController;

  String _selectedCategory = 'Security';
  String _selectedSystemCategory = 'Security & Surveillance';
  String _selectedIcon = 'videocam';
  String _selectedColor = '#2563EB';
  String _selectedProtocol = 'MQTT';

  final Set<String> _selectedProtocols = {'MQTT'};
  final Set<String> _selectedCapabilities = {'Live View', 'PTZ Control', 'Recording'};
  bool _isActive = true;
  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'name': 'Security', 'system': 'Security & Surveillance', 'color': '#DC2626'},
    {'name': 'AV & Display', 'system': 'Audio Visual & Multimedia', 'color': '#9333EA'},
    {'name': 'Network', 'system': 'IT & Infrastructure', 'color': '#2563EB'},
    {'name': 'Power & Energy', 'system': 'Electrical Infrastructure', 'color': '#D97706'},
    {'name': 'Building Automation', 'system': 'Building Automation', 'color': '#0284C7'},
    {'name': 'Environment', 'system': 'HVAC & Environmental', 'color': '#059669'},
    {'name': 'Safety & Fire', 'system': 'Safety & Emergency', 'color': '#E11D48'},
    {'name': 'Access Control', 'system': 'Access & Perimeter', 'color': '#4F46E5'},
  ];

  final List<String> _availableProtocols = [
    'MQTT',
    'ONVIF',
    'RTSP',
    'HTTP(S)',
    'BACnet/IP',
    'Modbus TCP',
    'Zigbee 3.0',
    'BLE',
    'CoAP',
  ];

  final List<Map<String, dynamic>> _catalogCapabilities = [
    {'name': 'Power Control', 'code': 'power_state', 'icon': Icons.power_settings_new_rounded},
    {'name': 'Live View', 'code': 'live_view', 'icon': Icons.videocam_rounded},
    {'name': 'PTZ Control', 'code': 'ptz_control', 'icon': Icons.control_camera_rounded},
    {'name': 'Recording', 'code': 'recording', 'icon': Icons.fiber_manual_record_rounded},
    {'name': 'Snapshot', 'code': 'snapshot', 'icon': Icons.camera_alt_rounded},
    {'name': 'Motion Alert', 'code': 'motion_alert', 'icon': Icons.motion_photos_on_rounded},
    {'name': 'Stream Share', 'code': 'stream_share', 'icon': Icons.share_rounded},
    {'name': 'Brightness / Dimming', 'code': 'brightness', 'icon': Icons.lightbulb_outline_rounded},
    {'name': 'Thermostat Temp', 'code': 'target_temperature', 'icon': Icons.thermostat_rounded},
    {'name': 'HVAC Mode', 'code': 'hvac_mode', 'icon': Icons.air_rounded},
    {'name': 'Fan Speed', 'code': 'fan_speed', 'icon': Icons.wind_power_rounded},
    {'name': 'Input Source', 'code': 'input_source', 'icon': Icons.input_rounded},
    {'name': 'Audio Volume', 'code': 'volume', 'icon': Icons.volume_up_rounded},
    {'name': 'Door Lock', 'code': 'lock_state', 'icon': Icons.lock_outline_rounded},
    {'name': 'Gate Barrier', 'code': 'barrier_command', 'icon': Icons.fence_rounded},
    {'name': 'Energy Telemetry', 'code': 'energy_kwh', 'icon': Icons.electric_meter_rounded},
    {'name': 'Air Quality AQI', 'code': 'air_quality', 'icon': Icons.co2_rounded},
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialType;
    _nameController = TextEditingController(text: init?.name ?? '');
    _codeController = TextEditingController(text: init?.code ?? '');
    _descController = TextEditingController(text: init?.description ?? '');
    _mfgController = TextEditingController(text: init?.manufacturer ?? '');
    _modelsController = TextEditingController(text: init?.supportedModels.join(', ') ?? '');
    _tagsController = TextEditingController(text: init?.tags.join(', ') ?? '');
    _docUrlController = TextEditingController(text: init?.docUrl ?? '');

    if (init != null) {
      _selectedCategory = init.categoryName;
      _selectedSystemCategory = init.systemCategory;
      _selectedIcon = init.icon;
      _selectedColor = init.color;
      _selectedProtocol = init.protocol;
      _selectedProtocols.clear();
      _selectedProtocols.addAll(init.supportedProtocols);
      _selectedCapabilities.clear();
      _selectedCapabilities.addAll(init.defaultCapabilities);
      _isActive = init.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _mfgController.dispose();
    _modelsController.dispose();
    _tagsController.dispose();
    _docUrlController.dispose();
    super.dispose();
  }

  void _onSave() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();

    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a Device Type Name in Basic Specifications.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      setState(() => _currentStep = 0);
      return;
    }

    if (_formKeyStep1.currentState != null && !_formKeyStep1.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final modelsList = _modelsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final tagsList = _tagsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final formattedCode = code.isEmpty
          ? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')
          : code.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

      final payload = <String, dynamic>{
        'name': name,
        'code': formattedCode,
        'system_category': _selectedSystemCategory,
        'description': _descController.text.trim(),
        'icon': _selectedIcon,
        'color': _selectedColor,
        'protocol': _selectedProtocol,
        'supported_protocols': _selectedProtocols.toList(),
        'manufacturer': _mfgController.text.trim().isEmpty ? null : _mfgController.text.trim(),
        'supported_models': modelsList,
        'tags': tagsList,
        'doc_url': _docUrlController.text.trim().isEmpty ? null : _docUrlController.text.trim(),
        'default_capabilities': _selectedCapabilities.toList(),
        'is_active': _isActive,
      };

      final res = await widget.onSave(payload);
      if (mounted) {
        if (res == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save device type. Please check if code already exists or review details.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isSubmitting = false);
        } else {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.initialType != null
                  ? 'Device type updated successfully!'
                  : 'Device type "$name" created successfully!'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving device type: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialType != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.devices_other_rounded, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Device Type: ${_nameController.text}' : 'Add New Device Type',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Configure category hierarchy, hardware protocols, and operational capability schemas.',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Stepper Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStepPill(0, '1. Basic Specifications', isDark, primaryColor),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    _buildStepPill(1, '2. Capability Builder', isDark, primaryColor),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    _buildStepPill(2, '3. Review & Summary', isDark, primaryColor),
                  ],
                ),
              ),
            ),

            // Body content per step (IndexedStack keeps steps alive and valid)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStepContent(theme, isDark, primaryColor),
              ),
            ),

            // Footer action buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                      onPressed: () => setState(() => _currentStep--),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep < 2)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Continue'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_currentStep == 0) {
                          if (_formKeyStep1.currentState?.validate() ?? true) {
                            if (_codeController.text.trim().isEmpty) {
                              _codeController.text = _nameController.text
                                  .trim()
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]'), '_');
                            }
                            setState(() => _currentStep = 1);
                          }
                        } else {
                          setState(() => _currentStep = 2);
                        }
                      },
                    )
                  else
                    ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: Text(_isSubmitting ? 'Saving...' : (isEdit ? 'Save Changes' : 'Create Device Type')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _onSave,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPill(int index, String label, bool isDark, Color primaryColor) {
    final isActive = _currentStep == index;
    final isPassed = _currentStep > index;

    return InkWell(
      onTap: () {
        if (index < _currentStep || (index == 1 && (_formKeyStep1.currentState?.validate() ?? true))) {
          setState(() => _currentStep = index);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor
              : (isPassed ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (isPassed) ...[
              Icon(Icons.check_rounded, size: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive || isPassed ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? Colors.white : (isPassed ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent(ThemeData theme, bool isDark, Color primaryColor) {
    switch (_currentStep) {
      case 0:
        return _buildStep1Basic(isDark, primaryColor);
      case 1:
        return _buildStep2Capabilities(isDark, primaryColor);
      case 2:
      default:
        return _buildStep3Review(isDark, primaryColor);
    }
  }

  Widget _buildStep1Basic(bool isDark, Color primaryColor) {
    final labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155));
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
    );
    final inputDeco = InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primaryColor, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey.shade400, fontSize: 13),
    );

    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Type Name *', style: labelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: inputDeco.copyWith(hintText: 'e.g. CCTV, Projector, Interactive Display'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a device type name' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unique Identifier Code *', style: labelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _codeController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: inputDeco.copyWith(hintText: 'e.g. cctv_camera, projector_device'),
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
                    Text('Category Badge *', style: labelStyle),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _selectedCategory,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: inputDeco,
                      items: _categories.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['name'],
                          child: Text(c['name']!, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                            final match = _categories.firstWhere((c) => c['name'] == val);
                            _selectedSystemCategory = match['system']!;
                            _selectedColor = match['color']!;
                          });
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
                    Text('System Category', style: labelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: _selectedSystemCategory,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: inputDeco,
                      onChanged: (v) => _selectedSystemCategory = v.trim(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Description', style: labelStyle),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descController,
            maxLines: 2,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
            decoration: inputDeco.copyWith(hintText: 'e.g. IP/Network surveillance cameras with PTZ and recording capabilities'),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manufacturer / OEM', style: labelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _mfgController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: inputDeco.copyWith(hintText: 'e.g. Hikvision, Dahua, Sony, Philips'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Supported Models (comma separated)', style: labelStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _modelsController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: inputDeco.copyWith(hintText: 'e.g. DS-2CD2143G2, DS-2CD2043G2'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Supported Communication Protocols', style: labelStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableProtocols.map((p) {
              final isSel = _selectedProtocols.contains(p);
              return FilterChip(
                label: Text(p),
                selected: isSel,
                selectedColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.12),
                checkmarkColor: primaryColor,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                  color: isSel ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: isSel ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedProtocols.add(p);
                    } else if (_selectedProtocols.length > 1) {
                      _selectedProtocols.remove(p);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Capabilities(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Hardware Capabilities for this Device Type',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        Text(
          'Enabling a capability exposes corresponding real-time controls, telemetry, and MQTT command endpoints to all devices mapped to this type.',
          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (ctx, c) {
            final isCompact = c.maxWidth < 620;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isCompact ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 10,
                childAspectRatio: isCompact ? 5.2 : 3.8,
              ),
              itemCount: _catalogCapabilities.length,
              itemBuilder: (context, idx) {
                final cap = _catalogCapabilities[idx];
                final name = cap['name'] as String;
                final isEnabled = _selectedCapabilities.contains(name);

                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isEnabled) {
                        _selectedCapabilities.remove(name);
                      } else {
                        _selectedCapabilities.add(name);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isEnabled ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.08) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                      border: Border.all(
                        color: isEnabled ? primaryColor : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isEnabled ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isEnabled ? primaryColor.withValues(alpha: 0.2) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(cap['icon'] as IconData, size: 18, color: isEnabled ? primaryColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isEnabled ? FontWeight.w700 : FontWeight.w600,
                                  color: isEnabled ? (isDark ? Colors.white : const Color(0xFF1E3A8A)) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                cap['code'] as String,
                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : Colors.grey.shade500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: isEnabled,
                          activeColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedCapabilities.add(name);
                              } else {
                                _selectedCapabilities.remove(name);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep3Review(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Device Type Configuration',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.devices_rounded, color: primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _nameController.text.trim().isEmpty ? 'Untitled Device Type' : _nameController.text.trim(),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedCategory,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _descController.text.trim().isEmpty ? 'No description provided' : _descController.text.trim(),
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildSummaryItem('Unique Code', _codeController.text.toLowerCase(), isDark),
                  _buildSummaryItem('System Category', _selectedSystemCategory, isDark),
                  _buildSummaryItem('Protocols', _selectedProtocols.join(', '), isDark),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildSummaryItem('Manufacturer', _mfgController.text.isEmpty ? 'Universal OEM' : _mfgController.text, isDark),
                  _buildSummaryItem('Capabilities Count', '${_selectedCapabilities.length} capabilities', isDark),
                  _buildSummaryItem('Status', _isActive ? 'Active' : 'Inactive', isDark),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('Configured Capabilities:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _selectedCapabilities.map((cap) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cap,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF052E16).withValues(alpha: 0.4) : const Color(0xFFF0FDF4),
            border: Border.all(color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A default profile ("Default Profile") will be automatically created and bound to this device type.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

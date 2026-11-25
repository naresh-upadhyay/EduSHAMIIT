import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/device_management_models.dart';

class DeviceDetailsDrawer extends StatefulWidget {
  final DeviceItemModel device;
  final VoidCallback onClose;
  final VoidCallback onTogglePower;
  final Function(int temp)? onSetTemperature;
  final Function(String mode)? onSetHvacMode;
  final Function(String speed)? onSetFanSpeed;
  final Function(int brightness)? onSetBrightness;
  final Function(String input)? onSetProjectorInput;
  final Function(int volume)? onSetProjectorVolume;
  final Function(String action)? onGateControl;
  final VoidCallback? onReboot;
  final Future<Map<String, dynamic>> Function()? onPing;
  final Function(Map<String, dynamic> updatedData)? onUpdateDevice;
  final VoidCallback? onDelete;

  const DeviceDetailsDrawer({
    super.key,
    required this.device,
    required this.onClose,
    required this.onTogglePower,
    this.onSetTemperature,
    this.onSetHvacMode,
    this.onSetFanSpeed,
    this.onSetBrightness,
    this.onSetProjectorInput,
    this.onSetProjectorVolume,
    this.onGateControl,
    this.onReboot,
    this.onPing,
    this.onUpdateDevice,
    this.onDelete,
  });

  @override
  State<DeviceDetailsDrawer> createState() => _DeviceDetailsDrawerState();
}

class _DeviceDetailsDrawerState extends State<DeviceDetailsDrawer> {
  bool _isEditing = false;
  bool _isPingLoading = false;
  String? _pingResult;

  // Local state for smooth interactive controls
  late bool _power;
  late int _temperature;
  late String _hvacMode;
  late String _fanSpeed;
  late int _brightness;
  late String _projectorInput;
  late int _projectorVolume;
  late String _gateState;

  // Edit Controllers
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _macController;
  late TextEditingController _powerController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _syncStateFromDevice();
  }

  @override
  void didUpdateWidget(covariant DeviceDetailsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device != widget.device) {
      _syncStateFromDevice();
    }
  }

  void _syncStateFromDevice() {
    final cur = widget.device.currentState;
    _power = widget.device.powerState;
    _temperature = (cur['temperature'] as num?)?.toInt() ?? 24;
    _hvacMode = cur['mode']?.toString() ?? 'Cool';
    _fanSpeed = cur['speed']?.toString() ?? cur['fan_speed']?.toString() ?? 'Medium';
    _brightness = (cur['brightness'] as num?)?.toInt() ?? 80;
    _projectorInput = cur['input']?.toString() ?? 'HDMI 1';
    _projectorVolume = (cur['volume'] as num?)?.toInt() ?? 70;
    _gateState = cur['position']?.toString() ?? (cur['locked'] == true ? 'Locked' : 'Unlocked');

    _nameController = TextEditingController(text: widget.device.deviceName);
    _ipController = TextEditingController(text: widget.device.ipAddress ?? '192.168.10.101');
    _macController = TextEditingController(text: widget.device.macAddress ?? '00:1B:44:11:3A:B7');
    _powerController = TextEditingController(text: widget.device.ratedPowerWatts.toInt().toString());
    _notesController = TextEditingController(text: widget.device.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _macController.dispose();
    _powerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handlePing() async {
    if (widget.onPing == null) return;
    setState(() {
      _isPingLoading = true;
      _pingResult = null;
    });
    try {
      final res = await widget.onPing!();
      final ms = res['latency_ms'] ?? 4.2;
      setState(() {
        _isPingLoading = false;
        _pingResult = 'Ping OK (${ms}ms) • Link Active';
      });
    } catch (_) {
      setState(() {
        _isPingLoading = false;
        _pingResult = 'Ping timeout (packet lost)';
      });
    }
  }

  void _saveEdits() {
    if (widget.onUpdateDevice != null) {
      widget.onUpdateDevice!({
        'device_name': _nameController.text.trim(),
        'ip_address': _ipController.text.trim(),
        'mac_address': _macController.text.trim(),
        'rated_power_watts': double.tryParse(_powerController.text) ?? widget.device.ratedPowerWatts,
        'notes': _notesController.text.trim(),
      });
    }
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device specifications updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 500 ? screenWidth * 0.95 : 420.0;

    return Container(
      width: drawerWidth,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(left: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          _buildHeader(isDark),

          // Drawer Body Scrollview
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Network Status & Quick Diagnostics Banner
                  _buildNetworkStatusBanner(isDark),
                  const SizedBox(height: 16),

                  // 2. Interactive Device Controls (Tailored per Device Type)
                  _buildTypeSpecificControls(isDark),
                  const SizedBox(height: 16),

                  // 3. Device Specifications & Full CRUD Update Form
                  _buildSpecificationsSection(isDark),
                  const SizedBox(height: 16),

                  // 4. MQTT Topic & Telemetry Information
                  _buildMqttSection(isDark),
                  const SizedBox(height: 16),

                  // 5. Live State JSON Schema
                  _buildJsonSchemaSection(isDark),
                  const SizedBox(height: 16),

                  // 6. Danger Zone (Reboot Hardware & Delete Device)
                  _buildDangerZoneSection(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
            child: const Icon(Icons.memory_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.device.deviceName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.device.deviceCode} • ${widget.device.typeName}',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit Toggle Action
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility_outlined : Icons.edit_outlined, size: 19),
            tooltip: _isEditing ? 'Cancel Editing' : 'Edit Specifications',
            color: _isEditing ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : const Color(0xFF475569)),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
          // Delete Action
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Color(0xFFDC2626)),
              tooltip: 'Delete Device',
              onPressed: widget.onDelete,
            ),
          // Close Action
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: widget.onClose,
            tooltip: 'Close Drawer',
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStatusBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.device.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.device.isOnline ? 'Online • MQTT Connected' : 'Offline • Unreachable',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.device.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _power = !_power);
                  widget.onTogglePower();
                },
                icon: Icon(Icons.power_settings_new_rounded, size: 14, color: _power ? Colors.white : Colors.red),
                label: Text(_power ? 'Turn OFF' : 'Turn ON'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _power ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(80, 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isPingLoading ? null : _handlePing,
                icon: _isPingLoading
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_ping_rounded, size: 14),
                label: const Text('Ping Device', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(60, 26),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onReboot != null)
                OutlinedButton.icon(
                  onPressed: widget.onReboot,
                  icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFF2563EB)),
                  label: const Text('Reboot', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(60, 26),
                  ),
                ),
            ],
          ),
          if (_pingResult != null) ...[
            const SizedBox(height: 6),
            Text(
              _pingResult!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _pingResult!.contains('OK') ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Dynamic Type-Specific Interactive Control Options ---
  Widget _buildTypeSpecificControls(bool isDark) {
    final lowerCode = widget.device.typeCode.toLowerCase();
    final lowerName = widget.device.typeName.toLowerCase();

    Widget controlBody;
    String sectionHeader;

    if (lowerCode.contains('ac') || lowerName.contains('ac') || lowerName.contains('hvac')) {
      sectionHeader = 'HVAC & Climate Controls';
      controlBody = _buildAcControls(isDark);
    } else if (lowerCode.contains('light') || lowerName.contains('light')) {
      sectionHeader = 'Lighting & Illumination Controls';
      controlBody = _buildLightingControls(isDark);
    } else if (lowerCode.contains('fan') || lowerName.contains('fan')) {
      sectionHeader = 'Air Circulation & Fan Controls';
      controlBody = _buildFanControls(isDark);
    } else if (lowerCode.contains('projector') || lowerName.contains('projector') || lowerName.contains('display')) {
      sectionHeader = 'Audio / Visual Presentation Controls';
      controlBody = _buildProjectorControls(isDark);
    } else if (lowerCode.contains('gate') || lowerCode.contains('access') || lowerName.contains('gate')) {
      sectionHeader = 'Access Control & Gate Automation';
      controlBody = _buildGateControls(isDark);
    } else {
      sectionHeader = 'Power & Relay Controls';
      controlBody = _buildGenericControls(isDark);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Text(
                sectionHeader,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          controlBody,
        ],
      ),
    );
  }

  // 1. AC / HVAC Controls
  Widget _buildAcControls(bool isDark) {
    final modes = ['Cool', 'Heat', 'Fan', 'Auto', 'Dry'];
    final speeds = ['Low', 'Medium', 'High', 'Auto'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Digital Stepper & Circular Indicator
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF2563EB), size: 24),
                  onPressed: () {
                    if (_temperature > 16) {
                      setState(() => _temperature--);
                      widget.onSetTemperature?.call(_temperature);
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_temperature°C',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2563EB), size: 24),
                  onPressed: () {
                    if (_temperature < 32) {
                      setState(() => _temperature++);
                      widget.onSetTemperature?.call(_temperature);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Temperature Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF2563EB),
            thumbColor: const Color(0xFF2563EB),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 4,
          ),
          child: Slider(
            value: _temperature.toDouble().clamp(16.0, 32.0),
            min: 16,
            max: 32,
            divisions: 16,
            label: '$_temperature°C',
            onChanged: (val) {
              setState(() => _temperature = val.toInt());
              widget.onSetTemperature?.call(_temperature);
            },
          ),
        ),
        const SizedBox(height: 10),

        // Mode Selector Pills
        const Text('Operating Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: modes.map((m) {
              final isSel = _hvacMode.toLowerCase() == m.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(m, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _hvacMode = m);
                      widget.onSetHvacMode?.call(m);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Fan Speed Selector
        const Text('Fan Speed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: speeds.map((s) {
              final isSel = _fanSpeed.toLowerCase() == s.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(s, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                  selected: isSel,
                  selectedColor: const Color(0xFF0284C7),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _fanSpeed = s);
                      widget.onSetFanSpeed?.call(s);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 2. Lighting Controls
  Widget _buildLightingControls(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Brightness Level', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_brightness%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFCA8A04)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFEAB308),
            thumbColor: const Color(0xFFCA8A04),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 4,
          ),
          child: Slider(
            value: _brightness.toDouble().clamp(0.0, 100.0),
            min: 0,
            max: 100,
            onChanged: (val) {
              setState(() => _brightness = val.toInt());
              widget.onSetBrightness?.call(_brightness);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [25, 50, 75, 100].map((preset) {
            return ActionChip(
              label: Text('$preset%', style: const TextStyle(fontSize: 11)),
              onPressed: () {
                setState(() => _brightness = preset);
                widget.onSetBrightness?.call(preset);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // 3. Fan Controls
  Widget _buildFanControls(bool isDark) {
    final speeds = ['Off', 'Low', 'Medium', 'High'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Airflow Speed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        Row(
          children: speeds.map((s) {
            final isSel = _fanSpeed.toLowerCase() == s.toLowerCase();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _fanSpeed = s);
                    widget.onSetFanSpeed?.call(s);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSel ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    foregroundColor: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 4. Projector Controls
  Widget _buildProjectorControls(bool isDark) {
    final inputs = ['HDMI 1', 'HDMI 2', 'Type-C', 'Wireless', 'VGA'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Input Source Selection', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: AppSearchableDropdown<String>.fromMenuItems(
              value: inputs.contains(_projectorInput) ? _projectorInput : 'HDMI 1',
              isExpanded: true,
              items: inputs.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _projectorInput = val);
                  widget.onSetProjectorInput?.call(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Audio Output Volume', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            Text('$_projectorVolume%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF2563EB),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            trackHeight: 3,
          ),
          child: Slider(
            value: _projectorVolume.toDouble().clamp(0.0, 100.0),
            min: 0,
            max: 100,
            onChanged: (val) {
              setState(() => _projectorVolume = val.toInt());
              widget.onSetProjectorVolume?.call(_projectorVolume);
            },
          ),
        ),
      ],
    );
  }

  // 5. Gate Controls
  Widget _buildGateControls(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Current State: $_gateState', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => widget.onGateControl?.call('Open'),
              icon: const Icon(Icons.sensor_door_outlined, size: 14),
              label: const Text('Open Gate'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onGateControl?.call('Close'),
              icon: const Icon(Icons.door_front_door_outlined, size: 14),
              label: const Text('Close Gate'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: () => widget.onGateControl?.call('Lock'),
              icon: const Icon(Icons.lock_outline, size: 14),
              label: const Text('Lock Secure'),
            ),
            OutlinedButton.icon(
              onPressed: () => widget.onGateControl?.call('Unlock'),
              icon: const Icon(Icons.lock_open, size: 14),
              label: const Text('Unlock Pass'),
            ),
          ],
        ),
      ],
    );
  }

  // 6. Generic Controls
  Widget _buildGenericControls(bool isDark) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: widget.onTogglePower,
        icon: Icon(_power ? Icons.power_settings_new : Icons.power_off, size: 18),
        label: Text(_power ? 'Disconnect Power Relay' : 'Engage Power Relay'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _power ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  // --- Specifications Section (View Mode vs Full CRUD Edit Mode) ---
  Widget _buildSpecificationsSection(bool isDark) {
    if (_isEditing) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2563EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Edit Device Specifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            _buildEditField('Device Name', _nameController, isDark),
            const SizedBox(height: 8),
            _buildEditField('IP Address', _ipController, isDark),
            const SizedBox(height: 8),
            _buildEditField('MAC Address', _macController, isDark),
            const SizedBox(height: 8),
            _buildEditField('Rated Power (Watts)', _powerController, isDark, isNumber: true),
            const SizedBox(height: 8),
            _buildEditField('Notes / Location Details', _notesController, isDark, maxLines: 2),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _isEditing = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saveEdits,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Device Specifications',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => setState(() => _isEditing = true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Edit', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          _buildInfoRow('Identifier / Code', widget.device.deviceCode, isDark),
          _buildInfoRow('Category / Type', widget.device.typeName, isDark),
          _buildInfoRow('Location', widget.device.locationDisplay, isDark),
          _buildInfoRow('IP Address', widget.device.ipAddress ?? '192.168.10.101', isDark),
          _buildInfoRow('MAC Address', widget.device.macAddress ?? '00:1B:44:11:3A:B7', isDark),
          _buildInfoRow('Rated Power', '${widget.device.ratedPowerWatts.toInt()} Watts', isDark),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, bool isDark, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
          ),
        ),
      ],
    );
  }

  Widget _buildMqttSection(bool isDark) {
    final topic = 'campus/11111111-1111-1111-1111-111111111111/${widget.device.deviceCode}/cmd';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MQTT Command Topic',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: topic));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MQTT topic copied!')));
              },
              child: const Text('Copy', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            topic,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF2563EB)),
          ),
        ),
      ],
    );
  }

  Widget _buildJsonSchemaSection(bool isDark) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(widget.device.currentState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live JSON State Schema',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('State JSON copied!')));
              },
              child: const Text('Copy JSON', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            jsonStr,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZoneSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2).withValues(alpha: isDark ? 0.08 : 1.0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Hardware Administration', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.onReboot != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onReboot,
                    icon: const Icon(Icons.restart_alt_rounded, size: 14),
                    label: const Text('Reboot Hardware', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              if (widget.onReboot != null && widget.onDelete != null)
                const SizedBox(width: 8),
              if (widget.onDelete != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_forever_rounded, size: 14),
                    label: const Text('Delete Device', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

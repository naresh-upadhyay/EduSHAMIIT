import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class AdvancedGroupControlDialog extends StatefulWidget {
  final DeviceGroupItem group;
  final Function(String commandType, Map<String, dynamic>? params) onExecuteCommand;

  const AdvancedGroupControlDialog({
    super.key,
    required this.group,
    required this.onExecuteCommand,
  });

  @override
  State<AdvancedGroupControlDialog> createState() => _AdvancedGroupControlDialogState();
}

class _AdvancedGroupControlDialogState extends State<AdvancedGroupControlDialog> with SingleTickerProviderStateMixin {
  late bool _masterPower;
  double _brightness = 80;
  double _temperature = 24;
  String _hvacMode = 'Cool';
  String _fanSpeed = 'Medium';
  String _doorLockState = 'Locked';
  double _audioVolume = 70;
  bool _isExecuting = false;
  String? _statusMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _masterPower = true;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _execute(String cmd, [Map<String, dynamic>? params]) async {
    setState(() {
      _isExecuting = true;
      _statusMessage = null;
    });

    try {
      await widget.onExecuteCommand(cmd, params);
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _statusMessage = 'Command "$cmd" published to Mosquitto broker for ${widget.group.deviceCount} devices!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExecuting = false;
          _statusMessage = 'Execution failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advanced Group Control: ${widget.group.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.group.deviceCount} Total Devices • ${widget.group.onlineCount} Online • ${widget.group.groupType}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab bar for Universal Controls vs Device Type Subsets
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              tabs: const [
                Tab(text: 'Universal Controls'),
                Tab(text: 'Device Type Subsets'),
              ],
            ),

            // Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUniversalControls(borderColor),
                  _buildSubsetControls(borderColor),
                ],
              ),
            ),

            // Footer Status & Close
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  if (_isExecuting)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  if (_statusMessage != null)
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Expanded(
                      child: Text(
                        'Changes dispatch in real-time across institutional MQTT channels.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniversalControls(Color borderColor) {
    final gType = widget.group.groupType.toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master Power Switch Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
              color: _masterPower
                  ? const Color(0xFF16A34A).withValues(alpha: 0.05)
                  : const Color(0xFFEF4444).withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: _masterPower ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                  size: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Master Group Power',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _masterPower
                            ? 'All eligible group devices are commanded ON'
                            : 'All eligible group devices are commanded OFF',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _masterPower,
                  activeThumbColor: const Color(0xFF16A34A),
                  onChanged: (val) {
                    setState(() => _masterPower = val);
                    _execute(val ? 'turn_on' : 'turn_off');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Brightness Control (Lighting / Composite)
          if (gType.contains('light') || gType.contains('composite')) ...[
            _buildControlCard(
              title: 'Group Brightness',
              subtitle: 'Adjust illumination levels for all group lights (0 - 100%)',
              icon: Icons.wb_sunny_outlined,
              iconColor: const Color(0xFFEAB308),
              valueDisplay: '${_brightness.toInt()}%',
              borderColor: borderColor,
              child: Slider(
                value: _brightness,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: const Color(0xFFEAB308),
                onChanged: (v) => setState(() => _brightness = v),
                onChangeEnd: (v) => _execute('brightness', {'brightness': v.toInt()}),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // HVAC Temperature Control
          if (gType.contains('hvac') || gType.contains('ac') || gType.contains('composite')) ...[
            _buildControlCard(
              title: 'Climate Temperature Setpoint',
              subtitle: 'Safe intersection range (18°C – 28°C)',
              icon: Icons.ac_unit,
              iconColor: const Color(0xFF0284C7),
              valueDisplay: '${_temperature.toInt()}°C',
              borderColor: borderColor,
              child: Column(
                children: [
                  Slider(
                    value: _temperature,
                    min: 18,
                    max: 28,
                    divisions: 10,
                    activeColor: const Color(0xFF0284C7),
                    onChanged: (v) => setState(() => _temperature = v),
                    onChangeEnd: (v) => _execute('set_temperature', {'temperature': v.toInt()}),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['Cool', 'Heat', 'Auto', 'Dry'].map((mode) {
                      final isSel = _hvacMode == mode;
                      return ChoiceChip(
                        label: Text(mode, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                        selected: isSel,
                        selectedColor: const Color(0xFF0284C7),
                        onSelected: (sel) {
                          if (sel) {
                            setState(() => _hvacMode = mode);
                            _execute('set_hvac_mode', {'mode': mode});
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Fan Speed Control
          if (gType.contains('fan') || gType.contains('environment') || gType.contains('composite')) ...[
            _buildControlCard(
              title: 'Fan Speed Selection',
              subtitle: 'Discrete speed settings across all ventilation fixtures',
              icon: Icons.toys,
              iconColor: const Color(0xFF10B981),
              valueDisplay: _fanSpeed,
              borderColor: borderColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Low', 'Medium', 'High', 'Auto'].map((speed) {
                  final isSel = _fanSpeed == speed;
                  return ChoiceChip(
                    label: Text(speed, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                    selected: isSel,
                    selectedColor: const Color(0xFF10B981),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _fanSpeed = speed);
                        _execute('set_fan_speed', {'fan_speed': speed});
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Audio Volume Control
          if (gType.contains('audio') || gType.contains('av') || gType.contains('display')) ...[
            _buildControlCard(
              title: 'Audio Master Gain',
              subtitle: 'Central PA & auditorium speaker levels',
              icon: Icons.volume_up,
              iconColor: const Color(0xFF8B5CF6),
              valueDisplay: '${_audioVolume.toInt()}%',
              borderColor: borderColor,
              child: Slider(
                value: _audioVolume,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: const Color(0xFF8B5CF6),
                onChanged: (v) => setState(() => _audioVolume = v),
                onChangeEnd: (v) => _execute('set_volume', {'volume': v.toInt()}),
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Access Control Lock
          if (gType.contains('door') || gType.contains('access') || gType.contains('security')) ...[
            _buildControlCard(
              title: 'Access Control Security State',
              subtitle: 'Campus security gate and door lock status',
              icon: Icons.lock_outline,
              iconColor: const Color(0xFF2563EB),
              valueDisplay: _doorLockState,
              borderColor: borderColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Locked', 'Unlocked', 'Emergency Open'].map((st) {
                  final isSel = _doorLockState == st;
                  final col = st == 'Locked' ? const Color(0xFF2563EB) : st == 'Unlocked' ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
                  return ChoiceChip(
                    label: Text(st, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
                    selected: isSel,
                    selectedColor: col,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() => _doorLockState = st);
                        _execute('set_lock_state', {'state': st});
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubsetControls(Color borderColor) {
    final adv = widget.group.advancedControls;

    if (adv.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.devices_other, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'No heterogeneous subsets detected.',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'All devices in "${widget.group.name}" share homogeneous capabilities.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: adv.length,
      itemBuilder: (ctx, idx) {
        final subset = adv[idx];
        final cat = subset['category'] ?? 'Device Subset';
        final count = subset['count'] ?? 0;
        final online = subset['online'] ?? count;
        final caps = (subset['capabilities'] as List?)?.join(', ') ?? 'power';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.device_hub, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$cat ($count Devices)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Text('$online Online • Capabilities: $caps', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.power_settings_new, size: 14),
                    label: const Text('Toggle Subset', style: TextStyle(fontSize: 11)),
                    onPressed: () => _execute('toggle_subset', {'category': cat}),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String valueDisplay,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  valueDisplay,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

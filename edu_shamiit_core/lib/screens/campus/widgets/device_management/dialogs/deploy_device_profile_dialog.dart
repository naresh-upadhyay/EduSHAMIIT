import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class DeployDeviceProfileDialog extends StatefulWidget {
  final DeviceProfileItem profile;
  final DeviceTypeDetailItem? deviceType;
  final Function(Map<String, dynamic> data) onDeploy;

  const DeployDeviceProfileDialog({
    super.key,
    required this.profile,
    this.deviceType,
    required this.onDeploy,
  });

  @override
  State<DeployDeviceProfileDialog> createState() => _DeployDeviceProfileDialogState();
}

class _DeployDeviceProfileDialogState extends State<DeployDeviceProfileDialog> {
  String _targetType = 'all';
  final _notesController = TextEditingController();
  bool _isDeploying = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _onConfirmDeploy() async {
    setState(() => _isDeploying = true);
    final payload = {
      'target_type': _targetType,
      'notes': _notesController.text.trim().isEmpty
          ? 'Manual deployment from Device Types & Profiles manager'
          : _notesController.text.trim(),
    };
    await widget.onDeploy(payload);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeName = widget.deviceType?.name ?? widget.profile.deviceTypeName ?? 'Selected Device Type';
    final mappedCount = widget.deviceType?.mappedDevicesCount ?? widget.profile.usageCount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Deploy Control Profile',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Push profile configuration to campus devices in real time.',
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

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.profile.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Target: $typeName • Version: ${widget.profile.version} • Status: ${widget.profile.status}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text('Deployment Scope', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 8),

                    RadioListTile<String>(
                      value: 'all',
                      groupValue: _targetType,
                      activeColor: const Color(0xFF2563EB),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'All Active Devices ($mappedCount devices)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Immediately reconfigures all online devices mapped to this hardware type.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      onChanged: (v) => setState(() => _targetType = v!),
                    ),

                    RadioListTile<String>(
                      value: 'new_only',
                      groupValue: _targetType,
                      activeColor: const Color(0xFF2563EB),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'New & Unassigned Devices Only',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Applies only to newly provisioned devices that have not yet had a custom profile applied.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      onChanged: (v) => setState(() => _targetType = v!),
                    ),

                    const SizedBox(height: 14),
                    const Text('Audit Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Upgrading camera PTZ control parameters for Term 1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sync_rounded, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Configuration updates will be broadcast to the Mosquitto MQTT broker and applied to connected IoT gateways automatically.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    icon: _isDeploying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 16),
                    label: Text(_isDeploying ? 'Deploying...' : 'Confirm & Deploy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isDeploying ? null : _onConfirmDeploy,
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

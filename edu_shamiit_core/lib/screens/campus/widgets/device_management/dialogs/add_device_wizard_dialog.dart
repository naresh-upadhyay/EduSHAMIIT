import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../../../services/device_management_api_service.dart';

class AddDeviceWizardDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const AddDeviceWizardDialog({super.key, required this.onSaved});

  @override
  State<AddDeviceWizardDialog> createState() => _AddDeviceWizardDialogState();
}

class _AddDeviceWizardDialogState extends State<AddDeviceWizardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _ipCtrl = TextEditingController(text: '192.168.10.');
  final _macCtrl = TextEditingController();
  final _powerCtrl = TextEditingController(text: '100');
  final _notesCtrl = TextEditingController();

  String _selectedType = 'lighting';
  String _selectedBuilding = 'B1';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _ipCtrl.dispose();
    _macCtrl.dispose();
    _powerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = {
      'device_name': _nameCtrl.text.trim(),
      'device_code': _codeCtrl.text.trim(),
      'device_type_code': _selectedType,
      'ip_address': _ipCtrl.text.trim(),
      'mac_address': _macCtrl.text.trim(),
      'rated_power_watts': double.tryParse(_powerCtrl.text.trim()) ?? 100.0,
      'notes': _notesCtrl.text.trim(),
    };

    final res = await DeviceManagementApiService.instance.createDevice(payload);
    setState(() => _isSaving = false);

    if (mounted) {
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to register device')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_to_photos_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Register New Campus Device',
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

              // Fields
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name & Code
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Device Name *', hintText: 'e.g. AC-B1-F1-104-01'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'Device Identifier / Code *', hintText: 'e.g. AC-104'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Device Type & Building
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _selectedType,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Device Type *'),
                              items: const [
                                DropdownMenuItem(value: 'ac', child: Text('AC (HVAC)')),
                                DropdownMenuItem(value: 'lighting', child: Text('Lighting')),
                                DropdownMenuItem(value: 'fan', child: Text('Ceiling Fan')),
                                DropdownMenuItem(value: 'projector', child: Text('Interactive Projector')),
                                DropdownMenuItem(value: 'gate_controller', child: Text('Gate Controller')),
                                DropdownMenuItem(value: 'power_switches', child: Text('Power Switch / Relay')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _selectedBuilding,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Building *'),
                              items: const [
                                DropdownMenuItem(value: 'B1', child: Text('B1 - Academic Block')),
                                DropdownMenuItem(value: 'B2', child: Text('B2 - Science Block')),
                                DropdownMenuItem(value: 'B3', child: Text('B3 - Admin Block')),
                                DropdownMenuItem(value: 'B4', child: Text('B4 - Library Block')),
                                DropdownMenuItem(value: 'B5', child: Text('B5 - Hostel Block')),
                                DropdownMenuItem(value: 'B6', child: Text('B6 - Sports Complex')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedBuilding = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // IP Address & MAC Address
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ipCtrl,
                              decoration: const InputDecoration(labelText: 'IP Address', hintText: '192.168.10.x'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _macCtrl,
                              decoration: const InputDecoration(labelText: 'MAC Address', hintText: '00:1B:44:11:3A:..'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Rated Power Watts
                      TextFormField(
                        controller: _powerCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Rated Power (Watts)', hintText: 'e.g. 1500 for AC, 80 for Light'),
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Installation Notes / Description'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Register Device'),
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

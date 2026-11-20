import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/campus_lookup_helper.dart';
import '../../../services/campus_api_service.dart';
import '../../../models/campus_models.dart';

class LogUtilityReadingDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const LogUtilityReadingDialog({super.key, required this.onSaved});

  @override
  State<LogUtilityReadingDialog> createState() => _LogUtilityReadingDialogState();
}

class _LogUtilityReadingDialogState extends State<LogUtilityReadingDialog> {
  final _formKey = GlobalKey<FormState>();

  String _utilityType = 'State Power Grid & Substation';
  String? _selectedBuildingId;
  final _readingCtrl = TextEditingController(text: '45210');
  final _unitCtrl = TextEditingController(text: 'kWh');
  final _fuelLitersCtrl = TextEditingController(text: '0');
  final _runtimeHoursCtrl = TextEditingController(text: '0');
  final _recordedByCtrl = TextEditingController(text: 'Suresh Sharma (Chief Electrical Specialist)');
  final _remarksCtrl = TextEditingController(text: 'Routine evening meter verification.');

  List<String> _utilityTypes = [];
  List<BuildingModel> _buildings = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final types = await CampusLookupHelper.instance.getLookupLabels(
      'UTILITY_TYPE',
      defaultLabels: [
        'State Power Grid & Substation',
        'Rooftop Solar PV Generation',
        'Backup Diesel Generator Sets (DG)',
        'Municipal Water & Deep Borewells',
        'Central RO Water Purification Plant',
        'Sewage Treatment Plant (STP)',
        'High-Speed Internet / Optical Fiber Leased Line',
        'Piped Natural Gas (PNG) / Lab LPG Bank',
      ],
    );

    final bldgs = await CampusLookupHelper.instance.getActiveBuildings();

    if (mounted) {
      setState(() {
        _utilityTypes = types;
        _buildings = bldgs;
        if (!_utilityTypes.contains(_utilityType) && _utilityTypes.isNotEmpty) {
          _utilityType = _utilityTypes.first;
        }
        if (_buildings.isNotEmpty) {
          _selectedBuildingId = _buildings.first.id;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _readingCtrl.dispose();
    _unitCtrl.dispose();
    _fuelLitersCtrl.dispose();
    _runtimeHoursCtrl.dispose();
    _recordedByCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    String uCat = 'Electrical & Solar';
    final lower = _utilityType.toLowerCase();
    if (lower.contains('water') || lower.contains('ro') || lower.contains('sump')) {
      uCat = 'Water & RO';
    } else if (lower.contains('internet') || lower.contains('fiber') || lower.contains('telecom')) {
      uCat = 'Internet & Telecom';
    } else if (lower.contains('gas') || lower.contains('hvac')) {
      uCat = 'Gas & HVAC';
    }

    final bldg = _buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => _buildings.isNotEmpty
          ? _buildings.first
          : const BuildingModel(id: '', schoolId: '', name: 'Main Campus Substation', code: 'MAIN'),
    );

    final payload = <String, dynamic>{
      'utility_name': _utilityType,
      'utility_type': uCat,
      'reading_value': '${_readingCtrl.text.trim()} ${_unitCtrl.text.trim()}',
      'metric_units': _unitCtrl.text.trim(),
      'location': '${bldg.name} (${bldg.code})',
      'recorded_by': _recordedByCtrl.text.trim(),
      'status': 'Normal',
      'notes': _remarksCtrl.text.trim(),
      'building_id': _selectedBuildingId,
    };

    final res = await CampusApiService.instance.logUtilityReading(payload);
    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed to log utility reading'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.min(580.0, screenWidth * 0.95);

    final isDg = _utilityType.contains('Diesel Generator') || _utilityType.contains('DG');

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _isLoading
              ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.bolt_rounded, size: 20, color: primaryColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Log Campus Utility Reading',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Record sub-meter, fuel intake, generator runtime or water capacity',
                                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              color: textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Utility Type Dropdown (from lookups)
                        DropdownButtonFormField<String>(
                          initialValue: _utilityType,
                          isExpanded: true,
                          decoration: _buildInputDeco('Utility Infrastructure System', borderColor, isDark),
                          dropdownColor: dialogBg,
                          items: _utilityTypes
                              .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u, style: TextStyle(fontSize: 12.5, color: textPrimary), overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _utilityType = v ?? _utilityType;
                              if (_utilityType.contains('Solar') || _utilityType.contains('Power Grid')) {
                                _unitCtrl.text = 'kWh';
                              } else if (_utilityType.contains('Water') || _utilityType.contains('RO')) {
                                _unitCtrl.text = 'Kilolitres (kL)';
                              } else if (_utilityType.contains('Internet')) {
                                _unitCtrl.text = 'GB';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Building Location (from buildings table)
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedBuildingId,
                          isExpanded: true,
                          decoration: _buildInputDeco('Campus Sub-Station / Building Location', borderColor, isDark),
                          dropdownColor: dialogBg,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Campus Main Substation / Central Sump')),
                            ..._buildings.map((b) => DropdownMenuItem(
                                  value: b.id,
                                  child: Text('${b.code} - ${b.name}', style: TextStyle(fontSize: 12.5, color: textPrimary), overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedBuildingId = v),
                        ),
                        const SizedBox(height: 12),

                        // Meter Reading & Unit
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _readingCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDeco('Current Meter Reading *', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _unitCtrl,
                                decoration: _buildInputDeco('Unit of Measure', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Generator Fuel & Runtime (if DG selected)
                        if (isDg) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _fuelLitersCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDeco('Diesel Added (Litres)', borderColor, isDark),
                                  style: TextStyle(fontSize: 13, color: textPrimary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _runtimeHoursCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDeco('Run Hours Today', borderColor, isDark),
                                  style: TextStyle(fontSize: 13, color: textPrimary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Recorded by
                        TextFormField(
                          controller: _recordedByCtrl,
                          decoration: _buildInputDeco('Recorded By (Officer / Technician)', borderColor, isDark),
                          style: TextStyle(fontSize: 13, color: textPrimary),
                        ),
                        const SizedBox(height: 12),

                        // Remarks
                        TextFormField(
                          controller: _remarksCtrl,
                          maxLines: 2,
                          decoration: _buildInputDeco('Operational Notes / Anomalies', borderColor, isDark),
                          style: TextStyle(fontSize: 13, color: textPrimary),
                        ),
                        const SizedBox(height: 20),

                        // Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: Text('Cancel', style: TextStyle(color: textPrimary)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _submit,
                              icon: _isSaving
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 16, color: Colors.white),
                              label: const Text('Save Reading', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco(String label, Color borderColor, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)),
    );
  }
}

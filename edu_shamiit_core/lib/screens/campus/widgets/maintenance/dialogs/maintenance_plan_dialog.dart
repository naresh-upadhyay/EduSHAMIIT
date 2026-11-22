import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';
import '../widgets/location_multi_selector.dart';

class MaintenancePlanDialog extends ConsumerStatefulWidget {
  final MaintenancePlanItem? plan;
  final VoidCallback? onSaved;

  const MaintenancePlanDialog({
    super.key,
    this.plan,
    this.onSaved,
  });

  @override
  ConsumerState<MaintenancePlanDialog> createState() => _MaintenancePlanDialogState();
}

class _MaintenancePlanDialogState extends ConsumerState<MaintenancePlanDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _costController;
  late final TextEditingController _vendorNameController;
  late final TextEditingController _vendorPhoneController;
  late final TextEditingController _vendorEmailController;
  final TextEditingController _checklistItemController = TextEditingController();

  String _category = 'HVAC';
  String _frequency = 'Every 6 Months';
  int _intervalMonths = 6;
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 180));
  bool _sendVendorEmail = true;
  bool _isActive = true;
  bool _isSubmitting = false;

  String? _selectedVendorId;
  List<SelectedLocationItem> _selectedLocations = [];
  final List<String> _checklistItems = [
    'Clean / replace air intake filters',
    'Inspect condenser & evaporator coils',
    'Verify refrigerant charge & operating pressure',
    'Check electrical wiring, contactors & thermostat',
  ];

  final List<String> _categories = [
    'HVAC',
    'Electrical',
    'Plumbing',
    'AV Equipment',
    'Civil',
    'Elevators / Lifts',
    'Fire & Safety',
  ];

  final List<Map<String, dynamic>> _frequencyOptions = [
    {'label': 'Monthly (Every Month)', 'value': 'Monthly', 'months': 1},
    {'label': 'Bi-Monthly (Every 2 Months)', 'value': 'Bi-Monthly', 'months': 2},
    {'label': 'Quarterly (Every 3 Months)', 'value': 'Quarterly', 'months': 3},
    {'label': 'Every 6 Months (Bi-Annual AC/Service)', 'value': 'Every 6 Months', 'months': 6},
    {'label': 'Yearly (Annual Overhaul)', 'value': 'Yearly', 'months': 12},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _titleController = TextEditingController(text: p?.title ?? 'Bi-Annual AC Servicing & Filter Replacement');
    _costController = TextEditingController(text: p != null ? p.estimatedCost.toStringAsFixed(0) : '15000');
    _vendorNameController = TextEditingController(text: p?.vendorName ?? '');
    _vendorPhoneController = TextEditingController(text: p?.vendorPhone ?? '');
    _vendorEmailController = TextEditingController(text: p?.vendorEmail ?? '');

    if (p != null) {
      if (_categories.contains(p.category)) _category = p.category;
      _frequency = p.frequency;
      _intervalMonths = p.recurrenceIntervalMonths > 0 ? p.recurrenceIntervalMonths : 6;
      _nextDueDate = p.nextDueDate;
      _sendVendorEmail = p.sendVendorEmail;
      _isActive = p.isActive;
      _selectedVendorId = p.vendorId;

      if (p.checklistItems.isNotEmpty) {
        _checklistItems.clear();
        for (final it in p.checklistItems) {
          if (it is String) {
            _checklistItems.add(it);
          } else if (it is Map && it['task'] != null) {
            _checklistItems.add(it['task'].toString());
          }
        }
      }

      if (p.targetLocations.isNotEmpty) {
        _selectedLocations = p.targetLocations.map((t) {
          final m = Map<String, dynamic>.from(t as Map);
          return SelectedLocationItem(
            buildingId: m['building_id']?.toString(),
            buildingName: m['building_name']?.toString(),
            floorId: m['floor_id']?.toString(),
            floorName: m['floor_name']?.toString(),
            roomId: m['room_id']?.toString(),
            roomName: m['room_name']?.toString(),
            facilityId: m['facility_id']?.toString(),
            facilityName: m['facility_name']?.toString(),
            displayName: m['location_name'] ?? m['location_display'] ?? 'Campus Location',
            locationType: m['location_type'] ?? 'room',
          );
        }).toList();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    _vendorNameController.dispose();
    _vendorPhoneController.dispose();
    _vendorEmailController.dispose();
    _checklistItemController.dispose();
    super.dispose();
  }

  void _onVendorSelected(String? vendorId, List<MaintenanceVendorItem> vendors) {
    setState(() {
      _selectedVendorId = vendorId;
      if (vendorId != null) {
        final v = vendors.where((x) => x.id == vendorId).firstOrNull;
        if (v != null) {
          _vendorNameController.text = v.vendorName;
          _vendorPhoneController.text = v.phone ?? '';
          _vendorEmailController.text = v.email ?? '';
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final payload = {
      'title': _titleController.text.trim(),
      'category': _category,
      'frequency': _frequency,
      'recurrence_interval_months': _intervalMonths,
      'estimated_cost': double.tryParse(_costController.text.trim()) ?? 0.0,
      'next_due_date': DateFormat('yyyy-MM-dd').format(_nextDueDate),
      'vendor_id': _selectedVendorId,
      'vendor_name': _vendorNameController.text.trim(),
      'vendor_phone': _vendorPhoneController.text.trim(),
      'vendor_email': _vendorEmailController.text.trim(),
      'send_vendor_email': _sendVendorEmail,
      'is_active': _isActive,
      'checklist_items': _checklistItems.map((c) => {'task': c, 'status': 'Pending'}).toList(),
      'target_locations': _selectedLocations.map((l) => l.toJson()).toList(),
      if (_selectedLocations.isNotEmpty) 'building_id': _selectedLocations.first.buildingId,
      if (_selectedLocations.isNotEmpty) 'floor_id': _selectedLocations.first.floorId,
      if (_selectedLocations.isNotEmpty) 'room_id': _selectedLocations.first.roomId,
      if (_selectedLocations.isNotEmpty) 'facility_id': _selectedLocations.first.facilityId,
    };

    bool success = false;
    final notifier = ref.read(maintenanceProvider.notifier);

    if (widget.plan != null) {
      success = await notifier.updatePlan(widget.plan!.id, payload);
    } else {
      success = await notifier.createPlan(payload);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.plan != null ? 'Maintenance plan updated successfully!' : 'Maintenance plan created successfully!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save plan. Please check inputs and try again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final vendors = state.vendors;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMaxWidth = math.min(680.0, screenWidth * 0.95);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.fact_check_outlined, size: 20, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.plan != null ? 'Edit Maintenance Plan (${widget.plan!.planCode})' : 'Create Preventive Maintenance Plan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        Text(
                          'Configure recurring schedules, target multiple locations, and automate vendor notifications',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
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
            const Divider(height: 1, thickness: 1),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Plan Definition
                      _buildSectionHeader('1. Plan Title & Service Scope', Icons.settings_suggest_outlined, textPrimary),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Plan Title *',
                          hintText: 'e.g. AC Annual Servicing & Filter Replacement',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Plan title required' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _category,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _category = v ?? 'HVAC'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _frequency,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Recurrence Frequency *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _frequencyOptions.map((f) => DropdownMenuItem(
                                    value: f['value'] as String,
                                    child: Text(f['label'] as String, style: const TextStyle(fontSize: 12)),
                                  )).toList(),
                              onChanged: (v) {
                                final opt = _frequencyOptions.where((x) => x['value'] == v).firstOrNull;
                                setState(() {
                                  _frequency = v ?? 'Every 6 Months';
                                  _intervalMonths = (opt?['months'] as int?) ?? 6;
                                  _nextDueDate = DateTime.now().add(Duration(days: _intervalMonths * 30));
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _nextDueDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) setState(() => _nextDueDate = d);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Next Due Execution Date',
                                  prefixIcon: const Icon(Icons.event, size: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(_nextDueDate), style: TextStyle(fontSize: 12, color: textPrimary)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Estimated Budget per Cycle (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Multi-Location Selection (Building, Floor, Rooms, Facilities)
                      _buildSectionHeader('2. Target Campus Locations (Single or Bulk Multi-Location)', Icons.domain_add, textPrimary),
                      const SizedBox(height: 10),
                      LocationMultiSelector(
                        initialSelected: _selectedLocations,
                        allowMultiple: true,
                        onSelectionChanged: (locs) => setState(() => _selectedLocations = locs),
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Vendor Automation & Direct Contact
                      _buildSectionHeader('3. Service Vendor Assignment & Automated Contact', Icons.contact_phone_outlined, textPrimary),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _selectedVendorId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select Registered AMC Vendor',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Custom / In-house Maintenance Team', style: TextStyle(fontSize: 12))),
                                ...vendors.map((v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text('${v.vendorName} (${v.serviceCategory} • ${v.phone ?? "No Phone"})', style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                              onChanged: (v) => _onVendorSelected(v, vendors),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _vendorNameController,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Vendor / Contractor Name',
                                      hintText: 'e.g. CoolAir Solutions Pvt Ltd',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _vendorPhoneController,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Vendor Mobile Number',
                                      prefixIcon: const Icon(Icons.phone, size: 14, color: Color(0xFF10B981)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vendorEmailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Vendor Dispatch Email ID',
                                prefixIcon: const Icon(Icons.email_outlined, size: 14, color: Color(0xFF2563EB)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile(
                                value: _sendVendorEmail,
                                onChanged: (v) => setState(() => _sendVendorEmail = v),
                                title: Text('Automated Email Dispatch to Vendor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                                subtitle: Text('When plan triggers, automated work order notification and PDF will be dispatched to vendor email', style: TextStyle(fontSize: 10.5, color: textMuted)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Inspection Checklist Tasks
                      _buildSectionHeader('4. Maintenance Procedure Checklist Tasks', Icons.checklist_rtl_rounded, textPrimary),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _checklistItemController,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Add checklist item (e.g. Check compressor noise & amp draw)...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) {
                                  setState(() {
                                    _checklistItems.add(v.trim());
                                    _checklistItemController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final text = _checklistItemController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  _checklistItems.add(text);
                                  _checklistItemController.clear();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            child: const Text('Add Task', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._checklistItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final task = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(task, style: TextStyle(fontSize: 11.5, color: textPrimary))),
                              IconButton(
                                icon: const Icon(Icons.close, size: 14),
                                onPressed: () => setState(() => _checklistItems.removeAt(idx)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 16, color: Colors.white),
                    label: Text(
                      widget.plan != null ? 'Update Plan' : 'Save Preventive Plan',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

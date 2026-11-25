import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class AssignTechnicianDialog extends ConsumerStatefulWidget {
  final MaintenanceRequestItem request;

  const AssignTechnicianDialog({super.key, required this.request});

  @override
  ConsumerState<AssignTechnicianDialog> createState() => _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState extends ConsumerState<AssignTechnicianDialog> {
  String _technician = 'Suresh Electrician';
  String? _vendor;
  final _instructionsController = TextEditingController();
  final DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  bool _isSubmitting = false;

  List<String> _technicians = [];
  List<String> _vendors = [];

  @override
  void initState() {
    super.initState();
    _technicians = [
      'Suresh Electrician (HVAC / Electrical)',
      'Ramesh Electrician (General Electrical)',
      'Kiran IT Technician (IT / AV Equipment)',
      'Gopal Carpenter (Furniture / Desks)',
      'Vinod Civil Maintenance (Doors / Civil)',
    ];
    _technician = _technicians.first;
    _vendors = [
      'Internal Maintenance Team Only',
      'CoolAir Solutions Pvt Ltd (HVAC AMC)',
      'PowerGrid Electric Services Ltd (AMC)',
      'FlowMaster Plumbing & Fire Systems',
      'Apex AV & Smart Classroom Systems',
    ];
    _vendor = _vendors.first;
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final techs = await CampusLookupHelper.instance.getTechnicians();
    final vends = await CampusLookupHelper.instance.getMaintenanceVendors();
    if (mounted) {
      setState(() {
        if (techs.isNotEmpty) {
          _technicians = techs;
          if (!_technicians.contains(_technician)) _technician = _technicians.first;
        }
        if (vends.isNotEmpty) {
          _vendors = vends;
          if (_vendor != null && !_vendors.contains(_vendor)) _vendor = _vendors.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final success = await ref.read(maintenanceProvider.notifier).assignTechnician(
      widget.request.id,
      assignedToName: _technician,
      vendorName: _vendor,
      scheduledAt: _scheduledDate,
      instructions: _instructionsController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Work order assigned to $_technician!'), backgroundColor: const Color(0xFF16A34A)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to assign work order.'), backgroundColor: Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMaxWidth = math.min(480.0, screenWidth * 0.95);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assign Work Order - ${widget.request.requestCode}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              AppSearchableDropdownFormField<String>.fromMenuItems(
                initialValue: _technicians.contains(_technician) ? _technician : (_technicians.isNotEmpty ? _technicians.first : null),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Assigned Technician',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                dropdownColor: bg,
                items: _technicians.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _technician = v ?? (_technicians.isNotEmpty ? _technicians.first : _technician)),
              ),
              const SizedBox(height: 12),

              AppSearchableDropdownFormField<String?>.fromMenuItems(
                initialValue: _vendors.contains(_vendor) ? _vendor : (_vendors.isNotEmpty ? _vendors.first : null),
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Service Vendor / AMC Contract',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                dropdownColor: bg,
                items: _vendors.map((v) => DropdownMenuItem<String?>(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _vendor = v),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _instructionsController,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Work Instructions / Special Remarks',
                  hintText: 'e.g. Check compressor, verify thermostat voltage...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

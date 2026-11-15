import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class CreateEditMaintenanceDialog extends ConsumerStatefulWidget {
  const CreateEditMaintenanceDialog({super.key});

  @override
  ConsumerState<CreateEditMaintenanceDialog> createState() => _CreateEditMaintenanceDialogState();
}

class _CreateEditMaintenanceDialogState extends ConsumerState<CreateEditMaintenanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController(text: 'B1 / G-101');
  final _reporterController = TextEditingController(text: 'Campus Facility Desk');

  String _requestType = 'Electrical & Power';
  String _priority = 'High';
  String _role = 'Faculty';
  final DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  final String _preferredTime = '02:00 PM';
  bool _isSubmitting = false;

  List<String> _requestTypes = [];
  List<String> _priorities = [];
  List<String> _roles = [];

  @override
  void initState() {
    super.initState();
    _requestTypes = CampusLookupHelper.instance.getImmediateLabels('MAINTENANCE_CATEGORY');
    if (_requestTypes.isNotEmpty) _requestType = _requestTypes.first;
    _priorities = CampusLookupHelper.instance.getImmediateLabels('MAINTENANCE_PRIORITY');
    if (_priorities.isNotEmpty) _priority = _priorities.contains('High') ? 'High' : _priorities.first;
    _roles = CampusLookupHelper.instance.getImmediateLabels('ORGANIZER_ROLE');
    if (_roles.isNotEmpty) _role = _roles.first;

    _loadDynamicLookups();
  }

  Future<void> _loadDynamicLookups() async {
    final types = await CampusLookupHelper.instance.getLookupLabels('MAINTENANCE_CATEGORY');
    final prios = await CampusLookupHelper.instance.getLookupLabels('MAINTENANCE_PRIORITY');
    final roles = await CampusLookupHelper.instance.getLookupLabels('ORGANIZER_ROLE');
    if (mounted) {
      setState(() {
        if (types.isNotEmpty) {
          _requestTypes = types;
          if (!_requestTypes.contains(_requestType)) _requestType = _requestTypes.first;
        }
        if (prios.isNotEmpty) {
          _priorities = prios;
          if (!_priorities.contains(_priority)) _priority = _priorities.first;
        }
        if (roles.isNotEmpty) {
          _roles = roles;
          if (!_roles.contains(_role)) _role = _roles.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _reporterController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'request_type': _requestType,
      'priority': _priority,
      'location_display': _locationController.text.trim(),
      'reported_by_name': _reporterController.text.trim(),
      'reported_by_role': _role,
      'preferred_date': '${_preferredDate.year}-${_preferredDate.month.toString().padLeft(2, '0')}-${_preferredDate.day.toString().padLeft(2, '0')}',
      'preferred_time': _preferredTime,
    };

    final success = await ref.read(maintenanceProvider.notifier).createRequest(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance request raised successfully!'), backgroundColor: Color(0xFF16A34A)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to raise request. Please try again.'), backgroundColor: Color(0xFFEF4444)),
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
    final dialogMaxWidth = math.min(540.0, screenWidth * 0.95);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.build_rounded, size: 18, color: primaryColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Raise Maintenance Request',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
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

                  // Title
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Issue Title *',
                      hintText: 'e.g. AC not cooling, Flickering lights',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Category Type & Priority
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 460;

                      if (isCompact) {
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _requestTypes.contains(_requestType) ? _requestType : (_requestTypes.isNotEmpty ? _requestTypes.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Request Type',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              dropdownColor: bg,
                              items: _requestTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _requestType = v ?? (_requestTypes.isNotEmpty ? _requestTypes.first : 'HVAC')),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _priorities.contains(_priority) ? _priority : (_priorities.isNotEmpty ? _priorities.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              dropdownColor: bg,
                              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) => setState(() => _priority = v ?? (_priorities.isNotEmpty ? _priorities.first : 'High')),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _requestTypes.contains(_requestType) ? _requestType : (_requestTypes.isNotEmpty ? _requestTypes.first : null),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Request Type',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                dropdownColor: bg,
                                items: _requestTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: (v) => setState(() => _requestType = v ?? (_requestTypes.isNotEmpty ? _requestTypes.first : 'HVAC')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _priorities.contains(_priority) ? _priority : (_priorities.isNotEmpty ? _priorities.first : null),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Priority',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                dropdownColor: bg,
                                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                onChanged: (v) => setState(() => _priority = v ?? (_priorities.isNotEmpty ? _priorities.first : 'High')),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Location
                  TextFormField(
                    controller: _locationController,
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Location (Building / Room) *',
                      hintText: 'e.g. B1 / G-101, B2 / F1-202',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Location is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Reporter & Role
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 460;

                      if (isCompact) {
                        return Column(
                          children: [
                            TextFormField(
                              controller: _reporterController,
                              style: TextStyle(fontSize: 13, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Reported By Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _roles.contains(_role) ? _role : (_roles.isNotEmpty ? _roles.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Role',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              dropdownColor: bg,
                              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                              onChanged: (v) => setState(() => _role = v ?? (_roles.isNotEmpty ? _roles.first : 'Faculty')),
                            ),
                          ],
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: TextFormField(
                                controller: _reporterController,
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Reported By Name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                initialValue: _roles.contains(_role) ? _role : (_roles.isNotEmpty ? _roles.first : null),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Role',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                dropdownColor: bg,
                                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                                onChanged: (v) => setState(() => _role = v ?? (_roles.isNotEmpty ? _roles.first : 'Faculty')),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    style: TextStyle(fontSize: 13, color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Detailed Description',
                      hintText: 'Describe the issue, symptoms, and urgency...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Submit Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
}

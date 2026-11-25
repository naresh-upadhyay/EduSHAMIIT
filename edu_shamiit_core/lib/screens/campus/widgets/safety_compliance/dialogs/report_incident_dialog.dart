import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/safety_compliance_models.dart';
import '../../../providers/safety_compliance_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class ReportIncidentDialog extends ConsumerStatefulWidget {
  final SafetyIncidentItem? existingIncident;

  const ReportIncidentDialog({super.key, this.existingIncident});

  @override
  ConsumerState<ReportIncidentDialog> createState() => _ReportIncidentDialogState();
}

class _ReportIncidentDialogState extends ConsumerState<ReportIncidentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _reporterNameController;
  late TextEditingController _reporterRoleController;
  late TextEditingController _descController;
  late TextEditingController _immediateActionController;
  late TextEditingController _preventiveController;
  late TextEditingController _victimsController;

  String _severity = 'Medium';
  String _incidentType = 'Slip, Trip & Fall';
  String _status = 'Reported';
  bool _firstAidProvided = false;
  DateTime _incidentTime = DateTime.now();
  bool _isSaving = false;

  List<String> _severities = [];
  List<String> _incidentTypes = [];
  List<String> _statuses = [];

  @override
  void initState() {
    super.initState();
    _severities = CampusLookupHelper.instance.getImmediateLabels('INCIDENT_SEVERITY');
    _incidentTypes = CampusLookupHelper.instance.getImmediateLabels('INCIDENT_TYPE');
    _statuses = CampusLookupHelper.instance.getImmediateLabels('INCIDENT_STATUS');

    final item = widget.existingIncident;
    _titleController = TextEditingController(text: item?.title ?? '');
    _locationController = TextEditingController(text: item?.locationDisplay ?? 'Academic Block / Ground Floor');
    _reporterNameController = TextEditingController(text: item?.reportedByName ?? 'Admin');
    _reporterRoleController = TextEditingController(text: item?.reportedByRole ?? 'Staff');
    _descController = TextEditingController(text: item?.description ?? '');
    _immediateActionController = TextEditingController(text: item?.immediateActionTaken ?? '');
    _preventiveController = TextEditingController(text: item?.preventiveMeasures ?? '');
    _victimsController = TextEditingController(text: '${item?.victimsCount ?? 0}');

    if (item != null) {
      _severity = item.severity;
      _incidentType = item.incidentType;
      _status = item.status;
      _firstAidProvided = item.firstAidProvided;
      _incidentTime = item.incidentTime;
    } else {
      if (_severities.isNotEmpty && !_severities.contains(_severity)) _severity = _severities.first;
      if (_incidentTypes.isNotEmpty && !_incidentTypes.contains(_incidentType)) _incidentType = _incidentTypes.first;
      if (_statuses.isNotEmpty && !_statuses.contains(_status)) _status = _statuses.first;
    }

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final sList = await CampusLookupHelper.instance.getLookupLabels('INCIDENT_SEVERITY');
    final tList = await CampusLookupHelper.instance.getLookupLabels('INCIDENT_TYPE');
    final stList = await CampusLookupHelper.instance.getLookupLabels('INCIDENT_STATUS');
    if (mounted) {
      setState(() {
        if (sList.isNotEmpty) {
          _severities = sList;
          if (!_severities.contains(_severity)) _severity = _severities.first;
        }
        if (tList.isNotEmpty) {
          _incidentTypes = tList;
          if (!_incidentTypes.contains(_incidentType)) _incidentType = _incidentTypes.first;
        }
        if (stList.isNotEmpty) {
          _statuses = stList;
          if (!_statuses.contains(_status)) _status = _statuses.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _reporterNameController.dispose();
    _reporterRoleController.dispose();
    _descController.dispose();
    _immediateActionController.dispose();
    _preventiveController.dispose();
    _victimsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.existingIncident != null ? 'Edit Safety Incident' : 'Report Safety & Security Incident',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Incident Title
                      Text('Incident Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter incident title' : null,
                        decoration: _inputDeco('e.g. Chemical Fume Leak in Chemistry Lab', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Severity & Type Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Severity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              AppSearchableDropdownFormField<String>.fromMenuItems(
                                isExpanded: true,
                                initialValue: _severities.contains(_severity) ? _severity : (_severities.isNotEmpty ? _severities.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _severities
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _severity = v ?? (_severities.isNotEmpty ? _severities.first : 'Medium')),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Incident Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              AppSearchableDropdownFormField<String>.fromMenuItems(
                                isExpanded: true,
                                initialValue: _incidentTypes.contains(_incidentType) ? _incidentType : (_incidentTypes.isNotEmpty ? _incidentTypes.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _incidentTypes
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _incidentType = v ?? (_incidentTypes.isNotEmpty ? _incidentTypes.first : 'Slip, Trip & Fall')),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location & Status Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location Display *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _locationController,
                                decoration: _inputDeco('e.g. Science Block / Lab 103', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Incident Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              AppSearchableDropdownFormField<String>.fromMenuItems(
                                isExpanded: true,
                                initialValue: _statuses.contains(_status) ? _status : (_statuses.isNotEmpty ? _statuses.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _statuses
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _status = v ?? (_statuses.isNotEmpty ? _statuses.first : 'Reported')),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text('Description & Circumstances', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: _inputDeco('Describe what happened, equipment involved, sequence of events...', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Immediate Action Taken
                      Text('Immediate Action Taken', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _immediateActionController,
                        maxLines: 2,
                        decoration: _inputDeco('e.g. Area evacuated, first aid administered, power isolated...', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Victims & First Aid Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Victims / Affected Count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _victimsController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco('0', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: CheckboxListTile(
                              value: _firstAidProvided,
                              onChanged: (v) => setState(() => _firstAidProvided = v ?? false),
                              title: Text('First Aid Provided On-Site', style: TextStyle(fontSize: 12, color: textPrimary)),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          disabledBackgroundColor: const Color(0xFFFCA5A5),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        ),
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Incident', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = {
      'title': _titleController.text.trim(),
      'severity': _severity,
      'incident_type': _incidentType,
      'location_display': _locationController.text.trim(),
      'reported_by_name': _reporterNameController.text.trim(),
      'reported_by_role': _reporterRoleController.text.trim(),
      'status': _status,
      'description': _descController.text.trim(),
      'immediate_action_taken': _immediateActionController.text.trim(),
      'preventive_measures': _preventiveController.text.trim(),
      'victims_count': int.tryParse(_victimsController.text) ?? 0,
      'first_aid_provided': _firstAidProvided,
      'incident_time': _incidentTime.toIso8601String(),
    };

    try {
      final notifier = ref.read(safetyComplianceProvider.notifier);
      final success = await notifier.saveIncident(payload, incidentId: widget.existingIncident?.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save incident. Please try again.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _responsiveRow(BuildContext context, List<Widget> children) {
    final isMobile = MediaQuery.of(context).size.width < 550;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  InputDecoration _inputDeco(String hint, Color border, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: border)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/safety_compliance_models.dart';
import '../../../providers/safety_compliance_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class ScheduleDrillDialog extends ConsumerStatefulWidget {
  final SafetyDrillItem? existingDrill;

  const ScheduleDrillDialog({super.key, this.existingDrill});

  @override
  ConsumerState<ScheduleDrillDialog> createState() => _ScheduleDrillDialogState();
}

class _ScheduleDrillDialogState extends ConsumerState<ScheduleDrillDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _participantsController;
  late TextEditingController _evacuationTimeController;
  late TextEditingController _targetTimeController;
  late TextEditingController _coordinatorController;
  late TextEditingController _observationsController;

  String _drillType = 'Fire Evacuation & Alarm Response Drill';
  String _status = 'Scheduled';
  String _performanceRating = 'Good';
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 14));
  bool _isSaving = false;

  List<String> _drillTypes = [];

  @override
  void initState() {
    super.initState();
    _drillTypes = CampusLookupHelper.instance.getImmediateLabels('DRILL_TYPE');

    final item = widget.existingDrill;
    _titleController = TextEditingController(text: item?.title ?? '');
    _locationController = TextEditingController(text: item?.locationDisplay ?? 'All Campus Blocks (Assembly Area: Central Turf)');
    _participantsController = TextEditingController(text: '${item?.participantsCount ?? 500}');
    _evacuationTimeController = TextEditingController(text: '${item?.evacuationTimeSeconds ?? 0}');
    _targetTimeController = TextEditingController(text: '${item?.targetTimeSeconds ?? 180}');
    _coordinatorController = TextEditingController(text: item?.coordinatorName ?? 'Capt. Rajesh Varma');
    _observationsController = TextEditingController(text: item?.observations ?? '');

    if (item != null) {
      _drillType = item.drillType;
      _status = item.status;
      _performanceRating = item.performanceRating;
      _scheduledDate = item.scheduledDate;
    } else {
      if (_drillTypes.isNotEmpty && !_drillTypes.contains(_drillType)) {
        _drillType = _drillTypes.first;
      }
    }

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final list = await CampusLookupHelper.instance.getLookupLabels('DRILL_TYPE');
    if (mounted && list.isNotEmpty) {
      setState(() {
        _drillTypes = list;
        if (!_drillTypes.contains(_drillType)) {
          _drillType = _drillTypes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _participantsController.dispose();
    _evacuationTimeController.dispose();
    _targetTimeController.dispose();
    _coordinatorController.dispose();
    _observationsController.dispose();
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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
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
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.campaign_rounded, size: 20, color: Color(0xFF06B6D4)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.existingDrill != null ? 'Edit Safety Drill' : 'Schedule Emergency Evacuation Drill',
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
                      Text('Drill Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter drill title' : null,
                        decoration: _inputDeco('e.g. Semi-Annual Campus Fire Evacuation Simulation', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Drill Type & Status Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Drill Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _drillTypes.contains(_drillType) ? _drillType : (_drillTypes.isNotEmpty ? _drillTypes.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _drillTypes
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _drillType = v ?? (_drillTypes.isNotEmpty ? _drillTypes.first : 'Fire Evacuation & Alarm Response Drill')),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Execution Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _status,
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: ['Scheduled', 'Completed', 'Cancelled']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _status = v ?? 'Scheduled'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location & Scheduled Date Row
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
                                decoration: _inputDeco('e.g. All Blocks / Football Turf', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Scheduled Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(context: context, initialDate: _scheduledDate, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime(2030));
                                  if (picked != null) setState(() => _scheduledDate = picked);
                                },
                                icon: const Icon(Icons.event_available, size: 15),
                                label: Text('${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}', style: TextStyle(fontSize: 12, color: textPrimary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  side: BorderSide(color: borderColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Participants, Evac Time & Target Time Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Participants', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _participantsController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco('500', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target (Sec)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _targetTimeController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco('180', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Actual (Sec)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _evacuationTimeController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco('0', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Coordinator & Rating Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Coordinator *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _coordinatorController,
                                decoration: _inputDeco('e.g. Chief Safety Warden', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Performance Rating', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _performanceRating,
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: ['Excellent', 'Good', 'Satisfactory', 'Needs Improvement']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _performanceRating = v ?? 'Good'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Observations & Follow-up
                      Text('Observations & Evacuation Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _observationsController,
                        maxLines: 2,
                        decoration: _inputDeco('Note bottlenecks, assembly headcounts, alarm responsiveness...', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        disabledBackgroundColor: const Color(0xFF67E8F9),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Drill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
      'drill_type': _drillType,
      'location_display': _locationController.text.trim(),
      'scheduled_date': '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}',
      'status': _status,
      'participants_count': int.tryParse(_participantsController.text) ?? 500,
      'target_time_seconds': int.tryParse(_targetTimeController.text) ?? 180,
      'evacuation_time_seconds': int.tryParse(_evacuationTimeController.text) ?? 0,
      'coordinator_name': _coordinatorController.text.trim(),
      'performance_rating': _performanceRating,
      'observations': _observationsController.text.trim(),
    };

    try {
      final notifier = ref.read(safetyComplianceProvider.notifier);
      final success = await notifier.saveDrill(payload, drillId: widget.existingDrill?.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save drill. Please try again.')),
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

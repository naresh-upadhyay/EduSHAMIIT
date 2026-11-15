import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/safety_compliance_models.dart';
import '../../../providers/safety_compliance_provider.dart';

class LogInspectionDialog extends ConsumerStatefulWidget {
  final SafetyInspectionItem? existingInspection;

  const LogInspectionDialog({super.key, this.existingInspection});

  @override
  ConsumerState<LogInspectionDialog> createState() => _LogInspectionDialogState();
}

class _LogInspectionDialogState extends ConsumerState<LogInspectionDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _inspectorNameController;
  late TextEditingController _inspectorRoleController;
  late TextEditingController _scoreController;
  late TextEditingController _findingsController;

  String _category = 'Fire Safety';
  String _status = 'Passed';
  DateTime _inspectionDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final item = widget.existingInspection;
    _titleController = TextEditingController(text: item?.title ?? '');
    _locationController = TextEditingController(text: item?.locationDisplay ?? 'Academic Block / All Floors');
    _inspectorNameController = TextEditingController(text: item?.inspectorName ?? 'Capt. Rajesh Varma');
    _inspectorRoleController = TextEditingController(text: item?.inspectorRole ?? 'Safety Officer');
    _scoreController = TextEditingController(text: '${item?.complianceScore ?? 96.0}');
    _findingsController = TextEditingController(text: item?.findings ?? '');

    if (item != null) {
      _category = item.category;
      _status = item.status;
      _inspectionDate = item.inspectionDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _inspectorNameController.dispose();
    _inspectorRoleController.dispose();
    _scoreController.dispose();
    _findingsController.dispose();
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
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fact_check_rounded, size: 20, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.existingInspection != null ? 'Edit Safety Inspection' : 'Log Safety & Quality Inspection',
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
                      Text('Inspection Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter inspection title' : null,
                        decoration: _inputDeco('e.g. Quarterly Extinguisher & Fire Hose Reel Audit', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Category & Status Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _category,
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: ['Fire Safety', 'Electrical Safety', 'Lab & Chemical Safety', 'Structural Integrity', 'Sanitation & Hygiene', 'CCTV & Physical Security', 'Sports & Playground', 'Food & Water Safety']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _category = v ?? 'Fire Safety'),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inspection Status *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _status,
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: ['Passed', 'Needs Attention', 'Critical Action', 'Scheduled']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _status = v ?? 'Passed'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location & Score Row
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
                                decoration: _inputDeco('e.g. Science Block / Labs', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Score (%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _scoreController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDeco('95.0', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Inspector Details Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inspector Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _inspectorNameController,
                                decoration: _inputDeco('Inspector full name', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inspector Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _inspectorRoleController,
                                decoration: _inputDeco('e.g. Fire Marshal, Facilities Head', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Findings & Audit Observations
                      Text('Audit Findings & Action Recommendations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _findingsController,
                        maxLines: 3,
                        decoration: _inputDeco('Enter physical check findings, pressure readings, test outcomes...', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        ),
                        onPressed: _submit,
                        child: const Text(
                          'Save Inspection',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
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
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'title': _titleController.text.trim(),
      'category': _category,
      'location_display': _locationController.text.trim(),
      'inspector_name': _inspectorNameController.text.trim(),
      'inspector_role': _inspectorRoleController.text.trim(),
      'status': _status,
      'compliance_score': double.tryParse(_scoreController.text) ?? 95.0,
      'findings': _findingsController.text.trim(),
      'inspection_date': '${_inspectionDate.year}-${_inspectionDate.month.toString().padLeft(2, '0')}-${_inspectionDate.day.toString().padLeft(2, '0')}',
    };

    final notifier = ref.read(safetyComplianceProvider.notifier);
    final success = await notifier.saveInspection(payload, inspectionId: widget.existingInspection?.id);
    if (mounted && success) {
      Navigator.pop(context);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/safety_compliance_models.dart';
import '../../../providers/safety_compliance_provider.dart';
import '../../../services/campus_lookup_helper.dart';

class AddCertificateDialog extends ConsumerStatefulWidget {
  final ComplianceCertificateItem? existingCertificate;

  const AddCertificateDialog({super.key, this.existingCertificate});

  @override
  ConsumerState<AddCertificateDialog> createState() => _AddCertificateDialogState();
}

class _AddCertificateDialogState extends ConsumerState<AddCertificateDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _authorityController;
  late TextEditingController _certNumberController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  String _category = 'Fire Safety NOC & Clearance';
  String _status = 'Valid';
  DateTime _issueDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 335));
  bool _isSaving = false;

  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _categories = CampusLookupHelper.instance.getImmediateLabels('CERTIFICATE_TYPE');

    final item = widget.existingCertificate;
    _titleController = TextEditingController(text: item?.title ?? '');
    _authorityController = TextEditingController(text: item?.issuingAuthority ?? '');
    _certNumberController = TextEditingController(text: item?.certificateNumber ?? '');
    _locationController = TextEditingController(text: item?.locationDisplay ?? 'All Campus Buildings');
    _notesController = TextEditingController(text: item?.notes ?? '');

    if (item != null) {
      _category = item.category;
      _status = item.status;
      _issueDate = item.issueDate;
      _expiryDate = item.expiryDate;
    } else {
      if (_categories.isNotEmpty && !_categories.contains(_category)) {
        _category = _categories.first;
      }
    }

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final list = await CampusLookupHelper.instance.getLookupLabels('CERTIFICATE_TYPE');
    if (mounted && list.isNotEmpty) {
      setState(() {
        _categories = list;
        if (!_categories.contains(_category)) {
          _category = _categories.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorityController.dispose();
    _certNumberController.dispose();
    _locationController.dispose();
    _notesController.dispose();
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.article_rounded, size: 20, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.existingCertificate != null ? 'Edit Compliance Certificate' : 'Add Statutory Certificate',
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
                      Text('Certificate / Clearance Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _titleController,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter title' : null,
                        decoration: _inputDeco('e.g. Fire Safety No Objection Certificate (Fire NOC)', borderColor, isDark),
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                      ),
                      const SizedBox(height: 12),

                      // Category & Authority Row
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
                                initialValue: _categories.contains(_category) ? _category : (_categories.isNotEmpty ? _categories.first : null),
                                decoration: _inputDeco('', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _categories
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: textPrimary))))
                                    .toList(),
                                onChanged: (v) => setState(() => _category = v ?? (_categories.isNotEmpty ? _categories.first : 'Fire Safety NOC & Clearance')),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Issuing Authority *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _authorityController,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter authority' : null,
                                decoration: _inputDeco('e.g. State Fire Services', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Registration No & Location Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('License / Reg Number *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _certNumberController,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter reg number' : null,
                                decoration: _inputDeco('e.g. NOC-2026-9041', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Applicable Location', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              TextFormField(
                                controller: _locationController,
                                decoration: _inputDeco('e.g. All Campus Buildings', borderColor, isDark),
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Issue & Expiry Dates Row
                      _responsiveRow(
                        context,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Issue Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(context: context, initialDate: _issueDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                                  if (picked != null) setState(() => _issueDate = picked);
                                },
                                icon: const Icon(Icons.calendar_today, size: 15),
                                label: Text('${_issueDate.day}/${_issueDate.month}/${_issueDate.year}', style: TextStyle(fontSize: 12, color: textPrimary)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  side: BorderSide(color: borderColor),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expiry Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 5),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showDatePicker(context: context, initialDate: _expiryDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                                  if (picked != null) setState(() => _expiryDate = picked);
                                },
                                icon: const Icon(Icons.event_busy, size: 15, color: Color(0xFFEF4444)),
                                label: Text('${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}', style: TextStyle(fontSize: 12, color: textPrimary)),
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

                      // Notes & Remarks
                      Text('Compliance Notes & Renewal Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 5),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: _inputDeco('Enter physical verification summary, renewal prerequisites...', borderColor, isDark),
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
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          disabledBackgroundColor: const Color(0xFF6EE7B7),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        ),
                        onPressed: _isSaving ? null : _submit,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Certificate', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
      'category': _category,
      'issuing_authority': _authorityController.text.trim(),
      'certificate_number': _certNumberController.text.trim(),
      'location_display': _locationController.text.trim(),
      'issue_date': '${_issueDate.year}-${_issueDate.month.toString().padLeft(2, '0')}-${_issueDate.day.toString().padLeft(2, '0')}',
      'expiry_date': '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}',
      'status': _status,
      'notes': _notesController.text.trim(),
    };

    try {
      final notifier = ref.read(safetyComplianceProvider.notifier);
      final success = await notifier.saveCertificate(payload, certificateId: widget.existingCertificate?.id);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save certificate. Please try again.')),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';

class AddEditVendorContractDialog extends ConsumerStatefulWidget {
  final MaintenanceVendorItem? vendor;
  final VoidCallback? onSaved;

  const AddEditVendorContractDialog({
    super.key,
    this.vendor,
    this.onSaved,
  });

  @override
  ConsumerState<AddEditVendorContractDialog> createState() => _AddEditVendorContractDialogState();
}

class _AddEditVendorContractDialogState extends ConsumerState<AddEditVendorContractDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _refNoController;
  late final TextEditingController _valueController;
  late final TextEditingController _docNameController;
  late final TextEditingController _docUrlController;
  late final TextEditingController _notesController;
  late final TextEditingController _addressController;

  String _category = 'HVAC';
  String _contractType = 'AMC';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  double _slaResponseHours = 4.0;
  double _slaResolutionHours = 24.0;
  bool _isActive = true;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'HVAC',
    'Electrical',
    'Plumbing',
    'AV Equipment',
    'Civil / Building',
    'Elevators / Lifts',
    'Fire & Safety',
    'Pest Control',
    'Security & CCTV',
    'Cleaning & Sanitation',
    'General',
  ];

  final List<String> _contractTypes = [
    'AMC',
    'Comprehensive CMC',
    'On-Demand SLA',
    'Equipment Warranty',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _nameController = TextEditingController(text: v?.vendorName ?? '');
    _contactController = TextEditingController(text: v?.contactPerson ?? '');
    _phoneController = TextEditingController(text: v?.phone ?? '');
    _emailController = TextEditingController(text: v?.email ?? '');
    _refNoController = TextEditingController(text: v?.contractRefNo ?? 'AMC-${DateTime.now().year}-${math.Random().nextInt(90) + 10}');
    _valueController = TextEditingController(text: v != null && v.contractValue > 0 ? v.contractValue.toStringAsFixed(0) : '150000');
    _docNameController = TextEditingController(text: v?.contractDocumentName ?? 'Service_Agreement_Contract.pdf');
    _docUrlController = TextEditingController(text: v?.agreementUrl ?? 'https://assets.edushamiit.org/contracts/Vendor_AMC_Agreement.pdf');
    _notesController = TextEditingController(text: v?.notes ?? '');
    _addressController = TextEditingController(text: v?.address ?? '');

    if (v != null) {
      if (_categories.contains(v.serviceCategory)) _category = v.serviceCategory;
      if (_contractTypes.contains(v.contractType)) _contractType = v.contractType;
      if (v.contractStart != null) _startDate = v.contractStart!;
      if (v.contractEnd != null) _endDate = v.contractEnd!;
      _slaResponseHours = v.slaResponseHours;
      _slaResolutionHours = v.slaResolutionHours;
      _isActive = v.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _refNoController.dispose();
    _valueController.dispose();
    _docNameController.dispose();
    _docUrlController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final payload = {
      'vendor_name': _nameController.text.trim(),
      'contact_person': _contactController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'service_category': _category,
      'contract_type': _contractType,
      'contract_ref_no': _refNoController.text.trim(),
      'contract_value': double.tryParse(_valueController.text.trim()) ?? 0.0,
      'contract_start': DateFormat('yyyy-MM-dd').format(_startDate),
      'contract_end': DateFormat('yyyy-MM-dd').format(_endDate),
      'sla_response_hours': _slaResponseHours,
      'sla_resolution_hours': _slaResolutionHours,
      'contract_document_name': _docNameController.text.trim(),
      'agreement_url': _docUrlController.text.trim(),
      'notes': _notesController.text.trim(),
      'address': _addressController.text.trim(),
      'is_active': _isActive,
      'attachments': [
        {
          'file_name': _docNameController.text.trim(),
          'url': _docUrlController.text.trim(),
          'uploaded_at': DateTime.now().toIso8601String(),
          'file_size': '2.4 MB',
        }
      ],
    };

    bool success = false;
    final notifier = ref.read(maintenanceProvider.notifier);

    if (widget.vendor != null) {
      success = await notifier.updateVendor(widget.vendor!.id, payload);
    } else {
      success = await notifier.createVendor(payload);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.vendor != null ? 'Vendor contract updated successfully!' : 'Vendor contract registered successfully!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save vendor contract. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.handshake_outlined, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.vendor != null ? 'Edit Vendor & AMC Contract' : 'Register Service Vendor & Agreement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                        ),
                        Text(
                          'Configure contact information, service scope, SLAs, and upload contract document',
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
                      // Section 1: Vendor Organization & Contact Details
                      _buildSectionHeader('1. Vendor Organization & Direct Contact', Icons.business_outlined, textPrimary),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameController,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Vendor Company / Agency Name *',
                                hintText: 'e.g. CoolAir Solutions Pvt Ltd',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? 'Vendor name required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _contactController,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Contact Person',
                                hintText: 'e.g. Rajesh Sharma',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Mobile / Phone Number *',
                                hintText: '+91 98801 23456',
                                prefixIcon: const Icon(Icons.phone_outlined, size: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? 'Phone number required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Official Email ID *',
                                hintText: 'support@vendor.com',
                                prefixIcon: const Icon(Icons.email_outlined, size: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (v) => v?.trim().isEmpty == true ? 'Email required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Service Category & Contract Specs
                      _buildSectionHeader('2. Service Scope & Agreement Terms', Icons.assignment_outlined, textPrimary),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _category,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Service Category',
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
                              initialValue: _contractType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Contract Type',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _contractTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _contractType = v ?? 'AMC'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _refNoController,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Contract Ref / Agreement No',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _valueController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Contract Annual Value (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Dates Row
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) setState(() => _startDate = d);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Agreement Start Date',
                                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 15),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(_startDate), style: TextStyle(fontSize: 12, color: textPrimary)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (d != null) setState(() => _endDate = d);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Agreement End Date',
                                  prefixIcon: const Icon(Icons.event_outlined, size: 15),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(_endDate), style: TextStyle(fontSize: 12, color: textPrimary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 3: SLA Performance Metrics
                      _buildSectionHeader('3. SLA Guarantees & Turnaround Times', Icons.timer_outlined, textPrimary),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('SLA Response Time', style: TextStyle(fontSize: 11, color: textMuted), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 4),
                                    Text('${_slaResponseHours.toStringAsFixed(1)} Hours', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                                  ],
                                ),
                                Slider(
                                  value: _slaResponseHours,
                                  min: 1.0,
                                  max: 48.0,
                                  divisions: 47,
                                  label: '${_slaResponseHours.toInt()}h',
                                  onChanged: (v) => setState(() => _slaResponseHours = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('SLA Resolution Target', style: TextStyle(fontSize: 11, color: textMuted), overflow: TextOverflow.ellipsis)),
                                    const SizedBox(width: 4),
                                    Text('${_slaResolutionHours.toStringAsFixed(0)} Hours', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                  ],
                                ),
                                Slider(
                                  value: _slaResolutionHours,
                                  min: 4.0,
                                  max: 72.0,
                                  divisions: 34,
                                  label: '${_slaResolutionHours.toInt()}h',
                                  onChanged: (v) => setState(() => _slaResolutionHours = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Document Attachment & Agreement File
                      _buildSectionHeader('4. Contract / Agreement Document Attachment', Icons.attach_file_rounded, textPrimary),
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
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _docNameController,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Attached Document File Name',
                                      prefixIcon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 16),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _docNameController.text = 'Signed_${_category}_AMC_Agreement_${DateTime.now().year}.pdf';
                                      _docUrlController.text = 'https://assets.edushamiit.org/contracts/Signed_${_category}_Agreement.pdf';
                                    });
                                  },
                                  icon: const Icon(Icons.upload_file, size: 15),
                                  label: const Text('Attach Sample', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _docUrlController,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Document Storage URL / Secure Access Link',
                                prefixIcon: const Icon(Icons.link, size: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes & Active Switch
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        style: TextStyle(fontSize: 12, color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Special Terms, Equipment Exclusions or Renewal Notes',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          title: Text('Active Contract Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                          subtitle: Text('Inactive contracts will be excluded from automatic maintenance work order routing', style: TextStyle(fontSize: 10.5, color: textMuted)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Footer Actions
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
                      widget.vendor != null ? 'Update Vendor Contract' : 'Save & Register Contract',
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
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
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

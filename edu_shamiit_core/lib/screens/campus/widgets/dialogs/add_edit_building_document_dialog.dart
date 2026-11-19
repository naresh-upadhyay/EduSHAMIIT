import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';

class AddEditBuildingDocumentDialog extends StatefulWidget {
  final BuildingModel building;
  final BuildingDocumentModel? document;
  final VoidCallback onSaved;

  const AddEditBuildingDocumentDialog({
    super.key,
    required this.building,
    this.document,
    required this.onSaved,
  });

  @override
  State<AddEditBuildingDocumentDialog> createState() => _AddEditBuildingDocumentDialogState();
}

class _AddEditBuildingDocumentDialogState extends State<AddEditBuildingDocumentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _authorityCtrl;
  late TextEditingController _urlCtrl;

  String _documentType = 'Compliance';
  String _status = 'Valid';
  DateTime? _issueDate;
  DateTime? _expiryDate;

  Uint8List? _fileBytes;
  String? _fileName;
  int _fileSize = 0;
  bool _isUploadingFile = false;
  bool _isSaving = false;
  String? _error;

  final List<String> _docTypes = [
    'Compliance',
    'Fire Safety NOC',
    'Occupancy Certificate',
    'Municipal Clearance',
    'Architectural Blueprint',
    'Structural Stability',
    'Electrical Clearance',
    'Pollution & Environment',
    'Insurance Policy',
    'Sanitation & Health',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _nameCtrl = TextEditingController(text: doc?.documentName ?? '');
    _authorityCtrl = TextEditingController(text: doc?.issuingAuthority ?? '');
    _urlCtrl = TextEditingController(text: doc?.fileUrl ?? '');
    if (doc != null) {
      if (_docTypes.contains(doc.documentType)) {
        _documentType = doc.documentType;
      }
      _status = doc.status;
      if (doc.issueDate != null) _issueDate = DateTime.tryParse(doc.issueDate!);
      if (doc.expiryDate != null) _expiryDate = DateTime.tryParse(doc.expiryDate!);
      _fileSize = doc.fileSizeBytes;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _authorityCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'docx', 'xlsx'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final f = res.files.first;
        if (f.bytes != null) {
          setState(() {
            _fileBytes = f.bytes;
            _fileName = f.name;
            _fileSize = f.size;
            _isUploadingFile = true;
            if (_nameCtrl.text.trim().isEmpty) {
              _nameCtrl.text = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
            }
          });

          final uploadedUrl = await CampusApiService.instance.uploadImage(f.bytes!, f.name);
          if (mounted) {
            setState(() {
              _isUploadingFile = false;
              if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                _urlCtrl.text = uploadedUrl;
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingFile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_urlCtrl.text.trim().isEmpty && _fileBytes == null) {
      setState(() => _error = 'Please upload a document file or specify a valid file URL.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'building_id': widget.building.id,
      'document_name': _nameCtrl.text.trim(),
      'document_type': _documentType,
      'file_url': _urlCtrl.text.trim(),
      'file_size_bytes': _fileSize,
      'mime_type': _fileName != null && _fileName!.endsWith('.pdf') ? 'application/pdf' : 'application/octet-stream',
      'issue_date': _issueDate != null ? '${_issueDate!.year}-${_issueDate!.month.toString().padLeft(2, '0')}-${_issueDate!.day.toString().padLeft(2, '0')}' : null,
      'expiry_date': _expiryDate != null ? '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}' : null,
      'issuing_authority': _authorityCtrl.text.trim().isNotEmpty ? _authorityCtrl.text.trim() : null,
      'status': _status,
    };

    final res = await CampusApiService.instance.saveBuildingDocument(
      widget.building.id,
      payload,
      docId: widget.document?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save document.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.document != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogWidth = math.min(580.0, MediaQuery.of(context).size.width * 0.95);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Building Document' : 'Upload Building Compliance Document',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Document Title *',
                          hintText: 'e.g. Fire Safety NOC 2026-2028',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Document Type & Status
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _documentType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Document Category',
                                prefixIcon: Icon(Icons.category_outlined, size: 18),
                              ),
                              items: _docTypes
                                  .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) => setState(() => _documentType = v ?? _documentType),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.verified_outlined, size: 18),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Valid', child: Text('Valid / Active')),
                                DropdownMenuItem(value: 'Under Review', child: Text('Under Review')),
                                DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? _status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Issuing Authority
                      TextFormField(
                        controller: _authorityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Issuing Authority / Agency',
                          hintText: 'e.g. State Disaster & Fire Services / Municipal Corp',
                          prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _issueDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2040),
                                );
                                if (d != null) setState(() => _issueDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Issue Date',
                                  prefixIcon: Icon(Icons.calendar_today, size: 16),
                                ),
                                child: Text(
                                  _issueDate != null
                                      ? '${_issueDate!.day.toString().padLeft(2, '0')}/${_issueDate!.month.toString().padLeft(2, '0')}/${_issueDate!.year}'
                                      : 'Select date',
                                  style: TextStyle(fontSize: 12.5, color: _issueDate == null ? Colors.grey : null),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2050),
                                );
                                if (d != null) setState(() => _expiryDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expiry / Renewal Date',
                                  prefixIcon: Icon(Icons.event_repeat, size: 16),
                                ),
                                child: Text(
                                  _expiryDate != null
                                      ? '${_expiryDate!.day.toString().padLeft(2, '0')}/${_expiryDate!.month.toString().padLeft(2, '0')}/${_expiryDate!.year}'
                                      : 'No expiry',
                                  style: TextStyle(fontSize: 12.5, color: _expiryDate == null ? Colors.grey : null),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // File Picker Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Attached Document File *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isUploadingFile ? null : _pickFile,
                                  icon: _isUploadingFile
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.attach_file, size: 16),
                                  label: Text(_isUploadingFile ? 'Uploading...' : 'Choose File (PDF/Image)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _fileName ?? (_urlCtrl.text.isNotEmpty ? 'File URL configured' : 'No file selected yet'),
                                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _urlCtrl,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Document Storage URL',
                                hintText: 'https://... or auto-generated upon upload',
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 24),

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Upload Document'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

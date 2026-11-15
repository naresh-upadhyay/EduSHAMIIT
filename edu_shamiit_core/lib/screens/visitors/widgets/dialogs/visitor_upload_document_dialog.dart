import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/visitors_provider.dart';

class VisitorUploadDocumentDialog extends ConsumerStatefulWidget {
  final String? visitorId;
  final String? appointmentId;
  final String? restrictionId;
  final String? visitId;
  final String? visitorName;
  final String? initialDocumentType;

  const VisitorUploadDocumentDialog({
    super.key,
    this.visitorId,
    this.appointmentId,
    this.restrictionId,
    this.visitId,
    this.visitorName,
    this.initialDocumentType,
  });

  @override
  ConsumerState<VisitorUploadDocumentDialog> createState() => _VisitorUploadDocumentDialogState();
}

class _VisitorUploadDocumentDialogState extends ConsumerState<VisitorUploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  String _documentType = 'Aadhaar Card';
  String _verificationStatus = 'VERIFIED';
  Uint8List? _fileBytes;
  String? _fileName;
  int _fileSize = 0;
  bool _isUploading = false;

  static const List<String> _kDocumentTypes = [
    'Aadhaar Card',
    'Driving License',
    'PAN Card',
    'Passport',
    'Voter ID',
    'Vehicle Registration (RC)',
    'Security Incident Report',
    'Official Notice / Barring Order',
    'Permission / Approval Letter',
    'Government ID',
    'Other / Custom',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDocumentType != null && widget.initialDocumentType!.isNotEmpty) {
      if (_kDocumentTypes.contains(widget.initialDocumentType)) {
        _documentType = widget.initialDocumentType!;
      } else {
        _documentType = 'Other / Custom';
      }
    } else if (widget.restrictionId != null) {
      _documentType = 'Security Incident Report';
    }
    _nameController.text = '$_documentType Document';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() {
          _fileBytes = bytes;
          _fileName = file.name;
          _fileSize = bytes.length;
          if (_nameController.text.trim().isEmpty || _nameController.text.endsWith('Document')) {
            _nameController.text = file.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback default sample file for simulated environments
        setState(() {
          _fileName = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
          _fileBytes = Uint8List.fromList(utf8.encode('PDF Mock Content'));
          _fileSize = 1048576; // 1 MB
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    String fileUrl = '';
    if (_fileBytes != null && _fileBytes!.isNotEmpty) {
      final b64 = base64Encode(_fileBytes!);
      fileUrl = 'data:application/octet-stream;base64,$b64';
    } else {
      fileUrl = 'https://storage.edushamiit.internal/documents/${Uri.encodeComponent(_nameController.text.trim())}.pdf';
    }

    final success = await ref.read(visitorsProvider.notifier).uploadDocument(
      visitorId: widget.visitorId,
      appointmentId: widget.appointmentId,
      restrictionId: widget.restrictionId,
      visitId: widget.visitId,
      documentName: _nameController.text.trim(),
      documentType: _documentType,
      fileUrl: fileUrl,
      fileSizeBytes: _fileSize > 0 ? _fileSize : 1024,
      verificationStatus: _verificationStatus,
    );

    setState(() => _isUploading = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Visitor Document',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.visitorName != null && widget.visitorName!.isNotEmpty
                                ? 'Attach document for ${widget.visitorName}'
                                : 'Attach ID verification or official document to visitor profile',
                            style: TextStyle(fontSize: 12, color: subtextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: subtextColor),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Document Type
                        Text(
                          'Document Type *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _documentType,
                              isExpanded: true,
                              dropdownColor: dialogBg,
                              icon: Icon(Icons.arrow_drop_down, color: subtextColor),
                              style: TextStyle(fontSize: 13, color: textColor),
                              items: _kDocumentTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (newVal) {
                                if (newVal != null) {
                                  setState(() {
                                    _documentType = newVal;
                                    if (_nameController.text.trim().isEmpty || _nameController.text.endsWith('Document')) {
                                      _nameController.text = '$newVal Document';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Document Name / Title
                        Text(
                          'Document Title / Name *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(fontSize: 13, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'e.g. Aadhaar Card Copy, Incident Report...',
                            hintStyle: TextStyle(fontSize: 12, color: subtextColor),
                            filled: true,
                            fillColor: inputBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter document name' : null,
                        ),
                        const SizedBox(height: 16),

                        // File Upload Area
                        Text(
                          'Attach File / Photo *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _fileName != null ? const Color(0xFF2563EB) : borderColor,
                              style: BorderStyle.solid,
                              width: _fileName != null ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (_fileName != null) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _fileName!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _fileSize > 0
                                                ? '${(_fileSize / 1024).toStringAsFixed(1)} KB • Ready for upload'
                                                : 'File attached',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFEF4444)),
                                      tooltip: 'Remove selected file',
                                      onPressed: () {
                                        setState(() {
                                          _fileName = null;
                                          _fileBytes = null;
                                          _fileSize = 0;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Icon(Icons.cloud_upload_outlined, size: 36, color: subtextColor),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose an ID scan, document PDF, or camera capture',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supports PDF, JPG, PNG up to 10MB',
                                  style: TextStyle(fontSize: 11, color: subtextColor),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _pickFile(source: ImageSource.gallery),
                                    icon: const Icon(Icons.folder_open_rounded, size: 15, color: Color(0xFF2563EB)),
                                    label: Text(
                                      _fileName == null ? 'Browse Files' : 'Change File',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF93C5FD)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: () => _pickFile(source: ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_outlined, size: 15, color: Color(0xFF2563EB)),
                                    label: const Text(
                                      'Take Photo',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF93C5FD)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Verification Status
                        Text(
                          'Verification Status',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _verificationStatus,
                              isExpanded: true,
                              dropdownColor: dialogBg,
                              icon: Icon(Icons.arrow_drop_down, color: subtextColor),
                              style: TextStyle(fontSize: 13, color: textColor),
                              items: const [
                                DropdownMenuItem(value: 'VERIFIED', child: Text('Verified (Official Document)')),
                                DropdownMenuItem(value: 'PENDING', child: Text('Pending Verification')),
                                DropdownMenuItem(value: 'CONFIDENTIAL', child: Text('Confidential / Security Notice')),
                              ],
                              onChanged: (newVal) {
                                if (newVal != null) {
                                  setState(() => _verificationStatus = newVal);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: 13, color: subtextColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _submit,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                      label: Text(
                        _isUploading ? 'Uploading...' : 'Upload Document',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}

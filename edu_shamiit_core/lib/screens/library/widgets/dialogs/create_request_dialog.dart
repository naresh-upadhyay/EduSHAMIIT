import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/request_provider.dart';

class CreateRequestDialog extends ConsumerStatefulWidget {
  const CreateRequestDialog({super.key});

  @override
  ConsumerState<CreateRequestDialog> createState() => _CreateRequestDialogState();
}

class _CreateRequestDialogState extends ConsumerState<CreateRequestDialog> {
  final _formKey = GlobalKey<FormState>();

  String _requestType = 'Book';
  String _preferredFormat = 'Physical';
  String _priority = 'Medium';
  final int _quantity = 1;
  DateTime? _requiredBy;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _editionController = TextEditingController();
  final TextEditingController _languageController = TextEditingController(text: 'English');
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  final List<Map<String, dynamic>> _uploadedAttachments = [];
  bool _isUploadingAttachment = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _publisherController.dispose();
    _editionController.dispose();
    _languageController.dispose();
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc', 'xlsx', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      setState(() => _isUploadingAttachment = true);
      final notifier = ref.read(requestProvider.notifier);
      final res = await notifier.uploadTempAttachment(
        bytes: bytes,
        filename: file.name,
      );

      setState(() {
        _uploadedAttachments.add({
          'file_name': res['file_name'] ?? file.name,
          'file_url': res['file_url'] ?? '',
          'mime_type': res['mime_type'] ?? 'application/octet-stream',
          'file_size': res['file_size'] ?? file.size,
        });
        _isUploadingAttachment = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File "${file.name}" attached successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingAttachment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload attachment: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Color(0xFFDC2626);
      case 'png':
      case 'jpg':
      case 'jpeg':
        return const Color(0xFF2563EB);
      case 'doc':
      case 'docx':
        return const Color(0xFF0284C7);
      case 'xlsx':
      case 'xls':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(requestProvider);
    final options = state.options;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 16,
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Library Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Request a new book, e-book, journal, or digital resource with attachments',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request Type & Format Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Request Type *',
                              value: _requestType,
                              items: options.requestTypes,
                              onChanged: (val) => setState(() => _requestType = val ?? 'Book'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Preferred Format',
                              value: _preferredFormat,
                              items: options.formats,
                              onChanged: (val) => setState(() => _preferredFormat = val ?? 'Physical'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Title
                      _buildTextField(
                        controller: _titleController,
                        label: 'Title / Item Name *',
                        hint: 'e.g. The Psychology of Money or IEEE Transactions',
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Author & ISBN
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _authorController,
                              label: 'Author / Editor',
                              hint: 'e.g. Morgan Housel',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _isbnController,
                              label: 'ISBN / Identifier',
                              hint: 'e.g. 978-0857197689',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Publisher & Edition
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _publisherController,
                              label: 'Publisher',
                              hint: 'e.g. Harriman House',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _editionController,
                              label: 'Edition / Volume',
                              hint: 'e.g. 2nd Edition',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Priority, Quantity & Required By Date
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              label: 'Priority',
                              value: _priority,
                              items: options.priorities.where((e) => e.toUpperCase() != 'ALL').toList().isNotEmpty
                                  ? options.priorities.where((e) => e.toUpperCase() != 'ALL').toList()
                                  : ['Low', 'Medium', 'High', 'Urgent'],
                              onChanged: (val) => setState(() => _priority = val ?? 'Medium'),
                            ),
                          ),

                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Required By Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _requiredBy ?? DateTime.now().add(const Duration(days: 7)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _requiredBy = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _requiredBy != null ? DateFormat('dd MMM yyyy').format(_requiredBy!) : 'Select Date',
                                          style: TextStyle(fontSize: 13, color: _requiredBy != null ? const Color(0xFF0F172A) : Colors.grey.shade400),
                                        ),
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reason / Purpose
                      _buildTextField(
                        controller: _reasonController,
                        label: 'Reason / Purpose of Request *',
                        hint: 'e.g. Required for semester project preparation and research reference',
                        maxLines: 2,
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Please provide a reason' : null,
                      ),
                      const SizedBox(height: 16),

                      // Additional Notes
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Additional Notes & Details',
                        hint: 'Any specific instructions, links, or requirements',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),

                      // Attachments Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Supporting Documents & Files',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isUploadingAttachment ? null : _pickAndUploadAttachment,
                            icon: _isUploadingAttachment
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.attach_file_rounded, size: 16),
                            label: Text(
                              _isUploadingAttachment ? 'Uploading...' : 'Attach File',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_uploadedAttachments.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.upload_file_rounded, size: 20, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Attach syllabus, requisition forms, sample covers, or references (PDF, Word, Excel, Image)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _uploadedAttachments.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final att = entry.value;
                            final fileName = att['file_name']?.toString() ?? 'Attachment';
                            final fileSize = int.tryParse(att['file_size']?.toString() ?? '0') ?? 0;
                            final color = _getFileColor(fileName);
                            final icon = _getFileIcon(fileName);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(icon, size: 18, color: color),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          _formatFileSize(fileSize),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                                    splashRadius: 14,
                                    onPressed: () {
                                      setState(() {
                                        _uploadedAttachments.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Request', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final notifier = ref.read(requestProvider.notifier);

    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : null,
      'isbn': _isbnController.text.trim().isNotEmpty ? _isbnController.text.trim() : null,
      'publisher': _publisherController.text.trim().isNotEmpty ? _publisherController.text.trim() : null,
      'edition': _editionController.text.trim().isNotEmpty ? _editionController.text.trim() : null,
      'language': _languageController.text.trim(),
      'request_type': _requestType,
      'preferred_format': _preferredFormat,
      'priority': _priority,
      'quantity': _quantity,
      'required_by': _requiredBy != null ? DateFormat('yyyy-MM-dd').format(_requiredBy!) : null,
      'reason': _reasonController.text.trim(),
      'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      if (_uploadedAttachments.isNotEmpty) 'attachments': _uploadedAttachments,
    };

    try {
      await notifier.createRequest(payload);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final sanitizedItems = items.toSet().toList();
    final sanitizedValue = sanitizedItems.contains(value) ? value : sanitizedItems.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sanitizedValue,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
              items: sanitizedItems.map((e) {
                return DropdownMenuItem<String>(
                  value: e,
                  child: Text(e.replaceAll('_', ' ')),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

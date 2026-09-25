import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class UploadDocumentDialog extends StatefulWidget {
  final VoidCallback onDocumentUploaded;
  final String? preselectedCategory;

  const UploadDocumentDialog({
    super.key,
    required this.onDocumentUploaded,
    this.preselectedCategory,
  });

  @override
  State<UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends State<UploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _ownerController = TextEditingController(text: 'HR Department');
  final _departmentController = TextEditingController(text: 'General');
  final _tagsController = TextEditingController();
  final _employeeController = TextEditingController();

  String _documentType = 'Employee Document';
  String? _selectedCategory;
  String _accessLevel = 'INSTITUTE_WIDE';

  DateTime _issueDate = DateTime.now();
  DateTime? _expiryDate;
  DateTime? _reviewDate;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // File picker state
  Uint8List? _fileBytes;
  String? _fileName;
  int _fileSize = 0;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  List<dynamic> _categories = [];

  List<String> _documentTypes = HRLookupHelper.instance.getCachedLabels('HR_DOCUMENT_TYPE');
  List<String> _accessLevels = HRLookupHelper.instance.getCachedLabels('DOCUMENT_ACCESS_LEVEL');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _selectedCategory = widget.preselectedCategory;
    _loadCategories();
    _loadLookups(true);
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final types = await HRLookupHelper.instance.getLookupLabels('HR_DOCUMENT_TYPE', forceRefresh: forceRefresh);
    final levels = await HRLookupHelper.instance.getLookupLabels('DOCUMENT_ACCESS_LEVEL', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _documentTypes = types;
        if (!_documentTypes.contains(_documentType) && _documentTypes.isNotEmpty) {
          _documentType = _documentTypes.first;
        }
        _accessLevels = levels;
        if (!_accessLevels.contains(_accessLevel) && _accessLevels.isNotEmpty) {
          _accessLevel = _accessLevels.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _nameController.dispose();
    _descController.dispose();
    _ownerController.dispose();
    _departmentController.dispose();
    _tagsController.dispose();
    _employeeController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.get('/hr/categories', useCache: true);
      if (res['success'] == true) {
        setState(() {
          _categories = res['data'] ?? [];
          if (_selectedCategory == null && _categories.isNotEmpty) {
            _selectedCategory = _categories.first['name'];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        // Validate max 25MB
        if (file.size > 25 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File exceeds 25MB limit'), backgroundColor: Colors.red),
          );
          return;
        }

        setState(() {
          _fileName = file.name;
          _fileBytes = file.bytes;
          _fileSize = file.size;
          if (_nameController.text.trim().isEmpty) {
            final nameWithoutExt = file.name.contains('.')
                ? file.name.substring(0, file.name.lastIndexOf('.'))
                : file.name;
            _nameController.text = nameWithoutExt.replaceAll('_', ' ');
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickDate(String type) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        if (type == 'issue') _issueDate = picked;
        if (type == 'expiry') _expiryDate = picked;
        if (type == 'review') _reviewDate = picked;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _normalizeAccessLevel(String val) {
    final clean = val.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
    switch (clean) {
      case 'PRIVATE':
        return 'PRIVATE';
      case 'HR_ONLY':
      case 'HR':
        return 'HR_ONLY';
      case 'MANAGEMENT':
        return 'MANAGEMENT';
      case 'DEPARTMENT':
      case 'DEPARTMENT_ONLY':
        return 'DEPARTMENT';
      case 'SELECTED_USERS':
        return 'SELECTED_USERS';
      case 'INSTITUTE_WIDE':
      default:
        return 'INSTITUTE_WIDE';
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fileBytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document file to upload'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_expiryDate != null && _expiryDate!.isBefore(_issueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry date cannot be before issue date'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.2;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var uri = Uri.parse('${AppConfig.apiBaseUrl}/hr/documents');
      var request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['document_name'] = _nameController.text.trim();
      request.fields['document_type'] = _documentType;
      request.fields['category_name'] = _selectedCategory ?? 'General';

      // Match category_id
      try {
        final matchedCat = _categories.firstWhere(
          (c) => c != null && c['name'] == _selectedCategory,
          orElse: () => null,
        );
        if (matchedCat != null && matchedCat['id'] != null) {
          request.fields['category_id'] = matchedCat['id'].toString();
        }
      } catch (_) {}

      request.fields['description'] = _descController.text.trim();
      request.fields['owner'] = _ownerController.text.trim();
      request.fields['department'] = _departmentController.text.trim();
      request.fields['access_level'] = _normalizeAccessLevel(_accessLevel);
      request.fields['issue_date'] = _dateFormat.format(_issueDate);
      request.fields['tags'] = _tagsController.text.trim();

      if (_employeeController.text.trim().isNotEmpty) {
        request.fields['linked_employee_name'] = _employeeController.text.trim();
      }
      if (_expiryDate != null) {
        request.fields['expiry_date'] = _dateFormat.format(_expiryDate!);
      }
      if (_reviewDate != null) {
        request.fields['review_date'] = _dateFormat.format(_reviewDate!);
      }

      // Attach file bytes
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _fileBytes!,
        filename: _fileName,
      ));

      setState(() => _uploadProgress = 0.6);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _uploadProgress = 1.0);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        widget.onDocumentUploaded();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        String errDetail = 'Upload failed (${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err is Map) {
            errDetail = err['detail'] ?? err['message'] ?? errDetail;
          }
        } catch (_) {
          if (response.body.isNotEmpty) errDetail = response.body;
        }
        throw Exception(errDetail);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString().replaceAll('Exception:', '').trim()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 780,
        height: 700,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload HR / Compliance Document',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Securely store institutional records, employee files, contracts and certifications.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // File Upload Drop Zone
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _fileName != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                              width: _fileName != null ? 1.5 : 1.0,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _fileName != null ? Icons.check_circle_rounded : Icons.file_upload_outlined,
                                color: _fileName != null ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fileName != null ? _fileName! : 'Click to browse or drop file here',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _fileName != null ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _fileName != null
                                    ? 'File size: ${_formatBytes(_fileSize)}'
                                    : 'Supported: PDF, DOC, DOCX, XLS, XLSX, JPG, PNG (Max 25MB)',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_isUploading) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(value: _uploadProgress, color: const Color(0xFF4F46E5)),
                      ],
                      const SizedBox(height: 20),
                      // Form Fields
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameController,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Document name required' : null,
                              decoration: InputDecoration(
                                labelText: 'Document Name *',
                                hintText: 'e.g. Employee Handbook 2026',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _documentTypes.contains(_documentType) ? _documentType : (_documentTypes.isNotEmpty ? _documentTypes.first : null),
                              decoration: InputDecoration(
                                labelText: 'Document Type *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setState(() => _documentType = v ?? _documentType),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _categories.map<DropdownMenuItem<String>>((c) {
                                return DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String));
                              }).toList(),
                              onChanged: (v) => setState(() => _selectedCategory = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _accessLevels.contains(_accessLevel) ? _accessLevel : (_accessLevels.isNotEmpty ? _accessLevels.first : null),
                              decoration: InputDecoration(
                                labelText: 'Access Level *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _accessLevels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                              onChanged: (v) => setState(() => _accessLevel = v ?? _accessLevel),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _departmentController,
                              decoration: InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _employeeController,
                              decoration: InputDecoration(
                                labelText: 'Linked Employee (Optional)',
                                hintText: 'e.g. Dr. Ramesh Kumar',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _tagsController,
                              decoration: InputDecoration(
                                labelText: 'Tags (comma-separated)',
                                hintText: 'handbook, rules, onboarding',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('issue'),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Issue Date',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                child: Text(_dateFormat.format(_issueDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('expiry'),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Expiry Date (Optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                child: Text(_expiryDate != null ? _dateFormat.format(_expiryDate!) : 'None'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('review'),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Review Date (Optional)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                child: Text(_reviewDate != null ? _dateFormat.format(_reviewDate!) : 'None'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description / Notes',
                          hintText: 'Add context or compliance remarks...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isUploading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _upload,
                    icon: _isUploading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_rounded, size: 18, color: Colors.white),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Document', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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

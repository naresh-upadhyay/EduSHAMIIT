import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../constants/app_fonts.dart';
import '../../../models/document_model.dart';

// ============================================================================
// 1. UPLOAD DOCUMENT DIALOG
// ============================================================================

class DocumentUploadDialog extends StatefulWidget {
  final List<FolderModel> folders;
  final String? initialFolderId;
  final Future<bool> Function({
    required List<int> bytes,
    required String filename,
    required String title,
    String description,
    String category,
    String? folderId,
    String department,
    String tags,
    bool approvalRequired,
    String? expiryDate,
  }) onUpload;

  const DocumentUploadDialog({
    super.key,
    required this.folders,
    this.initialFolderId,
    required this.onUpload,
  });

  @override
  State<DocumentUploadDialog> createState() => _DocumentUploadDialogState();
}

class _DocumentUploadDialogState extends State<DocumentUploadDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();

  PlatformFile? _pickedFile;
  String _category = 'academic';
  String? _selectedFolderId;
  String _department = 'Academics';
  bool _approvalRequired = false;
  DateTime? _expiryDate;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.initialFolderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'txt', 'csv'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final f = result.files.first;
        setState(() {
          _pickedFile = f;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
          }
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'File selection error: $e');
    }
  }

  Future<void> _submit() async {
    if (_pickedFile == null || _pickedFile!.bytes == null) {
      setState(() => _error = 'Please select a file to upload');
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a document title');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    final success = await widget.onUpload(
      bytes: _pickedFile!.bytes!,
      filename: _pickedFile!.name,
      title: title,
      description: _descController.text.trim(),
      category: _category,
      folderId: _selectedFolderId,
      department: _department,
      tags: _tagsController.text.trim(),
      approvalRequired: _approvalRequired,
      expiryDate: _expiryDate?.toIso8601String().split('T').first,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Upload Document',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],

              // Drop Zone / File Picker Box
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _pickedFile != null ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _pickedFile != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                        size: 36,
                        color: _pickedFile != null ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFile != null ? _pickedFile!.name : 'Click to browse or drag file here',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _pickedFile != null
                            ? '${(_pickedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB'
                            : 'Supported: PDF, DOCX, XLSX, PPTX, JPG, PNG, CSV, TXT (Max 50 MB)',
                        style: const TextStyle(fontFamily: AppFonts.body, fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title Field
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Document Title *',
                  hintText: 'e.g. Annual Academic Calendar 2025-26',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Description Field
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Provide context or summary for this document',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Row: Category & Folder
              LayoutBuilder(
                builder: (context, box) {
                  final isTight = box.maxWidth < 450;

                  final catField = DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'academic', child: Text('Academic', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'administration', child: Text('Administration', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'student_records', child: Text('Student Related', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'finance', child: Text('Fee & Accounts', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'library', child: Text('Library', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'transport', child: Text('Transport', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'policies', child: Text('Policies', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'others', child: Text('Others', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setState(() => _category = val ?? 'academic'),
                  );

                  final folderField = DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _selectedFolderId,
                    decoration: const InputDecoration(
                      labelText: 'Folder Location',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('📁 Root Directory', overflow: TextOverflow.ellipsis)),
                      ...widget.folders.map(
                        (f) => DropdownMenuItem(value: f.id, child: Text('📁 ${f.name}', overflow: TextOverflow.ellipsis)),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedFolderId = val),
                  );

                  if (isTight) {
                    return Column(
                      children: [
                        catField,
                        const SizedBox(height: 12),
                        folderField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: catField),
                      const SizedBox(width: 12),
                      Expanded(child: folderField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Row: Department & Tags
              LayoutBuilder(
                builder: (context, box) {
                  final isTight = box.maxWidth < 450;

                  final deptField = DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _department,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Academics', child: Text('Academics', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Administration', child: Text('Administration', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Finance', child: Text('Finance & Accounts', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'HR Management', child: Text('HR Management', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'Examination', child: Text('Examination', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'All', child: Text('All Departments', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) => setState(() => _department = val ?? 'Academics'),
                  );

                  final tagsField = TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags (comma separated)',
                      hintText: 'curriculum, term1, urgent',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  );

                  if (isTight) {
                    return Column(
                      children: [
                        deptField,
                        const SizedBox(height: 12),
                        tagsField,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: deptField),
                      const SizedBox(width: 12),
                      Expanded(child: tagsField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Approval Toggle & Expiry
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Require Approval', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Route to administrator review before publishing', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      value: _approvalRequired,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (val) => setState(() => _approvalRequired = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(_expiryDate != null ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}' : 'Set Expiry Date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: _isUploading ? null : _submit,
                    child: _isUploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.w700)),
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

// ============================================================================
// 2. CREATE FOLDER DIALOG
// ============================================================================

class CreateFolderDialog extends StatefulWidget {
  final List<FolderModel> folders;
  final String? initialParentId;
  final Future<bool> Function({
    required String name,
    String? description,
    String? parentId,
    String category,
    String color,
    String icon,
  }) onCreate;

  const CreateFolderDialog({
    super.key,
    required this.folders,
    this.initialParentId,
    required this.onCreate,
  });

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _parentId;
  final String _category = 'Academic';
  String _color = '#2563EB';
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _parentId = widget.initialParentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a folder name');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    final success = await widget.onCreate(
      name: name,
      description: _descController.text.trim(),
      parentId: _parentId,
      category: _category,
      color: _color,
      icon: 'folder',
    );

    if (mounted) {
      setState(() {
        _isCreating = false;
        if (!success) {
          _error = 'Failed to create folder. A folder with this name may already exist in this location.';
        }
      });
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.create_new_folder_rounded, color: Color(0xFF2563EB), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Create New Folder',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
              ),
              const SizedBox(height: 12),
            ],

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name *',
                hintText: 'e.g. Science Lab Manuals',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _parentId,
              decoration: const InputDecoration(labelText: 'Parent Folder', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('📁 Root Directory', overflow: TextOverflow.ellipsis)),
                ...widget.folders.map((f) => DropdownMenuItem(value: f.id, child: Text('📁 ${f.name}', overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (val) => setState(() => _parentId = val),
            ),
            const SizedBox(height: 12),

            // Color Palette Selector
            Row(
              children: [
                const Text('Color Accent: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ...['#2563EB', '#059669', '#7C3AED', '#EA580C', '#D97706', '#64748B'].map((cHex) {
                  final hex = cHex.replaceAll('#', '');
                  final col = Color(int.parse('FF$hex', radix: 16));
                  final isSelected = _color == cHex;
                  return GestureDetector(
                    onTap: () => setState(() => _color = cHex),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.black : Colors.transparent, width: 2),
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                  );
                }),
              ],
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: _isCreating ? null : _submit,
                  child: _isCreating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Create Folder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. SHARE DOCUMENT DIALOG
// ============================================================================

class ShareDocumentDialog extends StatefulWidget {
  final DocumentModel document;
  final List<DocumentShareModel> currentShares;
  final Future<List<Map<String, dynamic>>> Function(String query)? onSearchUsers;
  final Future<bool> Function({
    required String docId,
    required String shareType,
    String? targetId,
    String? targetName,
    String permissionLevel,
    bool allowDownload,
    bool allowPrint,
    String? expiryDate,
    String? message,
  }) onShare;
  final Future<bool> Function(String shareId, String docId) onRevoke;

  const ShareDocumentDialog({
    super.key,
    required this.document,
    required this.currentShares,
    this.onSearchUsers,
    required this.onShare,
    required this.onRevoke,
  });

  @override
  State<ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends State<ShareDocumentDialog> {
  final _searchController = TextEditingController();
  final _msgController = TextEditingController();
  String _shareType = 'user'; // user, role, department, class
  String _permissionLevel = 'Viewer'; // Viewer, Commenter, Editor, Manager
  bool _allowDownload = true;
  bool _isSharing = false;
  bool _isSearchingUsers = false;

  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userSearchResults = [];

  String _selectedRole = 'Teacher';
  String _selectedDepartment = 'Academics';
  String _selectedClass = 'Class 10-A';

  late List<DocumentShareModel> _sharesList;

  static const _availableRoles = [
    'Teacher',
    'Student',
    'Parent',
    'Staff',
    'Admin',
    'Super Admin',
    'Accountant',
    'Principal',
    'Librarian',
    'Transport Manager',
    'Hostel Warden',
  ];

  static const _availableDepartments = [
    'Academics',
    'Administration',
    'Finance',
    'Examination',
    'HR Management',
    'Hostel',
    'Transport',
    'Library',
    'Science',
    'Sports',
  ];

  static const _availableClasses = [
    'Class 1-A',
    'Class 2-A',
    'Class 3-A',
    'Class 4-A',
    'Class 5-A',
    'Class 6-A',
    'Class 7-A',
    'Class 8-A',
    'Class 9-A',
    'Class 10-A',
    'Class 10-B',
    'Class 11-A',
    'Class 11-B',
    'Class 12-A',
    'Class 12-B',
    'All Classes',
  ];

  @override
  void initState() {
    super.initState();
    _sharesList = List.from(widget.currentShares);
    _performUserSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _performUserSearch(String q) async {
    if (widget.onSearchUsers == null) return;
    setState(() => _isSearchingUsers = true);
    try {
      final results = await widget.onSearchUsers!(q);
      if (mounted) {
        setState(() {
          _userSearchResults = results;
          _isSearchingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingUsers = false);
    }
  }

  Future<void> _share() async {
    String? targetId;
    String? targetName;

    if (_shareType == 'user') {
      if (_selectedUser != null) {
        targetId = _selectedUser!['id']?.toString();
        targetName = _selectedUser!['full_name']?.toString() ?? _selectedUser!['email']?.toString();
      } else if (_searchController.text.trim().isNotEmpty) {
        targetId = _searchController.text.trim();
        targetName = _searchController.text.trim();
      } else {
        return;
      }
    } else if (_shareType == 'role') {
      targetId = _selectedRole;
      targetName = _selectedRole;
    } else if (_shareType == 'department') {
      targetId = _selectedDepartment;
      targetName = _selectedDepartment;
    } else if (_shareType == 'class') {
      targetId = _selectedClass;
      targetName = _selectedClass;
    }

    if (targetId == null || targetId.isEmpty) return;

    setState(() => _isSharing = true);
    final success = await widget.onShare(
      docId: widget.document.id,
      shareType: _shareType,
      targetId: targetId,
      targetName: targetName,
      permissionLevel: _permissionLevel,
      allowDownload: _allowDownload,
      message: _msgController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSharing = false;
        if (success) {
          _sharesList.insert(
            0,
            DocumentShareModel(
              id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
              documentId: widget.document.id,
              shareType: _shareType,
              targetId: targetId,
              targetName: targetName,
              permissionLevel: _permissionLevel,
              allowDownload: _allowDownload,
              createdAt: DateTime.now(),
            ),
          );
          _selectedUser = null;
          _searchController.clear();
          _msgController.clear();
        }
      });
    }
  }

  Future<void> _revokeShare(String shareId) async {
    final success = await widget.onRevoke(shareId, widget.document.id);
    if (success && mounted) {
      setState(() {
        _sharesList.removeWhere((s) => s.id == shareId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Share "${widget.document.title}"',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Share Type Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTypeChip('user', 'Individual User', Icons.person_outline_rounded, isDark),
                    const SizedBox(width: 8),
                    _buildTypeChip('role', 'By Role', Icons.badge_outlined, isDark),
                    const SizedBox(width: 8),
                    _buildTypeChip('department', 'Department', Icons.business_outlined, isDark),
                    const SizedBox(width: 8),
                    _buildTypeChip('class', 'Class/Section', Icons.school_outlined, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Target Selector depending on Share Type
              if (_shareType == 'user') ...[
                if (_selectedUser != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            (_selectedUser!['full_name'] as String? ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedUser!['full_name'] as String? ?? 'User',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                              ),
                              Text(
                                '${_selectedUser!['role'] ?? 'User'} • ${_selectedUser!['email'] ?? ''}',
                                style: TextStyle(fontSize: 11, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Deselect',
                          onPressed: () => setState(() => _selectedUser = null),
                        ),
                      ],
                    ),
                  )
                else ...[
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => _performUserSearch(val),
                    decoration: InputDecoration(
                      labelText: 'Search user by Name or Email',
                      hintText: 'Type to search real application users...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _isSearchingUsers
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                    ),
                    style: TextStyle(fontFamily: AppFonts.body, fontSize: 13, color: textPrimary),
                  ),
                  if (_userSearchResults.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderCol),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _userSearchResults.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: borderCol),
                        itemBuilder: (ctx, idx) {
                          final u = _userSearchResults[idx];
                          final name = u['full_name'] as String? ?? 'User';
                          final email = u['email'] as String? ?? '';
                          final role = u['role'] as String? ?? 'User';

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF2563EB),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: textPrimary)),
                            subtitle: Text('$role • $email', style: TextStyle(fontSize: 10.5, color: textMuted)),
                            onTap: () {
                              setState(() {
                                _selectedUser = u;
                                _searchController.text = name;
                                _userSearchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ] else if (_shareType == 'role') ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Select Role to Share With',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                  ),
                  dropdownColor: cardBg,
                  items: _availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(color: textPrimary)))).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val ?? 'Teacher'),
                ),
              ] else if (_shareType == 'department') ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedDepartment,
                  decoration: InputDecoration(
                    labelText: 'Select Department to Share With',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                  ),
                  dropdownColor: cardBg,
                  items: _availableDepartments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: textPrimary)))).toList(),
                  onChanged: (val) => setState(() => _selectedDepartment = val ?? 'Academics'),
                ),
              ] else if (_shareType == 'class') ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedClass,
                  decoration: InputDecoration(
                    labelText: 'Select Class/Section to Share With',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                  ),
                  dropdownColor: cardBg,
                  items: _availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: textPrimary)))).toList(),
                  onChanged: (val) => setState(() => _selectedClass = val ?? 'Class 10-A'),
                ),
              ],

              const SizedBox(height: 14),

              // Access Level & Permissions
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _permissionLevel,
                      decoration: InputDecoration(
                        labelText: 'Access Level',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      dropdownColor: cardBg,
                      items: const [
                        DropdownMenuItem(value: 'Viewer', child: Text('Viewer (View only)')),
                        DropdownMenuItem(value: 'Commenter', child: Text('Commenter (View & notes)')),
                        DropdownMenuItem(value: 'Editor', child: Text('Editor (Edit & update)')),
                        DropdownMenuItem(value: 'Manager', child: Text('Manager (Full access)')),
                      ],
                      onChanged: (val) => setState(() => _permissionLevel = val ?? 'Viewer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Download Permission Checkbox
              Row(
                children: [
                  Checkbox(
                    value: _allowDownload,
                    onChanged: (v) => setState(() => _allowDownload = v ?? true),
                    activeColor: const Color(0xFF2563EB),
                  ),
                  Expanded(
                    child: Text('Allow recipients to download this file', style: TextStyle(fontSize: 12, color: textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Send Share Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSharing ? null : _share,
                icon: _isSharing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isSharing ? 'Sharing...' : 'Send Share Invitation'),
              ),

              const SizedBox(height: 18),
              Divider(color: borderCol),
              Text(
                'Current Shares (${_sharesList.length})',
                style: TextStyle(fontFamily: AppFonts.heading, fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const SizedBox(height: 8),

              if (_sharesList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('This document is not currently shared with anyone.', style: TextStyle(color: textMuted, fontSize: 11)),
                )
              else
                ..._sharesList.map((s) {
                  IconData sIcon = Icons.person_rounded;
                  if (s.shareType == 'role') sIcon = Icons.badge_rounded;
                  if (s.shareType == 'department') sIcon = Icons.business_rounded;
                  if (s.shareType == 'class') sIcon = Icons.school_rounded;

                  Color badgeCol = const Color(0xFF2563EB);
                  if (s.permissionLevel == 'Editor') badgeCol = const Color(0xFF059669);
                  if (s.permissionLevel == 'Manager') badgeCol = const Color(0xFF7C3AED);

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: badgeCol.withValues(alpha: 0.15),
                      child: Icon(sIcon, size: 16, color: badgeCol),
                    ),
                    title: Text(
                      s.targetName ?? s.targetId ?? 'Recipient',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textPrimary),
                    ),
                    subtitle: Text(
                      '${s.permissionLevel} • ${s.shareType.toUpperCase()}${s.allowDownload ? "" : " • Download restricted"}',
                      style: TextStyle(fontSize: 10.5, color: textMuted),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                      tooltip: 'Revoke Access',
                      onPressed: () => _revokeShare(s.id),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, bool isDark) {
    final isSelected = _shareType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF2563EB)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      onSelected: (s) => setState(() => _shareType = type),
    );
  }
}

// ============================================================================
// 4. VERSION HISTORY DIALOG
// ============================================================================

class VersionHistoryDialog extends StatefulWidget {
  final DocumentModel document;
  final List<DocumentVersionModel> versions;
  final Future<bool> Function({required String docId, required List<int> bytes, required String filename, String changeSummary}) onUploadVersion;
  final Future<bool> Function(String docId, String versionId) onRestoreVersion;

  const VersionHistoryDialog({
    super.key,
    required this.document,
    required this.versions,
    required this.onUploadVersion,
    required this.onRestoreVersion,
  });

  @override
  State<VersionHistoryDialog> createState() => _VersionHistoryDialogState();
}

class _VersionHistoryDialogState extends State<VersionHistoryDialog> {
  bool _isUploading = false;

  Future<void> _uploadNewVersion() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      setState(() => _isUploading = true);
      await widget.onUploadVersion(
        docId: widget.document.id,
        bytes: f.bytes!,
        filename: f.name,
        changeSummary: 'Updated replacement file',
      );
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Text(
                      'Version History — ${widget.document.title}',
                      style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${widget.versions.length} versions recorded', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: _isUploading ? null : _uploadNewVersion,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Upload New Version'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.versions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final v = widget.versions[idx];
                  final isCurrent = idx == 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      foregroundColor: isCurrent ? Colors.white : const Color(0xFF0F172A),
                      radius: 16,
                      child: Text('v${v.versionNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    title: Row(
                      children: [
                        Text(v.fileName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Current', style: TextStyle(color: Color(0xFF16A34A), fontSize: 9.5, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${v.fileSizeLabel} • Uploaded by ${v.uploaderName} • ${v.createdAt.day}/${v.createdAt.month}/${v.createdAt.year}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: isCurrent
                        ? null
                        : TextButton(
                            onPressed: () => widget.onRestoreVersion(widget.document.id, v.id),
                            child: const Text('Restore', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. DOCUMENT REQUEST DIALOG
// ============================================================================

class DocumentRequestDialog extends StatefulWidget {
  final Future<bool> Function({required String title, String? description, String category, String priority, String? requiredByDate}) onSubmit;

  const DocumentRequestDialog({super.key, required this.onSubmit});

  @override
  State<DocumentRequestDialog> createState() => _DocumentRequestDialogState();
}

class _DocumentRequestDialogState extends State<DocumentRequestDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'Academic';
  String _priority = 'Medium';
  DateTime? _requiredByDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    final success = await widget.onSubmit(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      priority: _priority,
      requiredByDate: _requiredByDate?.toIso8601String().split('T').first,
    );
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF2563EB)),
                    SizedBox(width: 10),
                    Text('Request a Document', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Request Title *', hintText: 'e.g. Request Transfer Certificate', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Purpose / Remarks', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                      DropdownMenuItem(value: 'Finance', child: Text('Fee Receipt')),
                      DropdownMenuItem(value: 'Student Records', child: Text('Student Records')),
                      DropdownMenuItem(value: 'General', child: Text('General')),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'Academic'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                      DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: _isSubmitting ? null : _submit,
                  child: const Text('Submit Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. BULK ACTION BAR
// ============================================================================

class BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onBulkMove;
  final VoidCallback onBulkStar;
  final VoidCallback onBulkDownload;
  final VoidCallback onBulkTrash;
  final VoidCallback onClear;
  final bool isTrashTab;
  final VoidCallback? onBulkRestore;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onBulkMove,
    required this.onBulkStar,
    required this.onBulkDownload,
    required this.onBulkTrash,
    required this.onClear,
    this.isTrashTab = false,
    this.onBulkRestore,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isTrashTab ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$selectedCount Selected',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),

            if (isTrashTab) ...[
              if (onBulkRestore != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.25),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.restore_from_trash_rounded, size: 16, color: Color(0xFF4ADE80)),
                  label: const Text('Restore Selected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  onPressed: onBulkRestore,
                ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
                icon: const Icon(Icons.delete_forever_rounded, size: 16),
                label: const Text('Delete Permanently', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: onBulkTrash,
              ),
            ] else ...[
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                label: const Text('Move', style: TextStyle(fontSize: 12)),
                onPressed: onBulkMove,
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.star_outline_rounded, size: 16),
                label: const Text('Star', style: TextStyle(fontSize: 12)),
                onPressed: onBulkStar,
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.archive_outlined, size: 16, color: Color(0xFF93C5FD)),
                label: const Text('Download ZIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                onPressed: onBulkDownload,
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Move to Trash', style: TextStyle(fontSize: 12)),
                onPressed: onBulkTrash,
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              tooltip: 'Clear Selection',
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 7. DOCUMENT REQUESTS MANAGEMENT DIALOG (REVIEW & FULFILL)
// ============================================================================

class DocumentRequestsManagerDialog extends StatefulWidget {
  final List<DocumentRequestModel> requests;
  final List<DocumentModel> availableDocuments;
  final Future<void> Function({String? status}) onRefresh;
  final Future<bool> Function(String requestId, {required String status, String? responseNotes}) onUpdateStatus;
  final Future<bool> Function(String requestId, {required String documentId, String? responseNotes}) onFulfill;
  final bool isDark;

  const DocumentRequestsManagerDialog({
    super.key,
    required this.requests,
    required this.availableDocuments,
    required this.onRefresh,
    required this.onUpdateStatus,
    required this.onFulfill,
    this.isDark = false,
  });

  @override
  State<DocumentRequestsManagerDialog> createState() => _DocumentRequestsManagerDialogState();
}

class _DocumentRequestsManagerDialogState extends State<DocumentRequestsManagerDialog> {
  String _selectedStatusFilter = 'All';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await widget.onRefresh(status: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter);
    if (mounted) setState(() => _isLoading = false);
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent': return const Color(0xFFDC2626);
      case 'high': return const Color(0xFFEA580C);
      case 'medium': return const Color(0xFF2563EB);
      default: return const Color(0xFF64748B);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'fulfilled': return const Color(0xFF16A34A);
      case 'in progress': return const Color(0xFF2563EB);
      case 'rejected': return const Color(0xFFDC2626);
      default: return const Color(0xFFD97706);
    }
  }

  void _showStatusDialog(DocumentRequestModel req) {
    String currentStatus = req.status;
    final notesController = TextEditingController(text: req.responseNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Update Request Status', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request: ${req.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: currentStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'Fulfilled', child: Text('Fulfilled')),
                  DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => currentStatus = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Response Notes (Optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.onUpdateStatus(req.id, status: currentStatus, responseNotes: notesController.text.trim());
                await _refresh();
              },
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFulfillDialog(DocumentRequestModel req) {
    String? selectedDocId = widget.availableDocuments.isNotEmpty ? widget.availableDocuments.first.id : null;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Fulfill Document Request', style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fulfill: ${req.title} for ${req.requesterName ?? "User"}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (widget.availableDocuments.isEmpty)
                const Text('No uploaded documents available to link. Please upload the requested file first.', style: TextStyle(color: Colors.red))
              else
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedDocId,
                  decoration: const InputDecoration(labelText: 'Select Institutional Document', border: OutlineInputBorder()),
                  items: widget.availableDocuments.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(
                        '${doc.title} (${doc.fileType})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDocId = val);
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Fulfillment Note (Optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
              onPressed: selectedDocId == null
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await widget.onFulfill(req.id, documentId: selectedDocId!, responseNotes: notesController.text.trim());
                      await _refresh();
                    },
              child: const Text('Fulfill Request'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filteredRequests = _selectedStatusFilter == 'All'
        ? widget.requests
        : widget.requests.where((r) => r.status.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 780,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document Requests Review & Fulfillment',
                        style: TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.w800, color: textPrimary),
                      ),
                      Text(
                        'Review requests submitted across departments and fulfill them with institutional files.',
                        style: TextStyle(fontFamily: AppFonts.body, fontSize: 11.5, color: textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: textMuted),
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textMuted),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: borderCol),
            const SizedBox(height: 12),

            // Filter Tabs
            Row(
              children: ['All', 'Pending', 'In Progress', 'Fulfilled', 'Rejected'].map((status) {
                final isSelected = _selectedStatusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : textPrimary),
                    backgroundColor: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedStatusFilter = status);
                        _refresh();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // List of Requests
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : filteredRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_rounded, size: 48, color: textMuted),
                              const SizedBox(height: 8),
                              Text('No requests found for $_selectedStatusFilter status', style: TextStyle(fontWeight: FontWeight.w600, color: textMuted)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final req = filteredRequests[idx];
                            final priorityCol = _getPriorityColor(req.priority);
                            final statusCol = _getStatusColor(req.status);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderCol),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left icon
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: priorityCol.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.description_outlined, color: priorityCol, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              req.title,
                                              style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w700, fontSize: 13, color: textPrimary),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: priorityCol.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                req.priority.toUpperCase(),
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: priorityCol),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: statusCol.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                req.status,
                                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusCol),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Requested by: ${req.requesterName ?? "User"} • Category: ${req.category}',
                                          style: TextStyle(fontFamily: AppFonts.body, fontSize: 11.5, color: textMuted),
                                        ),
                                        if (req.description != null && req.description!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            req.description!,
                                            style: TextStyle(fontFamily: AppFonts.body, fontSize: 11, color: textPrimary),
                                          ),
                                        ],
                                        if (req.fulfilledDocumentId != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Fulfilled with Doc ID: ${req.fulfilledDocumentId}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Action buttons
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          side: BorderSide(color: borderCol),
                                        ),
                                        onPressed: () => _showStatusDialog(req),
                                        child: const Text('Change Status', style: TextStyle(fontSize: 11)),
                                      ),
                                      if (req.status != 'Fulfilled') ...[
                                        const SizedBox(height: 4),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: () => _showFulfillDialog(req),
                                          child: const Text('Fulfill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

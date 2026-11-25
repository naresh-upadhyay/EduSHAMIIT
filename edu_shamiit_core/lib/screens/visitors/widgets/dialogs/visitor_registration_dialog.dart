import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../../utils/visitor_avatar_helper.dart';

class AttachedVisitorDoc {
  String? id;
  final TextEditingController typeController;
  final TextEditingController nameController;
  String? url;
  Uint8List? bytes;
  int size;

  AttachedVisitorDoc({
    this.id,
    required String type,
    required String name,
    this.url,
    this.bytes,
    this.size = 0,
  })  : typeController = TextEditingController(text: type),
        nameController = TextEditingController(text: name);

  void dispose() {
    typeController.dispose();
    nameController.dispose();
  }

  Map<String, dynamic> toJson() {
    String fileData = url ?? '';
    if (bytes != null && bytes!.isNotEmpty) {
      final b64 = base64Encode(bytes!);
      fileData = 'data:application/octet-stream;base64,$b64';
    }
    return {
      if (id != null) 'id': id,
      'document_name': nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'Document',
      'document_type': typeController.text.trim().isNotEmpty ? typeController.text.trim() : 'ID Proof',
      'file_url': fileData.isNotEmpty ? fileData : 'https://example.com/docs/${nameController.text.trim()}',
      'file_size_bytes': size > 0 ? size : (bytes?.length ?? 1024),
      'verification_status': 'VERIFIED',
    };
  }
}

class VisitorRegistrationDialog extends ConsumerStatefulWidget {
  final VisitorItem? existingVisit;
  final bool initialInstantCheckIn;

  const VisitorRegistrationDialog({
    super.key,
    this.existingVisit,
    this.initialInstantCheckIn = true,
  });

  @override
  ConsumerState<VisitorRegistrationDialog> createState() => _VisitorRegistrationDialogState();
}

class _VisitorRegistrationDialogState extends ConsumerState<VisitorRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _idNumberController = TextEditingController(text: 'XXXX-XXXX-1234');
  final _purposeController = TextEditingController(text: 'Meet Student');
  final _hostController = TextEditingController(text: 'Rahul Sharma (Class 10 A)');
  final _vehicleController = TextEditingController();
  final _accompanyingController = TextEditingController(text: '0');
  final _remarksController = TextEditingController();

  final List<AttachedVisitorDoc> _documents = [];

  String _visitorType = 'Parent';
  String _idType = 'Aadhaar Card';
  String _destination = 'Main Gate';
  bool _autoCheckIn = true;
  bool _isSubmitting = false;
  String? _existingVisitorInfo;
  InstantRestrictionResult? _instantRestriction;

  // Photo state
  Uint8List? _capturedPhotoBytes;
  String? _capturedPhotoName;
  String? _existingPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  bool get _hasPhoto => _capturedPhotoBytes != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);

  ImageProvider? _getPreviewProvider() {
    if (_capturedPhotoBytes != null) {
      return MemoryImage(_capturedPhotoBytes!);
    }
    if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return getVisitorImageProvider(_existingPhotoUrl);
    }
    return null;
  }

  static const List<String> _types = [
    'Parent', 'Official', 'Vendor', 'Relative', 'Delivery', 'Maintenance', 'Alumni', 'Guest'
  ];

  static const List<String> _idTypes = [
    'Aadhaar Card', 'PAN Card', 'Driving License', 'Voter ID', 'Passport', 'Employee ID', 'Other'
  ];

  static const List<String> _destinations = [
    'Main Gate', 'Reception Desk', 'Library', 'Science Lab', 'Boys Hostel', 'Girls Hostel', 'Auditorium', 'Admin Office', 'Principal Office'
  ];

  @override
  void initState() {
    super.initState();
    _autoCheckIn = widget.initialInstantCheckIn;
    if (widget.existingVisit != null) {
      final v = widget.existingVisit!;
      _nameController.text = v.visitorName;
      _phoneController.text = v.phone;
      _visitorType = v.visitorType;
      _purposeController.text = v.purpose;
      _destination = v.location;
      _hostController.text = v.hostName;
      if (v.vehicleNumber != null) {
        _vehicleController.text = v.vehicleNumber!;
      }
      if (v.remarks != null) {
        _remarksController.text = v.remarks!;
      }
      if (v.photoUrl != null && v.photoUrl!.isNotEmpty) {
        _existingPhotoUrl = v.photoUrl;
        _capturedPhotoName = 'Current photo';
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.existingVisit != null && mounted) {
        final detail = ref.read(visitorsProvider).selectedDetail;
        if (detail != null) {
          setState(() {
            if (detail.email.isNotEmpty && detail.email != 'rajesh@gmail.com' && _emailController.text.isEmpty) {
              _emailController.text = detail.email;
            }
            if (detail.visitor['company'] != null && _companyController.text.isEmpty) {
              _companyController.text = detail.visitor['company'].toString();
            }
            if (detail.idType.isNotEmpty) {
              _idType = detail.idType;
            }
            if (detail.idNumberMasked.isNotEmpty && _idNumberController.text == 'XXXX-XXXX-1234') {
              _idNumberController.text = detail.idNumberMasked;
            }
            if (detail.photoUrl != null && detail.photoUrl!.isNotEmpty && _capturedPhotoBytes == null) {
              _existingPhotoUrl = detail.photoUrl;
              _capturedPhotoName = 'Current photo';
            }
            if (detail.documents.isNotEmpty && _documents.isEmpty) {
              for (final d in detail.documents) {
                _documents.add(AttachedVisitorDoc(
                  id: d['id']?.toString(),
                  type: d['document_type']?.toString() ?? 'Adhar',
                  name: d['document_name']?.toString() ?? 'Document',
                  url: d['file_url']?.toString(),
                  size: (d['file_size_bytes'] as num?)?.toInt() ?? 0,
                ));
              }
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    for (final doc in _documents) {
      doc.dispose();
    }
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _idNumberController.dispose();
    _purposeController.dispose();
    _hostController.dispose();
    _vehicleController.dispose();
    _accompanyingController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _addDocumentWithPicker({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() {
          _documents.add(AttachedVisitorDoc(
            type: 'Adhar',
            name: file.name,
            bytes: bytes,
            size: bytes.length,
          ));
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _documents.add(AttachedVisitorDoc(
            type: 'Adhar',
            name: 'Document_${_documents.length + 1}.pdf',
            size: 1024,
          ));
        });
      }
    }
  }

  Future<void> _pickFileForDoc(AttachedVisitorDoc doc) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() {
          doc.bytes = bytes;
          doc.nameController.text = file.name;
          doc.size = bytes.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedPhotoBytes = bytes;
          _capturedPhotoName = photo.name;
        });
      }
    } catch (e) {
      // Camera not available (e.g. desktop/web without camera), fall back to gallery
      if (mounted) {
        _pickFromGallery();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedPhotoBytes = bytes;
          _capturedPhotoName = photo.name;
        });
      }
    } catch (_) {}
  }

  void _removePhoto() {
    setState(() {
      _capturedPhotoBytes = null;
      _capturedPhotoName = null;
      _existingPhotoUrl = null;
    });
  }

  Future<void> _checkExistingPhone(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.length >= 10) {
      final notifier = ref.read(visitorsProvider.notifier);
      final res = await notifier.checkInstantRestriction(
        phone: cleanPhone,
        idNumber: _idNumberController.text.trim() != 'XXXX-XXXX-1234' ? _idNumberController.text.trim() : null,
      );
      if (mounted) {
        setState(() {
          _instantRestriction = res;
          if (res.profile != null) {
            final match = res.profile!;
            _existingVisitorInfo = 'Returning visitor detected: ${match.fullName} (${match.visitorType})';
            if (_nameController.text.isEmpty && match.fullName.isNotEmpty) {
              _nameController.text = match.fullName;
            }
            if (_emailController.text.isEmpty && match.email != null) {
              _emailController.text = match.email!;
            }
            if (_companyController.text.isEmpty && match.company != null) {
              _companyController.text = match.company!;
            }
            if (match.idType.isNotEmpty) {
              _idType = match.idType;
            }
            if (match.idNumberMasked.isNotEmpty) {
              _idNumberController.text = match.idNumberMasked;
            }
            if (match.photoUrl != null && match.photoUrl!.isNotEmpty && _capturedPhotoBytes == null) {
              _existingPhotoUrl = match.photoUrl;
              _capturedPhotoName = 'Profile photo synchronized';
            }
          } else {
            if (_existingVisitorInfo != null) {
              _existingVisitorInfo = null;
            }
          }
        });
      }
    } else {
      if (_instantRestriction != null || _existingVisitorInfo != null) {
        setState(() {
          _instantRestriction = null;
          _existingVisitorInfo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 680.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 24,
        vertical: isNarrow ? 12 : 24,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Modal Header
            Padding(
              padding: EdgeInsets.fromLTRB(isNarrow ? 16 : 24, isNarrow ? 14 : 20, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.existingVisit != null ? 'Edit Visitor' : 'Register Visitor',
                      style: TextStyle(
                        fontSize: isNarrow ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isNarrow ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_instantRestriction != null && _instantRestriction!.isRestricted)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.security, color: Color(0xFFDC2626), size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SECURITY RESTRICTION ACTIVE (${_instantRestriction!.restrictionType.toUpperCase()})',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _instantRestriction!.restrictionReason.isNotEmpty
                                          ? _instantRestriction!.restrictionReason
                                          : 'Visitor has an active security blacklist or temporary restriction on record. Supervisor override required.',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_existingVisitorInfo != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _existingVisitorInfo!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ============================================
                      // PHOTO CAPTURE SECTION
                      // ============================================
                      _buildSectionTitle('Visitor Photo', isDark),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Photo Preview / Placeholder
                            GestureDetector(
                              onTap: _capturePhoto,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _hasPhoto
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                    width: _hasPhoto ? 2 : 1,
                                  ),
                                  image: _getPreviewProvider() != null
                                      ? DecorationImage(
                                          image: _getPreviewProvider()!,
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _getPreviewProvider() == null
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt_rounded,
                                            size: 28,
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Photo',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Action Buttons
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _hasPhoto
                                        ? 'Photo attached successfully'
                                        : 'Capture or upload visitor\'s photo for identification',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _hasPhoto
                                          ? const Color(0xFF16A34A)
                                          : (isDark ? Colors.white : const Color(0xFF334155)),
                                    ),
                                  ),
                                  if (_capturedPhotoName != null)
                                    Text(
                                      _capturedPhotoName!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _buildPhotoButton(
                                        icon: Icons.camera_alt_rounded,
                                        label: 'Capture',
                                        color: const Color(0xFF2563EB),
                                        onTap: _capturePhoto,
                                        isDark: isDark,
                                      ),
                                      _buildPhotoButton(
                                        icon: Icons.photo_library_outlined,
                                        label: 'Upload',
                                        color: const Color(0xFF7C3AED),
                                        onTap: _pickFromGallery,
                                        isDark: isDark,
                                      ),
                                      if (_hasPhoto)
                                        _buildPhotoButton(
                                          icon: Icons.delete_outline,
                                          label: 'Remove',
                                          color: const Color(0xFFDC2626),
                                          onTap: _removePhoto,
                                          isDark: isDark,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Section 1: Visitor Identity
                      _buildSectionTitle('Visitor Identity', isDark),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name *',
                            hint: 'e.g. Mr. Rajesh Kumar',
                            isDark: isDark,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Contact Number *',
                            hint: '+91 98765 43210',
                            isDark: isDark,
                            onChanged: _checkExistingPhone,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Phone required' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email (Optional)',
                            hint: 'visitor@example.com',
                            isDark: isDark,
                          ),
                          _buildDropdownField(
                            label: 'Visitor Type',
                            value: _visitorType,
                            items: _types,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) setState(() => _visitorType = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildDropdownField(
                            label: 'ID Proof Type',
                            value: _idType,
                            items: _idTypes,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) setState(() => _idType = val);
                            },
                          ),
                          _buildTextField(
                            controller: _idNumberController,
                            label: 'ID Number (Masked)',
                            hint: 'XXXX-XXXX-1234',
                            isDark: isDark,
                          ),
                        ],
                      ),

                      // ============================================
                      // DOCUMENT ATTACHMENTS (Multi-attachment with custom types)
                      // ============================================
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildSectionTitle('Identity & Verification Documents', isDark),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                            label: const Text('Add Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _addDocumentWithPicker(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload identity proofs (e.g. Adhar, PAN, Driving License, RC). You can type any custom document type.',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      if (_documents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.file_present_outlined, color: Color(0xFF94A3B8), size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No documents attached yet. Click "+ Add Document" to attach Adhar, DL, RC, etc.',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.upload_file_rounded, size: 15),
                                label: const Text('Attach', style: TextStyle(fontSize: 12)),
                                onPressed: () => _addDocumentWithPicker(),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._documents.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final doc = entry.value;
                          return _buildDocumentAttachmentCard(doc, idx, isDark);
                        }),

                      const SizedBox(height: 24),
                      // Section 2: Visit Information
                      _buildSectionTitle('Visit Information', isDark),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildTextField(
                            controller: _purposeController,
                            label: 'Purpose of Visit *',
                            hint: 'e.g. Meet Student, Fee Payment, Official',
                            isDark: isDark,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Purpose required' : null,
                          ),
                          _buildDropdownField(
                            label: 'Destination / Checkpoint',
                            value: _destination,
                            items: _destinations,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) setState(() => _destination = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildSmartHostAutocompleteField(isDark),
                          _buildTextField(
                            controller: _vehicleController,
                            label: 'Vehicle Number (Optional)',
                            hint: 'e.g. UP16 AB 1234',
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _remarksController,
                        label: 'Operational Remarks',
                        hint: 'Additional notes or requirements',
                        isDark: isDark,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Auto Check-In Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Switch(
                              value: _autoCheckIn,
                              activeThumbColor: const Color(0xFF2563EB),
                              onChanged: (val) => setState(() => _autoCheckIn = val),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Check In Immediately (Walk-In)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Issues gate pass and logs entry checkpoint instantly',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
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

            // Modal Footer Actions
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 24,
                vertical: isNarrow ? 12 : 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            widget.existingVisit != null
                                ? 'Save Changes'
                                : (_autoCheckIn ? 'Register & Check In' : 'Register Visitor'),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
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

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (_instantRestriction != null && _instantRestriction!.isRestricted) {
      final override = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Security Override Warning'),
            ],
          ),
          content: Text(
            'This visitor has an active restriction on record:\n\n'
            'Reason: ${_instantRestriction!.restrictionReason}\n'
            'Type: ${_instantRestriction!.restrictionType}\n\n'
            'Are you sure you want to proceed and issue an entry pass?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel Entry'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supervisor Override', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (override != true) {
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final notifier = ref.read(visitorsProvider.notifier);

    String? photoUrlPayload;
    if (_capturedPhotoBytes != null) {
      photoUrlPayload = 'data:image/jpeg;base64,${base64Encode(_capturedPhotoBytes!)}';
    } else {
      photoUrlPayload = _existingPhotoUrl;
    }

    final payload = {
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      'company': _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
      'visitor_type': _visitorType,
      'id_type': _idType,
      'id_number_masked': _idNumberController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'destination': _destination,
      'host_name': _hostController.text.trim(),
      'vehicle_number': _vehicleController.text.trim().isNotEmpty ? _vehicleController.text.trim() : null,
      'remarks': _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
      'auto_check_in': _autoCheckIn,
      'has_photo': photoUrlPayload != null && photoUrlPayload.isNotEmpty,
      'photo_url': photoUrlPayload,
      'documents': _documents.map((d) => d.toJson()).toList(),
    };

    final bool ok;
    if (widget.existingVisit != null) {
      ok = await notifier.updateVisit(widget.existingVisit!.id, payload);
    } else {
      ok = await notifier.registerVisitor(payload);
    }

    setState(() => _isSubmitting = false);

    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow({required bool isNarrow, required List<Widget> children}) {
    if (isNarrow) {
      return Column(
        children: children.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: c,
        )).toList(),
      );
    }
    return Row(
      children: children.asMap().entries.map((entry) {
        final idx = entry.key;
        final child = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: idx > 0 ? 14 : 0),
            child: child,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: AppSearchableDropdown<String>.fromMenuItems(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onChanged: onChanged,
              items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentAttachmentCard(AttachedVisitorDoc doc, int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.nameController.text.isNotEmpty ? doc.nameController.text : 'Attachment #${index + 1}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      doc.bytes != null
                          ? '${(doc.bytes!.length / 1024).toStringAsFixed(1)} KB • Ready to upload'
                          : (doc.url != null && doc.url!.isNotEmpty ? 'Attached document • Verified' : 'No file attached'),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.upload_file_rounded, size: 14),
                label: const Text('Change File', style: TextStyle(fontSize: 11)),
                onPressed: () => _pickFileForDoc(doc),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 18),
                tooltip: 'Remove Attachment',
                onPressed: () {
                  setState(() {
                    doc.dispose();
                    _documents.removeAt(index);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Document Type (Type custom name, e.g. Adhar, Driving License, RC) *',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: doc.typeController,
            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Type document type (e.g. Adhar, PAN, Driving License)...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ['Adhar', 'PAN Card', 'Driving License', 'Vehicle RC', 'Passport', 'Voter ID'].map((chip) {
              final isSelected = doc.typeController.text.trim().toLowerCase() == chip.toLowerCase();
              return InkWell(
                onTap: () {
                  setState(() {
                    doc.typeController.text = chip;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartHostAutocompleteField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Host / Person to Meet *',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Search student / staff',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Autocomplete<HostSearchResultItem>(
          initialValue: TextEditingValue(text: _hostController.text),
          displayStringForOption: (item) => item.displayName,
          optionsBuilder: (textEditingValue) async {
            final query = textEditingValue.text.trim();
            if (query.length < 2) return const Iterable<HostSearchResultItem>.empty();
            final notifier = ref.read(visitorsProvider.notifier);
            return await notifier.searchHosts(query);
          },
          onSelected: (item) {
            _hostController.text = item.displayName;
            if (item.isStudent && item.hostelRoom != null && item.hostelRoom!.isNotEmpty) {
              if (item.hostelRoom!.toLowerCase().contains('girls')) {
                setState(() => _destination = 'Girls Hostel');
              } else if (item.hostelRoom!.toLowerCase().contains('boys')) {
                setState(() => _destination = 'Boys Hostel');
              }
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            controller.addListener(() {
              if (_hostController.text != controller.text) {
                _hostController.text = controller.text;
              }
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              validator: (v) => v == null || v.trim().isEmpty ? 'Host required' : null,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. Rahul Sharma, Anita Desai, Principal',
                hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.person_search_rounded, size: 18, color: Color(0xFF2563EB)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    itemBuilder: (context, index) {
                      final item = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: item.isStudent ? const Color(0xFFEFF6FF) : const Color(0xFFF3E8FF),
                          child: Icon(
                            item.isStudent ? Icons.school_rounded : Icons.business_center_rounded,
                            size: 16,
                            color: item.isStudent ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.fullName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isStudent ? const Color(0xFFDBEAFE) : const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.role.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: item.isStudent ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.isStudent
                                  ? 'Class ${item.classSection ?? '-'} • Roll ${item.rollNumber ?? '-'}'
                                  : (item.department.isNotEmpty ? item.department : (item.designation ?? 'Staff')),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                            if (item.hostelRoom != null && item.hostelRoom!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.hotel_rounded, size: 12, color: Color(0xFF0D9488)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Hostel: ${item.hostelRoom}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF0D9488), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            if (item.hasActiveOuting)
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.directions_walk, size: 12, color: Color(0xFFB45309)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'OUTING PASS ACTIVE: ${item.outingDetails ?? "Approved"}',
                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        onTap: () => onSelected(item),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../../utils/visitor_avatar_helper.dart';

class VisitorRestrictionDialog extends ConsumerStatefulWidget {
  final VisitorItem? initialVisitor;
  final VisitorProfileItem? initialProfile;

  const VisitorRestrictionDialog({
    super.key,
    this.initialVisitor,
    this.initialProfile,
  });

  @override
  ConsumerState<VisitorRestrictionDialog> createState() => _VisitorRestrictionDialogState();
}

class _VisitorRestrictionDialogState extends ConsumerState<VisitorRestrictionDialog> {
  final _formKey = GlobalKey<FormState>();

  // Profile Mode: 0 = Select Existing Profile, 1 = Enter New Profile
  int _profileMode = 0;
  VisitorProfileItem? _selectedProfile;
  final _searchProfileCtrl = TextEditingController();

  // Visitor identity fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController(text: 'XXXX-XXXX-1234');
  final _notesController = TextEditingController();

  String _visitorType = 'Parent';
  String _idType = 'Aadhaar Card';
  String _scopeType = 'CAMPUS';
  String _reasonCategory = 'Security Incident';
  int _durationDays = 30;
  DateTime? _customValidTill;
  bool _isSubmitting = false;
  String? _existingVisitorInfo;

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day.toString().padLeft(2, '0');
    final mon = months[dt.month - 1];
    final yr = dt.year.toString();
    return '$day $mon $yr';
  }

  Future<void> _pickCustomValidTill(BuildContext context) async {
    final now = DateTime.now();
    final initial = _customValidTill ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Select Valid Till Date',
      confirmText: 'Select',
    );
    if (picked != null) {
      setState(() {
        _customValidTill = picked;
      });
    }
  }

  // Photo state
  Uint8List? _capturedPhotoBytes;
  String? _capturedPhotoName;
  String? _existingPhotoUrl;
  final ImagePicker _picker = ImagePicker();

  bool get _hasPhoto =>
      _capturedPhotoBytes != null || (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty);

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

  static const List<Map<String, String>> _scopeOptions = [
    {'code': 'CAMPUS', 'label': 'Entire Campus'},
    {'code': 'INSTITUTION', 'label': 'All Institution Facilities'},
    {'code': 'BUILDING', 'label': 'Specific Building (Hostel/Lab/Library)'},
    {'code': 'DEPARTMENT', 'label': 'Specific Department/Floor'},
  ];

  static const List<String> _reasonOptions = [
    'Security Incident',
    'Behavioral Issue / Verbal Threat',
    'Campus Policy Violation',
    'Unauthorized Entry Attempt',
    'Harassment or Stalking',
    'Legal / Court / Police Directive',
    'Other Serious Misconduct',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialProfile != null) {
      _applyProfile(widget.initialProfile!);
    } else if (widget.initialVisitor != null) {
      final v = widget.initialVisitor!;
      _nameController.text = v.visitorName;
      _phoneController.text = v.phone;
      _visitorType = v.visitorType;
      if (v.photoUrl != null && v.photoUrl!.isNotEmpty) {
        _existingPhotoUrl = v.photoUrl;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(visitorsProvider.notifier).fetchProfiles();
    });
  }

  @override
  void dispose() {
    _searchProfileCtrl.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyProfile(VisitorProfileItem profile) {
    setState(() {
      _selectedProfile = profile;
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email ?? '';
      _visitorType = profile.visitorType;
      _idType = profile.idType;
      _idNumberController.text = profile.idNumberMasked;
      _existingPhotoUrl = profile.photoUrl;
      _capturedPhotoBytes = null;
      _capturedPhotoName = profile.fullName.isNotEmpty ? '${profile.fullName} Profile' : null;
      _existingVisitorInfo = 'Existing profile loaded: ${profile.fullName} (${profile.phone})';
    });
  }

  void _clearSelectedProfile() {
    setState(() {
      _selectedProfile = null;
      _existingVisitorInfo = null;
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _idNumberController.text = 'XXXX-XXXX-1234';
      _existingPhotoUrl = null;
      _capturedPhotoBytes = null;
      _capturedPhotoName = null;
    });
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
    } catch (_) {
      if (mounted) _pickFromGallery();
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
    if (phone.length >= 10 && _selectedProfile == null) {
      final api = ref.read(visitorsApiServiceProvider);
      final results = await api.searchExisting(phone.trim());
      if (results.isNotEmpty && mounted) {
        final match = results.first;
        setState(() {
          _existingVisitorInfo = 'Returning visitor detected: ${match['full_name']} (${match['visitor_type']})';
          if (_nameController.text.isEmpty) {
            _nameController.text = match['full_name']?.toString() ?? '';
          }
          if (_emailController.text.isEmpty && match['email'] != null) {
            _emailController.text = match['email']?.toString() ?? '';
          }
        });
      } else {
        if (_existingVisitorInfo != null) {
          setState(() => _existingVisitorInfo = null);
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    String? photoData = _existingPhotoUrl;
    if (_capturedPhotoBytes != null && _capturedPhotoBytes!.isNotEmpty) {
      photoData = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80';
    }

    final enteredPhone = _phoneController.text.trim();
    final payload = <String, dynamic>{
      if (_selectedProfile != null && enteredPhone == _selectedProfile!.phone)
        'visitor_id': _selectedProfile!.id
      else if (widget.initialVisitor != null &&
               widget.initialVisitor!.visitorId.isNotEmpty &&
               enteredPhone == widget.initialVisitor!.phone)
        'visitor_id': widget.initialVisitor!.visitorId,
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty)
        'email': _emailController.text.trim(),
      'visitor_type': _visitorType,
      'id_type': _idType,
      'id_number_masked': _idNumberController.text.trim(),
      'scope_type': _scopeType,
      'scope_name': _scopeOptions.firstWhere((s) => s['code'] == _scopeType, orElse: () => {'label': 'Entire Campus'})['label'],
      'reason_category': _reasonCategory,
      'confidential_notes': _notesController.text.trim(),
      'duration_days': _durationDays == -1 ? (_customValidTill?.difference(DateTime.now()).inDays.clamp(1, 36500) ?? 30) : _durationDays,
      'valid_till': _durationDays == 3650
          ? 'Permanent'
          : (_durationDays == -1 && _customValidTill != null
              ? _customValidTill!.toIso8601String()
              : DateTime.now().add(Duration(days: _durationDays)).toIso8601String()),
      'valid_till_text': _durationDays == 3650
          ? 'Permanent'
          : (_durationDays == -1 && _customValidTill != null
              ? _formatDate(_customValidTill!)
              : _formatDate(DateTime.now().add(Duration(days: _durationDays)))),
      'is_permanent': _durationDays == 3650,
      if (photoData != null && photoData.isNotEmpty) 'photo_url': photoData,
      'requested_by_name': 'Security Officer',
      'approved_by_name': 'Director / Principal',
    };

    final ok = await ref.read(visitorsProvider.notifier).createRestriction(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Visitor "${_nameController.text.trim()}" has been placed on the security blacklist.'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 680.0;
    final visitorsState = ref.watch(visitorsProvider);

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
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Place Security Restriction / Blacklist',
                          style: TextStyle(
                            fontSize: isNarrow ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Restrict visitor access with high security control & audit trail',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
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
                      // ============================================
                      // 1. PROFILE SELECTION MODE SEGMENTED CONTROL
                      // ============================================
                      _buildSectionTitle('Visitor Profile Source', isDark),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _profileMode = 0),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _profileMode == 0
                                        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _profileMode == 0
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.contacts_rounded,
                                        size: 15,
                                        color: _profileMode == 0
                                            ? const Color(0xFFDC2626)
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Select Existing Profile',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: _profileMode == 0 ? FontWeight.w700 : FontWeight.w500,
                                          color: _profileMode == 0
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _profileMode = 1;
                                    if (_selectedProfile != null) {
                                      _clearSelectedProfile();
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _profileMode == 1
                                        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _profileMode == 1
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_add_rounded,
                                        size: 15,
                                        color: _profileMode == 1
                                            ? const Color(0xFFDC2626)
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '+ New Profile Details',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: _profileMode == 1 ? FontWeight.w700 : FontWeight.w500,
                                          color: _profileMode == 1
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Existing Profile Picker Dropdown / Autocomplete
                      if (_profileMode == 0) ...[
                        if (_selectedProfile == null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Search & Choose Profile to Blacklist',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Autocomplete<VisitorProfileItem>(
                                  displayStringForOption: (p) => '${p.fullName} • ${p.phone} (${p.visitorType})',
                                  optionsBuilder: (TextEditingValue textVal) {
                                    final query = textVal.text.trim().toLowerCase();
                                    final profiles = visitorsState.profiles;
                                    if (query.isEmpty) {
                                      return profiles.take(15);
                                    }
                                    return profiles.where((p) =>
                                        p.fullName.toLowerCase().contains(query) ||
                                        p.phone.contains(query) ||
                                        (p.company != null && p.company!.toLowerCase().contains(query)));
                                  },
                                  onSelected: (VisitorProfileItem selection) {
                                    _applyProfile(selection);
                                  },
                                  fieldViewBuilder: (context, fieldCtrl, focusNode, onFieldSubmitted) {
                                    return TextField(
                                      controller: fieldCtrl,
                                      focusNode: focusNode,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Type name or phone number...',
                                        hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                                        suffixIcon: visitorsState.isLoadingProfiles
                                            ? const Padding(
                                                padding: EdgeInsets.all(10),
                                                child: SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                ),
                                              )
                                            : null,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(10),
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        child: Container(
                                          width: dialogWidth - 64,
                                          constraints: const BoxConstraints(maxHeight: 220),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: ListView.separated(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            separatorBuilder: (_, __) => Divider(
                                              height: 1,
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                            ),
                                            itemBuilder: (context, idx) {
                                              final item = options.elementAt(idx);
                                              return InkWell(
                                                onTap: () => onSelected(item),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundColor: const Color(0xFFFEE2E2),
                                                        child: Text(
                                                          item.fullName.isNotEmpty ? item.fullName[0].toUpperCase() : 'V',
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              item.fullName,
                                                              style: TextStyle(
                                                                fontSize: 12.5,
                                                                fontWeight: FontWeight.w600,
                                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                              ),
                                                            ),
                                                            Text(
                                                              '${item.phone} • ${item.visitorType}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFEFF6FF),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '${item.totalVisits} visits',
                                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF87171)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFDC2626),
                                  child: Text(
                                    _selectedProfile!.fullName.isNotEmpty
                                        ? _selectedProfile!.fullName[0].toUpperCase()
                                        : 'V',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            _selectedProfile!.fullName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDC2626),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Selected Profile',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Phone: ${_selectedProfile!.phone} • ${_selectedProfile!.visitorType} • ${_selectedProfile!.idType}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _clearSelectedProfile,
                                  icon: const Icon(Icons.refresh_rounded, size: 14),
                                  label: const Text('Change', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    side: const BorderSide(color: Color(0xFFDC2626)),
                                    foregroundColor: const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      if (_existingVisitorInfo != null && _selectedProfile == null)
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
                      // 2. VISITOR PHOTO SECTION
                      // ============================================
                      _buildSectionTitle('Visitor Photo Identification', isDark),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _capturePhoto,
                              child: Container(
                                width: 75,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _hasPhoto
                                        ? const Color(0xFFDC2626)
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
                                            size: 24,
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          ),
                                          const SizedBox(height: 3),
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
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _hasPhoto
                                        ? 'Photo attached for identification'
                                        : 'Capture or upload photo of person being blacklisted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _hasPhoto
                                          ? const Color(0xFFDC2626)
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
                                  const SizedBox(height: 8),
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
                      const SizedBox(height: 18),

                      // ============================================
                      // 3. VISITOR IDENTITY DETAILS
                      // ============================================
                      _buildSectionTitle('Visitor Identity Details', isDark),
                      const SizedBox(height: 10),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Visitor Full Name *',
                            hint: 'e.g. Mr. Rajesh Kumar',
                            isDark: isDark,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter visitor name' : null,
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Contact Phone Number *',
                            hint: '+91 98765 43210',
                            isDark: isDark,
                            onChanged: _checkExistingPhone,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter phone number' : null,
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
                      const SizedBox(height: 20),

                      // ============================================
                      // 4. SECURITY RESTRICTION PARAMETERS
                      // ============================================
                      _buildSectionTitle('Security Restriction Parameters', isDark),
                      const SizedBox(height: 10),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildMapDropdownField(
                            label: 'Restriction Scope *',
                            value: _scopeType,
                            items: _scopeOptions,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) setState(() => _scopeType = val);
                            },
                          ),
                          _buildDropdownField(
                            label: 'Reason Category *',
                            value: _reasonCategory,
                            items: _reasonOptions,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) setState(() => _reasonCategory = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildDurationDropdownField(
                            label: 'Restriction Period / Duration',
                            value: _durationDays,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _durationDays = val;
                                  if (val == -1 && _customValidTill == null) {
                                    _customValidTill = DateTime.now().add(const Duration(days: 30));
                                  }
                                });
                              }
                            },
                          ),
                          if (_durationDays == -1)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Custom Valid Till Date *',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _pickCustomValidTill(context),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFFDC2626)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _customValidTill != null ? _formatDate(_customValidTill!) : 'Select Date',
                                            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Confidential Incident Notes & Justification
                      _buildTextField(
                        controller: _notesController,
                        label: 'Confidential Incident Notes & Security Justification *',
                        hint: 'Document incident timeline, security log reference, and specific rationale for restriction...',
                        maxLines: 3,
                        isDark: isDark,
                        validator: (v) => v == null || v.trim().length < 5
                            ? 'Please provide detailed incident justification (min 5 chars)'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Bottom Action Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 14),
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
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.gavel_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Enforcing...' : 'Enforce Restriction & Blacklist',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        children: children
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: c,
                ))
            .toList(),
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
              items: items
                  .map((it) => DropdownMenuItem(
                        value: it,
                        child: Text(it, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapDropdownField({
    required String label,
    required String value,
    required List<Map<String, String>> items,
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
              value: items.any((it) => it['code'] == value) ? value : items.first['code'],
              isExpanded: true,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onChanged: onChanged,
              items: items
                  .map((it) => DropdownMenuItem(
                        value: it['code'],
                        child: Text(it['label']!, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDropdownField({
    required String label,
    required int value,
    required bool isDark,
    required ValueChanged<int?> onChanged,
  }) {
    const options = [
      {'val': 7, 'label': '7 Days (Temporary Warning)'},
      {'val': 30, 'label': '30 Days (Standard Month)'},
      {'val': 90, 'label': '90 Days (Quarterly Ban)'},
      {'val': 365, 'label': '1 Year (Extended Ban)'},
      {'val': 3650, 'label': 'Indefinite / Permanent Restriction'},
      {'val': -1, 'label': 'Custom Valid Till Date...'},
    ];

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
            child: AppSearchableDropdown<int>.fromMenuItems(
              value: options.any((it) => it['val'] == value) ? value : 30,
              isExpanded: true,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onChanged: onChanged,
              items: options
                  .map((it) => DropdownMenuItem<int>(
                        value: it['val'] as int,
                        child: Text(it['label'] as String, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

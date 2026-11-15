import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../../utils/visitor_avatar_helper.dart';

class VisitorScheduleDialog extends ConsumerStatefulWidget {
  final VisitorProfileItem? initialProfile;
  final VisitorItem? initialVisitor;

  const VisitorScheduleDialog({
    super.key,
    this.initialProfile,
    this.initialVisitor,
  });

  @override
  ConsumerState<VisitorScheduleDialog> createState() => _VisitorScheduleDialogState();
}

class _VisitorScheduleDialogState extends ConsumerState<VisitorScheduleDialog> {
  final _formKey = GlobalKey<FormState>();

  // Profile Mode: 0 = Select Existing Profile, 1 = Enter New Profile
  int _profileMode = 0;
  VisitorProfileItem? _selectedProfile;
  final _searchProfileCtrl = TextEditingController();

  // Visitor identity fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _idNumberController = TextEditingController(text: 'XXXX-XXXX-1234');

  // Appointment & Meeting fields
  final _hostController = TextEditingController(text: 'Principal Office');
  final _purposeController = TextEditingController(text: 'Official Meeting');
  final _vehicleController = TextEditingController();
  final _accompanyingController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  String _visitorType = 'Parent';
  String _idType = 'Aadhaar Card';
  String _destination = 'Admin Office';
  String _purpose = 'Official Meeting';

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  bool _isSubmitting = false;
  String? _existingVisitorInfo;
  InstantRestrictionResult? _instantRestriction;

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

  static const List<String> _destinations = [
    'Admin Office', 'Principal Office', 'Reception Desk', 'Library', 'Science Lab', 'Boys Hostel', 'Girls Hostel', 'Auditorium', 'Main Gate'
  ];

  static const List<String> _purposes = [
    'Official Meeting',
    'Academic Discussion',
    'Admission Inquiry',
    'Fee Payment / Inquiry',
    'Official Audit / Inspection',
    'Maintenance / Repair',
    'Vendor Supply / Delivery',
    'Parent-Teacher Meeting',
    'Campus Tour',
    'Other'
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
      _purposeController.text = v.purpose;
      _destination = v.location;
      _hostController.text = v.hostName;
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
    _companyController.dispose();
    _idNumberController.dispose();
    _hostController.dispose();
    _purposeController.dispose();
    _vehicleController.dispose();
    _accompanyingController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyProfile(VisitorProfileItem profile) {
    setState(() {
      _selectedProfile = profile;
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email ?? '';
      _companyController.text = profile.company ?? '';
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
      _companyController.clear();
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
    final cleanPhone = phone.trim();
    if (cleanPhone.length >= 10 && _selectedProfile == null) {
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Keep end time at least 30 minutes after start time
        final startMins = picked.hour * 60 + picked.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          final newEnd = startMins + 60;
          _endTime = TimeOfDay(hour: (newEnd ~/ 60) % 24, minute: newEnd % 60);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _addDuration(int minutes) {
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final newEndMins = startMins + minutes;
    setState(() {
      _endTime = TimeOfDay(hour: (newEndMins ~/ 60) % 24, minute: newEndMins % 60);
    });
  }

  Future<void> _submit() async {
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
            'Do you want to proceed and schedule an appointment anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
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

    String? photoData = _existingPhotoUrl;
    if (_capturedPhotoBytes != null && _capturedPhotoBytes!.isNotEmpty) {
      photoData = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80';
    }

    final startDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final expectedCount = int.tryParse(_accompanyingController.text.trim()) ?? 0;

    final payload = <String, dynamic>{
      if (_selectedProfile != null)
        'visitor_id': _selectedProfile!.id
      else if (widget.initialVisitor != null)
        'visitor_id': widget.initialVisitor!.id,
      'full_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      'company': _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
      'visitor_type': _visitorType,
      'id_type': _idType,
      'id_number_masked': _idNumberController.text.trim(),
      'host_name': _hostController.text.trim(),
      'host_department': _destination,
      'purpose': _purposeController.text.trim().isNotEmpty ? _purposeController.text.trim() : _purpose,
      'destination': _destination,
      'scheduled_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'scheduled_start_at': startDt.toUtc().toIso8601String(),
      'scheduled_end_at': endDt.toUtc().toIso8601String(),
      'expected_count': expectedCount + 1,
      'expected_visitors_text': '${expectedCount + 1} (Expected)',
      if (_vehicleController.text.trim().isNotEmpty) 'vehicle_number': _vehicleController.text.trim(),
      'notes': _notesController.text.trim(),
      if (photoData != null && photoData.isNotEmpty) 'photo_url': photoData,
    };

    final ok = await ref.read(visitorsProvider.notifier).scheduleAppointment(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (ok) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment scheduled successfully for ${_nameController.text.trim()}!'),
            backgroundColor: const Color(0xFF16A34A),
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
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: Color(0xFF9333EA), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Visitor Appointment',
                          style: TextStyle(
                            fontSize: isNarrow ? 16 : 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pre-register expected visitors, invitees, and schedule meetings',
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
                                            ? const Color(0xFF9333EA)
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
                                            ? const Color(0xFF9333EA)
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
                                  'Search & Choose Profile to Schedule',
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
                                        hintText: 'Type name or phone number to schedule...',
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
                                                        backgroundColor: const Color(0xFFF3E8FF),
                                                        child: Text(
                                                          item.fullName.isNotEmpty ? item.fullName[0].toUpperCase() : 'V',
                                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9333EA)),
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
                              color: const Color(0xFFF3E8FF).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFC084FC)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF9333EA),
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
                                              color: const Color(0xFF9333EA),
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
                                    side: const BorderSide(color: Color(0xFF9333EA)),
                                    foregroundColor: const Color(0xFF9333EA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

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
                                          : 'Visitor has an active security restriction on record.',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_existingVisitorInfo != null && _selectedProfile == null)
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
                      // 2. VISITOR PHOTO IDENTIFICATION
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
                                        ? const Color(0xFF9333EA)
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
                                        ? 'Photo attached for identification pass'
                                        : 'Capture or upload visitor\'s photo for appointment pass',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _hasPhoto
                                          ? const Color(0xFF9333EA)
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
                            label: 'Full Name *',
                            hint: 'e.g. Mr. Rajesh Kumar',
                            isDark: isDark,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter visitor name' : null,
                          ),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Contact Number *',
                            hint: '+91 98765 43210',
                            isDark: isDark,
                            onChanged: _checkExistingPhone,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter contact number' : null,
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
                      // 4. SCHEDULE & APPOINTMENT DETAILS
                      // ============================================
                      _buildSectionTitle('Schedule & Appointment Details', isDark),
                      const SizedBox(height: 10),

                      // Date and Time Pickers
                      Container(
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
                                const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF9333EA)),
                                const SizedBox(width: 6),
                                Text(
                                  'Appointment Date & Time Window',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildResponsiveRow(
                              isNarrow: isNarrow,
                              children: [
                                // Date Card
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF9333EA)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Date',
                                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                              ),
                                              Text(
                                                DateFormat('dd MMM yyyy').format(_selectedDate),
                                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Start Time Card
                                InkWell(
                                  onTap: _pickStartTime,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Start Time',
                                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                              ),
                                              Text(
                                                _startTime.format(context),
                                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                ),
                                // End Time Card
                                InkWell(
                                  onTap: _pickEndTime,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_filled_rounded, size: 16, color: Color(0xFFF59E0B)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'End Time',
                                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                              ),
                                              Text(
                                                _endTime.format(context),
                                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Quick duration buttons
                            Wrap(
                              spacing: 6,
                              children: [
                                _buildDurationChip('30 Mins', 30, isDark),
                                _buildDurationChip('1 Hour', 60, isDark),
                                _buildDurationChip('2 Hours', 120, isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Host and Destination
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildSmartHostAutocompleteField(isDark),
                          _buildDropdownField(
                            label: 'Destination / Department *',
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

                      // Purpose and Accompanying
                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildDropdownField(
                            label: 'Purpose of Meeting *',
                            value: _purpose,
                            items: _purposes,
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _purpose = val;
                                  _purposeController.text = val;
                                });
                              }
                            },
                          ),
                          _buildTextField(
                            controller: _accompanyingController,
                            label: 'Accompanying Persons Count',
                            hint: '0',
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildResponsiveRow(
                        isNarrow: isNarrow,
                        children: [
                          _buildTextField(
                            controller: _vehicleController,
                            label: 'Vehicle Number (Optional)',
                            hint: 'e.g. MH-12-AB-1234',
                            isDark: isDark,
                          ),
                          _buildTextField(
                            controller: _companyController,
                            label: 'Company / Organization (Optional)',
                            hint: 'e.g. Tata Consultancy Services',
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notes & Agenda
                      _buildTextField(
                        controller: _notesController,
                        label: 'Meeting Agenda / Appointment Notes',
                        hint: 'Provide details about agenda, meeting topics, special requirements...',
                        maxLines: 2,
                        isDark: isDark,
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
                      backgroundColor: const Color(0xFF9333EA),
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
                        : const Icon(Icons.event_available_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Scheduling...' : 'Schedule Appointment',
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

  Widget _buildDurationChip(String label, int minutes, bool isDark) {
    return InkWell(
      onTap: () => _addDuration(minutes),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF9333EA).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.3)),
        ),
        child: Text(
          '+$label',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF9333EA)),
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
            child: DropdownButton<String>(
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
  Widget _buildSmartHostAutocompleteField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Host / Staff to Meet *',
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
            } else if (item.department.isNotEmpty) {
              if (_destinations.contains(item.department)) {
                setState(() => _destination = item.department);
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
                prefixIcon: const Icon(Icons.person_search_rounded, size: 18, color: Color(0xFF9333EA)),
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
                                      'OUTING PASS ACTIVE: ${item.outingDetails ?? 'Approved'}',
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

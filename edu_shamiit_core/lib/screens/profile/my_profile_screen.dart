import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/nav_helper.dart';
import '../../utils/download_helper.dart';

/// Unified Universal Profile Screen for EduSHAMIIT
/// Accessible across Admin, Academic (Teacher, Student), and other portals.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingDocument = false;
  String? _errorMessage;

  // Profile data
  Map<String, dynamic> _profile = {};
  List<dynamic> _sessions = [];
  List<dynamic> _logs = [];
  List<dynamic> _documents = [];

  // Controllers for Personal Details
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _religionController = TextEditingController();
  final _categoryController = TextEditingController();

  String _selectedGender = 'Prefer not to say';
  String _selectedBloodGroup = 'O+';
  String _selectedLanguage = 'English (US)';
  String _selectedTimezone = '(GMT +05:30) Asia/Kolkata';
  String _selectedTheme = 'dark';

  // Academic / Professional Info
  final _classNameController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _sessionController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _houseController = TextEditingController();
  final _specializationController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceYearsController = TextEditingController();

  // Family & Guardian Details
  final _fatherNameController = TextEditingController();
  final _fatherOccupationController = TextEditingController();
  final _fatherPhoneController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _motherOccupationController = TextEditingController();
  final _motherPhoneController = TextEditingController();

  final _guardianNameController = TextEditingController();
  String _selectedGuardianRelation = 'Legal Guardian';
  final _guardianPhoneController = TextEditingController();
  final _guardianEmailController = TextEditingController();
  final _guardianAddressController = TextEditingController();

  // Structured Contact Info
  final _addressController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _countryController = TextEditingController();

  final _altEmailController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyRelationController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Preferences
  bool _emailNotifications = true;
  bool _smsAlerts = false;
  bool _pushNotifications = true;
  bool _weeklyReports = true;

  // Activity Log Filter
  String _selectedLogModule = 'All';

  final List<String> _validGenders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final List<String> _validBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _validLanguages = ['English (US)', 'English (UK)', 'Hindi', 'Spanish', 'French', 'German'];
  final List<String> _validTimezones = [
    '(GMT +05:30) Asia/Kolkata',
    '(GMT +00:00) UTC',
    '(GMT -05:00) Eastern Time (US)',
    '(GMT -08:00) Pacific Time (US)',
    '(GMT +04:00) Dubai / Gulf',
    '(GMT +08:00) Singapore / Perth',
  ];
  final List<String> _guardianRelations = [
    'Father',
    'Mother',
    'Grandparent',
    'Uncle',
    'Aunt',
    'Legal Guardian',
    'Sibling',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _bioController.dispose();
    _bloodGroupController.dispose();
    _nationalityController.dispose();
    _religionController.dispose();
    _categoryController.dispose();

    _classNameController.dispose();
    _rollNumberController.dispose();
    _sessionController.dispose();
    _admissionNumberController.dispose();
    _houseController.dispose();
    _specializationController.dispose();
    _qualificationController.dispose();
    _experienceYearsController.dispose();

    _fatherNameController.dispose();
    _fatherOccupationController.dispose();
    _fatherPhoneController.dispose();
    _motherNameController.dispose();
    _motherOccupationController.dispose();
    _motherPhoneController.dispose();

    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    _guardianAddressController.dispose();

    _addressController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();

    _altEmailController.dispose();
    _altPhoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyRelationController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService().get('/admin/schools/my-profile', useCache: false);
      if (res['success'] == true) {
        final profileData = res['profile'] ?? {};
        setState(() {
          _profile = profileData;
          _sessions = res['sessions'] ?? [];
          _logs = res['logs'] ?? [];
          _documents = (profileData['documents'] as List<dynamic>?) ?? [];

          // Personal Details
          _fullNameController.text = profileData['full_name'] ?? '';
          _usernameController.text = profileData['email'] != null
              ? profileData['email'].toString().split('@')[0]
              : '';
          _emailController.text = profileData['email'] ?? '';
          _phoneController.text = profileData['phone'] ?? '';
          _dobController.text = profileData['date_of_birth'] ?? '01/01/1990';
          _bioController.text = profileData['bio'] ??
              (profileData['role'] == 'super_admin'
                  ? 'System administrator with full access to manage all modules, users, and system settings.'
                  : '');

          final g = profileData['gender'] ?? 'Prefer not to say';
          _selectedGender = _validGenders.contains(g) ? g : 'Prefer not to say';

          final bg = (profileData['blood_group'] ?? 'O+').toString().trim();
          _selectedBloodGroup = _validBloodGroups.contains(bg) ? bg : 'O+';
          _bloodGroupController.text = _selectedBloodGroup;

          _nationalityController.text = profileData['nationality'] ?? 'Indian';
          _religionController.text = profileData['religion'] ?? '';
          _categoryController.text = profileData['category'] ?? 'General';

          final lang = profileData['preferred_language'] ?? 'English (US)';
          _selectedLanguage = _validLanguages.contains(lang) ? lang : 'English (US)';

          final tz = profileData['timezone'] ?? '(GMT +05:30) Asia/Kolkata';
          _selectedTimezone = _validTimezones.contains(tz) ? tz : '(GMT +05:30) Asia/Kolkata';

          _selectedTheme = profileData['preferred_theme'] ?? 'dark';

          // Academic / Professional
          _classNameController.text = profileData['class'] ?? '';
          _rollNumberController.text = profileData['roll_number']?.toString() ?? '';
          _sessionController.text = profileData['session'] ?? '';
          _admissionNumberController.text = profileData['admission_number'] ?? '';
          _houseController.text = profileData['house'] ?? '';
          _specializationController.text = profileData['specialization'] ?? '';
          _qualificationController.text = profileData['qualification'] ?? '';
          _experienceYearsController.text = profileData['experience_years']?.toString() ?? '';

          // Family & Guardian Info
          _fatherNameController.text = profileData['father_name'] ?? '';
          _fatherOccupationController.text = profileData['father_occupation'] ?? '';
          _fatherPhoneController.text = profileData['father_phone'] ?? '';
          _motherNameController.text = profileData['mother_name'] ?? '';
          _motherOccupationController.text = profileData['mother_occupation'] ?? '';
          _motherPhoneController.text = profileData['mother_phone'] ?? '';

          _guardianNameController.text = profileData['local_guardian'] ?? '';
          final gr = profileData['guardian_relationship'] ?? 'Legal Guardian';
          _selectedGuardianRelation = _guardianRelations.contains(gr) ? gr : 'Legal Guardian';
          _guardianPhoneController.text = profileData['guardian_phone'] ?? '';
          _guardianEmailController.text = profileData['guardian_email'] ?? '';
          _guardianAddressController.text = profileData['guardian_address'] ?? '';

          // Structured Contact Details
          _addressController.text = profileData['address'] ?? '';
          _addressLine1Controller.text = profileData['address_line1'] ?? profileData['address'] ?? '';
          _addressLine2Controller.text = profileData['address_line2'] ?? '';
          _cityController.text = profileData['city'] ?? '';
          _stateController.text = profileData['state'] ?? '';
          _pincodeController.text = profileData['pincode'] ?? '';
          _countryController.text = profileData['country'] ?? 'India';

          _altEmailController.text = profileData['alternative_email'] ?? '';
          _altPhoneController.text = profileData['alternative_phone'] ?? '';
          _emergencyNameController.text = profileData['emergency_contact_name'] ?? '';
          _emergencyRelationController.text = profileData['emergency_contact_relation'] ?? '';
          _emergencyPhoneController.text = profileData['emergency_contact_phone'] ?? '';

          // Preferences
          _emailNotifications = profileData['email_notifications'] ?? true;
          _smsAlerts = profileData['sms_alerts'] ?? false;
          _pushNotifications = profileData['push_notifications'] ?? true;
          _weeklyReports = profileData['weekly_reports'] ?? true;

          _isLoading = false;
        });

        // Sync authProvider so header and sidebar reflect latest profile
        ref.read(authProvider.notifier).updateUserData({
          'avatar_url': profileData['avatar_url'],
          'full_name': profileData['full_name'],
          'phone': profileData['phone'],
          'email': profileData['email'],
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load profile details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'dateOfBirth': _dobController.text.trim(),
        'bio': _bioController.text.trim(),
        'preferredLanguage': _selectedLanguage,
        'timezone': _selectedTimezone,
        'preferredTheme': _selectedTheme,
        // Demographics
        'bloodGroup': _selectedBloodGroup,
        'nationality': _nationalityController.text.trim(),
        'religion': _religionController.text.trim(),
        'category': _categoryController.text.trim(),
        // Professional / Academic
        'qualification': _qualificationController.text.trim(),
        'experienceYears': _experienceYearsController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'house': _houseController.text.trim(),
        // Family & Guardian
        'fatherName': _fatherNameController.text.trim(),
        'fatherOccupation': _fatherOccupationController.text.trim(),
        'fatherPhone': _fatherPhoneController.text.trim(),
        'motherName': _motherNameController.text.trim(),
        'motherOccupation': _motherOccupationController.text.trim(),
        'motherPhone': _motherPhoneController.text.trim(),
        'localGuardian': _guardianNameController.text.trim(),
        'guardianRelationship': _selectedGuardianRelation,
        'guardianPhone': _guardianPhoneController.text.trim(),
        'guardianEmail': _guardianEmailController.text.trim(),
        'guardianAddress': _guardianAddressController.text.trim(),
        // Structured Contact details
        'address': _addressController.text.trim(),
        'addressLine1': _addressLine1Controller.text.trim(),
        'addressLine2': _addressLine2Controller.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'country': _countryController.text.trim(),
        'alternativeEmail': _altEmailController.text.trim(),
        'alternativePhone': _altPhoneController.text.trim(),
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactRelation': _emergencyRelationController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        // Preferences
        'emailNotifications': _emailNotifications,
        'smsAlerts': _smsAlerts,
        'pushNotifications': _pushNotifications,
        'weeklyReports': _weeklyReports,
        // Avatar URL
        'avatarUrl': _profile['avatar_url'],
      };

      final res = await ApiService().post('/admin/schools/my-profile/update', payload);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        setState(() {
          _isEditing = false;
        });
        await _fetchProfileData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['detail'] ?? 'Failed to update profile.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateQuickPreferences({
    bool? email,
    bool? sms,
    bool? push,
    bool? weekly,
    String? language,
    String? timezone,
    String? theme,
  }) async {
    final payload = {
      if (email != null) 'emailNotifications': email,
      if (sms != null) 'smsAlerts': sms,
      if (push != null) 'pushNotifications': push,
      if (weekly != null) 'weeklyReports': weekly,
      if (language != null) 'preferredLanguage': language,
      if (timezone != null) 'timezone': timezone,
      if (theme != null) 'preferredTheme': theme,
    };

    try {
      final res = await ApiService().post('/admin/schools/my-profile/preferences', payload);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferences saved.'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Avatar',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Avatar',
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 220, height: 220),
          zoomable: true,
          rotatable: true,
          scalable: true,
        ),
      ],
    );
    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
    return null;
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 90,
      );
      if (image == null) return;

      final croppedBytes = await _cropImage(image.path);
      if (croppedBytes == null) return;

      setState(() => _isUploadingAvatar = true);

      final res = await ApiService().multipartPostBytes(
        '/admin/system-config/upload?file_type=avatar',
        croppedBytes,
        image.name,
        'file',
      );

      if (res['success'] == true && res['data'] != null) {
        final url = res['data']['url'];
        await ApiService().post('/admin/schools/my-profile/update', {
          'avatarUrl': url,
          'fullName': _fullNameController.text.trim(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        await _fetchProfileData();
      } else {
        setState(() => _isUploadingAvatar = false);
      }
    } catch (e) {
      setState(() => _isUploadingAvatar = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Avatar upload failed: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadDocument(String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _isUploadingDocument = true);

      final res = await ApiService().multipartPostBytes(
        '/admin/schools/my-profile/document',
        file.bytes!,
        file.name,
        'document',
        fields: {'document_type': docType},
      );

      setState(() => _isUploadingDocument = false);

      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$docType uploaded successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        await _fetchProfileData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['detail'] ?? 'Upload failed.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingDocument = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document upload error: $e')),
        );
      }
    }
  }

  void _showCustomDocumentUploadDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Upload Custom Document',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the title/type for this document (e.g. Transfer Certificate, Medical Report, Extracurricular Award):',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Document Name / Title',
                  hintText: 'e.g., Transfer Certificate',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final docTitle = titleController.text.trim();
                if (docTitle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a document title.'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _pickAndUploadDocument(docTitle);
              },
              child: const Text('Select File & Upload', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDocument(String docId, String docName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Document', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$docName"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await ApiService().delete('/admin/schools/my-profile/document/$docId');
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document removed.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        await _fetchProfileData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _previewDocument(dynamic doc) {
    final url = doc['file_url']?.toString();
    final fileName = doc['file_name']?.toString() ?? 'Document';
    if (url == null || url.isEmpty) return;

    final isImage = fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.webp');

    if (isImage) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          fileName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Download',
                            icon: const Icon(Icons.download_rounded, color: Color(0xFF10B981)),
                            onPressed: () {
                              getDownloadHelper().downloadFile(url, fileName);
                            },
                          ),
                          IconButton(
                            tooltip: 'Close',
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      getDownloadHelper().downloadFile(url, fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $fileName...')),
      );
    }
  }

  // ── Two-Factor Authentication Setup Modal ──────────────────────────────────
  Future<void> _start2FASetupFlow() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().post('/admin/schools/my-profile/two-factor/setup', {});
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        final secret = res['secret'] as String;
        final otpauthUrl = res['otpauth_url'] as String;
        final backupCodes = (res['backup_codes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        if (!mounted) return;
        _show2FAVerificationModal(secret, otpauthUrl, backupCodes);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['detail'] ?? 'Could not initialize 2FA setup'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start 2FA: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  void _show2FAVerificationModal(String secret, String otpauthUrl, List<String> backupCodes) {
    final codeController = TextEditingController();
    bool isVerifying = false;
    String? verifyError;

    // Format secret with spaces for human readability: ABCD EFGH IJKL
    final formattedSecret = secret.replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)} ').trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.security_rounded, color: Color(0xFF4F46E5)),
                  const SizedBox(width: 10),
                  Text(
                    'Setup Two-Factor Authentication',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan this key in your Authenticator App (Google Authenticator, Microsoft Authenticator, or 1Password):',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              formattedSecret,
                              style: GoogleFonts.firaCode(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF818CF8),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy Secret Key',
                            icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.white70),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: secret));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Secret key copied to clipboard!'),
                                  backgroundColor: Color(0xFF10B981),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter 6-digit confirmation code generated by your app:',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: GoogleFonts.firaCode(fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        errorText: verifyError,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDialogState(() => verifyError = 'Please enter a 6-digit code');
                            return;
                          }
                          setDialogState(() {
                            isVerifying = true;
                            verifyError = null;
                          });

                          try {
                            final verifyRes = await ApiService().post('/admin/schools/my-profile/two-factor/verify', {
                              'secret': secret,
                              'code': code,
                              'backupCodes': backupCodes,
                            });

                            if (verifyRes['success'] == true) {
                              if (context.mounted) Navigator.pop(context);
                              await _fetchProfileData();
                              _showBackupCodesDialog(backupCodes);
                            } else {
                              setDialogState(() {
                                verifyError = verifyRes['detail'] ?? 'Verification failed';
                                isVerifying = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              verifyError = e.toString().replaceAll('ApiException: ', '');
                              isVerifying = false;
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify & Enable', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBackupCodesDialog(List<String> codes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text('2FA Enabled Successfully', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save these one-time recovery backup codes. If you ever lose access to your authenticator device, each code can be used once to sign in:',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: codes.map((c) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          c,
                          style: GoogleFonts.firaCode(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
              label: const Text('Copy All Codes', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codes.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Backup codes copied to clipboard!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _disable2FA() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Disable Two-Factor Authentication', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to disable Two-Factor Authentication? Your account security will be lowered.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await ApiService().post('/admin/schools/my-profile/two-factor/disable', {});
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Two-Factor Authentication disabled.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        await _fetchProfileData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disable 2FA: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    try {
      final res = await ApiService().post('/admin/schools/my-profile/revoke-session', {'sessionId': sessionId});
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session revoked successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        await _fetchProfileData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revoke session: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _downloadMyData() async {
    try {
      final res = await ApiService().get('/admin/schools/my-profile/export-data');
      final exportData = res['data'] ?? {
        'profile': _profile,
        'sessions': _sessions,
        'logs': _logs,
        'documents': _documents,
        'exported_at': DateTime.now().toIso8601String(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      final bytes = utf8.encode(jsonStr);

      getDownloadHelper().downloadBytes(bytes, 'edushamiit_profile_data_export.json');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data exported successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Change Password',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      hintText: 'Enter current password',
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'At least 6 characters',
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter new password',
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (newPasswordController.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('New password must be at least 6 characters.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }
                          if (newPasswordController.text != confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passwords do not match!'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final res = await ApiService().post('/user/change-password', {
                              'currentPassword': currentPasswordController.text,
                              'newPassword': newPasswordController.text,
                            });
                            if (res['success'] == true) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated successfully!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('ApiException: ', '')),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageSessionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Active Sessions & Devices',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 480,
            child: _sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No other active sessions.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, idx) {
                      final s = _sessions[idx];
                      return ListTile(
                        leading: const Icon(Icons.devices_rounded, color: Color(0xFF4F46E5)),
                        title: Text('${s['device_name'] ?? 'Device'} (${s['browser_name'] ?? 'Browser'})'),
                        subtitle: Text('IP: ${s['ip_address'] ?? '127.0.0.1'} • ${s['location'] ?? 'Unknown'}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                          onPressed: () async {
                            await _revokeSession(s['id']);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchOrCopy(String value, String type) async {
    if (value.isEmpty) return;
    try {
      final uri = type == 'phone' ? 'tel:$value' : (type == 'email' ? 'mailto:$value' : value);
      final canLaunch = await canLaunchUrlString(uri);
      if (canLaunch) {
        await launchUrlString(uri);
        return;
      }
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied $value to clipboard!'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Role-aware profile completion computation
  Map<String, dynamic> _calculateRoleCompletion() {
    final rawRole = _profile['role']?.toString().toLowerCase() ?? 'user';
    int total = 8;
    int completed = 0;
    String missingReason = 'Complete your profile';

    if ((_profile['full_name'] ?? '').toString().isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Add full name';
    }

    if ((_profile['email'] ?? '').toString().isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Add email address';
    }

    if ((_profile['phone'] ?? '').toString().isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Add phone number';
    }

    if ((_profile['avatar_url'] ?? '').toString().isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Upload profile photo';
    }

    if ((_profile['date_of_birth'] ?? '').toString().isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Add date of birth';
    }

    final addr = _profile['address_line1'] ?? _profile['address'] ?? '';
    if (addr.toString().isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Add residential address';
    }

    if (_documents.isNotEmpty) {
      completed++;
    } else {
      missingReason = 'Upload verification document';
    }

    if (rawRole == 'student') {
      total = 10;
      if ((_profile['father_name'] ?? '').toString().isNotEmpty || (_profile['mother_name'] ?? '').toString().isNotEmpty) {
        completed++;
      } else {
        missingReason = "Add parent details";
      }
      if ((_profile['father_phone'] ?? _profile['mother_phone'] ?? _profile['guardian_phone'] ?? '').toString().isNotEmpty) {
        completed++;
      } else {
        missingReason = "Add emergency contact phone";
      }
    } else if (rawRole == 'teacher') {
      total = 10;
      if ((_profile['qualification'] ?? '').toString().isNotEmpty) {
        completed++;
      } else {
        missingReason = 'Add highest qualification';
      }
      if ((_profile['specialization'] ?? '').toString().isNotEmpty) {
        completed++;
      } else {
        missingReason = 'Add teaching specialization';
      }
    } else {
      total = 9;
      if ((_profile['two_factor_enabled'] ?? false) == true) {
        completed++;
      } else {
        missingReason = 'Enable Two-Factor Authentication';
      }
    }

    final double ratio = (completed / total).clamp(0.0, 1.0);
    return {
      'ratio': ratio,
      'percentage': (ratio * 100).toInt(),
      'missing': ratio == 1.0 ? 'Profile 100% Verified!' : missingReason,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _profile.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text('Error: $_errorMessage', style: const TextStyle(color: Color(0xFFEF4444))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                onPressed: _fetchProfileData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 1100;
    final fallbackRoute = dashboardFallback(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation & Breadcrumbs Row
            Row(
              children: [
                IconButton(
                  tooltip: 'Go Back',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  onPressed: () => safeGoBack(context, fallbackRoute),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => safeGoBack(context, fallbackRoute),
                  child: Text(
                    'Dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey),
                Text(
                  'My Profile',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Header Title & Action Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompactHeader = constraints.maxWidth < 650;
                final headerTitle = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Profile',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'View and manage your personal credentials, family records, security, and preferences.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                );

                final actionButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          label: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: _updateProfile,
                        ),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEditing ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(_isEditing ? Icons.cancel_outlined : Icons.edit_outlined, color: Colors.white, size: 16),
                      label: Text(_isEditing ? 'Cancel Edit' : 'Edit Profile', style: const TextStyle(color: Colors.white)),
                      onPressed: () {
                        setState(() {
                          if (_isEditing) {
                            _fetchProfileData();
                          }
                          _isEditing = !_isEditing;
                        });
                      },
                    ),
                  ],
                );

                if (isCompactHeader) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      headerTitle,
                      const SizedBox(height: 12),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: headerTitle),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Top Profile Summary Card (Image, Badges, Metadata)
            _buildProfileSummaryCard(isDark),
            const SizedBox(height: 24),

            // Adaptive Body (Wide: flex 7/3, Mobile: Single column)
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabbedFormSection(isDark),
                        const SizedBox(height: 24),
                        _buildRecentActivitySection(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildProfileCompletionCard(isDark),
                        const SizedBox(height: 24),
                        _buildSecurityCard(isDark),
                        const SizedBox(height: 24),
                        _buildLoginActivityCard(isDark),
                        const SizedBox(height: 24),
                        _buildQuickActionsCard(isDark),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildTabbedFormSection(isDark),
                  const SizedBox(height: 24),
                  _buildProfileCompletionCard(isDark),
                  const SizedBox(height: 24),
                  _buildSecurityCard(isDark),
                  const SizedBox(height: 24),
                  _buildLoginActivityCard(isDark),
                  const SizedBox(height: 24),
                  _buildQuickActionsCard(isDark),
                  const SizedBox(height: 24),
                  _buildRecentActivitySection(isDark),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummaryCard(bool isDark) {
    final rawRole = _profile['role']?.toString().toLowerCase() ?? 'user';
    String displayRole = 'User';
    Color roleBadgeColor = const Color(0xFF4F46E5);

    if (rawRole == 'super_admin') {
      displayRole = 'Super Administrator';
      roleBadgeColor = const Color(0xFF6366F1);
    } else if (rawRole == 'director' || rawRole == 'admin' || rawRole == 'school_admin') {
      displayRole = rawRole == 'director' ? 'Director' : 'School Administrator';
      roleBadgeColor = const Color(0xFF8B5CF6);
    } else if (rawRole == 'teacher') {
      displayRole = 'Teacher';
      roleBadgeColor = const Color(0xFF0284C7);
    } else if (rawRole == 'student') {
      displayRole = 'Student';
      roleBadgeColor = const Color(0xFF10B981);
    } else if (rawRole == 'driver') {
      displayRole = 'Bus Driver';
      roleBadgeColor = const Color(0xFFF59E0B);
    } else if (rawRole == 'accountant') {
      displayRole = 'Accountant';
      roleBadgeColor = const Color(0xFF14B8A6);
    } else {
      displayRole = rawRole.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }

    final userIdDisplay = _profile['user_id'] ??
        _profile['employee_id'] ??
        _profile['admission_number'] ??
        _profile['roll_number'] ??
        (_profile['id'] != null ? _profile['id'].toString().substring(0, 8).toUpperCase() : 'N/A');

    final departmentDisplay = _profile['department'] ??
        (rawRole == 'student'
            ? (_profile['class'] != null && _profile['class'].toString().isNotEmpty ? 'Class ${_profile['class']}' : 'Student Academic')
            : (rawRole == 'teacher'
                ? (_profile['specialization'] ?? 'Academic Faculty')
                : (rawRole == 'super_admin' ? 'Administration' : 'General')));

    final joinedOnRaw = _profile['joining_date'] ?? _profile['created_at'];
    String joinedOnDisplay = 'N/A';
    if (joinedOnRaw != null) {
      try {
        joinedOnDisplay = DateFormat('MMM dd, yyyy').format(DateTime.parse(joinedOnRaw.toString()).toLocal());
      } catch (_) {
        joinedOnDisplay = joinedOnRaw.toString();
      }
    }

    final lastLoginStr = _profile['last_login'] ?? _profile['last_sign_in_at'];
    String lastLoginFormatted = 'N/A';
    if (lastLoginStr != null) {
      try {
        lastLoginFormatted = DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(lastLoginStr.toString()).toLocal());
      } catch (_) {
        lastLoginFormatted = lastLoginStr.toString();
      }
    }

    final statusDisplay = _profile['status'] != null ? _profile['status'].toString().toUpperCase() : 'ACTIVE';
    final avatarUrl = _profile['avatar_url'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final showFlex = constraints.maxWidth > 800;

              Widget leftSide = Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [roleBadgeColor, roleBadgeColor.withValues(alpha: 0.5)],
                          ),
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                        child: ClipOval(
                          child: _isUploadingAvatar
                              ? const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : avatarUrl != null && avatarUrl.toString().isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl.toString(),
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _buildAvatarFallback(),
                                    )
                                  : _buildAvatarFallback(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: roleBadgeColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _profile['full_name'] ?? 'User',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleBadgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: roleBadgeColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                displayRole,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: roleBadgeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _profile['email'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Online',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (rawRole == 'student' && (_profile['class'] != null || _profile['roll_number'] != null)) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  '• Class: ${_profile['class'] ?? 'N/A'} | Roll: ${_profile['roll_number'] ?? 'N/A'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (rawRole == 'teacher' && _profile['specialization'] != null) ...[
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  '• ${_profile['specialization']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              Widget rightSide = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryMetaRow(isDark, Icons.badge_outlined, 'User ID', userIdDisplay.toString()),
                  _buildSummaryMetaRow(isDark, Icons.person_outline, 'Role', displayRole),
                  _buildSummaryMetaRow(isDark, Icons.corporate_fare_rounded, 'Department', departmentDisplay.toString()),
                  _buildSummaryMetaRow(isDark, Icons.calendar_today_outlined, 'Joined On', joinedOnDisplay),
                  _buildSummaryMetaRow(isDark, Icons.access_time_rounded, 'Last Login', lastLoginFormatted),
                  _buildSummaryMetaRow(isDark, Icons.check_circle_outline_rounded, 'Status', statusDisplay, isBadge: true),
                ],
              );

              if (showFlex) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftSide),
                    Container(height: 120, width: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: rightSide),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftSide,
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    rightSide,
                  ],
                );
              }
            },
          ),

          // Role-specific quick stats badge bar
          if (rawRole == 'student' || rawRole == 'teacher') ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: rawRole == 'student'
                    ? [
                        _buildStatItem('Avg Score', '${_profile['avg_score'] ?? '0'}%', const Color(0xFF4F46E5)),
                        _buildStatItem('Attendance', '${_profile['attendance_pct'] ?? '0'}%', const Color(0xFF10B981)),
                        _buildStatItem('Class Rank', _profile['rank'] ?? '-', const Color(0xFFF59E0B)),
                        _buildStatItem('House', _profile['house'] != null && _profile['house'].toString().isNotEmpty ? _profile['house'] : 'Alpha', const Color(0xFFEC4899)),
                      ]
                    : [
                        _buildStatItem('Experience', '${_profile['experience_years'] ?? '0'} Years', const Color(0xFF0284C7)),
                        _buildStatItem('Classes', '${(_profile['classes'] as List<dynamic>?)?.length ?? 1}', const Color(0xFF10B981)),
                        _buildStatItem('Specialization', _profile['specialization'] != null && _profile['specialization'].toString().isNotEmpty ? _profile['specialization'] : 'Faculty', const Color(0xFFF59E0B)),
                        _buildStatItem('Streak', '${_profile['streak_count'] ?? 1} Days', const Color(0xFFEC4899)),
                      ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final name = (_profile['full_name'] ?? 'U').toString().trim();
    final initials = name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Center(
      child: Text(
        initials.isEmpty ? 'U' : initials,
        style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSummaryMetaRow(bool isDark, IconData icon, String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white60 : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: isBadge
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          value,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletionCard(bool isDark) {
    final meta = _calculateRoleCompletion();
    final double completion = meta['ratio'] as double;
    final int pct = meta['percentage'] as int;
    final String missing = meta['missing'] as String;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '$pct%',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: pct == 100 ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completion,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                pct == 100 ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                pct == 100 ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 14,
                color: pct == 100 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  missing,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: pct == 100 ? const Color(0xFF10B981) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedFormSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF4F46E5),
            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF4F46E5),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.person_outline_rounded, size: 16), text: 'Personal Information'),
              Tab(icon: Icon(Icons.family_restroom_rounded, size: 16), text: 'Family & Guardian'),
              Tab(icon: Icon(Icons.contact_mail_outlined, size: 16), text: 'Contact Information'),
              Tab(icon: Icon(Icons.folder_shared_outlined, size: 16), text: 'Documents & Records'),
              Tab(icon: Icon(Icons.tune_rounded, size: 16), text: 'Preferences'),
              Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Activity Log'),
            ],
          ),
          SizedBox(
            height: 640,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalInfoTab(isDark),
                _buildFamilyGuardianTab(isDark),
                _buildContactInfoTab(isDark),
                _buildDocumentsTab(isDark),
                _buildPreferencesTab(isDark),
                _buildActivityLogTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Personal Information ───────────────────────────────────────────
  Widget _buildPersonalInfoTab(bool isDark) {
    final rawRole = _profile['role']?.toString().toLowerCase() ?? 'user';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMultiCol = constraints.maxWidth >= 750;

          Widget formFields = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Details',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, 'Full Name', _fullNameController, forceReadOnly: !_isEditing),
                _buildInputField(isDark, 'Username', _usernameController, forceReadOnly: true),
              ]),
              const SizedBox(height: 16),
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, 'Email Address', _emailController, forceReadOnly: true),
                _buildInputField(isDark, 'Phone Number', _phoneController, forceReadOnly: !_isEditing),
              ]),
              const SizedBox(height: 16),
              _buildResponsiveRow(isDark, [
                _buildDatePickerField(isDark, 'Date of Birth', _dobController),
                _buildDropdownField(isDark, 'Gender', _selectedGender, _validGenders, (val) {
                  setState(() => _selectedGender = val!);
                }),
              ]),
              const SizedBox(height: 16),
              _buildResponsiveRow(isDark, [
                _buildDropdownField(isDark, 'Blood Group', _selectedBloodGroup, _validBloodGroups, (val) {
                  setState(() => _selectedBloodGroup = val!);
                }),
                _buildInputField(isDark, 'Nationality', _nationalityController, forceReadOnly: !_isEditing),
              ]),
              const SizedBox(height: 16),
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, 'Religion', _religionController, forceReadOnly: !_isEditing),
                _buildInputField(isDark, 'Category', _categoryController, forceReadOnly: !_isEditing),
              ]),

              // Academic & Professional Fields
              if (rawRole == 'student' || rawRole == 'teacher') ...[
                const SizedBox(height: 24),
                Text(
                  rawRole == 'student' ? 'Academic Information' : 'Professional Qualifications',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                if (rawRole == 'student') ...[
                  _buildResponsiveRow(isDark, [
                    _buildInputField(isDark, 'Class', _classNameController, forceReadOnly: true),
                    _buildInputField(isDark, 'Roll Number', _rollNumberController, forceReadOnly: true),
                  ]),
                  const SizedBox(height: 16),
                  _buildResponsiveRow(isDark, [
                    _buildInputField(isDark, 'Academic Session', _sessionController, forceReadOnly: true),
                    _buildInputField(isDark, 'Admission Number', _admissionNumberController, forceReadOnly: true),
                  ]),
                  const SizedBox(height: 16),
                  _buildResponsiveRow(isDark, [
                    _buildInputField(isDark, 'House Team', _houseController, forceReadOnly: !_isEditing),
                    _buildInputField(isDark, 'Alternative ID', _usernameController, forceReadOnly: true),
                  ]),
                ] else ...[
                  _buildResponsiveRow(isDark, [
                    _buildInputField(isDark, 'Highest Qualification', _qualificationController, forceReadOnly: !_isEditing),
                    _buildInputField(isDark, 'Experience (Years)', _experienceYearsController, forceReadOnly: !_isEditing),
                  ]),
                  const SizedBox(height: 16),
                  _buildResponsiveRow(isDark, [
                    _buildInputField(isDark, 'Subject / Faculty Specialization', _specializationController, forceReadOnly: !_isEditing),
                    _buildInputField(isDark, 'Academic Department', _classNameController, forceReadOnly: true),
                  ]),
                ],
              ],

              const SizedBox(height: 24),
              if (_isEditing)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _updateProfile,
                  child: const Text('Update Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          );

          Widget sideCard = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAboutMeCard(isDark),
              const SizedBox(height: 16),
              _buildAccountMetaPills(isDark),
            ],
          );

          if (isMultiCol) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: formFields),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: sideCard),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sideCard,
              const SizedBox(height: 20),
              formFields,
            ],
          );
        },
      ),
    );
  }

  // ── Tab 2: Family & Guardian Information ───────────────────────────────────
  Widget _buildFamilyGuardianTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.family_restroom_rounded, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 8),
              Text(
                'Parent & Guardian Details',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep parents and designated guardians updated for academic correspondence, attendance, and emergency SOS alerts.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Father's Information
          _buildDetailCard(
            isDark: isDark,
            title: "Father's Information",
            icon: Icons.person_rounded,
            iconColor: const Color(0xFF3B82F6),
            actionWidget: _fatherPhoneController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Call Father',
                    icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFF3B82F6)),
                    onPressed: () => _launchOrCopy(_fatherPhoneController.text, 'phone'),
                  )
                : null,
            children: [
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, "Father's Full Name", _fatherNameController, forceReadOnly: !_isEditing),
                _buildInputField(isDark, "Father's Occupation", _fatherOccupationController, forceReadOnly: !_isEditing),
              ]),
              const SizedBox(height: 14),
              _buildInputField(isDark, "Father's Phone Number", _fatherPhoneController, forceReadOnly: !_isEditing),
            ],
          ),
          const SizedBox(height: 16),

          // Mother's Information
          _buildDetailCard(
            isDark: isDark,
            title: "Mother's Information",
            icon: Icons.person_3_rounded,
            iconColor: const Color(0xFFEC4899),
            actionWidget: _motherPhoneController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Call Mother',
                    icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFFEC4899)),
                    onPressed: () => _launchOrCopy(_motherPhoneController.text, 'phone'),
                  )
                : null,
            children: [
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, "Mother's Full Name", _motherNameController, forceReadOnly: !_isEditing),
                _buildInputField(isDark, "Mother's Occupation", _motherOccupationController, forceReadOnly: !_isEditing),
              ]),
              const SizedBox(height: 14),
              _buildInputField(isDark, "Mother's Phone Number", _motherPhoneController, forceReadOnly: !_isEditing),
            ],
          ),
          const SizedBox(height: 16),

          // Local Guardian Information
          _buildDetailCard(
            isDark: isDark,
            title: "Designated Local Guardian & Alternate Contact",
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF10B981),
            actionWidget: _guardianPhoneController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Call Guardian',
                    icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFF10B981)),
                    onPressed: () => _launchOrCopy(_guardianPhoneController.text, 'phone'),
                  )
                : null,
            children: [
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, "Guardian Name", _guardianNameController, forceReadOnly: !_isEditing),
                _buildDropdownField(isDark, "Relationship to Student", _selectedGuardianRelation, _guardianRelations, (val) {
                  setState(() => _selectedGuardianRelation = val!);
                }),
              ]),
              const SizedBox(height: 14),
              _buildResponsiveRow(isDark, [
                _buildInputField(isDark, "Guardian Phone", _guardianPhoneController, forceReadOnly: !_isEditing),
                _buildInputField(isDark, "Guardian Email", _guardianEmailController, forceReadOnly: !_isEditing),
              ]),
              const SizedBox(height: 14),
              _buildInputField(isDark, "Guardian Residential Address", _guardianAddressController, maxLines: 2, forceReadOnly: !_isEditing),
            ],
          ),
          const SizedBox(height: 24),

          if (_isEditing)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _updateProfile,
              child: const Text('Save Family Information', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ── Tab 3: Contact Information ─────────────────────────────────────────────
  Widget _buildContactInfoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Structured Residential Address',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Used for formal correspondence, transport pickup point assignment, and emergency services.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildResponsiveRow(isDark, [
            _buildInputField(isDark, 'Address Line 1 (Flat/House/Street)', _addressLine1Controller, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'Address Line 2 (Apartment/Landmark)', _addressLine2Controller, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 16),
          _buildResponsiveRow(isDark, [
            _buildInputField(isDark, 'City', _cityController, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'State / Province', _stateController, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 16),
          _buildResponsiveRow(isDark, [
            _buildInputField(isDark, 'Postal / Pin Code', _pincodeController, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'Country', _countryController, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 24),

          Text(
            'Alternative & Emergency Contacts',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildResponsiveRow(isDark, [
            _buildInputField(isDark, 'Alternative Email', _altEmailController, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'Alternative Phone', _altPhoneController, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 16),
          _buildResponsiveRow(isDark, [
            _buildInputField(isDark, 'Emergency Contact Person', _emergencyNameController, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'Relationship (e.g. Uncle/Doctor)', _emergencyRelationController, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 16),
          _buildInputField(isDark, 'Emergency Contact Phone Number', _emergencyPhoneController, forceReadOnly: !_isEditing),
          const SizedBox(height: 24),

          if (_isEditing)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _updateProfile,
              child: const Text('Save Contact Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // ── Tab 4: Documents & Records ─────────────────────────────────────────────
  Widget _buildDocumentsTab(bool isDark) {
    final rawRole = _profile['role']?.toString().toLowerCase() ?? 'user';
    final List<String> standardTypes = rawRole == 'student'
        ? [
            'Birth Certificate',
            'Aadhaar / National ID Card',
            'Previous Marksheet',
            'Migration Certificate',
            'Character Certificate',
          ]
        : rawRole == 'teacher'
            ? [
                'Degree / Graduation Certificate',
                'B.Ed / Teaching Credential',
                'National ID Proof',
                'Experience Certificate',
                'Police Clearance Record',
              ]
        : [
            'Government Photo ID Proof',
            'Appointment / Contract Letter',
            'Address Proof',
          ];

    final uploadedMap = {for (var d in _documents) (d['document_type'] ?? ''): d};

    // Filter out standard types to see custom documents
    final customDocs = _documents.where((d) => !standardTypes.contains(d['document_type'])).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Documents & Records',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Upload certified documents (PDF, JPG, PNG under 10MB).',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isUploadingDocument)
                    const Padding(
                      padding: EdgeInsets.only(right: 12.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                      ),
                    ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Upload Custom Document', style: TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: _showCustomDocumentUploadDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Standard Document Types
          ...standardTypes.map((docType) {
            final doc = uploadedMap[docType];
            return _buildDocumentRow(isDark, docType, doc);
          }),

          // Custom Uploaded Documents
          if (customDocs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Additional & Custom Records',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...customDocs.map((doc) {
              return _buildDocumentRow(isDark, doc['document_type'] ?? 'Custom Document', doc);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentRow(bool isDark, String docType, dynamic doc) {
    final bool hasDoc = doc != null;
    final status = doc?['verification_status'] ?? 'missing';
    final fileSize = doc?['file_size'];
    String sizeText = '';
    if (fileSize != null && fileSize is num && fileSize > 0) {
      if (fileSize > 1024 * 1024) {
        sizeText = ' • ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeText = ' • ${(fileSize / 1024).toStringAsFixed(0)} KB';
      }
    }

    final rejectionReason = doc?['rejection_reason'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasDoc ? Icons.description_rounded : Icons.file_upload_outlined,
                color: hasDoc ? const Color(0xFF4F46E5) : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docType,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    if (hasDoc)
                      Text(
                        '${doc['file_name'] ?? 'Uploaded Document'}$sizeText',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              _buildDocStatusPill(status),
              const SizedBox(width: 12),
              if (hasDoc) ...[
                IconButton(
                  tooltip: 'Preview / Download',
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF4F46E5)),
                  onPressed: () => _previewDocument(doc),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                  onPressed: () => _deleteDocument(doc['id'], docType),
                ),
              ] else ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.upload_rounded, size: 14, color: Colors.white),
                  label: const Text('Upload', style: TextStyle(color: Colors.white, fontSize: 11)),
                  onPressed: () => _pickAndUploadDocument(docType),
                ),
              ],
            ],
          ),
          if (rejectionReason != null && rejectionReason.toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rejection reason: $rejectionReason',
                      style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocStatusPill(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'verified':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF10B981);
        label = 'Verified';
        break;
      case 'pending':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        label = 'Pending';
        break;
      case 'rejected':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        fg = const Color(0xFFEF4444);
        label = 'Rejected';
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey;
        label = 'Missing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: fg, fontWeight: FontWeight.bold)),
    );
  }

  // ── Tab 5: Preferences ─────────────────────────────────────────────────────
  Widget _buildPreferencesTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Notification & Interface Preferences',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure your localized preferences. Changes to notification switches and theme apply immediately.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          _buildResponsiveRow(isDark, [
            _buildDropdownField(isDark, 'Interface Language', _selectedLanguage, _validLanguages, (val) {
              setState(() => _selectedLanguage = val!);
              _updateQuickPreferences(language: val);
            }),
            _buildDropdownField(isDark, 'System Timezone', _selectedTimezone, _validTimezones, (val) {
              setState(() => _selectedTimezone = val!);
              _updateQuickPreferences(timezone: val);
            }),
          ]),
          const SizedBox(height: 16),

          _buildPreferenceSwitch(
            isDark,
            'Email Notifications',
            'Receive academic bulletins, exam schedules, security alerts, and attendance summaries via email.',
            _emailNotifications,
            (val) {
              setState(() => _emailNotifications = val);
              _updateQuickPreferences(email: val);
            },
          ),
          _buildPreferenceSwitch(
            isDark,
            'SMS Alerts',
            'Receive emergency SOS events, fee receipts, and security login triggers directly on your phone.',
            _smsAlerts,
            (val) {
              setState(() => _smsAlerts = val);
              _updateQuickPreferences(sms: val);
            },
          ),
          _buildPreferenceSwitch(
            isDark,
            'Push Notifications',
            'Receive live notifications in the app and browser session dashboard in real-time.',
            _pushNotifications,
            (val) {
              setState(() => _pushNotifications = val);
              _updateQuickPreferences(push: val);
            },
          ),
          _buildPreferenceSwitch(
            isDark,
            'Weekly Performance Digest',
            'Automatically generate and receive weekly academic, attendance, and activity reports.',
            _weeklyReports,
            (val) {
              setState(() => _weeklyReports = val);
              _updateQuickPreferences(weekly: val);
            },
          ),
        ],
      ),
    );
  }

  // ── Tab 6: Activity Log ────────────────────────────────────────────────────
  Widget _buildActivityLogTab(bool isDark) {
    final filteredLogs = _selectedLogModule == 'All'
        ? _logs
        : _logs.where((l) => (l['module'] ?? '').toString().toLowerCase() == _selectedLogModule.toLowerCase()).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Audit Trail History (${filteredLogs.length})',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedLogModule,
                underline: const SizedBox(),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
                items: ['All', 'Profile', 'Authentication', 'System', 'Academics'].map((m) {
                  return DropdownMenuItem(value: m, child: Text('Filter: $m'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLogModule = val);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text('No activity logs found for $_selectedLogModule.', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final log = filteredLogs[idx];
                    final timeStr = log['created_at'] != null
                        ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(log['created_at']).toLocal())
                        : '';

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_toggle_off_rounded, size: 16, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['action'] ?? log['event_type'] ?? 'Action',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'IP: ${log['ip_address'] ?? '127.0.0.1'} | Module: ${log['module'] ?? 'System'}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          timeStr,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildDetailCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
    Widget? actionWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (actionWidget != null) actionWidget,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitch(bool isDark, String title, String subtitle, bool val, ValueChanged<bool>? onChange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: val,
            onChanged: onChange,
            activeThumbColor: const Color(0xFF4F46E5),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveRow(bool isDark, List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: c,
                    ))
                .toList(),
          );
        }
        return Row(
          children: children
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildInputField(
    bool isDark,
    String label,
    TextEditingController controller, {
    bool forceReadOnly = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: forceReadOnly,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
          decoration: InputDecoration(
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            filled: true,
            hintText: 'Enter $label',
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    bool isDark,
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              isExpanded: true,
              items: items.map((val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
              onChanged: !_isEditing ? null : onChange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(bool isDark, String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
          decoration: InputDecoration(
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            filled: true,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onTap: !_isEditing
              ? null
              : () async {
                  DateTime initDate = DateTime.now();
                  try {
                    if (controller.text.isNotEmpty) {
                      if (controller.text.contains('/')) {
                        final p = controller.text.split('/');
                        if (p.length == 3) {
                          initDate = DateTime(int.parse(p[2]), int.parse(p[0]), int.parse(p[1]));
                        }
                      } else if (controller.text.contains('-')) {
                        initDate = DateTime.parse(controller.text);
                      }
                    }
                  } catch (_) {}

                  final date = await showDatePicker(
                    context: context,
                    initialDate: initDate.isAfter(DateTime.now()) ? DateTime.now() : initDate,
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    controller.text = DateFormat('MM/dd/yyyy').format(date);
                  }
                },
        ),
      ],
    );
  }

  Widget _buildAboutMeCard(bool isDark) {
    final joiningDate = _profile['joining_date'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(_profile['joining_date']))
        : 'Jan 01, 2023';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Me',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            readOnly: !_isEditing,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: _isEditing ? const EdgeInsets.all(8) : EdgeInsets.zero,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              filled: _isEditing,
              border: _isEditing ? OutlineInputBorder(borderRadius: BorderRadius.circular(6)) : InputBorder.none,
              hintText: 'Tell us about yourself...',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Member Since', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              Text(joiningDate, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Account Role', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (_profile['role'] ?? 'user').toString().toUpperCase(),
                  style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMetaPills(bool isDark) {
    final emailVerified = _profile['email_verified'] ?? true;
    final phoneVerified = _profile['phone_verified'] ?? false;
    final twoFactorEnabled = _profile['two_factor_enabled'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security & Trust Badges',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _buildTrustRow('Email Verification', emailVerified, Icons.mark_email_read_rounded),
          const SizedBox(height: 8),
          _buildTrustRow('Phone Verification', phoneVerified, Icons.phone_android_rounded),
          const SizedBox(height: 8),
          _buildTrustRow('Two-Factor Authentication', twoFactorEnabled, Icons.verified_user_rounded),
        ],
      ),
    );
  }

  Widget _buildTrustRow(String label, bool isVerified, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isVerified ? const Color(0xFF10B981) : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (isVerified ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isVerified ? 'VERIFIED' : 'UNVERIFIED',
            style: TextStyle(
              color: isVerified ? const Color(0xFF10B981) : Colors.grey,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ── Right Side Cards ──────────────────────────────────────────────────────
  Widget _buildSecurityCard(bool isDark) {
    final twoFactorEnabled = _profile['two_factor_enabled'] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Security',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Password', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  const Text('••••••••', style: TextStyle(color: Colors.grey)),
                ],
              ),
              TextButton(
                onPressed: _showChangePasswordDialog,
                child: const Text('Change', style: TextStyle(color: Color(0xFF4F46E5))),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Two-Factor Authentication', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(
                    twoFactorEnabled ? 'TOTP Enabled (Authenticator App)' : 'Disabled',
                    style: TextStyle(color: twoFactorEnabled ? const Color(0xFF10B981) : Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              Switch(
                value: twoFactorEnabled,
                onChanged: (enabled) {
                  if (enabled) {
                    _start2FASetupFlow();
                  } else {
                    _disable2FA();
                  }
                },
                activeThumbColor: const Color(0xFF10B981),
              ),
            ],
          ),
          const Divider(),
          _buildSecurityStatRow(isDark, 'Login Devices', '${_sessions.length} Devices'),
          _buildSecurityStatRow(isDark, 'Active Sessions', '${_sessions.where((s) => s['expires_at'] != null).length} Sessions'),
          const SizedBox(height: 12),
          InkWell(
            onTap: _showManageSessionsDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Manage Security',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginActivityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Login Activity',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: _showManageSessionsDialog,
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: Text('No active sessions found.', style: TextStyle(color: Colors.grey))),
            )
          else
            ..._sessions.take(4).map((session) {
              final isCurrent = session['is_current'] == true || session == _sessions.first;
              final lastActive = session['last_active'] != null
                  ? DateTime.parse(session['last_active'])
                  : DateTime.now();

              final difference = DateTime.now().difference(lastActive);
              String timeAgo = 'Just now';
              if (difference.inHours > 0) {
                timeAgo = '${difference.inHours} hours ago';
              } else if (difference.inMinutes > 0) {
                timeAgo = '${difference.inMinutes} minutes ago';
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Icon(
                      session['device_name'] == 'Windows' || session['device_name'] == 'MacOS'
                          ? Icons.laptop_chromebook_rounded
                          : Icons.phone_android_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${session['device_name'] ?? 'Device'} • ${session['browser_name'] ?? 'Browser'}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            session['location'] ?? 'Local Network',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (isCurrent)
                      const Text(
                        'Active now',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                      )
                    else ...[
                      Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFEF4444)),
                        onPressed: () => _revokeSession(session['id']),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionItem(Icons.lock_open_rounded, 'Change Password', _showChangePasswordDialog),
          _buildQuickActionItem(
            Icons.verified_user_outlined,
            'Manage Two-Factor Authentication',
            () {
              if ((_profile['two_factor_enabled'] ?? false) == true) {
                _disable2FA();
              } else {
                _start2FASetupFlow();
              }
            },
          ),
          _buildQuickActionItem(Icons.devices_other_rounded, 'Manage Active Sessions', _showManageSessionsDialog),
          _buildQuickActionItem(Icons.cloud_download_outlined, 'Download My Data (GDPR)', _downloadMyData),
          _buildQuickActionItem(
            Icons.logout_rounded,
            'Sign Out',
            () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        title: Text(title, style: GoogleFonts.inter(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildRecentActivitySection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Account Activity',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () {
                  final rawRole = _profile['role']?.toString().toLowerCase();
                  if (rawRole == 'super_admin' || rawRole == 'admin') {
                    context.go('/admin/audit-log?search=${_profile['email'] ?? ''}');
                  } else {
                    _tabController.animateTo(5);
                  }
                },
                child: Text(
                  'View All Activity',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF4F46E5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_logs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: Text('No recent account activity logged.', style: TextStyle(color: Colors.grey))),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                  ),
                  children: [
                    _buildTableHeader(isDark, 'Activity'),
                    _buildTableHeader(isDark, 'Description'),
                    _buildTableHeader(isDark, 'IP Address'),
                    _buildTableHeader(isDark, 'Status'),
                    _buildTableHeader(isDark, 'Date & Time'),
                  ],
                ),
                ..._logs.take(6).map((log) {
                  final dateStr = log['created_at'] != null
                      ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(log['created_at']).toLocal())
                      : '';

                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9))),
                    ),
                    children: [
                      _buildTableCell(isDark, log['event_type'] ?? 'Log', isBold: true),
                      _buildTableCell(isDark, log['action'] ?? ''),
                      _buildTableCell(isDark, log['ip_address'] ?? '127.0.0.1'),
                      _buildTableCell(isDark, log['status'] ?? 'Success'),
                      _buildTableCell(isDark, dateStr),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white60 : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildTableCell(bool isDark, String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isDark ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }
}

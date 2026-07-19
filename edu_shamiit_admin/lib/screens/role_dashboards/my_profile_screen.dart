import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
// Conditional import for Flutter Web
import 'dart:html' as html;

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _errorMessage;

  // Profile data
  Map<String, dynamic> _profile = {};
  List<dynamic> _sessions = [];
  List<dynamic> _logs = [];

  // Controllers for Personal Info
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _bioController = TextEditingController();
  
  String _selectedGender = 'Prefer not to say';
  String _selectedLanguage = 'English (US)';
  String _selectedTimezone = '(GMT +05:30) Asia/Kolkata';

  // Contact Info
  final _addressController = TextEditingController();
  final _altEmailController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  // Preferences
  bool _emailNotifications = true;
  bool _smsAlerts = false;
  bool _pushNotifications = true;
  bool _weeklyReports = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    _addressController.dispose();
    _altEmailController.dispose();
    _altPhoneController.dispose();
    _emergencyNameController.dispose();
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
          
          // Populate controllers
          _fullNameController.text = profileData['full_name'] ?? '';
          _usernameController.text = profileData['email'] != null ? profileData['email'].toString().split('@')[0] : '';
          _emailController.text = profileData['email'] ?? '';
          _phoneController.text = profileData['phone'] ?? '';
          _dobController.text = profileData['date_of_birth'] ?? '01/01/1990';
          _bioController.text = profileData['bio'] ?? 'System administrator with full access to manage all modules, users, and system settings.';
          
          _selectedGender = profileData['gender'] ?? 'Prefer not to say';
          _selectedLanguage = profileData['specialization'] ?? 'English (US)';
          _selectedTimezone = profileData['address'] ?? '(GMT +05:30) Asia/Kolkata';
          
          _emailNotifications = profileData['email_notifications'] ?? true;
          _smsAlerts = profileData['sms_alerts'] ?? false;
          _pushNotifications = profileData['push_notifications'] ?? true;
          _weeklyReports = profileData['weekly_reports'] ?? true;

          _isLoading = false;
        });

        // Sync the authProvider so sidebar & other screens reflect the latest
        // avatar, name, etc. without needing a logout/login.
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
        'fullName': _fullNameController.text,
        'phone': _phoneController.text,
        'gender': _selectedGender,
        'dateOfBirth': _dobController.text,
        'bio': _bioController.text,
        'language': _selectedLanguage,
        'timezone': _selectedTimezone,
        // Contact details
        'address': _addressController.text,
        'alternativeEmail': _altEmailController.text,
        'alternativePhone': _altPhoneController.text,
        'emergencyContactName': _emergencyNameController.text,
        'emergencyContactPhone': _emergencyPhoneController.text,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() {
          _isEditing = false;
        });
        await _fetchProfileData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['detail'] ?? 'Failed to update profile.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
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

  Future<void> _pickAndUploadImage(String fileType) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1000, imageQuality: 90);
      if (image == null) return;

      final croppedBytes = await _cropImage(image.path);
      if (croppedBytes == null) return; // User cancelled crop

      setState(() => _isLoading = true);

      final res = await ApiService().multipartPostBytes(
        '/admin/system-config/upload?file_type=$fileType',
        croppedBytes,
        image.name,
        'file',
      );

      if (res['success'] == true && res['data'] != null) {
        final url = res['data']['url'];
        // Update user profile on backend with new avatarUrl
        await ApiService().post('/admin/schools/my-profile/update', {
          'fullName': _fullNameController.text,
          'phone': _phoneController.text,
          'gender': _selectedGender,
          'dateOfBirth': _dobController.text,
          'bio': _bioController.text,
          'language': _selectedLanguage,
          'timezone': _selectedTimezone,
          'address': _addressController.text,
          'alternativeEmail': _altEmailController.text,
          'alternativePhone': _altPhoneController.text,
          'emergencyContactName': _emergencyNameController.text,
          'emergencyContactPhone': _emergencyPhoneController.text,
          'emailNotifications': _emailNotifications,
          'smsAlerts': _smsAlerts,
          'pushNotifications': _pushNotifications,
          'weeklyReports': _weeklyReports,
          'avatarUrl': url,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded and updated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        await _fetchProfileData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _toggle2FA(bool enabled) async {
    try {
      final res = await ApiService().post('/admin/schools/my-profile/two-factor', {'enabled': enabled});
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Two-Factor Authentication ${enabled ? "enabled" : "disabled"} successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await _fetchProfileData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update 2FA: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _revokeSession(String sessionId) async {
    try {
      final res = await ApiService().post('/admin/schools/my-profile/revoke-session', {'sessionId': sessionId});
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session revoked successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        await _fetchProfileData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to revoke session: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _downloadMyData() {
    try {
      final dump = {
        'profile': _profile,
        'sessions': _sessions,
        'logs': _logs,
      };
      
      final csvString = const JsonEncoder.withIndent('  ').convert(dump);
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = 'my_profile_data_export.json';
      
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data exported successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export data: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;

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
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      hintText: 'Enter current password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Enter new password',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Re-enter new password',
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
                  onPressed: isSaving ? null : () async {
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
                      final res = await ApiService().post('/shared/user/change-password', {
                        'currentPassword': currentPasswordController.text,
                        'newPassword': newPasswordController.text,
                      });
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated successfully!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.toString().replaceAll('ApiException: ', '')),
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
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
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Login Sessions',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (_sessions.length > 1)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                      icon: const Icon(Icons.logout_rounded, size: 14),
                      label: const Text('Revoke Other Devices', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final otherSessions = _sessions.where((s) => s['token'] != 'sess_win').toList();
                        for (final s in otherSessions) {
                          await ApiService().post('/admin/schools/my-profile/revoke-session', {'sessionId': s['id']});
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All other sessions revoked successfully!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                        await _fetchProfileData();
                      },
                    ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _sessions.isEmpty
                        ? [const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No active sessions found.', style: TextStyle(color: Colors.grey)))]
                        : _sessions.map((session) {
                            final isCurrent = session['token'] == 'sess_win';
                            final lastActive = session['last_active'] != null ? DateTime.parse(session['last_active']) : DateTime.now();
                            final difference = DateTime.now().difference(lastActive);
                            String timeAgo = 'Just now';
                            if (difference.inHours > 0) {
                              timeAgo = '${difference.inHours} hours ago';
                            } else if (difference.inMinutes > 0) {
                              timeAgo = '${difference.inMinutes} minutes ago';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                                          'IP: ${session['ip_address'] ?? '127.0.0.1'} • ${session['location'] ?? 'Unknown Location'}',
                                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    const Text(
                                      'Current',
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                                    )
                                  else
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        foregroundColor: const Color(0xFFEF4444),
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _revokeSession(session['id']);
                                      },
                                      child: const Text('Revoke', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                  ),
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
      },
    );
  }

  void _showAvatarSelector() {
    final avatarUrls = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=150',
      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=150',
      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=150',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=150',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=150',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Avatar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: avatarUrls.map((url) {
                return InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      await ApiService().post('/admin/schools/my-profile/update', {
                        'fullName': _fullNameController.text,
                        'phone': _phoneController.text,
                        'gender': _selectedGender,
                        'dateOfBirth': _dobController.text,
                        'bio': _bioController.text,
                        'language': _selectedLanguage,
                        'timezone': _selectedTimezone,
                        'avatarUrl': url,
                      });
                      await _fetchProfileData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update avatar: $e')),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(url),
                    radius: 36,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchProfileData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width >= 1100;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumbs Title
            Row(
              children: [
                Text(
                  'Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                      'View and manage your personal information and account settings.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
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
                        // Reset form fields
                        _fullNameController.text = _profile['full_name'] ?? '';
                        _phoneController.text = _profile['phone'] ?? '';
                        _dobController.text = _profile['date_of_birth'] ?? '01/01/1990';
                        _bioController.text = _profile['bio'] ?? '';
                        _selectedGender = _profile['gender'] ?? 'Prefer not to say';
                        _selectedLanguage = _profile['specialization'] ?? 'English (US)';
                        _selectedTimezone = _profile['address'] ?? '(GMT +05:30) Asia/Kolkata';
                      }
                      _isEditing = !_isEditing;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Header Profile details card
            _buildProfileSummaryCard(isDark),
            const SizedBox(height: 24),

            // Adaptive layout body
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
    final joiningDate = _profile['joining_date'] != null
        ? DateFormat('MMM dd, yyyy').format(DateTime.parse(_profile['joining_date']))
        : 'Jan 01, 2023';

    final lastLoginStr = _profile['last_login'];
    String lastLoginFormatted = '--';
    if (lastLoginStr != null) {
      try {
        lastLoginFormatted = DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(lastLoginStr).toLocal());
      } catch (_) {
        lastLoginFormatted = lastLoginStr;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showFlex = constraints.maxWidth > 800;
          final avatarUrl = _profile['avatar_url'];
          
          Widget leftSide = Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            _profile['full_name'] != null ? _profile['full_name'].substring(0, 2).toUpperCase() : 'SA',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4F46E5),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _pickAndUploadImage("avatar"),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _profile['full_name'] ?? 'Super Admin',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Super Admin',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _profile['email'] ?? 'superadmin@schoolerp.com',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                            fontSize: 12,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
              _buildSummaryMetaRow(isDark, Icons.badge_outlined, 'User ID', 'ADM001'),
              _buildSummaryMetaRow(isDark, Icons.person_outline, 'Role', 'Super Administrator'),
              _buildSummaryMetaRow(isDark, Icons.domain_outlined, 'Department', 'System Administration'),
              _buildSummaryMetaRow(isDark, Icons.calendar_today_outlined, 'Joined On', '$joiningDate 10:30 AM'),
              _buildSummaryMetaRow(isDark, Icons.history_toggle_off_rounded, 'Last Login', lastLoginFormatted),
              _buildSummaryMetaRow(isDark, Icons.check_circle_outline_rounded, 'Status', 'Active', isBadge: true),
            ],
          );

          if (showFlex) {
            return Row(
              children: [
                Expanded(flex: 5, child: leftSide),
                Container(
                  height: 120,
                  width: 1,
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),
                Expanded(flex: 5, child: rightSide),
              ],
            );
          } else {
            return Column(
              children: [
                leftSide,
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                rightSide,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryMetaRow(bool isDark, IconData icon, String label, String value, {bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.white60 : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
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
            labelColor: const Color(0xFF4F46E5),
            unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
            indicatorColor: const Color(0xFF4F46E5),
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(text: 'Personal Information'),
              Tab(text: 'Contact Information'),
              Tab(text: 'Preferences'),
              Tab(text: 'Activity Log'),
            ],
          ),
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalInfoTab(isDark),
                _buildContactInfoTab(isDark),
                _buildPreferencesTab(isDark),
                _buildActivityLogTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Column(
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
                _buildFormRow(isDark, [
                  _buildInputField(isDark, 'Full Name', _fullNameController, forceReadOnly: !_isEditing),
                  _buildInputField(isDark, 'Username', _usernameController, forceReadOnly: true),
                ]),
                const SizedBox(height: 16),
                _buildFormRow(isDark, [
                  _buildInputField(isDark, 'Email Address', _emailController, forceReadOnly: true),
                  _buildInputField(isDark, 'Phone Number', _phoneController, forceReadOnly: !_isEditing),
                ]),
                const SizedBox(height: 16),
                _buildFormRow(isDark, [
                  _buildDatePickerField(isDark, 'Date of Birth', _dobController),
                  _buildDropdownField(isDark, 'Gender', _selectedGender, ['Male', 'Female', 'Other', 'Prefer not to say'], (val) {
                    setState(() {
                      _selectedGender = val!;
                    });
                  }),
                ]),
                const SizedBox(height: 16),
                _buildFormRow(isDark, [
                  _buildDropdownField(isDark, 'Language', _selectedLanguage, ['English (US)', 'Hindi', 'Spanish', 'French'], (val) {
                    setState(() {
                      _selectedLanguage = val!;
                    });
                  }),
                  _buildDropdownField(isDark, 'Timezone', _selectedTimezone, [
                    '(GMT +05:30) Asia/Kolkata',
                    '(GMT +00:00) Europe/London',
                    '(GMT -05:00) America/New_York',
                    '(GMT +08:00) Asia/Shanghai'
                  ], (val) {
                    setState(() {
                      _selectedTimezone = val!;
                    });
                  }),
                ]),
                const SizedBox(height: 24),
                if (_isEditing)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _updateProfile,
                    child: const Text('Update Profile', style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAboutMeCard(isDark),
                const SizedBox(height: 16),
                _buildProfilePhotoCard(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Details',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField(isDark, 'Permanent Address', _addressController, maxLines: 2, forceReadOnly: !_isEditing),
          const SizedBox(height: 16),
          _buildFormRow(isDark, [
            _buildInputField(isDark, 'Alternative Email', _altEmailController, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'Alternative Phone', _altPhoneController, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 16),
          _buildFormRow(isDark, [
            _buildInputField(isDark, 'Emergency Contact Name', _emergencyNameController, forceReadOnly: !_isEditing),
            _buildInputField(isDark, 'Emergency Contact Phone', _emergencyPhoneController, forceReadOnly: !_isEditing),
          ]),
          const SizedBox(height: 24),
          if (_isEditing)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _updateProfile,
              child: const Text('Save Details', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

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
          const SizedBox(height: 16),
          _buildPreferenceSwitch(isDark, 'Email Notifications', 'Receive system alters, security logs, and digests via email.', _emailNotifications, !_isEditing ? null : (val) {
            setState(() {
              _emailNotifications = val;
            });
          }),
          _buildPreferenceSwitch(isDark, 'SMS Alerts', 'Receive critical system events and security login triggers via SMS.', _smsAlerts, !_isEditing ? null : (val) {
            setState(() {
              _smsAlerts = val;
            });
          }),
          _buildPreferenceSwitch(isDark, 'Push Notifications', 'Receive instant push updates in the browser session dashboard.', _pushNotifications, !_isEditing ? null : (val) {
            setState(() {
              _pushNotifications = val;
            });
          }),
          _buildPreferenceSwitch(isDark, 'Weekly System Digest', 'Automatically generate and receive weekly system activity reports.', _weeklyReports, !_isEditing ? null : (val) {
            setState(() {
              _weeklyReports = val;
            });
          }),
          const SizedBox(height: 24),
          if (_isEditing)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _updateProfile,
              child: const Text('Save Preferences', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityLogTab(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final log = _logs[idx];
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
                    log['action'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'IP Address: ${log['ip_address'] ?? '127.0.0.1'} | Module: ${log['module'] ?? ''}',
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

  Widget _buildFormRow(bool isDark, List<Widget> children) {
    return Row(
      children: children.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12.0), child: c))).toList(),
    );
  }

  Widget _buildInputField(bool isDark, String label, TextEditingController controller, {bool forceReadOnly = false, int maxLines = 1}) {
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

  Widget _buildDropdownField(bool isDark, String label, String value, List<String> items, ValueChanged<String?> onChange) {
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
          onTap: !_isEditing ? null : () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
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
              border: _isEditing 
                  ? OutlineInputBorder(borderRadius: BorderRadius.circular(6))
                  : InputBorder.none,
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
              Text('Account Type', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Super Admin', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePhotoCard(bool isDark) {
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
            'Profile Photo',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: !_isEditing ? null : () => _pickAndUploadImage("avatar"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, style: BorderStyle.none), // Dotted border simplified
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.upload_file_outlined, color: !_isEditing ? Colors.grey : const Color(0xFF4F46E5), size: 24),
                  const SizedBox(height: 8),
                  Text(
                    'Click to upload new photo',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: !_isEditing ? Colors.grey : const Color(0xFF4F46E5)),
                  ),
                  Text(
                    'JPG, PNG or GIF. Max size 2MB',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                    twoFactorEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(color: twoFactorEnabled ? const Color(0xFF10B981) : Colors.grey, fontSize: 11),
                  ),
                ],
              ),
              Switch(
                value: twoFactorEnabled,
                onChanged: _toggle2FA,
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
              Text(
                'View All',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold),
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
            ..._sessions.map((session) {
              final isCurrent = session['token'] == 'sess_win'; // Simulating primary session
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
                            session['location'] ?? 'Unknown Location',
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
                    ]
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
          _buildQuickActionItem(Icons.verified_user_outlined, 'Manage Two-Factor Authentication', () => _toggle2FA(!(_profile['two_factor_enabled'] ?? false))),
          _buildQuickActionItem(Icons.devices_other_rounded, 'Manage Active Sessions', _showManageSessionsDialog),
          _buildQuickActionItem(Icons.cloud_download_outlined, 'Download My Data', _downloadMyData),
          _buildQuickActionItem(
            Icons.logout_rounded,
            'Logout',
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
                  context.go('/admin/audit-log?search=${_profile['email'] ?? ''}');
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
                  _buildTableHeader(isDark, 'Location'),
                  _buildTableHeader(isDark, 'Date & Time'),
                ],
              ),
              ..._logs.map((log) {
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
                    _buildTableCell(isDark, 'Noida, India'),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:typed_data';

class AdminSystemConfigScreen extends ConsumerStatefulWidget {
  const AdminSystemConfigScreen({super.key});

  @override
  ConsumerState<AdminSystemConfigScreen> createState() =>
      _AdminSystemConfigScreenState();
}

class _AdminSystemConfigScreenState
    extends ConsumerState<AdminSystemConfigScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSaving = false;
  int _activeTab =
      0; // 0: General, 1: Security, 2: Email & SMS, 3: Modules, 4: Appearance, 5: Payments, 6: Integrations, 7: Backup, 8: Advanced

  bool get _isMobile => MediaQuery.of(context).size.width < 1024;

  // Dropdown list options
  final List<String> _languages = [
    "English",
    "Spanish",
    "Hindi",
    "Arabic",
    "French"
  ];
  final List<String> _timezones = [
    "(UTC+05:30) Asia/Kolkata",
    "(UTC+00:00) UTC",
    "(UTC-05:00) America/New_York",
    "(UTC+08:00) Asia/Singapore"
  ];
  final List<String> _dateFormats = [
    "May 24, 2025 (MMM DD, YYYY)",
    "2025-05-24 (YYYY-MM-DD)",
    "24/05/2025 (DD/MM/YYYY)"
  ];
  final List<String> _timeFormats = [
    "12 Hour (hh:mm AM/PM)",
    "24 Hour (HH:mm)"
  ];

  // System Schools
  List<dynamic> _schools = [];
  String _selectedSchoolId = "All Institutions";

  // Telemetry stats
  Map<String, dynamic> _stats = {
    "version": "v2.6.1",
    "environment": "Production",
    "last_updated": "--",
    "uptime": "15d 7h 24m",
    "active_sessions": 156,
    "storage_used_gb": 238.45,
    "storage_total_gb": 1000.0,
    "database_size_gb": 125.72,
    "total_settings": 18,
    "enabled_settings": 12,
    "disabled_settings": 4,
    "not_configured_settings": 2
  };

  // Text Controllers
  final _systemNameController = TextEditingController();
  final _systemTitleController = TextEditingController();
  final _systemLogoController = TextEditingController();
  final _faviconController = TextEditingController();
  final _loginMessageController = RichTextEditingController();
  final _autoLogoutController = TextEditingController();
  final _sessionTimeoutController = TextEditingController();

  // Contact Info Controllers
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactAddressController = TextEditingController();
  final _liveChatInfoController = TextEditingController();

  // Login Page Controllers
  final _loginTitleController = TextEditingController();
  final _loginSubtitleController = TextEditingController();
  final _loginDescController = TextEditingController();
  final _loginFeature1Controller = TextEditingController();
  final _loginFeature2Controller = TextEditingController();
  final _loginFeature3Controller = TextEditingController();
  final _loginFeature4Controller = TextEditingController();

  // Illustration Controllers
  final _loginIllustrationController = TextEditingController();
  final _forgotPasswordIllustrationController = TextEditingController();
  final _resetPasswordIllustrationController = TextEditingController();
  final _otpVerificationIllustrationController = TextEditingController();

  // SMTP Settings
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController();
  final _twilioSenderController = TextEditingController();

  // Footer Settings
  final _footerDescController = TextEditingController();
  final _footerCopyrightController = TextEditingController();
  final _newQuickLinkLabelController = TextEditingController();
  final _newQuickLinkUrlController = TextEditingController();
  final _newModuleLabelController = TextEditingController();
  final _newModuleUrlController = TextEditingController();
  final _newSupportLabelController = TextEditingController();
  final _newSupportUrlController = TextEditingController();
  final _newSocialPlatformController = TextEditingController();
  final _newSocialUrlController = TextEditingController();

  List<FooterLink> _footerQuickLinks = [];
  List<FooterLink> _footerModules = [];
  List<FooterLink> _footerSupport = [];
  List<FooterSocialLink> _footerSocialLinks = [];

  // Basic Info States
  String _defaultLanguage = "English";
  String _defaultTimezone = "(UTC+05:30) Asia/Kolkata";
  String _dateFormat = "May 24, 2025 (MMM DD, YYYY)";
  String _timeFormat = "12 Hour (hh:mm AM/PM)";

  // System Preferences Switches
  bool _allowNewRegistrations = true;
  bool _maintenanceMode = false;
  bool _multiInstitutionSupport = true;
  bool _dataAnonymization = false;
  bool _enableTwoFactor = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true;

  // JSON columns
  Map<String, dynamic> _securitySettings = {};
  Map<String, dynamic> _emailSmsSettings = {};
  Map<String, dynamic> _modulesSettings = {};
  Map<String, dynamic> _appearanceSettings = {};
  Map<String, dynamic> _paymentsSettings = {};
  Map<String, dynamic> _integrationsSettings = {};
  Map<String, dynamic> _backupRestoreSettings = {};
  Map<String, dynamic> _advancedSettings = {};

  @override
  void initState() {
    super.initState();
    _fetchSchools();
    _fetchConfig();
    _fetchStats();
  }

  @override
  void dispose() {
    _systemNameController.dispose();
    _systemTitleController.dispose();
    _systemLogoController.dispose();
    _faviconController.dispose();
    _loginMessageController.dispose();
    _autoLogoutController.dispose();
    _sessionTimeoutController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _contactAddressController.dispose();
    _liveChatInfoController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _twilioSenderController.dispose();
    _loginTitleController.dispose();
    _loginSubtitleController.dispose();
    _loginDescController.dispose();
    _loginFeature1Controller.dispose();
    _loginFeature2Controller.dispose();
    _loginFeature3Controller.dispose();
    _loginFeature4Controller.dispose();
    _loginIllustrationController.dispose();
    _forgotPasswordIllustrationController.dispose();
    _resetPasswordIllustrationController.dispose();
    _otpVerificationIllustrationController.dispose();
    _footerDescController.dispose();
    _footerCopyrightController.dispose();
    _newQuickLinkLabelController.dispose();
    _newQuickLinkUrlController.dispose();
    _newModuleLabelController.dispose();
    _newModuleUrlController.dispose();
    _newSupportLabelController.dispose();
    _newSupportUrlController.dispose();
    _newSocialPlatformController.dispose();
    _newSocialUrlController.dispose();
    super.dispose();
  }

  void _formatTextMessage(String prefix, String suffix) {
    final text = _loginMessageController.text;
    final selection = _loginMessageController.selection;
    if (!selection.isValid) {
      final newText = "$text$prefix$suffix";
      _loginMessageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      return;
    }

    final selectedText = selection.textInside(text);
    final formatted = "$prefix$selectedText$suffix";
    final newText =
        text.replaceRange(selection.start, selection.end, formatted);

    _loginMessageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start +
            prefix.length +
            selectedText.length +
            suffix.length,
      ),
    );
  }

  void _showLogoUrlDialog() {
    final controller = TextEditingController(text: _systemLogoController.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter System Logo URL"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "https://example.com/logo.png",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _systemLogoController.text = controller.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  void _showFaviconUrlDialog() {
    final controller = TextEditingController(text: _faviconController.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Favicon URL"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "https://example.com/favicon.png",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _faviconController.text = controller.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Logo',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Logo',
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

      setState(() => _isSaving = true);

      final res = await ApiService().multipartPostBytes(
        '/admin/system-config/upload?file_type=$fileType',
        croppedBytes,
        image.name,
        'file',
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res['success'] == true && res['data'] != null) {
        final url = res['data']['url'];
        if (!mounted) return;
        setState(() {
          if (fileType == "logo") {
            _systemLogoController.text = url;
          } else if (fileType == "favicon") {
            _faviconController.text = url;
          } else if (fileType == "login_illustration") {
            _loginIllustrationController.text = url;
          } else if (fileType == "forgot_password_illustration") {
            _forgotPasswordIllustrationController.text = url;
          } else if (fileType == "reset_password_illustration") {
            _resetPasswordIllustrationController.text = url;
          } else if (fileType == "otp_verification_illustration") {
            _otpVerificationIllustrationController.text = url;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Image uploaded successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _showLogoChangeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text("Upload from computer"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage("logo");
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text("Paste image URL"),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoUrlDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFaviconChangeOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text("Upload from computer"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage("favicon");
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text("Paste image URL"),
                onTap: () {
                  Navigator.pop(context);
                  _showFaviconUrlDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchSchools() async {
    try {
      final res = await ApiService().get('/admin/schools');
      if (res['success'] == true) {
        if (!mounted) return;
        setState(() {
          _schools = res['data']['schools'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching schools: $e");
    }
  }

  Future<void> _fetchConfig() async {
    setState(() => _isLoading = true);
    String url = '/admin/system-config';
    if (_selectedSchoolId != "All Institutions") {
      url += '?school_id=$_selectedSchoolId';
    }
    try {
      final res = await ApiService().get(url, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (!mounted) return;
        setState(() {
          _systemNameController.text = data['system_name'] ?? 'School ERP';
          _systemTitleController.text =
              data['system_title'] ?? 'Next Generation School Management';
          _systemLogoController.text = data['system_logo'] ?? '';
          _faviconController.text = data['favicon'] ?? '';
          _loginMessageController.text = data['login_page_message'] ?? '';
          _autoLogoutController.text =
              (data['auto_logout_minutes'] ?? 30).toString();
          _sessionTimeoutController.text =
              (data['session_timeout_minutes'] ?? 120).toString();

          _contactEmailController.text = data['contact_email'] ?? 'support@schoolerp.com';
          _contactPhoneController.text = data['contact_phone'] ?? '+91 98765 43210';
          _contactAddressController.text = data['contact_address'] ?? '';
          _liveChatInfoController.text = data['live_chat_info'] ?? 'Available in the application';

          _defaultLanguage = data['default_language'] ?? 'English';
          _defaultTimezone =
              data['default_timezone'] ?? '(UTC+05:30) Asia/Kolkata';
          _dateFormat = data['date_format'] ?? 'May 24, 2025 (MMM DD, YYYY)';
          _timeFormat = data['time_format'] ?? '12 Hour (hh:mm AM/PM)';

          _allowNewRegistrations = data['allow_new_registrations'] ?? true;
          _maintenanceMode = data['maintenance_mode'] ?? false;
          _multiInstitutionSupport = data['multi_institution_support'] ?? true;
          _dataAnonymization = data['data_anonymization'] ?? false;
          _enableTwoFactor = data['enable_two_factor'] ?? true;
          _emailNotifications = data['email_notifications'] ?? true;
          _smsNotifications = data['sms_notifications'] ?? true;

          _securitySettings =
              Map<String, dynamic>.from(data['security_settings'] ?? {});
          _emailSmsSettings =
              Map<String, dynamic>.from(data['email_sms_settings'] ?? {});
          _modulesSettings =
              Map<String, dynamic>.from(data['modules_settings'] ?? {});
          _appearanceSettings =
              Map<String, dynamic>.from(data['appearance_settings'] ?? {});
          _paymentsSettings =
              Map<String, dynamic>.from(data['payments_settings'] ?? {});
          _integrationsSettings =
              Map<String, dynamic>.from(data['integrations_settings'] ?? {});

          // Populate Login Settings controllers
          _loginTitleController.text = _appearanceSettings['login_title'] ?? 'Welcome Back!';
          _loginSubtitleController.text = _appearanceSettings['login_subtitle'] ?? 'Sign in to your account';
          _loginDescController.text = _appearanceSettings['login_desc'] ?? 'Access your dashboard and manage your institution with ease.';
          _loginFeature1Controller.text = _appearanceSettings['login_feature1'] ?? 'Secure Access';
          _loginFeature2Controller.text = _appearanceSettings['login_feature2'] ?? 'Smart Insights';
          _loginFeature3Controller.text = _appearanceSettings['login_feature3'] ?? 'Role Based Dashboard';
          _loginFeature4Controller.text = _appearanceSettings['login_feature4'] ?? 'Centralized Management';

          _loginIllustrationController.text = _appearanceSettings['login_illustration'] ?? '';
          
          final footer = _appearanceSettings['footer'] ?? {};
          _footerDescController.text = footer['description'] ?? 'An all-in-one school management system designed to simplify administration, improve communication and enhance overall efficiency.';
          _footerCopyrightController.text = footer['copyright'] ?? '© 2025 \$name. All rights reserved.';
          
          if (footer['quick_links'] != null) {
            _footerQuickLinks = (footer['quick_links'] as List)
                .map((item) => FooterLink.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          } else {
            _footerQuickLinks = List<FooterLink>.from(AppConfig.footerQuickLinks);
          }
          
          if (footer['modules'] != null) {
            _footerModules = (footer['modules'] as List)
                .map((item) => FooterLink.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          } else {
            _footerModules = List<FooterLink>.from(AppConfig.footerModules);
          }
          
          if (footer['support'] != null) {
            _footerSupport = (footer['support'] as List)
                .map((item) => FooterLink.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          } else {
            _footerSupport = List<FooterLink>.from(AppConfig.footerSupport);
          }

          if (footer['social_links'] != null) {
            _footerSocialLinks = (footer['social_links'] as List)
                .map((item) => FooterSocialLink.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          } else {
            _footerSocialLinks = List<FooterSocialLink>.from(AppConfig.footerSocialLinks);
          }
          _forgotPasswordIllustrationController.text = _appearanceSettings['forgot_password_illustration'] ?? '';
          _resetPasswordIllustrationController.text = _appearanceSettings['reset_password_illustration'] ?? '';
          _otpVerificationIllustrationController.text = _appearanceSettings['otp_verification_illustration'] ?? '';
          _backupRestoreSettings =
              Map<String, dynamic>.from(data['backup_restore_settings'] ?? {});
          _advancedSettings =
              Map<String, dynamic>.from(data['advanced_settings'] ?? {});

          // Load SMTP values to controllers
          _smtpHostController.text =
              _emailSmsSettings['smtp_host'] ?? 'smtp.shamiit-infra.com';
          _smtpPortController.text =
              (_emailSmsSettings['smtp_port'] ?? 587).toString();
          _twilioSenderController.text =
              _emailSmsSettings['twilio_sender'] ?? '+1-888-SHAMIIT';

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load system config: $e')),
        );
      }
    }
  }

  Future<void> _fetchStats() async {
    String url = '/admin/system-config/stats';
    if (_selectedSchoolId != "All Institutions") {
      url += '?school_id=$_selectedSchoolId';
    }
    try {
      final res = await ApiService().get(url, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        if (!mounted) return;
        setState(() {
          _stats = Map<String, dynamic>.from(res['data']);
        });
      }
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    // Sync SMTP values from controllers
    _emailSmsSettings['smtp_host'] = _smtpHostController.text.trim();
    _emailSmsSettings['smtp_port'] =
        int.tryParse(_smtpPortController.text) ?? 587;
    _emailSmsSettings['twilio_sender'] = _twilioSenderController.text.trim();

    // Sync Login settings to appearance_settings map
    _appearanceSettings['login_title'] = _loginTitleController.text.trim();
    _appearanceSettings['login_subtitle'] = _loginSubtitleController.text.trim();
    _appearanceSettings['login_desc'] = _loginDescController.text.trim();
    _appearanceSettings['login_feature1'] = _loginFeature1Controller.text.trim();
    _appearanceSettings['login_feature2'] = _loginFeature2Controller.text.trim();
    _appearanceSettings['login_feature3'] = _loginFeature3Controller.text.trim();
    _appearanceSettings['login_feature4'] = _loginFeature4Controller.text.trim();

    _appearanceSettings['login_illustration'] = _loginIllustrationController.text.trim();

    final footer = {
      'description': _footerDescController.text.trim(),
      'copyright': _footerCopyrightController.text.trim(),
      'quick_links': _footerQuickLinks.map((e) => e.toJson()).toList(),
      'modules': _footerModules.map((e) => e.toJson()).toList(),
      'support': _footerSupport.map((e) => e.toJson()).toList(),
      'social_links': _footerSocialLinks.map((e) => e.toJson()).toList(),
    };
    _appearanceSettings['footer'] = footer;
    _appearanceSettings['forgot_password_illustration'] = _forgotPasswordIllustrationController.text.trim();
    _appearanceSettings['reset_password_illustration'] = _resetPasswordIllustrationController.text.trim();
    _appearanceSettings['otp_verification_illustration'] = _otpVerificationIllustrationController.text.trim();

    final payload = {
      "school_id":
          _selectedSchoolId == "All Institutions" ? null : _selectedSchoolId,
      "system_name": _systemNameController.text.trim(),
      "system_title": _systemTitleController.text.trim(),
      "system_logo": _systemLogoController.text.trim().isEmpty
          ? null
          : _systemLogoController.text.trim(),
      "favicon": _faviconController.text.trim().isEmpty
          ? null
          : _faviconController.text.trim(),
      "default_language": _defaultLanguage,
      "default_timezone": _defaultTimezone,
      "date_format": _dateFormat,
      "time_format": _timeFormat,
      "allow_new_registrations": _allowNewRegistrations,
      "maintenance_mode": _maintenanceMode,
      "multi_institution_support": _multiInstitutionSupport,
      "data_anonymization": _dataAnonymization,
      "enable_two_factor": _enableTwoFactor,
      "email_notifications": _emailNotifications,
      "sms_notifications": _smsNotifications,
      "auto_logout_minutes": int.tryParse(_autoLogoutController.text) ?? 30,
      "session_timeout_minutes":
          int.tryParse(_sessionTimeoutController.text) ?? 120,
      "login_page_message": _loginMessageController.text.trim(),
      "contact_email": _contactEmailController.text.trim(),
      "contact_phone": _contactPhoneController.text.trim(),
      "contact_address": _contactAddressController.text.trim(),
      "live_chat_info": _liveChatInfoController.text.trim(),
      "security_settings": _securitySettings,
      "email_sms_settings": _emailSmsSettings,
      "modules_settings": _modulesSettings,
      "appearance_settings": _appearanceSettings,
      "payments_settings": _paymentsSettings,
      "integrations_settings": _integrationsSettings,
      "backup_restore_settings": _backupRestoreSettings,
      "advanced_settings": _advancedSettings
    };

    try {
      final res = await ApiService().put('/admin/system-config', payload);
      if (mounted) {
        setState(() => _isSaving = false);
      }
      if (res['success'] == true) {
        ref.read(systemConfigProvider.notifier).loadConfig();
        _fetchStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('System configuration saved successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save configuration: $e')),
        );
      }
    }
  }

  void _showImageUrlDialog(String label, TextEditingController controller) {
    final textController = TextEditingController(text: controller.text);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Set $label URL"),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: "https://example.com/image.png",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  controller.text = textController.text.trim();
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showIllustrationUploadOptions(String label, String fileType, TextEditingController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text("Upload from computer"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadImage(fileType);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text("Enter image URL manually"),
                onTap: () {
                  Navigator.pop(context);
                  _showImageUrlDialog(label, controller);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageUploadRow(String label, String fileType, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: "Upload file or enter URL...",
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _showIllustrationUploadOptions(label, fileType, controller),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 16,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Upload",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (controller.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              AppConfig.resolveUrl(controller.text),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.red, size: 24),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showLogsDialog(List<dynamic> logs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: dialogBg,
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'System Audit Logs',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        letterSpacing: -0.2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: logs.isEmpty
                      ? Center(
                          child: Text(
                            'No logs available.',
                            style: TextStyle(color: textSecondary, fontFamily: 'Outfit'),
                          ),
                        )
                      : ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (context, idx) => Divider(color: borderColor),
                          itemBuilder: (context, idx) {
                            final log = logs[idx];
                            final time = DateTime.tryParse(log['created_at']?.toString() ?? '') ?? DateTime.now();
                            final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(time);
                            final email = log['user_email'] ?? 'System';
                            final event = log['event_type'] ?? 'Action';
                            final status = log['status'] ?? 'Success';
                            final isSuccess = status.toString().toLowerCase() == 'success' || status.toString().toLowerCase() == 'true';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSuccess
                                          ? const Color(0xFF10B981).withOpacity(0.1)
                                          : const Color(0xFFEF4444).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status.toString().toUpperCase(),
                                      style: TextStyle(
                                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          event,
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'By $email • $timeStr',
                                          style: TextStyle(
                                            color: textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
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
      },
    );
  }

  void _showHealthCheckDialog(Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    final dbStatus = data['database'] ?? 'unknown';
    final redisStatus = data['redis'] ?? 'unknown';
    final servicesStatus = data['services'] ?? 'unknown';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: dialogBg,
          elevation: 24,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: servicesStatus == 'healthy'
                        ? const Color(0xFF10B981).withOpacity(0.08)
                        : const Color(0xFFF59E0B).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      servicesStatus == 'healthy'
                          ? Icons.check_circle_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: servicesStatus == 'healthy'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'System Health Check',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Overall Status: ${servicesStatus.toString().toUpperCase()}',
                  style: TextStyle(
                    color: servicesStatus == 'healthy'
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 24),
                _buildHealthItem('PostgreSQL Database', dbStatus == 'online', textPrimary, textSecondary),
                const SizedBox(height: 12),
                _buildHealthItem('Redis Cache Broker', redisStatus == 'online', textPrimary, textSecondary),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Close Diagnostics',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthItem(String title, bool isOnline, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _triggerQuickAction(String action) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Triggering $action...'),
        duration: const Duration(seconds: 1),
      ),
    );
    try {
      String endpoint = '';
      bool isPost = true;
      if (action == "Clear System Cache") {
        endpoint = '/admin/system-config/maintenance/clear-cache';
      } else if (action == "System Health Check") {
        endpoint = '/admin/system-config/maintenance/health-check';
      } else if (action == "Regenerate API Keys") {
        endpoint = '/admin/system-config/maintenance/regenerate-api-keys';
      } else if (action == "View System Logs") {
        endpoint = '/admin/system-config/maintenance/logs';
        isPost = false;
      }

      if (endpoint.isNotEmpty) {
        final res = isPost
            ? await ApiService().post(endpoint, {})
            : await ApiService().get(endpoint);

        if (res['success'] == true) {
          if (action == "View System Logs") {
            _showLogsDialog(res['data'] as List<dynamic>);
          } else if (action == "System Health Check") {
            _showHealthCheckDialog(res['data'] as Map<String, dynamic>);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$action completed successfully!'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
          _fetchStats();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: ${res['message'] ?? 'Unknown error'}'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = _isMobile;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.primaryColor))
          : isMobile
              ? NestedScrollView(
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildHeader(isDark),
                        ),
                      ),
                    ];
                  },
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildTabsRow(isDark),
                        const SizedBox(height: 16),
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildActiveTabContent(isDark),
                                      const SizedBox(height: 24),
                                      _buildSystemStatusCard(isDark),
                                      const SizedBox(height: 24),
                                      _buildConfigurationOverviewCard(isDark),
                                      const SizedBox(height: 24),
                                      _buildQuickActionsCard(isDark),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isDark),
                      const SizedBox(height: 24),
                      _buildTabsRow(isDark),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left config panel (2/3 width)
                            Expanded(
                              flex: 2,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 24),
                                  child: _buildActiveTabContent(isDark),
                                ),
                              ),
                            ),
                            // Right status panel (1/3 width)
                            SizedBox(
                              width: 380,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _buildSystemStatusCard(isDark),
                                    const SizedBox(height: 24),
                                    _buildConfigurationOverviewCard(isDark),
                                    const SizedBox(height: 24),
                                    _buildQuickActionsCard(isDark),
                                  ],
                                ),
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

  Widget _buildHeader(bool isDark) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "System Configuration",
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Manage and configure global system settings for your ERP platform.",
              style: TextStyle(
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Top dropdown: All Institutions
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSchoolId,
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSchoolId = val;
                      });
                      _fetchConfig();
                      _fetchStats();
                    }
                  },
                  items: [
                    const DropdownMenuItem(
                      value: "All Institutions",
                      child: Text("All Institutions"),
                    ),
                    ..._schools.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['id'].toString(),
                        child: Text(s['name'].toString()),
                      );
                    })
                  ],
                ),
              ),
            ),
            // Search Input placeholder
            Container(
              width: 200,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search settings...",
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                style: TextStyle(fontSize: 12),
              ),
            ),
            // Save Changes button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white),
              label: Text(_isSaving ? "Saving..." : "Save Changes"),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabsRow(bool isDark) {
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> tabs = [
      {"label": "General Settings", "icon": Icons.tune_rounded},
      {"label": "Security", "icon": Icons.security_rounded},
      {"label": "Email & SMS", "icon": Icons.mail_outline_rounded},
      {"label": "Modules", "icon": Icons.dashboard_customize_rounded},
      {"label": "Appearance", "icon": Icons.palette_outlined},
      {"label": "Payments", "icon": Icons.payment_rounded},
      {
        "label": "Integrations",
        "icon": Icons.integration_instructions_outlined
      },
      {"label": "Backup & Restore", "icon": Icons.backup_rounded},
      {"label": "Advanced", "icon": Icons.settings_suggest_rounded},
      {"label": "Login Page", "icon": Icons.login_rounded},
      {"label": "Footer Settings", "icon": Icons.view_headline_rounded},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isActive = _activeTab == idx;

          return GestureDetector(
            onTap: () => setState(() => _activeTab = idx),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.primaryColor
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item["icon"] as IconData,
                    size: 14,
                    color: isActive
                        ? Colors.white
                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item["label"] as String,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTabContent(bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildGeneralSettingsTab(isDark);
      case 1:
        return _buildSecurityTab(isDark);
      case 2:
        return _buildEmailSMSTab(isDark);
      case 3:
        return _buildModulesTab(isDark);
      case 4:
        return _buildAppearanceTab(isDark);
      case 5:
        return _buildPaymentsTab(isDark);
      case 6:
        return _buildIntegrationsTab(isDark);
      case 7:
        return _buildBackupRestoreTab(isDark);
      case 8:
        return _buildAdvancedTab(isDark);
      case 9:
        return _buildLoginPageTab(isDark);
      case 10:
        return _buildFooterTab(isDark);
      default:
        return _buildGeneralSettingsTab(isDark);
    }
  }

  // =========================================================================
  // Tab UI Builders
  // =========================================================================

  Widget _buildGeneralSettingsTab(bool isDark) {
    final theme = Theme.of(context);
    final isMobile = _isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Basic Information Card
        _buildConfigCard(
          isDark,
          title: "Basic Information",
          subtitle:
              "Configure basic system details that will be used across all institutions.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "System Logo",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _showLogoChangeOptions(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: _systemLogoController.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    AppConfig.resolveUrl(_systemLogoController.text),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            size: 24, color: Colors.red),
                                        SizedBox(height: 8),
                                        Text("Invalid Image URL",
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_search_rounded,
                                        size: 24,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey),
                                    const SizedBox(height: 8),
                                    const Text("Click to upload Logo",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    const Text("PNG, JPG or SVG format",
                                        style: TextStyle(
                                            fontSize: 8, color: Colors.grey)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputField("System Name", _systemNameController,
                    isDark, "School ERP"),
                const SizedBox(height: 16),
                _buildInputField("System Title", _systemTitleController,
                    isDark, "Next Generation School Management"),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildInputField("System Name", _systemNameController,
                              isDark, "School ERP"),
                          const SizedBox(height: 16),
                          _buildInputField("System Title", _systemTitleController,
                              isDark, "Next Generation School Management"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Logo container
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "System Logo",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _showLogoChangeOptions(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0)),
                            ),
                            child: _systemLogoController.text.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      AppConfig.resolveUrl(_systemLogoController.text),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.error_outline_rounded,
                                              size: 24, color: Colors.red),
                                          SizedBox(height: 8),
                                          Text("Invalid Image URL",
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_search_rounded,
                                          size: 24,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey),
                                      const SizedBox(height: 8),
                                      const Text("Click to upload Logo",
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      const Text("PNG, JPG or SVG format",
                                          style: TextStyle(
                                              fontSize: 8, color: Colors.grey)),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildDropdownField(
                    "Default Language", _defaultLanguage, _languages,
                    (val) {
                  if (val != null) setState(() => _defaultLanguage = val);
                }, isDark),
                const SizedBox(height: 16),
                // Favicon
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Favicon",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0)),
                          ),
                          child: _faviconController.text.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    AppConfig.resolveUrl(_faviconController.text),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                            Icons.error_outline_rounded,
                                            size: 18,
                                            color: Colors.red),
                                  ),
                                )
                              : Icon(Icons.school_rounded,
                                  size: 18, color: theme.primaryColor),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => _showFaviconChangeOptions(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : const Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text("Change",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87)),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                          "Default Language", _defaultLanguage, _languages,
                          (val) {
                        if (val != null) setState(() => _defaultLanguage = val);
                      }, isDark),
                    ),
                    const SizedBox(width: 32),
                    // Favicon
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Favicon",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.white10
                                          : const Color(0xFFE2E8F0)),
                                ),
                                child: _faviconController.text.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          AppConfig.resolveUrl(_faviconController.text),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 18,
                                                  color: Colors.red),
                                        ),
                                      )
                                    : Icon(Icons.school_rounded,
                                        size: 18, color: theme.primaryColor),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => _showFaviconChangeOptions(),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: isDark
                                          ? Colors.white24
                                          : const Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                                child: Text("Change",
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (isMobile) ...[
                _buildDropdownField(
                    "Default Timezone", _defaultTimezone, _timezones,
                    (val) {
                  if (val != null) setState(() => _defaultTimezone = val);
                }, isDark),
                const SizedBox(height: 16),
                _buildDropdownField(
                    "Date Format", _dateFormat, _dateFormats, (val) {
                  if (val != null) setState(() => _dateFormat = val);
                }, isDark),
                const SizedBox(height: 16),
                _buildDropdownField(
                    "Time Format", _timeFormat, _timeFormats, (val) {
                  if (val != null) setState(() => _timeFormat = val);
                }, isDark),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                          "Default Timezone", _defaultTimezone, _timezones,
                          (val) {
                        if (val != null) setState(() => _defaultTimezone = val);
                      }, isDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                          "Date Format", _dateFormat, _dateFormats, (val) {
                        if (val != null) setState(() => _dateFormat = val);
                      }, isDark),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                          "Time Format", _timeFormat, _timeFormats, (val) {
                        if (val != null) setState(() => _timeFormat = val);
                      }, isDark),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 2. System Preferences Card
        _buildConfigCard(
          isDark,
          title: "System Preferences",
          subtitle: "Manage global system preferences and behavior.",
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildSwitchRow(
                        "Allow New Registrations",
                        "Allow new institutions to register on the system",
                        _allowNewRegistrations, (val) {
                      setState(() => _allowNewRegistrations = val);
                    }, isDark),
                    const Divider(height: 24, color: Colors.white10),
                    _buildSwitchRow(
                        "Maintenance Mode",
                        "Enable maintenance mode (system will be unavailable)",
                        _maintenanceMode, (val) {
                      setState(() => _maintenanceMode = val);
                    }, isDark),
                    const Divider(height: 24, color: Colors.white10),
                    _buildSwitchRow(
                        "Multi-Institution Support",
                        "Enable multi-institution (multi-tenant) support",
                        _multiInstitutionSupport, (val) {
                      setState(() => _multiInstitutionSupport = val);
                    }, isDark),
                    const Divider(height: 24, color: Colors.white10),
                    _buildSwitchRow(
                        "Data Anonymization",
                        "Automatically anonymize old records",
                        _dataAnonymization, (val) {
                      setState(() => _dataAnonymization = val);
                    }, isDark),
                    const Divider(height: 24, color: Colors.white10),
                    _buildSwitchRow(
                        "Enable Two-Factor Authentication",
                        "Require 2FA for admin and users",
                        _enableTwoFactor, (val) {
                      setState(() => _enableTwoFactor = val);
                    }, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: Column(
                  children: [
                    _buildSwitchRow(
                        "Email Notifications",
                        "Enable email notifications for system events",
                        _emailNotifications, (val) {
                      setState(() => _emailNotifications = val);
                    }, isDark),
                    const Divider(height: 24, color: Colors.white10),
                    _buildSwitchRow(
                        "SMS Notifications",
                        "Enable SMS notifications for alerts",
                        _smsNotifications, (val) {
                      setState(() => _smsNotifications = val);
                    }, isDark),
                    const Divider(height: 24, color: Colors.white10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Auto Logout (minutes)",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              const Text("Automatically logout inactive users",
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 38,
                          child: TextField(
                            controller: _autoLogoutController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Colors.white10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Session Timeout (minutes)",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              const Text("Maximum session duration",
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          height: 38,
                          child: TextField(
                            controller: _sessionTimeoutController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 3. System Message Card
        _buildConfigCard(
          isDark,
          title: "System Message",
          subtitle: "Configure system-wide messages and alerts.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Login Page Message",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Fake Editor Toolbar
                    Container(
                      height: 36,
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            IconButton(
                                icon: const Icon(Icons.format_bold_rounded,
                                    size: 16),
                                onPressed: () => _formatTextMessage('**', '**'),
                                tooltip: "Bold"),
                            IconButton(
                                icon: const Icon(Icons.format_italic_rounded,
                                    size: 16),
                                onPressed: () => _formatTextMessage('*', '*'),
                                tooltip: "Italic"),
                            IconButton(
                                icon: const Icon(Icons.format_underlined_rounded,
                                    size: 16),
                                onPressed: () =>
                                    _formatTextMessage('<u>', '</u>'),
                                tooltip: "Underline"),
                            const VerticalDivider(
                                color: Colors.white24, indent: 8, endIndent: 8),
                            IconButton(
                                icon: const Icon(
                                    Icons.format_list_bulleted_rounded,
                                    size: 16),
                                onPressed: () => _formatTextMessage('\n- ', '')),
                            IconButton(
                                icon: const Icon(
                                    Icons.format_list_numbered_rounded,
                                    size: 16),
                                onPressed: () => _formatTextMessage('\n1. ', '')),
                            const VerticalDivider(
                                color: Colors.white24, indent: 8, endIndent: 8),
                            IconButton(
                                icon: const Icon(Icons.link_rounded, size: 16),
                                onPressed: () =>
                                    _formatTextMessage('[', '](url)')),
                          ],
                        ),
                      ),
                    ),
                    TextField(
                      controller: _loginMessageController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                        hintText: "Enter custom login message...",
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 4. Contact Information Card
        _buildConfigCard(
          isDark,
          title: "Contact Information",
          subtitle: "Configure contact details displayed on public pages (Contact Us, Help Center, footers).",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                _buildInputField("Contact Email", _contactEmailController, isDark, "support@schoolerp.com"),
                const SizedBox(height: 16),
                _buildInputField("Contact Phone", _contactPhoneController, isDark, "+91 98765 43210"),
                const SizedBox(height: 16),
                _buildInputField("Live Chat Info", _liveChatInfoController, isDark, "Available in the application"),
                const SizedBox(height: 16),
                _buildInputField("Contact Address", _contactAddressController, isDark, "School Address...", maxLines: 3),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField("Contact Email", _contactEmailController, isDark, "support@schoolerp.com"),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField("Contact Phone", _contactPhoneController, isDark, "+91 98765 43210"),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInputField("Live Chat Info", _liveChatInfoController, isDark, "Available in the application"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInputField("Contact Address", _contactAddressController, isDark, "School Address...", maxLines: 3),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab(bool isDark) {
    final isMobile = _isMobile;
    return _buildConfigCard(
      isDark,
      title: "Security Settings",
      subtitle:
          "Control platform-wide user security, passwords policies, and lockout credentials.",
      child: Column(
        children: [
          _buildDropdownField(
            "Password Complexity Policy",
            _securitySettings['password_policy'] ?? "Strong",
            ["Simple", "Medium", "Strong", "Enterprise"],
            (val) {
              if (val != null) {
                setState(() {
                  _securitySettings['password_policy'] = val;
                });
              }
            },
            isDark,
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Max Active Sessions per User",
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: [1, 2, 5, 10, 20].contains(int.tryParse(_securitySettings['session_limit']?.toString() ?? '5') ?? 5)
                      ? (int.tryParse(_securitySettings['session_limit']?.toString() ?? '5') ?? 5)
                      : 5,
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _securitySettings['session_limit'] = val;
                      });
                    }
                  },
                  items: [1, 2, 5, 10, 20].map((int val) {
                    return DropdownMenuItem<int>(
                        value: val, child: Text("$val Sessions"));
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Failed Login Lockout Threshold",
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  value: [3, 5, 10, 15].contains(int.tryParse(_securitySettings['failed_attempts_lockout']?.toString() ?? '5') ?? 5)
                      ? (int.tryParse(_securitySettings['failed_attempts_lockout']?.toString() ?? '5') ?? 5)
                      : 5,
                  dropdownColor:
                      isDark ? const Color(0xFF1E293B) : Colors.white,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _securitySettings['failed_attempts_lockout'] = val;
                      });
                    }
                  },
                  items: [3, 5, 10, 15].map((int val) {
                    return DropdownMenuItem<int>(
                        value: val, child: Text("$val Attempts"));
                  }).toList(),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Max Active Sessions per User",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: [1, 2, 5, 10, 20].contains(int.tryParse(_securitySettings['session_limit']?.toString() ?? '5') ?? 5)
                            ? (int.tryParse(_securitySettings['session_limit']?.toString() ?? '5') ?? 5)
                            : 5,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _securitySettings['session_limit'] = val;
                            });
                          }
                        },
                        items: [1, 2, 5, 10, 20].map((int val) {
                          return DropdownMenuItem<int>(
                              value: val, child: Text("$val Sessions"));
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Failed Login Lockout Threshold",
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: [3, 5, 10, 15].contains(int.tryParse(_securitySettings['failed_attempts_lockout']?.toString() ?? '5') ?? 5)
                            ? (int.tryParse(_securitySettings['failed_attempts_lockout']?.toString() ?? '5') ?? 5)
                            : 5,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _securitySettings['failed_attempts_lockout'] = val;
                            });
                          }
                        },
                        items: [3, 5, 10, 15].map((int val) {
                          return DropdownMenuItem<int>(
                              value: val, child: Text("$val Attempts"));
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailSMSTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Email & SMS Settings",
      subtitle:
          "Configure notification dispatch templates and providers API credentials.",
      child: Column(
        children: [
          _buildInputField("SMTP Gateway Endpoint", _smtpHostController, isDark,
              "smtp.shamiit-infra.com"),
          const SizedBox(height: 16),
          _buildInputField("SMTP Port", _smtpPortController, isDark, "587"),
          const SizedBox(height: 16),
          _buildInputField("Twilio SMS Route Sender", _twilioSenderController,
              isDark, "+1-888-SHAMIIT"),
        ],
      ),
    );
  }

  Widget _buildModulesTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Global Modules Registry",
      subtitle: "Select which functional modules are activated for this scope.",
      child: Column(
        children: [
          _buildSwitchRow(
              "Academic & Curriculum Engine",
              "Timetables, course paths, study plans, live learning",
              _modulesSettings['academics'] ?? true, (val) {
            setState(() => _modulesSettings['academics'] = val);
          }, isDark),
          const Divider(height: 24, color: Colors.white10),
          _buildSwitchRow(
              "Financial & Tuition Ledger",
              "Fee collections, recurring plans, defaulters triggers",
              _modulesSettings['finance'] ?? true, (val) {
            setState(() => _modulesSettings['finance'] = val);
          }, isDark),
          const Divider(height: 24, color: Colors.white10),
          _buildSwitchRow(
              "HR & Payroll Registry",
              "Teacher salaries, bio logins, attendance tracking, leave manager",
              _modulesSettings['hr_payroll'] ?? true, (val) {
            setState(() => _modulesSettings['hr_payroll'] = val);
          }, isDark),
          const Divider(height: 24, color: Colors.white10),
          _buildSwitchRow(
              "Logistics & Transport Dispatch",
              "Bus routing, driver mapping, live GPS tracker",
              _modulesSettings['transport'] ?? true, (val) {
            setState(() => _modulesSettings['transport'] = val);
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildAppearanceTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Appearance Settings",
      subtitle:
          "Customize standard primary colors, styles, layouts and dashboard looks.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownField(
            "Default Visual Mode",
            _appearanceSettings['theme'] ?? "Dark",
            ["Light", "Dark", "System Mode"],
            (val) {
              if (val != null) {
                setState(() {
                  _appearanceSettings['theme'] = val;
                });
              }
            },
            isDark,
          ),
          const SizedBox(height: 16),
          const Text("Primary Color Theme",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Colors.indigo,
              Colors.blue,
              Colors.green,
              Colors.teal,
              Colors.orange,
              Colors.purple
            ].map((c) {
              final hex =
                  '#${c.value.toRadixString(16).substring(2).toUpperCase()}';
              final isSel = _appearanceSettings['primary_color'] == hex ||
                  (_appearanceSettings['primary_color'] == null &&
                      c == Colors.indigo);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _appearanceSettings['primary_color'] = hex;
                  });
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSel
                        ? Border.all(
                            color: isDark ? Colors.black : Colors.white,
                            width: 2)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Tuition & Payments Settings",
      subtitle:
          "Configure gateways, invoice generation, base currencies, and merchant accounts.",
      child: Column(
        children: [
          _buildDropdownField(
            "Base Currency",
            _paymentsSettings['currency'] ?? "INR",
            ["INR", "USD", "EUR", "AED"],
            (val) {
              if (val != null) {
                setState(() {
                  _paymentsSettings['currency'] = val;
                });
              }
            },
            isDark,
          ),
          const SizedBox(height: 16),
          _buildSwitchRow(
              "Automatic Invoice Dispatch",
              "Automatically create and email invoices upon fee due",
              _paymentsSettings['auto_invoice'] ?? true, (val) {
            setState(() => _paymentsSettings['auto_invoice'] = val);
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildIntegrationsTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Automation & Integrations",
      subtitle:
          "Toggle broker connections to live hardware terminals, video channels, and calendars.",
      child: Column(
        children: [
          _buildSwitchRow(
            "Biometric Sync Broker Service",
            "Automatically synchronize biometric terminals daily between 9:00 - 10:00 AM.",
            _integrationsSettings['biometric_sync'] ?? true,
            (val) {
              setState(() => _integrationsSettings['biometric_sync'] = val);
            },
            isDark,
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildSwitchRow(
            "Zoom Virtual Classroom Engine",
            "Enable scheduling Zoom links automatically inside live learning channels",
            _integrationsSettings['zoom_integration'] ?? false,
            (val) {
              setState(() => _integrationsSettings['zoom_integration'] = val);
            },
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildBackupRestoreTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Data Backup & Recovery Policy",
      subtitle:
          "Configure automatic snapshots, backup destinations, and logs retention threshold.",
      child: Column(
        children: [
          _buildSwitchRow(
            "Automatic Snapshots",
            "Perform daily full database and transaction logs backup",
            _backupRestoreSettings['auto_backup'] ?? true,
            (val) {
              setState(() => _backupRestoreSettings['auto_backup'] = val);
            },
            isDark,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            "Backup Snapshots Interval",
            _backupRestoreSettings['backup_interval'] ?? "Daily",
            ["Daily", "Weekly", "Monthly"],
            (val) {
              if (val != null) {
                setState(() {
                  _backupRestoreSettings['backup_interval'] = val;
                });
              }
            },
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Advanced System Settings",
      subtitle:
          "Configure low-level debug parameters, caching brokers, and platform modes.",
      child: Column(
        children: [
          _buildSwitchRow(
            "Platform Debug Logging",
            "Print verbose stack traces and debug output inside system log stream",
            _advancedSettings['debug_mode'] ?? false,
            (val) {
              setState(() => _advancedSettings['debug_mode'] = val);
            },
            isDark,
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildSwitchRow(
            "Query Result Cache Broker",
            "Enable Redis query caching to boost listing latency speed",
            _advancedSettings['query_caching'] ?? true,
            (val) {
              setState(() => _advancedSettings['query_caching'] = val);
            },
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPageTab(bool isDark) {
    return _buildConfigCard(
      isDark,
      title: "Login Page Settings",
      subtitle:
          "Configure dynamic welcome texts, description guidelines, and highlight features for your Login Page Left Banner.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInputField("Welcome Banner Title", _loginTitleController, isDark, "e.g., Welcome Back!"),
          const SizedBox(height: 16),
          _buildInputField("Welcome Banner Subtitle", _loginSubtitleController, isDark, "e.g., Sign in to your account"),
          const SizedBox(height: 16),
          _buildInputField("Welcome Banner Description", _loginDescController, isDark, "e.g., Access your dashboard and manage your institution with ease."),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            "Banner Highlights Features (4 Items)",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildInputField("Feature Item 1 Label", _loginFeature1Controller, isDark, "e.g., Secure Access"),
          const SizedBox(height: 12),
          _buildInputField("Feature Item 2 Label", _loginFeature2Controller, isDark, "e.g., Smart Insights"),
          const SizedBox(height: 12),
          _buildInputField("Feature Item 3 Label", _loginFeature3Controller, isDark, "e.g., Role Based Dashboard"),
          const SizedBox(height: 12),
          _buildInputField("Feature Item 4 Label", _loginFeature4Controller, isDark, "e.g., Centralized Management"),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            "Auth Screens Illustration Images",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          _buildImageUploadRow("Login Screen Illustration", "login_illustration", _loginIllustrationController, isDark),
          const SizedBox(height: 16),
          _buildImageUploadRow("Forgot Password Screen Illustration", "forgot_password_illustration", _forgotPasswordIllustrationController, isDark),
          const SizedBox(height: 16),
          _buildImageUploadRow("Reset Password Screen Illustration", "reset_password_illustration", _resetPasswordIllustrationController, isDark),
          const SizedBox(height: 16),
          _buildImageUploadRow("OTP Verification Screen Illustration", "otp_verification_illustration", _otpVerificationIllustrationController, isDark),
        ],
      ),
    );
  }

  // =========================================================================
  // Shared Form Components
  // =========================================================================

  Widget _buildConfigCard(
    bool isDark, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      bool isDark, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items,
      ValueChanged<String?> onChanged, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 12),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged, bool isDark) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: theme.primaryColor.withValues(alpha: 0.5),
          activeColor: theme.primaryColor,
        ),
      ],
    );
  }

  // =========================================================================
  // Right Column Widgets (Uptime, Doughnut, Quick Actions)
  // =========================================================================

  Widget _buildSystemStatusCard(bool isDark) {
    final theme = Theme.of(context);
    final double usedGb = (double.tryParse(_stats["storage_used_gb"]?.toString() ?? '0') ?? 0.0);
    final double totalGb = (double.tryParse(_stats["storage_total_gb"]?.toString() ?? '1.0') ?? 1.0);
    final double percentage = totalGb > 0 ? (usedGb / totalGb * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("System Status",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          _buildStatusRow("System Version",
              _stats["version"]?.toString() ?? "v2.6.1", isDark),
          _buildStatusRow("Environment",
              _stats["environment"]?.toString() ?? "Production", isDark),
          _buildStatusRow("Last Updated",
              _formatLastUpdated(_stats["last_updated"]), isDark),
          _buildStatusRow("System Uptime",
              _stats["uptime"]?.toString() ?? "15d 7h 24m", isDark),
          _buildStatusRow("Active Sessions",
              _stats["active_sessions"]?.toString() ?? "156", isDark),
          const SizedBox(height: 12),
          const Text("Storage Used",
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalGb > 0 ? (usedGb / totalGb) : 0.0,
              minHeight: 6,
              backgroundColor:
                  isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${usedGb.toStringAsFixed(2)} GB / ${totalGb.toInt()} GB (${percentage.toStringAsFixed(1)}%)",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
              "Database Size", "${_stats["database_size_gb"]} GB", isDark),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  String _formatLastUpdated(dynamic dateStr) {
    if (dateStr == null || dateStr == "--") return "--";
    try {
      final date = DateTime.parse(dateStr.toString()).toLocal();
      return DateFormat('MMM dd, yyyy hh:mm a').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Widget _buildConfigurationOverviewCard(bool isDark) {
    final theme = Theme.of(context);
    final int enabled = _stats["enabled_settings"] ?? 12;
    final int disabled = _stats["disabled_settings"] ?? 4;
    final int notConfigured = _stats["not_configured_settings"] ?? 2;
    final int total = enabled + disabled + notConfigured;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Configuration Overview",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 0,
                        centerSpaceRadius: 36,
                        sections: total == 0
                            ? [
                                PieChartSectionData(
                                  color: isDark ? Colors.white10 : const Color(0xFFCBD5E1),
                                  value: 1.0,
                                  radius: 8,
                                  showTitle: false,
                                )
                              ]
                            : [
                                PieChartSectionData(
                                  color: const Color(0xFF10B981),
                                  value: enabled.toDouble(),
                                  radius: 8,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  color: const Color(0xFFF59E0B),
                                  value: disabled.toDouble(),
                                  radius: 8,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFCBD5E1),
                                  value: notConfigured.toDouble(),
                                  radius: 8,
                                  showTitle: false,
                                ),
                              ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          total.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const Text("Settings",
                            style: TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildOverviewLegendRow(
                        "Enabled", enabled, total, const Color(0xFF10B981)),
                    const SizedBox(height: 6),
                    _buildOverviewLegendRow(
                        "Disabled", disabled, total, const Color(0xFFF59E0B)),
                    const SizedBox(height: 6),
                    _buildOverviewLegendRow(
                        "Not Configured",
                        notConfigured,
                        total,
                        isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: InkWell(
              onTap: () => setState(() => _activeTab = 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("View All Settings",
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded,
                      size: 10, color: theme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewLegendRow(
      String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : "0.0";
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ),
        Text(
          "$count ($pct%)",
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Actions",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          _buildQuickActionButton(
              "Clear System Cache",
              Icons.cleaning_services_outlined,
              () => _triggerQuickAction("Clear System Cache"),
              isDark),
          const SizedBox(height: 10),
          _buildQuickActionButton(
              "System Health Check",
              Icons.health_and_safety_outlined,
              () => _triggerQuickAction("System Health Check"),
              isDark),
          const SizedBox(height: 10),
          _buildQuickActionButton("Regenerate API Keys", Icons.vpn_key_outlined,
              () => _triggerQuickAction("Regenerate API Keys"), isDark),
          const SizedBox(height: 10),
          _buildQuickActionButton("View System Logs", Icons.terminal_outlined,
              () => _triggerQuickAction("View System Logs"), isDark),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, VoidCallback onTap, bool isDark) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: theme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Color _getSocialBrandColor(String platform) {
    switch (platform.toLowerCase().trim()) {
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'twitter':
      case 'x':
        return const Color(0xFF1DA1F2);
      case 'email':
      case 'mail':
        return const Color(0xFF6366F1);
      case 'youtube':
      case 'play':
        return const Color(0xFFFF0000);
      case 'linkedin':
        return const Color(0xFF0A66C2);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _showEditLinkDialog(int index, String columnTitle, List<FooterLink> list) {
    final link = list[index];
    final labelController = TextEditingController(text: link.label);
    final urlController = TextEditingController(text: link.url);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Link in $columnTitle"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: "Link Label"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: "Target URL / Route"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final label = labelController.text.trim();
                final url = urlController.text.trim();
                if (label.isNotEmpty && url.isNotEmpty) {
                  setState(() {
                    list[index] = FooterLink(label: label, url: url);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showEditSocialLinkDialog(int index) {
    final item = _footerSocialLinks[index];
    final platformController = TextEditingController(text: item.platform);
    final urlController = TextEditingController(text: item.url);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Social Connection"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: platformController,
                decoration: const InputDecoration(labelText: "Platform Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: "Target URL"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final platform = platformController.text.trim();
                final url = urlController.text.trim();
                if (platform.isNotEmpty && url.isNotEmpty) {
                  setState(() {
                    _footerSocialLinks[index] = FooterSocialLink(platform: platform, url: url);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFooterTab(bool isDark) {
    final isMobile = _isMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildConfigCard(
          isDark,
          title: "Footer Information",
          subtitle: "Customize the description text and the copyright / all-rights-reserved information.",
          child: Column(
            children: [
              _buildInputField(
                "Footer Description",
                _footerDescController,
                isDark,
                "Enter footer description...",
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                "Copyright Text (Use \$name placeholder for dynamic institution name)",
                _footerCopyrightController,
                isDark,
                "e.g., © 2025 \$name. All rights reserved.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildConfigCard(
          isDark,
          title: "Social Media Links (Drag to Reorder)",
          subtitle: "Configure platform connections and external target URLs in the footer. Drag handles to reorder them immediately.",
          child: Column(
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: _footerSocialLinks.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "No social media connections added",
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      )
                    : ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _footerSocialLinks.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = _footerSocialLinks.removeAt(oldIndex);
                            _footerSocialLinks.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _footerSocialLinks[index];
                          return Container(
                            key: ValueKey("social_${index}_${item.platform}"),
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(Icons.drag_indicator_rounded, size: 20, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getSocialBrandColor(item.platform).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getSocialIcon(item.platform),
                                    size: 18,
                                    color: _getSocialBrandColor(item.platform),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.platform.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.url,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                      onPressed: () => _showEditSocialLinkDialog(index),
                                      tooltip: "Edit Connection",
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() {
                                          _footerSocialLinks.removeAt(index);
                                        });
                                      },
                                      tooltip: "Delete Connection",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _newSocialPlatformController,
                      decoration: InputDecoration(
                        hintText: "Platform (e.g. facebook, email)",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _newSocialUrlController,
                      decoration: InputDecoration(
                        hintText: "Target URL (e.g. https://facebook.com/...)",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final platform = _newSocialPlatformController.text.trim();
                      final url = _newSocialUrlController.text.trim();
                      if (platform.isNotEmpty && url.isNotEmpty) {
                        setState(() {
                          _footerSocialLinks.add(FooterSocialLink(platform: platform, url: url));
                          _newSocialPlatformController.clear();
                          _newSocialUrlController.clear();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildConfigCard(
          isDark,
          title: "Footer Columns Manager (Drag to Reorder)",
          subtitle: "Manage dynamic links displayed in the Quick Links, Modules, and Support columns. Drag handles to reorder them.",
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (isMobile) {
                return Column(
                  children: [
                    _buildLinkManagerColumn(
                      "Quick Links",
                      _footerQuickLinks,
                      _newQuickLinkLabelController,
                      _newQuickLinkUrlController,
                      () {
                        final label = _newQuickLinkLabelController.text.trim();
                        final url = _newQuickLinkUrlController.text.trim();
                        if (label.isNotEmpty && url.isNotEmpty) {
                          setState(() {
                            _footerQuickLinks.add(FooterLink(label: label, url: url));
                            _newQuickLinkLabelController.clear();
                            _newQuickLinkUrlController.clear();
                          });
                        }
                      },
                      (idx) {
                        setState(() {
                          _footerQuickLinks.removeAt(idx);
                        });
                      },
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    _buildLinkManagerColumn(
                      "Modules",
                      _footerModules,
                      _newModuleLabelController,
                      _newModuleUrlController,
                      () {
                        final label = _newModuleLabelController.text.trim();
                        final url = _newModuleUrlController.text.trim();
                        if (label.isNotEmpty && url.isNotEmpty) {
                          setState(() {
                            _footerModules.add(FooterLink(label: label, url: url));
                            _newModuleLabelController.clear();
                            _newModuleUrlController.clear();
                          });
                        }
                      },
                      (idx) {
                        setState(() {
                          _footerModules.removeAt(idx);
                        });
                      },
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    _buildLinkManagerColumn(
                      "Support",
                      _footerSupport,
                      _newSupportLabelController,
                      _newSupportUrlController,
                      () {
                        final label = _newSupportLabelController.text.trim();
                        final url = _newSupportUrlController.text.trim();
                        if (label.isNotEmpty && url.isNotEmpty) {
                          setState(() {
                            _footerSupport.add(FooterLink(label: label, url: url));
                            _newSupportLabelController.clear();
                            _newSupportUrlController.clear();
                          });
                        }
                      },
                      (idx) {
                        setState(() {
                          _footerSupport.removeAt(idx);
                        });
                      },
                      isDark,
                    ),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildLinkManagerColumn(
                        "Quick Links",
                        _footerQuickLinks,
                        _newQuickLinkLabelController,
                        _newQuickLinkUrlController,
                        () {
                          final label = _newQuickLinkLabelController.text.trim();
                          final url = _newQuickLinkUrlController.text.trim();
                          if (label.isNotEmpty && url.isNotEmpty) {
                            setState(() {
                              _footerQuickLinks.add(FooterLink(label: label, url: url));
                              _newQuickLinkLabelController.clear();
                              _newQuickLinkUrlController.clear();
                            });
                          }
                        },
                        (idx) {
                          setState(() {
                            _footerQuickLinks.removeAt(idx);
                          });
                        },
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildLinkManagerColumn(
                        "Modules",
                        _footerModules,
                        _newModuleLabelController,
                        _newModuleUrlController,
                        () {
                          final label = _newModuleLabelController.text.trim();
                          final url = _newModuleUrlController.text.trim();
                          if (label.isNotEmpty && url.isNotEmpty) {
                            setState(() {
                              _footerModules.add(FooterLink(label: label, url: url));
                              _newModuleLabelController.clear();
                              _newModuleUrlController.clear();
                            });
                          }
                        },
                        (idx) {
                          setState(() {
                            _footerModules.removeAt(idx);
                          });
                        },
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildLinkManagerColumn(
                        "Support",
                        _footerSupport,
                        _newSupportLabelController,
                        _newSupportUrlController,
                        () {
                          final label = _newSupportLabelController.text.trim();
                          final url = _newSupportUrlController.text.trim();
                          if (label.isNotEmpty && url.isNotEmpty) {
                            setState(() {
                              _footerSupport.add(FooterLink(label: label, url: url));
                              _newSupportLabelController.clear();
                              _newSupportUrlController.clear();
                            });
                          }
                        },
                        (idx) {
                          setState(() {
                            _footerSupport.removeAt(idx);
                          });
                        },
                        isDark,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  IconData _getSocialIcon(String platform) {
    switch (platform.toLowerCase().trim()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'twitter':
      case 'x':
        return Icons.close;
      case 'email':
      case 'mail':
        return Icons.alternate_email;
      case 'youtube':
      case 'play':
        return Icons.play_circle_filled;
      case 'linkedin':
        return Icons.business;
      default:
        return Icons.link;
    }
  }

  Widget _buildLinkManagerColumn(
    String title,
    List<FooterLink> links,
    TextEditingController labelController,
    TextEditingController urlController,
    VoidCallback onAdd,
    Function(int) onDelete,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$title (${links.length})",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: links.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "No links added",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: links.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = links.removeAt(oldIndex);
                      links.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = links[index];
                    return Container(
                      key: ValueKey("link_${title}_${index}_${item.label}"),
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.drag_indicator_rounded, size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.url,
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                                onPressed: () => _showEditLinkDialog(index, title, links),
                                tooltip: "Edit Link",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                onPressed: () => onDelete(index),
                                tooltip: "Delete Link",
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                hintText: "Link Label (e.g. Home)",
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      hintText: "Target URL (e.g. /faq)",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onAdd,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final textVal = text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final regExp = RegExp(
      r'(\*\*.*?\*\*)|(\*.*?\*)|(<u>.*?</u>)|(\[.*?\]\(.*?\))',
      dotAll: true,
    );

    int lastIndex = 0;
    
    final tagStyle = TextStyle(
      color: isDark ? Colors.white30 : Colors.black26,
      fontSize: 11,
    );

    for (final match in regExp.allMatches(textVal)) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: textVal.substring(lastIndex, match.start),
          style: style,
        ));
      }

      final matchedText = match.group(0)!;

      if (match.group(1) != null) {
        final content = matchedText.substring(2, matchedText.length - 2);
        children.add(TextSpan(text: '**', style: tagStyle));
        children.add(TextSpan(
          text: content,
          style: style?.copyWith(fontWeight: FontWeight.bold) ??
              const TextStyle(fontWeight: FontWeight.bold),
        ));
        children.add(TextSpan(text: '**', style: tagStyle));
      } else if (match.group(2) != null) {
        final content = matchedText.substring(1, matchedText.length - 1);
        children.add(TextSpan(text: '*', style: tagStyle));
        children.add(TextSpan(
          text: content,
          style: style?.copyWith(fontStyle: FontStyle.italic) ??
              const TextStyle(fontStyle: FontStyle.italic),
        ));
        children.add(TextSpan(text: '*', style: tagStyle));
      } else if (match.group(3) != null) {
        final content = matchedText.substring(3, matchedText.length - 4);
        children.add(TextSpan(text: '<u>', style: tagStyle));
        children.add(TextSpan(
          text: content,
          style: style?.copyWith(decoration: TextDecoration.underline) ??
              const TextStyle(decoration: TextDecoration.underline),
        ));
        children.add(TextSpan(text: '</u>', style: tagStyle));
      } else if (match.group(4) != null) {
        final closeBracketIdx = matchedText.indexOf(']');
        if (closeBracketIdx != -1) {
          final label = matchedText.substring(1, closeBracketIdx);
          final urlPart = matchedText.substring(closeBracketIdx + 1);
          
          children.add(TextSpan(text: '[', style: tagStyle));
          children.add(TextSpan(
            text: label,
            style: style?.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ) ??
                const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
          ));
          children.add(TextSpan(text: ']', style: tagStyle));
          children.add(TextSpan(text: urlPart, style: tagStyle));
        } else {
          children.add(TextSpan(text: matchedText, style: style));
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < textVal.length) {
      children.add(TextSpan(
        text: textVal.substring(lastIndex),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}

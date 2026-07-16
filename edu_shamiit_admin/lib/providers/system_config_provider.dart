import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class SystemConfig {
  final String systemName;
  final String systemTitle;
  final String? systemLogo;
  final String? favicon;
  final String primaryColor;
  final String theme;
  final String loginPageMessage;
  final String loginTitle;
  final String loginSubtitle;
  final String loginDesc;
  final String loginFeature1;
  final String loginFeature2;
  final String loginFeature3;
  final String loginFeature4;
  final String loginIllustration;
  final String forgotPasswordIllustration;
  final String resetPasswordIllustration;
  final String otpVerificationIllustration;
  final String contactEmail;
  final String contactPhone;
  final String contactAddress;
  final String liveChatInfo;

  SystemConfig({
    required this.systemName,
    required this.systemTitle,
    this.systemLogo,
    this.favicon,
    required this.primaryColor,
    required this.theme,
    required this.loginPageMessage,
    required this.loginTitle,
    required this.loginSubtitle,
    required this.loginDesc,
    required this.loginFeature1,
    required this.loginFeature2,
    required this.loginFeature3,
    required this.loginFeature4,
    required this.loginIllustration,
    required this.forgotPasswordIllustration,
    required this.resetPasswordIllustration,
    required this.otpVerificationIllustration,
    required this.contactEmail,
    required this.contactPhone,
    required this.contactAddress,
    required this.liveChatInfo,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final appearance = json['appearance_settings'] ?? {};
    final email = json['contact_email'] ?? 'support@schoolerp.com';
    final phone = json['contact_phone'] ?? '+91 98765 43210';
    final address = json['contact_address'] ?? 'School ERP Solutions Pvt. Ltd., Plot No. 123, Tech Park, Sector 62, Noida, Uttar Pradesh - 201309, India';
    final chatInfo = json['live_chat_info'] ?? 'Available in the application';

    // Update AppConfig static fields dynamically
    AppConfig.contactEmail = email;
    AppConfig.contactPhone = phone;
    AppConfig.contactAddress = address;
    AppConfig.liveChatInfo = chatInfo;

    return SystemConfig(
      systemName: json['system_name'] ?? 'School ERP',
      systemTitle: json['system_title'] ?? 'Next Generation School Management',
      systemLogo: json['system_logo'],
      favicon: json['favicon'],
      primaryColor: appearance['primary_color'] ?? '#4F46E5',
      theme: appearance['theme'] ?? 'Dark',
      loginPageMessage: json['login_page_message'] ?? '',
      loginTitle: appearance['login_title'] ?? 'Welcome Back!',
      loginSubtitle: appearance['login_subtitle'] ?? 'your account',
      loginDesc: appearance['login_desc'] ?? 'Access your dashboard and manage your institution with ease.',
      loginFeature1: appearance['login_feature1'] ?? 'Secure Access',
      loginFeature2: appearance['login_feature2'] ?? 'Smart Insights',
      loginFeature3: appearance['login_feature3'] ?? 'Role Based Dashboard',
      loginFeature4: appearance['login_feature4'] ?? 'Centralized Management',
      loginIllustration: appearance['login_illustration'] ?? '',
      forgotPasswordIllustration: appearance['forgot_password_illustration'] ?? '',
      resetPasswordIllustration: appearance['reset_password_illustration'] ?? '',
      otpVerificationIllustration: appearance['otp_verification_illustration'] ?? '',
      contactEmail: email,
      contactPhone: phone,
      contactAddress: address,
      liveChatInfo: chatInfo,
    );
  }
}

class SystemConfigNotifier extends StateNotifier<SystemConfig?> {
  SystemConfigNotifier() : super(null) {
    loadConfig();
  }

  Future<void> loadConfig() async {
    try {
      final res = await ApiService().get('/admin/system-config/public', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        state = SystemConfig.fromJson(res['data']);
      }
    } catch (e) {
      print("Error loading system config in provider: $e");
    }
  }

  void updateConfig(SystemConfig config) {
    state = config;
  }
}

final systemConfigProvider = StateNotifierProvider<SystemConfigNotifier, SystemConfig?>((ref) {
  return SystemConfigNotifier();
});

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

  SystemConfig({
    required this.systemName,
    required this.systemTitle,
    this.systemLogo,
    this.favicon,
    required this.primaryColor,
    required this.theme,
    required this.loginPageMessage,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    final appearance = json['appearance_settings'] ?? {};
    return SystemConfig(
      systemName: json['system_name'] ?? 'School ERP',
      systemTitle: json['system_title'] ?? 'Next Generation School Management',
      systemLogo: json['system_logo'],
      favicon: json['favicon'],
      primaryColor: appearance['primary_color'] ?? '#4F46E5',
      theme: appearance['theme'] ?? 'Dark',
      loginPageMessage: json['login_page_message'] ?? '',
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

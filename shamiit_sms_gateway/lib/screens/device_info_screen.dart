import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  Map<String, dynamic> _diag = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final diag = await PlatformBridge.getDiagnostics();
    if (!mounted) return;
    setState(() {
      _diag = diag;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            const AppTopBar(title: 'Device Information', showBackButton: true),
            Expanded(
              child: _loading
                  ? const LoadingState()
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        24 + MediaQuery.viewPaddingOf(context).bottom,
                      ),
                      children: [
                        StatusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.smartphone_rounded, color: AppColors.primaryBlue, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Hardware & Gateway Terminal',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              InfoMetricRow(label: 'Device ID', value: ApiService().deviceId, monospace: true, showDivider: true),
                              InfoMetricRow(label: 'Device Model', value: (_diag['device_model'] ?? 'Android').toString(), showDivider: true),
                              InfoMetricRow(label: 'Android OS', value: (_diag['android_version'] ?? 'Android').toString(), showDivider: true),
                              InfoMetricRow(label: 'School / Tenant ID', value: ApiService().schoolId, showDivider: true),
                              InfoMetricRow(label: 'Institution', value: ApiService().institutionName, showDivider: true),
                              InfoMetricRow(label: 'Backend Server', value: ApiService().displayServerHost, monospace: true, showDivider: true),
                              InfoMetricRow(label: 'Detected SIM Slots', value: '${_diag['sim_count'] ?? 0}', showDivider: true),
                              InfoMetricRow(
                                label: 'Keystore Encryption',
                                value: _diag['keystore_backed'] == true ? 'Active (AES-256)' : 'Standard',
                                statusIcon: Icons.verified_user_rounded,
                                statusColor: _diag['keystore_backed'] == true ? AppColors.successGreen : AppColors.warningOrange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        StatusCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                                ),
                                child: Image.asset(
                                  'assets/images/shamiit_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.sms_rounded, color: AppColors.primaryBlue),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(AppConstants.appTitle, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppConstants.companyName,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      AppConstants.tagline,
                                      style: TextStyle(color: AppColors.primaryBlue, fontStyle: FontStyle.italic, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Version ${AppConstants.appVersion} • support@shamiit.com',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                      ),
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
          ],
        ),
      ),
    );
  }
}

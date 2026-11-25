import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../widgets/common_components.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            const AppTopBar(title: 'Privacy & SMS Policy', showBackButton: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  StatusCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.policy_rounded, color: AppColors.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Enterprise SMS Compliance',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppConstants.companyName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PolicyCard(
                    icon: Icons.security_rounded,
                    color: AppColors.primaryBlue,
                    title: '1. Purpose & Permissions',
                    body:
                        'SHAMIIT SMS GATEWAY requests SEND_SMS, RECEIVE_SMS, READ_PHONE_STATE, and POST_NOTIFICATIONS exclusively to operate as an enterprise SMS gateway connected to your authorized SHAMIIT FastAPI server. READ_CONTACTS is requested only when you tap Contacts.',
                  ),
                  const SizedBox(height: 10),
                  const _PolicyCard(
                    icon: Icons.verified_user_outlined,
                    color: AppColors.purple,
                    title: '2. Google Play SMS Policy & Distribution',
                    body:
                        'Public Google Play distribution restricts SEND_SMS and RECEIVE_SMS to default SMS handlers or approved core use cases. For internal institutional and enterprise deployments, distribute via managed enterprise channels (Managed Google Play / MDM / signed enterprise APK).',
                  ),
                  const SizedBox(height: 10),
                  const _PolicyCard(
                    icon: Icons.enhanced_encryption_outlined,
                    color: AppColors.successGreen,
                    title: '3. Data Retention & Keystore Security',
                    body:
                        'Device tokens and auth credentials are stored in Android Keystore-backed EncryptedSharedPreferences. Pending events and incoming SMS are persisted locally in SQLite and never deleted prior to backend acknowledgment.',
                  ),
                  const SizedBox(height: 10),
                  const _PolicyCard(
                    icon: Icons.cell_tower_rounded,
                    color: AppColors.warningOrange,
                    title: '4. India Commercial SMS (DLT)',
                    body:
                        'Commercial/bulk A2P messaging over telecom networks in India may require DLT-registered headers and templates; configure DLT Template ID and Sender Header in Message Templates.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '© ${AppConstants.companyName} • ${AppConstants.tagline}',
                    textAlign: TextAlign.center,
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
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _PolicyCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StatusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.8,
              height: 1.5,
              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

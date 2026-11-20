import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/app_header.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          const AppHeader(
            title: 'Privacy Policy & Compliance',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.security_rounded,
                            color: AppColors.primaryNavy,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SHAMIIT Data Protection',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Financial Notification Privacy & Security Standards',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSection(
                    title: '1. On-Device Notification Processing',
                    icon: Icons.phonelink_lock_rounded,
                    content:
                        'SHAMIIT Payment Bridge operates strictly as an institutional terminal utility. '
                        'It inspects incoming notifications exclusively from whitelisted UPI banking applications '
                        '(such as PhonePe, Google Pay, Paytm, BHIM UPI, Canara ai1, and verified Bank SMS alerts).\n\n'
                        'Personal text messages, private chat applications, authentication OTPs, and unrelated app notifications '
                        'are never read, stored, transmitted, or logged. All filtering occurs directly on the local Android device before any event is queued.',
                  ),

                  _buildSection(
                    title: '2. PII Data Minimization & Masking',
                    icon: Icons.visibility_off_rounded,
                    content:
                        'To preserve payer confidentiality, sender identifiers and bank account numbers are masked '
                        'immediately at the parsing boundary (e.g. "**** 9821" or "XXXX2887"). '
                        'Only financial metadata required for accounting reconciliation—including monetary amount, '
                        'NPCI UPI transaction reference / UTR, originating app, and timestamp—are forwarded.',
                  ),

                  _buildSection(
                    title: '3. Encrypted Synchronization',
                    icon: Icons.vpn_key_rounded,
                    content:
                        'All communication between SHAMIIT Payment Bridge and the SHAMIIT Enterprise Backend is secured '
                        'using TLS 1.3 / HTTPS encryption and device token authorization. '
                        'Local cache on the terminal uses encrypted SQLite storage and isolated Android SharedPreferences.',
                  ),

                  _buildSection(
                    title: '4. Non-Authoritative Evidence Policy',
                    icon: Icons.verified_user_rounded,
                    content:
                        'In accordance with financial reconciliation best practices, notification events generated on '
                        'Android devices serve as provisional candidate payment signals only. '
                        'Final invoice settlement and definitive audit closure remain governed by official bank statements '
                        'and authorized banking partner verification.',
                  ),

                  _buildSection(
                    title: '5. Regulatory & DPDP Act Compliance',
                    icon: Icons.gavel_rounded,
                    content:
                        'This application is engineered for enterprise school and business accounts under the Digital Personal '
                        'Data Protection (DPDP) Act and Reserve Bank of India (RBI) payment guidelines. '
                        'Organizations maintain full sovereignty over their payment bridge logs with complete audit trail visibility.',
                  ),

                  _buildSection(
                    title: '6. Contact & Data Protection Officer',
                    icon: Icons.mail_outline_rounded,
                    content:
                        'For questions regarding data handling or security verification:\n'
                        '• Company: SHAMIIT Technologies Pvt. Ltd.\n'
                        '• Web: https://shamiit.com\n'
                        '• Email: privacy@shamiit.com / support@shamiit.com',
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'SHAMIIT Payment Bridge • Version 1.2.0 • Build 2026.11',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

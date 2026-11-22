import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';
import 'package:edu_shamiit_core/providers/system_config_provider.dart';

/// Screen displayed when an authenticated user's role is not authorized
/// for the current application (e.g. Admin user logging into the Academic app).
/// Allows the user to view their logged-in details, log out cleanly, and switch
/// to an authorized account without encountering broken or unmapped routes.
class SharedUnauthorizedRoleScreen extends ConsumerWidget {
  final String appName;
  final String allowedRolesDescription;
  final String? adminPortalUrl;

  const SharedUnauthorizedRoleScreen({
    super.key,
    this.appName = 'Academic Portal',
    this.allowedRolesDescription = 'Teachers, Students, and Parents',
    this.adminPortalUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final config = ref.watch(systemConfigProvider);
    final systemName = config?.systemName ?? 'School ERP';

    final userData = authState.userData ?? {};
    final userName = userData['name']?.toString() ??
        userData['full_name']?.toString() ??
        'User';
    final userEmail = userData['email']?.toString() ?? '';
    final roleName = _formatRoleName(authState.role.value);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // System Header & Branding
                  _buildBrandHeader(config, systemName),
                  const SizedBox(height: 32),

                  // Main Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF334155),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Shield Warning Badge
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                const Color(0xFFEF4444).withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 42,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Access Restricted',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'This account does not have permission to access the $appName.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Current User Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF6366F1),
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            userName,
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            roleName,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFFCD34D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userEmail.isNotEmpty ? userEmail : 'No email associated',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Friendly Explanation
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Color(0xFF60A5FA),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'The $appName is reserved for $allowedRolesDescription. To access your portal, please log out and sign in with your academic credentials.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12.5,
                                    color: const Color(0xFF93C5FD),
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Primary Action: Logout and Login with Another Account
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await ref.read(authProvider.notifier).signOut();
                              if (context.mounted) {
                                _safeNavigate(context, '/login');
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: Text(
                              'Logout & Login with Another Account',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Secondary Action: Go to Login / Switch Account
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(authProvider.notifier).signOut();
                              if (context.mounted) {
                                _safeNavigate(context, '/login');
                              }
                            },
                            icon: const Icon(Icons.switch_account_outlined, size: 18),
                            label: Text(
                              'Switch Account',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFCBD5E1),
                              side: const BorderSide(color: Color(0xFF475569)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Help / Contact Link
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.help_outline_rounded,
                            size: 15,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Believe this is an error? ',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              try {
                                context.push('/contact');
                              } catch (_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please contact your school administrator to adjust your role.'),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'Contact School Admin',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF818CF8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader(SystemConfig? config, String systemName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (config?.systemLogo != null && config!.systemLogo!.isNotEmpty)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              AppConfig.resolveUrl(config.systemLogo!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.school_outlined,
                color: Color(0xFF818CF8),
                size: 20,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: Color(0xFF818CF8),
              size: 20,
            ),
          ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              systemName,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Education Management System',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static void _safeNavigate(BuildContext context, String path) {
    try {
      context.go(path);
    } catch (_) {
      try {
        Navigator.of(context).pushReplacementNamed(path);
      } catch (_) {}
    }
  }

  static String _formatRoleName(String role) {
    if (role.isEmpty) return 'Staff';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

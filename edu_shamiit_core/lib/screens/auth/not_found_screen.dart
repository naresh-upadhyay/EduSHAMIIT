import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

/// Clean, responsive, and friendly 404 / Route Not Found screen
/// to prevent showing raw GoException errors to users.
class SharedNotFoundScreen extends ConsumerWidget {
  final String? path;
  final String appName;
  final bool isAcademicApp;

  const SharedNotFoundScreen({
    super.key,
    this.path,
    this.appName = 'EduSHAMIIT',
    this.isAcademicApp = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.isAuthenticated;
    final role = authState.role;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 404 badge icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.explore_off_rounded,
                        size: 38,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Page Not Found',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    Text(
                      path != null && path!.isNotEmpty
                          ? 'The requested page "$path" could not be found or is not available in $appName.'
                          : 'The page you are looking for does not exist or has been moved.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: const Color(0xFF94A3B8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Primary Navigation Button
                    if (isAuthenticated) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (isAcademicApp) {
                              if (role == UserRole.teacher) {
                                _safeNavigate(context, '/teacher/dashboard');
                              } else if (role == UserRole.student || role == UserRole.parent) {
                                _safeNavigate(context, '/student/dashboard');
                              } else {
                                _safeNavigate(context, '/unauthorized');
                              }
                            } else {
                              _safeNavigate(context, '/admin/dashboard');
                            }
                          },
                          icon: const Icon(Icons.home_rounded, size: 18),
                          label: Text(
                            'Back to Dashboard',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: Text(
                            'Logout & Switch Account',
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
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/login'),
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: Text(
                            'Go to Login',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_admin/providers/system_config_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  UserRole? _selectedRole = UserRole.superAdmin; // Default to Super Admin
  String? _roleErrorText;
  String? _warningMessage;

  // 0: Password Login, 1: OTP Login
  int _activeTab = 0;
  bool _isSendingOtp = false;
  String? _otpErrorText;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearWarning);
    _passwordController.addListener(_clearWarning);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _clearWarning() {
    if (_warningMessage != null) {
      setState(() {
        _warningMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearWarning);
    _passwordController.removeListener(_clearWarning);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    setState(() {
      if (_selectedRole == null) {
        _roleErrorText = 'Please select a role';
      } else {
        _roleErrorText = null;
      }
    });

    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid || _selectedRole == null) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final success = await ref.read(authProvider.notifier).signIn(
            email: email,
            password: password,
            role: _selectedRole!,
          );

      if (!mounted) return;

      if (success) {
        setState(() {
          _warningMessage = null;
        });
        _showSnackBar('Successfully authenticated!', Colors.green);
        context.go('/dashboard');
      } else {
        final errorMessage = ref.read(authProvider).error ??
            'Login failed. Please check your credentials.';
        setState(() {
          _warningMessage = errorMessage;
        });
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      final errorMsg = e.toString();
      setState(() {
        _warningMessage = errorMsg;
      });
      _showSnackBar('Error: $errorMsg', Colors.red);
    }
  }

  Future<void> _handleSendOtp() async {
    setState(() {
      _otpErrorText = null;
      if (_selectedRole == null) {
        _roleErrorText = 'Please select a role';
      } else {
        _roleErrorText = null;
      }
    });

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Email is required', Colors.orange);
      return;
    }

    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('Please enter a valid email address', Colors.orange);
      return;
    }

    if (_selectedRole == null) {
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/send-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': email}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        _showSnackBar('Verification code sent to your email!', Colors.green);
        context.push('/otp-verification', extra: {
          'email': email,
          'isLogin': true,
          'role': _selectedRole,
        });
      } else {
        setState(() {
          _otpErrorText = body['detail'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _otpErrorText = 'Connection error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSendingOtp = false;
      });
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF090B15),
              Color(0xFF101426),
              Color(0xFF1A1F3C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo & Title Header
                    _buildLogoHeader(),
                    const SizedBox(height: 24),

                    // Main Glassmorphic Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Method Switcher Tab (Password / OTP)
                            _buildTabSwitcher(),
                            const SizedBox(height: 24),

                            // Role Grid Select Header
                            const Text(
                              'SELECT ROLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 14 Roles Grid
                            _buildRolesGrid(),
                            if (_roleErrorText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _roleErrorText!,
                                  style: const TextStyle(
                                      color: Color(0xFFFF5252), fontSize: 11),
                                ),
                              ),
                            const SizedBox(height: 20),

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: 'Registered Email',
                              hint: 'example@school.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final emailRegex = RegExp(
                                    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // Animated Password Fields (if Password Tab active)
                            AnimatedCrossFade(
                              firstChild:
                                  _buildPasswordFields(authState.isLoading),
                              secondChild: const SizedBox.shrink(),
                              crossFadeState: _activeTab == 0
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              duration: const Duration(milliseconds: 300),
                            ),

                            if (_activeTab == 1 && _otpErrorText != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _otpErrorText!,
                                style: const TextStyle(
                                    color: Color(0xFFFF5252), fontSize: 12),
                              ),
                            ],
                            if (_warningMessage != null) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFF59E0B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _warningMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFFCD34D),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Action Button
                            _buildActionButton(authState.isLoading),
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
      ),
    );
  }

  Widget _buildLogoHeader() {
    final config = ref.watch(systemConfigProvider);
    final hasLogo = config?.systemLogo != null && config!.systemLogo!.isNotEmpty;

    return Column(
      children: [
        // Premium Glow icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: hasLogo
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.network(
                      config.systemLogo!,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Color(0xFF818CF8),
                        size: 36,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF818CF8),
                    size: 36,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Title Text with Premium Styling
        Text(
          config?.systemName ?? 'Admin Suite',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          config?.systemTitle ?? 'CORE CONTROLLER & ENTERPRISE PORTAL',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 2.0,
            fontFamily: 'Outfit',
          ),
          textAlign: TextAlign.center,
        ),
        if (config?.loginPageMessage != null && config!.loginPageMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
            ),
            child: RichSystemMessage(text: config.loginPageMessage),
          ),
        ],
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / 2;
          return Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: _activeTab == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  width: tabWidth,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 0),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color:
                                _activeTab == 0 ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = 1),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'OTP Code',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color:
                                _activeTab == 1 ? Colors.white : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRolesGrid() {
    final rolesList = [
      {'label': 'Super', 'icon': '🛡️', 'role': UserRole.superAdmin},
      {'label': 'Director', 'icon': '👑', 'role': UserRole.director},
      {'label': 'Principal', 'icon': '🎓', 'role': UserRole.principal},
      {'label': 'Admin', 'icon': '📋', 'role': UserRole.admin},
      {'label': 'Finance', 'icon': '💰', 'role': UserRole.finance},
      {'label': 'HR', 'icon': '👥', 'role': UserRole.hr},
      {'label': 'Transport', 'icon': '🚌', 'role': UserRole.transport},
      {'label': 'Library', 'icon': '📚', 'role': UserRole.library},
      {'label': 'Security', 'icon': '🔒', 'role': UserRole.security},
      {'label': 'Sports', 'icon': '⚽', 'role': UserRole.sports},
      {'label': 'Support', 'icon': '🎧', 'role': UserRole.support},
      {'label': 'Driver', 'icon': '🚐', 'role': UserRole.driver},
      {'label': 'Hostel', 'icon': '🏠', 'role': UserRole.hostel},
      {'label': 'Exam', 'icon': '📝', 'role': UserRole.examCtrl},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.15,
      ),
      itemCount: rolesList.length,
      itemBuilder: (context, index) {
        final item = rolesList[index];
        final isSelected = _selectedRole == item['role'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedRole = item['role'] as UserRole;
              _roleErrorText = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.white.withValues(alpha: 0.05),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['icon'] as String,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordFields(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF94A3B8),
              size: 18,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (value) {
            if (_activeTab == 0 && (value == null || value.isEmpty)) {
              return 'Password is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF818CF8), size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(bool isLoading) {
    final isOtpLoading = _isSendingOtp;
    final isButtonLoading = isLoading || isOtpLoading;

    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isButtonLoading
            ? null
            : (_activeTab == 0 ? _handlePasswordLogin : _handleSendOtp),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isButtonLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _activeTab == 0 ? 'Authenticate Control Suite' : 'Send OTP',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class RichSystemMessage extends StatelessWidget {
  final String text;
  const RichSystemMessage({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final List<TextSpan> spans = [];
    final regExp = RegExp(r'(\*\*.*?\*\*|\*.*?\*|<u>.*?</u>|[^\*<]+|[^<]+)');
    final matches = regExp.allMatches(text);

    for (final match in matches) {
      final part = match.group(0)!;
      if (part.startsWith('**') && part.endsWith('**')) {
        spans.add(TextSpan(
          text: part.substring(2, part.length - 2),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ));
      } else if (part.startsWith('*') && part.endsWith('*')) {
        spans.add(TextSpan(
          text: part.substring(1, part.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
        ));
      } else if (part.startsWith('<u>') && part.endsWith('</u>')) {
        spans.add(TextSpan(
          text: part.substring(3, part.length - 4),
          style: const TextStyle(decoration: TextDecoration.underline, color: Colors.white),
        ));
      } else {
        spans.add(TextSpan(
          text: part,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ));
      }
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(fontSize: 12, height: 1.5, fontFamily: 'Outfit'),
        children: spans,
      ),
    );
  }
}

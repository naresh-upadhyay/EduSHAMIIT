import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _rememberMe = false;
  
  // 0: Password Login, 1: OTP Login, 2: Biometric Login
  int _activeTab = 0;
  bool _isSendingOtp = false;
  bool _isScanningBiometric = false;
  String? _warningMessage;
  String? _otpErrorText;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearWarning);
    _passwordController.addListener(_clearWarning);
    _loadRememberedCredentials();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me_state') ?? false;
      if (rememberMe) {
        final email = prefs.getString('remembered_email') ?? '';
        final password = prefs.getString('remembered_password') ?? '';
        setState(() {
          _rememberMe = true;
          _emailController.text = email;
          _passwordController.text = password;
        });
      }
    } catch (e) {
      // Ignore preference loading errors
    }
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
      _warningMessage = null;
    });

    final isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final success = await ref.read(authProvider.notifier).signIn(
            email: email,
            password: password,
          );

      if (!mounted) return;

      if (success) {
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('remembered_email', email);
          await prefs.setString('remembered_password', password);
          await prefs.setBool('remember_me_state', true);
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('remembered_email');
          await prefs.remove('remembered_password');
          await prefs.setBool('remember_me_state', false);
        }

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

  Future<void> _handleBiometricLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address first', Colors.orange);
      return;
    }

    setState(() {
      _isScanningBiometric = true;
      _warningMessage = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isScanningBiometric = false;
    });

    // Simulated bypass for biometric verification
    final success = await ref.read(authProvider.notifier).signInWithOtp(
          email: email,
          otp: '123456',
        );

    if (!mounted) return;

    if (success) {
      context.go('/dashboard');
    } else {
      setState(() {
        _warningMessage = 'Biometric signature not registered. Please log in with password first.';
      });
    }
  }

  Future<void> _handleSendOtp() async {
    setState(() {
      _otpErrorText = null;
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
        context.go('/otp-verification', extra: {
          'email': email,
          'isLogin': true,
          'role': null, // Automatically resolved by backend
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final config = ref.watch(systemConfigProvider);

    return Scaffold(
      backgroundColor: isDesktop ? const Color(0xFFF8FAFC) : const Color(0xFF0F1026),
      body: isDesktop
          ? SingleChildScrollView(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1B1D3A), // Left side background fallback
                      Color(0xFFF8FAFC), // Right side background fallback
                    ],
                    stops: [0.4545, 0.4545],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildLeftBanner(),
                    ),
                    Expanded(
                      flex: 6,
                      child: _buildRightLoginForm(authState.isLoading),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F1026),
                    Color(0xFF1B1D3A),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMobileHeader(config),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _buildRightLoginForm(authState.isLoading, isMobile: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMobileHeader(SystemConfig? config) {
    final logoUrl = config?.systemLogo;
    final name = config?.systemName ?? 'School ERP';
    return InkWell(
      onTap: () => context.go('/'),
      child: Column(
        children: [
          if (logoUrl != null && logoUrl.isNotEmpty)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                AppConfig.resolveUrl(logoUrl),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF818CF8),
                    size: 32,
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF818CF8),
                size: 32,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Smart Management. Better Education.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftBanner({bool isMobile = false}) {
    final config = ref.watch(systemConfigProvider);
    final systemName = config?.systemName ?? 'School ERP';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1026),
            Color(0xFF1B1D3A),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: InkWell(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  if (config?.systemLogo != null && config!.systemLogo!.isNotEmpty)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        AppConfig.resolveUrl(config.systemLogo!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF818CF8),
                            size: 24,
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF818CF8),
                        size: 24,
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
                        'Smart Management. Better Education.',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
            if (!isMobile) ...[
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config?.loginTitle ?? 'Welcome Back!',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        children: [
                          const TextSpan(text: 'Sign in to '),
                          TextSpan(
                            text: config?.loginSubtitle ?? 'your account',
                            style: const TextStyle(color: Color(0xFF818CF8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Glowing gradient underline accent
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      config?.loginDesc ?? 'Access your dashboard and manage your institution with ease.',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // 3D Laptop illustration (dynamic with asset fallback)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return RadialGradient(
                      center: Alignment.center,
                      radius: 0.7,
                      colors: [
                        Colors.black,
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.85, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Builder(
                    builder: (context) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      final imageHeight = (screenHeight * 0.38).clamp(240.0, 420.0);
                      final imageUrl = config?.loginIllustration ?? '';
                      if (imageUrl.isNotEmpty) {
                        return Image.network(
                          AppConfig.resolveUrl(imageUrl),
                          width: double.infinity,
                          height: imageHeight,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildFallbackIllustration('assets/images/login_illustration.png', imageHeight: imageHeight),
                        );
                      }
                      return _buildFallbackIllustration('assets/images/login_illustration.png', imageHeight: imageHeight);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Feature grid & bottom banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildFeatureIcon(Icons.lock_outline, config?.loginFeature1.replaceAll(' ', '\n') ?? 'Secure\nAccess'),
                        ),
                        Expanded(
                          child: _buildFeatureIcon(Icons.bar_chart_outlined, config?.loginFeature2.replaceAll(' ', '\n') ?? 'Smart\nInsights'),
                        ),
                        Expanded(
                          child: _buildFeatureIcon(Icons.dashboard_outlined, config?.loginFeature3.replaceAll(' ', '\n') ?? 'Role Based\nDashboard'),
                        ),
                        Expanded(
                          child: _buildFeatureIcon(Icons.layers_outlined, config?.loginFeature4.replaceAll(' ', '\n') ?? 'Centralized\nManagement'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Bottom trusted banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Color(0xFF818CF8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Secure & Trusted Platform',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Your data is protected with enterprise-grade security and privacy.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: Colors.white60,
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
          ],
        ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: Colors.white70,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildRightLoginForm(bool isLoading, {bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back, size: 14, color: Color(0xFF475569)),
                    label: Text(
                      'Back to Home',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language_outlined, size: 14, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              'English',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.wb_sunny_outlined,
                          size: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Main Form Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1.5,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login to Your Account',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your email to login with password or OTP',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      if (_activeTab == 0 && _warningMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _warningMessage!,
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF991B1B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_activeTab == 1 && _otpErrorText != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _otpErrorText!,
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF991B1B),
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
                      // Email
                      _buildInputLabel('Email Address'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Enter your email address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex = RegExp(
                              r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
                          if (!emailRegex.hasMatch(value.trim())) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Tab Selection
                      _buildMethodSelector(),
                      const SizedBox(height: 20),
                      if (_activeTab == 0) ...[
                        // Password Form
                        _buildInputLabel('Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF94A3B8),
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
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: const Color(0xFF6366F1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remember me',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Login Button
                        _buildPrimaryButton(
                          label: 'Login',
                          icon: Icons.arrow_forward,
                          isLoading: isLoading,
                          onPressed: _handlePasswordLogin,
                        ),
                      ] else ...[
                        // OTP Form details
                        const SizedBox(height: 12),
                        Text(
                          'Click below to send a secure one-time passcode to your email.',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildPrimaryButton(
                          label: 'Send OTP to Email',
                          icon: Icons.mail_outline,
                          isLoading: _isSendingOtp,
                          onPressed: _handleSendOtp,
                        ),
                      ],

                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                                children: const [
                                  TextSpan(text: "Don't have an account? "),
                                  TextSpan(
                                    text: 'Contact your administrator',
                                    style: TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => context.go('/contact'),
                              icon: const Icon(Icons.mail_outline, size: 14, color: Color(0xFF4F46E5)),
                              label: Text(
                                'Contact Us / Submit Query',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4F46E5),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.security_outlined,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'School ERP © 2025. All rights reserved.',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Choose Login Method',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 0),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _activeTab == 0 ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _activeTab == 0 ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 16,
                        color: _activeTab == 0 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Password Login',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 0 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 1),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? const Color(0xFFEEF2FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _activeTab == 1 ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mail_outline,
                        size: 16,
                        color: _activeTab == 1 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OTP Login',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _activeTab == 1 ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFallbackIllustration(String defaultUrl, {required double imageHeight}) {
    final isAsset = defaultUrl.startsWith('assets/');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: isAsset
          ? Image.asset(
              defaultUrl,
              width: double.infinity,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white30,
                      size: 64,
                    ),
                  ),
                );
              },
            )
          : Image.network(
              defaultUrl,
              width: double.infinity,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.white30,
                      size: 64,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

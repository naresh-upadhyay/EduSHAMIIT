import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';
import 'forgot_password_screen.dart';
import 'main_navigation_shell.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isSendingOtp = false;
  int _activeTab = 0; // 0: Password, 1: OTP
  String? _warningMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('sms_remember_me') ?? false;
    final email = prefs.getString('sms_remembered_email') ?? '';
    final pwd = prefs.getString('sms_remembered_password') ?? '';
    if ((remember || (email.isNotEmpty && pwd.isNotEmpty)) && mounted) {
      setState(() {
        _rememberMe = true;
        _emailController.text = email;
        _passwordController.text = pwd;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _warningMessage = null;
    });
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;

    try {
      final res = await ApiService().loginWithPassword(email: email, password: pwd);
      if (!mounted) return;
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('sms_remembered_email', email);
          await prefs.setString('sms_remembered_password', pwd);
          await prefs.setBool('sms_remember_me', true);
        } else {
          await prefs.remove('sms_remembered_email');
          await prefs.remove('sms_remembered_password');
          await prefs.setBool('sms_remember_me', false);
        }
        TextInput.finishAutofillContext();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        );
      } else {
        setState(() => _warningMessage = res['detail']?.toString() ?? 'Login failed');
      }
    } catch (e) {
      setState(() => _warningMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      setState(() => _warningMessage = 'Enter a valid email address');
      return;
    }
    setState(() {
      _isSendingOtp = true;
      _warningMessage = null;
    });
    try {
      final res = await ApiService().sendLoginOtp(email);
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email)),
        );
      } else {
        setState(() => _warningMessage = res['detail']?.toString() ?? 'Failed to send OTP');
      }
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _showServerConfigDialog() async {
    final ctrl = TextEditingController(text: ApiService().displayServerHost);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AppDialogFrame(
          icon: Icons.dns_rounded,
          iconColor: AppColors.primaryBlue,
          title: 'Backend Server URL',
          subtitle: 'Select an environment preset or enter custom host',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Cloud (Live)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    onPressed: () => setDlg(() => ctrl.text = AppConstants.liveServerBaseUrl),
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    onPressed: () => setDlg(() => ctrl.text = AppConstants.localServerBaseUrlAndroid),
                  ),
                  ActionChip(
                    label: const Text('Localhost', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    onPressed: () => setDlg(() => ctrl.text = AppConstants.localServerBaseUrlLoopback),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'FastAPI Server Host',
                  hintText: 'https://eduapi.shamiit.com',
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != null && saved.trim().isNotEmpty) {
      await ApiService().setServerUrl(saved);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SkyHeaderContainer(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppShapes.softShadow,
                            ),
                            child: Image.asset(
                              'assets/images/shamiit_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.sms_rounded,
                                color: AppColors.primaryBlue,
                                size: 38,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'SHAMIIT SMS GATEWAY',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppConstants.companyName} • ${AppConstants.tagline}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    StatusCard(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Admin Login',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Authenticate to link this Android SMS terminal',
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceElevated : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TabPill(
                                      label: 'Password',
                                      active: _activeTab == 0,
                                      onTap: () => setState(() => _activeTab = 0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TabPill(
                                      label: 'Email OTP',
                                      active: _activeTab == 1,
                                      onTap: () => setState(() => _activeTab = 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_warningMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.errorRed.withValues(alpha: 0.16) : AppColors.errorRedBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  _warningMessage!,
                                  style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: Icon(Icons.email_outlined, size: 18),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Email is required';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            if (_activeTab == 0) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'Remember me',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12.5),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                    ),
                                    child: const Text('Forgot Password?'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handlePasswordLogin,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('Login to Gateway'),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isSendingOtp ? null : _handleSendOtp,
                                  child: _isSendingOtp
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('Send Login OTP'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: _showServerConfigDialog,
                        icon: const Icon(Icons.dns_outlined, size: 16),
                        label: Text(
                          'Server: ${ApiService().displayServerHost}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
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
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? (isDark ? AppColors.darkCard : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active && !isDark ? AppShapes.softShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: active
                ? AppColors.primaryBlue
                : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
          ),
        ),
      ),
    );
  }
}

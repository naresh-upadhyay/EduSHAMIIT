import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';
import 'main_navigation_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _remainingSeconds = 180;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 180);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit OTP code');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiService().verifyLoginOtp(email: widget.email, otp: otp);
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          (_) => false,
        );
      } else {
        setState(() => _errorMessage = res['detail']?.toString() ?? 'Verification failed');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final min = _remainingSeconds ~/ 60;
    final sec = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            const AppTopBar(title: 'Verify OTP', showBackButton: true),
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: StatusCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.mark_email_read_outlined, size: 30, color: AppColors.primaryBlue),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Verify Your Identity',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-digit code sent to\n${widget.email}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.errorRed.withValues(alpha: 0.16) : AppColors.errorRedBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            controller: _otpController,
                            maxLength: 6,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '000000',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Expires in $min:$sec',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOtp,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text('Verify & Login'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _remainingSeconds == 0
                                ? () async {
                                    await ApiService().sendLoginOtp(widget.email);
                                    _startTimer();
                                  }
                                : null,
                            child: const Text('Resend OTP'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

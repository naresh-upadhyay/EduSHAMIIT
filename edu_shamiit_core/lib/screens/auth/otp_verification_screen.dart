import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/constants/app_gradients.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/providers/role_provider.dart';

class SharedOtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final bool isLogin;
  final UserRole? role;
  final bool isAdmin;

  const SharedOtpVerificationScreen({
    super.key,
    required this.email,
    this.isLogin = false,
    this.role,
    this.isAdmin = false,
  });

  @override
  ConsumerState<SharedOtpVerificationScreen> createState() =>
      _SharedOtpVerificationScreenState();
}

class _SharedOtpVerificationScreenState
    extends ConsumerState<SharedOtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _remainingSeconds = 180; // 3 minutes
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          }
          if (_remainingSeconds <= 0) {
            _canResend = true;
          }
        });
        if (_remainingSeconds > 0) {
          _startTimer();
        }
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.isLogin) {
        final success = await ref.read(authProvider.notifier).signInWithOtp(
              email: widget.email,
              otp: _otp,
              role: widget.role ?? (widget.isAdmin ? UserRole.superAdmin : UserRole.student),
            );

        if (!mounted) return;

        if (success) {
          if (widget.isAdmin) {
            context.go('/dashboard');
          } else {
            final userRole = ref.read(authProvider).role;
            if (userRole == UserRole.teacher) {
              context.go('/teacher/dashboard');
            } else {
              context.go('/student/dashboard');
            }
          }
        } else {
          final errorMessage =
              ref.read(authProvider).error ?? 'OTP verification failed';
          _showError(errorMessage);
          _clearOtp();
        }
      } else {
        final response = await http.post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/verify-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identifier': widget.email,
            'otp': _otp,
          }),
        );

        final data = jsonDecode(response.body);

        if (!mounted) return;

        if (data['success'] == true) {
          context.pushReplacement(
            '/reset-password',
            extra: {
              'email': widget.email,
              'otp': _otp,
            },
          );
        } else {
          _showError(data['detail'] ?? 'Invalid OTP');
          _clearOtp();
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _remainingSeconds = 180;
    });

    try {
      final path = widget.isLogin ? 'send-login-otp' : 'send-otp';
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': widget.email,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data['success'] == true) {
        _showSuccess('OTP resent successfully');
        _startTimer();
      } else {
        setState(() {
          _canResend = true;
        });
        _showError(data['detail'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _canResend = true;
      });
      _showError('Network error. Please try again.');
    }
  }

  void _clearOtp() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C0728), Color(0xFF1E1145), Color(0xFF130932)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Logo Header
                    _buildLogoHeader(),
                    const SizedBox(height: 24),

                    // Main Glassmorphic Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // OTP Inputs Row
                          _buildOtpInputs(),
                          const SizedBox(height: 24),

                          // Timer & Resend
                          _buildTimerResend(),
                          const SizedBox(height: 28),

                          // Verify Button
                          _buildVerifyButton(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Back to Login Link
                    _buildFooterLink(),
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
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
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
          child: const Center(
            child: Text(
              '📱',
              style: TextStyle(fontSize: 38),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enter OTP',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a 6-digit OTP to\n${widget.email}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 44,
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _focusNodes[index + 1].requestFocus();
              }
              // Auto-verify when all 6 digits are entered
              if (index == 5 && value.isNotEmpty) {
                _verifyOtp();
              }
            },
            onFieldSubmitted: (value) {
              if (value.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildTimerResend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_canResend)
          Text(
            'Resend OTP in $_formattedTime',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          )
        else
          TextButton(
            onPressed: _resendOtp,
            child: const Text(
              'Resend OTP',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifyButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: AppGradients.studentPrimary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildFooterLink() {
    return TextButton(
      onPressed: () => context.pop(),
      child: const Text(
        'Back to Login',
        style: TextStyle(
          color: Color(0xFF818CF8),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

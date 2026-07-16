import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/config/app_config.dart';

class SharedGetStartedScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;

  const SharedGetStartedScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
  }) : super(key: key);

  @override
  State<SharedGetStartedScreen> createState() => _SharedGetStartedScreenState();
}

class _SharedGetStartedScreenState extends State<SharedGetStartedScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isLoadingPlans = true;

  // Step 1: Basic Info Form Controllers
  final _basicFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = true;

  // Step 2: School Info Form Controllers
  final _schoolFormKey = GlobalKey<FormState>();
  final _schoolNameController = TextEditingController();
  final _schoolAddressController = TextEditingController();
  final _schoolPhoneController = TextEditingController();
  String _selectedBoard = 'CBSE';
  final List<String> _boards = ['CBSE', 'ICSE', 'State Board', 'IB', 'Other'];

  // Step 3: Plan & Payment Controllers
  List<dynamic> _plans = [];
  String _selectedPlanCode = 'premium';
  String _billingCycle = 'monthly'; // 'monthly' or 'yearly'
  String _paymentMethod = 'upi'; // 'upi', 'card', 'netbanking'
  
  // Payment Details Controllers
  final _paymentFormKey = GlobalKey<FormState>();
  final _upiIdController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  String _selectedBank = 'State Bank of India';
  final List<String> _banks = [
    'State Bank of India',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Punjab National Bank'
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    
    _schoolNameController.dispose();
    _schoolAddressController.dispose();
    _schoolPhoneController.dispose();

    _upiIdController.dispose();
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlans() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/auth/plans'));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        setState(() {
          _plans = body['data']['plans'] ?? [];
          _isLoadingPlans = false;
        });
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching plans: $e');
      setState(() {
        // Fallback static plans if API fails
        _plans = [
          {
            'name': 'Basic Plan',
            'code': 'basic',
            'price_per_month': 499.0,
            'price_per_year': 4999.0,
            'features': ['Core ERP Modules', 'LMS access', 'Up to 500 students', 'Email support']
          },
          {
            'name': 'Premium Plan',
            'code': 'premium',
            'price_per_month': 1199.0,
            'price_per_year': 11999.0,
            'features': ['Advanced Analytics', 'IoT Node controller', 'Up to 2000 students', 'Priority 24/7 support', 'Custom branding']
          },
          {
            'name': 'Enterprise Custom',
            'code': 'enterprise',
            'price_per_month': 4999.0,
            'price_per_year': 49999.0,
            'features': ['Unlimited students', 'Dedicated server hosting', 'Custom API Integrations', 'Dedicated Account Manager']
          }
        ];
        _isLoadingPlans = false;
      });
    }
  }

  double _calculateAmount() {
    if (_plans.isEmpty) return 0.0;
    final plan = _plans.firstWhere((p) => p['code'] == _selectedPlanCode, orElse: () => _plans[0]);
    if (_billingCycle == 'yearly') {
      return (plan['price_per_year'] ?? 0.0).toDouble();
    } else {
      return (plan['price_per_month'] ?? 0.0).toDouble();
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_paymentFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final payload = {
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
      'full_name': _fullNameController.text.trim(),
      'school_name': _schoolNameController.text.trim(),
      'school_address': _schoolAddressController.text.trim(),
      'school_phone': _schoolPhoneController.text.trim(),
      'board': _selectedBoard,
      'plan_code': _selectedPlanCode,
      'billing_cycle': _billingCycle,
      'payment_method': _paymentMethod,
      'payment_amount': _calculateAmount()
    };

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/onboard-school'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _currentStep = 3; // Step 4 (Done)
        });
      } else {
        _showErrorSnackBar(data['detail'] ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;
    final name = widget.systemName ?? 'School ERP';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildNavbar(isDesktop, name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 40,
              ),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left column
                        Expanded(
                          flex: 5,
                          child: _buildLeftInfoColumn(),
                        ),
                        const SizedBox(width: 60),
                        // Right column (Stepper Card)
                        Expanded(
                          flex: 6,
                          child: _buildRightStepperCard(name),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildLeftInfoColumn(),
                        const SizedBox(height: 40),
                        _buildRightStepperCard(name),
                      ],
                    ),
            ),
            _buildFooter(screenWidth >= 1100, name),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar(bool isDesktop, String name) {
    final logoUrl = widget.systemLogo;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            InkWell(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        AppConfig.resolveUrl(logoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.school_outlined,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Smart Management. Better Education.',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isDesktop) ...[
              _buildNavbarLink('Home', () => context.go('/')),
              _buildNavbarLink('Features', () => context.go('/')),
              _buildNavbarLink('Modules', () => context.go('/')),
              _buildNavbarLink('Pricing', () => context.go('/')),
              _buildNavbarLink('About Us', () => context.go('/')),
              _buildNavbarLink('Contact Us', () => context.go('/contact')),
              const SizedBox(width: 24),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Login', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.login, color: Color(0xFF6366F1)),
                onPressed: () => context.go('/login'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbarLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF475569)),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLeftInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Get Started in Minutes',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Let\'s Set Up Your\nSchool ERP',
          style: GoogleFonts.outfit(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Create your account and take the first step towards smarter school management. It\'s quick, easy, and free to get started!',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        // School Illustration
        Center(
          child: Image.asset(
            'assets/images/school_building_illustration.png',
            width: 320,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 320,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.school, size: 80, color: Color(0xFF6366F1)),
            ),
          ),
        ),
        const SizedBox(height: 48),
        Text(
          'Why Schools Choose School ERP',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 24),
        _buildBenefitItem(Icons.verified_user_outlined, 'All-in-One Solution', 'Manage all academic and administrative operations in one integrated platform.'),
        _buildBenefitItem(Icons.assignment_outlined, 'Save Time & Effort', 'Automate repetitive tasks and streamline workflows to save valuable time.'),
        _buildBenefitItem(Icons.people_outline, 'Better Communication', 'Enhance communication between teachers, students, and parents.'),
        _buildBenefitItem(Icons.lock_outline, 'Secure & Reliable', 'Your data is protected with enterprise-grade security and regular backups.'),
        _buildBenefitItem(Icons.headset_mic_outlined, '24/7 Support', 'Our dedicated support team is always here to help you succeed.'),
        const SizedBox(height: 32),
        // Help Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.headset_mic, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help Getting Started?',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Our team is here to help you every step of the way.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go('/contact'),
                child: Row(
                  children: [
                    Text(
                      'Contact Support',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF4F46E5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightStepperCard(String name) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          // Step 1-3 Header Icon
          if (_currentStep < 3) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_outlined, color: Color(0xFF6366F1), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Get Started',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create your School ERP account',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            // Custom Stepper Progress Indicator
            _buildStepperProgress(),
            const SizedBox(height: 40),
          ],
          // Step Content Switcher
          _buildStepContent(name),
        ],
      ),
    );
  }

  Widget _buildStepperProgress() {
    return Row(
      children: [
        _buildStepIndicator(0, 'Basic Info'),
        _buildStepLine(0),
        _buildStepIndicator(1, 'School Info'),
        _buildStepLine(1),
        _buildStepIndicator(2, 'Payment'),
      ],
    );
  }

  Widget _buildStepIndicator(int index, String label) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF10B981)
                  : (isActive ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive || isDone ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int afterIndex) {
    final isDone = _currentStep > afterIndex;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildStepContent(String name) {
    switch (_currentStep) {
      case 0:
        return _buildStep1BasicInfo();
      case 1:
        return _buildStep2SchoolInfo();
      case 2:
        return _buildStep3Payment();
      case 3:
        return _buildStep4Done(name);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1BasicInfo() {
    return Form(
      key: _basicFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            validator: (value) => value == null || value.trim().isEmpty ? 'Full name is required' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'Enter your email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Invalid email format';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'Enter your phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) => value == null || value.trim().isEmpty ? 'Phone number is required' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Create a password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm your password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B), size: 18),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Confirm password is required';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          // Agreement Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                activeColor: const Color(0xFF6366F1),
                onChanged: (val) => setState(() => _agreeToTerms = val ?? true),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RichText(
                    text: TextSpan(
                      text: 'By creating an account, you agree to our ',
                      style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: InkWell(
                            onTap: () => context.go('/terms-conditions'),
                            child: Text(
                              'Terms & Conditions',
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: InkWell(
                            onTap: () => context.go('/privacy-policy'),
                            child: Text(
                              'Privacy Policy',
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_basicFormKey.currentState!.validate() && _agreeToTerms) {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next: Add School Information',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B))),
              InkWell(
                onTap: () => context.go('/login'),
                child: Text('Login', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2SchoolInfo() {
    return Form(
      key: _schoolFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(
            controller: _schoolNameController,
            label: 'School Name',
            hint: 'Enter your school/institution name',
            icon: Icons.school_outlined,
            validator: (value) => value == null || value.trim().isEmpty ? 'School name is required' : null,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _schoolAddressController,
            label: 'School Address',
            hint: 'Enter full school address',
            icon: Icons.location_on_outlined,
            validator: (value) => value == null || value.trim().isEmpty ? 'School address is required' : null,
          ),
          const SizedBox(height: 20),
          // Board Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Affiliation Board',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedBoard,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.assignment_ind_outlined, color: Color(0xFF94A3B8), size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0F172A)),
                items: _boards.map((board) {
                  return DropdownMenuItem<String>(
                    value: board,
                    child: Text(board),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBoard = val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _schoolPhoneController,
            label: 'School Phone',
            hint: 'Enter school contact number',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            validator: (value) => value == null || value.trim().isEmpty ? 'School contact number is required' : null,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_schoolFormKey.currentState!.validate()) {
                setState(() => _currentStep = 2);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next: Choose Plan & Pay',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            child: Text('Back to Basic Info', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Payment() {
    if (_isLoadingPlans) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    return Form(
      key: _paymentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Select Subscription Plan',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          // Plans List
          ..._plans.map((plan) {
            final isSelected = plan['code'] == _selectedPlanCode;
            final price = _billingCycle == 'yearly'
                ? plan['price_per_year'] ?? 0.0
                : plan['price_per_month'] ?? 0.0;
            final features = List<String>.from(plan['features'] ?? []);

            return InkWell(
              onTap: () => setState(() => _selectedPlanCode = plan['code']),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6366F1).withOpacity(0.02) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          plan['name'] ?? 'Plan',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '₹${price.toInt()} / ${_billingCycle == 'yearly' ? 'yr' : 'mo'}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      features.join(' • '),
                      style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          // Billing Cycle Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Monthly', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
              Switch(
                value: _billingCycle == 'yearly',
                activeColor: const Color(0xFF6366F1),
                onChanged: (val) => setState(() => _billingCycle = val ? 'yearly' : 'monthly'),
              ),
              Text('Yearly (Save 10%)', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Select Payment Method',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPaymentMethodOption('upi', 'UPI', Icons.qr_code_outlined),
              const SizedBox(width: 12),
              _buildPaymentMethodOption('card', 'Cards', Icons.credit_card_outlined),
              const SizedBox(width: 12),
              _buildPaymentMethodOption('netbanking', 'NetBanking', Icons.account_balance_outlined),
            ],
          ),
          const SizedBox(height: 24),
          // Render conditional details
          _buildPaymentDetailsInputs(),
          const SizedBox(height: 32),
          // Complete Onboarding Button
          ElevatedButton(
            onPressed: _isLoading ? null : _submitOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pay ₹${_calculateAmount().toInt()} & Register School',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            child: Text('Back to School Info', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption(String code, String label, IconData icon) {
    final isSelected = _paymentMethod == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMethod = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withOpacity(0.04) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B), size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsInputs() {
    if (_paymentMethod == 'upi') {
      return _buildTextField(
        controller: _upiIdController,
        label: 'UPI ID',
        hint: 'username@upi',
        icon: Icons.qr_code,
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'UPI ID is required';
          if (!value.contains('@')) return 'Invalid UPI ID';
          return null;
        },
      );
    } else if (_paymentMethod == 'card') {
      return Column(
        children: [
          _buildTextField(
            controller: _cardNumberController,
            label: 'Card Number',
            hint: '1234 5678 1234 5678',
            icon: Icons.credit_card,
            keyboardType: TextInputType.number,
            validator: (value) => value == null || value.trim().isEmpty ? 'Card number is required' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cardExpiryController,
                  label: 'Expiry Date',
                  hint: 'MM/YY',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.datetime,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _cardCvvController,
                  label: 'CVV',
                  hint: '123',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Bank',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedBank,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.account_balance, color: Color(0xFF94A3B8), size: 18),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0F172A)),
            items: _banks.map((bank) {
              return DropdownMenuItem<String>(
                value: bank,
                child: Text(bank),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedBank = val);
              }
            },
          ),
        ],
      );
    }
  }

  Widget _buildStep4Done(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 72),
        ),
        const SizedBox(height: 24),
        Text(
          'Onboarding Request Submitted!',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your school registration is pending superadmin review. Admin credentials will start working immediately once the school subscription is marked as Active.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => context.go('/'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F1026),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          ),
          child: Text(
            'Back to Home',
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold),
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
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildFooter(bool showWideFooter, String name) {
    return Container(
      color: const Color(0xFF0F1026),
      padding: EdgeInsets.symmetric(
        horizontal: showWideFooter ? 64 : 24,
        vertical: 60,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: showWideFooter ? 3 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'An all-in-one school management system designed to simplify administration, improve communication and enhance overall efficiency.',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: Colors.white60,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildSocialIcon(Icons.facebook),
                        _buildSocialIcon(Icons.camera_alt),
                        _buildSocialIcon(Icons.alternate_email),
                        _buildSocialIcon(Icons.play_circle_filled),
                      ],
                    ),
                  ],
                ),
              ),
              if (showWideFooter) ...[
                const SizedBox(width: 48),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn('Quick Links', const ['Home', 'Features', 'Modules', 'Pricing', 'About Us', 'Contact Us', 'FAQ', 'Help Center']),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn('Modules', const ['Student Management', 'Attendance Management', 'Examination Management', 'Fee Management', 'Transport Management', 'Library Management']),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 2,
                  child: _buildFooterColumn('Support', const ['Help Center', 'User Guides', 'FAQ\'s', 'Privacy Policy', 'Terms & Conditions']),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Us',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooterContactItem(Icons.location_on_outlined, AppConfig.contactAddress),
                      _buildFooterContactItem(Icons.email_outlined, AppConfig.contactEmail),
                      _buildFooterContactItem(Icons.phone_outlined, AppConfig.contactPhone),
                      _buildFooterContactItem(Icons.access_time_outlined, 'Mon - Sat: 9:00 AM - 6:00 PM'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!showWideFooter) ...[
            const SizedBox(height: 32),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            Wrap(
              spacing: 48,
              runSpacing: 32,
              children: [
                SizedBox(
                  width: 180,
                  child: _buildFooterColumn('Quick Links', const ['Home', 'Features', 'Modules', 'Pricing', 'About Us', 'Contact Us', 'FAQ', 'Help Center']),
                ),
                SizedBox(
                  width: 220,
                  child: _buildFooterColumn('Modules', const ['Student Management', 'Attendance Management', 'Examination Management', 'Fee Management', 'Transport Management', 'Library Management']),
                ),
                SizedBox(
                  width: 180,
                  child: _buildFooterColumn('Support', const ['Help Center', 'User Guides', 'FAQ\'s', 'Privacy Policy', 'Terms & Conditions']),
                ),
                SizedBox(
                  width: 260,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Us',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFooterContactItem(Icons.location_on_outlined, AppConfig.contactAddress),
                      _buildFooterContactItem(Icons.email_outlined, AppConfig.contactEmail),
                      _buildFooterContactItem(Icons.phone_outlined, AppConfig.contactPhone),
                      _buildFooterContactItem(Icons.access_time_outlined, 'Mon - Sat: 9:00 AM - 6:00 PM'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 48),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2025 $name. All rights reserved.',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white54, size: 16),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  if (item == 'Contact Us') {
                    context.go('/contact');
                  } else if (item == 'Home') {
                    context.go('/');
                  } else if (item == 'Privacy Policy') {
                    context.go('/privacy-policy');
                  } else if (item == 'Terms & Conditions') {
                    context.go('/terms-conditions');
                  } else if (item == 'FAQ' || item == 'FAQ\'s') {
                    context.go('/faq');
                  } else if (item == 'Help Center') {
                    context.go('/help-center');
                  } else if (item == 'User Guides') {
                    context.go('/user-guides');
                  }
                },
                child: Text(
                  item,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFooterContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

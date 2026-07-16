import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/widgets/public_drawer.dart';

class SharedContactUsScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;
  final String? illustrationUrl;

  const SharedContactUsScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
    this.illustrationUrl,
  }) : super(key: key);

  @override
  State<SharedContactUsScreen> createState() => _SharedContactUsScreenState();
}

class _SharedContactUsScreenState extends State<SharedContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedSubject = 'General Inquiry';
  bool _isLoading = false;
  int _charCount = 0;

  final List<String> _subjects = [
    'General Inquiry',
    'Technical Support',
    'Billing & Finance',
    'Admissions & Enrollment',
    'Feedback & Suggestions',
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _charCount = _messageController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/contact/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'subject': _selectedSubject,
          'message': _messageController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        _showSnackBar('Your query has been sent successfully!', Colors.green);
        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
        setState(() {
          _selectedSubject = 'General Inquiry';
        });
      } else {
        _showSnackBar(data['detail'] ?? 'Failed to send query. Try again.', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Network error. Please check your connection.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final name = widget.systemName ?? 'School ERP';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildNavbar(isDesktop, name),
      ),
      drawer: isDesktop ? null : PublicDrawer(
        systemName: name,
        systemLogo: widget.systemLogo,
      ),
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
                      child: _buildRightForm(isMobile: false),
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
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _buildRightForm(isMobile: true),
                        ),
                        const SizedBox(height: 24),
                        _buildOfficeCard(isMobile: true),
                        const SizedBox(height: 24),
                        _buildFooterLinks(),
                      ],
                    ),
                  ),
                ),
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
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Color(0xFF0F172A)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbarLink(String label, VoidCallback onTap) {
    final isActive = label == 'Contact Us';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569),
        ),
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

  Widget _buildLeftBanner() {
    const imageHeight = 260.0;

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
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    children: const [
                      TextSpan(text: "We're Here to "),
                      TextSpan(
                        text: 'Help You!',
                        style: TextStyle(color: Color(0xFF818CF8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Have a question, suggestion, or need assistance? Our team is ready to help you with the best solutions.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const RadialGradient(
                    center: Alignment.center,
                    radius: 0.65,
                    colors: [
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.8, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/images/contact_illustration.png',
                  height: imageHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: imageHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.contact_support_outlined,
                        color: Colors.white30,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Other Ways to Reach Us',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildContactInfoRow(
                  Icons.email_outlined,
                  'Email Us',
                  AppConfig.contactEmail,
                  'We\'ll reply as soon as possible.',
                ),
                const SizedBox(height: 16),
                _buildContactInfoRow(
                  Icons.phone_outlined,
                  'Call Us',
                  AppConfig.contactPhone,
                  'Mon - Sat, 9:00 AM - 6:00 PM',
                ),
                const SizedBox(height: 16),
                _buildContactInfoRow(
                  Icons.chat_bubble_outline,
                  'Live Chat',
                  AppConfig.liveChatInfo,
                  'Get instant help from our team.',
                ),
                const SizedBox(height: 16),
                _buildContactInfoRow(
                  Icons.help_outline,
                  'Help Center',
                  'Visit our Help Center',
                  'Guides and FAQs available 24/7.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoRow(IconData icon, String title, String value, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightForm({required bool isMobile}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                const SizedBox(height: 24),
              ],
              Text(
                'Contact Us',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send us a message and we\'ll get back to you.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputLabel('Full Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 16),
                    _buildInputLabel('Subject'),
                    const SizedBox(height: 8),
                    _buildDropdownField(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInputLabel('Message'),
                        Text(
                          '$_charCount / 1000',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _messageController,
                      hint: 'Type your message here...',
                      icon: Icons.message_outlined,
                      maxLines: 4,
                      maxLength: 1000,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Message is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildInfoBanner(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 24),
                _buildOfficeCard(isMobile: false),
                const SizedBox(height: 24),
                _buildFooterLinks(),
              ],
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
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: maxLength != null ? (context, {required currentLength, required isFocused, maxLength}) => null : null,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
        ),
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

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      value: _selectedSubject,
      onChanged: (val) {
        setState(() {
          _selectedSubject = val ?? 'General Inquiry';
        });
      },
      items: _subjects.map((sub) {
        return DropdownMenuItem<String>(
          value: sub,
          child: Text(sub, style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF0F172A))),
        );
      }).toList(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.subject, color: Color(0xFF94A3B8), size: 18),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFF6366F1),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What happens next?',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF312E81),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our team will review your message and get back to you within 24 hours.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF4F46E5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _submitForm,
      icon: _isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : const Icon(Icons.send, size: 16),
      label: Text(
        'Send Message',
        style: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 0,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildOfficeCard({required bool isMobile}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF4F46E5), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Our Office',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppConfig.contactAddress,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            const Expanded(
              flex: 2,
              child: Icon(
                Icons.business_outlined,
                size: 64,
                color: Color(0xFFCBD5E1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headset_mic_outlined, size: 12, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                children: [
                  const TextSpan(text: 'Need immediate help? '),
                  TextSpan(
                    text: 'Call Us: ${AppConfig.contactPhone}',
                    style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

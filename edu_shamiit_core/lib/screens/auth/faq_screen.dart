import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class SharedFaqScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;
  final String? illustrationUrl;

  const SharedFaqScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
    this.illustrationUrl,
  }) : super(key: key);

  @override
  State<SharedFaqScreen> createState() => _SharedFaqScreenState();
}

class _SharedFaqScreenState extends State<SharedFaqScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All Questions';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _faqs = [
    {
      'category': 'Getting Started',
      'question': 'How do I get started with School ERP?',
      'answer': 'You can get started by clicking the "Get Started" button in the top right, filling in your administrator and school details, selecting a subscription plan, and completing the mock payment. Once submitted, the request goes to the superadmin for activation. Upon approval, your credentials will work immediately.'
    },
    {
      'category': 'Getting Started',
      'question': 'What are the hardware requirements for School ERP?',
      'answer': 'School ERP is completely web-based and cloud-hosted. All you need is a device (computer, tablet, or smartphone) with a modern web browser (such as Chrome, Firefox, Safari, or Edge) and an active internet connection.'
    },
    {
      'category': 'Getting Started',
      'question': 'Is training provided for the school staff?',
      'answer': 'Yes! We provide complete onboarding training sessions for teachers, administrators, and staff. We also offer comprehensive user guides, video tutorials, and dedicated training documentation.'
    },
    {
      'category': 'Getting Started',
      'question': 'Can we import our existing student and teacher data?',
      'answer': 'Absolutely. We support bulk data import via Excel/CSV templates. Our technical onboarding support team will help you migrate your legacy data smoothly during setup.'
    },
    {
      'category': 'Getting Started',
      'question': 'Can we customize School ERP according to our school\'s needs?',
      'answer': 'Yes, School ERP has highly configurable settings, custom templates for report cards, fee receipts, and various modules that can be toggled on or off depending on your school\'s unique requirements.'
    },
    {
      'category': 'Account & Security',
      'question': 'How do I reset my password?',
      'answer': 'Click on the "Forgot Password" link on the Login screen, enter your registered email address or user ID, and follow the instructions sent to your email to securely reset your password.'
    },
    {
      'category': 'Account & Security',
      'question': 'Can we set different access permissions for different users?',
      'answer': 'Yes. School ERP features robust Role-Based Access Control (RBAC). You can define specific permissions for students, teachers, principals, finance officers, HR personnel, and custom staff roles.'
    },
    {
      'category': 'Account & Security',
      'question': 'Does School ERP support multi-factor authentication (MFA)?',
      'answer': 'Yes, you can enable MFA or secure OTP-based login options through the security settings in your user profile dashboard.'
    },
    {
      'category': 'Account & Security',
      'question': 'What should I do if my account is locked?',
      'answer': 'Accounts are temporarily locked after several failed login attempts for security. You can either wait for the lockout period to expire or contact your school\'s system administrator to unlock it immediately.'
    },
    {
      'category': 'Features & Modules',
      'question': 'What modules are included in School ERP?',
      'answer': 'School ERP includes Student & Staff Information Management, Attendance Tracking, Examination & Report Card Generation, Online Fees & Payments, Library Cataloging, Transport Route Tracking, Live Classes, and IoT Controller configurations.'
    },
    {
      'category': 'Features & Modules',
      'question': 'Does the system support online examinations?',
      'answer': 'Yes, teachers can create dynamic online exams, assign them to classes, enable proctoring features (camera/mic tracking), and the system will automatically grade objective questions and publish results.'
    },
    {
      'category': 'Features & Modules',
      'question': 'Is there a mobile app for parents and students?',
      'answer': 'Yes, parents and students can access the portal via a responsive web interface on any mobile browser, and native mobile apps are available for download on both iOS and Android stores.'
    },
    {
      'category': 'Features & Modules',
      'question': 'Does it support bus route tracking?',
      'answer': 'Yes, our Transport Management module integrates live route tracking, stops management, and automated notifications for parents when the bus is near.'
    },
    {
      'category': 'Billing & Payments',
      'question': 'What subscription plans do you offer?',
      'answer': 'We offer three primary subscription plans: Basic (starter features for small schools), Premium (advanced analytics, IoT controller, priority support), and Enterprise (tailored custom configurations and dedicated hosting).'
    },
    {
      'category': 'Billing & Payments',
      'question': 'What payment methods are supported for online fee payment?',
      'answer': 'We support all major payment options including UPI, NetBanking, Debit/Credit Cards, and popular mobile wallets through our secure payment gateway integration.'
    },
    {
      'category': 'Billing & Payments',
      'question': 'How is the subscription billed?',
      'answer': 'Subscription plans can be billed monthly or yearly. Yearly billing includes a 10% discount on the subscription fee.'
    },
    {
      'category': 'Billing & Payments',
      'question': 'What happens if a school subscription expires?',
      'answer': 'If the school subscription expires, all user accounts associated with that school will be blocked from logging in. Data is safely preserved, and access is restored immediately upon renewal.'
    },
    {
      'category': 'Data & Security',
      'question': 'Is my school data secure with School ERP?',
      'answer': 'Yes, security is our top priority. We use industry-standard SSL/TLS encryption for all data in transit, and databases are encrypted at rest with regular daily automated backups.'
    },
    {
      'category': 'Data & Security',
      'question': 'Where is the data hosted?',
      'answer': 'Our systems are hosted on secure, enterprise-grade cloud servers (such as AWS/Google Cloud/Supabase) with multi-region redundancy to ensure 99.9% uptime.'
    },
    {
      'category': 'Data & Security',
      'question': 'Who owns the data uploaded to the system?',
      'answer': 'The school retains full ownership of all data uploaded to the platform. We do not share, sell, or utilize your data for any commercial purposes.'
    },
    {
      'category': 'Support & Services',
      'question': 'What kind of support does School ERP provide?',
      'answer': 'We offer 24/7 email and ticket-based support, and premium phone support for Premium/Enterprise plans. We also assign dedicated onboarding managers for large institutes.'
    },
    {
      'category': 'Support & Services',
      'question': 'How often is School ERP updated?',
      'answer': 'We release regular system updates and feature enhancements every month. All updates are automatically deployed to the cloud, so you always use the latest version without any downtime.'
    }
  ];

  final List<String> _categories = [
    'All Questions',
    'Getting Started',
    'Account & Security',
    'Features & Modules',
    'Billing & Payments',
    'Data & Security',
    'Support & Services'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getCategoryCount(String category) {
    if (category == 'All Questions') return _faqs.length;
    return _faqs.where((faq) => faq['category'] == category).length;
  }

  List<Map<String, dynamic>> _getFilteredFaqs() {
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategory == 'All Questions' || faq['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          faq['question'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 950;
    final name = widget.systemName ?? 'School ERP';
    final filteredFaqs = _getFilteredFaqs();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildNavbar(isDesktop, name),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Hero Header
            _buildHeroHeader(isDesktop),
            
            // 2. Main Content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 40,
              ),
              child: Column(
                children: [
                  // Search Bar Section
                  _buildSearchBarCard(),
                  const SizedBox(height: 40),
                  
                  // Split Layout (Categories & Accordions)
                  isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Categories Sidebar
                            Expanded(
                              flex: 4,
                              child: _buildLeftSidebar(),
                            ),
                            const SizedBox(width: 40),
                            // Right Accordions Panel
                            Expanded(
                              flex: 8,
                              child: _buildFaqListPanel(filteredFaqs),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildLeftSidebar(),
                            const SizedBox(height: 40),
                            _buildFaqListPanel(filteredFaqs),
                          ],
                        ),
                ],
              ),
            ),
            
            // 3. Bottom Banner CTA
            _buildBottomBanner(),
            
            // 4. Footer
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
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => context.go('/get-started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Get Started', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildNavbarLink(String label, VoidCallback onTap, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: 16,
                color: const Color(0xFF4F46E5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isDesktop) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 20,
        vertical: 60,
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildHeroLeftText(),
                ),
                const SizedBox(width: 40),
                Expanded(
                  flex: 5,
                  child: _buildHeroRightImage(),
                ),
              ],
            )
          : Column(
              children: [
                _buildHeroLeftText(),
                const SizedBox(height: 40),
                _buildHeroRightImage(),
              ],
            ),
    );
  }

  Widget _buildHeroLeftText() {
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
            'FAQ',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Frequently Asked\nQuestions',
          style: GoogleFonts.outfit(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            text: 'Find answers to common questions about School ERP.\nCan\'t find what you\'re looking for? ',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: InkWell(
                  onTap: () => context.go('/contact'),
                  child: Text(
                    'Contact us',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroRightImage() {
    final illustration = widget.illustrationUrl ?? 'assets/images/faq_illustration.png';
    return Center(
      child: Image.asset(
        illustration,
        width: 380,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 380,
          height: 250,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.help_center_outlined, size: 80, color: Color(0xFF6366F1)),
              const SizedBox(height: 16),
              Text(
                'FAQ Center',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          return isWide
              ? Row(
                  children: [
                    _buildSearchLabel(),
                    const SizedBox(width: 40),
                    Expanded(child: _buildSearchInputField()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchLabel(),
                    const SizedBox(height: 16),
                    _buildSearchInputField(),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildSearchLabel() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF4F46E5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.search, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Have a Question?',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Search our FAQ or browse by category.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchInputField() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search questions...',
        hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 13),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  Widget _buildLeftSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Categories list card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Categories',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._categories.map((category) {
                final isSelected = _selectedCategory == category;
                final count = _getCategoryCount(category);
                final icon = _getCategoryIcon(category);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEEF2F6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Still Need Help Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6).withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.headset_mic_outlined, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(height: 16),
              Text(
                'Still Need Help?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Our support team is always ready to assist you.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Contact Support',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    AppConfig.contactPhone,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'All Questions':
        return Icons.grid_view_outlined;
      case 'Getting Started':
        return Icons.rocket_launch_outlined;
      case 'Account & Security':
        return Icons.lock_outline;
      case 'Features & Modules':
        return Icons.widgets_outlined;
      case 'Billing & Payments':
        return Icons.credit_card_outlined;
      case 'Data & Security':
        return Icons.security_outlined;
      case 'Support & Services':
        return Icons.headset_mic_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildFaqListPanel(List<Map<String, dynamic>> filteredFaqs) {
    if (filteredFaqs.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_outlined, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              Text(
                'No FAQs Found',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search queries or category filters.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredFaqs.length,
      itemBuilder: (context, index) {
        final faq = filteredFaqs[index];
        return _FaqAccordionItem(
          question: faq['question'],
          answer: faq['answer'],
        );
      },
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF2F6).withOpacity(0.6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              return isWide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildBottomBannerText(),
                        ),
                        const SizedBox(width: 40),
                        _buildBottomBannerButton(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBottomBannerText(),
                        const SizedBox(height: 24),
                        _buildBottomBannerButton(),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBannerText() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.help_outline, color: Color(0xFF6366F1), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Still Have Questions?',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'We\'re here to help! Reach out to our experts and we\'ll get back to you as soon as possible.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBannerButton() {
    return ElevatedButton(
      onPressed: () => context.go('/contact'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Contact Us',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, size: 16),
        ],
      ),
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
                  } else if (item == 'FAQ') {
                    context.go('/faq');
                  } else if (item == 'FAQ\'s') {
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

class _FaqAccordionItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqAccordionItem({
    Key? key,
    required this.question,
    required this.answer,
  }) : super(key: key);

  @override
  State<_FaqAccordionItem> createState() => _FaqAccordionItemState();
}

class _FaqAccordionItemState extends State<_FaqAccordionItem> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_animationController);
    _heightFactor = _animationController.drive(CurveTween(curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isExpanded ? const Color(0xFF6366F1).withOpacity(0.02) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  // Circular expand status icon on the left
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _isExpanded ? const Color(0xFF6366F1) : const Color(0xFFEEF2F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isExpanded ? Icons.remove : Icons.add,
                      color: _isExpanded ? Colors.white : const Color(0xFF6366F1),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isExpanded ? const Color(0xFF4F46E5) : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _isExpanded ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _animationController.view,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _heightFactor,
                child: Padding(
                  padding: const EdgeInsets.only(left: 54, right: 20, bottom: 20),
                  child: Text(
                    widget.answer,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

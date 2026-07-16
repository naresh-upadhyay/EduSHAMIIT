import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class SharedTermsConditionsScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;
  final String? illustrationUrl;

  const SharedTermsConditionsScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
    this.illustrationUrl,
  }) : super(key: key);

  @override
  State<SharedTermsConditionsScreen> createState() => _SharedTermsConditionsScreenState();
}

class _SharedTermsConditionsScreenState extends State<SharedTermsConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  
  // Section keys for scrolling
  final List<GlobalKey> _sectionKeys = List.generate(12, (_) => GlobalKey());
  int _activeSectionIndex = 0;

  final List<String> _sections = [
    'Acceptance of Terms',
    'Use of the Platform',
    'User Accounts',
    'Data & Privacy',
    'Intellectual Property',
    'Payments & Refunds',
    'Third-Party Services',
    'Limitation of Liability',
    'Termination',
    'Changes to Terms',
    'Governing Law',
    'Contact Us',
  ];

  final List<IconData> _sectionIcons = [
    Icons.description_outlined,
    Icons.computer_outlined,
    Icons.people_outline,
    Icons.lock_outline,
    Icons.history_outlined,
    Icons.admin_panel_settings_outlined,
    Icons.child_care_outlined,
    Icons.cookie_outlined,
    Icons.share_outlined,
    Icons.edit_note_outlined,
    Icons.gavel_outlined,
    Icons.mail_outline,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    double minDistance = double.maxFinite;
    int closestIndex = 0;

    for (int i = 0; i < _sectionKeys.length; i++) {
      final context = _sectionKeys[i].currentContext;
      if (context != null) {
        final renderBox = context.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero).dy;
        final distance = (position - 120).abs(); // Offset from navbar header
        if (distance < minDistance) {
          minDistance = distance;
          closestIndex = i;
        }
      }
    }

    if (closestIndex != _activeSectionIndex) {
      setState(() {
        _activeSectionIndex = closestIndex;
      });
    }
  }

  void _scrollToSection(int index) {
    _scrollController.removeListener(_onScroll);
    setState(() {
      _activeSectionIndex = index;
    });

    final context = _sectionKeys[index].currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        // Re-attach listener after animation completes
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.addListener(_onScroll);
        });
      });
    }
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
      drawer: isDesktop ? null : _buildMobileDrawer(name),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHeroSection(isDesktop),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 40,
              ),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left navigation panel
                        SizedBox(
                          width: 280,
                          child: _buildLeftIndexPanel(),
                        ),
                        const SizedBox(width: 40),
                        // Right content cards
                        Expanded(
                          child: _buildContentPanel(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildContentPanel(),
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

  Widget _buildMobileDrawer(String name) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0F1026)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact Us'),
            onTap: () {
              Navigator.pop(context);
              context.go('/contact');
            },
          ),
          ListTile(
            leading: const Icon(Icons.login_outlined),
            title: const Text('Login'),
            onTap: () {
              Navigator.pop(context);
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isDesktop) {
    final imageWidth = isDesktop ? 220.0 : 140.0;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 20,
        vertical: 40,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Terms and Conditions',
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 36 : 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please read these terms and conditions carefully before using School ERP.',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Image.asset(
            widget.illustrationUrl ?? 'assets/images/terms_illustration.png',
            width: imageWidth,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: imageWidth,
              height: imageWidth * 0.8,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.assignment_outlined, size: 64, color: Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftIndexPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'In this page',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sections.length,
            itemBuilder: (context, index) {
              final isActive = index == _activeSectionIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () => _scrollToSection(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF6366F1).withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}.  ${_sections[index]}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? const Color(0xFF4F46E5) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF6366F1)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'By using School ERP, you agree to these Terms and Conditions. If you do not agree, please do not use our platform.',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: const Color(0xFF4F46E5),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPanel() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        return Container(
          key: _sectionKeys[index],
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _sectionIcons[index],
                      color: const Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${index + 1}. ${_sections[index]}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _getSectionBodyText(index),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF475569),
                  height: 1.6,
                ),
              ),
              if (index == 11) ...[
                const SizedBox(height: 20),
                _buildContactInfoRow(Icons.email_outlined, 'info@schoolerp.com'),
                _buildContactInfoRow(Icons.phone_outlined, '+91 98765 43210'),
                _buildContactInfoRow(Icons.location_on_outlined, '123, Tech Park, Sector 62, Noida, UP, India'),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactInfoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 16),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getSectionBodyText(int index) {
    switch (index) {
      case 0:
        return 'By accessing or using School ERP ("we", "our", or "us"), you agree to be bound by these Terms and Conditions and our Privacy Policy. If you do not agree with any part of these terms, please do not use our platform.';
      case 1:
        return 'School ERP is a school management platform that helps educational institutions manage their daily operations. You agree to use the platform only for lawful purposes and in accordance with these terms.';
      case 2:
        return 'You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. Notify us immediately of any unauthorized access.';
      case 3:
        return 'We collect, store, and process your data in accordance with our Privacy Policy. You agree to provide accurate and complete information to us.';
      case 4:
        return 'All content, features, and functionality on School ERP, including text, graphics, logos, and software, are the property of School ERP and are protected by copyright and other intellectual property laws.';
      case 5:
        return 'Fees are billed in advance and are non-refundable except as required by law or as specifically stated in our refund policy.';
      case 6:
        return 'Our platform may contain links or integrations with third-party services. We are not responsible for the content, policies, or practices of any third-party services.';
      case 7:
        return 'School ERP is provided "as is" without warranties of any kind. We are not liable for any indirect, incidental, or consequential damages arising from your use of the platform.';
      case 8:
        return 'We reserve the right to suspend or terminate your access to School ERP at any time, without notice, for conduct that we believe violates these Terms or is harmful to other users or us.';
      case 9:
        return 'We may update these Terms and Conditions from time to time. We will notify you of significant changes by posting the new terms on this page with an updated effective date.';
      case 10:
        return 'These Terms shall be governed by and construed in accordance with the laws of India, without regard to its conflict of law provisions.';
      case 11:
        return 'If you have any questions about these Terms and Conditions, please contact us:';
      default:
        return '';
    }
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
                      _buildFooterContactItem(Icons.location_on_outlined, '123, Tech Park, Sector 62, Noida, UP, India'),
                      _buildFooterContactItem(Icons.email_outlined, 'info@schoolerp.com'),
                      _buildFooterContactItem(Icons.phone_outlined, '+91 98765 43210'),
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
                      _buildFooterContactItem(Icons.location_on_outlined, '123, Tech Park, Sector 62, Noida, UP, India'),
                      _buildFooterContactItem(Icons.email_outlined, 'info@schoolerp.com'),
                      _buildFooterContactItem(Icons.phone_outlined, '+91 98765 43210'),
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
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                  );
                },
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

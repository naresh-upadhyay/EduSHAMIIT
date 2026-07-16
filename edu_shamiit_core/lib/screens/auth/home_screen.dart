import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/widgets/public_footer.dart';
import 'package:edu_shamiit_core/widgets/public_drawer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class SharedHomeScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;

  const SharedHomeScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
  }) : super(key: key);

  @override
  State<SharedHomeScreen> createState() => _SharedHomeScreenState();
}

class _SharedHomeScreenState extends State<SharedHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isNavbarSticky = false;

  // Global Keys for smooth scrolling to sections
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _modulesKey = GlobalKey();
  final GlobalKey _benefitsKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 50) {
        if (!_isNavbarSticky) {
          setState(() {
            _isNavbarSticky = true;
          });
        }
      } else {
        if (_isNavbarSticky) {
          setState(() {
            _isNavbarSticky = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final showDesktopNavbar = screenWidth >= 1150;
    final name = widget.systemName ?? 'School ERP';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildNavbar(showDesktopNavbar, name),
      ),
      drawer: showDesktopNavbar ? null : PublicDrawer(
        systemName: name,
        systemLogo: widget.systemLogo,
        onScrollToSection: (section) {
          if (section == 'Home') {
            _scrollToSection(_homeKey);
          } else if (section == 'Features') {
            _scrollToSection(_featuresKey);
          } else if (section == 'Modules') {
            _scrollToSection(_modulesKey);
          } else if (section == 'Benefits') {
            _scrollToSection(_benefitsKey);
          } else if (section == 'Pricing') {
            _scrollToSection(_pricingKey);
          } else if (section == 'About Us') {
            _scrollToSection(_aboutKey);
          }
        },
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeroSection(isDesktop, name),
            _buildTrustedSchoolsSection(),
            _buildStatsSection(isDesktop),
            _buildModulesSection(isDesktop),
            _buildWhyChooseUsSection(isDesktop),
            _buildTestimonialsSection(isDesktop),
            _buildCTABanner(isDesktop),
            PublicFooter(
              showWideFooter: screenWidth >= 1100,
              name: name,
              onScrollToSection: (section) {
                if (section == 'Home') {
                  _scrollToSection(_homeKey);
                } else if (section == 'Features') {
                  _scrollToSection(_featuresKey);
                } else if (section == 'Modules') {
                  _scrollToSection(_modulesKey);
                } else if (section == 'Pricing') {
                  _scrollToSection(_pricingKey);
                } else if (section == 'About Us') {
                  _scrollToSection(_aboutKey);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar(bool showDesktopNavbar, String name) {
    final logoUrl = widget.systemLogo;
    return Container(
      decoration: BoxDecoration(
        color: _isNavbarSticky ? Colors.white.withOpacity(0.95) : Colors.white,
        boxShadow: _isNavbarSticky
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0).withOpacity(_isNavbarSticky ? 0.0 : 1.0),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            // Logo & Title
            InkWell(
              onTap: () => _scrollToSection(_homeKey),
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

            // Desktop Links
            if (showDesktopNavbar) ...[
              _buildNavbarLink('Home', () => _scrollToSection(_homeKey)),
              _buildNavbarLink('Features', () => _scrollToSection(_featuresKey)),
              _buildNavbarLink('Modules', () => _scrollToSection(_modulesKey)),
              _buildNavbarLink('Benefits', () => _scrollToSection(_benefitsKey)),
              _buildNavbarLink('Pricing', () => _scrollToSection(_pricingKey)),
              _buildNavbarLink('About Us', () => _scrollToSection(_aboutKey)),
              _buildNavbarLink('Contact Us', () => context.go('/contact')),
              const SizedBox(width: 16),
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

  Widget _buildHeroSection(bool isDesktop, String name) {
    return Container(
      key: _homeKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 80 : 40,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEEF2FF),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: isDesktop ? 5 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'All-in-One School Management Solution',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: isDesktop ? 48 : 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          height: 1.2,
                        ),
                        children: [
                          const TextSpan(text: "Manage Your School\n"),
                          TextSpan(
                            text: 'Smarter, Faster & Better',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'School ERP simplifies administration, enhances communication, and improves overall efficiency — all in one integrated platform.',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        ElevatedButton(
                          onPressed: () => _scrollToSection(_aboutKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(140, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Request Demo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _scrollToSection(_featuresKey),
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('Explore Features'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4F46E5),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            minimumSize: const Size(160, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    // Quick Highlights
                    Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _buildHeroHighlight(Icons.verified_user_outlined, 'Secure & Reliable', 'Enterprise-grade security'),
                        _buildHeroHighlight(Icons.thumb_up_alt_outlined, 'Easy to Use', 'Intuitive & user-friendly'),
                        _buildHeroHighlight(Icons.support_agent_outlined, '24/7 Support', 'We\'re here to help'),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 48),
                Expanded(
                  flex: 6,
                  child: Image.asset(
                    'assets/images/hero_illustration.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.laptop, size: 80, color: Color(0xFF818CF8)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 40),
            Image.asset(
              'assets/images/hero_illustration.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(Icons.laptop, size: 60, color: Color(0xFF818CF8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroHighlight(IconData icon, String title, String subtitle) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF6366F1), size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrustedSchoolsSection() {
    return Container(
      key: _featuresKey,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Text(
            'Trusted by 500+ Schools & Institutions',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSchoolLogo('SUNRISE PUBLIC SCHOOL'),
                _buildSchoolLogo('GREENFIELD ACADEMY'),
                _buildSchoolLogo('HOLY CROSS SCHOOL'),
                _buildSchoolLogo('BRIGHT FUTURE SCHOOL'),
                _buildSchoolLogo('WISDOM WORLD SCHOOL'),
                _buildSchoolLogo('PINE GROVE ACADEMY'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolLogo(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.school, color: Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 8),
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 40,
      ),
      color: Colors.white,
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: isDesktop ? 80 : 32,
          runSpacing: 24,
          children: [
            _buildStatItem('500+', 'Institutions'),
            _buildStatItem('50,000+', 'Students'),
            _buildStatItem('5,000+', 'Teachers'),
            _buildStatItem('98%', 'Satisfaction'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String val, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.analytics_outlined, color: Color(0xFF4F46E5), size: 20),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              val,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
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

  Widget _buildModulesSection(bool isDesktop) {
    return Container(
      key: _modulesKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Text(
            'Everything You Need in One Platform',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Powerful modules to streamline every aspect of your school operations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 48),
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: isDesktop ? 1.5 : 1.8,
            children: [
              _buildModuleCard(Icons.people_outline, 'Student Management', 'Manage student information, admissions, documents, and profiles easily.'),
              _buildModuleCard(Icons.how_to_reg_outlined, 'Attendance Management', 'Track attendance in real-time with advanced analytics and reports.'),
              _buildModuleCard(Icons.assignment_outlined, 'Examination Management', 'Create exams, assign grades, and generate result reports effortlessly.'),
              _buildModuleCard(Icons.receipt_long_outlined, 'Fee Management', 'Automate fee collection, invoices, discounts and payment tracking.'),
              _buildModuleCard(Icons.directions_bus_outlined, 'Transport Management', 'Manage routes, vehicles, drivers and student transport details.'),
              _buildModuleCard(Icons.local_library_outlined, 'Library Management', 'Organize books, issue/return logs, fines and maintain library inventory.'),
            ],
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _scrollToSection(_aboutKey),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              minimumSize: const Size(180, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View All Modules'),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          const Spacer(),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'Learn more',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward, size: 10, color: Color(0xFF4F46E5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseUsSection(bool isDesktop) {
    return Container(
      key: _benefitsKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      color: Colors.white,
      child: Row(
        children: [
          if (isDesktop)
            Expanded(
              flex: 5,
              child: Image.asset(
                'assets/images/school_building_illustration.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 360,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.business_outlined, size: 64, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ),
          if (isDesktop) const SizedBox(width: 64),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why Schools Choose School ERP?',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  children: [
                    _buildBenefitItem('Centralized Data', 'All your data in one place, accessible anytime.', isDesktop),
                    _buildBenefitItem('Save Time & Effort', 'Automate tasks and reduce paperwork.', isDesktop),
                    _buildBenefitItem('Better Communication', 'Connect students, parents and staff seamlessly.', isDesktop),
                    _buildBenefitItem('Insightful Reports', 'Make data-driven decisions with reports.', isDesktop),
                    _buildBenefitItem('Scalable Solution', 'Designed to grow with your institution.', isDesktop),
                    _buildBenefitItem('Secure & Compliant', 'Your data is always safe with us.', isDesktop),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String title, String desc, bool isDesktop) {
    return SizedBox(
      width: isDesktop ? 240 : double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
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

  Widget _buildTestimonialsSection(bool isDesktop) {
    return Container(
      key: _pricingKey,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Text(
            'What Our Users Say',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schools love how School ERP transforms their daily operations.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildTestimonialCard(
                'School ERP has completely transformed the way we manage our school. It\'s easy to use, reliable and the support team is amazing!',
                'Rohit Sharma',
                'Principal, Sunrise Public School',
              ),
              _buildTestimonialCard(
                'The fee management and attendance tracking features have saved us so much time and effort. Highly recommended!',
                'Neha Verma',
                'Admin Head, Greenfield Academy',
              ),
              _buildTestimonialCard(
                'An all-in-one solution that covers everything from admission to exams. Our parents are also very happy!',
                'Amit Patel',
                'Director, Bright Future School',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard(String quote, String name, String role) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (_) => const Icon(Icons.star, color: Colors.amber, size: 14)),
          ),
          const SizedBox(height: 16),
          Text(
            '"$quote"',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: const Color(0xFF475569),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                radius: 18,
                child: Text(
                  name[0],
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    role,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCTABanner(bool isDesktop) {
    return Container(
      key: _aboutKey,
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 48,
      ),
      padding: EdgeInsets.all(isDesktop ? 48 : 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to Transform Your School Management?',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join hundreds of schools that trust School ERP to simplify their operations.',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                ElevatedButton(
                  onPressed: () => context.go('/contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size(140, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Request Demo'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.go('/get-started'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(150, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Get Started Now'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ready to Transform Your School Management?',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Join hundreds of schools that trust School ERP to simplify their operations.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/contact'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4F46E5),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Request Demo'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/get-started'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Get Started Now'),
                ),
              ],
            ),
    );
  }
}

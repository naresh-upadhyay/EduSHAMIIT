import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/widgets/public_footer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/config/app_config.dart';

class SharedHelpCenterScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;
  final String? illustrationUrl;

  const SharedHelpCenterScreen({
    Key? key,
    this.systemName,
    this.systemLogo,
    this.illustrationUrl,
  }) : super(key: key);

  @override
  State<SharedHelpCenterScreen> createState() => _SharedHelpCenterScreenState();
}

class _SharedHelpCenterScreenState extends State<SharedHelpCenterScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _topics = [
    {
      'title': 'Getting Started',
      'summary': 'Learn the basics and set up School ERP for your institution.',
      'icon': Icons.rocket_launch_outlined,
      'category': 'Getting Started'
    },
    {
      'title': 'User Accounts',
      'summary': 'Manage users, roles, permissions and account settings.',
      'icon': Icons.people_outline,
      'category': 'User Management'
    },
    {
      'title': 'Features & Modules',
      'summary': 'Understand all the features and modules in detail.',
      'icon': Icons.menu_book_outlined,
      'category': 'Student Management'
    },
    {
      'title': 'Billing & Payments',
      'summary': 'Manage subscriptions, payments, invoices and billing.',
      'icon': Icons.credit_card_outlined,
      'category': 'Fee Management'
    },
    {
      'title': 'Data & Security',
      'summary': 'Learn how we protect your data and ensure privacy.',
      'icon': Icons.lock_outline,
      'category': 'Settings & Configuration'
    },
    {
      'title': 'Support & Services',
      'summary': 'Get help from our support team and find additional resources.',
      'icon': Icons.support_agent_outlined,
      'category': 'FAQ'
    }
  ];

  final List<Map<String, dynamic>> _popularArticles = [
    {
      'title': 'How do I add a new student?',
      'summary': 'Learn how to add student details, contact information and admission data.',
      'category': 'Student Management',
      'article': 'welcome'
    },
    {
      'title': 'How can I manage employee roles and permissions?',
      'summary': 'Understand user roles, permissions and how to add staff members.',
      'category': 'User Management',
      'article': 'welcome'
    },
    {
      'title': 'How to take attendance in School ERP?',
      'summary': 'A quick guide to taking daily attendance for students and staff.',
      'category': 'Attendance Management',
      'article': 'welcome'
    },
    {
      'title': 'How can I generate fee collection reports?',
      'summary': 'Learn steps to generate and export fee collection reports.',
      'category': 'Fee Management',
      'article': 'welcome'
    },
    {
      'title': 'How can I reset my password?',
      'summary': 'Step-by-step process to reset your account password.',
      'category': 'Getting Started',
      'article': 'welcome'
    }
  ];

  final List<Map<String, dynamic>> _popularGuides = [
    {
      'title': 'How to Add Students',
      'desc': 'Step-by-step guide',
      'category': 'Student Management'
    },
    {
      'title': 'Managing Attendance',
      'desc': 'Track attendance easily',
      'category': 'Attendance Management'
    },
    {
      'title': 'Generating Reports',
      'desc': 'Create and download reports',
      'category': 'Reports'
    },
    {
      'title': 'Fee Management',
      'desc': 'Collect and manage fees',
      'category': 'Fee Management'
    },
    {
      'title': 'Backup & Restore Data',
      'desc': 'Keep your data safe',
      'category': 'Settings & Configuration'
    }
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredArticles() {
    if (_searchQuery.isEmpty) return _popularArticles;
    return _popularArticles.where((art) {
      return art['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          art['summary'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
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
            // 1. Hero Header
            _buildHeroHeader(isDesktop),

            // 2. Split Content Layout
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 20,
                vertical: 40,
              ),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Main Column
                        Expanded(
                          flex: 8,
                          child: _buildLeftColumn(),
                        ),
                        const SizedBox(width: 40),
                        // Right Sidebar Column
                        Expanded(
                          flex: 4,
                          child: _buildRightSidebar(),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildLeftColumn(),
                        const SizedBox(height: 40),
                        _buildRightSidebar(),
                      ],
                    ),
            ),

            // 3. Footer
            PublicFooter(
              showWideFooter: screenWidth >= 1100,
              name: name,
            ),
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
                icon: const Icon(Icons.menu, color: Color(0xFF6366F1)),
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
            'HELP CENTER',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4F46E5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            text: 'How can we\n',
            style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), height: 1.2),
            children: [
              TextSpan(
                text: 'help you',
                style: TextStyle(color: const Color(0xFF6366F1)),
              ),
              const TextSpan(
                text: ' today?',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Find helpful articles, guides and resources to make the most of School ERP.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: const Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        // Search Box
        Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search for articles, topics or keywords...',
              hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
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
                  : null,
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
              fillColor: const Color(0xFFF8FAFC),
            ),
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroRightImage() {
    final imgUrl = widget.illustrationUrl ?? 'assets/images/help_center_illustration.png';
    return Center(
      child: Image.asset(
        imgUrl,
        width: 380,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 380,
          height: 250,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.live_help_outlined, size: 80, color: Color(0xFF6366F1)),
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    final filtered = _getFilteredArticles();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Browse Help Topics Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Browse Help Topics',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/user-guides'),
              child: Row(
                children: [
                  Text(
                    'View all topics',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Browse Topics Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 3 : 1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 200,
          ),
          itemCount: _topics.length,
          itemBuilder: (context, index) {
            final topic = _topics[index];
            final icon = topic['icon'] as IconData;
            final category = topic['category'] as String;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: const Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    topic['title'],
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      topic['summary'],
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => context.go('/user-guides?category=${Uri.encodeComponent(category)}'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Explore Articles',
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF4F46E5)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 48),

        // 3. Popular Articles Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Popular Articles',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/user-guides'),
              child: Row(
                children: [
                  Text(
                    'View all articles',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Popular Articles List
        if (filtered.isEmpty)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                'No articles matched your search.',
                style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
              ),
            ),
          )
        else ...[
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final art = filtered[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: InkWell(
                  onTap: () {
                    final cat = art['category'] as String;
                    // For welcome articles, route to guides screen
                    context.go('/user-guides?category=${Uri.encodeComponent(cat)}&article=welcome');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.description_outlined, color: Color(0xFF6366F1), size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                art['title'],
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                art['summary'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              onPressed: () => context.go('/user-guides'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All Articles',
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRightSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Popular Guides Card List
        Container(
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
                children: [
                  const Icon(Icons.star_outline, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Popular Guides',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._popularGuides.map((guide) {
                final cat = guide['category'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => context.go('/user-guides?category=${Uri.encodeComponent(cat)}'),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.menu_book_outlined, color: Color(0xFF6366F1), size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guide['title'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                guide['desc'],
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go('/user-guides'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All Guides',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Still Need Help? Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), // Sleek subtle green tint
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCFCE7)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.contact_support_outlined, color: Color(0xFF16A34A), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Still Need Help?',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF14532D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Our support team is here to help you with any questions you have.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF15803D),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(height: 24),
              Text(
                'Other Ways to Reach Us',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF14532D),
                ),
              ),
              const SizedBox(height: 16),
              _buildContactSidebarItem(Icons.email_outlined, AppConfig.contactEmail),
              _buildContactSidebarItem(Icons.phone_outlined, AppConfig.contactPhone),
              _buildContactSidebarItem(Icons.chat_bubble_outline, 'Live Chat\n${AppConfig.liveChatInfo}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactSidebarItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF16A34A), size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: const Color(0xFF15803D),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

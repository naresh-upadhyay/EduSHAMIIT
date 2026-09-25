import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class SharedJobDetailsScreen extends StatefulWidget {
  final String slug;
  final String? systemName;
  final String? systemLogo;
  final String? schoolId;

  const SharedJobDetailsScreen({
    super.key,
    required this.slug,
    this.systemName,
    this.systemLogo,
    this.schoolId,
  });

  @override
  State<SharedJobDetailsScreen> createState() => _SharedJobDetailsScreenState();
}

class _SharedJobDetailsScreenState extends State<SharedJobDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isNavbarSticky = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _job;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchJobDetails();
  }

  @override
  void didUpdateWidget(SharedJobDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slug != oldWidget.slug) {
      _fetchJobDetails();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    if (offset > 40 && !_isNavbarSticky) {
      setState(() => _isNavbarSticky = true);
    } else if (offset <= 40 && _isNavbarSticky) {
      setState(() => _isNavbarSticky = false);
    }
  }

  String get _baseUrl => AppConfig.resolveUrl('http://localhost:8082');

  String get _cleanPublicUrl => '${Uri.base.origin}/careers/jobs/${widget.slug}';

  Future<void> _fetchJobDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse('$_baseUrl/api/public/careers/jobs/${widget.slug}');
      final resp = await http.get(url).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) {
            setState(() {
              _job = Map<String, dynamic>.from(data['data']);
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (resp.statusCode == 404) {
        if (mounted) {
          setState(() {
            _errorMessage = 'This job opening could not be found or has expired.';
            _isLoading = false;
          });
        }
        return;
      }

      throw Exception('Server returned status ${resp.statusCode}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load job details. Please check your internet connection or try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _copyJobUrl() {
    Clipboard.setData(ClipboardData(text: _cleanPublicUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Job link copied: $_cleanPublicUrl')),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _openApplyDialog() {
    if (_job == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => JobApplicationFormDialog(
        job: _job!,
        baseUrl: _baseUrl,
        onSuccess: (refNum, appliedJobTitle) {
          showApplicationSuccessDialog(context, refNum, appliedJobTitle);
        },
      ),
    );
  }

  IconData _getDeptIcon(String? dept) {
    final d = (dept ?? '').toLowerCase();
    if (d.contains('it') || d.contains('tech') || d.contains('system') || d.contains('software')) {
      return Icons.computer_rounded;
    }
    if (d.contains('teach') || d.contains('academic') || d.contains('faculty') || d.contains('science')) {
      return Icons.school_rounded;
    }
    if (d.contains('finance') || d.contains('account')) {
      return Icons.account_balance_rounded;
    }
    if (d.contains('admin') || d.contains('executive')) {
      return Icons.badge_rounded;
    }
    return Icons.work_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1050;
    final showDesktopNavbar = screenWidth >= 1150;
    final name = widget.systemName ?? 'EduSHAMIIT';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // Top Navigation Bar
            _buildNavbar(showDesktopNavbar, name),

            // Main View State Handling
            if (_isLoading)
              _buildLoadingSkeleton(isDesktop)
            else if (_errorMessage != null || _job == null)
              _buildErrorView(isDesktop)
            else
              _buildJobContent(isDesktop),

            const SizedBox(height: 60),

            // Public Institution Footer
            PublicFooter(
              showWideFooter: screenWidth >= 1100,
              name: name,
              onScrollToSection: (section) {
                if (section == 'Careers') {
                  context.go('/careers');
                } else if (section == 'Home') {
                  context.go('/');
                } else if (section == 'Features') {
                  context.go('/#features');
                } else if (section == 'Modules') {
                  context.go('/#modules');
                } else if (section == 'Benefits') {
                  context.go('/#benefits');
                } else if (section == 'Pricing') {
                  context.go('/#pricing');
                } else if (section == 'About Us') {
                  context.go('/#about');
                } else {
                  context.go('/');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TOP NAVBAR
  // ==========================================================================
  Widget _buildNavbar(bool showDesktopNavbar, String name) {
    final logoUrl = widget.systemLogo;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: _isNavbarSticky
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: _isNavbarSticky ? 0.0 : 1.0),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            // Logo & Title
            InkWell(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  if (logoUrl != null && logoUrl.isNotEmpty)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        AppConfig.resolveUrl(logoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.school_outlined, color: Color(0xFF6366F1), size: 20),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school_outlined, color: Color(0xFF6366F1), size: 20),
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
                        style: GoogleFonts.outfit(fontSize: 9, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Desktop Links
            if (showDesktopNavbar) ...[
              _buildNavbarLink('Home', () => context.go('/')),
              _buildNavbarLink('Features', () => context.go('/#features')),
              _buildNavbarLink('Modules', () => context.go('/#modules')),
              _buildNavbarLink('Careers', () => context.go('/careers'), isCurrent: true),
              _buildNavbarLink('Contact Us', () => context.go('/contact')),
              const SizedBox(width: 12),
            ],

            // Back to Careers Button
            OutlinedButton.icon(
              onPressed: () => context.go('/careers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F3663),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.arrow_back, size: 14),
              label: Text('All Openings', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),

            // Share Button
            IconButton(
              onPressed: _copyJobUrl,
              icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF475569)),
              tooltip: 'Copy Clean Job Link',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbarLink(String label, VoidCallback onTap, {bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
              color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // MAIN JOB CONTENT (HERO + TWO COLUMNS)
  // ==========================================================================
  Widget _buildJobContent(bool isDesktop) {
    final job = _job!;
    final title = (job['job_title'] ?? 'Job Position').toString();
    final jobCode = (job['job_code'] ?? '').toString();
    final dept = (job['department'] ?? 'Department').toString();
    final location = (job['location'] ?? 'Main Campus').toString();
    final campus = (job['campus'] ?? '').toString();
    final empType = (job['employment_type'] ?? 'Full-time').toString();
    final workMode = (job['work_mode'] ?? 'On-site').toString();
    final exp = (job['experience_required'] ?? '2-5 Years').toString();
    final deadline = job['application_deadline']?.toString();
    final canApply = job['can_apply'] == true;
    final isExpired = job['is_expired'] == true;
    final isFeatured = job['is_featured'] == true;
    final isSalaryPublic = job['is_salary_public'] == true;
    final isOpeningsPublic = job['is_openings_public'] == true;
    final vacancies = job['vacancies'];
    final salaryMin = job['salary_min'];
    final salaryMax = job['salary_max'];
    final payFreq = job['pay_frequency'] ?? 'Monthly';

    String salaryText = '';
    if (isSalaryPublic && (salaryMin != null || salaryMax != null)) {
      if (salaryMin != null && salaryMax != null) {
        salaryText = '₹$salaryMin - ₹$salaryMax / $payFreq';
      } else if (salaryMin != null) {
        salaryText = 'From ₹$salaryMin / $payFreq';
      } else {
        salaryText = 'Up to ₹$salaryMax / $payFreq';
      }
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1240),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb Bar
          _buildBreadcrumbs(dept, title),
          const SizedBox(height: 20),

          // Hero Banner Card
          _buildHeroCard(
            title: title,
            jobCode: jobCode,
            dept: dept,
            location: location,
            campus: campus,
            empType: empType,
            workMode: workMode,
            exp: exp,
            salaryText: salaryText,
            vacancies: vacancies,
            isOpeningsPublic: isOpeningsPublic,
            deadline: deadline,
            canApply: canApply,
            isExpired: isExpired,
            isFeatured: isFeatured,
            isDesktop: isDesktop,
          ),
          const SizedBox(height: 32),

          // Two-Column Layout (Desktop) or Stack (Mobile)
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Detailed Job Information (68%)
                Expanded(
                  flex: 68,
                  child: _buildLeftDetailsColumn(job, canApply),
                ),
                const SizedBox(width: 28),

                // Right Column: Sticky Summary & Application Actions (32%)
                Expanded(
                  flex: 32,
                  child: _buildRightSidebarColumn(job, canApply, isExpired),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRightSidebarColumn(job, canApply, isExpired),
                const SizedBox(height: 24),
                _buildLeftDetailsColumn(job, canApply),
              ],
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BREADCRUMBS
  // ==========================================================================
  Widget _buildBreadcrumbs(String dept, String title) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: Text('Home', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
        ),
        InkWell(
          onTap: () => context.go('/careers'),
          child: Text('Careers', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
        ),
        Text(dept, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
        ),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F2B48)),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ==========================================================================
  // HERO BANNER CARD
  // ==========================================================================
  Widget _buildHeroCard({
    required String title,
    required String jobCode,
    required String dept,
    required String location,
    required String campus,
    required String empType,
    required String workMode,
    required String exp,
    required String salaryText,
    required dynamic vacancies,
    required bool isOpeningsPublic,
    required String? deadline,
    required bool canApply,
    required bool isExpired,
    required bool isFeatured,
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? 32 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Badges & Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Department Circle Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3663).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0F3663).withValues(alpha: 0.15)),
                ),
                child: Icon(_getDeptIcon(dept), color: const Color(0xFF0F3663), size: 28),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag Pills Row
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildHeroPill(dept, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                        _buildHeroPill(workMode, const Color(0xFF4F46E5), const Color(0xFFEEF2FF)),
                        _buildHeroPill(empType, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
                        if (isFeatured)
                          _buildHeroPill('★ Featured', const Color(0xFF059669), const Color(0xFFECFDF5)),
                        if (canApply)
                          _buildHeroPill('● Open for Applications', const Color(0xFF16A34A), const Color(0xFFF0FDF4))
                        else if (isExpired)
                          _buildHeroPill('Deadline Passed', const Color(0xFFDC2626), const Color(0xFFFEF2F2))
                        else
                          _buildHeroPill('Applications Closed', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Job Title
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 26 : 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Job Code & Reference
                    if (jobCode.isNotEmpty)
                      Text(
                        'Requisition Code: $jobCode • Institutional Posting',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),

              // Desktop Quick Apply CTA
              if (isDesktop && canApply) ...[
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: _openApplyDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3663),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    'Apply Now',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Key Highlights Strip
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _buildMetaItem(Icons.location_on_outlined, 'Location', campus.isNotEmpty ? '$location ($campus)' : location),
              _buildMetaItem(Icons.timeline_rounded, 'Experience', exp),
              if (salaryText.isNotEmpty)
                _buildMetaItem(Icons.payments_outlined, 'Compensation', salaryText),
              if (isOpeningsPublic && vacancies != null)
                _buildMetaItem(Icons.people_outline_rounded, 'Total Positions', '$vacancies Vacancies'),
              _buildMetaItem(
                Icons.calendar_today_outlined,
                'Application Deadline',
                deadline ?? 'Open Until Filled',
                isHighlighted: isExpired,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill(String text, Color fgColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fgColor,
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 16, color: isHighlighted ? const Color(0xFFDC2626) : const Color(0xFF0F3663)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // LEFT DETAILS COLUMN (OVERVIEW, RESPONSIBILITIES, SKILLS, PERKS)
  // ==========================================================================
  Widget _buildLeftDetailsColumn(Map<String, dynamic> job, bool canApply) {
    final desc = job['description']?.toString() ?? 'No detailed description provided.';
    final resp = job['responsibilities'];
    final qual = job['qualifications'];
    final benefits = job['benefits'];
    final reqSkills = List<String>.from(job['required_skills'] ?? []);
    final prefSkills = List<String>.from(job['preferred_skills'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Role Overview
        _buildContentCard(
          title: 'Role Overview & Purpose',
          icon: Icons.article_outlined,
          child: Text(
            desc,
            style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF334155), height: 1.7),
          ),
        ),
        const SizedBox(height: 24),

        // Card 2: Key Responsibilities
        if (resp != null && resp.toString().trim().isNotEmpty) ...[
          _buildContentCard(
            title: 'Key Responsibilities',
            icon: Icons.checklist_rounded,
            child: _buildBulletSection(resp),
          ),
          const SizedBox(height: 24),
        ],

        // Card 3: Requirements & Qualifications
        if (qual != null && qual.toString().trim().isNotEmpty) ...[
          _buildContentCard(
            title: 'Qualifications & Requirements',
            icon: Icons.school_outlined,
            child: _buildBulletSection(qual),
          ),
          const SizedBox(height: 24),
        ],

        // Card 4: Required Skills & Competencies
        if (reqSkills.isNotEmpty || prefSkills.isNotEmpty) ...[
          _buildContentCard(
            title: 'Required Skills & Competencies',
            icon: Icons.psychology_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reqSkills.isNotEmpty) ...[
                  Text(
                    'Essential Skills',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reqSkills.map((s) => _buildSkillChip(s, isPrimary: true)).toList(),
                  ),
                ],
                if (prefSkills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Preferred / Good to Have',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: prefSkills.map((s) => _buildSkillChip(s, isPrimary: false)).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Card 5: Benefits & Perks
        _buildContentCard(
          title: 'What We Offer & Institutional Perks',
          icon: Icons.card_giftcard_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (benefits != null && benefits.toString().trim().isNotEmpty) ...[
                Text(
                  benefits.toString(),
                  style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF334155), height: 1.6),
                ),
                const SizedBox(height: 20),
              ],
              // 4 Standard Institutional Benefit Highlights
              Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  _buildPerkTile(Icons.medical_services_outlined, 'Comprehensive Health', 'Medical and wellness support for staff'),
                  _buildPerkTile(Icons.trending_up_rounded, 'Continuous Learning', 'Workshops, research grants & skill elevation'),
                  _buildPerkTile(Icons.beach_access_outlined, 'Paid Leave & Time Off', 'Generous paid vacation, sick leave & sabbatical'),
                  _buildPerkTile(Icons.laptop_chromebook_rounded, 'Modern Environment', 'State-of-the-art labs and campus infrastructure'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Bottom CTA Card
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Join the EduSHAMIIT Team?',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submit your application today to shape the next generation of learners.',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              if (canApply) ...[
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _openApplyDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F2B48),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply Now',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3663).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0F3663)),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletSection(dynamic content) {
    List<String> items = [];
    if (content is List) {
      items = content.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (content is String) {
      items = content
          .split(RegExp(r'\r?\n|\u2022|\*|-'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (items.isEmpty) {
      return Text(content.toString(), style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF334155), height: 1.6));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155), height: 1.55),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillChip(String skill, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isPrimary ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        skill,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPrimary ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildPerkTile(IconData icon, String title, String desc) {
    return SizedBox(
      width: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF059669)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RIGHT SIDEBAR COLUMN (QUICK FACTS, SHARE, TIMELINE)
  // ==========================================================================
  Widget _buildRightSidebarColumn(Map<String, dynamic> job, bool canApply, bool isExpired) {
    final dept = (job['department'] ?? 'General').toString();
    final designation = (job['designation'] ?? 'Staff').toString();
    final empType = (job['employment_type'] ?? 'Full-time').toString();
    final workMode = (job['work_mode'] ?? 'On-site').toString();
    final location = (job['location'] ?? 'Main Campus').toString();
    final exp = (job['experience_required'] ?? '2-5 Years').toString();
    final deadline = job['application_deadline']?.toString() ?? 'Open until filled';
    final vacancies = job['vacancies'];
    final isOpeningsPublic = job['is_openings_public'] == true;

    return Column(
      children: [
        // Card 1: Job Summary & Main Apply Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Job Summary',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 16),

              _buildFactRow('Department', dept),
              _buildFactRow('Designation', designation),
              _buildFactRow('Employment', empType),
              _buildFactRow('Work Mode', workMode),
              _buildFactRow('Campus Location', location),
              _buildFactRow('Experience', exp),
              if (isOpeningsPublic && vacancies != null)
                _buildFactRow('Vacancies', '$vacancies Openings'),
              _buildFactRow('Deadline', deadline),

              const SizedBox(height: 20),

              // Action CTA
              ElevatedButton(
                onPressed: canApply ? _openApplyDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3663),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      canApply ? 'Apply for this Job' : (isExpired ? 'Deadline Passed' : 'Closed'),
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (canApply) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 2: Share this Position (Clean URL without #)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this Opportunity',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Copy and share this job link with colleagues and potential candidates:',
                style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),

              // Clean URL Display Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cleanPublicUrl,
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _copyJobUrl,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3663),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Copy',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 3: Hiring Process Timeline
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.route_outlined, size: 18, color: Color(0xFF0F3663)),
                  const SizedBox(width: 8),
                  Text(
                    'Our Hiring Journey',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTimelineStep('1', 'Submit Application', 'Fast 5-minute online form with resume upload'),
              _buildTimelineStep('2', 'HR & Peer Review', 'Profile evaluated by relevant academic / IT committee'),
              _buildTimelineStep('3', 'Interview Session', 'Competency and discussion with department head'),
              _buildTimelineStep('4', 'Offer & Welcome', 'Formal offer letter & seamless digital onboarding', isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String stepNumber, String title, String desc, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF0F3663),
                shape: BoxShape.circle,
              ),
              child: Text(
                stepNumber,
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 26, color: const Color(0xFFCBD5E1)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Text(desc, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
              if (!isLast) const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // LOADING SKELETON & ERROR VIEWS
  // ==========================================================================
  Widget _buildLoadingSkeleton(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1240),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 16, width: 220, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 20),
          Container(height: 160, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 32),
          Container(height: 280, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
        ],
      ),
    );
  }

  Widget _buildErrorView(bool isDesktop) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.work_off_outlined, color: Color(0xFFDC2626), size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Job Opening Not Available',
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'This position may have expired or is no longer accepting public applications.',
            style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/careers'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3663),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text('Browse All Current Openings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

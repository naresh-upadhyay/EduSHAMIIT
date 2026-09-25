import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class SharedCareersScreen extends StatefulWidget {
  final String? systemName;
  final String? systemLogo;
  final String? initialJobSlug;
  final String? schoolId;

  const SharedCareersScreen({
    super.key,
    this.systemName,
    this.systemLogo,
    this.initialJobSlug,
    this.schoolId,
  });

  @override
  State<SharedCareersScreen> createState() => _SharedCareersScreenState();
}

class _SharedCareersScreenState extends State<SharedCareersScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newsletterController = TextEditingController();

  bool _isNavbarSticky = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Stats
  Map<String, dynamic> _stats = {
    'open_positions_display': '0',
    'departments_count_display': '0',
    'growth_opportunities': '100%',
    'work_environment': 'Great',
  };

  // Filters from API
  List<String> _departments = ['All Departments'];
  List<String> _locations = ['All Locations'];
  List<String> _employmentTypes = ['All Types'];
  List<String> _workModes = ['All Modes'];

  // Current filter selections
  String _selectedDepartment = 'All Departments';
  String _selectedLocation = 'All Locations';
  String _selectedEmploymentType = 'All Types';
  String _selectedWorkMode = 'All Modes';
  String _searchQuery = '';

  // Pagination & Job List
  List<Map<String, dynamic>> _jobs = [];
  int _totalJobs = 0;
  int _currentPage = 1;
  final int _pageSize = 8;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void didUpdateWidget(SharedCareersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialJobSlug != null &&
        widget.initialJobSlug!.isNotEmpty &&
        widget.initialJobSlug != oldWidget.initialJobSlug) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/careers/jobs/${widget.initialJobSlug!}');
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _newsletterController.dispose();
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

  String get _baseUrl {
    return AppConfig.resolveUrl('http://localhost:8082');
  }

  String get _activeSchoolId => widget.schoolId ?? '11111111-1111-1111-1111-111111111111';

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.wait([
      _fetchStats(),
      _fetchFilters(),
      _fetchJobs(page: 1),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);

      // If opened with initial job slug
      if (widget.initialJobSlug != null && widget.initialJobSlug!.isNotEmpty) {
        context.go('/careers/jobs/${widget.initialJobSlug!}');
      }
    }
  }

  Future<void> _fetchStats() async {
    try {
      final url = Uri.parse('$_baseUrl/api/public/careers/stats').replace(
        queryParameters: {'school_id': _activeSchoolId},
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true && data['data'] != null) {
          if (mounted) {
            setState(() {
              _stats = Map<String, dynamic>.from(data['data']);
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchFilters() async {
    try {
      final url = Uri.parse('$_baseUrl/api/public/careers/filters').replace(
        queryParameters: {'school_id': _activeSchoolId},
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true && data['data'] != null) {
          final filterData = data['data'];
          if (mounted) {
            setState(() {
              if (filterData['departments'] is List) {
                _departments = ['All Departments', ...List<String>.from(filterData['departments'])];
              }
              if (filterData['locations'] is List) {
                _locations = ['All Locations', ...List<String>.from(filterData['locations'])];
              }
              if (filterData['employment_types'] is List) {
                _employmentTypes = ['All Types', ...List<String>.from(filterData['employment_types'])];
              }
              if (filterData['work_modes'] is List) {
                _workModes = ['All Modes', ...List<String>.from(filterData['work_modes'])];
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchJobs({int page = 1}) async {
    try {
      final params = <String, String>{
        'school_id': _activeSchoolId,
        'page': page.toString(),
        'page_size': _pageSize.toString(),
      };
      if (_searchQuery.trim().isNotEmpty) {
        params['search'] = _searchQuery.trim();
      }
      if (_selectedDepartment != 'All Departments') {
        params['department'] = _selectedDepartment;
      }
      if (_selectedLocation != 'All Locations') {
        params['location'] = _selectedLocation;
      }
      if (_selectedEmploymentType != 'All Types') {
        params['employment_type'] = _selectedEmploymentType;
      }
      if (_selectedWorkMode != 'All Modes') {
        params['work_mode'] = _selectedWorkMode;
      }

      final uri = Uri.parse('$_baseUrl/api/public/careers/jobs').replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          final rawList = data['data'] as List? ?? [];
          final pagination = data['pagination'] ?? {};

          if (mounted) {
            setState(() {
              _jobs = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
              _totalJobs = pagination['total_records'] ?? _jobs.length;
              _currentPage = pagination['page'] ?? page;
              _totalPages = pagination['total_pages'] ?? 1;
              _errorMessage = null;
            });
          }
          return;
        }
      }
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load jobs. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Network error loading jobs. Please check connection.');
      }
    }
  }

  void _applySearch() {
    _searchQuery = _searchController.text;
    _currentPage = 1;
    _fetchJobs(page: 1);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDepartment = 'All Departments';
      _selectedLocation = 'All Locations';
      _selectedEmploymentType = 'All Types';
      _selectedWorkMode = 'All Modes';
    });
    _fetchJobs(page: 1);
  }



  IconData _getDepartmentIcon(String? department, String? title) {
    final d = (department ?? '').toLowerCase();
    final t = (title ?? '').toLowerCase();

    if (d.contains('teach') || d.contains('academic') || t.contains('teacher') || t.contains('faculty')) {
      return Icons.school_outlined;
    }
    if (d.contains('it') || d.contains('tech') || t.contains('system') || t.contains('engineer') || t.contains('developer')) {
      return Icons.computer_outlined;
    }
    if (d.contains('admin') || t.contains('admin') || t.contains('executive') || t.contains('office')) {
      return Icons.badge_outlined;
    }
    if (d.contains('market') || t.contains('market') || t.contains('coordinator')) {
      return Icons.campaign_outlined;
    }
    if (d.contains('finance') || d.contains('account') || t.contains('account')) {
      return Icons.account_balance_outlined;
    }
    if (d.contains('transport') || t.contains('driver')) {
      return Icons.directions_bus_outlined;
    }
    return Icons.work_outline;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1050;
    final showDesktopNavbar = screenWidth >= 1150;
    final name = widget.systemName ?? 'EduSHAMIIT';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: _buildNavbar(showDesktopNavbar, name),
      ),
      drawer: showDesktopNavbar
          ? null
          : PublicDrawer(
              systemName: name,
              systemLogo: widget.systemLogo,
              onScrollToSection: (section) {
                if (section == 'Careers' || section == 'ScrollToTop') {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
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
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Section matching screenshot
            _buildHeroSection(isDesktop),

            // 2. Metrics / Stat Highlights Strip
            _buildStatsStrip(isDesktop),

            const SizedBox(height: 24),

            // 3. Main Body (Current Openings + Right Sidebar)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64 : 16,
                vertical: 16,
              ),
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Openings List
                        Expanded(
                          flex: 7,
                          child: _buildOpeningsSection(),
                        ),
                        const SizedBox(width: 32),
                        // Right Column: Promotional Cards & Benefits
                        Expanded(
                          flex: 3,
                          child: _buildRightSidebar(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOpeningsSection(),
                        const SizedBox(height: 40),
                        _buildRightSidebar(),
                      ],
                    ),
            ),

            const SizedBox(height: 48),

            // 4. Institutional Website Footer
            PublicFooter(
              showWideFooter: screenWidth >= 1100,
              name: name,
              onScrollToSection: (section) {
                if (section == 'Careers' || section == 'ScrollToTop') {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
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
  // TOP NAVBAR (MATCHING HOME PAGE)
  // ==========================================================================
  Widget _buildNavbar(bool showDesktopNavbar, String name) {
    final logoUrl = widget.systemLogo;

    return Container(
      decoration: BoxDecoration(
        color: _isNavbarSticky
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white,
        boxShadow: _isNavbarSticky
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE2E8F0)
                .withValues(alpha: _isNavbarSticky ? 0.0 : 1.0),
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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(
                        AppConfig.resolveUrl(logoUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
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
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
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
              _buildNavbarLink('Home', () => context.go('/')),
              _buildNavbarLink(
                  'Features', () => context.go('/#features')),
              _buildNavbarLink('Modules', () => context.go('/#modules')),
              _buildNavbarLink(
                  'Benefits', () => context.go('/#benefits')),
              _buildNavbarLink('Pricing', () => context.go('/#pricing')),
              _buildNavbarLink('About Us', () => context.go('/#about')),
              _buildNavbarLink('Careers', () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              }),
              _buildNavbarLink('Contact Us', () => context.go('/contact')),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => context.go('/login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Login',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => context.go('/get-started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('Get Started',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.bold)),
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

  // ==========================================================================
  // SECTION 1: HERO & FLOATING DISCOVERY CARD
  // ==========================================================================
  Widget _buildHeroSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A1E3C), // Deep Institutional Navy
            Color(0xFF142B4E),
            Color(0xFF1E3A5F),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 20,
        vertical: isDesktop ? 64 : 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "CAREERS" Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'CAREERS',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Main Heading
          Text(
            'Join Our Team',
            style: GoogleFonts.outfit(
              fontSize: isDesktop ? 44 : 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              'Be a part of our mission to provide quality education and shape the future. Explore exciting career opportunities at EduSHAMIIT.',
              style: GoogleFonts.outfit(
                fontSize: isDesktop ? 15 : 13,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 36),

          // Floating Search & Filter Bar Card (matching screenshot)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: isDesktop
                ? Row(
                    children: [
                      // Search Input
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _applySearch(),
                          decoration: InputDecoration(
                            hintText: 'Search job title, department or keywords...',
                            hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),

                      // Location Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLocation,
                            isExpanded: true,
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
                            ),
                            items: _locations.map((loc) {
                              return DropdownMenuItem<String>(
                                value: loc,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 12),
                                    const Icon(Icons.location_on_outlined, color: Color(0xFF64748B), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        loc,
                                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedLocation = val);
                                _fetchJobs(page: 1);
                              }
                            },
                          ),
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),

                      // Department Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            icon: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
                            ),
                            items: _departments.map((dept) {
                              return DropdownMenuItem<String>(
                                value: dept,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 12),
                                    const Icon(Icons.business_outlined, color: Color(0xFF64748B), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dept,
                                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedDepartment = val);
                                _fetchJobs(page: 1);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Search Button
                      ElevatedButton(
                        onPressed: _applySearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3663),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Search Jobs',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _applySearch(),
                        decoration: InputDecoration(
                          hintText: 'Search jobs...',
                          hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(height: 1),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedLocation,
                                isExpanded: true,
                                items: _locations
                                    .map((l) => DropdownMenuItem(value: l, child: Text(l, style: GoogleFonts.outfit(fontSize: 12))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedLocation = v);
                                    _fetchJobs(page: 1);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDepartment,
                                isExpanded: true,
                                items: _departments
                                    .map((d) => DropdownMenuItem(value: d, child: Text(d, style: GoogleFonts.outfit(fontSize: 12))))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedDepartment = v);
                                    _fetchJobs(page: 1);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applySearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F3663),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Search Jobs', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION 2: STATS & HIGHLIGHTS STRIP
  // ==========================================================================
  Widget _buildStatsStrip(bool isDesktop) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 16, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.work_outline, _stats['open_positions_display'] ?? '12+', 'Open Positions'),
                _buildStatDivider(),
                _buildStatItem(Icons.groups_outlined, _stats['departments_count_display'] ?? '5+', 'Departments'),
                _buildStatDivider(),
                _buildStatItem(Icons.trending_up, _stats['growth_opportunities'] ?? '100%', 'Growth Opportunities'),
                _buildStatDivider(),
                _buildStatItem(Icons.favorite_border, _stats['work_environment'] ?? 'Great', 'Work Environment'),
              ],
            )
          : Wrap(
              runSpacing: 16,
              spacing: 24,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.work_outline, _stats['open_positions_display'] ?? '12+', 'Open Positions'),
                _buildStatItem(Icons.groups_outlined, _stats['departments_count_display'] ?? '5+', 'Departments'),
                _buildStatItem(Icons.trending_up, _stats['growth_opportunities'] ?? '100%', 'Growth Opportunities'),
                _buildStatItem(Icons.favorite_border, _stats['work_environment'] ?? 'Great', 'Work Environment'),
              ],
            ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1D4ED8), size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 36,
      width: 1,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ==========================================================================
  // SECTION 3: CURRENT OPENINGS (LEFT COLUMN)
  // ==========================================================================
  Widget _buildOpeningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current Openings',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '$_totalJobs Jobs Found',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Quick Work Mode Pills
        if (_workModes.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._workModes.map((mode) {
                  final isSelected = _selectedWorkMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(mode),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedWorkMode = mode);
                        _fetchJobs(page: 1);
                      },
                      selectedColor: const Color(0xFF0F3663).withValues(alpha: 0.12),
                      checkmarkColor: const Color(0xFF0F3663),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF0F3663) : const Color(0xFF475569),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF0F3663) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  );
                }),
                ..._employmentTypes.where((t) => t != 'All Types').map((type) {
                  final isSelected = _selectedEmploymentType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedEmploymentType = isSelected ? 'All Types' : type);
                        _fetchJobs(page: 1);
                      },
                      selectedColor: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                      checkmarkColor: const Color(0xFF1D4ED8),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Active Filter Chips
        if (_hasActiveFilters) _buildActiveFilterChips(),

        // Loading State
        if (_isLoading) ...[
          for (int i = 0; i < 4; i++) _buildSkeletonCard(),
        ]
        // Error State
        else if (_errorMessage != null)
          _buildErrorCard()
        // Empty State
        else if (_jobs.isEmpty)
          _buildEmptyState()
        // Job Cards List
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _buildJobCard(_jobs[index]);
            },
          ),
          const SizedBox(height: 24),
          _buildPaginationControls(),
        ],
      ],
    );
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedDepartment != 'All Departments' ||
        _selectedLocation != 'All Locations' ||
        _selectedEmploymentType != 'All Types' ||
        _selectedWorkMode != 'All Modes';
  }

  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Filters:', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
          if (_searchQuery.isNotEmpty)
            _buildFilterChip('Keyword: $_searchQuery', () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
              _fetchJobs(page: 1);
            }),
          if (_selectedDepartment != 'All Departments')
            _buildFilterChip(_selectedDepartment, () {
              setState(() => _selectedDepartment = 'All Departments');
              _fetchJobs(page: 1);
            }),
          if (_selectedLocation != 'All Locations')
            _buildFilterChip(_selectedLocation, () {
              setState(() => _selectedLocation = 'All Locations');
              _fetchJobs(page: 1);
            }),
          if (_selectedEmploymentType != 'All Types')
            _buildFilterChip(_selectedEmploymentType, () {
              setState(() => _selectedEmploymentType = 'All Types');
              _fetchJobs(page: 1);
            }),
          if (_selectedWorkMode != 'All Modes')
            _buildFilterChip(_selectedWorkMode, () {
              setState(() => _selectedWorkMode = 'All Modes');
              _fetchJobs(page: 1);
            }),
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Clear All',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF1E293B))),
      deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
      onDeleted: onRemove,
      backgroundColor: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final title = job['job_title'] ?? 'Open Position';
    final dept = job['department'] ?? 'Academic Department';
    final empType = job['employment_type'] ?? 'Full Time';
    final location = job['location'] ?? 'Main Campus';
    final exp = job['experience_required'] ?? '2–5 Years Experience';
    final isFeatured = job['is_featured'] == true;
    final isNew = job['is_featured'] != true; // Alternatively based on posting date

    final rawSlug = job['slug']?.toString().trim();
    final slug = (rawSlug != null && rawSlug.isNotEmpty)
        ? rawSlug
        : (job['job_code'] != null && job['job_code'].toString().trim().isNotEmpty)
            ? job['job_code'].toString().trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            : (job['id']?.toString().trim() ?? '');

    void navigateToJob() {
      if (slug.isNotEmpty) {
        context.go('/careers/jobs/$slug');
      }
    }

    return InkWell(
      onTap: navigateToJob,
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Department / Role Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Icon(
                _getDepartmentIcon(dept, title),
                color: const Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(width: 18),

            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Title + Featured/New badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge matching screenshot
                      if (isFeatured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'Featured',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      )
                    else if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'New',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Subtitle: Department • Employment Type
                Text(
                  '$dept  •  $empType',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // Row: Location & Experience
                Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.work_outline, size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          exp,
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    if (job['work_mode'] != null && job['work_mode'] != 'On-site')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          job['work_mode'],
                          style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF475569)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Apply Now Button (matching screenshot pill)
          ElevatedButton(
            onPressed: () => _openApplicationModal(job),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3663),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Apply Now',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 16, width: 180, color: const Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Container(height: 12, width: 120, color: const Color(0xFFF8FAFC)),
              ],
            ),
          ),
          Container(height: 36, width: 90, color: const Color(0xFFF1F5F9)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(
            'No matching job openings found',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          Text(
            'Try selecting a different department, location, or clearing search criteria.',
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _clearFilters,
            child: Text('Clear All Filters', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'An error occurred.',
              style: GoogleFonts.outfit(color: const Color(0xFF991B1B), fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () => _fetchJobs(page: _currentPage),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 1 ? () => _fetchJobs(page: _currentPage - 1) : null,
        ),
        const SizedBox(width: 8),
        for (int i = 1; i <= _totalPages; i++) ...[
          if (i == 1 || i == _totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1))
            InkWell(
              onTap: () => _fetchJobs(page: i),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == _currentPage ? const Color(0xFF0F3663) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: i == _currentPage ? const Color(0xFF0F3663) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$i',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: i == _currentPage ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            )
          else if (i == _currentPage - 2 || i == _currentPage + 2)
            const Text(' ... '),
          const SizedBox(width: 6),
        ],
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages ? () => _fetchJobs(page: _currentPage + 1) : null,
        ),
      ],
    );
  }

  // ==========================================================================
  // SECTION 4: RIGHT SIDEBAR (CARDS 1, 2, 3 MATCHING SCREENSHOT)
  // ==========================================================================
  Widget _buildRightSidebar() {
    return Column(
      children: [
        // Card 1: "Build Your Future With Us"
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build Your Future\nWith Us',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We offer a supportive, inclusive and innovative work environment where your skills and passion can make a real difference.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  // Scrolls to why work with us
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F2B48),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Learn More', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 2: "Why Work With Us?" (Matching screenshot 4 points)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why Work With Us?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                Icons.layers_outlined,
                const Color(0xFF0284C7),
                'Competitive Salary & Benefits',
                'Attractive compensation packages',
              ),
              const SizedBox(height: 14),
              _buildBenefitItem(
                Icons.trending_up,
                const Color(0xFF10B981),
                'Professional Growth',
                'Learning & development opportunities',
              ),
              const SizedBox(height: 14),
              _buildBenefitItem(
                Icons.people_outline,
                const Color(0xFFF59E0B),
                'Supportive Culture',
                'Collaborative and inclusive environment',
              ),
              const SizedBox(height: 14),
              _buildBenefitItem(
                Icons.check_circle_outline,
                const Color(0xFFEF4444),
                'Make an Impact',
                'Contribute to student success',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Card 3: "Stay Updated" (Newsletter)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.mail_outline, color: Color(0xFF0F3663), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Stay Updated',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Get notified about new job openings and career events.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _newsletterController,
                style: GoogleFonts.outfit(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Enter your email address',
                  hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  final email = _newsletterController.text.trim();
                  if (email.isNotEmpty && email.contains('@')) {
                    _newsletterController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you! You have been subscribed to career notifications.'),
                        backgroundColor: Color(0xFF059669),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3663),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Subscribe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  // ==========================================================================
  // SECTION 6: APPLICATION MODAL & FLOW (END-TO-END)
  // ==========================================================================
  void _openApplicationModal(Map<String, dynamic> job) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => JobApplicationFormDialog(
        job: job,
        baseUrl: _baseUrl,
        onSuccess: (refNum, appliedJobTitle) {
          showApplicationSuccessDialog(context, refNum, appliedJobTitle);
        },
      ),
    );
  }
}

void showApplicationSuccessDialog(BuildContext context, String refNum, String appliedJobTitle) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(28),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Application Submitted Successfully',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You have successfully applied for $appliedJobTitle.',
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text('Application Reference Number', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(
                  refNum,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F3663)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What happens next: Our HR Recruitment team will review your qualifications. Communication regarding your application will be sent to your provided email address.',
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3663),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back to Careers'),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// STATEFUL APPLICATION FORM DIALOG COMPONENT
// ============================================================================
class JobApplicationFormDialog extends StatefulWidget {
  final Map<String, dynamic> job;
  final String baseUrl;
  final Function(String refNum, String jobTitle) onSuccess;

  const JobApplicationFormDialog({
    super.key,
    required this.job,
    required this.baseUrl,
    required this.onSuccess,
  });

  @override
  State<JobApplicationFormDialog> createState() => _JobApplicationFormDialogState();
}

class _JobApplicationFormDialogState extends State<JobApplicationFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _orgController = TextEditingController();
  final _titleController = TextEditingController();
  final _expController = TextEditingController(text: '2.0');
  final _qualificationController = TextEditingController();
  final _specializationController = TextEditingController();
  final _skillsController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _coverLetterController = TextEditingController();
  final _whyJoinController = TextEditingController();
  final _noticePeriodController = TextEditingController(text: '30');
  final _expectedSalaryController = TextEditingController();

  // Gender & Date of Birth
  String? _selectedGender;
  DateTime? _selectedDob;
  final _dobController = TextEditingController();

  // Resume state
  String? _resumeUrl;
  String? _resumeFileName;
  int? _resumeFileSize;
  bool _isUploadingResume = false;

  // Custom question answers
  final Map<String, dynamic> _customAnswers = {};

  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _alternatePhoneController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _orgController.dispose();
    _titleController.dispose();
    _expController.dispose();
    _qualificationController.dispose();
    _specializationController.dispose();
    _skillsController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _coverLetterController.dispose();
    _whyJoinController.dispose();
    _noticePeriodController.dispose();
    _expectedSalaryController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        setState(() => _submissionError = 'Could not read resume file.');
        return;
      }

      if (file.size > 10 * 1024 * 1024) {
        setState(() => _submissionError = 'Resume file exceeds maximum size of 10MB.');
        return;
      }

      setState(() {
        _isUploadingResume = true;
        _submissionError = null;
      });

      final uploadUri = Uri.parse('${widget.baseUrl}/api/public/careers/upload-resume');
      final request = http.MultipartRequest('POST', uploadUri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _resumeUrl = data['data']['resume_url'];
            _resumeFileName = file.name;
            _resumeFileSize = file.size;
            _isUploadingResume = false;
          });
          return;
        }
      }

      setState(() {
        _isUploadingResume = false;
        _submissionError = 'Failed to upload resume. Please try a valid PDF/DOCX file.';
      });
    } catch (e) {
      setState(() {
        _isUploadingResume = false;
        _submissionError = 'Resume upload error: $e';
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_resumeUrl == null) {
      setState(() => _submissionError = 'Please upload your Resume / CV to proceed.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final skillsList = _skillsController.text
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final payload = {
        'job_id': widget.job['id'],
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'alternate_phone': _alternatePhoneController.text.trim().isEmpty ? null : _alternatePhoneController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': _dobController.text.trim().isEmpty ? null : _dobController.text.trim(),
        'city': _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        'state': _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        'current_organization': _orgController.text.trim().isEmpty ? null : _orgController.text.trim(),
        'current_job_title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        'total_experience': double.tryParse(_expController.text.trim()) ?? 0.0,
        'highest_qualification': _qualificationController.text.trim().isEmpty ? null : _qualificationController.text.trim(),
        'specialization': _specializationController.text.trim().isEmpty ? null : _specializationController.text.trim(),
        'skills': skillsList,
        'linkedin_url': _linkedinController.text.trim().isEmpty ? null : _linkedinController.text.trim(),
        'portfolio_url': _portfolioController.text.trim().isEmpty ? null : _portfolioController.text.trim(),
        'cover_letter': _coverLetterController.text.trim().isEmpty ? null : _coverLetterController.text.trim(),
        'why_join_us': _whyJoinController.text.trim().isEmpty ? null : _whyJoinController.text.trim(),
        'notice_period_days': int.tryParse(_noticePeriodController.text.trim()) ?? 0,
        'expected_salary': double.tryParse(_expectedSalaryController.text.replaceAll(RegExp(r'[^\d.]'), '')),
        'resume_url': _resumeUrl,
        'custom_answers': _customAnswers,
      };

      final uri = Uri.parse('${widget.baseUrl}/api/public/careers/apply');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final data = json.decode(resp.body);

      if (resp.statusCode == 200 && data['success'] == true) {
        final refNum = data['data']['application_reference'] ?? 'APP-2026-XXXXXX';
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess(refNum, widget.job['job_title'] ?? 'Position');
        }
      } else if (resp.statusCode == 409) {
        setState(() {
          _isSubmitting = false;
          _submissionError = data['detail'] ?? 'You have already applied for this position.';
        });
      } else {
        setState(() {
          _isSubmitting = false;
          _submissionError = data['detail'] ?? 'Submission failed. Please verify your details.';
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _submissionError = 'Submission error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.job['job_title'] ?? 'Job Application';
    final customQuestions = widget.job['custom_questions'] as List? ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apply for $title',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete the details below. Our HR Recruitment team will review your application.',
                          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Error banner if any
              if (_submissionError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submissionError!,
                          style: GoogleFonts.outfit(color: const Color(0xFF991B1B), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Scrollable Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Personal Information
                        _buildFormSectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: _inputDeco('Full Name *', Icons.person_outline),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                decoration: _inputDeco('Email Address *', Icons.email_outlined),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Email is required';
                                  if (!v.contains('@') || !v.contains('.')) return 'Invalid email address';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: _inputDeco('Mobile Number *', Icons.phone_outlined),
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Mobile Number is required';
                                  if (v.trim().length < 8) return 'Enter valid phone number';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedGender,
                                decoration: _inputDeco('Gender', Icons.wc_outlined),
                                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B)),
                                icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                                hint: Text('Select Gender', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                                items: const [
                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                ],
                                onChanged: (val) => setState(() => _selectedGender = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _dobController,
                                readOnly: true,
                                decoration: _inputDeco('Date of Birth', Icons.cake_outlined).copyWith(
                                  suffixIcon: const Icon(Icons.calendar_month_outlined, size: 18, color: Color(0xFF64748B)),
                                  hintText: 'YYYY-MM-DD',
                                  hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                                ),
                                onTap: () async {
                                  final now = DateTime.now();
                                  final initial = _selectedDob ?? DateTime(now.year - 24, 1, 1);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initial,
                                    firstDate: DateTime(1950, 1, 1),
                                    lastDate: DateTime(now.year - 16, now.month, now.day),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedDob = picked;
                                      _dobController.text =
                                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cityController,
                                decoration: _inputDeco('City', Icons.location_city_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _stateController,
                                decoration: _inputDeco('State', Icons.map_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 2: Professional Details
                        _buildFormSectionTitle('Professional Qualifications'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _orgController,
                                decoration: _inputDeco('Current Organization', Icons.business_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _titleController,
                                decoration: _inputDeco('Current Job Title', Icons.work_outline),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _expController,
                                decoration: _inputDeco('Total Experience (Years) *', Icons.timeline),
                                keyboardType: TextInputType.number,
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Experience is required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _qualificationController,
                                decoration: _inputDeco('Highest Qualification *', Icons.school_outlined),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Qualification is required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _specializationController,
                          decoration: _inputDeco('Specialization (e.g. Computer Science, Mathematics)', Icons.menu_book_outlined),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _skillsController,
                          decoration: _inputDeco('Key Skills (comma separated)', Icons.star_border),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _linkedinController,
                                decoration: _inputDeco('LinkedIn Profile URL', Icons.link),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _portfolioController,
                                decoration: _inputDeco('Portfolio / GitHub URL', Icons.language),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Section 3: Application Details
                        _buildFormSectionTitle('Application & Availability'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _noticePeriodController,
                                decoration: _inputDeco('Notice Period (Days)', Icons.timer_outlined),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _expectedSalaryController,
                                decoration: _inputDeco('Expected Annual Salary (₹)', Icons.currency_rupee),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _coverLetterController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Cover Letter / Brief Introduction',
                            labelStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Section 4: Dynamic Custom Questions
                        if (customQuestions.isNotEmpty) ...[
                          _buildFormSectionTitle('Job Specific Questions'),
                          const SizedBox(height: 12),
                          for (final q in customQuestions) _buildCustomQuestionField(q),
                          const SizedBox(height: 24),
                        ],

                        // Section 5: Resume Upload
                        _buildFormSectionTitle('Upload Resume / CV *'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _resumeUrl != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                              width: _resumeUrl != null ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                _resumeUrl != null ? Icons.check_circle : Icons.upload_file_outlined,
                                size: 36,
                                color: _resumeUrl != null ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              ),
                              const SizedBox(height: 8),
                              if (_resumeUrl != null) ...[
                                Text(
                                  _resumeFileName ?? 'Resume.pdf',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                if (_resumeFileSize != null)
                                  Text(
                                    '${(_resumeFileSize! / 1024).toStringAsFixed(1)} KB • Uploaded',
                                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF10B981)),
                                  ),
                                const SizedBox(height: 8),
                                OutlinedButton(
                                  onPressed: _pickAndUploadResume,
                                  child: const Text('Change File'),
                                ),
                              ] else ...[
                                Text(
                                  'Attach your resume (PDF, DOC, DOCX up to 10MB)',
                                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: _isUploadingResume ? null : _pickAndUploadResume,
                                  icon: _isUploadingResume
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.attach_file, size: 16),
                                  label: Text(_isUploadingResume ? 'Uploading...' : 'Select Resume File'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F3663),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(height: 24),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3663),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Submit Application', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildCustomQuestionField(dynamic q) {
    if (q is! Map) return const SizedBox.shrink();
    final questionText = q['question'] ?? 'Question';
    final questionType = q['type'] ?? 'text'; // 'yes_no', 'text'

    if (questionType == 'yes_no') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(questionText, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                ChoiceChip(
                  label: Text('Yes', style: GoogleFonts.outfit(fontSize: 12)),
                  selected: _customAnswers[questionText] == 'Yes',
                  onSelected: (selected) => setState(() => _customAnswers[questionText] = selected ? 'Yes' : null),
                  selectedColor: const Color(0xFF0F3663).withValues(alpha: 0.15),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: Text('No', style: GoogleFonts.outfit(fontSize: 12)),
                  selected: _customAnswers[questionText] == 'No',
                  onSelected: (selected) => setState(() => _customAnswers[questionText] = selected ? 'No' : null),
                  selectedColor: const Color(0xFF0F3663).withValues(alpha: 0.15),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: questionText,
          labelStyle: GoogleFonts.outfit(fontSize: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onChanged: (val) => _customAnswers[questionText] = val,
      ),
    );
  }
}

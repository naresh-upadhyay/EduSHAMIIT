import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AdminFormControllers {
  final title = TextEditingController();
  final description = TextEditingController();
  final scheduledAt = TextEditingController();
  final expiresAt = TextEditingController();

  void clear() {
    title.clear();
    description.clear();
    scheduledAt.clear();
    expiresAt.clear();
  }

  void dispose() {
    title.dispose();
    description.dispose();
    scheduledAt.dispose();
    expiresAt.dispose();
  }
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _leftScrollController = ScrollController();
  final _rightScrollController = ScrollController();
  final _formControllers = _AdminFormControllers();
  
  bool _isLoading = true;
  bool _isActionLoading = false;
  List<dynamic> _announcements = [];
  List<dynamic> _schools = [];
  List<dynamic> _roles = [];
  List<dynamic> _recentAnnouncements = [];
  Map<String, dynamic> _stats = {
    "total": 0,
    "published": 0,
    "scheduled": 0,
    "draft": 0,
    "expired": 0,
    "audience_breakdown": {}
  };

  // Pagination & Filtering state
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalRecords = 0;
  String _searchQuery = "";
  String _selectedStatus = "All Status";
  String _selectedPriority = "All Priority";
  String _selectedAudience = "All Audience";
  String _selectedInstitution = "All Institutions";

  // Create/Edit Announcement state
  bool _isCreatingOrEditing = false;
  Map<String, dynamic>? _editingAnnouncement;
  List<String> _formAudiences = [];
  String? _formSchoolId; // NULL means 'All Institutions'
  String _formPriority = "Medium";
  String _formStatus = "Draft";
  DateTime? _formScheduledAt;
  DateTime? _formExpiresAt;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _fetchAnnouncements();
    _fetchRecentAnnouncements();
    _fetchSchools();
    _fetchRoles();
  }

  Future<void> _fetchRecentAnnouncements() async {
    try {
      final res = await ApiService().get('/admin/announcements?page=1&page_size=4', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _recentAnnouncements = res['data']['announcements'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching recent announcements: $e");
    }
  }

  void _refreshData() {
    _fetchStats();
    _fetchAnnouncements();
    _fetchRecentAnnouncements();
  }

  @override
  void dispose() {
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    _formControllers.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final res = await ApiService().get('/admin/announcements/stats', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _stats = Map<String, dynamic>.from(res['data'] ?? _stats);
        });
      }
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  Future<void> _fetchSchools() async {
    try {
      final res = await ApiService().get('/admin/schools');
      if (res['success'] == true) {
        setState(() {
          _schools = res['data']['schools'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching schools: $e");
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final res = await ApiService().get('/admin/schools/roles?status=Active');
      if (res['success'] == true && res['data'] != null) {
        final rolesList = List<Map<String, dynamic>>.from(res['data'])
            .where((r) => (r['status'] ?? 'Active').toString().toLowerCase() == 'active')
            .toList();
        setState(() {
          _roles = rolesList;
        });
      }
    } catch (e) {
      print("Error fetching roles: $e");
    }
  }

  Future<void> _fetchAnnouncements() async {
    setState(() {
      _isLoading = true;
    });

    String queryPath = '/admin/announcements?page=$_currentPage&page_size=$_pageSize';
    if (_searchQuery.trim().isNotEmpty) {
      queryPath += '&search=${Uri.encodeComponent(_searchQuery.trim())}';
    }
    if (_selectedStatus != "All Status") {
      queryPath += '&status=$_selectedStatus';
    }
    if (_selectedPriority != "All Priority") {
      queryPath += '&priority=$_selectedPriority';
    }
    if (_selectedAudience != "All Audience") {
      queryPath += '&audience=$_selectedAudience';
    }
    if (_selectedInstitution != "All Institutions") {
      queryPath += '&school_id=$_selectedInstitution';
    }

    try {
      final res = await ApiService().get(queryPath, useCache: false);
      if (res['success'] == true) {
        setState(() {
          _announcements = res['data']['announcements'] ?? [];
          _totalRecords = res['data']['total_records'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load announcements: $e')),
        );
      }
    }
  }

  void _openCreateForm() {
    _formControllers.clear();
    setState(() {
      _editingAnnouncement = null;
      _formAudiences = [];
      _formSchoolId = null;
      _formPriority = "Medium";
      _formStatus = "Draft";
      _formScheduledAt = null;
      _formExpiresAt = null;
      _isCreatingOrEditing = true;
    });
  }

  void _openEditForm(Map<String, dynamic> announcement) {
    _formControllers.clear();
    _formControllers.title.text = announcement['title'] ?? "";
    _formControllers.description.text = announcement['description'] ?? "";
    
    DateTime? scheduled = announcement['scheduled_at'] != null ? DateTime.parse(announcement['scheduled_at']) : null;
    DateTime? expires = announcement['expires_at'] != null ? DateTime.parse(announcement['expires_at']) : null;
    
    if (scheduled != null) {
      _formControllers.scheduledAt.text = DateFormat('yyyy-MM-dd HH:mm').format(scheduled);
    }
    if (expires != null) {
      _formControllers.expiresAt.text = DateFormat('yyyy-MM-dd HH:mm').format(expires);
    }

    setState(() {
      _editingAnnouncement = announcement;
      final rawAudience = announcement['audience'];
      if (rawAudience is List) {
        _formAudiences = List<String>.from(rawAudience);
      } else if (rawAudience is String) {
        _formAudiences = [rawAudience];
      } else {
        _formAudiences = [];
      }
      _formSchoolId = announcement['school_id'];
      _formPriority = announcement['priority'] ?? "Medium";
      _formStatus = announcement['status'] ?? "Draft";
      _formScheduledAt = scheduled;
      _formExpiresAt = expires;
      _isCreatingOrEditing = true;
    });
  }

  Future<void> _saveAnnouncement() async {
    if (_formControllers.title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title is required")),
      );
      return;
    }
    if (_formAudiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("At least one audience role must be selected")),
      );
      return;
    }

    setState(() {
      _isActionLoading = true;
    });

    final payload = {
      "title": _formControllers.title.text.trim(),
      "description": _formControllers.description.text.trim().isEmpty ? null : _formControllers.description.text.trim(),
      "audience": _formAudiences,
      "school_id": _formSchoolId,
      "priority": _formPriority,
      "status": _formStatus,
      "scheduled_at": _formScheduledAt?.toUtc().toIso8601String(),
      "expires_at": _formExpiresAt?.toUtc().toIso8601String()
    };

    try {
      dynamic res;
      if (_editingAnnouncement == null) {
        // Create
        res = await ApiService().post('/admin/announcements', payload);
      } else {
        // Update
        res = await ApiService().put('/admin/announcements/${_editingAnnouncement!['id']}', payload);
      }

      if (res['success'] == true) {
        setState(() {
          _isCreatingOrEditing = false;
        });
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_editingAnnouncement == null 
                ? "Announcement created successfully!" 
                : "Announcement updated successfully!"),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save announcement: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      setState(() {
        _isActionLoading = false;
      });
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      final res = await ApiService().delete('/admin/announcements/$id');
      if (res['success'] == true) {
        _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Announcement deleted successfully!"),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickDateTime(BuildContext context, bool isScheduled) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isScheduled) {
        _formScheduledAt = selected;
        _formControllers.scheduledAt.text = DateFormat('yyyy-MM-dd HH:mm').format(selected);
      } else {
        _formExpiresAt = selected;
        _formControllers.expiresAt.text = DateFormat('yyyy-MM-dd HH:mm').format(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1100;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Main Panel
          Expanded(
            flex: 7,
            child: Scrollbar(
              controller: _leftScrollController,
              child: SingleChildScrollView(
                controller: _leftScrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme, isDark),
                    const SizedBox(height: 24),
                    _buildMetricsGrid(isDark),
                    const SizedBox(height: 24),
                    _isCreatingOrEditing ? _buildFormCard(theme, isDark) : _buildTableCard(theme, isDark),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Sidebar Panel (desktop only)
          if (isDesktop)
            Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                color: isDark ? const Color(0xFF0B0F19) : Colors.white,
              ),
              child: Scrollbar(
                controller: _rightScrollController,
                child: SingleChildScrollView(
                  controller: _rightScrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDoughnutCard(isDark),
                      const SizedBox(height: 24),
                      _buildRecentAnnouncements(isDark),
                      const SizedBox(height: 24),
                      _buildQuickActionsCard(isDark),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Announcements',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create, manage and publish important announcements for institutions, staff, students and parents.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (!_isCreatingOrEditing)
          ElevatedButton.icon(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text('Create Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 2 : (constraints.maxWidth < 900 ? 3 : 5);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            _buildMetricCard(
              title: "Total Announcements",
              value: "${_stats['total']}",
              subtitle: "All time",
              color: const Color(0xFF4F46E5),
              icon: Icons.campaign_rounded,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: "Published",
              value: "${_stats['published']}",
              subtitle: "Currently visible",
              color: const Color(0xFF3B82F6),
              icon: Icons.send_rounded,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: "Scheduled",
              value: "${_stats['scheduled']}",
              subtitle: "Upcoming announcements",
              color: const Color(0xFF10B981),
              icon: Icons.timer_rounded,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: "Drafts",
              value: "${_stats['draft']}",
              subtitle: "Not published yet",
              color: const Color(0xFFF59E0B),
              icon: Icons.edit_rounded,
              isDark: isDark,
            ),
            _buildMetricCard(
              title: "Expired",
              value: "${_stats['expired']}",
              subtitle: "Past expiry date",
              color: const Color(0xFFEF4444),
              icon: Icons.cancel_rounded,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(ThemeData theme, bool isDark) {
    final filteredAnnouncements = _announcements;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(theme, isDark),
          const SizedBox(height: 20),
          _isLoading
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = constraints.maxWidth < 950 ? 950.0 : constraints.maxWidth;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.5),
                            1: FlexColumnWidth(1.0),
                            2: FlexColumnWidth(1.8),
                            3: FlexColumnWidth(1.0),
                            4: FlexColumnWidth(1.0),
                            5: FlexColumnWidth(1.8),
                            6: FlexColumnWidth(1.0),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9))),
                              ),
                              children: const [
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Title", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Audience", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Institution", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Priority", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Published / Scheduled On", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                                Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                              ],
                            ),
                            ...filteredAnnouncements.map((ann) {
                              return TableRow(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9))),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ann['title'] ?? "",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ann['description'] ?? "No description",
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: _buildAudienceBadges(ann['audience']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      ann['school'] != null ? ann['school']['name'] : "All Institutions",
                                      style: TextStyle(fontSize: 11, color: ann['school'] != null ? null : const Color(0xFF64748B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: _buildPriorityBadge(ann['priority']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: _buildStatusBadge(ann['status']),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      _formatDate(ann),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF4F46E5)),
                                          onPressed: () => _openEditForm(ann),
                                          tooltip: "Edit",
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                                          onPressed: () => _showConfirmDelete(ann['id']),
                                          tooltip: "Delete",
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 20),
          _buildPaginationFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          width: 220,
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _currentPage = 1;
              });
              _fetchAnnouncements();
            },
            decoration: const InputDecoration(
              hintText: "Search announcements...",
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
              prefixIcon: Icon(Icons.search_rounded, size: 14, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        _buildDropdownFilter(
          _selectedStatus,
          ["All Status", "Draft", "Published", "Scheduled", "Expired"],
          (val) {
            if (val != null) {
              setState(() {
                _selectedStatus = val;
                _currentPage = 1;
              });
              _fetchAnnouncements();
            }
          },
          theme,
          isDark,
        ),
        _buildDropdownFilter(
          _selectedInstitution,
          ["All Institutions", "Global"] + _schools.map((s) => s['id'].toString()).toList(),
          (val) {
            if (val != null) {
              setState(() {
                _selectedInstitution = val;
                _currentPage = 1;
              });
              _fetchAnnouncements();
            }
          },
          theme,
          isDark,
          displayMapper: (id) {
            if (id == "All Institutions" || id == "Global") return id;
            final match = _schools.firstWhere((s) => s['id'].toString() == id, orElse: () => null);
            return match != null ? match['name'].toString() : id;
          },
        ),
        _buildDropdownFilter(
          _selectedAudience,
          ["All Audience"] + _roles.map((r) => r['name'].toString()).toList() + ["public"],
          (val) {
            if (val != null) {
              setState(() {
                _selectedAudience = val;
                _currentPage = 1;
              });
              _fetchAnnouncements();
            }
          },
          theme,
          isDark,
          displayMapper: (aud) {
            if (aud == "All Audience") return aud;
            return aud.toUpperCase();
          },
        ),
        _buildDropdownFilter(
          _selectedPriority,
          ["All Priority", "Low", "Medium", "High"],
          (val) {
            if (val != null) {
              setState(() {
                _selectedPriority = val;
                _currentPage = 1;
              });
              _fetchAnnouncements();
            }
          },
          theme,
          isDark,
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(
    String value,
    List<String> items,
    void Function(String?) onChanged,
    ThemeData theme,
    bool isDark, {
    String Function(String)? displayMapper,
  }) {
    final activeValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: activeValue,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(displayMapper != null ? displayMapper(item) : item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAudienceBadges(dynamic audienceData) {
    List<dynamic> audiences = [];
    if (audienceData is List) {
      audiences = audienceData;
    } else if (audienceData is String) {
      audiences = [audienceData];
    }
    if (audiences.isEmpty) {
      return const Text("None", style: TextStyle(fontSize: 10, color: Colors.grey));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: audiences.map<Widget>((aud) {
        final label = aud.toString();
        Color bg = Colors.blue.withValues(alpha: 0.1);
        Color text = Colors.blue;

        if (label.toLowerCase() == 'parents' || label.toLowerCase() == 'parent') {
          bg = Colors.purple.withValues(alpha: 0.1);
          text = Colors.purple;
        } else if (label.toLowerCase() == 'staff' || label.toLowerCase() == 'teacher' || label.toLowerCase() == 'admin' || label.toLowerCase() == 'super_admin') {
          bg = Colors.teal.withValues(alpha: 0.1);
          text = Colors.teal;
        } else if (label.toLowerCase() == 'public') {
          bg = Colors.amber.withValues(alpha: 0.1);
          text = Colors.amber;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAudienceBadge(String? audience) {
    final label = audience ?? "Students";
    Color bg = Colors.blue.withValues(alpha: 0.1);
    Color text = Colors.blue;

    if (label.toLowerCase() == 'parents' || label.toLowerCase() == 'parent') {
      bg = Colors.purple.withValues(alpha: 0.1);
      text = Colors.purple;
    } else if (label.toLowerCase() == 'staff' || label.toLowerCase() == 'teacher' || label.toLowerCase() == 'admin' || label.toLowerCase() == 'super_admin') {
      bg = Colors.teal.withValues(alpha: 0.1);
      text = Colors.teal;
    } else if (label.toLowerCase() == 'public') {
      bg = Colors.amber.withValues(alpha: 0.1);
      text = Colors.amber;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String? priority) {
    Color color = Colors.blue;
    if (priority == 'High') color = Colors.red;
    if (priority == 'Medium') color = Colors.orange;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          priority ?? "Medium",
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bg = Colors.grey.withValues(alpha: 0.1);
    Color text = Colors.grey;

    if (status == 'Published') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.1);
      text = const Color(0xFF10B981);
    } else if (status == 'Scheduled') {
      bg = const Color(0xFF8B5CF6).withValues(alpha: 0.1);
      text = const Color(0xFF8B5CF6);
    } else if (status == 'Expired') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.1);
      text = const Color(0xFFEF4444);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(
          status ?? "Draft",
          style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatDate(Map<String, dynamic> ann) {
    String? dateStr = ann['published_at'] ?? ann['scheduled_at'];
    if (dateStr == null) return "--";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM dd, yyyy\nhh:mm A').format(date);
    } catch (_) {
      return "--";
    }
  }

  Widget _buildPaginationFooter(bool isDark) {
    final startIdx = ((_currentPage - 1) * _pageSize) + 1;
    final endIdx = startIdx + _announcements.length - 1;
    final totalPages = (_totalRecords / _pageSize).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Showing $startIdx to $endIdx of $_totalRecords announcements",
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 16),
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _fetchAnnouncements();
                    }
                  : null,
            ),
            const SizedBox(width: 8),
            ...List.generate(totalPages.clamp(1, 5), (index) {
              final page = index + 1;
              final isCurrent = page == _currentPage;
              return InkWell(
                onTap: () {
                  setState(() => _currentPage = page);
                  _fetchAnnouncements();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF4F46E5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$page",
                    style: TextStyle(
                      color: isCurrent ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _fetchAnnouncements();
                    }
                  : null,
            ),
            const SizedBox(width: 16),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                      _fetchAnnouncements();
                    }
                  },
                  items: [5, 10, 20, 50].map((int val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text("$val / page"),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoughnutCard(bool isDark) {
    final breakdown = Map<String, dynamic>.from(_stats['audience_breakdown'] ?? {});
    final total = breakdown.values.fold(0, (sum, val) => sum + (val as int));

    List<PieChartSectionData> sections = [];
    final List<Color> colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFF59E0B)
    ];
    int colorIdx = 0;

    breakdown.forEach((key, val) {
      final percentage = total > 0 ? (val / total * 100).toStringAsFixed(2) : "0.00";
      sections.add(
        PieChartSectionData(
          value: (val as int).toDouble(),
          title: "",
          color: colors[colorIdx % colors.length],
          radius: 18,
        ),
      );
      colorIdx++;
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Audience Overview", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          const SizedBox(height: 20),
          SizedBox(
            height: 140,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sections: sections.isEmpty
                        ? [PieChartSectionData(value: 1, color: Colors.grey.withValues(alpha: 0.2), radius: 10)]
                        : sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 3,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$total",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const Text("Total", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(breakdown.keys.length, (idx) {
            final key = breakdown.keys.elementAt(idx);
            final val = breakdown[key];
            final pct = total > 0 ? (val / total * 100).toStringAsFixed(2) : "0.00";
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedAudience = key.toUpperCase();
                  _currentPage = 1;
                });
                _fetchAnnouncements();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors[idx % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text("$val ($pct%)", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentAnnouncements(bool isDark) {
    final recent = _recentAnnouncements;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Recent Announcements", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          const SizedBox(height: 16),
          recent.isEmpty
              ? const Text("No announcements found", style: TextStyle(fontSize: 11, color: Color(0xFF64748B)))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final ann = recent[idx];
                    return InkWell(
                      onTap: () => _openEditForm(ann),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.campaign_rounded, color: Color(0xFF4F46E5), size: 14),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ann['title'] ?? "",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ann['published_at'] != null 
                                    ? DateFormat('MMM dd, yyyy').format(DateTime.parse(ann['published_at']).toLocal())
                                    : "Draft",
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(ann['status']),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Actions", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          const SizedBox(height: 12),
          _buildQuickActionTile("Announcement Templates", "Use pre-built templates", Icons.file_copy_outlined, isDark),
          const SizedBox(height: 8),
          _buildQuickActionTile("Audience Groups", "Manage audience lists", Icons.groups_outlined, isDark),
          const SizedBox(height: 8),
          _buildQuickActionTile("Notification Settings", "Configure delivery preferences", Icons.notifications_none_rounded, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(String title, String desc, IconData icon, bool isDark) {
    return InkWell(
      onTap: () {
        if (title == "Announcement Templates") {
          _showTemplatesDialog();
        } else if (title == "Audience Groups") {
          _showAudienceGroupsDialog();
        } else if (title == "Notification Settings") {
          context.go('/admin/alerts-notifications');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  void _showTemplatesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
        
        final templates = [
          {
            "title": "Sports Day Announcement",
            "description": "Annual sports day will be held on June 20 at main ground. Attend and support!",
            "audience": ["STUDENT", "TEACHER"],
            "priority": "Low",
            "status": "Scheduled"
          },
          {
            "title": "PTM Schedule Notice",
            "description": "Parent Teacher Meeting is scheduled for next Saturday from 9 AM to 1 PM.",
            "audience": ["PARENT", "ADMIN"],
            "priority": "Medium",
            "status": "Published"
          },
          {
            "title": "Holiday Notice",
            "description": "School will remain closed on upcoming Monday on account of national holiday.",
            "audience": ["STUDENT", "TEACHER", "PARENT"],
            "priority": "High",
            "status": "Scheduled"
          },
          {
            "title": "Staff Meeting Invitation",
            "description": "Weekly staff review meeting is scheduled on Friday at 3:00 PM in conference hall.",
            "audience": ["TEACHER"],
            "priority": "Medium",
            "status": "Draft"
          }
        ];

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text("Select Announcement Template", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: templates.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, idx) {
                final t = templates[idx];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t['title'] as String, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(t['description'] as String, style: TextStyle(color: subtitleColor, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 10),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openCreateForm();
                    // Populate fields
                    _formControllers.title.text = t['title'] as String;
                    _formControllers.description.text = t['description'] as String;
                    setState(() {
                      _formAudiences = List<String>.from(t['audience'] as List);
                      _formPriority = t['priority'] as String;
                      _formStatus = t['status'] as String;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Template '${t['title']}' loaded!"),
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel", style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _showAudienceGroupsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);
        
        final breakdown = Map<String, dynamic>.from(_stats['audience_breakdown'] ?? {});
        
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text("Audience Groups Overview", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGroupTile("Students", breakdown['Student'] ?? 0, Icons.school_outlined, textColor, subtitleColor),
                const Divider(),
                _buildGroupTile("Teachers", breakdown['Teacher'] ?? 0, Icons.people_outline, textColor, subtitleColor),
                const Divider(),
                _buildGroupTile("Parents", breakdown['Parent'] ?? 0, Icons.family_restroom_outlined, textColor, subtitleColor),
                const Divider(),
                _buildGroupTile("Admins", breakdown['Admin'] ?? 0, Icons.admin_panel_settings_outlined, textColor, subtitleColor),
                const Divider(),
                _buildGroupTile("Directors", breakdown['Director'] ?? 0, Icons.work_outline, textColor, subtitleColor),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close", style: TextStyle(fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupTile(String name, int count, IconData icon, Color textColor, Color subtitleColor) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF4F46E5), size: 16),
      title: Text(name, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "$count Active",
          style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showConfirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkTheme(context) ? const Color(0xFF1E293B) : Colors.white,
          title: const Text("Delete Announcement"),
          content: const Text("Are you sure you want to permanently delete this announcement?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAnnouncement(id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  bool isDarkTheme(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Widget _buildFormCard(ThemeData theme, bool isDark) {
    final titleLabel = _editingAnnouncement == null ? 'New Announcement' : 'Edit Announcement';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titleLabel,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _isCreatingOrEditing = false),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _formControllers.title,
            decoration: _buildInputDecoration("Announcement Title", "Enter announcement title...", Icons.title_rounded, theme, isDark),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _formControllers.description,
            maxLines: 4,
            decoration: _buildInputDecoration("Description / Body", "Compose announcement body...", Icons.description_outlined, theme, isDark),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Audience (Select multiple)",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (_roles.map((r) => r['name'].toString()).toList() + ["public"]).map<Widget>((roleName) {
                        final isSelected = _formAudiences.contains(roleName);
                        return FilterChip(
                          label: Text(roleName.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                          checkmarkColor: const Color(0xFF4F46E5),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _formAudiences.add(roleName);
                              } else {
                                _formAudiences.remove(roleName);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormDropdown(
                  "Institution",
                  _formSchoolId ?? "All Institutions",
                  ["All Institutions"] + _schools.map((s) => s['id'].toString()).toList(),
                  (val) {
                    setState(() {
                      _formSchoolId = val == "All Institutions" ? null : val;
                    });
                  },
                  theme,
                  isDark,
                  displayMapper: (id) {
                    if (id == "All Institutions") return id;
                    final match = _schools.firstWhere((s) => s['id'].toString() == id, orElse: () => null);
                    return match != null ? match['name'].toString() : id;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildFormDropdown(
                  "Priority",
                  _formPriority,
                  ["Low", "Medium", "High"],
                  (val) {
                    if (val != null) setState(() => _formPriority = val);
                  },
                  theme,
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormDropdown(
                  "Status",
                  _formStatus,
                  ["Draft", "Published", "Scheduled", "Expired"],
                  (val) {
                    if (val != null) setState(() => _formStatus = val);
                  },
                  theme,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateTime(context, true),
                  child: IgnorePointer(
                    child: TextField(
                      controller: _formControllers.scheduledAt,
                      decoration: _buildInputDecoration("Scheduled Publish Time", "Pick publish time...", Icons.calendar_today_rounded, theme, isDark),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDateTime(context, false),
                  child: IgnorePointer(
                    child: TextField(
                      controller: _formControllers.expiresAt,
                      decoration: _buildInputDecoration("Expiry Date & Time", "Pick expiry time...", Icons.event_busy_rounded, theme, isDark),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _isCreatingOrEditing = false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isActionLoading ? null : _saveAnnouncement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _isActionLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
    ThemeData theme,
    bool isDark, {
    String Function(String)? displayMapper,
  }) {
    final activeValue = items.contains(value)
        ? value
        : (items.isNotEmpty ? items.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeValue,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(displayMapper != null ? displayMapper(item) : item, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, ThemeData theme, bool isDark) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 16),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }
}

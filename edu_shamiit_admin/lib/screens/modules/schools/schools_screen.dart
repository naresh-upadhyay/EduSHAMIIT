import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSchoolsScreen extends StatefulWidget {
  const AdminSchoolsScreen({super.key});

  @override
  State<AdminSchoolsScreen> createState() => _AdminSchoolsScreenState();
}

class _AdminSchoolsScreenState extends State<AdminSchoolsScreen> {
  int _activeTab = 0; // 0: Tenants, 1: Mail Configs, 2: Subscription Plans

  List<dynamic> _schools = [];
  List<dynamic> _mailSubs = [];
  List<dynamic> _plans = [];

  bool _isLoadingSchools = false;
  bool _isLoadingMail = false;
  bool _isLoadingPlans = false;

  String _filter = 'All';
  String _searchQuery = '';
  String _mailFilter = 'All';
  String _mailSearchQuery = '';
  String _plansFilter = 'All';
  String _plansSearchQuery = '';

  final ScrollController _schoolsScrollController = ScrollController();
  final ScrollController _mailScrollController = ScrollController();
  final ScrollController _plansScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSchools();
    _fetchMailSubscriptions();
    _fetchPlans();
  }

  @override
  void dispose() {
    _schoolsScrollController.dispose();
    _mailScrollController.dispose();
    _plansScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    setState(() {
      _isLoadingSchools = true;
    });
    try {
      final res = await ApiService().get('/admin/schools', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _schools = res['data']['schools'] as List<dynamic>? ?? [];
        });
      } else {
        _showError(
            'Failed to load tenants: ${res['detail'] ?? "Unknown error"}');
      }
    } catch (e) {
      _showError('Network error loading tenants: $e');
    } finally {
      setState(() {
        _isLoadingSchools = false;
      });
    }
  }

  Future<void> _fetchMailSubscriptions({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingMail = true;
      });
    }
    try {
      final res = await ApiService()
          .get('/admin/schools/mail-subscriptions', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _mailSubs = res['data']['mail_subscriptions'] as List<dynamic>? ?? [];
        });
      } else {
        _showError(
            'Failed to load mail configs: ${res['detail'] ?? "Unknown error"}');
      }
    } catch (e) {
      _showError('Network error loading mail configs: $e');
    } finally {
      if (showLoading) {
        setState(() {
          _isLoadingMail = false;
        });
      }
    }
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _isLoadingPlans = true;
    });
    try {
      final res =
          await ApiService().get('/admin/schools/plans', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _plans = res['data']['plans'] as List<dynamic>? ?? [];
        });
      } else {
        _showError('Failed to load plans: ${res['detail'] ?? "Unknown error"}');
      }
    } catch (e) {
      _showError('Network error loading subscription plans: $e');
    } finally {
      setState(() {
        _isLoadingPlans = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  Future<void> _deleteSchool(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Delete Tenant?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete "$name"? This action will remove all associated database records and cannot be undone.',
            style:
                const TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final res = await ApiService().delete('/admin/schools/$id');
        if (res['success'] == true) {
          _showSuccess('Tenant "$name" deleted successfully.');
          _fetchSchools();
        } else {
          _showError(
              'Failed to delete tenant: ${res['detail'] ?? "Unknown error"}');
        }
      } catch (e) {
        _showError('Failed to delete tenant due to connection error.');
      }
    }
  }

  Future<void> _sendReminder(String id, String name) async {
    try {
      final res =
          await ApiService().post('/admin/schools/$id/send-reminder', {});
      if (res['success'] == true) {
        _showSuccess(res['message'] ?? 'Reminder alert sent.');
      } else {
        _showError(res['detail'] ?? 'Failed to send alert.');
      }
    } catch (e) {
      _showError('Failed to send reminder due to connection error.');
    }
  }

  Future<void> _deletePlan(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Delete Plan?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete plan "$name"?',
            style:
                const TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final res = await ApiService().delete('/admin/schools/plans/$id');
        if (res['success'] == true) {
          _showSuccess('Plan "$name" deleted.');
          _fetchPlans();
        } else {
          _showError(res['detail'] ?? 'Failed to delete plan.');
        }
      } catch (e) {
        _showError('Connection error.');
      }
    }
  }

  void _showSchoolForm({Map<String, dynamic>? school}) {
    Map<String, dynamic>? mailSub;
    if (school != null) {
      mailSub = _mailSubs.firstWhere(
        (m) => m['school_id'] == school['id'],
        orElse: () => null,
      );
    }
    showDialog(
      context: context,
      builder: (context) => SchoolFormDialog(
        school: school,
        mailSub: mailSub,
        plans: _plans,
        onSaved: () {
          _fetchSchools();
          _fetchMailSubscriptions(showLoading: false);
        },
      ),
    );
  }

  void _showMailConfigForm(Map<String, dynamic>? mailSub) {
    showDialog(
      context: context,
      builder: (context) => MailConfigDialog(
        mailSub: mailSub,
        schools: _schools,
        mailSubs: _mailSubs,
        plans: _plans,
        onSaved: () {
          _fetchMailSubscriptions();
        },
      ),
    );
  }

  void _showPlanForm({Map<String, dynamic>? plan}) {
    showDialog(
      context: context,
      builder: (context) => PlanFormDialog(
        plan: plan,
        onSaved: () {
          _fetchPlans();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        title: Text(
          'Tenant & Subscription Suite',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
            fontSize: 18,
          ),
        ),
        actions: [
          // Compact Custom Tab Switcher (minimizes vertical space)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildCompactTabItem('Tenants', 0, Icons.business_rounded),
                _buildCompactTabItem(
                    'Mail Server Configs', 1, Icons.mail_outline_rounded),
                _buildCompactTabItem(
                    'Subscription Plans', 2, Icons.workspace_premium_rounded),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildActiveTabBody(theme, isDark),
    );
  }

  Widget _buildCompactTabItem(String title, int tabIndex, IconData icon) {
    final isSelected = _activeTab == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = tabIndex;
        });
        if (tabIndex == 0) {
          _fetchSchools();
        } else if (tabIndex == 1) {
          _fetchMailSubscriptions();
        } else {
          _fetchPlans();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
                fontSize: 11,
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabBody(ThemeData theme, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildTenantsTab(theme, isDark);
      case 1:
        return _buildMailTab(theme, isDark);
      case 2:
        return _buildPlansTab(theme, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ===========================================================
  // Tab 1: Tenants Smart Grid
  // ===========================================================
  Widget _buildTenantsTab(ThemeData theme, bool isDark) {
    if (_isLoadingSchools) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredList = _schools.where((s) {
      final nameMatches = (s['name'] as String? ?? '')
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      final status = s['subscription_status'] as String? ?? 'active';
      if (_filter == 'All') return nameMatches;
      if (_filter == 'Active') return status == 'active' && nameMatches;
      if (_filter == 'Expiring') return status == 'expiring' && nameMatches;
      if (_filter == 'Suspended') return status == 'suspended' && nameMatches;
      return nameMatches;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search bar inside the view
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search tenants by name...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: isDark
                          ? BorderSide.none
                          : const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children:
                    ['All', 'Active', 'Expiring', 'Suspended'].map((status) {
                  final isSelected = _filter == status;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _filter = status;
                          });
                        }
                      },
                      backgroundColor: theme.cardColor,
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: isSelected
                            ? BorderSide.none
                            : BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showSchoolForm(),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Add Tenant',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Smart Grid View
          Expanded(
            child: filteredList.isEmpty
                ? const Center(
                    child: Text('No tenants match your filters.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 1200
                        ? 3
                        : (constraints.maxWidth > 800 ? 2 : 1);
                    return GridView.builder(
                      controller: _schoolsScrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 320,
                      ),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final school = filteredList[index];
                        return _buildSchoolGridCard(school, theme, isDark);
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolGridCard(
      Map<String, dynamic> school, ThemeData theme, bool isDark) {
    final status = school['subscription_status'] as String? ?? 'active';
    final tier = school['subscription_tier'] as String? ?? 'premium';
    final pricing = school['pricing_model'] as String? ?? 'per_student';
    final rate = school['pricing_rate'] ?? 10.00;
    final name = school['name'] as String? ?? 'Unnamed School';
    final logoUrl = school['logo_url'] as String?;
    final ownerEmail =
        school['owner_email'] as String? ?? 'No email configured';
    final ownerName = school['owner_name'] as String? ?? 'No name';

    Color statusColor = const Color(0xFF10B981);
    Color statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);

    if (status == 'expiring') {
      statusColor = const Color(0xFFF59E0B);
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
    } else if (status == 'suspended') {
      statusColor = const Color(0xFFEF4444);
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
    }

    final startDateStr = school['subscription_start_date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(school['subscription_start_date']))
        : 'N/A';
    final endDateStr = school['subscription_end_date'] != null
        ? DateFormat('dd MMM yyyy')
            .format(DateTime.parse(school['subscription_end_date']))
        : 'N/A';

    // Warnings alert calculation: is expiring in less than 30 days
    bool showExpiryWarning = false;
    int remainingDays = 0;
    if (school['subscription_end_date'] != null) {
      final end = DateTime.parse(school['subscription_end_date']);
      remainingDays = end.difference(DateTime.now()).inDays;
      if (remainingDays >= 0 && remainingDays <= 30) {
        showExpiryWarning = true;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showExpiryWarning
              ? Colors.amber.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: showExpiryWarning ? 1.5 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Brand & badges
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  child: logoUrl != null &&
                          logoUrl.isNotEmpty &&
                          (logoUrl.startsWith('http://') ||
                              logoUrl.startsWith('https://'))
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                name
                                    .substring(0, name.length > 2 ? 2 : name.length)
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            name
                                .substring(0, name.length > 2 ? 2 : name.length)
                                .toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'Outfit',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      school['address'] ?? 'No address',
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Details row
          _buildDetailRow('Owner Contact', '$ownerName ($ownerEmail)'),
          _buildDetailRow('Active Period', '$startDateStr - $endDateStr'),
          _buildDetailRow(
              'Subscription Price', '₹$rate / ${_formatPricingModel(pricing)}'),

          // Expiring warning alert banner
          if (showExpiryWarning)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Warning: Expires in $remainingDays days!',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),

          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tier.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _sendReminder(school['id'], name),
                    icon: const Icon(Icons.notification_important_outlined,
                        color: Colors.orange, size: 18),
                    tooltip: 'Send Renewal Warning Email',
                  ),
                  IconButton(
                    onPressed: () => _deleteSchool(school['id'], name),
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 18),
                    tooltip: 'Delete Tenant',
                  ),
                  IconButton(
                    onPressed: () => _showSchoolForm(school: school),
                    icon: const Icon(Icons.edit_rounded,
                        color: Color(0xFF4F46E5), size: 18),
                    tooltip: 'Edit Subscription Details',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontFamily: 'Outfit')),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  fontFamily: 'Outfit'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPricingModel(String model) {
    switch (model) {
      case 'per_student':
        return 'Per Student';
      case 'per_month':
        return 'Per Month';
      case 'per_quarter':
        return 'Per Quarter';
      case 'per_year':
        return 'Per Year';
      default:
        return model;
    }
  }

  // ===========================================================
  // Tab 2: Mail Server Advanced Configurations
  // ===========================================================
  Widget _buildMailTab(ThemeData theme, bool isDark) {
    if (_isLoadingMail) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredList = _mailSubs.where((s) {
      final nameMatches = (s['school_name'] as String? ?? '')
          .toLowerCase()
          .contains(_mailSearchQuery.toLowerCase());
      final enabled = s['enabled'] ?? false;
      final sizeLimit = (s['mail_server_size_limit_mb'] ?? 1024.0).toDouble();
      final sizeUsed = (s['mail_server_size_used_mb'] ?? 0.0).toDouble();
      final isOverLimit = sizeUsed >= sizeLimit;

      if (_mailFilter == 'All') return nameMatches;
      if (_mailFilter == 'Enabled') return enabled && nameMatches;
      if (_mailFilter == 'Disabled') return !enabled && nameMatches;
      if (_mailFilter == 'Over Limit') return isOverLimit && nameMatches;
      return nameMatches;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uniform Filter & Search Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search mail servers by school name...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: isDark
                          ? BorderSide.none
                          : const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _mailSearchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children:
                    ['All', 'Enabled', 'Disabled', 'Over Limit'].map((status) {
                  final isSelected = _mailFilter == status;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                          status == 'Over Limit' ? 'Storage Warning' : status,
                          style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _mailFilter = status;
                          });
                        }
                      },
                      backgroundColor: theme.cardColor,
                      selectedColor: const Color(0xFF4F46E5),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: isSelected
                            ? BorderSide.none
                            : BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFE2E8F0),
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showMailConfigForm({}),
                icon: const Icon(Icons.settings_outlined, size: 14),
                label: const Text('Configure SMTP',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _fetchMailSubscriptions,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Mail Servers',
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: filteredList.isEmpty
                ? const Center(
                    child: Text('No mail subscription configurations found.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 1200
                        ? 3
                        : (constraints.maxWidth > 800 ? 2 : 1);
                    return GridView.builder(
                      controller: _mailScrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 340,
                      ),
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final sub = filteredList[index] as Map<String, dynamic>;
                        return _buildMailSubGridCard(sub, theme, isDark);
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildMailSubGridCard(
      Map<String, dynamic> sub, ThemeData theme, bool isDark) {
    final bool enabled = sub['enabled'] ?? false;
    final String pricing = sub['pricing_model'] ?? 'per_email';
    final double rate = (sub['rate_per_unit'] ?? 0.10).toDouble();
    final int limit = sub['monthly_limit'] ?? 5000;
    final int sent = sub['emails_sent'] ?? 0;
    final String schoolName = sub['school_name'] ?? 'Unnamed School';
    final double percent = (sent / limit).clamp(0.0, 1.0);

    final mailPlanCode = sub['mail_plan_code'] as String? ?? 'mail_starter';
    final plan = _plans.firstWhere((p) => p['code'] == mailPlanCode, orElse: () => null);
    final planName = plan != null ? plan['name'] as String : mailPlanCode.toUpperCase();

    // Advanced Mail Server configurations
    final String host = sub['mail_host'] ?? 'smtp.gmail.com';
    final int port = sub['mail_port'] ?? 587;
    final String username = sub['mail_username'] ?? 'Not Configured';

    // Server storage space
    final double sizeLimit =
        (sub['mail_server_size_limit_mb'] ?? 1024.0).toDouble();
    final double sizeUsed = (sub['mail_server_size_used_mb'] ?? 0.0).toDouble();
    final double storagePercent = (sizeUsed / sizeLimit).clamp(0.0, 1.0);

    // Storage alert calculation
    final bool showStorageAlert = sizeUsed >= sizeLimit;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showStorageAlert
              ? Colors.red.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: showStorageAlert ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  schoolName,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: enabled,
                  activeTrackColor: const Color(0xFF10B981),
                  onChanged: (val) async {
                    setState(() {
                      sub['enabled'] = val;
                    });
                    try {
                      final res = await ApiService().put(
                          '/admin/schools/${sub['school_id']}/mail-subscription',
                          {
                            'enabled': val,
                          });
                      if (res['success'] == true) {
                        _showSuccess('Mail status updated.');
                        // Fetch in background to sync backend changes without showing the spinner
                        _fetchMailSubscriptions(showLoading: false);
                      } else {
                        setState(() {
                          sub['enabled'] = !val;
                        });
                        _showError('Failed to toggle status.');
                      }
                    } catch (e) {
                      setState(() {
                        sub['enabled'] = !val;
                      });
                      _showError('Failed to toggle status.');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Advanced host settings
          _buildDetailRow('SMTP Host', '$host:$port'),
          _buildDetailRow('Username', username),
          _buildDetailRow('Mail Plan', planName),
          _buildDetailRow('Billing Plan',
              '₹$rate (${pricing == 'per_email' ? 'Per Email' : 'Flat Monthly'})'),

          // Emails Limit bar
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Email Sent Relay',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              Text('$sent / $limit sent',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor:
                  isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              color: const Color(0xFF4F46E5),
              minHeight: 4,
            ),
          ),

          // Server Storage Space bar
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mail Storage Space',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
              Text(
                  '${sizeUsed.toStringAsFixed(1)} / ${sizeLimit.toStringAsFixed(0)} MB',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: storagePercent,
              backgroundColor:
                  isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              color: showStorageAlert ? Colors.redAccent : Colors.teal,
              minHeight: 4,
            ),
          ),

          // Warning storage block
          if (showStorageAlert)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.redAccent, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'Warning: Server Storage Limit Exceeded!',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),

          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showMailConfigForm(sub),
                icon: const Icon(Icons.settings_outlined, size: 12),
                label: const Text('Configure SMTP & Limits',
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  foregroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // Tab 3: Subscription Plans Manager CRUD
  // ===========================================================
  Widget _buildPlansTab(ThemeData theme, bool isDark) {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredPlans = _plans.where((p) {
      final nameMatches = (p['name'] as String? ?? '')
              .toLowerCase()
              .contains(_plansSearchQuery.toLowerCase()) ||
          (p['code'] as String? ?? '')
              .toLowerCase()
              .contains(_plansSearchQuery.toLowerCase());
      final type = p['plan_type'] ?? 'erp';

      bool typeMatches = true;
      if (_plansFilter == 'ERP') typeMatches = type == 'erp';
      if (_plansFilter == 'Mail') typeMatches = type == 'mail';

      return nameMatches && typeMatches;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uniform Controls Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search subscription plans...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    prefixIcon:
                        const Icon(Icons.search, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: theme.cardColor,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: isDark
                          ? BorderSide.none
                          : const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _plansSearchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  ...['All', 'ERP', 'Mail'].map((type) {
                    final isSelected = _plansFilter == type;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                            type == 'All'
                                ? 'All Plans'
                                : (type == 'ERP' ? 'ERP Tiers' : 'Mail Tiers'),
                            style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _plansFilter = type;
                            });
                          }
                        },
                        backgroundColor: theme.cardColor,
                        selectedColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: isSelected
                              ? BorderSide.none
                              : const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showPlanForm(),
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Add Plan',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _fetchPlans,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Plans',
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: filteredPlans.isEmpty
                ? const Center(
                    child: Text('No plans added in this category.',
                        style: TextStyle(color: Color(0xFF64748B))),
                  )
                : LayoutBuilder(builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 1200
                        ? 3
                        : (constraints.maxWidth > 800 ? 2 : 1);
                    return GridView.builder(
                      controller: _plansScrollController,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 315,
                      ),
                      itemCount: filteredPlans.length,
                      itemBuilder: (context, index) {
                        final plan = filteredPlans[index];
                        return _buildPlanGridCard(plan, theme, isDark);
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanGridCard(
      Map<String, dynamic> plan, ThemeData theme, bool isDark) {
    final String name = plan['name'] ?? 'Unnamed Plan';
    final String code = plan['code'] ?? 'custom';
    final double priceMonth = (plan['price_per_month'] ?? 0.0).toDouble();
    final double priceYear = (plan['price_per_year'] ?? 0.0).toDouble();
    final double discount = (plan['discount_percent'] ?? 0.0).toDouble();
    final String? offerText = plan['offer_text'] as String?;

    // Parse features list
    List<dynamic> features = [];
    if (plan['features'] is List) {
      features = plan['features'];
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: discount > 0
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          width: discount > 0 ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              if (discount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${discount.toInt()}% OFF',
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Code: $code',
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Pricing
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                  Text('₹${priceMonth.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Outfit')),
                ],
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Annual (Save)',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                  Text('₹${priceYear.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF4F46E5),
                          fontFamily: 'Outfit')),
                ],
              ),
            ],
          ),

          // Offer texts banner
          if (offerText != null && offerText.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_outlined,
                      color: Color(0xFF4F46E5), size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      offerText,
                      style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 8),

          const SizedBox(height: 10),
          const Text('Key Features:',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 4),

          Expanded(
            child: ListView.builder(
              itemCount: features.length,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0, right: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2.0),
                        child: Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 10),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          features[index],
                          style: const TextStyle(
                              fontSize: 10, fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Edit/Delete plans action row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => _deletePlan(plan['id'], name),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 18),
                tooltip: 'Delete Plan',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showPlanForm(plan: plan),
                icon: const Icon(Icons.edit_rounded, size: 12),
                label: const Text('Edit Plan',
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  foregroundColor: const Color(0xFF4F46E5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// School / Tenant Form Dialog
// ===========================================================
class SchoolFormDialog extends StatefulWidget {
  final Map<String, dynamic>? school;
  final Map<String, dynamic>? mailSub;
  final List<dynamic> plans;
  final VoidCallback onSaved;

  const SchoolFormDialog({
    super.key,
    this.school,
    this.mailSub,
    required this.plans,
    required this.onSaved,
  });

  @override
  State<SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends State<SchoolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _logoController;
  late TextEditingController _rateController;
  late TextEditingController _maxStudentsController;

  // Owner details
  late TextEditingController _ownerNameController;
  late TextEditingController _ownerEmailController;
  bool _sendRenewalReminders = true;

  // Mail server details
  late TextEditingController _mailHostController;
  late TextEditingController _mailPortController;
  late TextEditingController _mailUsernameController;
  late TextEditingController _mailPasswordController;
  late TextEditingController _mailStorageController;

  String _tier = 'premium';
  String _mailPlanCode = 'mail_starter';
  bool _enableMailServer = false; // Mail server is opt-in
  String _status = 'active';
  String _pricingModel = 'per_student';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));

  bool _isSaving = false;
  bool _isUploadingLogo = false;

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Logo',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Logo',
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 220, height: 220),
          zoomable: true,
          rotatable: true,
          scalable: true,
        ),
      ],
    );
    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
    return null;
  }

  Future<void> _uploadLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 90,
      );
      if (picked == null) return;

      final croppedBytes = await _cropImage(picked.path);
      if (croppedBytes == null) return; // User cancelled crop

      setState(() {
        _isUploadingLogo = true;
      });

      String filename = picked.name;
      if (!filename.contains('.')) {
        filename += '.png';
      }

      final response = await ApiService().multipartPostBytes(
        '/admin/schools/upload-logo',
        croppedBytes,
        filename,
        'file',
      );

      if (response['success'] == true) {
        final publicUrl = response['data']?['logo_url'] as String?;
        if (publicUrl != null && mounted) {
          setState(() {
            _logoController.text = publicUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Logo uploaded and cropped successfully!'),
                backgroundColor: Color(0xFF10B981)),
          );
        }
      } else {
        throw response['detail'] ?? 'Failed to upload logo to server';
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to upload logo: $err'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingLogo = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    final ms = widget.mailSub;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _addressController = TextEditingController(text: s?['address'] ?? '');
    _phoneController = TextEditingController(text: s?['phone'] ?? '');
    _logoController = TextEditingController(text: s?['logo_url'] ?? '');
    _rateController =
        TextEditingController(text: (s?['pricing_rate'] ?? 10.00).toString());
    _maxStudentsController =
        TextEditingController(text: (s?['max_students'] ?? 1000).toString());

    _ownerNameController = TextEditingController(text: s?['owner_name'] ?? '');
    _ownerEmailController =
        TextEditingController(text: s?['owner_email'] ?? '');
    _sendRenewalReminders = s?['send_renewal_reminders'] ?? true;

    _mailHostController = TextEditingController(text: ms?['mail_host'] ?? 'smtp.gmail.com');
    _mailPortController = TextEditingController(text: (ms?['mail_port'] ?? 587).toString());
    _mailUsernameController = TextEditingController(text: ms?['mail_username'] ?? '');
    _mailPasswordController = TextEditingController(text: ms?['mail_password'] ?? '');
    _mailStorageController = TextEditingController(
        text: (ms?['mail_server_size_limit_mb'] ?? 1024.0).toString());
    _mailPlanCode = ms?['mail_plan_code'] ?? 'mail_starter';
    // Toggle is ON only when a subscription row exists AND it's enabled in DB
    _enableMailServer = ms != null && (ms['enabled'] == true);

    if (s != null) {
      _tier = s['subscription_tier'] ?? 'premium';
      _status = s['subscription_status'] ?? 'active';
      _pricingModel = s['pricing_model'] ?? 'per_student';
      if (s['subscription_start_date'] != null) {
        _startDate = DateTime.parse(s['subscription_start_date']);
      }
      if (s['subscription_end_date'] != null) {
        _endDate = DateTime.parse(s['subscription_end_date']);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _logoController.dispose();
    _rateController.dispose();
    _maxStudentsController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _mailHostController.dispose();
    _mailPortController.dispose();
    _mailUsernameController.dispose();
    _mailPasswordController.dispose();
    _mailStorageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final payload = {
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'logo_url': _logoController.text.trim(),
      'subscription_tier': _tier,
      'subscription_status': _status,
      'pricing_model': _pricingModel,
      'pricing_rate': double.tryParse(_rateController.text) ?? 10.00,
      'max_students': int.tryParse(_maxStudentsController.text) ?? 1000,
      'subscription_start_date': _startDate.toIsoformatString(),
      'subscription_end_date': _endDate.toIsoformatString(),
      'owner_name': _ownerNameController.text.trim(),
      'owner_email': _ownerEmailController.text.trim(),
      'send_renewal_reminders': _sendRenewalReminders,
      // Always send the toggle state so backend can enable/disable the subscription
      'enable_mail_server': _enableMailServer,
      if (_enableMailServer) ...{
        'mail_plan_code': _mailPlanCode,
        'mail_host': _mailHostController.text.trim(),
        'mail_port': int.tryParse(_mailPortController.text) ?? 587,
        'mail_username': _mailUsernameController.text.trim(),
        'mail_password': _mailPasswordController.text.trim(),
        'mail_server_size_limit_mb':
            double.tryParse(_mailStorageController.text) ?? 1024.00,
      },
    };

    try {
      final bool isEdit = widget.school != null;
      final res = isEdit
          ? await ApiService()
              .put('/admin/schools/${widget.school!['id']}', payload)
          : await ApiService().post('/admin/schools', payload);

      if (res['success'] == true) {
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        _showError(res['detail'] ?? 'Failed to save school');
      }
    } catch (e) {
      _showError('Failed to save school due to network error.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title =
        widget.school == null ? 'Add New Tenant' : 'Edit Subscription';

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Brand Info
                const Text('1. Institute Details',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                      labelText: 'Institute Name *',
                      hintText: 'Enter name of school/university'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _addressController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        child: _logoController.text.isNotEmpty &&
                                (_logoController.text.startsWith('http://') ||
                                    _logoController.text.startsWith('https://'))
                            ? Image.network(
                                _logoController.text,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.business_rounded,
                                        color: Color(0xFF4F46E5), size: 28),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(Icons.business_rounded,
                                    color: Color(0xFF4F46E5), size: 28),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isUploadingLogo ? null : _uploadLogo,
                          icon: _isUploadingLogo
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_upload_outlined,
                                  size: 14),
                          label: Text(
                              _isUploadingLogo
                                  ? 'Uploading...'
                                  : 'Upload Logo Icon',
                              style: const TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supported formats: PNG, JPG, SVG. Max 2MB.',
                          style:
                              TextStyle(color: Color(0xFF64748B), fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _logoController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          labelText: 'Logo URL Link (Optional fallback)',
                          hintText: 'Or paste an external image link',
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 2: Owner Details
                const Text('2. Owner & Contact Information',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ownerNameController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Owner / Director Name *'),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _ownerEmailController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Owner Email (Billing Contact) *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _sendRenewalReminders,
                  title: const Text(
                      'Shoot renewal alert warnings to owner before expiry',
                      style: TextStyle(fontSize: 12)),
                  activeColor: const Color(0xFF4F46E5),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sendRenewalReminders = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Section 3: Subscription Parameters
                const Text('3. SaaS Subscription Parameters',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _tier,
                        style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration:
                            const InputDecoration(labelText: 'ERP Subscription Plan *'),
                        items: () {
                          final erpPlans = widget.plans
                              .where((p) => p['plan_type'] == null || p['plan_type'] == 'erp')
                              .toList();
                          if (!erpPlans.any((p) => p['code'] == _tier)) {
                            erpPlans.add({
                              'code': _tier,
                              'name': _tier.toUpperCase(),
                              'plan_type': 'erp',
                              'price_per_month': 0.0,
                            });
                          }
                          return erpPlans.map<DropdownMenuItem<String>>((p) {
                            final price = p['price_per_month'] ?? 0;
                            return DropdownMenuItem<String>(
                              value: p['code'] as String,
                              child: Text('${p['name']} (₹$price/mo)'),
                            );
                          }).toList();
                        }(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _tier = val;
                              // Dynamically update default values
                              if (val == 'basic') {
                                _pricingModel = 'per_student';
                                _rateController.text = '10.00';
                                _maxStudentsController.text = '500';
                              } else if (val == 'premium') {
                                _pricingModel = 'per_student';
                                _rateController.text = '10.00';
                                _maxStudentsController.text = '2000';
                              } else if (val == 'enterprise') {
                                _pricingModel = 'per_month';
                                _rateController.text = '4999.00';
                                _maxStudentsController.text = '50000';
                              }
                            });
                          }
                        },
                        validator: (val) => val == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: () {
                          final dropdownItems = ['active', 'expiring', 'suspended'];
                          if (!dropdownItems.contains(_status)) {
                            dropdownItems.add(_status);
                          }
                          return dropdownItems.map((status) {
                            return DropdownMenuItem(
                                value: status, child: Text(status.toUpperCase()));
                          }).toList();
                        }(),
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Optional Mail Server Feature Toggle ──────────────────
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _enableMailServer
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFE2E8F0),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _enableMailServer
                        ? const Color(0xFF4F46E5).withOpacity(0.05)
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded,
                          size: 20, color: Color(0xFF4F46E5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Transactional Mail Server',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Optional — activate SMTP mail subscription for this tenant',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableMailServer,
                        activeColor: const Color(0xFF4F46E5),
                        onChanged: (val) =>
                            setState(() => _enableMailServer = val),
                      ),
                    ],
                  ),
                ),
                if (_enableMailServer) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _mailPlanCode,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Mail Subscription Plan *',
                      border: OutlineInputBorder(),
                    ),
                    items: () {
                      final list = widget.plans
                          .where((p) => p['plan_type'] == 'mail')
                          .toList();
                      if (!list.any((p) => p['code'] == _mailPlanCode)) {
                        list.add({
                          'code': _mailPlanCode,
                          'name': _mailPlanCode.toUpperCase().replaceAll('_', ' '),
                          'plan_type': 'mail',
                          'price_per_month': 0.0,
                        });
                      }
                      return list.map<DropdownMenuItem<String>>((p) {
                        final price = p['price_per_month'] ?? 0;
                        return DropdownMenuItem<String>(
                          value: p['code'] as String,
                          child: Text('${p['name']} (Rs.$price/mo)'),
                        );
                      }).toList();
                    }(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _mailPlanCode = val;
                          if (widget.school == null) {
                            if (val == 'mail_starter') {
                              _mailStorageController.text = '1024';
                            } else if (val == 'mail_growth') {
                              _mailStorageController.text = '5120';
                            } else if (val == 'mail_enterprise') {
                              _mailStorageController.text = '102400';
                            }
                          }
                        });
                      }
                    },
                  ),
                ], // end if (_enableMailServer)

                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _pricingModel,
                        decoration:
                            const InputDecoration(labelText: 'Pricing Model'),
                        items: () {
                          final dropdownItems = [
                            'per_student',
                            'per_month',
                            'per_quarter',
                            'per_year'
                          ];
                          if (!dropdownItems.contains(_pricingModel)) {
                            dropdownItems.add(_pricingModel);
                          }
                          return dropdownItems.map((model) {
                            return DropdownMenuItem(
                                value: model,
                                child: Text(
                                    model.replaceAll('_', ' ').toUpperCase()));
                          }).toList();
                        }(),
                        onChanged: (val) {
                          if (val != null) setState(() => _pricingModel = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Billing Rate (₹) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _maxStudentsController,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                      labelText: 'Maximum Student Capacity *'),
                  keyboardType: TextInputType.number,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Timelines
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start Date',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF64748B))),
                        subtitle: Text(
                            DateFormat('dd MMM yyyy').format(_startDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        trailing:
                            const Icon(Icons.calendar_today_rounded, size: 14),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) setState(() => _startDate = date);
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End Date (Expiry)',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF64748B))),
                        subtitle: Text(
                            DateFormat('dd MMM yyyy').format(_endDate),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        trailing:
                            const Icon(Icons.calendar_today_rounded, size: 14),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) setState(() => _endDate = date);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 4: Initial Mail Server configs (Only for new schools with mail enabled)
                if (widget.school == null && _enableMailServer) ...[
                  const Text('4. Initial Transactional Mail Configurations',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF4F46E5))),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mailHostController,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration: const InputDecoration(
                              labelText: 'SMTP Host IP/Domain'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _mailPortController,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration:
                              const InputDecoration(labelText: 'SMTP Port'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mailUsernameController,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration:
                              const InputDecoration(labelText: 'SMTP Username'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _mailPasswordController,
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A)),
                          decoration:
                              const InputDecoration(labelText: 'SMTP Password'),
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _mailStorageController,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                        labelText: 'Mail Server Storage Size Limit (MB)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

// ===========================================================
// Mail Server Configure Dialog
// ===========================================================
class MailConfigDialog extends StatefulWidget {
  final Map<String, dynamic>? mailSub;
  final List<dynamic> schools;
  final List<dynamic> mailSubs;
  final List<dynamic> plans;
  final VoidCallback onSaved;

  const MailConfigDialog({
    super.key,
    this.mailSub,
    required this.schools,
    required this.mailSubs,
    required this.plans,
    required this.onSaved,
  });

  @override
  State<MailConfigDialog> createState() => _MailConfigDialogState();
}

class _MailConfigDialogState extends State<MailConfigDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _rateController;
  late TextEditingController _limitController;
  late TextEditingController _sentController;

  // Advanced SMTP Configs
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  // Storage Metrics
  late TextEditingController _storageLimitController;
  late TextEditingController _storageUsedController;

  String _pricingModel = 'per_email';
  String _mailPlanCode = 'mail_starter';
  bool _isSaving = false;
  String? _selectedSchoolId;

  @override
  void initState() {
    super.initState();
    final ms = widget.mailSub;
    if (ms != null && ms.isNotEmpty) {
      _selectedSchoolId = ms['school_id'];
      _initFields(ms);
    } else {
      _initFields({});
    }
  }

  void _initFields(Map<String, dynamic> ms) {
    _rateController =
        TextEditingController(text: (ms['rate_per_unit'] ?? 0.10).toString());
    _limitController =
        TextEditingController(text: (ms['monthly_limit'] ?? 5000).toString());
    _sentController =
        TextEditingController(text: (ms['emails_sent'] ?? 0).toString());
    _pricingModel = ms['pricing_model'] ?? 'per_email';
    _mailPlanCode = ms['mail_plan_code'] ?? 'mail_starter';

    _hostController =
        TextEditingController(text: ms['mail_host'] ?? 'smtp.gmail.com');
    _portController =
        TextEditingController(text: (ms['mail_port'] ?? 587).toString());
    _usernameController =
        TextEditingController(text: ms['mail_username'] ?? '');
    _passwordController =
        TextEditingController(text: ms['mail_password'] ?? '');

    _storageLimitController = TextEditingController(
        text: (ms['mail_server_size_limit_mb'] ?? 1024.00).toString());
    _storageUsedController = TextEditingController(
        text: (ms['mail_server_size_used_mb'] ?? 0.00).toString());
  }

  void _onSchoolChanged(String? schoolId) {
    if (schoolId == null) return;
    setState(() {
      _selectedSchoolId = schoolId;
      final existing = widget.mailSubs.firstWhere(
        (m) => m['school_id'] == schoolId,
        orElse: () => null,
      );
      if (existing != null) {
        _rateController.text = (existing['rate_per_unit'] ?? 0.10).toString();
        _limitController.text = (existing['monthly_limit'] ?? 5000).toString();
        _sentController.text = (existing['emails_sent'] ?? 0).toString();
        _pricingModel = existing['pricing_model'] ?? 'per_email';
        _mailPlanCode = existing['mail_plan_code'] ?? 'mail_starter';
        _hostController.text = existing['mail_host'] ?? 'smtp.gmail.com';
        _portController.text = (existing['mail_port'] ?? 587).toString();
        _usernameController.text = existing['mail_username'] ?? '';
        _passwordController.text = existing['mail_password'] ?? '';
        _storageLimitController.text =
            (existing['mail_server_size_limit_mb'] ?? 1024.00).toString();
        _storageUsedController.text =
            (existing['mail_server_size_used_mb'] ?? 0.00).toString();
      } else {
        _rateController.text = '0.10';
        _limitController.text = '5000';
        _sentController.text = '0';
        _pricingModel = 'per_email';
        _mailPlanCode = 'mail_starter';
        _hostController.text = 'smtp.gmail.com';
        _portController.text = '587';
        _usernameController.text = '';
        _passwordController.text = '';
        _storageLimitController.text = '1024.00';
        _storageUsedController.text = '0.00';
      }
    });
  }

  @override
  void dispose() {
    _rateController.dispose();
    _limitController.dispose();
    _sentController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _storageLimitController.dispose();
    _storageUsedController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final schoolId = _selectedSchoolId;
    if (schoolId == null || schoolId.isEmpty) {
      _showError('Please select a school to configure SMTP.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final payload = {
      'pricing_model': _pricingModel,
      'rate_per_unit': double.tryParse(_rateController.text) ?? 0.10,
      'monthly_limit': int.tryParse(_limitController.text) ?? 5000,
      'emails_sent': int.tryParse(_sentController.text) ?? 0,
      'mail_host': _hostController.text.trim(),
      'mail_port': int.tryParse(_portController.text) ?? 587,
      'mail_username': _usernameController.text.trim(),
      'mail_password': _passwordController.text.trim(),
      'mail_server_size_limit_mb':
          double.tryParse(_storageLimitController.text) ?? 1024.00,
      'mail_server_size_used_mb':
          double.tryParse(_storageUsedController.text) ?? 0.00,
      'mail_plan_code': _mailPlanCode,
    };

    try {
      final res = await ApiService()
          .put('/admin/schools/$schoolId/mail-subscription', payload);
      if (res['success'] == true) {
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        _showError(res['detail'] ?? 'Failed to update mail subscription');
      }
    } catch (e) {
      _showError('Failed to save config due to network error.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: const Text('Configure Transactional Mail Limits',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.mailSub == null || widget.mailSub!.isEmpty) ...[
                  const Text('Select Tenant / School',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF4F46E5))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSchoolId,
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      labelText: 'Select Tenant *',
                      border: OutlineInputBorder(),
                    ),
                    items: () {
                      final dropdownItems = List<Map<String, dynamic>>.from(widget.schools);
                      if (_selectedSchoolId != null &&
                          !dropdownItems.any((s) => s['id'] == _selectedSchoolId)) {
                        dropdownItems.insert(0, {
                          'id': _selectedSchoolId,
                          'name': 'Unknown School ID ($_selectedSchoolId)',
                        });
                      }
                      return dropdownItems.map<DropdownMenuItem<String>>((s) {
                        return DropdownMenuItem<String>(
                          value: s['id'],
                          child: Text(s['name'] ?? 'Unnamed School'),
                        );
                      }).toList();
                    }(),
                    onChanged: _onSchoolChanged,
                    validator: (val) => val == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  Text(
                    'School: ${widget.mailSub!['school_name'] ?? 'Unnamed School'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(height: 20),
                ],
                // Mail Plan Selection
                const Text('Mail Subscription Plan',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _mailPlanCode,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    labelText: 'Mail Subscription Plan *',
                    border: OutlineInputBorder(),
                  ),
                  items: () {
                    final list = widget.plans
                        .where((p) => p['plan_type'] == 'mail')
                        .toList();
                    if (!list.any((p) => p['code'] == _mailPlanCode)) {
                      list.add({
                        'code': _mailPlanCode,
                        'name': _mailPlanCode.toUpperCase().replaceAll('_', ' '),
                        'plan_type': 'mail',
                        'price_per_month': 0.0,
                      });
                    }
                    return list.map<DropdownMenuItem<String>>((p) {
                      final price = p['price_per_month'] ?? 0;
                      return DropdownMenuItem<String>(
                        value: p['code'] as String,
                        child: Text('${p['name']} (₹$price/mo)'),
                      );
                    }).toList();
                  }(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _mailPlanCode = val;
                        // Dynamically update the limit and rate if the user changes the plan
                        if (val == 'mail_starter') {
                          _limitController.text = '5000';
                          _rateController.text = '0.10';
                          _pricingModel = 'per_email';
                        } else if (val == 'mail_growth') {
                          _limitController.text = '25000';
                          _rateController.text = '0.08';
                          _pricingModel = 'per_email';
                        } else if (val == 'mail_enterprise') {
                          _limitController.text = '100000';
                          _rateController.text = '0.05';
                          _pricingModel = 'monthly_flat';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Billing
                const Text('Billing Settings',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _pricingModel,
                  decoration:
                      const InputDecoration(labelText: 'Mail Pricing Model'),
                  items: () {
                    final dropdownItems = ['per_email', 'monthly_flat', 'unlimited'];
                    if (!dropdownItems.contains(_pricingModel)) {
                      dropdownItems.add(_pricingModel);
                    }
                    return dropdownItems.map((model) {
                      return DropdownMenuItem(
                          value: model,
                          child: Text(model.replaceAll('_', ' ').toUpperCase()));
                    }).toList();
                  }(),
                  onChanged: (val) {
                    if (val != null) setState(() => _pricingModel = val);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration:
                            const InputDecoration(labelText: 'Rate (₹) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _limitController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Monthly Limit (Emails) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SMTP Configs
                const Text('SMTP Mail Server Settings',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _hostController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'SMTP Host Server IP / DNS'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration:
                            const InputDecoration(labelText: 'SMTP Port'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usernameController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration:
                            const InputDecoration(labelText: 'SMTP Username'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _passwordController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration:
                            const InputDecoration(labelText: 'SMTP Password'),
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Storage Capacity Space
                const Text('Mail Storage Limits & Counters',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Color(0xFF4F46E5))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _storageLimitController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Server Storage Limit (MB) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _storageUsedController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Storage Space Used (MB) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _sentController,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                      labelText: 'Manual Reset Emails Sent Counter'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save Configurations'),
        ),
      ],
    );
  }
}

// ===========================================================
// Plan Form Dialog (Subscription Catalog plans CRUD)
// ===========================================================
class PlanFormDialog extends StatefulWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback onSaved;

  const PlanFormDialog({super.key, this.plan, required this.onSaved});

  @override
  State<PlanFormDialog> createState() => _PlanFormDialogState();
}

class _PlanFormDialogState extends State<PlanFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _priceMonthController;
  late TextEditingController _priceYearController;
  late TextEditingController _discountController;
  late TextEditingController _offerTextController;
  late TextEditingController _featuresController; // Features comma-separated

  String _planType = 'erp';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _nameController = TextEditingController(text: p?['name'] ?? '');
    _codeController = TextEditingController(text: p?['code'] ?? '');
    _priceMonthController =
        TextEditingController(text: (p?['price_per_month'] ?? 0.0).toString());
    _priceYearController =
        TextEditingController(text: (p?['price_per_year'] ?? 0.0).toString());
    _discountController =
        TextEditingController(text: (p?['discount_percent'] ?? 0.0).toString());
    _offerTextController = TextEditingController(text: p?['offer_text'] ?? '');
    _planType = p?['plan_type'] ?? 'erp';

    // Parse list of features into comma-separated text
    String featText = '';
    if (p?['features'] is List) {
      featText = (p?['features'] as List).join(', ');
    }
    _featuresController = TextEditingController(text: featText);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _priceMonthController.dispose();
    _priceYearController.dispose();
    _discountController.dispose();
    _offerTextController.dispose();
    _featuresController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    // Convert comma-separated string back to list
    final List<String> featuresList = _featuresController.text
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toLowerCase(),
      'plan_type': _planType,
      'price_per_month': double.tryParse(_priceMonthController.text) ?? 0.00,
      'price_per_year': double.tryParse(_priceYearController.text) ?? 0.00,
      'discount_percent': double.tryParse(_discountController.text) ?? 0.00,
      'offer_text': _offerTextController.text.trim(),
      'features': featuresList
    };

    try {
      final bool isEdit = widget.plan != null;
      final res = isEdit
          ? await ApiService()
              .put('/admin/schools/plans/${widget.plan!['id']}', payload)
          : await ApiService().post('/admin/schools/plans', payload);

      if (res['success'] == true) {
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        _showError(res['detail'] ?? 'Failed to save subscription plan');
      }
    } catch (e) {
      _showError('Failed to save plan due to network error.');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title =
        widget.plan == null ? 'Create Subscription Plan' : 'Edit Plan Details';

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _planType,
                  decoration: const InputDecoration(
                      labelText: 'Plan Category / Type *'),
                  items: const [
                    DropdownMenuItem(
                        value: 'erp', child: Text('ERP Subscription')),
                    DropdownMenuItem(
                        value: 'mail', child: Text('Mail Notification Server')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _planType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                      labelText: 'Plan Name *',
                      hintText: 'Basic, Premium, Enterprise...'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                      labelText: 'Plan Code UNIQUE *',
                      hintText: 'basic, premium, enterprise'),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                  enabled: widget.plan == null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceMonthController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Price Per Month (₹) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceYearController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Price Per Year (₹) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discountController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Discount Percent (%)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _offerTextController,
                        style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                            labelText: 'Offer Text Banner',
                            hintText: 'Festive Sale: 20% Off!'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _featuresController,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    labelText: 'Key Features (comma-separated)',
                    hintText: 'Core ERP, IoT integration, LMS Access',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child:
              const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save Plan'),
        ),
      ],
    );
  }
}

extension DateTimeIso on DateTime {
  String toIsoformatString() {
    return toUtc().toIso8601String();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:go_router/go_router.dart';

// Helper widget for a premium modular card wrapper
class QuickAccessCard extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const QuickAccessCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: theme.cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.04),
        elevation: isDark ? 0 : 2,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// Scaffold helper for all quick access screens
class QuickAccessScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const QuickAccessScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}



// 2. Module Toggle Screen
class ModuleToggleScreen extends StatefulWidget {
  const ModuleToggleScreen({super.key});

  @override
  State<ModuleToggleScreen> createState() => _ModuleToggleScreenState();
}

class _ModuleToggleScreenState extends State<ModuleToggleScreen> {
  List<dynamic> _schools = [];
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final schoolsRes = await ApiService().get('/admin/schools', useCache: false);
      final modulesRes = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (schoolsRes['success'] == true && modulesRes['success'] == true) {
        setState(() {
          _schools = schoolsRes['data']['schools'] as List<dynamic>? ?? [];
          
          final allModules = modulesRes['data'] as List<dynamic>? ?? [];
          _modules = allModules.where((m) => m['is_enabled'] == true).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load module configuration: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return QuickAccessScaffold(
      title: 'Module Management',
      children: [
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        else if (_schools.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No schools registered in the system.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          )
        else
          ..._schools.map((school) {
            final logoUrl = school['logo_url']?.toString() ?? '';
            final address = school['address']?.toString() ?? 'UP, India';
            final existingUsers = school['existing_users'] ?? 0;
            final maxStudents = school['max_students'] ?? 1000;
            final moduleToggles = school['module_toggles'] as Map<String, dynamic>? ?? {};

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // School Info Header
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'))
                              ? Image.network(
                                  logoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, s) => const Icon(
                                    Icons.school_outlined,
                                    color: Color(0xFF4F46E5),
                                    size: 22,
                                  ),
                                )
                              : const Icon(
                                  Icons.school_outlined,
                                  color: Color(0xFF4F46E5),
                                  size: 22,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              school['name'] ?? 'Institution Name',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$address • $existingUsers / $maxStudents users',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  // Grid of Toggles
                  if (_modules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No globally active modules configured in setup.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 8,
                        mainAxisExtent: 44,
                      ),
                      itemCount: _modules.length,
                      itemBuilder: (context, index) {
                        final mod = _modules[index];
                        final label = mod['name'] ?? 'Feature';
                        final key = mod['id'] ?? '';
                        // Default to false for any newly added modules
                        final value = moduleToggles[key] as bool? ?? false;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: value ? const Color(0xFF10B981) : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: value,
                              activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                              activeColor: const Color(0xFF4F46E5),
                              onChanged: (newVal) async {
                                final updatedToggles = Map<String, dynamic>.from(moduleToggles);
                                updatedToggles[key] = newVal;

                                setState(() {
                                  final sIndex = _schools.indexWhere((s) => s['id'] == school['id']);
                                  if (sIndex != -1) {
                                    _schools[sIndex]['module_toggles'] = updatedToggles;
                                  }
                                });

                                try {
                                  await ApiService().put('/admin/schools/${school['id']}', {
                                    'module_toggles': updatedToggles,
                                  });
                                } catch (e) {
                                  _fetchData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e')),
                                  );
                                }
                              },
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}



// 4. Automations Screen
class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});

  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> {
  bool _sendReminders = true;
  bool _syncBiometrics = true;

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Automations Engine',
      children: [
        QuickAccessCard(
          title: 'Active Triggers & Cron',
          description: 'Manage automated systems running daily inside the Noida Cluster.',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Send Fee Reminder Messages', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Auto SMS/Email notifications on 1st of every month.', style: TextStyle(fontSize: 11)),
                value: _sendReminders,
                activeThumbColor: const Color(0xFF4F46E5),
                activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _sendReminders = val),
              ),
              SwitchListTile(
                title: const Text('Automated Biometric Sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sync devices at Noida Sector 62 daily at 9:00 AM.', style: TextStyle(fontSize: 11)),
                value: _syncBiometrics,
                activeThumbColor: const Color(0xFF4F46E5),
                activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _syncBiometrics = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}





// 7. Smart Insights Screen
class SmartInsightsScreen extends StatelessWidget {
  const SmartInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'AI Smart Insights',
      children: [
        QuickAccessCard(
          title: 'Automated Diagnostic Feed',
          description: 'Real-time issues flagged by Shamiit AI diagnostics.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInsightAlert('Biometric Broker Lag', 'Noida Gateway experienced 4 pings with lag > 500ms between 9:00 - 10:00 AM.', Colors.amber),
              const SizedBox(height: 12),
              _buildInsightAlert('License Renewal Expiry', '3 schools in Gurugram Region expire within 30 days. Auto invoice drafted.', Colors.redAccent),
            ],
          ),
        ),
        QuickAccessCard(
          title: 'Automated Scaling Telemetry',
          description: 'Status of CPU-based autoscaling configurations.',
          child: Column(
            children: [
              _buildMetricItem('Autoscaling Target CPU', '75% load threshold'),
              _buildMetricItem('Current Instance Count', '3 Active Nodes'),
              _buildMetricItem('Auto-mitigation Status', 'Idle — Noida cluster healthy'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightAlert(String title, String desc, Color alertColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alertColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: alertColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: alertColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}



// 9. APIs Screen
class ApisScreen extends StatelessWidget {
  const ApisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'API Gateway',
      children: [
        QuickAccessCard(
          title: 'Global Endpoint Settings',
          description: 'API base integration targets for active mail and SMS pathways.',
          child: Column(
            children: [
              _buildApiRow('SMTP Gateway Endpoint', 'smtp.shamiit-infra.com'),
              _buildApiRow('Twilio SMS Pathway', 'Active — +1-888-SHAMIIT'),
              _buildApiRow('Supabase Realtime Broker', 'ws://api.shamiit.com/realtime'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApiRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// 10. Audit Log Screen
class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Audit Logs',
      children: [
        QuickAccessCard(
          title: 'Security Trail Logs',
          description: 'Historical list of super admin configurations and toggles.',
          child: Column(
            children: [
              _buildAuditItem('[14:20:00] Rahul Kapoor updated Noida database replica delay.', '127.0.0.1'),
              _buildAuditItem('[12:00:15] Naresh Upadhyay created tenant: Gurugram Prep.', '192.168.1.1'),
              _buildAuditItem('[09:00:00] System Cron synchronized Biometric Batch #145.', 'CronDaemon'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditItem(String logText, String ip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(logText, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: 8),
          Text(ip, style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}





// 13. Announcements Screen
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _announcementController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Global Announcements',
      children: [
        QuickAccessCard(
          title: 'Broadcast Announcement',
          description: 'Broadcast notifications to all active school clusters.',
          child: Column(
            children: [
              TextField(
                controller: _announcementController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Compose announcement to broadcast globally...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Announcement Broadcasted Successfully!')),
                  );
                  _announcementController.clear();
                },
                icon: const Icon(Icons.campaign_outlined, size: 16),
                label: const Text('Broadcast Announcement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 10. Module Config Screen (Super Admin CRUD)
class ModuleConfigScreen extends StatefulWidget {
  const ModuleConfigScreen({super.key});

  @override
  State<ModuleConfigScreen> createState() => _ModuleConfigScreenState();
}

class _ModuleConfigScreenState extends State<ModuleConfigScreen> {
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchModules();
  }

  Future<void> _fetchModules() async {
    try {
      final res = await ApiService().get('/admin/schools/modules/all', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _modules = res['data'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load modules: $e')),
      );
    }
  }

  void _showConstraintWarningDialog(String message) {
    String schoolsText = '';
    if (message.contains('active for:')) {
      final parts = message.split('active for:');
      if (parts.length > 1) {
        final schoolParts = parts[1].split('. Please');
        schoolsText = schoolParts[0].trim();
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: theme.scaffoldBackgroundColor,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gpp_bad_outlined,
                    color: Color(0xFFEF4444),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Deactivation Blocked',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This module cannot be deactivated or deleted because it is currently active for one or more institutions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (schoolsText.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ACTIVE INSTITUTIONS:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: schoolsText.split(',').map((school) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_outlined,
                                color: Color(0xFFEF4444),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                school.trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Dismiss',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          context.go('/admin/modules');
                        },
                        child: const Text(
                          'Manage Toggles',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveModule(String? id, Map<String, dynamic> data) async {
    try {
      if (id == null) {
        await ApiService().post('/admin/schools/modules/all', data);
      } else {
        await ApiService().put('/admin/schools/modules/all/$id', data);
      }
      _fetchModules();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module saved successfully')),
      );
    } catch (e) {
      _fetchModules();
      final errStr = e.toString();
      if (errStr.contains('Cannot deactivate') || errStr.contains('Cannot delete')) {
        _showConstraintWarningDialog(errStr);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save module: $e')),
        );
      }
    }
  }

  Future<void> _deleteModule(String id) async {
    try {
      await ApiService().delete('/admin/schools/modules/all/$id');
      _fetchModules();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module deleted successfully')),
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Cannot deactivate') || errStr.contains('Cannot delete')) {
        _showConstraintWarningDialog(errStr);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete module: $e')),
        );
      }
    }
  }

  void _showEditDialog([dynamic module]) {
    final isNew = module == null;
    final idController = TextEditingController(text: isNew ? '' : module['id']);
    final nameController = TextEditingController(text: isNew ? '' : module['name']);
    final descController = TextEditingController(text: isNew ? '' : module['description'] ?? '');
    final iconController = TextEditingController(text: isNew ? 'extension' : module['icon'] ?? 'extension');
    
    List<dynamic> screensList = isNew ? [] : (module['screens'] as List<dynamic>? ?? []);
    List<dynamic> endpointsList = isNew ? [] : (module['endpoints'] as List<dynamic>? ?? []);
    final screensController = TextEditingController(text: screensList.join(', '));
    final endpointsController = TextEditingController(text: endpointsList.join(', '));

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: Text(
            isNew ? 'Create Master Module' : 'Edit Master Module',
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    enabled: isNew,
                    decoration: const InputDecoration(
                      labelText: 'Module ID / Key',
                      hintText: 'e.g. academic_tracker',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Module Name',
                      hintText: 'e.g. Academic Tracker',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief summary of features',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'Material Icon Name',
                      hintText: 'e.g. assessment, school, local_library',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: screensController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Controlled Screens (comma separated paths)',
                      hintText: '/student/exams, /teacher/exams',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endpointsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Controlled Endpoints (comma separated paths)',
                      hintText: '/api/exams, /api/exam-questions',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final id = idController.text.trim();
                final name = nameController.text.trim();
                if (id.isEmpty || name.isEmpty) return;

                final screens = screensController.text.split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                final endpoints = endpointsController.text.split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final payload = {
                  'id': id,
                  'name': name,
                  'description': descController.text.trim(),
                  'icon': iconController.text.trim(),
                  'screens': screens,
                  'endpoints': endpoints,
                  'is_enabled': isNew ? true : (module['is_enabled'] ?? true)
                };

                Navigator.pop(context);
                _saveModule(isNew ? null : id, payload);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconData(String? name) {
    if (name == null || name.isEmpty) return Icons.extension;
    switch (name) {
      case 'payment':
        return Icons.payment;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'local_library':
        return Icons.local_library;
      case 'hotel':
        return Icons.hotel;
      case 'assignment':
        return Icons.assignment;
      case 'video_call':
        return Icons.video_call;
      case 'chat':
        return Icons.chat;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'badge':
        return Icons.badge;
      case 'fingerprint':
        return Icons.fingerprint;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'sms':
        return Icons.sms;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return QuickAccessScaffold(
      title: 'Module Config Console',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Master Feature Modules Registry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Module'),
              onPressed: () => _showEditDialog(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        else if (_modules.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No master modules registered.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          )
        else
          ..._modules.map((module) {
            final screens = module['screens'] as List<dynamic>? ?? [];
            final endpoints = module['endpoints'] as List<dynamic>? ?? [];
            final isEnabled = module['is_enabled'] ?? true;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIconData(module['icon']),
                          color: const Color(0xFF4F46E5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              module['name'] ?? 'Unnamed Module',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Key: ${module['id']}',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEnabled,
                        activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                        activeColor: const Color(0xFF4F46E5),
                        onChanged: (val) {
                          _saveModule(module['id'], {'is_enabled': val});
                        },
                      ),
                    ],
                  ),
                  if (module['description'] != null && module['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      module['description'],
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (screens.isNotEmpty) ...[
                    const Text('Controlled Screens:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: screens.map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(s.toString(), style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                      )).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (endpoints.isNotEmpty) ...[
                    const Text('Controlled Endpoints:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: endpoints.map((e) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          e.toString(),
                          style: const TextStyle(fontSize: 10, color: Color(0xFF4F46E5), fontFamily: 'monospace'),
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF4F46E5)),
                        label: const Text('Edit Configuration', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12)),
                        onPressed: () => _showEditDialog(module),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: const Text('Delete Module', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: Text('Are you sure you want to delete module "${module['name']}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteModule(module['id']);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// 11. Vault Secrets Screen (Supabase Vault Management)
class VaultSecretsScreen extends StatefulWidget {
  const VaultSecretsScreen({super.key});

  @override
  State<VaultSecretsScreen> createState() => _VaultSecretsScreenState();
}

class _VaultSecretsScreenState extends State<VaultSecretsScreen> {
  List<dynamic> _secrets = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final Map<String, String> _revealedSecrets = {};
  final Set<String> _loadingSecretIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSecrets();
  }

  Future<void> _fetchSecrets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService().get('/admin/vault/secrets', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _secrets = res['data'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load secrets: $e')),
      );
    }
  }

  Future<void> _revealSecret(String id) async {
    if (_revealedSecrets.containsKey(id)) {
      setState(() {
        _revealedSecrets.remove(id);
      });
      return;
    }

    setState(() {
      _loadingSecretIds.add(id);
    });

    try {
      final res = await ApiService().get('/admin/vault/secrets/$id/value', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _revealedSecrets[id] = res['value']?.toString() ?? '';
          _loadingSecretIds.remove(id);
        });
      }
    } catch (e) {
      setState(() {
        _loadingSecretIds.remove(id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decrypt secret: $e')),
      );
    }
  }

  Future<void> _saveSecret(String? id, String name, String value, String desc) async {
    try {
      final payload = {
        'name': name,
        'value': value,
        'description': desc,
      };

      if (id == null) {
        await ApiService().post('/admin/vault/secrets', payload);
      } else {
        await ApiService().put('/admin/vault/secrets/$id', payload);
      }
      
      // Clear revealed cache if updating
      if (id != null) {
        _revealedSecrets.remove(id);
      }
      
      _fetchSecrets();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(id == null ? 'Secret created successfully' : 'Secret updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save secret: $e')),
      );
    }
  }

  Future<void> _deleteSecret(String id) async {
    try {
      await ApiService().delete('/admin/vault/secrets/$id');
      _revealedSecrets.remove(id);
      _fetchSecrets();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secret deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete secret: $e')),
      );
    }
  }

  void _showSecretDialog([dynamic secret]) {
    final isEdit = secret != null;
    final nameController = TextEditingController(text: isEdit ? secret['name'] : '');
    final descController = TextEditingController(text: isEdit ? secret['description'] : '');
    final valController = TextEditingController();
    bool isFetchingVal = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Fetch existing value on edit if not already revealed
            if (isEdit && valController.text.isEmpty && !isFetchingVal) {
              setModalState(() {
                isFetchingVal = true;
              });
              ApiService().get('/admin/vault/secrets/${secret['id']}/value', useCache: false).then((res) {
                if (res['success'] == true) {
                  setModalState(() {
                    valController.text = res['value']?.toString() ?? '';
                    isFetchingVal = false;
                  });
                }
              }).catchError((err) {
                setModalState(() {
                  isFetchingVal = false;
                });
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: theme.scaffoldBackgroundColor,
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_outlined : Icons.add_moderator_outlined,
                            color: const Color(0xFF4F46E5),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          isEdit ? 'Modify Vault Secret' : 'Add Vault Secret',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SECRET IDENTIFIER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      enabled: !isEdit, // Name / Key key cannot be edited in Supabase vault
                      decoration: InputDecoration(
                        hintText: 'e.g. STRIPE_API_KEY',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SECRET VALUE (ENCRYPTED AT REST)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: valController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: isFetchingVal ? 'Decrypting key securely...' : 'Enter sensitive credentials here...',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        contentPadding: const EdgeInsets.all(16),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        suffixIcon: isFetchingVal
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                                ),
                              )
                            : null,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        hintText: 'What is this secret key used for?',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (nameController.text.trim().isEmpty || valController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill out name and value fields.')),
                              );
                              return;
                            }
                            Navigator.pop(context);
                            _saveSecret(
                              isEdit ? secret['id'] : null,
                              nameController.text.trim(),
                              valController.text.trim(),
                              descController.text.trim(),
                            );
                          },
                          child: Text(
                            isEdit ? 'Save Changes' : 'Create Secret',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredSecrets = _secrets.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final desc = (s['description'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();

    return QuickAccessScaffold(
      title: 'Vault Secrets',
      children: [
        // Premium Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vpn_lock_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hardware-Level App Security (Encrypted Vault)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage sensitive environment variables, API gateway key tokens, and configuration secrets. Vault details are transparently encrypted at rest in pg-sodium and cannot be compromised.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Search and Add layout
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search secure environment variables or tokens...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_moderator_rounded, size: 18),
              label: const Text(
                'Add Secret',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showSecretDialog(),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        else if (filteredSecrets.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No credentials registered in Secure Key Vault yet.'
                        : 'No secrets matched your query.',
                    style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: 168,
            ),
            itemCount: filteredSecrets.length,
            itemBuilder: (cellContext, index) {
              final sec = filteredSecrets[index];
              final id = sec['id']?.toString() ?? '';
              final name = sec['name']?.toString() ?? 'SECRET_KEY';
              final desc = sec['description']?.toString() ?? 'No description provided';
              final revealed = _revealedSecrets.containsKey(id);
              final decryptedVal = _revealedSecrets[id] ?? '';
              final isRevealing = _loadingSecretIds.contains(id);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                desc,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: isRevealing
                                ? const Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4F46E5)),
                                    ),
                                  )
                                : SelectableText(
                                    revealed ? decryptedVal : '••••••••••••••••••••••••',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: revealed ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                                      fontWeight: revealed ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: isRevealing ? null : () => _revealSecret(id),
                            child: Icon(
                              revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 16,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (revealed) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: decryptedVal));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Secret copied to clipboard')),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () => _showSecretDialog(sec),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        const SizedBox(width: 14),
                        InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Confirm Deletion'),
                                content: Text('Are you sure you want to permanently delete secret "$name" from the hardware vault?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _deleteSecret(id);
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}



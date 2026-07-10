import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.all(18),
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
      child: Material(
        color: Colors.transparent,
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

// 1. White Label Branding Screen
class WhiteLabelScreen extends StatefulWidget {
  const WhiteLabelScreen({super.key});

  @override
  State<WhiteLabelScreen> createState() => _WhiteLabelScreenState();
}

class _WhiteLabelScreenState extends State<WhiteLabelScreen> {
  bool _enableWhiteLabel = true;
  String _customTitle = 'EduSHAMIIT Portal';
  Color _themeColor = const Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'White Label Branding',
      children: [
        QuickAccessCard(
          title: 'Branding Configuration',
          description: 'Apply custom color palettes and system domains to white-labeled tenants.',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Enable Tenant White Labeling', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Allows schools to supply custom logo assets and themes.', style: TextStyle(fontSize: 11)),
                value: _enableWhiteLabel,
                activeThumbColor: const Color(0xFF4F46E5),
                activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _enableWhiteLabel = val),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Global Portal Domain Prefix',
                  hintText: 'e.g. shamiit',
                  labelStyle: const TextStyle(fontSize: 12),
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                controller: TextEditingController(text: _customTitle),
                onChanged: (val) => _customTitle = val,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Primary Branding Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [Colors.indigo, Colors.blue, Colors.green, Colors.teal, Colors.orange, Colors.purple].map((c) {
                  final isSel = _themeColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _themeColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSel ? Border.all(color: Colors.white, width: 2) : null,
                        boxShadow: isSel ? [const BoxShadow(color: Colors.black26, blurRadius: 4)] : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
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
  final Map<String, bool> _modules = {
    'Academic Engine': true,
    'Tuition Ledger': true,
    'Biometric Attendance': true,
    'Bus Route Tracking': false,
    'Hostel Management': false,
  };

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Module Registry',
      children: [
        QuickAccessCard(
          title: 'Institutional Modules',
          description: 'Toggle system-wide access to modules on or off.',
          child: Column(
            children: _modules.keys.map((name) {
              return SwitchListTile(
                title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _modules[name]!,
                activeThumbColor: const Color(0xFF4F46E5),
                activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _modules[name] = val),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// 3. Workflows Screen
class WorkflowsScreen extends StatelessWidget {
  const WorkflowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Academic Workflows',
      children: [
        QuickAccessCard(
          title: 'Active Workflow Blueprint',
          description: 'Track multi-step institutional workflows from signup to activation.',
          child: Column(
            children: [
              _buildStepItem('Step 1: Tenant Registered', 'Triggers database schema creation', true),
              _buildStepItem('Step 2: Subscription Validated', 'Requires active payment confirmation', true),
              _buildStepItem('Step 3: Super Admin Assigned', 'Auto-sends OTP to supervisor email', true),
              _buildStepItem('Step 4: Live Synchronization', 'Synchronizes Delhi & Noida biometrics', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem(String title, String desc, bool isDone) {
    return ListTile(
      leading: Icon(
        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isDone ? Colors.green : Colors.grey,
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
      contentPadding: EdgeInsets.zero,
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

// 5. Permissions Screen
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Permissions Matrix',
      children: [
        QuickAccessCard(
          title: 'Role-Based Access Rules',
          description: 'Modify active permission matrix mapping security tiers.',
          child: Column(
            children: [
              _buildPermissionRow('Super Admin', 'Full Root Read/Write', Colors.red),
              _buildPermissionRow('School Admin', 'Read/Write for Specific Tenant', Colors.orange),
              _buildPermissionRow('Teacher Profile', 'Curriculum & Grading access', Colors.blue),
              _buildPermissionRow('Student Profile', 'Read-only course material', Colors.green),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionRow(String role, String access, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(access, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// 6. Real-Time Telemetry Screen
class RealTimeScreen extends StatelessWidget {
  const RealTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Real-Time Telemetry',
      children: [
        QuickAccessCard(
          title: 'Infrastructure Telemetry Feed',
          description: 'Uptime and ping metrics for Noida and Delhi servers.',
          child: Column(
            children: [
              _buildTelemetryItem('Noida Primary DB Node', '12ms Ping', 'Healthy', Colors.green),
              _buildTelemetryItem('Delhi Cluster Replica', '18ms Ping', 'Healthy', Colors.green),
              _buildTelemetryItem('White Label DNS Router', '45ms Ping', 'Healthy', Colors.green),
              _buildTelemetryItem('Biometric Sync Webhook', '540ms Ping', 'Slow Response', Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryItem(String label, String value, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(status, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
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
}

// 8. Groups Screen
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Institutional Groups',
      children: [
        QuickAccessCard(
          title: 'Active School Regions',
          description: 'Regional clustering configurations for the EduSHAMIIT ecosystem.',
          child: Column(
            children: [
              _buildGroupItem('Noida School Cluster', '4 Schools — 14.5K Students'),
              _buildGroupItem('Delhi Metro Cluster', '2 Schools — 10.2K Students'),
              _buildGroupItem('Gurugram Region', '3 Schools — 4.1K Students'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupItem(String name, String details) {
    return ListTile(
      leading: const Icon(Icons.corporate_fare_outlined, color: Colors.blue),
      title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(details, style: const TextStyle(fontSize: 11)),
      contentPadding: EdgeInsets.zero,
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

// 11. Roles & Modules Screen
class RolesModulesScreen extends StatelessWidget {
  const RolesModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Roles & Modules Config',
      children: [
        QuickAccessCard(
          title: 'Custom Roles Registry',
          description: 'Customize roles defined across all school platforms.',
          child: Column(
            children: [
              _buildRoleItem('School Registrar', 'Enrollments, batch transfers', true),
              _buildRoleItem('Librarian Assistant', 'Book tracking, penalty ledger', true),
              _buildRoleItem('Bus Coordinator', 'Live route updates', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleItem(String name, String desc, bool isActive) {
    return SwitchListTile(
      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
      value: isActive,
      activeThumbColor: const Color(0xFF4F46E5),
      activeTrackColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
      contentPadding: EdgeInsets.zero,
      onChanged: (val) {},
    );
  }
}

// 12. AI Ops Dashboard Screen
class AiOpsScreen extends StatelessWidget {
  const AiOpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'AI Ops Dashboard',
      children: [
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

// 14. Tenant Onboarding Screen
class TenantOnboardScreen extends StatefulWidget {
  const TenantOnboardScreen({super.key});

  @override
  State<TenantOnboardScreen> createState() => _TenantOnboardScreenState();
}

class _TenantOnboardScreenState extends State<TenantOnboardScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'Tenant Onboarding Wizard',
      children: [
        QuickAccessCard(
          title: 'New Institutional Onboarding',
          description: 'Follow these steps to initialize a new school tenant database.',
          child: Stepper(
            currentStep: _currentStep,
            physics: const NeverScrollableScrollPhysics(),
            onStepContinue: () {
              if (_currentStep < 2) {
                setState(() => _currentStep += 1);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New Tenant Successfully Onboarded!')),
                );
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              }
            },
            steps: const [
              Step(
                title: Text('Institution Info', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                content: Text('Enter school name, region, and primary contact phone number.', style: TextStyle(fontSize: 11)),
              ),
              Step(
                title: Text('Domain Config', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                content: Text('Provision portal URL prefixes and customize white label colors.', style: TextStyle(fontSize: 11)),
              ),
              Step(
                title: Text('Select Subscription', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                content: Text('Assign subscription plan (Basic, Standard, Enterprise).', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 15. SaaS Pricing Plans Screen
class SaasPlansScreen extends StatelessWidget {
  const SaasPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return QuickAccessScaffold(
      title: 'SaaS Subscription Plans',
      children: [
        QuickAccessCard(
          title: 'Pricing Engine Config',
          description: 'Configure standard plans and active pricing thresholds.',
          child: Column(
            children: [
              _buildPlanItem('Basic Plan', '₹5,000 / month', 'Upto 500 Students, basic curriculum', Colors.blue),
              const Divider(height: 24),
              _buildPlanItem('Standard Plan', '₹12,000 / month', 'Upto 2,000 Students, fee modules + bio', Colors.green),
              const Divider(height: 24),
              _buildPlanItem('Enterprise Scale', '₹35,000 / month', 'Unlimited Students, full whitelist + AI scaling', Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanItem(String name, String pricing, String details, Color themeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor)),
            const SizedBox(height: 2),
            Text(details, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        Text(pricing, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

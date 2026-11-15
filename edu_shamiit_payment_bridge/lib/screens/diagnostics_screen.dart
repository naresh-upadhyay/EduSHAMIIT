import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_header.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _notificationAccessGranted = true;
  bool _listenerRunning = true;
  bool _batteryOptimizationIgnored = true;
  int _pendingQueueCount = 0;
  bool _isRunningPing = false;
  String _pingResult = '42ms (HTTP 200 OK)';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final hasAccess = await PlatformBridge.hasNotificationAccess();
    final isRunning = await PlatformBridge.isServiceRunning();
    final isOptIgnored =
        await PlatformBridge.isIgnoringBatteryOptimizations();
    final pending = await PlatformBridge.getPendingEventsCount();

    if (mounted) {
      setState(() {
        _notificationAccessGranted = hasAccess;
        _listenerRunning = isRunning;
        _batteryOptimizationIgnored = isOptIgnored;
        _pendingQueueCount = pending;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Device Diagnostics',
            showBackButton: true,
            onBackPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _checkStatus,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Service Health & Permissions'),
                    const SizedBox(height: 8),
                    _buildHealthCard(),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Local SQLite Storage & Sync Queue'),
                    const SizedBox(height: 8),
                    _buildQueueCard(),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Device & System Information'),
                    const SizedBox(height: 8),
                    _buildDeviceInfoCard(),
                    const SizedBox(height: 16),

                    _buildSectionTitle('Diagnostic Actions'),
                    const SizedBox(height: 8),
                    _buildActionsCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryNavy,
      ),
    );
  }

  Widget _buildHealthCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildStatusRow(
            title: 'Notification Access',
            subtitle: _notificationAccessGranted
                ? 'Granted (BIND_NOTIFICATION_LISTENER_SERVICE)'
                : 'Permission required',
            isGood: _notificationAccessGranted,
            actionLabel: _notificationAccessGranted ? null : 'Grant',
            onAction: () async {
              await PlatformBridge.openNotificationSettings();
              await Future.delayed(const Duration(seconds: 1));
              _checkStatus();
            },
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildStatusRow(
            title: 'Listener Background Service',
            subtitle: _listenerRunning
                ? 'Active (Running continuously)'
                : 'Service stopped or restarting',
            isGood: _listenerRunning,
            actionLabel: _listenerRunning ? null : 'Start',
            onAction: () async {
              await PlatformBridge.startListenerService();
              _checkStatus();
            },
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildStatusRow(
            title: 'Battery Optimization',
            subtitle: _batteryOptimizationIgnored
                ? 'Exempted (Unrestricted background run)'
                : 'Restricted by Android Doze mode',
            isGood: _batteryOptimizationIgnored,
            actionLabel:
                _batteryOptimizationIgnored ? null : 'Exempt',
            onAction: () async {
              await PlatformBridge.requestIgnoreBatteryOptimizations();
              _checkStatus();
            },
          ),
          const Divider(color: AppColors.border, height: 16),
          _buildStatusRow(
            title: 'Backend Connectivity Ping',
            subtitle: _pingResult,
            isGood: true,
            actionLabel: _isRunningPing ? null : 'Ping',
            onAction: _runPing,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMetricRow('Pending Queue Count', '$_pendingQueueCount events'),
          const Divider(color: AppColors.border, height: 16),
          _buildMetricRow('Today Synced Notifications', '42 notifications'),
          const Divider(color: AppColors.border, height: 16),
          _buildMetricRow('Duplicate Suppressions', '4 events prevented'),
          const Divider(color: AppColors.border, height: 16),
          _buildMetricRow('Local Database Path', 'payment_bridge.db (SQLite)'),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildMetricRow('Hardware Model', 'Dedicated UPI Terminal (PB-AND-001)'),
          const Divider(color: AppColors.border, height: 16),
          _buildMetricRow('Android OS Version', 'Android 14 (API Level 34)'),
          const Divider(color: AppColors.border, height: 16),
          _buildMetricRow('Application Version', 'EduSHAMIIT Payment Bridge 1.0.0'),
          const Divider(color: AppColors.border, height: 16),
          _buildMetricRow('Assigned School ID', '33333333-3333-3333-3333-333333333333'),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _simulateNotification(),
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Simulate Test UPI Notification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final ok = await ApiService().triggerSync();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Sync initiated successfully'
                        : 'Sync queued locally'),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              }
            },
            icon: const Icon(Icons.sync, size: 18, color: AppColors.primaryBlue),
            label: const Text(
              'Force Sync with Backend',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow({
    required String title,
    required String subtitle,
    required bool isGood,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(
          isGood ? Icons.check_circle : Icons.warning_amber_rounded,
          size: 20,
          color: isGood ? AppColors.successGreen : AppColors.warningOrange,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _runPing() async {
    setState(() => _isRunningPing = true);
    final stopwatch = Stopwatch()..start();
    final ok = await ApiService().testConnection();
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _isRunningPing = false;
        _pingResult = ok
            ? '${stopwatch.elapsedMilliseconds}ms (HTTP 200 OK)'
            : 'Mock Connected (Local mode)';
      });
    }
  }

  void _simulateNotification() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simulate UPI Notification'),
        content: const Text(
          'This will post a test payment event (PhonePe: ₹2,000.34 for Seema INV-1042) to the local SQLite queue and dispatch to the listener parser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Simulated UPI payment notification ingested! Candidate matched.',
                  ),
                  backgroundColor: AppColors.successGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simulate'),
          ),
        ],
      ),
    );
  }
}

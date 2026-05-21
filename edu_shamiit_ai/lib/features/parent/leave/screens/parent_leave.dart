import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/child_switcher.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentLeave extends ConsumerStatefulWidget {
  const ParentLeave({super.key});

  @override
  ConsumerState<ParentLeave> createState() => _ParentLeaveState();
}

class _ParentLeaveState extends ConsumerState<ParentLeave> {
  final _reasonController = TextEditingController();
  String _selectedLeaveType = 'Sick Leave';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;

  final List<String> _leaveTypes = [
    'Sick Leave',
    'Casual Leave',
    'Urgent Work',
    'Family Event'
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final leaveAsync = ref.watch(parentLeaveProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Leave Management'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const ChildSwitcher(),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: leaveAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyDialog(context, isDark),
        backgroundColor: ParentColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Apply Leave'.tr(ref),
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final applications = data['applications'] as List<dynamic>? ?? [];
    final balance = data['balance'] as int? ?? 15;
    final used = data['used'] as int? ?? 0;
    final pending = data['pending'] as int? ?? 0;

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 80),
        children: [
          // ── Leave Balance Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _balanceItem('Balance'.tr(ref), balance, Colors.white),
                _balanceItem('Used'.tr(ref), used, Colors.greenAccent),
                _balanceItem('Pending'.tr(ref), pending, Colors.orangeAccent),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Applications ──
          Text(
            'Leave History'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),

          if (applications.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No leave applications'.tr(ref),
                  style: TextStyle(
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3),
                ),
              ),
            )
          else
            ...applications.map((a) {
              final app = a as Map<String, dynamic>;
              return _buildLeaveCard(app, isDark);
            }),
        ],
      ),
    );
  }

  Widget _balanceItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> app, bool isDark) {
    final type = app['leave_type'] ?? 'Leave';
    final startDate = app['start_date'] ?? '';
    final endDate = app['end_date'] ?? '';
    final reason = app['reason'] ?? '';
    final status = app['status'] ?? 'pending';

    final statusColor = status == 'approved'
        ? ParentColors.success
        : status == 'rejected'
            ? ParentColors.error
            : ParentColors.warning;
    final statusBg = status == 'approved'
        ? ParentColors.successBg
        : status == 'rejected'
            ? ParentColors.errorBg
            : ParentColors.warningBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                _getLeaveIcon(type),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                Text(
                  '$startDate → $endDate',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? statusColor.withValues(alpha: 0.2) : statusBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  String _getLeaveIcon(String type) {
    switch (type) {
      case 'Sick Leave':
        return '🤒';
      case 'Casual Leave':
        return '🏖️';
      case 'Urgent Work':
        return '⚡';
      case 'Family Event':
        return '👨‍👩‍👧';
      default:
        return '📋';
    }
  }

  void _showApplyDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Apply Leave'.tr(ref),
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),

              // Leave Type
              DropdownButtonFormField<String>(
                initialValue: _selectedLeaveType,
                decoration: InputDecoration(
                  labelText: 'Leave Type'.tr(ref),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _leaveTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setModalState(() => _selectedLeaveType = v!),
              ),
              const SizedBox(height: 12),

              // Start Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_startDate == null
                    ? 'Select Start Date'.tr(ref)
                    : 'Start: ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setModalState(() => _startDate = date);
                },
              ),

              // End Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_endDate == null
                    ? 'Select End Date'.tr(ref)
                    : 'End: ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setModalState(() => _endDate = date);
                },
              ),
              const SizedBox(height: 12),

              // Reason
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason'.tr(ref),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitLeave(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParentColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Submit Application'.tr(ref),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitLeave(BuildContext context) async {
    if (_startDate == null ||
        _endDate == null ||
        _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields'.tr(ref))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final selectedChildId = ref.read(selectedChildProvider);
      await ApiService().post('/parent/leave/apply', {
        'student_id': selectedChildId,
        'leave_type': _selectedLeaveType,
        'start_date': _startDate!.toIso8601String().split('T')[0],
        'end_date': _endDate!.toIso8601String().split('T')[0],
        'reason': _reasonController.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Leave application submitted'.tr(ref))),
        );
        ref.invalidate(parentLeaveProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load leave data'.tr(ref),
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentLeaveProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

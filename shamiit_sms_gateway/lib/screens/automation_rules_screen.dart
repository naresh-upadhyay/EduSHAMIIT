import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class AutomationRulesScreen extends StatefulWidget {
  const AutomationRulesScreen({super.key});

  @override
  State<AutomationRulesScreen> createState() => _AutomationRulesScreenState();
}

class _AutomationRulesScreenState extends State<AutomationRulesScreen> {
  bool _isLoading = true;
  String? _error;
  List<AutomationRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ApiService().getAutomationRules();
      if (mounted) {
        setState(() {
          _rules = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _openEditor({AutomationRule? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.ruleName ?? '');
    final appCtrl = TextEditingController(text: existing?.applicationName ?? 'EduSHAMIIT');
    final triggerCtrl = TextEditingController(text: existing?.triggerEvent ?? 'Student absent');
    final mapCtrl = TextEditingController(text: existing?.recipientMapping ?? 'parent_phone');
    final bodyCtrl = TextEditingController(
      text: existing?.messageTemplate ??
          'Dear {parent_name}, {student_name} was marked absent today at {school_name}.',
    );
    final webhookCtrl = TextEditingController(text: existing?.webhookUrl ?? '');
    String priority = existing?.priority ?? 'NORMAL';
    int? simSlot = existing?.preferredSimSlot;
    bool isActive = existing?.isActive ?? true;
    bool saving = false;

    final saved = await showAppBottomSheet<bool>(
      context: context,
      icon: Icons.auto_awesome_rounded,
      iconColor: AppColors.purple,
      title: existing == null ? 'New Automation Rule' : 'Edit Automation Rule',
      subtitle: 'Configure trigger event, template & routing',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Rule Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: appCtrl,
                    decoration: const InputDecoration(labelText: 'Application'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: triggerCtrl,
                    decoration: const InputDecoration(labelText: 'Trigger Event'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mapCtrl,
              decoration: const InputDecoration(labelText: 'Recipient Mapping Field'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message Template (with {variables})',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: webhookCtrl,
              decoration: const InputDecoration(
                labelText: 'Webhook URL (Inbound Forwarding)',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: simSlot,
                    decoration: const InputDecoration(labelText: 'Preferred SIM'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Default SIM')),
                      DropdownMenuItem(value: 0, child: Text('SIM 1')),
                      DropdownMenuItem(value: 1, child: Text('SIM 2')),
                    ],
                    onChanged: (v) => setSheet(() => simSlot = v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                      DropdownMenuItem(value: 'HIGH', child: Text('High')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                    ],
                    onChanged: (v) => setSheet(() => priority = v ?? 'NORMAL'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            StatusCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rule Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                value: isActive,
                onChanged: (v) => setSheet(() => isActive = v),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Rule name and message template are required'),
                                  backgroundColor: AppColors.errorRed,
                                ),
                              );
                              return;
                            }
                            setSheet(() => saving = true);
                            await ApiService().saveAutomationRule(
                              id: existing?.id,
                              payload: {
                                'rule_name': nameCtrl.text.trim(),
                                'application_name': appCtrl.text.trim(),
                                'trigger_event': triggerCtrl.text.trim(),
                                'recipient_mapping': mapCtrl.text.trim(),
                                'message_template': bodyCtrl.text.trim(),
                                'preferred_sim_slot': simSlot,
                                'priority': priority,
                                'is_active': isActive,
                                'webhook_url': webhookCtrl.text.trim().isEmpty ? null : webhookCtrl.text.trim(),
                              },
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(saving ? 'Saving...' : 'Save Rule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _testRule(AutomationRule rule) async {
    final vars = <String, TextEditingController>{};
    final regex = RegExp(r'\{([a-zA-Z0-9_]+)\}');
    for (final m in regex.allMatches(rule.messageTemplate)) {
      final k = m.group(1)!;
      vars.putIfAbsent(k, () => TextEditingController(text: k));
    }
    final phoneCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AppDialogFrame(
        icon: Icons.play_circle_outline_rounded,
        iconColor: AppColors.primaryBlue,
        title: 'Test Rule',
        subtitle: rule.ruleName,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Optional Test Recipient (+91...)',
                hintText: 'Leave empty for dry-run render',
              ),
            ),
            ...vars.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: e.value,
                  decoration: InputDecoration(labelText: 'Variable {${e.key}}'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Run Test'),
            onPressed: () async {
              try {
                final res = await ApiService().testAutomationRule(
                  rule.id,
                  recipientNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  variables: vars.map((k, v) => MapEntry(k, v.text)),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rendered: ${res['rendered_message']}'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Test failed: $e'), backgroundColor: AppColors.errorRed),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showExecutions(AutomationRule rule) async {
    final execs = await ApiService().getRuleExecutions(rule.id);
    if (!mounted) return;
    showAppBottomSheet(
      context: context,
      icon: Icons.history_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'Execution History',
      subtitle: rule.ruleName,
      builder: (_) => execs.isEmpty
          ? const EmptyState(
              icon: Icons.history_toggle_off_rounded,
              title: 'No Executions Yet',
              subtitle: 'Triggered runs and test executions will appear here.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: execs
                  .map(
                    (ex) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: StatusCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (ex['recipient_number'] ?? 'Dry Run').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${ex['executed_at'] ?? ''}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: (ex['status'] ?? 'DONE').toString()),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Rule'),
      ),
      body: SkyHeaderContainer(
        child: Column(
          children: [
            AppTopBar(
              title: 'Automation Rules',
              showBackButton: true,
              actions: [
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Loading automation rules...')
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : _rules.isEmpty
                          ? EmptyState(
                              icon: Icons.auto_awesome_outlined,
                              title: 'No Automation Rules Configured',
                              subtitle:
                                  'Create rules for EduSHAMIIT, Apna School, SHAMIIT CRM, Meri GYM, or incoming SMS webhooks.',
                              action: ElevatedButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create First Rule'),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 84),
                              itemCount: _rules.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final r = _rules[idx];
                                return StatusCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              r.ruleName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(status: r.isActive ? 'ACTIVE' : 'PAUSED'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${r.applicationName} • Trigger: ${r.triggerEvent}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        r.messageTemplate,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _RuleActionPill(
                                            icon: r.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                            label: r.isActive ? 'Pause' : 'Activate',
                                            color: r.isActive ? AppColors.warningOrange : AppColors.successGreen,
                                            onTap: () async {
                                              await ApiService().saveAutomationRule(
                                                id: r.id,
                                                payload: {
                                                  'rule_name': r.ruleName,
                                                  'application_name': r.applicationName,
                                                  'trigger_event': r.triggerEvent,
                                                  'recipient_mapping': r.recipientMapping,
                                                  'message_template': r.messageTemplate,
                                                  'preferred_sim_slot': r.preferredSimSlot,
                                                  'priority': r.priority,
                                                  'is_active': !r.isActive,
                                                  'webhook_url': r.webhookUrl,
                                                },
                                              );
                                              _load();
                                            },
                                          ),
                                          _RuleActionPill(
                                            icon: Icons.edit_outlined,
                                            label: 'Edit',
                                            color: AppColors.primaryBlue,
                                            onTap: () => _openEditor(existing: r),
                                          ),
                                          _RuleActionPill(
                                            icon: Icons.copy_rounded,
                                            label: 'Duplicate',
                                            color: AppColors.purple,
                                            onTap: () async {
                                              await ApiService().duplicateAutomationRule(r.id);
                                              _load();
                                            },
                                          ),
                                          _RuleActionPill(
                                            icon: Icons.bolt_rounded,
                                            label: 'Test',
                                            color: AppColors.primaryBlue,
                                            onTap: () => _testRule(r),
                                          ),
                                          _RuleActionPill(
                                            icon: Icons.history_rounded,
                                            label: 'History (${r.executionCount})',
                                            color: AppColors.secondaryText,
                                            onTap: () => _showExecutions(r),
                                          ),
                                          _RuleActionPill(
                                            icon: Icons.delete_outline_rounded,
                                            label: 'Delete',
                                            color: AppColors.errorRed,
                                            onTap: () async {
                                              final ok = await showConfirmationDialog(
                                                context,
                                                title: 'Delete Rule',
                                                message: 'Delete "${r.ruleName}"?',
                                                confirmLabel: 'Delete',
                                                confirmColor: AppColors.errorRed,
                                              );
                                              if (ok) {
                                                await ApiService().deleteAutomationRule(r.id);
                                                _load();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RuleActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? color.withValues(alpha: 0.14) : color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

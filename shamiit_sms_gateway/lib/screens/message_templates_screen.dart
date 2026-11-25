import 'package:flutter/material.dart';
import '../core/sms_utils.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  bool _isLoading = true;
  String? _error;
  List<MessageTemplate> _templates = [];

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
      final list = await ApiService().getTemplates();
      if (mounted) {
        setState(() {
          _templates = list;
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

  Future<void> _openEditor({MessageTemplate? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.templateName ?? '');
    final appCtrl = TextEditingController(text: existing?.applicationName ?? 'EduSHAMIIT');
    final catCtrl = TextEditingController(text: existing?.category ?? 'Fee Reminder');
    final bodyCtrl = TextEditingController(
      text: existing?.messageBody ??
          'Dear {parent_name}, fee of INR {amount} for {student_name} is due on {due_date}. Regards, {school_name}.',
    );
    final dltIdCtrl = TextEditingController(text: existing?.dltTemplateId ?? '');
    final dltHeaderCtrl = TextEditingController(text: existing?.dltHeader ?? '');
    String priority = existing?.defaultPriority ?? 'NORMAL';
    bool active = existing?.isActive ?? true;
    bool saving = false;

    final saved = await showAppBottomSheet<bool>(
      context: context,
      icon: Icons.description_outlined,
      iconColor: AppColors.primaryBlue,
      title: existing == null ? 'Create SMS Template' : 'Edit SMS Template',
      subtitle: 'Supports dynamic {variables} and India DLT headers',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final detectedVars = SmsUtils.extractTemplateVariables(bodyCtrl.text);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Template Name'),
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
                      controller: catCtrl,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                onChanged: (_) => setSheet(() {}),
                decoration: const InputDecoration(
                  labelText: 'Message Body',
                  hintText: 'Supports {student_name}, {parent_name}, {amount}...',
                  alignLabelWithHint: true,
                ),
              ),
              if (detectedVars.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: detectedVars
                      .map(
                        (v) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '{$v}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dltIdCtrl,
                      decoration: const InputDecoration(labelText: 'DLT Template ID'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: dltHeaderCtrl,
                      decoration: const InputDecoration(labelText: 'DLT Header'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Default Priority'),
                items: const [
                  DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                ],
                onChanged: (v) => setSheet(() => priority = v ?? 'NORMAL'),
              ),
              const SizedBox(height: 10),
              StatusCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Template Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  value: active,
                  onChanged: (v) => setSheet(() => active = v),
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
                                    content: Text('Template name and body are required'),
                                    backgroundColor: AppColors.errorRed,
                                  ),
                                );
                                return;
                              }
                              setSheet(() => saving = true);
                              await ApiService().saveTemplate(
                                id: existing?.id,
                                payload: {
                                  'template_name': nameCtrl.text.trim(),
                                  'application_name': appCtrl.text.trim(),
                                  'category': catCtrl.text.trim(),
                                  'message_body': bodyCtrl.text.trim(),
                                  'dlt_template_id': dltIdCtrl.text.trim().isEmpty ? null : dltIdCtrl.text.trim(),
                                  'dlt_header': dltHeaderCtrl.text.trim().isEmpty ? null : dltHeaderCtrl.text.trim(),
                                  'default_priority': priority,
                                  'is_active': active,
                                },
                              );
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(saving ? 'Saving...' : 'Save Template'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) _load();
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
        label: const Text('New Template'),
      ),
      body: SkyHeaderContainer(
        child: Column(
          children: [
            AppTopBar(
              title: 'Message Templates',
              showBackButton: true,
              actions: [
                IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Loading templates...')
                  : _error != null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : _templates.isEmpty
                          ? EmptyState(
                              icon: Icons.description_outlined,
                              title: 'No Templates Created',
                              subtitle:
                                  'Create DLT-ready templates with {student_name}, {parent_name}, {amount}, {due_date} placeholders.',
                              action: ElevatedButton.icon(
                                onPressed: () => _openEditor(),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create Template'),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 84),
                              itemCount: _templates.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, idx) {
                                final t = _templates[idx];
                                return StatusCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              t.templateName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          StatusBadge(status: t.isActive ? 'ACTIVE' : 'PAUSED'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${t.applicationName} • ${t.category}${t.dltTemplateId != null ? ' • DLT: ${t.dltTemplateId}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        t.messageBody,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          TextButton.icon(
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            label: const Text('Edit'),
                                            onPressed: () => _openEditor(existing: t),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed),
                                            label: const Text('Delete', style: TextStyle(color: AppColors.errorRed)),
                                            onPressed: () async {
                                              final ok = await showConfirmationDialog(
                                                context,
                                                title: 'Delete Template',
                                                message: 'Delete template "${t.templateName}"?',
                                                confirmLabel: 'Delete',
                                                confirmColor: AppColors.errorRed,
                                              );
                                              if (ok) {
                                                await ApiService().deleteTemplate(t.id);
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

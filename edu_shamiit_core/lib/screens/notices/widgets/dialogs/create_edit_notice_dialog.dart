import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/notice_models.dart';
import '../../providers/notice_provider.dart';

class CreateEditNoticeDialog extends ConsumerStatefulWidget {
  final NoticeModel? editNotice;
  final bool isTemplate;

  const CreateEditNoticeDialog({
    super.key,
    this.editNotice,
    this.isTemplate = false,
  });

  @override
  ConsumerState<CreateEditNoticeDialog> createState() => _CreateEditNoticeDialogState();
}

class _CreateEditNoticeDialogState extends ConsumerState<CreateEditNoticeDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _category;
  late String _priority;
  late String _targetScope;
  late Set<String> _targetRoles;
  late Set<String> _targetClasses;
  late Set<String> _notificationChannels;

  DateTime? _scheduledAt;
  DateTime? _expiresAt;
  bool _requiresAck = false;
  DateTime? _ackDeadline;
  bool _isPinned = false;
  bool _isUrgent = false;
  final bool _sendImmediately = true;
  bool _isSubmitting = false;

  final List<NoticeAttachmentModel> _attachments = [];
  final List<NoticeLinkModel> _links = [];

  @override
  void initState() {
    super.initState();
    final n = widget.editNotice;
    _titleController = TextEditingController(text: n?.title ?? (widget.isTemplate ? 'Holiday Announcement - [Occasion]' : ''));
    _contentController = TextEditingController(text: n?.content ?? (widget.isTemplate ? 'Dear Students and Parents,\n\nPlease be informed that the school will remain closed on [Date] on account of [Occasion]. Normal classes will resume on [Date].' : ''));
    _category = n?.category ?? 'General';
    _priority = n?.priority ?? 'normal';
    _isUrgent = (n?.isUrgent == true) || (n?.priority == 'urgent');
    if (_isUrgent) _priority = 'urgent';
    _targetScope = n?.targetScope ?? 'entire_institute';
    _targetRoles = Set<String>.from(n?.targetRoles ?? []);
    _targetClasses = Set<String>.from(n?.targetClasses ?? []);
    _notificationChannels = Set<String>.from(n?.notificationChannels ?? ['in_app']);
    _scheduledAt = n?.scheduledAt;
    _expiresAt = n?.expiresAt;
    _requiresAck = n?.requiresAcknowledgement ?? false;
    _ackDeadline = n?.acknowledgementDeadline;
    _isPinned = n?.isPinned ?? false;

    if (n != null) {
      _attachments.addAll(n.attachments);
      _links.addAll(n.links);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit({String status = 'published'}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final effectivePriority = _isUrgent ? 'urgent' : _priority;
    final payload = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _category,
      'priority': effectivePriority,
      'status': status,
      'target_scope': _targetScope,
      'target_roles': _targetRoles.toList(),
      'target_classes': _targetClasses.toList(),
      'target_departments': [],
      'target_user_ids': [],
      'timezone': 'Asia/Kolkata',
      if (_scheduledAt != null) 'scheduled_at': _scheduledAt!.toUtc().toIso8601String(),
      if (_expiresAt != null) 'expires_at': _expiresAt!.toUtc().toIso8601String(),
      'requires_acknowledgement': _requiresAck,
      if (_ackDeadline != null) 'acknowledgement_deadline': _ackDeadline!.toUtc().toIso8601String(),
      'notification_channels': _notificationChannels.toList(),
      'send_notification_immediately': _sendImmediately,
      'attachments': _attachments.map((e) => e.toJson()).toList(),
      'links': _links.map((e) => e.toJson()).toList(),
      'is_pinned': _isPinned,
      'is_urgent': _isUrgent,
    };

    try {
      final api = ref.read(noticeApiServiceProvider);
      if (widget.editNotice != null) {
        await api.updateNotice(widget.editNotice!.id, payload);
      } else {
        await api.createNotice(payload);
      }

      await ref.read(noticeProvider.notifier).refreshAll();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notice ${widget.editNotice != null ? "updated" : "saved"} successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noticeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final categories = state.categories.isNotEmpty
        ? state.categories.map((c) => c.name).toList()
        : ['General', 'Academic', 'Examination', 'Event', 'Holiday', 'Meeting', 'Transport', 'Fee & Accounts', 'Emergency'];
    final availableRoles = state.roles.isNotEmpty
        ? state.roles
        : ['student', 'teacher', 'parent', 'staff', 'driver', 'accountant', 'librarian', 'principal', 'admin', 'super_admin'];
    final availableClasses = state.classes.isNotEmpty
        ? state.classes
        : ['Class 10A', 'Class 10B', 'Class 9A', 'Class 9B', 'Class 8A', 'Class 8B', 'Class 7', 'Class 6'];

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.editNotice != null ? 'Edit Notice' : (widget.isTemplate ? 'Notice from Template' : 'Create Notice / Circular'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Target the entire institute, specific roles, or classes.',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Section 1: Basic Information
                    _buildSectionHeader('1. Basic Information', isDark),
                    const SizedBox(height: 12),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                      decoration: _inputDecoration('Notice Title *', 'e.g., Parent Teacher Meeting Schedule', isDark),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    // Category and Priority in Row
                    if (isMobile) ...[
                      DropdownButtonFormField<String>(
                        initialValue: categories.contains(_category) ? _category : (categories.isNotEmpty ? categories.first : 'General'),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                        decoration: _inputDecoration('Category', '', isDark),
                        items: categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                        decoration: _inputDecoration('Priority', '', isDark),
                        items: const ['low', 'normal', 'high', 'urgent'].map((p) {
                          return DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 12)));
                        }).toList(),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: categories.contains(_category) ? _category : (categories.isNotEmpty ? categories.first : 'General'),
                              onChanged: (val) {
                                if (val != null) setState(() => _category = val);
                              },
                              decoration: _inputDecoration('Category', '', isDark),
                              items: categories.map((c) {
                                return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)));
                              }).toList(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _priority,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _priority = val;
                                    _isUrgent = (val == 'urgent');
                                  });
                                }
                              },
                              decoration: _inputDecoration('Priority', '', isDark),
                              items: const ['low', 'normal', 'high', 'urgent'].map((p) {
                                return DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 12)));
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Section 2: Rich Content & Body
                    _buildSectionHeader('2. Content & Details', isDark),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 5,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Content cannot be empty' : null,
                      decoration: _inputDecoration('Notice Body / Circular Content *', 'Write the full notice announcement details here...', isDark),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // Section 3: Target Audience
                    _buildSectionHeader('3. Target Audience', isDark),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildAudienceChoice('entire_institute', 'Entire School', Icons.school_rounded, isDark),
                        _buildAudienceChoice('roles', 'Specific Roles', Icons.group_rounded, isDark),
                        _buildAudienceChoice('classes', 'Specific Classes', Icons.class_rounded, isDark),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // If Roles selected
                    if (_targetScope == 'roles') ...[
                      Text('Select Target Roles:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableRoles.map((role) {
                          final isSelected = _targetRoles.contains(role);
                          return FilterChip(
                            label: Text(role.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            selected: isSelected,
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _targetRoles.add(role);
                                } else {
                                  _targetRoles.remove(role);
                                }
                              });
                            },
                            selectedColor: const Color(0xFF4F46E5).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF4F46E5),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // If Classes selected
                    if (_targetScope == 'classes') ...[
                      Text('Select Target Classes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: availableClasses.map((cls) {
                          final isSelected = _targetClasses.contains(cls);
                          return FilterChip(
                            label: Text(cls, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            selected: isSelected,
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _targetClasses.add(cls);
                                } else {
                                  _targetClasses.remove(cls);
                                }
                              });
                            },
                            selectedColor: const Color(0xFF0EA5E9).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF0EA5E9),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),

                    // Section 4: Publication & Scheduling
                    _buildSectionHeader('4. Publication & Expiry', isDark),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Scheduled At
                        SizedBox(
                          width: isMobile ? double.infinity : 320,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final dt = await showDatePicker(
                                context: context,
                                initialDate: _scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (dt != null) {
                                final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                                if (time != null) {
                                  setState(() {
                                    _scheduledAt = DateTime(dt.year, dt.month, dt.day, time.hour, time.minute);
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.schedule_rounded, size: 16),
                            label: Text(
                              _scheduledAt != null ? 'Schedule: ${DateFormat("dd MMM, hh:mm a").format(_scheduledAt!)}' : 'Schedule for Later (Optional)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),

                        // Expires At
                        SizedBox(
                          width: isMobile ? double.infinity : 320,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final dt = await showDatePicker(
                                context: context,
                                initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (dt != null) {
                                setState(() => _expiresAt = dt);
                              }
                            },
                            icon: const Icon(Icons.timer_off_outlined, size: 16),
                            label: Text(
                              _expiresAt != null ? 'Expires: ${DateFormat("dd MMM yyyy").format(_expiresAt!)}' : 'Set Expiration Date (Optional)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section 5: Acknowledgement & Flags
                    _buildSectionHeader('5. Interaction & Urgent Settings', isDark),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Require Recipient Acknowledgement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: const Text('Recipients must click "Acknowledge" to confirm they have read this notice.', style: TextStyle(fontSize: 11)),
                      value: _requiresAck,
                      onChanged: (val) => setState(() => _requiresAck = val),
                      activeColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Pin Notice to Top of List', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      value: _isPinned,
                      onChanged: (val) => setState(() => _isPinned = val),
                      activeColor: const Color(0xFFF59E0B),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Mark as Urgent Announcement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      value: _isUrgent,
                      onChanged: (val) {
                        setState(() {
                          _isUrgent = val;
                          if (val) {
                            _priority = 'urgent';
                          } else if (_priority == 'urgent') {
                            _priority = 'normal';
                          }
                        });
                      },
                      activeColor: const Color(0xFFEF4444),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _handleSubmit(status: 'draft'),
                    child: const Text('Save Draft'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _handleSubmit(status: _scheduledAt != null ? 'scheduled' : 'published'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_scheduledAt != null ? 'Schedule Notice' : 'Publish Notice'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
      ),
    );
  }

  Widget _buildAudienceChoice(String scope, String label, IconData icon, bool isDark) {
    final isSelected = _targetScope == scope;
    return InkWell(
      onTap: () => setState(() => _targetScope = scope),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? (isDark ? Colors.white : const Color(0xFF4F46E5)) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, bool isDark) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

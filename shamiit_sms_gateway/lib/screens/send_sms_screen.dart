import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/platform_bridge.dart';
import '../core/sms_utils.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class SendSmsScreen extends StatefulWidget {
  const SendSmsScreen({super.key});

  @override
  State<SendSmsScreen> createState() => _SendSmsScreenState();
}

class _SendSmsScreenState extends State<SendSmsScreen> {
  int _activeTab = 0; // 0: Compose, 1: Templates, 2: Contacts
  final _recipientInputCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _appSourceCtrl = TextEditingController(text: 'SMS Gateway App');
  final _referenceCtrl = TextEditingController();
  final _contactSearchCtrl = TextEditingController();

  final List<String> _recipients = [];
  List<SimInfo> _sims = [];
  List<MessageTemplate> _templates = [];
  List<Map<String, String>> _contacts = [];
  bool _contactsLoaded = false;

  int? _selectedSubId;
  String _priority = 'NORMAL';
  bool _isScheduled = false;
  DateTime? _scheduledDateTime;
  bool _requestDeliveryReport = true;
  int _expirationHours = 24;
  String? _selectedTemplateId;
  bool _isSending = false;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _recipientInputCtrl.dispose();
    _messageCtrl.dispose();
    _appSourceCtrl.dispose();
    _referenceCtrl.dispose();
    _contactSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final simCfg = await ApiService().getSimConfiguration();
      final sims = (simCfg['sims'] as List<SimInfo>?) ?? [];
      List<MessageTemplate> tpls = [];
      try {
        tpls = await ApiService().getTemplates();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _sims = sims;
        _templates = tpls;
        final sendable = sims.where((s) => s.canSend).firstOrNull;
        _selectedSubId = sendable?.subscriptionId ?? (sims.isNotEmpty ? sims.first.subscriptionId : null);
      });
    } catch (_) {}
  }

  void _addRecipientFromField() {
    final raw = _recipientInputCtrl.text.trim();
    if (raw.isEmpty) return;
    final parsed = SmsUtils.parseMultiplePhones(raw);
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid phone number. Enter Indian 10-digit or E.164 (+91...) format.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    setState(() {
      for (final p in parsed) {
        if (!_recipients.contains(p)) _recipients.add(p);
      }
      _recipientInputCtrl.clear();
    });
  }

  Future<void> _pasteOrImportCsv() async {
    final ctrl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null) ctrl.text = clip!.text!;
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialogFrame(
        icon: Icons.content_paste_go_rounded,
        iconColor: AppColors.purple,
        title: 'Bulk Paste / CSV Import',
        subtitle: 'Paste comma, newline, or CSV separated numbers',
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '+919876543210, 9876500001\n9811223344',
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download_done_rounded, size: 18),
            label: const Text('Import'),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
          ),
        ],
      ),
    );
    if (text == null) return;
    final parsed = SmsUtils.parseMultiplePhones(text);
    setState(() {
      for (final p in parsed) {
        if (!_recipients.contains(p)) _recipients.add(p);
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${parsed.length} valid recipient(s)')),
      );
    }
  }

  Future<void> _loadContacts() async {
    final perms = await PlatformBridge.getPermissionSnapshot();
    if (perms['read_contacts'] != true) {
      final updated = await PlatformBridge.requestContactsPermission();
      if (updated['read_contacts'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contacts permission denied. Enter numbers manually or grant READ_CONTACTS.'),
              backgroundColor: AppColors.warningOrange,
            ),
          );
        }
        return;
      }
    }
    final list = await PlatformBridge.getContacts(query: _contactSearchCtrl.text);
    if (!mounted) return;
    setState(() {
      _contacts = list.map((e) => Map<String, String>.from(e)).toList();
      _contactsLoaded = true;
    });
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15))),
    );
    if (t == null || !mounted) return;
    setState(() {
      _isScheduled = true;
      _scheduledDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    if (_recipientInputCtrl.text.trim().isNotEmpty) {
      _addRecipientFromField();
    }
    if (_recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one valid recipient.'), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    final body = _messageCtrl.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message body cannot be empty.'), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    final unresolved = SmsUtils.extractTemplateVariables(body);
    if (unresolved.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Replace unresolved template variables first: ${unresolved.join(', ')}'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final selectedSim = _sims.where((s) => s.subscriptionId == _selectedSubId).firstOrNull;
    if (selectedSim != null && !selectedSim.canSend) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedSim.displayTitle} is unavailable or set to Receive Only.'),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    if (_recipients.length > 1) {
      final confirmed = await showConfirmationDialog(
        context,
        title: 'Confirm Bulk SMS',
        message: 'Send this message to ${_recipients.length} recipients?',
        confirmLabel: 'Send to All',
        confirmColor: AppColors.successGreen,
        icon: Icons.send_rounded,
      );
      if (!confirmed) return;
    }

    setState(() => _isSending = true);
    try {
      final expiresAt = DateTime.now().toUtc().add(Duration(hours: _expirationHours)).toIso8601String();
      final res = await ApiService().submitSms(
        recipients: List<String>.from(_recipients),
        messageBody: body,
        subscriptionId: _selectedSubId,
        simSlot: selectedSim?.simSlotIndex,
        priority: _priority,
        scheduledAt: _isScheduled && _scheduledDateTime != null
            ? _scheduledDateTime!.toUtc().toIso8601String()
            : null,
        expiresAt: expiresAt,
        templateId: _selectedTemplateId,
        applicationSource: _appSourceCtrl.text.trim().isEmpty ? 'SMS Gateway App' : _appSourceCtrl.text.trim(),
        referenceId: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
        deliveryReportRequested: _requestDeliveryReport,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isScheduled
                  ? 'Scheduled for ${_recipients.length} recipient(s)'
                  : 'Submitted ${_recipients.length} SMS (${res['status']})',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error']?.toString() ?? 'Failed to submit SMS'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enc = SmsUtils.analyzeEncoding(_messageCtrl.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            AppTopBar(
              title: 'Send SMS',
              showBackButton: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.contacts_outlined, color: AppColors.primaryBlue),
                  onPressed: () {
                    setState(() => _activeTab = 2);
                    _loadContacts();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  children: [
                    _ModeTab('Compose', _activeTab == 0, () => setState(() => _activeTab = 0)),
                    _ModeTab('Templates', _activeTab == 1, () => setState(() => _activeTab = 1)),
                    _ModeTab('Contacts', _activeTab == 2, () {
                      setState(() => _activeTab = 2);
                      if (!_contactsLoaded) _loadContacts();
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _activeTab == 1
                  ? _buildTemplatesTab()
                  : _activeTab == 2
                      ? _buildContactsTab()
                      : _buildComposeTab(enc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeTab(SmsEncodingInfo enc) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        28 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        const Text('Recipients', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        StatusCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _recipientInputCtrl,
                      keyboardType: TextInputType.phone,
                      onSubmitted: (_) => _addRecipientFromField(),
                      decoration: const InputDecoration(
                        hintText: 'Enter +91... or 10-digit number',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add Recipient',
                    icon: const Icon(Icons.add_circle_rounded, color: AppColors.primaryBlue),
                    onPressed: _addRecipientFromField,
                  ),
                  IconButton(
                    tooltip: 'Paste / CSV Import',
                    icon: const Icon(Icons.content_paste_go_rounded, color: AppColors.purple),
                    onPressed: _pasteOrImportCsv,
                  ),
                ],
              ),
              if (_recipients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _recipients
                      .map((r) => Chip(
                            label: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => setState(() => _recipients.remove(r)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Message', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${enc.characterCount} / ${enc.currentSegmentMax} • ${enc.segmentCount} part(s) • ${enc.encoding}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enc.isUnicode ? AppColors.purple : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        StatusCard(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _messageCtrl,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Type your SMS message...',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(height: 14),

        const Text('SIM Selection', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        StatusCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _sims.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No local SIM detected (will route via backend/default gateway SIM)',
                    style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _sims.any((s) => s.subscriptionId == _selectedSubId) ? _selectedSubId : null,
                    isExpanded: true,
                    items: _sims.map((sim) {
                      return DropdownMenuItem<int>(
                        value: sim.subscriptionId,
                        child: Row(
                          children: [
                            const Icon(Icons.sim_card_rounded, color: AppColors.primaryBlue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${sim.displayTitle}${sim.canSend ? '' : ' (Unavailable)'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SignalBars(level: sim.signalLevel),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedSubId = v),
                  ),
                ),
        ),
        const SizedBox(height: 14),

        const Text('Options', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 6),
        StatusCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.priority_high_rounded, color: AppColors.warningOrange, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text('Priority', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  DropdownButton<String>(
                    value: _priority,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                      DropdownMenuItem(value: 'HIGH', child: Text('High')),
                      DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                      DropdownMenuItem(value: 'LOW', child: Text('Low')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
                  ),
                ],
              ),
              const Divider(height: 12),
              Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text('Schedule', overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _pickScheduleDateTime,
                    child: Text(
                      _isScheduled && _scheduledDateTime != null
                          ? '${_scheduledDateTime!.day}/${_scheduledDateTime!.month} ${_scheduledDateTime!.hour}:${_scheduledDateTime!.minute.toString().padLeft(2, '0')}'
                          : 'Now ▾',
                    ),
                  ),
                ],
              ),
              if (_isScheduled)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _isScheduled = false;
                      _scheduledDateTime = null;
                    }),
                    child: const Text('Clear Schedule (Send Now)', style: TextStyle(fontSize: 12)),
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _requestDeliveryReport,
                onChanged: (v) => setState(() => _requestDeliveryReport = v ?? true),
                title: const Text('Request Delivery Report', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              InkWell(
                onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Application Source, Reference & Expiry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                        ),
                      ),
                      Icon(
                        _showAdvancedOptions ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showAdvancedOptions) ...[
                const Divider(height: 12),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _appSourceCtrl,
                        decoration: const InputDecoration(labelText: 'Application Source'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _referenceCtrl,
                        decoration: const InputDecoration(labelText: 'Reference ID (Opt)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Expiration Window', style: TextStyle(fontSize: 13)),
                    DropdownButton<int>(
                      value: _expirationHours,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 Hour')),
                        DropdownMenuItem(value: 6, child: Text('6 Hours')),
                        DropdownMenuItem(value: 24, child: Text('24 Hours')),
                        DropdownMenuItem(value: 72, child: Text('72 Hours')),
                      ],
                      onChanged: (v) => setState(() => _expirationHours = v ?? 24),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _handleSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
              _isScheduled ? 'Schedule Message' : 'Send Message',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _applyTemplate(MessageTemplate t) async {
    final vars = SmsUtils.extractTemplateVariables(t.messageBody);
    String finalBody = t.messageBody;
    if (vars.isNotEmpty) {
      final ctrls = {for (final v in vars) v: TextEditingController()};
      final rendered = await showDialog<String>(
        context: context,
        builder: (ctx) => AppDialogFrame(
          icon: Icons.description_outlined,
          iconColor: AppColors.primaryBlue,
          title: 'Fill Template Fields',
          subtitle: t.templateName,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: vars
                .map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: ctrls[v],
                      decoration: InputDecoration(labelText: '{$v}'),
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, t.messageBody),
              child: const Text('Insert Raw'),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  final valMap = {for (final e in ctrls.entries) e.key: e.value.text.trim()};
                  final out = SmsUtils.renderTemplateStrict(t.messageBody, valMap);
                  Navigator.pop(ctx, out);
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.errorRed),
                  );
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      for (final c in ctrls.values) {
        c.dispose();
      }
      if (rendered == null) return;
      finalBody = rendered;
    }

    if (!mounted) return;
    setState(() {
      _selectedTemplateId = t.id;
      _messageCtrl.text = finalBody;
      _appSourceCtrl.text = t.applicationName;
      _priority = t.defaultPriority;
      if (t.preferredSimSlot != null) {
        final match = _sims.where((s) => s.simSlotIndex == t.preferredSimSlot).firstOrNull;
        if (match != null) _selectedSubId = match.subscriptionId;
      }
      _activeTab = 0;
    });
  }

  Widget _buildTemplatesTab() {
    if (_templates.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'No Templates Saved',
        subtitle: 'Create reusable templates in Settings → Message Templates.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: _templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, idx) {
        final t = _templates[idx];
        return StatusCard(
          onTap: () => _applyTemplate(t),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      t.templateName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: t.isActive ? 'ACTIVE' : 'INACTIVE'),
                ],
              ),
              const SizedBox(height: 4),
              Text(t.messageBody, style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText)),
              const SizedBox(height: 6),
              Text('${t.applicationName} • ${t.category}', style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppSearchBar(
            controller: _contactSearchCtrl,
            hintText: 'Search Android contacts...',
            onChanged: (_) => _loadContacts(),
            onClear: _loadContacts,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _contacts.isEmpty
              ? EmptyState(
                  icon: Icons.contacts_outlined,
                  title: 'No Contacts Loaded',
                  subtitle: 'Tap below to load device contacts (requires READ_CONTACTS permission).',
                  action: ElevatedButton(onPressed: _loadContacts, child: const Text('Load Contacts')),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  itemCount: _contacts.length,
                  itemBuilder: (_, idx) {
                    final c = _contacts[idx];
                    final phone = c['phone'] ?? '';
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(c['name'] ?? 'Contact'),
                      subtitle: Text(phone),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
                        onPressed: () {
                          if (SmsUtils.isValidPhone(phone)) {
                            final norm = SmsUtils.normalizePhone(phone);
                            setState(() {
                              if (!_recipients.contains(norm)) _recipients.add(norm);
                              _activeTab = 0;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

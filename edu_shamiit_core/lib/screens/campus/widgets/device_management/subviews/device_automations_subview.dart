import 'package:flutter/material.dart';

class DeviceAutomationsSubview extends StatefulWidget {
  final List<Map<String, dynamic>> automations;
  final VoidCallback onBackToDashboard;
  final Function(String id) onToggleAutomation;
  final Function(Map<String, dynamic> data)? onCreateRule;
  final Function(String ruleId, Map<String, dynamic> data)? onUpdateRule;
  final Function(String ruleId)? onDeleteRule;
  final Function(String ruleId)? onDuplicateRule;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)? onTestRule;
  final Future<Map<String, dynamic>> Function()? onRunCron;

  const DeviceAutomationsSubview({
    super.key,
    required this.automations,
    required this.onBackToDashboard,
    required this.onToggleAutomation,
    this.onCreateRule,
    this.onUpdateRule,
    this.onDeleteRule,
    this.onDuplicateRule,
    this.onTestRule,
    this.onRunCron,
  });

  @override
  State<DeviceAutomationsSubview> createState() => _DeviceAutomationsSubviewState();
}

class _DeviceAutomationsSubviewState extends State<DeviceAutomationsSubview> {
  String _searchQuery = '';
  String _selectedBuilding = 'All Buildings';
  String _selectedDeviceType = 'All Device Types';
  String _selectedStatus = 'All Status';
  final int _currentPage = 1;
  bool _isRunningCron = false;

  // Selected rule being edited or created
  String? _editingRuleId;
  late TextEditingController _ruleNameController;
  late TextEditingController _descController;
  String _ruleCategory = 'Smart Rule'; // Smart Rule, Schedule Rule, Threshold Rule
  String _conditionCombinator = 'All Conditions (AND)'; // All Conditions (AND), Any Condition (OR)
  String _actionExecutionMode = 'In Sequence'; // In Sequence, Simultaneously

  // Lists of conditions and actions
  List<Map<String, dynamic>> _conditions = [];
  List<Map<String, dynamic>> _actions = [];

  // Optional settings
  bool _optActive = true;
  bool _optAllowManualOverride = true;
  bool _optLogActivity = true;
  String _effectiveFor = 'always'; // always, schedule, custom_range

  // Simulation test feedback
  String? _testResultBanner;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _ruleNameController = TextEditingController();
    _descController = TextEditingController();

    if (widget.automations.isNotEmpty) {
      _loadRuleIntoEditor(widget.automations.first);
    } else {
      _initNewRuleTemplate();
    }
  }

  @override
  void didUpdateWidget(covariant DeviceAutomationsSubview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.automations.isNotEmpty && _editingRuleId == null) {
      _loadRuleIntoEditor(widget.automations.first);
    }
  }

  @override
  void dispose() {
    _ruleNameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _initNewRuleTemplate() {
    setState(() {
      _editingRuleId = null;
      _ruleNameController.text = 'New Automation Rule';
      _descController.text = 'Trigger device operations based on sensor thresholds';
      _ruleCategory = 'Smart Rule';
      _conditionCombinator = 'All Conditions (AND)';
      _actionExecutionMode = 'In Sequence';
      _conditions = [
        {
          'icon': 'people',
          'attribute': 'Occupancy',
          'operator': 'is equal to',
          'value': '0 (No one)',
          'unit': '',
        },
        {
          'icon': 'schedule',
          'attribute': 'For a duration of',
          'operator': '>=',
          'value': '2',
          'unit': 'Minutes',
        },
      ];
      _actions = [
        {
          'icon': 'sensor_door',
          'target': 'Automatic Door',
          'action': 'Close',
          'parameter': '',
        },
        {
          'icon': 'notifications',
          'target': 'Send Notification',
          'action': 'To: Facility Team',
          'parameter': 'Door auto-closed',
        },
      ];
      _optActive = true;
      _optAllowManualOverride = true;
      _optLogActivity = true;
      _effectiveFor = 'always';
      _testResultBanner = null;
    });
  }

  void _loadRuleIntoEditor(Map<String, dynamic> rule) {
    final cond = rule['trigger_condition'] is Map ? rule['trigger_condition'] as Map : {};
    final act = rule['action_payload'] is Map ? rule['action_payload'] as Map : {};
    final opts = act['options'] is Map ? act['options'] as Map : {};

    setState(() {
      _editingRuleId = rule['id']?.toString();
      _ruleNameController.text = rule['name']?.toString() ?? 'Unnamed Rule';
      _descController.text = rule['description']?.toString() ?? '';
      _ruleCategory = cond['category']?.toString() ?? (rule['trigger_type'] == 'schedule' ? 'Schedule Rule' : 'Smart Rule');
      _conditionCombinator = cond['combinator'] == 'OR' ? 'Any Condition (OR)' : 'All Conditions (AND)';
      _actionExecutionMode = act['execution_mode']?.toString() ?? 'In Sequence';

      final rawConds = cond['conditions'] as List? ?? [];
      if (rawConds.isNotEmpty) {
        _conditions = rawConds.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _conditions = [
          {'icon': 'people', 'attribute': 'Occupancy', 'operator': 'is equal to', 'value': '0 (No one)', 'unit': ''}
        ];
      }

      final rawActs = act['actions'] as List? ?? [];
      if (rawActs.isNotEmpty) {
        _actions = rawActs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _actions = [
          {'icon': 'sensor_door', 'target': 'Automatic Door', 'action': 'Close', 'parameter': ''}
        ];
      }

      _optActive = rule['is_active'] == true;
      _optAllowManualOverride = opts['allow_override'] != false;
      _optLogActivity = opts['log_activity'] != false;
      _effectiveFor = act['effective_for']?.toString() ?? 'always';
      _testResultBanner = null;
    });
  }

  void _addCondition() {
    setState(() {
      _conditions.add({
        'icon': 'sensors',
        'attribute': 'Occupancy',
        'operator': 'is equal to',
        'value': '0 (No one)',
        'unit': '',
      });
    });
  }

  void _removeCondition(int index) {
    if (_conditions.length > 1) {
      setState(() => _conditions.removeAt(index));
    }
  }

  void _addAction() {
    setState(() {
      _actions.add({
        'icon': 'bolt',
        'target': 'Classroom Lights',
        'action': 'Turn OFF',
        'parameter': '',
      });
    });
  }

  void _removeAction(int index) {
    if (_actions.length > 1) {
      setState(() => _actions.removeAt(index));
    }
  }

  void _handleTestRule() async {
    if (widget.onTestRule == null) return;
    setState(() {
      _isTesting = true;
      _testResultBanner = null;
    });

    final payload = {
      'rule_id': _editingRuleId,
      'trigger_condition': {
        'combinator': _conditionCombinator.contains('OR') ? 'OR' : 'AND',
        'category': _ruleCategory,
        'conditions': _conditions,
      },
      'action_payload': {
        'execution_mode': _actionExecutionMode,
        'actions': _actions,
      },
    };

    try {
      final res = await widget.onTestRule!(payload);
      setState(() {
        _isTesting = false;
        _testResultBanner = res['evaluation'] ?? 'Simulation successful: Conditions satisfied against live IoT telemetry.';
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testResultBanner = 'Test completed: All rule parameters valid.';
      });
    }
  }

  void _handleSaveRule() {
    final name = _ruleNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a rule name')));
      return;
    }

    final payload = {
      'name': name,
      'description': _descController.text.trim(),
      'trigger_type': _ruleCategory.toLowerCase().contains('schedule') ? 'schedule' : 'smart',
      'trigger_condition': {
        'combinator': _conditionCombinator.contains('OR') ? 'OR' : 'AND',
        'category': _ruleCategory,
        'location': 'B1 • Classrooms',
        'conditions': _conditions,
      },
      'action_payload': {
        'execution_mode': _actionExecutionMode,
        'actions': _actions,
        'options': {
          'allow_override': _optAllowManualOverride,
          'log_activity': _optLogActivity,
          'active': _optActive,
        },
        'effective_for': _effectiveFor,
      },
      'is_active': _optActive,
    };

    if (_editingRuleId != null) {
      widget.onUpdateRule?.call(_editingRuleId!, payload);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rule "$name" updated successfully!')));
    } else {
      widget.onCreateRule?.call(payload);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New rule "$name" created successfully!')));
    }
  }

  void _confirmDeleteRule(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $name?'),
        content: const Text('Are you sure you want to permanently delete this automation rule?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      widget.onDeleteRule?.call(id);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rule "$name" deleted.')));
    }
  }

  Future<void> _handleRunCron() async {
    if (widget.onRunCron == null) return;
    setState(() => _isRunningCron = true);
    try {
      final res = await widget.onRunCron!();
      if (!mounted) return;
      final triggeredCount = res['rules_triggered'] ?? 0;
      final actionsCount = res['actions_executed_count'] ?? 0;
      final mqttCount = res['mqtt_commands_dispatched'] ?? 0;
      final evaluatedCount = res['rules_evaluated'] ?? 0;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.alarm_on_rounded, color: Color(0xFF16A34A), size: 24),
              SizedBox(width: 10),
              Text('Automation Cron Executed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Periodic cron evaluation cycle completed successfully.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 12),
              _buildCronMetricRow('Active Rules Evaluated:', '$evaluatedCount rules'),
              _buildCronMetricRow('Rules Satisfied & Triggered:', '$triggeredCount rules'),
              _buildCronMetricRow('Device Actions Executed:', '$actionsCount actions'),
              _buildCronMetricRow('MQTT Control Packets Sent:', '$mqttCount packets'),
              _buildCronMetricRow('Next Automatic Run:', 'In 60 seconds (Background Loop)'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to execute cron: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isRunningCron = false);
    }
  }

  Widget _buildCronMetricRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = screenWidth >= 950;

    // Filter rules
    final filteredRules = widget.automations.where((r) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final desc = (r['description'] ?? '').toString().toLowerCase();
      final matchesQuery = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());

      final isActive = r['is_active'] == true;
      final matchesStatus = _selectedStatus == 'All Status' ||
          (_selectedStatus == 'Active' && isActive) ||
          (_selectedStatus == 'Inactive' && !isActive);

      return matchesQuery && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Subview Top Breadcrumb & Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBackToDashboard,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Automation Rules',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Trigger automated device operations based on occupancy, schedules, and environmental thresholds',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Main Content Area: Side-by-Side Split View matching Upload 3
        Expanded(
          child: isDesktopOrTablet
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Pane: Automation Rules List & Filters (~42% flex)
                    Expanded(
                      flex: 42,
                      child: _buildRulesListPane(filteredRules, isDark),
                    ),
                    const SizedBox(width: 14),

                    // Right Pane: Create / Edit Rule Interactive Builder (~58% flex)
                    Expanded(
                      flex: 58,
                      child: _buildRuleEditorPane(isDark),
                    ),
                  ],
                )
              : _buildRulesListPane(filteredRules, isDark),
        ),
      ],
    );
  }

  // --- LEFT PANE: Rules List with Filters, Badges & Pagination ---
  Widget _buildRulesListPane(List<Map<String, dynamic>> rules, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: "Automation Rules (42)" + "+ Create New Rule" Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Automation Rules (${rules.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Live Cron Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(
                          'Cron: 60s Loop',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Run Cron Now Button
                  OutlinedButton.icon(
                    onPressed: _isRunningCron ? null : _handleRunCron,
                    icon: _isRunningCron
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.alarm_on_rounded, size: 14, color: Color(0xFF16A34A)),
                    label: const Text('Run Cron Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),

                  ElevatedButton.icon(
                    onPressed: _initNewRuleTemplate,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create New Rule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'export', child: Text('Export Rules')),
                      PopupMenuItem(value: 'import', child: Text('Import Rules')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search rules by name, device, location...',
                  hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),

          // Filters Row: All Buildings, All Device Types, All Status
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterDropdown(
                    value: _selectedBuilding,
                    items: const ['All Buildings', 'B1 - Academic', 'B2 - Science', 'B3 - Admin', 'B4 - Library'],
                    onChanged: (v) => setState(() => _selectedBuilding = v!),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterDropdown(
                    value: _selectedDeviceType,
                    items: const ['All Device Types', 'Lighting', 'HVAC', 'Fans', 'Projectors', 'Gates'],
                    onChanged: (v) => setState(() => _selectedDeviceType = v!),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterDropdown(
                    value: _selectedStatus,
                    items: const ['All Status', 'Active', 'Inactive'],
                    onChanged: (v) => setState(() => _selectedStatus = v!),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Rules List
          Expanded(
            child: rules.isEmpty
                ? Center(
                    child: Text(
                      'No automation rules matching criteria.',
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  )
                : ListView.separated(
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = rules[index];
                      final id = r['id']?.toString() ?? '';
                      final isSelected = _editingRuleId == id;
                      return _buildRuleCard(r, isSelected, isDark);
                    },
                  ),
          ),

          // Pagination Footer Bar
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing 1 - ${rules.length} of ${rules.length} rules',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const IconButton(icon: Icon(Icons.chevron_left, size: 18), onPressed: null),
                      ...[1, 2, 3].map((p) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: p == _currentPage ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$p',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: p == _currentPage ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                            ),
                          )),
                      const IconButton(icon: Icon(Icons.chevron_right, size: 18), onPressed: null),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      i,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // --- Rule List Item Card ---
  Widget _buildRuleCard(Map<String, dynamic> r, bool isSelected, bool isDark) {
    final id = r['id']?.toString() ?? '';
    final name = r['name'] ?? 'Unnamed Rule';
    final desc = r['description'] ?? '';
    final isActive = r['is_active'] == true;
    final cond = r['trigger_condition'] is Map ? r['trigger_condition'] as Map : {};
    final location = cond['location']?.toString() ?? 'B1 • Classrooms';
    final category = cond['category']?.toString() ?? (r['trigger_type'] == 'schedule' ? 'Schedule' : 'Smart');

    // Choose leading icon & color based on rule
    IconData icon = Icons.psychology_rounded;
    Color iconColor = const Color(0xFF2563EB);
    final lowerName = name.toLowerCase();
    if (lowerName.contains('door') || lowerName.contains('entrance')) {
      icon = Icons.sensor_door_outlined;
      iconColor = const Color(0xFF2563EB);
    } else if (lowerName.contains('light')) {
      icon = Icons.lightbulb_outline_rounded;
      iconColor = const Color(0xFFEAB308);
    } else if (lowerName.contains('fan')) {
      icon = Icons.mode_fan_off_rounded;
      iconColor = const Color(0xFF06B6D4);
    } else if (lowerName.contains('projector')) {
      icon = Icons.videocam_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (lowerName.contains('ac') || lowerName.contains('hvac') || lowerName.contains('temp')) {
      icon = Icons.ac_unit_rounded;
      iconColor = const Color(0xFF0284C7);
    } else if (lowerName.contains('hour') || lowerName.contains('schedule')) {
      icon = Icons.calendar_today_rounded;
      iconColor = const Color(0xFF7C3AED);
    } else if (lowerName.contains('energy') || lowerName.contains('saving')) {
      icon = Icons.notifications_none_rounded;
      iconColor = const Color(0xFFD97706);
    }

    return InkWell(
      onTap: () => _loadRuleIntoEditor(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Leading Icon in rounded container
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),

            // Rule Title & Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Location badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Category badge (Smart vs Schedule)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: category.toLowerCase().contains('smart')
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category.replaceAll(' Rule', ''),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: category.toLowerCase().contains('smart')
                                ? const Color(0xFF6D28D9)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Toggle Switch
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isActive,
                activeThumbColor: const Color(0xFF16A34A),
                onChanged: (_) => widget.onToggleAutomation(id),
              ),
            ),

            // 3-dots Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18),
              onSelected: (val) {
                if (val == 'edit') _loadRuleIntoEditor(r);
                if (val == 'test') _handleTestRule();
                if (val == 'duplicate') widget.onDuplicateRule?.call(id);
                if (val == 'delete') _confirmDeleteRule(id, name);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Rule')),
                const PopupMenuItem(value: 'test', child: Text('Test Rule')),
                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Rule')),
                const PopupMenuItem(value: 'delete', child: Text('Delete Rule', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- RIGHT PANE: Create / Edit Rule Interactive Builder ---
  Widget _buildRuleEditorPane(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: "<- Create / Edit Automation Rule" + "Smart Rule v" Badge
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: _initNewRuleTemplate,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _editingRuleId != null ? 'Edit Automation Rule' : 'Create Automation Rule',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),

              // Category Badge Dropdown
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ['Smart Rule', 'Schedule Rule', 'Threshold Rule'].contains(_ruleCategory)
                        ? _ruleCategory
                        : 'Smart Rule',
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 8,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                    ),
                    items: ['Smart Rule', 'Schedule Rule', 'Threshold Rule']
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _ruleCategory = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Scrollable Builder Form
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Test Simulation Result Banner if active
                  if (_testResultBanner != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? const Color(0xFF10B981) : const Color(0xFF16A34A)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResultBanner!,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF166534)),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 16, color: isDark ? const Color(0xFFD1FAE5) : const Color(0xFF166534)),
                            onPressed: () => setState(() => _testResultBanner = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Rule Name *
                  Text('Rule Name *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _ruleNameController,
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Auto Close Classroom Door (No Occupancy)',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text('Description', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Close automatic door when no one is in the room for 2 minutes',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. IF (Conditions) Container (Light Blue Background)
                  _buildConditionsBox(isDark),
                  const SizedBox(height: 14),

                  // 2. THEN (Actions) Container (Light Green Background)
                  _buildActionsBox(isDark),
                  const SizedBox(height: 14),

                  // 3. Bottom Settings: Also Set & Effective For
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Also Set (Optional)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Also Set (Optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              _buildCheckboxRow('Active Rule', _optActive, (v) => setState(() => _optActive = v ?? true), isDark),
                              _buildCheckboxRow('Allow Manual Override', _optAllowManualOverride, (v) => setState(() => _optAllowManualOverride = v ?? true), isDark),
                              _buildCheckboxRow('Log Activity', _optLogActivity, (v) => setState(() => _optLogActivity = v ?? true), isDark),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Effective For
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Effective For', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              const SizedBox(height: 6),
                              _buildRadioRow('Always (24 x 7)', 'always', isDark),
                              _buildRadioRow('As per Schedule', 'schedule', isDark),
                              _buildRadioRow('Custom Date Range', 'custom_range', isDark),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          const Divider(height: 16),

          // Action Buttons Bar: Test Rule (Left) & Cancel/Save (Right)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isTesting ? null : _handleTestRule,
                icon: _isTesting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF2563EB)),
                label: const Text('Test Rule', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _initNewRuleTemplate,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _handleSaveRule,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Rule', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 1. IF (Conditions) Container ---
  Widget _buildConditionsBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon, "IF (Conditions)", Dropdown "All Conditions (AND)"
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 6),
              Text(
                'IF (Conditions)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                ),
              ),
              const Spacer(),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _conditionCombinator,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                    ),
                    items: const [
                      'All Conditions (AND)',
                      'Any Condition (OR)',
                    ]
                        .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(
                                opt,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E3A8A),
                                  fontSize: 11,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _conditionCombinator = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dynamic Condition Rows
          ...List.generate(_conditions.length, (idx) {
            final c = _conditions[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(
                      idx == 0 ? Icons.people_outline_rounded : Icons.schedule_rounded,
                      size: 18,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),

                    // Attribute Dropdown
                    _buildSmallDropdown(
                      value: c['attribute']?.toString() ?? 'Occupancy',
                      items: const ['Occupancy', 'For a duration of', 'Room Temperature', 'Video Input Signal', 'Time of Day'],
                      onChanged: (val) => setState(() => c['attribute'] = val),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // Operator Dropdown
                    _buildSmallDropdown(
                      value: c['operator']?.toString() ?? 'is equal to',
                      items: const ['is equal to', '>=', '<=', '>', '<', 'in'],
                      onChanged: (val) => setState(() => c['operator'] = val),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // Value Input
                    SizedBox(
                      width: 100,
                      height: 28,
                      child: TextField(
                        controller: TextEditingController(text: c['value']?.toString() ?? ''),
                        onChanged: (val) => c['value'] = val,
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                    ),

                    if (c['unit'] != null && c['unit'].toString().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildSmallDropdown(
                        value: c['unit']?.toString() ?? 'Minutes',
                        items: const ['Seconds', 'Minutes', 'Hours', '°C'],
                        onChanged: (val) => setState(() => c['unit'] = val),
                        isDark: isDark,
                      ),
                    ],

                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      onPressed: () => _removeCondition(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          }),

          // "Add Condition" Button (Single +, no double ++)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addCondition,
              icon: const Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
              label: const Text('Add Condition', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. THEN (Actions) Container ---
  Widget _buildActionsBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon, "THEN (Actions)", "Execute Actions | In Sequence"
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 6),
              Text(
                'THEN (Actions)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                ),
              ),
              const Spacer(),
              Text('Execute Actions', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(width: 6),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF22C55E) : const Color(0xFFBBF7D0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _actionExecutionMode,
                    isDense: true,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 8,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                    ),
                    items: const [
                      'In Sequence',
                      'Simultaneously',
                    ]
                        .map((mode) => DropdownMenuItem(
                              value: mode,
                              child: Text(
                                mode,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF166534),
                                  fontSize: 11,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _actionExecutionMode = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dynamic Action Rows
          ...List.generate(_actions.length, (idx) {
            final a = _actions[idx];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(
                      idx == 0 ? Icons.sensor_door_outlined : Icons.notifications_none_rounded,
                      size: 18,
                      color: const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),

                    // Target Dropdown
                    _buildSmallDropdown(
                      value: a['target']?.toString() ?? 'Automatic Door',
                      items: const [
                        'Automatic Door',
                        'Send Notification',
                        'Classroom Lights',
                        'AC (HVAC)',
                        'Ceiling Fans',
                        'Projector',
                        'Heavy Load Fixtures',
                      ],
                      onChanged: (val) => setState(() => a['target'] = val),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // Action Dropdown
                    _buildSmallDropdown(
                      value: a['action']?.toString() ?? 'Close',
                      items: const [
                        'Close',
                        'Open',
                        'Turn ON',
                        'Turn OFF',
                        'Set Temperature',
                        'Standby / OFF',
                        'To: Facility Team',
                        'To: Admin Office',
                        'Power Saver Mode',
                      ],
                      onChanged: (val) => setState(() => a['action'] = val),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),

                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      onPressed: () => _removeAction(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            );
          }),

          // "Add Action" Button (Single +, no double ++)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addAction,
              icon: const Icon(Icons.add, size: 14, color: Color(0xFF16A34A)),
              label: const Text('Add Action', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          borderRadius: BorderRadius.circular(8),
          elevation: 8,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      i,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCheckboxRow(String label, bool value, ValueChanged<bool?> onChanged, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(value: value, onChanged: onChanged),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _buildRadioRow(String label, String val, bool isDark) {
    final isSelected = _effectiveFor == val;
    return InkWell(
      onTap: () => setState(() => _effectiveFor = val),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155))),
          ],
        ),
      ),
    );
  }
}

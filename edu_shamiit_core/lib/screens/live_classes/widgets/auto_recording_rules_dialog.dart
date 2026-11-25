import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';

class AutoRecordingRulesDialog extends ConsumerStatefulWidget {
  const AutoRecordingRulesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AutoRecordingRulesDialog(),
    );
  }

  @override
  ConsumerState<AutoRecordingRulesDialog> createState() =>
      _AutoRecordingRulesDialogState();
}

class _AutoRecordingRulesDialogState
    extends ConsumerState<AutoRecordingRulesDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _globalAutoRecordAll;
  late Set<String> _enabledClasses;
  late List<AutoRecordingQueryClause> _clauses;

  final List<Map<String, dynamic>> _assignedClasses = [
    {
      'id': '10-A',
      'title': 'Class 10 - 10-A',
      'subject': 'Computer Science',
      'room': 'Lab 2',
      'students': 38,
      'icon': Icons.computer_rounded,
    },
    {
      'id': '10-B',
      'title': 'Class 10 - 10-B',
      'subject': 'Mathematics',
      'room': 'Room 102',
      'students': 42,
      'icon': Icons.calculate_rounded,
    },
    {
      'id': '11-A',
      'title': 'Class 11 - 11-A',
      'subject': 'Physics',
      'room': 'Physics Lab',
      'students': 35,
      'icon': Icons.science_rounded,
    },
    {
      'id': '12-A',
      'title': 'Class 12 - 12-A',
      'subject': 'Chemistry',
      'room': 'Chem Lab 1',
      'students': 30,
      'icon': Icons.biotech_rounded,
    },
    {
      'id': '12-B',
      'title': 'Class 12 - 12-B',
      'subject': 'Computer Science',
      'room': 'Lab 1',
      'students': 28,
      'icon': Icons.terminal_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final currentRules =
        ref.read(liveClassManagementProvider).autoRecordingRules;
    _globalAutoRecordAll = currentRules.globalAutoRecordAll;
    _enabledClasses = Set<String>.from(currentRules.enabledClassSectionIds);
    _clauses = currentRules.customQueryClauses.map((c) {
      return AutoRecordingQueryClause(
        id: c.id,
        logicalOp: c.logicalOp,
        field: c.field,
        operator: c.operator,
        value: c.value,
      );
    }).toList();

    if (_clauses.isEmpty) {
      _clauses.add(
        AutoRecordingQueryClause(
          id: 'clause_1',
          logicalOp: RuleLogicalOperator.and,
          field: RuleField.meetingTitle,
          operator: RuleConditionOperator.contains,
          value: 'Exam',
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addClause() {
    setState(() {
      _clauses.add(
        AutoRecordingQueryClause(
          id: 'clause_${DateTime.now().millisecondsSinceEpoch}',
          logicalOp: RuleLogicalOperator.and,
          field: RuleField.subject,
          operator: RuleConditionOperator.contains,
          value: '',
        ),
      );
    });
  }

  void _removeClause(int index) {
    if (_clauses.length <= 1) return;
    setState(() {
      _clauses.removeAt(index);
    });
  }

  void _saveRules() {
    final updatedRules = AutoRecordingRuleSet(
      globalAutoRecordAll: _globalAutoRecordAll,
      enabledClassSectionIds: _enabledClasses,
      customQueryClauses: _clauses,
    );
    ref
        .read(liveClassManagementProvider.notifier)
        .updateAutoRecordingRules(updatedRules);

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Auto-recording rules updated and activated across all live sessions.'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _getFieldLabel(RuleField field) {
    switch (field) {
      case RuleField.meetingTitle:
        return 'Meeting Title';
      case RuleField.classSectionCombo:
        return 'Class & Section';
      case RuleField.subject:
        return 'Subject';
      case RuleField.teacherHost:
        return 'Teacher / Host';
      case RuleField.sessionType:
        return 'Session Type';
      case RuleField.scheduledDay:
        return 'Scheduled Day';
    }
  }

  String _getOperatorLabel(RuleConditionOperator op) {
    switch (op) {
      case RuleConditionOperator.contains:
        return 'Contains';
      case RuleConditionOperator.doesNotContain:
        return 'Does Not Contain';
      case RuleConditionOperator.equals:
        return 'Equals (=)';
      case RuleConditionOperator.doesNotEqual:
        return 'Does Not Equal (≠)';
      case RuleConditionOperator.startsWith:
        return 'Starts With';
      case RuleConditionOperator.endsWith:
        return 'Ends With';
      case RuleConditionOperator.matchesPattern:
        return 'Matches Pattern (Regex)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputFill =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rule_folder_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Auto-Recording Rules & Class Triggers',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.4)),
                              ),
                              child: const Text('SHAMIIT Rules Engine',
                                  style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Configure automatic egress recording triggers for assigned teaching classes or build conditional query rules.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: textSecondary,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.class_outlined, size: 15),
                          const SizedBox(width: 6),
                          Text(
                              'Assigned Classes (${_enabledClasses.length} Enabled)'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.alt_route_rounded, size: 15),
                          const SizedBox(width: 6),
                          Text(
                              'Conditional Query Rules (${_clauses.length} Clauses)'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Assigned Classes Quick Toggles
                    _buildAssignedClassesTab(isDark, cardBorder, textPrimary,
                        textSecondary, inputFill),

                    // TAB 2: SHAMIIT Query Rules Builder
                    _buildConditionalQueryRulesTab(isDark, cardBorder,
                        textPrimary, textSecondary, inputFill),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: cardBorder),
              const SizedBox(height: 14),

              // Footer Actions
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Matching live classes will auto-trigger backend recording immediately upon session start.',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveRules,
                    icon: const Icon(Icons.save_rounded, size: 15),
                    label: const Text('Save & Apply Rules',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: ASSIGNED CLASSES
  // ============================================================================
  Widget _buildAssignedClassesTab(bool isDark, Color cardBorder,
      Color textPrimary, Color textSecondary, Color inputFill) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master switch card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.all_inclusive_rounded,
                    color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Master Toggle: Auto-Record ALL Assigned Teaching Classes',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: textPrimary)),
                      Text(
                          'When enabled, all sessions for classes assigned to you will automatically record.',
                          style: TextStyle(fontSize: 11, color: textSecondary)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _globalAutoRecordAll,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (val) {
                    setState(() {
                      _globalAutoRecordAll = val;
                      if (val) {
                        for (final c in _assignedClasses) {
                          _enabledClasses.add(c['id'] as String);
                        }
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Assigned Class Roster & Sections',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: textPrimary)),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () {
                      setState(() {
                        for (final c in _assignedClasses) {
                          _enabledClasses.add(c['id'] as String);
                        }
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: Color(0xFF2563EB)),
                    label: const Text('Enable All',
                        style: TextStyle(
                            fontSize: 11.5, color: Color(0xFF2563EB))),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    onPressed: () {
                      setState(() {
                        _globalAutoRecordAll = false;
                        _enabledClasses.clear();
                      });
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        size: 14, color: Colors.red),
                    label: const Text('Clear All',
                        style: TextStyle(fontSize: 11.5, color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // List of classes
          ..._assignedClasses.map((cls) {
            final id = cls['id'] as String;
            final isEnabled =
                _globalAutoRecordAll || _enabledClasses.contains(id);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isEnabled
                    ? (isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.18)
                        : const Color(0xFFEFF6FF))
                    : (isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isEnabled
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                      : cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cls['icon'] as IconData,
                        size: 18, color: const Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cls['title'] as String,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textPrimary)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(cls['subject'] as String,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.w600)),
                            Text(
                                ' • ${cls['room']} • ${cls['students']} students enrolled',
                                style: TextStyle(
                                    fontSize: 11, color: textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isEnabled,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (val) {
                      setState(() {
                        if (val) {
                          _enabledClasses.add(id);
                        } else {
                          _globalAutoRecordAll = false;
                          _enabledClasses.remove(id);
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: CONDITIONAL QUERY RULES (SHAMIIT QUERY RULES STYLE)
  // ============================================================================
  Widget _buildConditionalQueryRulesTab(bool isDark, Color cardBorder,
      Color textPrimary, Color textSecondary, Color inputFill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Query Expression Preview Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.code_rounded, size: 14, color: Color(0xFF38BDF8)),
                  SizedBox(width: 6),
                  Text('Active Rule Logic Expression:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38BDF8))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _generateExpressionPreview(),
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Multi-line clause editor
        Expanded(
          child: ListView.builder(
            itemCount: _clauses.length,
            itemBuilder: (context, index) {
              final clause = _clauses[index];
              final isFirst = index == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    // Logical Operator (WHERE or AND/OR)
                    SizedBox(
                      width: 82,
                      child: isFirst
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Text('WHERE',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB))),
                              ),
                            )
                          : Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: cardBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: AppSearchableDropdown<
                                    RuleLogicalOperator>.fromMenuItems(
                                  value: clause.logicalOp,
                                  isExpanded: true,
                                  dropdownColor: isDark
                                      ? const Color(0xFF1E222D)
                                      : Colors.white,
                                  items: const [
                                    DropdownMenuItem(
                                      value: RuleLogicalOperator.and,
                                      child: Text('AND',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF3B82F6))),
                                    ),
                                    DropdownMenuItem(
                                      value: RuleLogicalOperator.or,
                                      child: Text('OR',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFF59E0B))),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() => clause.logicalOp = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),

                    // Field Selector
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<RuleField>.fromMenuItems(
                            value: clause.field,
                            isExpanded: true,
                            dropdownColor:
                                isDark ? const Color(0xFF1E222D) : Colors.white,
                            items: RuleField.values.map((f) {
                              return DropdownMenuItem(
                                value: f,
                                child: Text(_getFieldLabel(f),
                                    style: TextStyle(
                                        fontSize: 11.5, color: textPrimary)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => clause.field = v);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Operator Selector
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<
                              RuleConditionOperator>.fromMenuItems(
                            value: clause.operator,
                            isExpanded: true,
                            dropdownColor:
                                isDark ? const Color(0xFF1E222D) : Colors.white,
                            items: RuleConditionOperator.values.map((op) {
                              return DropdownMenuItem(
                                value: op,
                                child: Text(_getOperatorLabel(op),
                                    style: TextStyle(
                                        fontSize: 11, color: textPrimary)),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => clause.operator = v);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Value Input
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 36,
                        child: TextFormField(
                          initialValue: clause.value,
                          onChanged: (v) => setState(() => clause.value = v),
                          style: TextStyle(fontSize: 11.5, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Enter matching text...',
                            hintStyle:
                                TextStyle(fontSize: 11, color: textSecondary),
                            filled: true,
                            fillColor: inputFill,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: cardBorder)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: cardBorder)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Remove clause button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      color: _clauses.length > 1
                          ? Colors.redAccent
                          : textSecondary.withValues(alpha: 0.3),
                      tooltip: 'Remove Condition',
                      onPressed: _clauses.length > 1
                          ? () => _removeClause(index)
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Add condition button
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                    : const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                side: const BorderSide(color: Color(0xFF3B82F6), width: 0.8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _addClause,
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Add Condition / Clause',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Text(
              'Supports complex multi-line criteria for intelligent automated recording triggers.',
              style: TextStyle(fontSize: 11, color: textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  String _generateExpressionPreview() {
    if (_clauses.isEmpty) return 'No conditional rules defined.';
    final buf = StringBuffer();
    for (int i = 0; i < _clauses.length; i++) {
      final c = _clauses[i];
      if (i > 0) {
        buf.write('  ${c.logicalOp.name.toUpperCase()}  ');
      } else {
        buf.write('IF  ');
      }
      buf.write(
          '[${_getFieldLabel(c.field)}] ${_getOperatorLabel(c.operator)} \'${c.value.isEmpty ? "<value>" : c.value}\'');
    }
    buf.write('  =>  [START RECORDING AUTOMATICALLY]');
    return buf.toString();
  }
}

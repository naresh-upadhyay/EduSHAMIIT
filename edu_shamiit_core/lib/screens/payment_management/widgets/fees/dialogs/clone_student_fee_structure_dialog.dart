import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/payment_management_api_service.dart';
import '../../../providers/student_fee_provider.dart';

class CloneStudentFeeStructureDialog extends ConsumerStatefulWidget {
  final String? initialSourceClass;
  final String? initialSourceSection;

  const CloneStudentFeeStructureDialog({
    super.key,
    this.initialSourceClass,
    this.initialSourceSection,
  });

  @override
  ConsumerState<CloneStudentFeeStructureDialog> createState() => _CloneStudentFeeStructureDialogState();
}

class _CloneStudentFeeStructureDialogState extends ConsumerState<CloneStudentFeeStructureDialog> {
  late String _sourceClass;
  late String _sourceSection;
  late String _targetClass;
  late String _targetSection;
  final TextEditingController _markupController = TextEditingController(text: '0');
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sourceClass = widget.initialSourceClass ?? 'Class 10';
    _sourceSection = widget.initialSourceSection ?? 'All Sections';
    _targetClass = 'Class 11';
    _targetSection = 'All Sections';
  }

  @override
  void dispose() {
    _markupController.dispose();
    super.dispose();
  }

  List<String> _getSectionsForClass(String className, StudentFeeState state) {
    if (className == 'All Classes') return ['All Sections'];
    final sList = state.classesWithSections[className];
    if (sList != null && sList.isNotEmpty) {
      return ['All Sections', ...sList];
    }
    return ['All Sections', 'Section A', 'Section B', 'Section C', 'Section D'];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(studentFeeProvider);

    final availableClasses = <String>{};
    for (final c in state.classesList) {
      if (c.isNotEmpty && c != 'All Classes') availableClasses.add(c);
    }
    for (final c in state.classesWithSections.keys) {
      if (c.isNotEmpty && c != 'All Classes') availableClasses.add(c);
    }
    if (availableClasses.isEmpty) {
      availableClasses.addAll(['Class 9', 'Class 10', 'Class 11', 'Class 12']);
    }

    final classList = availableClasses.toList()..sort();
    if (!classList.contains(_sourceClass)) _sourceClass = classList.first;
    if (!classList.contains(_targetClass)) _targetClass = classList.length > 1 ? classList[1] : classList.first;

    final sourceSections = _getSectionsForClass(_sourceClass, state);
    if (!sourceSections.contains(_sourceSection)) _sourceSection = sourceSections.first;

    final targetSections = _getSectionsForClass(_targetClass, state);
    if (!targetSections.contains(_targetSection)) _targetSection = targetSections.first;

    final matchingSourceCount = state.feeStructures.where((f) =>
        (f.classGrade == _sourceClass || f.classGrade == 'All Classes') &&
        (f.sectionName == _sourceSection || f.sectionName == 'All Sections')
    ).length;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.copy_all_rounded, color: Color(0xFF8B5CF6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clone Class Fee Structure',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Duplicate itemized fee schedule to another class or section',
                            style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 24),

              // Source Cohort Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.source_outlined, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text('SOURCE CLASS & SECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sourceClass,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: classList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _sourceClass = val;
                                      _sourceSection = 'All Sections';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sourceSection,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: sourceSections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _sourceSection = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Found $matchingSourceCount active fee heads eligible for cloning',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Arrow Indicator
              const Center(
                child: Icon(Icons.arrow_downward_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(height: 14),

              // Target Cohort Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.output_rounded, size: 14, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 6),
                        Text('TARGET CLASS & SECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Color(0xFF8B5CF6))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _targetClass,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: classList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _targetClass = val;
                                      _targetSection = 'All Sections';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _targetSection,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: targetSections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _targetSection = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Markup Adjustment
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Price Adjustment (% Markup / Discount)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _markupController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            suffixText: '%',
                            hintText: '0 (exact copy) or 5 (+5%)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        'Set 0% for exact replication, or e.g. 5% for standard yearly increase',
                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _submitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.copy_all_rounded, size: 18),
                    label: Text(_submitting ? 'Cloning Fee Schedule...' : 'Clone Fee Structure', style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: _submitting ? null : _clone,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clone() async {
    if (_sourceClass == _targetClass && _sourceSection == _targetSection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target class and section cannot be the same as source.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final markup = double.tryParse(_markupController.text.trim()) ?? 0.0;
    setState(() => _submitting = true);

    final payload = {
      'source_class': _sourceClass,
      'source_section': _sourceSection,
      'target_class': _targetClass,
      'target_section': _targetSection,
      'markup_percent': markup,
    };

    final ok = await PaymentManagementApiService.instance.cloneStudentFeeStructure(payload);

    if (mounted) {
      setState(() => _submitting = false);
      if (ok) {
        Navigator.of(context).pop();
        ref.read(studentFeeProvider.notifier).loadAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fee structure cloned successfully to $_targetClass ($_targetSection)!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clone fee structure. Please check selection.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    }
  }
}

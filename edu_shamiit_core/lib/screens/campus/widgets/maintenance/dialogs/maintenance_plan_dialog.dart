import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/maintenance_provider.dart';

class MaintenancePlanDialog extends ConsumerStatefulWidget {
  const MaintenancePlanDialog({super.key});

  @override
  ConsumerState<MaintenancePlanDialog> createState() =>
      _MaintenancePlanDialogState();
}

class _MaintenancePlanDialogState extends ConsumerState<MaintenancePlanDialog> {
  final _titleController =
      TextEditingController(text: 'AC Annual Servicing & Filter Replacement');
  final _costController = TextEditingController(text: '12500');
  String _category = 'HVAC';
  String _frequency = 'Quarterly';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // Call API via notifier
    await ref.read(maintenanceProvider.notifier).loadPlans();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Maintenance Plan created successfully!'),
          backgroundColor: Color(0xFF16A34A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMaxWidth = math.min(500.0, screenWidth * 0.95);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined,
                      color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Create Preventive Maintenance Plan',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Plan Name *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 460;

                  if (isCompact) {
                    return Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          dropdownColor: bg,
                          items: const [
                            DropdownMenuItem(
                                value: 'HVAC', child: Text('HVAC (AC)')),
                            DropdownMenuItem(
                                value: 'Electrical', child: Text('Electrical')),
                            DropdownMenuItem(
                                value: 'Plumbing', child: Text('Plumbing')),
                            DropdownMenuItem(
                                value: 'Civil', child: Text('Civil')),
                            DropdownMenuItem(
                                value: 'AV Equipment',
                                child: Text('AV Equipment')),
                          ],
                          onChanged: (v) =>
                              setState(() => _category = v ?? 'HVAC'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _frequency,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          dropdownColor: bg,
                          items: const [
                            DropdownMenuItem(
                                value: 'Daily', child: Text('Daily')),
                            DropdownMenuItem(
                                value: 'Weekly', child: Text('Weekly')),
                            DropdownMenuItem(
                                value: 'Monthly', child: Text('Monthly')),
                            DropdownMenuItem(
                                value: 'Quarterly', child: Text('Quarterly')),
                            DropdownMenuItem(
                                value: 'Annually', child: Text('Annually')),
                          ],
                          onChanged: (v) =>
                              setState(() => _frequency = v ?? 'Quarterly'),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            dropdownColor: bg,
                            items: const [
                              DropdownMenuItem(
                                  value: 'HVAC', child: Text('HVAC (AC)')),
                              DropdownMenuItem(
                                  value: 'Electrical',
                                  child: Text('Electrical')),
                              DropdownMenuItem(
                                  value: 'Plumbing', child: Text('Plumbing')),
                              DropdownMenuItem(
                                  value: 'Civil', child: Text('Civil')),
                              DropdownMenuItem(
                                  value: 'AV Equipment',
                                  child: Text('AV Equipment')),
                            ],
                            onChanged: (v) =>
                                setState(() => _category = v ?? 'HVAC'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _frequency,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Frequency',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            dropdownColor: bg,
                            items: const [
                              DropdownMenuItem(
                                  value: 'Daily', child: Text('Daily')),
                              DropdownMenuItem(
                                  value: 'Weekly', child: Text('Weekly')),
                              DropdownMenuItem(
                                  value: 'Monthly', child: Text('Monthly')),
                              DropdownMenuItem(
                                  value: 'Quarterly', child: Text('Quarterly')),
                              DropdownMenuItem(
                                  value: 'Annually', child: Text('Annually')),
                            ],
                            onChanged: (v) =>
                                setState(() => _frequency = v ?? 'Quarterly'),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Estimated Cost (₹)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Plan',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

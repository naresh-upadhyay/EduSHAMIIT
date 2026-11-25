import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class CreateOfferDialog extends StatefulWidget {
  final String applicationId;
  final String candidateName;
  final String jobTitle;
  final VoidCallback onOfferCreated;

  const CreateOfferDialog({
    super.key,
    required this.applicationId,
    required this.candidateName,
    required this.jobTitle,
    required this.onOfferCreated,
  });

  @override
  State<CreateOfferDialog> createState() => _CreateOfferDialogState();
}

class _CreateOfferDialogState extends State<CreateOfferDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _salaryController = TextEditingController(text: '65000');
  final TextEditingController _probationController = TextEditingController(text: '6');
  final TextEditingController _benefitsController = TextEditingController(
    text: 'Health Insurance, Provident Fund, Annual Performance Bonus, Gratuity',
  );
  final TextEditingController _termsController = TextEditingController(
    text: 'Standard institute employment terms, subject to document verification and background check.',
  );
  final TextEditingController _notesController = TextEditingController();

  DateTime _joiningDate = DateTime.now().add(const Duration(days: 30));
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));
  String _employmentType = 'Full-time';
  bool _sendImmediately = false;
  bool _isSubmitting = false;

  List<String> _employmentTypes = HRLookupHelper.instance.getCachedLabels('EMPLOYMENT_TYPE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadLookups(true);
    _salaryController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final types = await HRLookupHelper.instance.getLookupLabels('EMPLOYMENT_TYPE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _employmentTypes = types;
        if (!_employmentTypes.contains(_employmentType) && _employmentTypes.isNotEmpty) {
          _employmentType = _employmentTypes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _salaryController.dispose();
    _probationController.dispose();
    _benefitsController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectJoiningDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _joiningDate = picked);
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _submitOffer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final salary = double.tryParse(_salaryController.text.trim()) ?? 0.0;
      final probation = int.tryParse(_probationController.text.trim()) ?? 6;

      final payload = {
        'application_id': widget.applicationId,
        'salary': salary,
        'joining_date': DateFormat('yyyy-MM-dd').format(_joiningDate),
        'probation_period_months': probation,
        'employment_type': _employmentType,
        'offer_expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate),
        'benefits': _benefitsController.text.trim().isEmpty ? null : _benefitsController.text.trim(),
        'terms': _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'send_immediately': _sendImmediately,
      };

      await _apiService.post('/recruitment/offers', payload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sendImmediately
                  ? 'Job offer generated and formal offer email dispatched to ${widget.candidateName}!'
                  : 'Job offer drafted successfully for ${widget.candidateName}!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onOfferCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating offer: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0.0;
    final annualCtc = salary * 12;
    final inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_offer_rounded, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Generate Employment Offer',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.candidateName} • ${widget.jobTitle}',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Real-time CTC Preview Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly Compensation',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inrFormat.format(salary),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                            Container(
                              height: 32,
                              width: 1,
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Calculated Annual CTC',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inrFormat.format(annualCtc),
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Compensation & Type
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _salaryController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Offered Monthly Salary (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee_rounded),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Salary is required';
                                if (double.tryParse(val) == null) return 'Enter valid amount';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 3,
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _employmentTypes.contains(_employmentType) ? _employmentType : (_employmentTypes.isNotEmpty ? _employmentTypes.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Employment Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: _employmentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _employmentType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dates: Joining Date & Offer Expiry Date
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectJoiningDate,
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expected Joining Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today_outlined),
                                ),
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(_joiningDate),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: InkWell(
                              onTap: _selectExpiryDate,
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Offer Expiry Date',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event_busy_outlined),
                                ),
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(_expiryDate),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Probation Months
                      TextFormField(
                        controller: _probationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Probation Period (Months)',
                          suffixText: 'Months',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.hourglass_bottom_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Benefits
                      TextFormField(
                        controller: _benefitsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Key Benefits & Allowances',
                          hintText: 'e.g. Health Insurance, Provident Fund, Performance Bonus...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Terms
                      TextFormField(
                        controller: _termsController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Offer Terms & Conditions',
                          hintText: 'Standard institute terms...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Immediate Dispatch Checkbox Card
                      Material(
                        color: _sendImmediately
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _sendImmediately
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: const Text(
                            'Dispatch Formal Offer Letter via Email Immediately',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            _sendImmediately
                                ? 'Status will be "Sent" and candidate will immediately receive the full employment offer letter.'
                                : 'Offer will be saved as "Draft". You can review and email it at any time.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                          value: _sendImmediately,
                          activeTrackColor: const Color(0xFF10B981),
                          onChanged: (val) => setState(() => _sendImmediately = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitOffer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_sendImmediately ? Icons.send_rounded : Icons.save_outlined, size: 18),
                    label: Text(
                      _isSubmitting
                          ? 'Generating...'
                          : (_sendImmediately ? 'Create & Dispatch Offer' : 'Save Offer as Draft'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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

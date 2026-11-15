import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';

class HostelVisitorLogDialog extends ConsumerStatefulWidget {
  const HostelVisitorLogDialog({super.key});

  @override
  ConsumerState<HostelVisitorLogDialog> createState() => _HostelVisitorLogDialogState();
}

class _HostelVisitorLogDialogState extends ConsumerState<HostelVisitorLogDialog> {
  List<Map<String, dynamic>> _visitors = [];
  bool _isLoading = true;
  bool _isLoggingNew = false;

  // New visitor form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController(text: 'Parent');
  final _idProofCtrl = TextEditingController(text: 'Aadhar Card');
  final _idNumberCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController(text: 'Family Visit');
  final _vehicleCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController(text: 'V-101');

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationshipCtrl.dispose();
    _idProofCtrl.dispose();
    _idNumberCtrl.dispose();
    _purposeCtrl.dispose();
    _vehicleCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() => _isLoading = true);
    try {
      final list = await ref.read(hostelProvider.notifier).service.getHostelVisitors();
      if (mounted) {
        setState(() {
          _visitors = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkoutVisitor(String id) async {
    final notifier = ref.read(hostelProvider.notifier);
    try {
      final res = await notifier.service.checkoutHostelVisitor(id);
      if (mounted && res['success'] == true) {
        notifier.showSuccess('Visitor checked out successfully');
        _loadVisitors();
      }
    } catch (e) {
      if (mounted) notifier.showError('Error: $e');
    }
  }

  Future<void> _saveNewVisitor() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(hostelProvider.notifier);
    final payload = {
      'visitor_name': _nameCtrl.text.trim(),
      'visitor_phone': _phoneCtrl.text.trim(),
      'relationship': _relationshipCtrl.text.trim(),
      'id_proof_type': _idProofCtrl.text.trim(),
      'id_proof_number': _idNumberCtrl.text.trim(),
      'purpose': _purposeCtrl.text.trim(),
      'vehicle_number': _vehicleCtrl.text.trim(),
      'badge_number': _badgeCtrl.text.trim(),
    };

    try {
      final res = await notifier.service.logHostelVisitor(payload);
      if (mounted && res['success'] == true) {
        notifier.showSuccess('Visitor pass issued successfully');
        setState(() => _isLoggingNew = false);
        _nameCtrl.clear();
        _phoneCtrl.clear();
        _idNumberCtrl.clear();
        _vehicleCtrl.clear();
        _loadVisitors();
      }
    } catch (e) {
      if (mounted) notifier.showError('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 840,
        height: 680,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.badge_rounded, color: Color(0xFF0D9488), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor Logbook & Campus Entry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Authorized guardian entries, day passes & security gate registers',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isLoggingNew = !_isLoggingNew),
                  icon: Icon(_isLoggingNew ? Icons.view_list_rounded : Icons.person_add_rounded, size: 16),
                  label: Text(_isLoggingNew ? 'View Visitors' : 'Issue Pass'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Content Body
            Expanded(
              child: _isLoggingNew ? _buildNewVisitorForm(isDark) : _buildVisitorsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorsList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_visitors.isEmpty) {
      return const Center(child: Text('No visitor records logged today'));
    }

    return ListView.separated(
      itemCount: _visitors.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final v = _visitors[i];
        final isActive = v['status'] == 'ACTIVE';
        final checkIn = v['check_in_time']?.toString().substring(11, 16) ?? '10:00';
        final checkOut = v['check_out_time'] != null ? v['check_out_time'].toString().substring(11, 16) : '-';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFDCFCE7) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    v['badge_number'] ?? 'VIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          v['visitor_name'] ?? 'Visitor',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v['relationship'] ?? 'Parent',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Phone: ${v['visitor_phone']}  |  Vehicle: ${v['vehicle_number'] ?? 'None'}  |  Purpose: ${v['purpose']}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'In: $checkIn | Out: $checkOut',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  if (isActive)
                    ElevatedButton(
                      onPressed: () => _checkoutVisitor(v['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Check Out', style: TextStyle(fontSize: 11)),
                    )
                  else
                    const Text('Completed', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewVisitorForm(bool isDark) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Visitor Full Name *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Contact Phone Number *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _relationshipCtrl,
                    decoration: const InputDecoration(labelText: 'Relationship (Parent, Brother, etc.)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _badgeCtrl,
                    decoration: const InputDecoration(labelText: 'Visitor Badge Number', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _idProofCtrl,
                    decoration: const InputDecoration(labelText: 'ID Proof Type', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _idNumberCtrl,
                    decoration: const InputDecoration(labelText: 'ID Proof Number', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purposeCtrl,
                    decoration: const InputDecoration(labelText: 'Purpose of Visit', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vehicleCtrl,
                    decoration: const InputDecoration(labelText: 'Vehicle Number (Optional)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isLoggingNew = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _saveNewVisitor,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Save & Issue Pass'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

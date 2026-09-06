import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/member_provider.dart';

class ImportMembersDialog extends ConsumerStatefulWidget {
  const ImportMembersDialog({super.key});

  @override
  ConsumerState<ImportMembersDialog> createState() => _ImportMembersDialogState();
}

class _ImportMembersDialogState extends ConsumerState<ImportMembersDialog> {
  int _currentStep = 0;
  final TextEditingController _csvInputCtrl = TextEditingController();
  bool _isValidating = false;
  bool _isImporting = false;
  Map<String, dynamic>? _validationResult;
  Map<String, dynamic>? _importResult;

  final String _sampleCsvTemplate = '''email,phone,admission_number,membership_type,borrowing_limit,max_issue_duration_days
aarav.sharma@example.com,+91 98765 43210,STD-2025-001,Student,3,14
diya.singh@example.com,+91 98765 43211,STD-2025-002,Student,3,14
rohit.verma@example.com,+91 98765 43212,EMP-1001,Teacher,5,30
neha.gupta@example.com,+91 98765 43213,EMP-1002,Staff,3,14''';

  @override
  void initState() {
    super.initState();
    _csvInputCtrl.text = _sampleCsvTemplate;
  }

  @override
  void dispose() {
    _csvInputCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseCsv(String text) {
    final lines = text.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];

    final headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    final records = <Map<String, dynamic>>[];

    for (int i = 1; i < lines.length; i++) {
      final values = lines[i].split(',').map((v) => v.trim().replaceAll('"', '')).toList();
      final map = <String, dynamic>{};
      for (int h = 0; h < headers.length; h++) {
        if (h < values.length) {
          map[headers[h]] = values[h];
        }
      }
      records.add(map);
    }
    return records;
  }

  Future<void> _validateData() async {
    final rows = _parseCsv(_csvInputCtrl.text);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste valid CSV data with header row.')),
      );
      return;
    }

    setState(() => _isValidating = true);
    try {
      final api = ref.read(memberApiServiceProvider);
      final res = await api.importMembers(rows, mode: 'PREVIEW');
      setState(() {
        _validationResult = res;
        _currentStep = 1;
        _isValidating = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isValidating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _executeImport() async {
    final rows = _parseCsv(_csvInputCtrl.text);
    setState(() => _isImporting = true);

    try {
      final api = ref.read(memberApiServiceProvider);
      final res = await api.importMembers(rows, mode: 'COMMIT');
      if (mounted) {
        setState(() {
          _importResult = res;
          _currentStep = 2;
          _isImporting = false;
        });
        ref.read(memberProvider.notifier).fetchMembers(resetPage: true);
        ref.read(memberProvider.notifier).fetchStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.file_upload_outlined, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Import Library Members from CSV', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                        Text('Batch create memberships linked to existing profiles.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: _currentStep == 0
                  ? _buildStep0Input(isDark)
                  : (_currentStep == 1 ? _buildStep1Preview(isDark) : _buildStep2Result(isDark)),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentStep == 1)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Edit CSV Data'),
                      onPressed: () => setState(() => _currentStep = 0),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_currentStep == 2 ? 'Done' : 'Cancel'),
                  ),
                  const SizedBox(width: 10),
                  if (_currentStep == 0)
                    ElevatedButton.icon(
                      icon: _isValidating
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded, size: 17),
                      label: const Text('Validate & Preview', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                      onPressed: _isValidating ? null : _validateData,
                    )
                  else if (_currentStep == 1)
                    ElevatedButton.icon(
                      icon: _isImporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_rounded, size: 17),
                      label: const Text('Commit Import', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: _isImporting ? null : _executeImport,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0Input(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Paste CSV Content (with columns: email/phone/admission_number, membership_type, borrowing_limit)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _csvInputCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Preview(bool isDark) {
    final res = _validationResult ?? {};
    final validRows = (res['valid_rows'] as List?) ?? [];
    final invalidRows = (res['invalid_rows'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${validRows.length} Valid Profiles Ready',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (invalidRows.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${invalidRows.length} Errors / Duplicates',
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Preview Records:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: validRows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, idx) {
                final r = validRows[idx];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        r['full_name']?.toString() ?? r['email']?.toString() ?? 'Profile',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                      Text(
                        'Type: ${r['membership_type']} • Limit: ${r['borrowing_limit']}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Result(bool isDark) {
    final res = _importResult ?? {};
    final imported = res['imported_count'] ?? 0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 48, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 16),
          Text(
            '$imported Member(s) Successfully Imported!',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text('All memberships are now active and ready for book circulation.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      ),
    );
  }
}

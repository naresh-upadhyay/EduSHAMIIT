import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart';

class ImportBooksDialog extends ConsumerStatefulWidget {
  const ImportBooksDialog({super.key});

  @override
  ConsumerState<ImportBooksDialog> createState() => _ImportBooksDialogState();
}

class _ImportBooksDialogState extends ConsumerState<ImportBooksDialog> {
  int _currentStep = 0;
  final TextEditingController _csvInputCtrl = TextEditingController();
  bool _isValidating = false;
  bool _isImporting = false;
  Map<String, dynamic>? _validationResult;
  Map<String, dynamic>? _importResult;

  final String _sampleCsvTemplate = '''Title,Author,Category,ISBN,Year,Copies,Rack,Shelf,Price,Supplier
The Psychology of Money,Morgan Housel,Finance,978-9390166268,2020,4,Rack A,Shelf 1,299.00,Sapna Book House
Atomic Habits,James Clear,Self Help,978-1847941831,2018,5,Rack A,Shelf 2,399.00,Amazon Business
Wings of Fire,A.P.J. Abdul Kalam,Biography,978-8179925938,1999,3,Rack A,Shelf 3,250.00,Orient Blackswan
The Alchemist,Paulo Coelho,Fiction,978-8172234984,2005,6,Rack B,Shelf 1,275.00,Harper Collins''';

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
        const SnackBar(content: Text('Please enter valid CSV data with header row.')),
      );
      return;
    }

    setState(() => _isValidating = true);
    try {
      final notifier = ref.read(bookProvider.notifier);
      final res = await notifier.importBooks(rows, mode: 'PREVIEW');
      setState(() {
        _isValidating = false;
        _validationResult = res;
        _currentStep = 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isValidating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _commitImport() async {
    final rows = _parseCsv(_csvInputCtrl.text);
    setState(() => _isImporting = true);
    try {
      final notifier = ref.read(bookProvider.notifier);
      final res = await notifier.importBooks(rows, mode: 'COMMIT');
      if (mounted) {
        setState(() {
          _isImporting = false;
          _importResult = res;
          _currentStep = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red),
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
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.upload_file_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Import Books Catalogue (CSV / XLSX)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Stepper Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  _buildStepIndicator(0, '1. Upload Data', isDark),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 16),
                  _buildStepIndicator(1, '2. Validate & Preview', isDark),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 16),
                  _buildStepIndicator(2, '3. Summary Report', isDark),
                ],
              ),
            ),

            // Step Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(isDark),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentStep > 0 && _currentStep < 2)
                    TextButton(
                      onPressed: () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_currentStep == 2 ? 'Done' : 'Cancel'),
                  ),
                  const SizedBox(width: 12),
                  if (_currentStep == 0)
                    ElevatedButton.icon(
                      icon: _isValidating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('Validate & Preview'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isValidating ? null : _validateData,
                    )
                  else if (_currentStep == 1)
                    ElevatedButton.icon(
                      icon: _isImporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_rounded, size: 16),
                      label: const Text('Confirm Import'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isImporting ? null : _commitImport,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label, bool isDark) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: isDone ? const Color(0xFF10B981) : (isActive ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
          child: Text(
            isDone ? '✓' : '${stepIndex + 1}',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep(bool isDark) {
    if (_currentStep == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Paste or upload CSV text content:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Reset to Sample', style: TextStyle(fontSize: 11.5)),
                onPressed: () => setState(() => _csvInputCtrl.text = _sampleCsvTemplate),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _csvInputCtrl,
              maxLines: null,
              expands: true,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      final summary = _validationResult?['summary'] as Map<String, dynamic>? ?? {};
      final preview = (_validationResult?['preview'] as List?) ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics summary
          Row(
            children: [
              _buildMetricChip('Total Records', '${summary['total_processed'] ?? 0}', const Color(0xFF6366F1), isDark),
              const SizedBox(width: 8),
              _buildMetricChip('Valid to Import', '${summary['imported_count'] ?? 0}', const Color(0xFF10B981), isDark),
              const SizedBox(width: 8),
              _buildMetricChip('Duplicate ISBNs', '${summary['duplicates_count'] ?? 0}', const Color(0xFFF59E0B), isDark),
              const SizedBox(width: 8),
              _buildMetricChip('Invalid Rows', '${summary['invalid_count'] ?? 0}', const Color(0xFFEF4444), isDark),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Previewing Valid Records:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: preview.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final item = preview[idx];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                  title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                  subtitle: Text('${item['author']} • ${item['category_name']} • ISBN: ${item['isbn13']}', style: const TextStyle(fontSize: 11)),
                  trailing: Text('${item['copies_count']} copies', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
        ],
      );
    } else {
      final summary = _importResult?['summary'] as Map<String, dynamic>? ?? {};
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_rounded, color: Color(0xFF10B981), size: 56),
            const SizedBox(height: 16),
            const Text(
              'Books Import Completed Successfully!',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary['imported_count'] ?? 0} books and copies were created in your catalogue.',
              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildMetricChip(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

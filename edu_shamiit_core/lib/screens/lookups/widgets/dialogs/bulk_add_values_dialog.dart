import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lookup_models.dart';
import '../../providers/lookup_provider.dart';

class BulkAddValuesDialog extends ConsumerStatefulWidget {
  final LookupKeyModel lookupKey;

  const BulkAddValuesDialog({super.key, required this.lookupKey});

  @override
  ConsumerState<BulkAddValuesDialog> createState() => _BulkAddValuesDialogState();
}

class _BulkAddValuesDialogState extends ConsumerState<BulkAddValuesDialog> {
  final TextEditingController _textController = TextEditingController();
  List<Map<String, String>> _parsedItems = [];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_parseInput);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseInput() {
    final text = _textController.text;
    final lines = text.split('\n');
    final List<Map<String, String>> items = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      String name = trimmed;
      String code = '';

      if (trimmed.contains(',')) {
        final parts = trimmed.split(',');
        name = parts[0].trim();
        if (parts.length > 1) code = parts[1].trim().toUpperCase();
      }

      if (code.isEmpty) {
        code = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
      }

      items.add({
        'value_name': name,
        'value_code': code,
        'status': 'ACTIVE',
      });
    }

    setState(() {
      _parsedItems = items;
    });
  }

  Future<void> _submit() async {
    if (_parsedItems.isEmpty) return;

    try {
      final res = await ref.read(lookupProvider.notifier).bulkAddValues(_parsedItems);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Bulk values imported successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk import error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(lookupProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bulk Add Values',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Paste multiple items (one per line) for ${widget.lookupKey.keyName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Paste List of Values',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format: "Value Name" or "Value Name, CODE"',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'Cricket\nFootball, SOCCER_01\nBasketball\nBadminton, BADMINTON',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preview
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Parsed Preview (${_parsedItems.length} items)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: _parsedItems.isEmpty
                            ? Center(
                                child: Text(
                                  'Paste or type lines above to preview parsed items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: _parsedItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (ctx, idx) {
                                  final item = _parsedItems[idx];
                                  return Row(
                                    children: [
                                      Text(
                                        '#${idx + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['value_name']!,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['value_code']!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: state.isSaving || _parsedItems.isEmpty ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: state.isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Import ${_parsedItems.length} Values', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lookup_models.dart';
import '../../providers/lookup_provider.dart';

class DeleteLookupConfirmationDialog extends ConsumerStatefulWidget {
  final LookupKeyModel lookupKey;

  const DeleteLookupConfirmationDialog({super.key, required this.lookupKey});

  @override
  ConsumerState<DeleteLookupConfirmationDialog> createState() => _DeleteLookupConfirmationDialogState();
}

class _DeleteLookupConfirmationDialogState extends ConsumerState<DeleteLookupConfirmationDialog> {
  bool _isLoading = false;
  String? _usageWarning;

  Future<void> _handleDelete({bool forceDeactivate = false}) async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(lookupProvider.notifier).deleteLookupKey(
        widget.lookupKey.id,
        forceDeactivate: forceDeactivate,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Lookup key processed successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _usageWarning = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUsage = widget.lookupKey.usage.totalRecords > 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Delete Lookup Key',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.lookupKey.keyName}" (${widget.lookupKey.keyCode})?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 12),
            if (hasUsage || _usageWarning != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'In-Use Across ERP Modules',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.amber),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This lookup key is currently referenced by ${widget.lookupKey.usage.totalRecords} records across ${widget.lookupKey.usage.modulesCount} modules. Deleting it will break historical records.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'This action will permanently delete this key and all its associated values.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (hasUsage || _usageWarning != null)
          ElevatedButton(
            onPressed: _isLoading ? null : () => _handleDelete(forceDeactivate: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate Instead', style: TextStyle(fontWeight: FontWeight.w700)),
          )
        else
          ElevatedButton(
            onPressed: _isLoading ? null : () => _handleDelete(forceDeactivate: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class DeleteLookupValueDialog extends ConsumerStatefulWidget {
  final LookupKeyModel lookupKey;
  final LookupValueModel value;

  const DeleteLookupValueDialog({super.key, required this.lookupKey, required this.value});

  @override
  ConsumerState<DeleteLookupValueDialog> createState() => _DeleteLookupValueDialogState();
}

class _DeleteLookupValueDialogState extends ConsumerState<DeleteLookupValueDialog> {
  bool _isLoading = false;

  Future<void> _handleDelete({bool forceDeactivate = false}) async {
    setState(() => _isLoading = true);
    try {
      final res = await ref.read(lookupProvider.notifier).deleteValue(
        widget.value.id,
        forceDeactivate: forceDeactivate,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Value processed successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            'Delete Value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete "${widget.value.valueName}" (${widget.value.valueCode})?',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _handleDelete(forceDeactivate: false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

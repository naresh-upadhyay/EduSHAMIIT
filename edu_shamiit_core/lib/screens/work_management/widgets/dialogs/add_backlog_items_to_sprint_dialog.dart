import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/work_models.dart';
import '../../providers/work_management_provider.dart';

class AddBacklogItemsToSprintDialog extends ConsumerStatefulWidget {
  final String sprintId;

  const AddBacklogItemsToSprintDialog({
    super.key,
    required this.sprintId,
  });

  @override
  ConsumerState<AddBacklogItemsToSprintDialog> createState() => _AddBacklogItemsToSprintDialogState();
}

class _AddBacklogItemsToSprintDialogState extends ConsumerState<AddBacklogItemsToSprintDialog> {
  final Set<String> _selectedItemIds = {};
  String _searchQuery = '';
  bool _isLoading = true;
  List<WorkItemModel> _backlogItems = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchBacklog();
  }

  Future<void> _fetchBacklog() async {
    try {
      final api = ref.read(workApiServiceProvider);
      final res = await api.getBacklogTree(pageSize: 50);
      final items = (res['items'] as List<WorkItemModel>?) ?? [];
      if (mounted) {
        setState(() {
          _backlogItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedItemIds.isEmpty) return;
    setState(() => _isSubmitting = true);

    final notifier = ref.read(workSprintDashboardProvider.notifier);
    final success = await notifier.addItemsToSprint(widget.sprintId, _selectedItemIds.toList());

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add items to sprint')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _backlogItems.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.title.toLowerCase().contains(q) || i.itemNumber.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Items from Backlog to Sprint',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
              Divider(color: isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Search field
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search backlog by title or ID...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedItemIds.length} items selected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedItemIds.length == filtered.length) {
                          _selectedItemIds.clear();
                        } else {
                          _selectedItemIds.addAll(filtered.map((e) => e.id));
                        }
                      });
                    },
                    child: Text(_selectedItemIds.length == filtered.length ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('No backlog items found.'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              final isSelected = _selectedItemIds.contains(item.id);

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedItemIds.add(item.id);
                                    } else {
                                      _selectedItemIds.remove(item.id);
                                    }
                                  });
                                },
                                dense: true,
                                title: Row(
                                  children: [
                                    Text(
                                      item.itemNumber,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${item.workType} • ${item.priority} • ${item.category}',
                                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _selectedItemIds.isEmpty || _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Add to Sprint (${_selectedItemIds.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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

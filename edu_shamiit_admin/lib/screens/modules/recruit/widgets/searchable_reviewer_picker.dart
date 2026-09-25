import 'package:flutter/material.dart';

class SearchableReviewerPicker extends StatefulWidget {
  final List<Map<String, dynamic>> candidateReviewers;
  final Map<String, dynamic>? selectedReviewer;
  final ValueChanged<Map<String, dynamic>?> onReviewerSelected;

  const SearchableReviewerPicker({
    super.key,
    required this.candidateReviewers,
    required this.selectedReviewer,
    required this.onReviewerSelected,
  });

  @override
  State<SearchableReviewerPicker> createState() => _SearchableReviewerPickerState();
}

class _SearchableReviewerPickerState extends State<SearchableReviewerPicker> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedReviewer;
  }

  @override
  void didUpdateWidget(covariant SearchableReviewerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedReviewer != oldWidget.selectedReviewer) {
      setState(() {
        _selected = widget.selectedReviewer;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredCandidates {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.candidateReviewers;
    return widget.candidateReviewers.where((emp) {
      final name = (emp['full_name'] ?? emp['name'] ?? '').toString().toLowerCase();
      final email = (emp['email'] ?? '').toString().toLowerCase();
      final role = (emp['role'] ?? '').toString().toLowerCase();
      final dept = (emp['department'] ?? '').toString().toLowerCase();
      final desig = (emp['designation'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.contains(q) || dept.contains(q) || desig.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 1. If reviewer is selected and not actively searching for a replacement
    if (_selected != null && !_isSearching) {
      final name = _selected!['full_name'] ?? _selected!['name'] ?? _selected!['email'] ?? 'Staff Reviewer';
      final email = _selected!['email'] ?? '';
      final role = _selected!['role'] ?? 'Reviewer';
      final dept = _selected!['department'] ?? 'General';
      final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'R';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF4F46E5),
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dept.isNotEmpty ? '$dept · $email' : email,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF4F46E5)),
              label: const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Search Field + Filtered Reviewer Dropdown/List
    final candidates = _filteredCandidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _searchController,
          autofocus: _isSearching,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search reviewer by name, email, role, or department...',
            hintStyle: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF4F46E5)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : (_isSearching && _selected != null
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                          });
                        },
                      )
                    : null),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: candidates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No staff members found'
                          : 'No reviewers found matching "${_searchController.text.trim()}"',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),
                  itemBuilder: (context, index) {
                    final emp = candidates[index];
                    final name = emp['full_name'] ?? emp['name'] ?? emp['email'] ?? 'Staff';
                    final role = emp['role'] ?? 'Staff';
                    final dept = emp['department'] ?? 'General';
                    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'R';
                    final isCurrent = _selected != null && _selected!['id'] == emp['id'];

                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF4F46E5),
                        child: Text(
                          initial,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$role · $dept',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
                          : const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                      onTap: () {
                        setState(() {
                          _selected = emp;
                          _isSearching = false;
                          _searchController.clear();
                        });
                        widget.onReviewerSelected(emp);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

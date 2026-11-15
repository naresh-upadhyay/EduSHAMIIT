import 'package:flutter/material.dart';

/// Reusable enterprise searchable & creatable dropdown selector.
/// Supports selecting from dynamic lookups or typing a new value that
/// automatically gets added to the database & Lookup Management key-value table.
/// Provides both a Searchable Picker Modal and Direct Inline Manual Entry.
class InventorySearchableDropdown<T> extends StatefulWidget {
  final String label;
  final String? value;
  final String hint;
  final List<T> items;
  final String Function(T item) getItemId;
  final String Function(T item) getItemName;
  final String? Function(T item)? getItemSubtitle;
  final String? Function(T item)? getItemBadge;
  final ValueChanged<String?> onChanged;
  final Future<String?> Function(String enteredText)? onQuickAdd;
  final String? Function(String?)? validator;
  final bool isRequired;
  final bool allowManualEntry;
  final String? quickAddLabel;
  final IconData? prefixIcon;

  const InventorySearchableDropdown({
    super.key,
    required this.label,
    required this.value,
    this.hint = 'Select or type to search...',
    required this.items,
    required this.getItemId,
    required this.getItemName,
    this.getItemSubtitle,
    this.getItemBadge,
    required this.onChanged,
    this.onQuickAdd,
    this.validator,
    this.isRequired = false,
    this.allowManualEntry = true,
    this.quickAddLabel,
    this.prefixIcon,
  });

  @override
  State<InventorySearchableDropdown<T>> createState() => _InventorySearchableDropdownState<T>();
}

class _InventorySearchableDropdownState<T> extends State<InventorySearchableDropdown<T>> {
  bool _manualMode = false;
  late TextEditingController _manualTextCtrl;
  bool _isSavingManual = false;

  @override
  void initState() {
    super.initState();
    _manualTextCtrl = TextEditingController(text: _resolveInitialText());
  }

  @override
  void didUpdateWidget(covariant InventorySearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newText = _resolveInitialText();
      if (_manualTextCtrl.text != newText) {
        _manualTextCtrl.text = newText;
      }
    }
  }

  String _resolveInitialText() {
    if (widget.value == null || widget.value!.isEmpty) return '';
    for (final it in widget.items) {
      final id = widget.getItemId(it);
      final name = widget.getItemName(it);
      if (id == widget.value || id.toLowerCase() == widget.value!.toLowerCase()) {
        return name;
      }
    }
    return widget.value!;
  }

  @override
  void dispose() {
    _manualTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _commitManualText(String text, FormFieldState<String> formState) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      formState.didChange(null);
      return;
    }

    // Check if trimmed matches an existing item by name or id
    for (final it in widget.items) {
      final id = widget.getItemId(it);
      final name = widget.getItemName(it);
      if (name.toLowerCase() == trimmed.toLowerCase() || id.toLowerCase() == trimmed.toLowerCase()) {
        widget.onChanged(id);
        formState.didChange(id);
        return;
      }
    }

    // If new and onQuickAdd is provided, automatically add to Lookups
    if (widget.onQuickAdd != null) {
      setState(() => _isSavingManual = true);
      try {
        final newId = await widget.onQuickAdd!(trimmed);
        final finalVal = newId ?? trimmed;
        widget.onChanged(finalVal);
        formState.didChange(finalVal);
      } finally {
        if (mounted) setState(() => _isSavingManual = false);
      }
    } else {
      widget.onChanged(trimmed);
      formState.didChange(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find currently selected item
    T? selectedItem;
    if (widget.value != null && widget.value!.isNotEmpty) {
      for (final it in widget.items) {
        final id = widget.getItemId(it);
        final name = widget.getItemName(it);
        if (id == widget.value || name.toLowerCase() == widget.value!.toLowerCase() || id.toLowerCase() == widget.value!.toLowerCase()) {
          selectedItem = it;
          break;
        }
      }
    }

    final displayText = selectedItem != null
        ? widget.getItemName(selectedItem)
        : (widget.value != null && widget.value!.isNotEmpty ? widget.value! : widget.hint);

    final isPlaceholder = selectedItem == null && (widget.value == null || widget.value!.isEmpty);

    return FormField<String>(
      initialValue: widget.value,
      validator: widget.validator ??
          (widget.isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? '${widget.label} is required' : null
              : null),
      builder: (formFieldState) {
        final hasError = formFieldState.hasError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Label + Manual Entry Toggle
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isRequired && !widget.label.endsWith('*') ? '${widget.label} *' : widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                if (widget.allowManualEntry) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _manualMode = !_manualMode;
                        if (_manualMode) {
                          _manualTextCtrl.text = selectedItem != null
                              ? widget.getItemName(selectedItem)
                              : (widget.value ?? '');
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _manualMode ? Icons.list_alt_rounded : Icons.edit_note_rounded,
                            size: 15,
                            color: const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _manualMode ? 'Select' : '+ Manual',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),

            if (_manualMode) ...[
              // Direct Inline Manual Input Mode
              TextFormField(
                controller: _manualTextCtrl,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
                decoration: InputDecoration(
                  hintText: 'Type new ${widget.label.replaceAll('*', '').trim().toLowerCase()}...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: 'Inter'),
                  prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 18, color: const Color(0xFF64748B)) : null,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSavingManual)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                          ),
                        )
                      else ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
                          tooltip: 'Save to Lookups & Select',
                          onPressed: () => _commitManualText(_manualTextCtrl.text, formFieldState),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Cancel & Switch to List',
                          onPressed: () => setState(() => _manualMode = false),
                        ),
                      ],
                    ],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
                onFieldSubmitted: (text) => _commitManualText(text, formFieldState),
                onChanged: (text) {
                  formFieldState.didChange(text);
                  widget.onChanged(text);
                },
              ),
            ] else ...[
              // Dropdown Selection Mode (Click opens Searchable Modal Picker)
              InkWell(
                onTap: () => _openSearchDialog(context, isDark, formFieldState),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasError
                          ? const Color(0xFFEF4444)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null) ...[
                        Icon(widget.prefixIcon, size: 18, color: const Color(0xFF64748B)),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          displayText,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: isPlaceholder
                                ? const Color(0xFF94A3B8)
                                : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                            fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.value != null && widget.value!.isNotEmpty) ...[
                        InkWell(
                          onTap: () {
                            formFieldState.didChange(null);
                            widget.onChanged(null);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (hasError) ...[
              const SizedBox(height: 5),
              Text(
                formFieldState.errorText ?? '',
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontFamily: 'Inter'),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openSearchDialog(BuildContext context, bool isDark, FormFieldState<String> formState) {
    showDialog(
      context: context,
      builder: (ctx) => _SearchablePickerModal<T>(
        title: widget.label.replaceAll('*', '').trim(),
        items: widget.items,
        initialValue: widget.value,
        getItemId: widget.getItemId,
        getItemName: widget.getItemName,
        getItemSubtitle: widget.getItemSubtitle,
        getItemBadge: widget.getItemBadge,
        allowManualEntry: widget.allowManualEntry,
        quickAddLabel: widget.quickAddLabel,
        onSelected: (selectedId) {
          formState.didChange(selectedId);
          widget.onChanged(selectedId);
          Navigator.pop(ctx);
        },
        onQuickAdd: widget.onQuickAdd != null
            ? (text) async {
                final createdId = await widget.onQuickAdd!(text);
                final finalVal = createdId ?? text;
                formState.didChange(finalVal);
                widget.onChanged(finalVal);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            : null,
      ),
    );
  }
}

class _SearchablePickerModal<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String? initialValue;
  final String Function(T item) getItemId;
  final String Function(T item) getItemName;
  final String? Function(T item)? getItemSubtitle;
  final String? Function(T item)? getItemBadge;
  final bool allowManualEntry;
  final String? quickAddLabel;
  final ValueChanged<String> onSelected;
  final Future<void> Function(String text)? onQuickAdd;

  const _SearchablePickerModal({
    required this.title,
    required this.items,
    this.initialValue,
    required this.getItemId,
    required this.getItemName,
    this.getItemSubtitle,
    this.getItemBadge,
    required this.allowManualEntry,
    this.quickAddLabel,
    required this.onSelected,
    this.onQuickAdd,
  });

  @override
  State<_SearchablePickerModal<T>> createState() => _SearchablePickerModalState<T>();
}

class _SearchablePickerModalState<T> extends State<_SearchablePickerModal<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _isAdding = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEnterOrAdd() async {
    final clean = _query.trim();
    if (clean.isEmpty) return;

    // 1. If an exact match exists, select it
    for (final it in widget.items) {
      final name = widget.getItemName(it).trim().toLowerCase();
      final id = widget.getItemId(it).trim().toLowerCase();
      if (name == clean.toLowerCase() || id == clean.toLowerCase()) {
        widget.onSelected(widget.getItemId(it));
        return;
      }
    }

    // 2. Otherwise quick add if allowed
    if (widget.allowManualEntry && widget.onQuickAdd != null) {
      setState(() => _isAdding = true);
      try {
        await widget.onQuickAdd!(clean);
      } finally {
        if (mounted) setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanQuery = _query.trim().toLowerCase();

    // Filter items
    final filtered = widget.items.where((it) {
      if (cleanQuery.isEmpty) return true;
      final name = widget.getItemName(it).toLowerCase();
      final id = widget.getItemId(it).toLowerCase();
      final sub = widget.getItemSubtitle?.call(it)?.toLowerCase() ?? '';
      return name.contains(cleanQuery) || id.contains(cleanQuery) || sub.contains(cleanQuery);
    }).toList();

    // Check if query is exact match with any existing item
    final hasExactMatch = widget.items.any(
      (it) => widget.getItemName(it).trim().toLowerCase() == cleanQuery,
    );

    final showAddOption = widget.allowManualEntry &&
        widget.onQuickAdd != null &&
        cleanQuery.isNotEmpty &&
        !hasExactMatch;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select ${widget.title}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          'Select from lookups or type a custom value to add on the fly',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontFamily: 'Inter',
                          ),
                        ),
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
            const Divider(height: 1, thickness: 1, color: Color(0xFF334155)),

            // Search Input Field with Keyboard Enter Handler
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val),
                onSubmitted: (_) => _handleEnterOrAdd(),
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  fontFamily: 'Inter',
                ),
                decoration: InputDecoration(
                  hintText: 'Search or type new ${widget.title.toLowerCase()} (Press Enter to add)...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontFamily: 'Inter'),
                  prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFF2563EB)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 17),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
            ),

            // Tip Banner when query is empty
            if (_query.trim().isEmpty && widget.allowManualEntry && widget.onQuickAdd != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Can\'t find what you need? Type in search above to add a new ${widget.title.toLowerCase()} to Lookups.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Quick Add Option (When user typed a new name not in list)
            if (showAddOption)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: InkWell(
                  onTap: _isAdding
                      ? null
                      : () async {
                          setState(() => _isAdding = true);
                          try {
                            await widget.onQuickAdd!(_query.trim());
                          } finally {
                            if (mounted) setState(() => _isAdding = false);
                          }
                        },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        if (_isAdding)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                          )
                        else
                          const Icon(Icons.add_circle_rounded, size: 22, color: Color(0xFF2563EB)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+ Add "${_query.trim()}"',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Text(
                                widget.quickAddLabel ?? 'Save to Lookup Management key-value table and select',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Add & Select',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Items Count Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Options (${filtered.length})',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (widget.initialValue != null)
                    const Text(
                      'Tap to select',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontFamily: 'Inter'),
                    ),
                ],
              ),
            ),

            // Scrollable Options List
            Expanded(
              child: filtered.isEmpty && !showAddOption
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 36, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'No matching ${widget.title.toLowerCase()} found',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: 'Inter'),
                          ),
                          if (widget.allowManualEntry && widget.onQuickAdd != null && _query.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _handleEnterOrAdd(),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text('Add "${_query.trim()}" to Lookups'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF334155)),
                      itemBuilder: (context, idx) {
                        final it = filtered[idx];
                        final id = widget.getItemId(it);
                        final name = widget.getItemName(it);
                        final subtitle = widget.getItemSubtitle?.call(it);
                        final badge = widget.getItemBadge?.call(it);

                        final isSelected = widget.initialValue != null &&
                            (widget.initialValue == id ||
                                widget.initialValue!.toLowerCase() == name.toLowerCase() ||
                                widget.initialValue!.toLowerCase() == id.toLowerCase());

                        return InkWell(
                          onTap: () => widget.onSelected(id),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected
                                              ? const Color(0xFF2563EB)
                                              : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      if (subtitle != null && subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          subtitle,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (badge != null && badge.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ],
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2563EB)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

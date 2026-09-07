import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/circulation_models.dart';
import '../../models/book_models.dart';
import '../../providers/circulation_provider.dart';
import '../../providers/book_provider.dart';

class ProcessIssueRequestDialog extends ConsumerStatefulWidget {
  final LibraryTransactionModel transaction;

  const ProcessIssueRequestDialog({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<ProcessIssueRequestDialog> createState() => _ProcessIssueRequestDialogState();
}

class _ProcessIssueRequestDialogState extends ConsumerState<ProcessIssueRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  final _copyBarcodeCtrl = TextEditingController();

  String _selectedAction = 'ISSUE'; // 'ISSUE', 'WAITING', 'REJECT'
  String _selectedWaitingReason = 'Copies of book are currently not available';
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  bool _isSubmitting = false;

  BookModel? _book;
  List<BookCopyModel> _availableCopies = [];
  bool _isLoadingBook = true;
  String? _selectedCopyId;
  String _issueFormat = 'PHYSICAL'; // 'PHYSICAL' or 'DIGITAL'

  late final List<String> _waitingReasons;

  @override
  void initState() {
    super.initState();
    _waitingReasons = [
      'Copies of book are currently not available',
      'Student / Teacher has not reached library desk to collect',
      'Awaiting return from previous borrower',
      'Copy reserved at circulation counter awaiting inspection',
      'Other reason (details in notes)',
    ];
    _initializeExistingValues();
    _loadBookDetails();
  }

  void _initializeExistingValues() {
    final tx = widget.transaction;
    final currentStatus = tx.status.toUpperCase();

    // 1. Preserve Action Status
    if (currentStatus == 'WAITING') {
      _selectedAction = 'WAITING';
    } else if (currentStatus == 'REJECTED' || currentStatus == 'CANCELLED' || currentStatus == 'CANCELED') {
      _selectedAction = 'REJECT';
    } else {
      _selectedAction = 'ISSUE';
    }

    // 2. Preserve Issue Date & Due Date
    _issueDate = tx.issueDate;
    if (tx.dueDate != null) {
      _dueDate = tx.dueDate!;
    }

    // 3. Preserve Copy Barcode & Copy ID
    if (tx.copyBarcode != 'N/A' && tx.copyBarcode.isNotEmpty) {
      _copyBarcodeCtrl.text = tx.copyBarcode;
    }
    if (tx.copyId != null && tx.copyId!.isNotEmpty) {
      _selectedCopyId = tx.copyId;
    }

    // 4. Preserve Format if digital
    if (tx.copyBarcode == 'DIGITAL' || tx.transactionType == 'DIGITAL_ISSUE') {
      _issueFormat = 'DIGITAL';
    }

    // 5. Preserve Waiting Reason and Notes
    final rawNotes = tx.notes?.trim() ?? '';
    if (rawNotes.isNotEmpty) {
      // Check Pattern A: "[Waiting Reason] Extra notes"
      final bracketMatch = RegExp(r'^\[(.*?)\](?:\s*(.*))?$', dotAll: true).firstMatch(rawNotes);
      if (bracketMatch != null) {
        final parsedReason = bracketMatch.group(1)?.trim() ?? '';
        final parsedExtra = bracketMatch.group(2)?.trim() ?? '';
        if (parsedReason.isNotEmpty) {
          if (!_waitingReasons.contains(parsedReason)) {
            _waitingReasons.insert(_waitingReasons.length - 1, parsedReason);
          }
          _selectedWaitingReason = parsedReason;
        }
        if (parsedExtra.isNotEmpty) {
          _notesCtrl.text = parsedExtra;
        }
      } else {
        // Check Pattern B: Matches one of the standard waiting reasons
        bool matched = false;
        for (final r in _waitingReasons) {
          if (rawNotes == r ||
              rawNotes.startsWith('$r:') ||
              rawNotes.startsWith('$r -') ||
              rawNotes.startsWith('$r ')) {
            _selectedWaitingReason = r;
            final extra = rawNotes.substring(r.length).trim().replaceFirst(RegExp(r'^[:\-\s]+'), '');
            if (extra.isNotEmpty) {
              _notesCtrl.text = extra;
            }
            matched = true;
            break;
          }
        }
        if (!matched) {
          if (_selectedAction == 'WAITING') {
            if (rawNotes.length <= 80 && !rawNotes.contains('\n')) {
              if (!_waitingReasons.contains(rawNotes)) {
                _waitingReasons.insert(_waitingReasons.length - 1, rawNotes);
              }
              _selectedWaitingReason = rawNotes;
            } else {
              _selectedWaitingReason = 'Other reason (details in notes)';
              _notesCtrl.text = rawNotes;
            }
          } else {
            _notesCtrl.text = rawNotes;
          }
        }
      }
    }
  }

  Future<void> _loadBookDetails() async {
    try {
      final res = await ref.read(libraryApiServiceProvider).fetchBookDetails(widget.transaction.bookId);
      final book = res['book'] as BookModel?;
      final copies = (res['copies'] as List<BookCopyModel>?) ?? [];
      final avail = copies
          .where((c) => c.status.toUpperCase() == 'AVAILABLE' || c.status.toUpperCase() == 'ACTIVE')
          .toList();

      if (mounted) {
        setState(() {
          _book = book;
          _availableCopies = avail;
          _isLoadingBook = false;
          if (_book != null) {
            if (_book!.hasDigitalEdition && !_book!.hasPhysicalEdition) {
              _issueFormat = 'DIGITAL';
            } else if (_book!.hasBothEditions) {
              if (_issueFormat != 'DIGITAL') {
                _issueFormat = avail.isEmpty ? 'DIGITAL' : 'PHYSICAL';
              }
            } else {
              _issueFormat = 'PHYSICAL';
            }
          }

          // If a copy was already selected/saved in transaction, sync with copy list
          if (_selectedCopyId != null && _copyBarcodeCtrl.text.isEmpty) {
            final match = copies.where((c) => c.id == _selectedCopyId).firstOrNull;
            if (match != null) {
              _copyBarcodeCtrl.text = match.barcode;
            }
          } else if (_copyBarcodeCtrl.text.isNotEmpty && _selectedCopyId == null) {
            final match = copies.where((c) =>
                c.barcode.trim().toLowerCase() == _copyBarcodeCtrl.text.trim().toLowerCase() ||
                c.accessionNumber.trim().toLowerCase() == _copyBarcodeCtrl.text.trim().toLowerCase()).firstOrNull;
            if (match != null) {
              _selectedCopyId = match.id;
            }
          }

          // Only default to first available copy if NONE was previously selected and barcode is empty
          if (_selectedCopyId == null && avail.isNotEmpty && _issueFormat == 'PHYSICAL' && _copyBarcodeCtrl.text.isEmpty && _selectedAction == 'ISSUE') {
            _selectedCopyId = avail.first.id;
            _copyBarcodeCtrl.text = avail.first.barcode;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBook = false);
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _copyBarcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    String? notesToSend;
    if (_selectedAction == 'WAITING') {
      notesToSend = _notesCtrl.text.trim().isNotEmpty
          ? '[$_selectedWaitingReason] ${_notesCtrl.text.trim()}'
          : _selectedWaitingReason;
    } else {
      notesToSend = _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
    }

    final issDateStr = DateFormat('yyyy-MM-dd').format(_issueDate);
    final dueDateStr = DateFormat('yyyy-MM-dd').format(_dueDate);

    final isDigitalIssue = _issueFormat == 'DIGITAL' || (_book != null && _book!.hasDigitalEdition && !_book!.hasPhysicalEdition);

    final success = await ref.read(circulationProvider.notifier).processIssueRequest(
      widget.transaction.id,
      action: _selectedAction,
      copyId: isDigitalIssue ? null : _selectedCopyId,
      copyBarcode: isDigitalIssue ? null : _copyBarcodeCtrl.text.trim(),
      issueDate: issDateStr,
      dueDate: dueDateStr,
      notes: notesToSend,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = widget.transaction;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, size: 22, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Process Book Issue Request',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transaction Code: ${tx.transactionCode}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Requester & Book Summary Grid
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Member Avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFF6366F1),
                                  child: Text(
                                    tx.memberName.isNotEmpty ? tx.memberName[0].toUpperCase() : 'M',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.memberName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tx.memberCode} · ${tx.memberRole.toUpperCase()} · ${tx.memberClass}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.bookTitle,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Author: ${tx.bookAuthor} · ISBN: ${tx.bookIsbn}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Selection Tabs (Issue / Waiting / Reject)
                      const Text(
                        'Select Action Status *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildActionTab('ISSUE', 'Issue Book', Icons.check_circle_rounded, const Color(0xFF10B981), isDark),
                          const SizedBox(width: 10),
                          _buildActionTab('WAITING', 'Mark Waiting', Icons.hourglass_top_rounded, const Color(0xFFF59E0B), isDark),
                          const SizedBox(width: 10),
                          _buildActionTab('REJECT', 'Reject Request', Icons.cancel_rounded, const Color(0xFFEF4444), isDark),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Fields based on selected action
                      if (_selectedAction == 'ISSUE') ...[
                        // Dates Row
                        Row(
                          children: [
                            // Issue Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Issue Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _issueDate,
                                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                        lastDate: DateTime.now().add(const Duration(days: 30)),
                                      );
                                      if (picked != null) setState(() => _issueDate = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.today_rounded, size: 16, color: Color(0xFF10B981)),
                                          const SizedBox(width: 8),
                                          Text(DateFormat('dd MMM yyyy').format(_issueDate), style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Due Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Due Date (Return by)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _dueDate,
                                        firstDate: _issueDate,
                                        lastDate: _issueDate.add(const Duration(days: 180)),
                                      );
                                      if (picked != null) setState(() => _dueDate = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF6366F1)),
                                          const SizedBox(width: 8),
                                          Text(DateFormat('dd MMM yyyy').format(_dueDate), style: const TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Dual edition format selector
                        if (_book != null && _book!.hasBothEditions) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Issue Edition:',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  selected: _issueFormat == 'PHYSICAL',
                                  label: const Text('Physical Hardcopy'),
                                  avatar: const Icon(Icons.book_rounded, size: 14),
                                  selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                                  onSelected: (selected) {
                                    if (selected) setState(() => _issueFormat = 'PHYSICAL');
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  selected: _issueFormat == 'DIGITAL',
                                  label: const Text('Digital Edition'),
                                  avatar: const Icon(Icons.cloud_done_rounded, size: 14),
                                  selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                                  onSelected: (selected) {
                                    if (selected) setState(() => _issueFormat = 'DIGITAL');
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Digital Edition Notice (No Barcode Required)
                        if (_issueFormat == 'DIGITAL' || (_book != null && _book!.hasDigitalEdition && !_book!.hasPhysicalEdition)) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cloud_done_rounded, size: 20, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Digital Edition Access (eBook / Video / Audio)',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'No physical barcode or accession number required for digital media. Digital reading/streaming license will be issued immediately upon confirmation.',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Physical Hardcopy Barcode Entry / Scan
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Book Barcode / Accession No. *',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                  if (_availableCopies.isNotEmpty)
                                    Text(
                                      '${_availableCopies.length} copies available in stock',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _copyBarcodeCtrl,
                                validator: (val) {
                                  if (_selectedAction == 'ISSUE' &&
                                      _issueFormat == 'PHYSICAL' &&
                                      (val == null || val.trim().isEmpty)) {
                                    return 'Please manually enter or scan the physical copy barcode.';
                                  }
                                  return null;
                                },
                                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w700),
                                decoration: _inputDecoration(
                                  isDark,
                                  hintText: 'Enter or scan physical copy barcode (e.g. BC-00123)...',
                                ).copyWith(
                                  prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Color(0xFF6366F1)),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.center_focus_strong_rounded, size: 20, color: Color(0xFF6366F1)),
                                    tooltip: 'Scan Barcode',
                                    onPressed: () => _openBarcodeScannerModal(context, isDark),
                                  ),
                                ),
                                onChanged: (val) {
                                  final match = _availableCopies.where((c) =>
                                      c.barcode.trim().toLowerCase() == val.trim().toLowerCase() ||
                                      c.accessionNumber.trim().toLowerCase() == val.trim().toLowerCase()).firstOrNull;
                                  if (match != null) {
                                    setState(() => _selectedCopyId = match.id);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              if (_availableCopies.isNotEmpty) ...[
                                const Text(
                                  'Available Copies (click to select):',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: _availableCopies.map((copy) {
                                    final isSelected = _copyBarcodeCtrl.text.trim() == copy.barcode;
                                    return ChoiceChip(
                                      selected: isSelected,
                                      selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                      avatar: Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.bookmark_outline_rounded,
                                        size: 14,
                                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                                      ),
                                      label: Text(
                                        '${copy.barcode} (Copy #${copy.copyNumber})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        setState(() {
                                          _copyBarcodeCtrl.text = copy.barcode;
                                          _selectedCopyId = copy.id;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ] else if (!_isLoadingBook) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No physical copies currently marked AVAILABLE in system. You can manually enter an unrecorded copy barcode or mark as WAITING.',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ] else if (_selectedAction == 'WAITING') ...[
                        const Text(
                          'Waiting Reason *',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedWaitingReason,
                          decoration: _inputDecoration(isDark),
                          items: _waitingReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12.5)))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedWaitingReason = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFF59E0B)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'The request status will be updated to Waiting in the transaction grid and member notification queue until the book is ready.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      // Additional Notes / Rejection Reason
                      Text(
                        _selectedAction == 'REJECT' ? 'Reason for Rejection *' : 'Additional Notes / Instructions',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _selectedAction == 'REJECT' ? const Color(0xFFEF4444) : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        validator: (val) {
                          if (_selectedAction == 'REJECT' && (val == null || val.trim().isEmpty)) {
                            return 'Please provide a reason for rejecting the request.';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(
                          isDark,
                          hintText: _selectedAction == 'REJECT'
                              ? 'Explain why this request is rejected...'
                              : 'Optional comments for borrower or circulation log...',
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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAction == 'ISSUE'
                            ? const Color(0xFF10B981)
                            : (_selectedAction == 'WAITING' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(
                              _selectedAction == 'ISSUE'
                                  ? Icons.check_circle_outline_rounded
                                  : (_selectedAction == 'WAITING' ? Icons.hourglass_top_rounded : Icons.cancel_outlined),
                              size: 16,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Processing...'
                            : (_selectedAction == 'ISSUE'
                                ? 'Confirm & Issue Book'
                                : (_selectedAction == 'WAITING'
                                    ? (widget.transaction.status.toUpperCase() == 'WAITING'
                                        ? 'Update Waiting Status'
                                        : 'Set Status to Waiting')
                                    : 'Reject Request')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTab(String key, String title, IconData icon, Color color, bool isDark) {
    final isSelected = _selectedAction == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedAction = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.15)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
      ),
    );
  }

  void _openBarcodeScannerModal(BuildContext context, bool isDark) {
    final scanCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text('Scan Book Barcode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use your USB/Bluetooth barcode scanner or manually enter the physical copy barcode below:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: scanCtrl,
              autofocus: true,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g. BC-00123 or ACC-00045',
                prefixIcon: const Icon(Icons.barcode_reader, size: 20),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (code) {
                if (code.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  setState(() {
                    _copyBarcodeCtrl.text = code.trim();
                    final match = _availableCopies.where((c) =>
                        c.barcode.trim().toLowerCase() == code.trim().toLowerCase() ||
                        c.accessionNumber.trim().toLowerCase() == code.trim().toLowerCase()).firstOrNull;
                    if (match != null) {
                      _selectedCopyId = match.id;
                    }
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final code = scanCtrl.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _copyBarcodeCtrl.text = code;
                  final match = _availableCopies.where((c) =>
                      c.barcode.trim().toLowerCase() == code.toLowerCase() ||
                      c.accessionNumber.trim().toLowerCase() == code.toLowerCase()).firstOrNull;
                  if (match != null) {
                    _selectedCopyId = match.id;
                  }
                });
              }
            },
            child: const Text('Assign Barcode'),
          ),
        ],
      ),
    );
  }
}

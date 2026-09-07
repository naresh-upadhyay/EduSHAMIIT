import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/circulation_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/book_provider.dart';
import '../../models/member_models.dart';
import '../../models/book_models.dart';


class QuickIssueDialog extends ConsumerStatefulWidget {
  final String? initialMemberQuery;
  final String? initialBookQuery;

  const QuickIssueDialog({
    super.key,
    this.initialMemberQuery,
    this.initialBookQuery,
  });

  @override
  ConsumerState<QuickIssueDialog> createState() => _QuickIssueDialogState();
}

class _QuickIssueDialogState extends ConsumerState<QuickIssueDialog> {
  int _currentStep = 0;

  // Step 1: Member
  final TextEditingController _memberSearchCtrl = TextEditingController();
  LibraryMemberModel? _selectedMember;

  // Step 2: Book & Copy
  final TextEditingController _bookSearchCtrl = TextEditingController();
  final TextEditingController _copyBarcodeCtrl = TextEditingController();
  BookModel? _selectedBook;
  BookCopyModel? _selectedCopy;
  List<BookCopyModel> _bookCopies = [];
  bool _isLoadingCopies = false;
  String _issueEditionType = 'PHYSICAL'; // 'PHYSICAL' or 'DIGITAL'

  // Step 3: Due Date & Notes
  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMemberQuery != null) {
      _memberSearchCtrl.text = widget.initialMemberQuery!;
    }
    if (widget.initialBookQuery != null) {
      _bookSearchCtrl.text = widget.initialBookQuery!;
    }
  }

  Future<void> _loadCopiesForBook(String bookId) async {
    setState(() => _isLoadingCopies = true);
    try {
      final copies = await ref.read(libraryApiServiceProvider).fetchBookCopies(bookId);
      final avail = copies.where((c) => c.status.toUpperCase() == 'AVAILABLE' || c.status.toUpperCase() == 'ACTIVE').toList();
      if (mounted) {
        setState(() {
          _bookCopies = avail;
          _isLoadingCopies = false;
          if (_selectedCopy == null && avail.isNotEmpty) {
            _selectedCopy = avail.first;
            _copyBarcodeCtrl.text = avail.first.barcode;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCopies = false);
    }
  }

  @override
  void dispose() {
    _memberSearchCtrl.dispose();
    _bookSearchCtrl.dispose();
    _copyBarcodeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberState = ref.watch(memberProvider);
    final bookState = ref.watch(bookProvider);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Issue Book to Member',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Stepper Header
            Row(
              children: [
                _buildStepHeader('1', 'Select Member', 0),
                _buildStepLine(0),
                _buildStepHeader('2', 'Select Book', 1),
                _buildStepLine(1),
                _buildStepHeader('3', 'Confirm', 2),
              ],
            ),
            const SizedBox(height: 20),

            // Step Body
            if (_currentStep == 0) ...[
              _buildStep1MemberSelection(memberState, isDark),
            ] else if (_currentStep == 1) ...[
              _buildStep2BookSelection(bookState, isDark),
            ] else ...[
              _buildStep3Confirm(isDark),
            ],

            const SizedBox(height: 24),

            // Footer Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('Back'),
                  )
                else
                  const SizedBox.shrink(),

                if (_currentStep < 2)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (_currentStep == 0 && _selectedMember != null) ||
                            (_currentStep == 1 &&
                                _selectedBook != null &&
                                (_issueEditionType == 'DIGITAL' || _selectedCopy != null || _copyBarcodeCtrl.text.trim().isNotEmpty))
                        ? () => setState(() => _currentStep++)
                        : null,
                    child: const Text('Next Step'),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting ? null : _handleIssueSubmission,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Confirm & Issue Book'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String number, String title, int stepIndex) {
    final isDone = _currentStep > stepIndex;
    final isCurrent = _currentStep == stepIndex;

    Color bg = const Color(0xFF94A3B8);
    if (isDone) bg = const Color(0xFF10B981);
    if (isCurrent) bg = const Color(0xFF6366F1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: bg,
          child: isDone
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : Text(number, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int stepIndex) {
    final isDone = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
      ),
    );
  }

  Widget _buildStep1MemberSelection(MemberState memberState, bool isDark) {
    final filteredMembers = memberState.members.where((m) {
      if (_memberSearchCtrl.text.isEmpty) return true;
      final q = _memberSearchCtrl.text.toLowerCase();
      return m.memberName.toLowerCase().contains(q) ||
          m.memberCode.toLowerCase().contains(q) ||
          (m.phone?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _memberSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search member by name, member code, phone...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: filteredMembers.isEmpty
              ? const Center(child: Text('No active library members found.'))
              : ListView.builder(
                  itemCount: filteredMembers.length,
                  itemBuilder: (ctx, i) {
                    final m = filteredMembers[i];
                    final isSelected = _selectedMember?.id == m.id;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF6366F1),
                        child: Text(m.memberName.isNotEmpty ? m.memberName[0] : 'M', style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                      title: Text(m.memberName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text('${m.memberCode} • ${m.membershipType} • Loans: ${m.booksIssued}/${m.borrowingLimit}'),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF6366F1)) : null,
                      onTap: () {
                        setState(() => _selectedMember = m);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStep2BookSelection(BookState bookState, bool isDark) {
    final filteredBooks = bookState.books.where((b) {
      if (_bookSearchCtrl.text.isEmpty) return true;
      final q = _bookSearchCtrl.text.toLowerCase();
      return b.title.toLowerCase().contains(q) ||
          (b.isbn?.toLowerCase().contains(q) ?? false) ||
          b.author.toLowerCase().contains(q);
    }).toList();


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _bookSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search book by title, author, ISBN...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: filteredBooks.isEmpty
              ? const Center(child: Text('No books available.'))
              : ListView.builder(
                  itemCount: filteredBooks.length,
                  itemBuilder: (ctx, i) {
                    final b = filteredBooks[i];
                    final isSelected = _selectedBook?.id == b.id;
                    final available = b.hasDigitalEdition || b.availableCopies > 0;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      enabled: available,
                      leading: Icon(
                        b.hasDigitalEdition ? Icons.cloud_done_rounded : Icons.menu_book_rounded,
                        color: const Color(0xFF6366F1),
                      ),
                      title: Text(b.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        b.hasDigitalEdition && !b.hasPhysicalEdition
                            ? '${b.author} • Digital Edition (eBook/Audio/Video)'
                            : '${b.author} • Available: ${b.availableCopies}/${b.totalCopies}${b.hasDigitalEdition ? " + Digital" : ""}',
                      ),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF6366F1)) : null,

                      onTap: available
                          ? () {
                              setState(() {
                                _selectedBook = b;
                                _selectedCopy = null;
                                _copyBarcodeCtrl.clear();
                                if (b.hasDigitalEdition && !b.hasPhysicalEdition) {
                                  _issueEditionType = 'DIGITAL';
                                } else if (b.hasBothEditions) {
                                  _issueEditionType = b.availableCopies > 0 ? 'PHYSICAL' : 'DIGITAL';
                                } else {
                                  _issueEditionType = 'PHYSICAL';
                                }
                              });
                              if (_issueEditionType == 'PHYSICAL') {
                                _loadCopiesForBook(b.id);
                              }
                            }
                          : null,
                    );
                  },
                ),
        ),

        // Selected Book Edition & Barcode Section
        if (_selectedBook != null) ...[
          const SizedBox(height: 14),
          if (_selectedBook!.hasBothEditions) ...[
            Row(
              children: [
                const Text('Issue Edition: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ChoiceChip(
                  selected: _issueEditionType == 'PHYSICAL',
                  label: const Text('Physical Copy'),
                  avatar: const Icon(Icons.book_rounded, size: 14),
                  selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _issueEditionType = 'PHYSICAL');
                      _loadCopiesForBook(_selectedBook!.id);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: _issueEditionType == 'DIGITAL',
                  label: const Text('Digital Edition'),
                  avatar: const Icon(Icons.cloud_done_rounded, size: 14),
                  selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                  onSelected: (val) {
                    if (val) setState(() => _issueEditionType = 'DIGITAL');
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (_issueEditionType == 'DIGITAL') ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Digital Edition Selected (eBook / Video / Audio). No barcode or physical copy allocation required.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            TextField(
              controller: _copyBarcodeCtrl,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Physical Copy Barcode / Accession No. *',
                hintText: 'Enter or scan physical copy barcode...',
                prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF6366F1)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (val) {
                final match = _bookCopies.where((c) =>
                    c.barcode.trim().toLowerCase() == val.trim().toLowerCase() ||
                    c.accessionNumber.trim().toLowerCase() == val.trim().toLowerCase()).firstOrNull;
                if (match != null) {
                  setState(() => _selectedCopy = match);
                }
              },
            ),
            if (_isLoadingCopies) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 2),
            ] else if (_bookCopies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _bookCopies.map((copy) {
                  final isSelected = _selectedCopy?.id == copy.id || _copyBarcodeCtrl.text.trim() == copy.barcode;
                  return ChoiceChip(
                    selected: isSelected,
                    selectedColor: const Color(0xFF6366F1).withOpacity(0.2),
                    label: Text('${copy.barcode} (Copy #${copy.copyNumber})', style: const TextStyle(fontSize: 11)),
                    onSelected: (val) {
                      setState(() {
                        _selectedCopy = copy;
                        _copyBarcodeCtrl.text = copy.barcode;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildStep3Confirm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildConfirmRow('Borrower:', '${_selectedMember?.memberName} (${_selectedMember?.memberCode})'),

              const SizedBox(height: 6),
              _buildConfirmRow('Book:', _selectedBook?.title ?? '—'),
              const SizedBox(height: 6),
              _buildConfirmRow(
                'Edition / Format:',
                _issueEditionType == 'DIGITAL'
                    ? 'Digital Edition (No Barcode)'
                    : 'Physical Copy (${_copyBarcodeCtrl.text.isNotEmpty ? _copyBarcodeCtrl.text : (_selectedCopy?.barcode ?? "Selected")})',
              ),
              const SizedBox(height: 6),
              _buildConfirmRow('Issue Date:', DateFormat('dd MMM yyyy').format(DateTime.now())),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Due Date Picker
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dueDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (picked != null) {
              setState(() => _dueDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Text('Due Date: ${DateFormat('dd MMM yyyy').format(_dueDate)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                const Text('Change', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Notes Input
        TextField(
          controller: _notesCtrl,
          decoration: InputDecoration(
            hintText: 'Add remarks or special notes (optional)...',
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Future<void> _handleIssueSubmission() async {
    if (_selectedMember == null || _selectedBook == null) return;
    setState(() => _isSubmitting = true);

    final isDigital = _issueEditionType == 'DIGITAL' ||
        (_selectedBook != null && _selectedBook!.hasDigitalEdition && !_selectedBook!.hasPhysicalEdition);

    final success = await ref.read(circulationProvider.notifier).issueBooks(
      memberId: _selectedMember!.id,
      items: [
        {
          'book_id': _selectedBook!.id,
          'copy_id': isDigital ? null : _selectedCopy?.id,
          'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
        }
      ],
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book issued successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(circulationProvider).errorMessage ?? 'Failed to issue book.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}

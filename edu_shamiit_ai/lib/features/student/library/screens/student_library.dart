import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/student_providers.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

class StudentLibrary extends ConsumerStatefulWidget {
  const StudentLibrary({super.key});

  @override
  ConsumerState<StudentLibrary> createState() => _StudentLibraryState();
}

class _StudentLibraryState extends ConsumerState<StudentLibrary> {
  int _selectedTab = 0; // 0=My Books, 1=Browse, 2=Digital, 3=Request
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(libraryProvider.notifier).fetchLibraryData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Widget _buildRequestForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9D5FF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('📋', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'Request a New Acquisition',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3B0764),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildRequestInputField(_titleController, 'Book Title',
                'e.g. Introduction to Algorithms', true),
            const SizedBox(height: 10),
            _buildRequestInputField(_authorController, 'Author Name',
                'e.g. Thomas H. Cormen', true),
            const SizedBox(height: 10),
            _buildRequestInputField(_isbnController, 'ISBN (Optional)',
                'e.g. 978-0262033848', false),
            const SizedBox(height: 10),
            TextFormField(
              controller: _reasonController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Why do you need this book?',
                labelStyle:
                    const TextStyle(color: Color(0xFF6D28D9), fontSize: 13),
                hintText: 'e.g. Required reference for CSE-301 curriculum',
                hintStyle:
                    const TextStyle(color: Colors.black38, fontSize: 12),
                filled: true,
                fillColor: const Color(0xFFFAF5FF),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE9D5FF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Submit Request',
                  style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final borrows = libraryState.borrows;

    // Total borrows includes active and requests
    final activeCount = borrows
        .where((b) => b.status == 'borrowed' || b.status.startsWith('pending'))
        .length;

    // AzureGrid columns definitions
    final myBooksColumns = [
      AzureGridColumn<LibraryBorrow>(
        label: 'Book Title',
        width: 180.0,
        compare: (a, b) => a.bookTitle.compareTo(b.bookTitle),
        cellBuilder: (b) => Text(b.bookTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      AzureGridColumn<LibraryBorrow>(
        label: 'Author',
        width: 130.0,
        compare: (a, b) => a.bookAuthor.compareTo(b.bookAuthor),
        cellBuilder: (b) => Text(b.bookAuthor),
      ),
      AzureGridColumn<LibraryBorrow>(
        label: 'Borrow Date',
        width: 110.0,
        compare: (a, b) => a.borrowedAt.compareTo(b.borrowedAt),
        cellBuilder: (b) => Text('${b.borrowedAt.day}/${b.borrowedAt.month}/${b.borrowedAt.year}'),
      ),
      AzureGridColumn<LibraryBorrow>(
        label: 'Due Date',
        width: 110.0,
        compare: (a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return -1;
          if (b.dueDate == null) return 1;
          return a.dueDate!.compareTo(b.dueDate!);
        },
        cellBuilder: (b) => Text(b.dueDate != null ? '${b.dueDate!.day}/${b.dueDate!.month}/${b.dueDate!.year}' : 'N/A'),
      ),
      AzureGridColumn<LibraryBorrow>(
        label: 'Status',
        width: 110.0,
        compare: (a, b) => a.status.compareTo(b.status),
        cellBuilder: (b) {
          final isOverdue = b.dueDate != null && b.dueDate!.isBefore(DateTime.now()) && !b.isReturned;
          String statusLabel = 'Borrowed';
          Color badgeBg = const Color(0xFFF5F3FF);
          Color badgeText = const Color(0xFF6D28D9);

          if (b.status == 'requested') {
            statusLabel = 'Awaiting Issue';
            badgeBg = const Color(0xFFFEF3C7);
            badgeText = const Color(0xFFD97706);
          } else if (b.status == 'pending_renew') {
            statusLabel = 'Awaiting Renewal';
            badgeBg = const Color(0xFFDBEAFE);
            badgeText = const Color(0xFF1D4ED8);
          } else if (b.status == 'pending_return') {
            statusLabel = 'Awaiting Return';
            badgeBg = const Color(0xFFE0F2FE);
            badgeText = const Color(0xFF0369A1);
          } else if (b.status == 'returned') {
            statusLabel = 'Returned';
            badgeBg = const Color(0xFFD1FAE5);
            badgeText = const Color(0xFF065F46);
          } else if (isOverdue) {
            statusLabel = 'Overdue';
            badgeBg = const Color(0xFFFEE2E2);
            badgeText = const Color(0xFF991B1B);
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
            child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText)),
          );
        },
      ),
      AzureGridColumn<LibraryBorrow>(
        label: 'Action',
        width: 130.0,
        cellBuilder: (b) {
          final canRenew = b.status == 'borrowed';
          final canReturn = b.status == 'borrowed';
          if (!canRenew && !canReturn) return const Text('No Action');
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRenew)
                SizedBox(
                  height: 24,
                  child: ElevatedButton(
                    onPressed: () => _confirmRenew(b),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: const Color(0xFF6D28D9),
                    ),
                    child: const Text('Renew', style: TextStyle(fontSize: 9, color: Colors.white)),
                  ),
                ),
              if (canRenew && canReturn) const SizedBox(width: 4),
              if (canReturn)
                SizedBox(
                  height: 24,
                  child: OutlinedButton(
                    onPressed: () => _confirmReturn(b),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: const BorderSide(color: Color(0xFF6D28D9)),
                    ),
                    child: const Text('Return', style: TextStyle(fontSize: 9, color: Color(0xFF6D28D9))),
                  ),
                ),
            ],
          );
        },
      ),
    ];

    final browseColumns = [
      AzureGridColumn<LibraryBook>(
        label: 'Title',
        width: 180.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (bk) => Text(bk.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Author',
        width: 130.0,
        compare: (a, b) => a.author.compareTo(b.author),
        cellBuilder: (bk) => Text(bk.author),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Category',
        width: 120.0,
        compare: (a, b) => a.category.compareTo(b.category),
        cellBuilder: (bk) => Text(bk.category),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'ISBN',
        width: 110.0,
        cellBuilder: (bk) => Text(bk.isbn),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Available Copies',
        width: 120.0,
        compare: (a, b) => a.availableCopies.compareTo(b.availableCopies),
        cellBuilder: (bk) => Text('${bk.availableCopies} / ${bk.totalCopies}'),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Action',
        width: 110.0,
        cellBuilder: (bk) {
          final isAvailable = bk.availableCopies > 0;
          return SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: () => _showBookDetailsDialog(bk),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: isAvailable ? const Color(0xFF6D28D9) : Colors.grey,
              ),
              child: Text(isAvailable ? 'Request Borrow' : 'Details', style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
          );
        },
      ),
    ];

    final digitalColumns = [
      AzureGridColumn<LibraryBook>(
        label: 'Title',
        width: 200.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (bk) => Text(bk.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Author',
        width: 140.0,
        compare: (a, b) => a.author.compareTo(b.author),
        cellBuilder: (bk) => Text(bk.author),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Category',
        width: 130.0,
        compare: (a, b) => a.category.compareTo(b.category),
        cellBuilder: (bk) => Text(bk.category),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Format',
        width: 100.0,
        cellBuilder: (bk) => Text(bk.isDigital ? 'PDF' : 'Physical'),
      ),
      AzureGridColumn<LibraryBook>(
        label: 'Action',
        width: 110.0,
        cellBuilder: (bk) {
          return SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: () => _showBookDetailsDialog(bk),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: const Color(0xFF3B82F6),
              ),
              child: const Text('Read / Download', style: TextStyle(fontSize: 10, color: Colors.white)),
            ),
          );
        },
      ),
    ];

    final requestColumns = [
      AzureGridColumn<LibraryBookRequest>(
        label: 'Book Title',
        width: 180.0,
        compare: (a, b) => a.title.compareTo(b.title),
        cellBuilder: (req) => Text(req.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      AzureGridColumn<LibraryBookRequest>(
        label: 'Author',
        width: 130.0,
        compare: (a, b) => a.author.compareTo(b.author),
        cellBuilder: (req) => Text(req.author),
      ),
      AzureGridColumn<LibraryBookRequest>(
        label: 'Reason',
        width: 150.0,
        cellBuilder: (req) => Text(req.reason ?? 'N/A', overflow: TextOverflow.ellipsis),
      ),
      AzureGridColumn<LibraryBookRequest>(
        label: 'Status',
        width: 100.0,
        compare: (a, b) => a.status.compareTo(b.status),
        cellBuilder: (req) {
          Color badgeBg = const Color(0xFFFEF3C7);
          Color badgeText = const Color(0xFFD97706);
          if (req.status == 'approved') {
            badgeBg = const Color(0xFFD1FAE5);
            badgeText = const Color(0xFF065F46);
          } else if (req.status == 'rejected') {
            badgeBg = const Color(0xFFFEE2E2);
            badgeText = const Color(0xFF991B1B);
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
            child: Text(req.status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText)),
          );
        },
      ),
    ];

    Widget tabContent;
    if (libraryState.isLoading) {
      tabContent = const Center(child: CircularProgressIndicator(color: Color(0xFF6D28D9)));
    } else {
      if (Responsive.isWide(context)) {
        if (_selectedTab == 0) {
          tabContent = AzureGrid<LibraryBorrow>(
            title: 'My Borrowed Books',
            items: borrows.where((b) => b.status != 'cancelled').toList(),
            columns: myBooksColumns,
            searchMatcher: (b) => '${b.bookTitle} ${b.bookAuthor} ${b.status}',
            onRefresh: () => ref.read(libraryProvider.notifier).fetchLibraryData(),
            mobileCardBuilder: (context, b) => const SizedBox(),
          );
        } else if (_selectedTab == 1) {
          tabContent = AzureGrid<LibraryBook>(
            title: 'Browse Library Books',
            items: libraryState.books.where((b) => !b.isDigital).toList(),
            columns: browseColumns,
            searchMatcher: (bk) => '${bk.title} ${bk.author} ${bk.isbn} ${bk.category}',
            onRefresh: () => ref.read(libraryProvider.notifier).fetchLibraryData(),
            mobileCardBuilder: (context, bk) => const SizedBox(),
          );
        } else if (_selectedTab == 2) {
          tabContent = AzureGrid<LibraryBook>(
            title: 'Digital Library',
            items: libraryState.books.where((b) => b.isDigital).toList(),
            columns: digitalColumns,
            searchMatcher: (bk) => '${bk.title} ${bk.author} ${bk.category}',
            onRefresh: () => ref.read(libraryProvider.notifier).fetchLibraryData(),
            mobileCardBuilder: (context, bk) => const SizedBox(),
          );
        } else {
          tabContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: _buildRequestForm(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 6,
                child: AzureGrid<LibraryBookRequest>(
                  title: 'My Book Requests',
                  items: libraryState.requests.where((r) => r.status != 'cancelled').toList(),
                  columns: requestColumns,
                  searchMatcher: (r) => '${r.title} ${r.author} ${r.status}',
                  onRefresh: () => ref.read(libraryProvider.notifier).fetchLibraryData(),
                  mobileCardBuilder: (context, r) => const SizedBox(),
                ),
              ),
            ],
          );
        }
      } else {
        tabContent = ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            if (_selectedTab == 0) ..._buildMyBooksTab(borrows, libraryState),
            if (_selectedTab == 1) ..._buildBrowseTab(libraryState),
            if (_selectedTab == 2) ..._buildDigitalTab(libraryState),
            if (_selectedTab == 3) ..._buildRequestTab(libraryState),
            const SizedBox(height: 50),
          ],
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF5FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B0764), Color(0xFF6D28D9)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () =>
                      safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Library Portal',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📚 $activeCount Active',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Tab Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _buildTabChip('My Books', 0),
                const SizedBox(width: 6),
                _buildTabChip('Browse', 1),
                const SizedBox(width: 6),
                _buildTabChip('Digital', 2),
                const SizedBox(width: 6),
                _buildTabChip('Request', 3),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: tabContent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6D28D9) : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF6D28D9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMyBooksTab(
      List<LibraryBorrow> borrows, LibraryState libraryState) {
    final searchQuery = _searchController.text.toLowerCase().trim();
    final visibleBorrows = borrows.where((b) {
      if (b.status == 'cancelled') return false;
      if (searchQuery.isEmpty) return true;
      return b.bookTitle.toLowerCase().contains(searchQuery) ||
          b.bookAuthor.toLowerCase().contains(searchQuery);
    }).toList();
    if (visibleBorrows.isEmpty) {
      return [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              const Icon(Icons.library_books_outlined,
                  size: 64, color: Color(0xFFC084FC)),
              const SizedBox(height: 16),
              const Text(
                'No books borrowed yet',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF581C87),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Explore the Browse tab to find books to read.'.tr(ref),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      const SizedBox(height: 10),
      ...visibleBorrows.map((borrow) {
        final isOverdue = borrow.dueDate != null &&
            borrow.dueDate!.isBefore(DateTime.now()) &&
            !borrow.isReturned;
        final dueDateStr = borrow.dueDate != null
            ? '${borrow.dueDate!.day}/${borrow.dueDate!.month}/${borrow.dueDate!.year}'
            : 'No due date';

        String statusLabel = 'Borrowed';
        Color badgeColor = const Color(0xFF6D28D9);
        Color badgeText = Colors.white;

        if (borrow.status == 'requested') {
          statusLabel = 'Awaiting Issue';
          badgeColor = const Color(0xFFFEF3C7);
          badgeText = const Color(0xFFD97706);
        } else if (borrow.status == 'pending_renew') {
          statusLabel = 'Awaiting Renewal';
          badgeColor = const Color(0xFFDBEAFE);
          badgeText = const Color(0xFF1D4ED8);
        } else if (borrow.status == 'pending_return') {
          statusLabel = 'Awaiting Return';
          badgeColor = const Color(0xFFE0F2FE);
          badgeText = const Color(0xFF0369A1);
        } else if (borrow.status == 'returned') {
          statusLabel = 'Returned';
          badgeColor = const Color(0xFFD1FAE5);
          badgeText = const Color(0xFF065F46);
        } else if (isOverdue) {
          statusLabel = 'Overdue';
          badgeColor = const Color(0xFFFEE2E2);
          badgeText = const Color(0xFF991B1B);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color:
                  isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE9D5FF),
              width: isOverdue ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              final matchingBook = libraryState.books.firstWhere(
                (b) =>
                    b.id == borrow.bookId ||
                    b.title.toLowerCase() == borrow.bookTitle.toLowerCase(),
                orElse: () => LibraryBook(
                  id: borrow.bookId,
                  title: borrow.bookTitle,
                  author: borrow.bookAuthor,
                  isbn: '',
                  category: 'General',
                  totalCopies: 1,
                  availableCopies: 0,
                  isIssued: borrow.status == 'borrowed',
                  isDigital: false,
                  description: LibraryBook.getDefaultDescription(
                      borrow.bookTitle, 'General'),
                ),
              );
              _showBookDetailsDialog(matchingBook);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 55,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: isOverdue
                          ? const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)])
                          : borrow.status == 'returned'
                              ? const LinearGradient(colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF047857)
                                ])
                              : const LinearGradient(colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFF4C1D95)
                                ]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        isOverdue
                            ? '⚠️'
                            : borrow.status == 'returned'
                                ? '✅'
                                : '📖',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: badgeText,
                                ),
                              ),
                            ),
                            if (borrow.fineAmount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Fine: ₹${borrow.fineAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          borrow.bookTitle,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B0764),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'By ${borrow.bookAuthor}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              borrow.status == 'returned'
                                  ? 'Returned at: ${borrow.returnedAt?.day}/${borrow.returnedAt?.month}'
                                  : 'Due: $dueDateStr',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isOverdue
                                    ? const Color(0xFFB91C1C)
                                    : Colors.black87,
                              ),
                            ),
                            if (borrow.status == 'borrowed')
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _confirmReturn(borrow),
                                    style: TextButton.styleFrom(
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Return',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF7C3AED),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _confirmRenew(borrow),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF5F3FF),
                                      foregroundColor: const Color(0xFF7C3AED),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Renew',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              )
                            else if (borrow.status == 'requested')
                              ElevatedButton(
                                onPressed: () => _confirmCancelBorrow(borrow),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEE2E2),
                                  foregroundColor: const Color(0xFFEF4444),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Cancel Request',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ];
  }

  Widget _buildAIPicksCard(List<LibraryBook> recommendations) {
    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 18)),
              SizedBox(width: 6),
              Text(
                'AI Librarian Recommendations',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.length,
              itemBuilder: (ctx, index) {
                final book = recommendations[index];
                return GestureDetector(
                  onTap: () => _showBookDetailsDialog(book),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 35,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.white30,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                              child:
                                  Text('📕', style: TextStyle(fontSize: 16))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                book.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                book.author,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                book.recommendationReason ??
                                    'Highly recommended.',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFFDE047),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBrowseTab(LibraryState state) {
    final physicalBooks = state.books.where((b) => !b.isDigital).toList();

    return [
      _buildAIPicksCard(state.recommendations),
      const SizedBox(height: 8),
      if (physicalBooks.isEmpty) ...[
        const SizedBox(height: 40),
        const Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: Color(0xFFC084FC)),
              SizedBox(height: 16),
              Text(
                'No physical books found',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF581C87),
                ),
              ),
              SizedBox(height: 6),
              Text('Try searching for another term',
                  style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ] else
        ...physicalBooks.map((book) {
          final isAvailable = book.availableCopies > 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE9D5FF)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showBookDetailsDialog(book),
              child: Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                          child: Text('📕', style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B0764),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'By ${book.author} · ${book.category}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isAvailable
                                    ? 'Available (${book.availableCopies} copies)'
                                    : 'Out of Stock',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: isAvailable
                                    ? () => _confirmBorrow(book)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Borrow',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
    ];
  }

  List<Widget> _buildDigitalTab(LibraryState state) {
    final digitalBooks = state.books.where((b) => b.isDigital).toList();

    if (digitalBooks.isEmpty) {
      return [
        const SizedBox(height: 60),
        const Center(
          child: Column(
            children: [
              Icon(Icons.menu_book, size: 64, color: Color(0xFFC084FC)),
              SizedBox(height: 16),
              Text(
                'No digital books available',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF581C87),
                ),
              ),
              SizedBox(height: 6),
              Text('Check back later for new digital catalogs',
                  style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ];
    }

    return digitalBooks.map((book) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE9D5FF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showBookDetailsDialog(book),
          child: Container(
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: Text('💻', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B0764),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'eBook · PDF · By ${book.author}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Instant Read / Download',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.black45,
                                fontStyle: FontStyle.italic),
                          ),
                          ElevatedButton(
                            onPressed: () => _downloadEBook(book),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF06B6D4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download, size: 12),
                                SizedBox(width: 4),
                                Text('Read Now',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  void _downloadEBook(LibraryBook book) async {
    if (book.digitalUrl != null && book.digitalUrl!.isNotEmpty) {
      final uri = Uri.parse(book.digitalUrl!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Could not open eBook URL: ${book.digitalUrl}'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ eBook does not have a valid download link.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  List<Widget> _buildRequestTab(LibraryState state) {
    final searchQuery = _searchController.text.toLowerCase().trim();
    final filteredRequests = state.requests.where((r) {
      if (r.status == 'cancelled') return false;
      if (searchQuery.isEmpty) return true;
      return r.title.toLowerCase().contains(searchQuery) ||
          r.author.toLowerCase().contains(searchQuery);
    }).toList();

    return [
      Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9D5FF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D28D9).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📋', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text(
                    'Request a New Acquisition',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B0764),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildRequestInputField(_titleController, 'Book Title',
                  'e.g. Introduction to Algorithms', true),
              const SizedBox(height: 10),
              _buildRequestInputField(_authorController, 'Author Name',
                  'e.g. Thomas H. Cormen', true),
              const SizedBox(height: 10),
              _buildRequestInputField(_isbnController, 'ISBN (Optional)',
                  'e.g. 978-0262033848', false),
              const SizedBox(height: 10),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Why do you need this book?',
                  labelStyle:
                      const TextStyle(color: Color(0xFF6D28D9), fontSize: 13),
                  hintText: 'e.g. Required reference for CSE-301 curriculum',
                  hintStyle:
                      const TextStyle(color: Colors.black38, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFFFAF5FF),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE9D5FF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Submit Request',
                    style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Your Previous Requests',
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3B0764),
        ),
      ),
      const SizedBox(height: 10),
      if (state.requests.isEmpty || filteredRequests.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: const Center(
            child: Text(
              'No previous acquisition requests found.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
        )
      else
        ...filteredRequests.map((req) {
          Color badgeColor = const Color(0xFFFEF3C7);
          Color badgeText = const Color(0xFFD97706);
          if (req.status == 'approved') {
            badgeColor = const Color(0xFFD1FAE5);
            badgeText = const Color(0xFF065F46);
          } else if (req.status == 'rejected') {
            badgeColor = const Color(0xFFFEE2E2);
            badgeText = const Color(0xFF991B1B);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.title,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B0764)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'By ${req.author}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black54),
                      ),
                      if (req.reason != null && req.reason!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reason: ${req.reason}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black45,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        req.status.toUpperCase(),
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: badgeText),
                      ),
                    ),
                    if (req.status == 'pending') ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => _confirmCancelRequest(req),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
    ];
  }

  Widget _buildRequestInputField(TextEditingController controller, String label,
      String placeholder, bool required) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      validator: required
          ? (value) => (value == null || value.trim().isEmpty)
              ? '$label is required'
              : null
          : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6D28D9), fontSize: 13),
        hintText: placeholder,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFFAF5FF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9D5FF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
      ),
    );
  }

  void _submitRequest() async {
    if (_formKey.currentState!.validate()) {
      final success =
          await ref.read(libraryProvider.notifier).submitBookRequest(
                _titleController.text.trim(),
                _authorController.text.trim(),
                _isbnController.text.trim(),
                _reasonController.text.trim(),
              );
      if (success) {
        _titleController.clear();
        _authorController.clear();
        _isbnController.clear();
        _reasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Acquisition request submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to submit acquisition request.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _confirmBorrow(LibraryBook book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Borrow Request',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
        content: Text(
            'Would you like to request to borrow "${book.title}" by ${book.author}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await ref.read(libraryProvider.notifier).borrowBook(book.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ Borrow request submitted successfully!'),
                      backgroundColor: Color(0xFF10B981)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          '❌ You have already requested/borrowed this book or copies are unavailable.'),
                      backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
            child: const Text('Borrow'),
          ),
        ],
      ),
    );
  }

  void _confirmRenew(LibraryBorrow borrow) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Book Renewal',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
        content: Text(
            'Request renewal for "${borrow.bookTitle}"?\n\nThis will send a request to the librarian. Max 2 renewals allowed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await ref.read(libraryProvider.notifier).renewBook(borrow.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('✅ Renewal request submitted to librarian!'),
                      backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
            child: const Text('Renew'),
          ),
        ],
      ),
    );
  }

  void _confirmReturn(LibraryBorrow borrow) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Initiate Return',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
        content: Text(
            'Mark "${borrow.bookTitle}" as returned?\n\nPlease return the physical book to the library desk to complete approval.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(libraryProvider.notifier)
                  .returnBook(borrow.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ Return request submitted to librarian!'),
                      backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white),
            child: const Text('Return Book'),
          ),
        ],
      ),
    );
  }

  void _showBookDetailsDialog(LibraryBook book) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner with gradient
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B0764), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        book.isDigital ? '💻' : '📕',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'By ${book.author}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content Area
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Grid (Category, ISBN, Shelf, Availability)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildDetailChip(Icons.category_outlined,
                              book.category, const Color(0xFF6D28D9)),
                          if (book.isbn.isNotEmpty)
                            _buildDetailChip(Icons.info_outline,
                                'ISBN: ${book.isbn}', const Color(0xFF0369A1)),
                          if (book.shelfLocation != null &&
                              book.shelfLocation!.isNotEmpty)
                            _buildDetailChip(
                                Icons.shelves,
                                'Shelf: ${book.shelfLocation}',
                                const Color(0xFFD97706)),
                          _buildDetailChip(
                            book.isDigital
                                ? Icons.cloud_done_outlined
                                : Icons.inventory_2_outlined,
                            book.isDigital
                                ? 'Digital eBook'
                                : (book.availableCopies > 0
                                    ? 'In Stock (${book.availableCopies} available)'
                                    : 'Out of Stock'),
                            book.isDigital
                                ? const Color(0xFF0D9488)
                                : (book.availableCopies > 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Short Description Section
                      const Text(
                        'Short Description',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF3B0764),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE9D5FF)),
                        ),
                        child: Text(
                          book.description ??
                              LibraryBook.getDefaultDescription(
                                  book.title, book.category),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5B21B6),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AI Recommendation Reason Section
                      const Text(
                        'AI Librarian Insights',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Color(0xFF3B0764),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                book.recommendationReason ??
                                    'Highly relevant to your current academic curriculum, containing detailed references and practice resources.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF166534),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Color(0xFF6D28D9),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!book.isDigital &&
                        book.availableCopies > 0 &&
                        !_isAlreadyBorrowed(book))
                      const SizedBox(width: 8),
                    if (!book.isDigital &&
                        book.availableCopies > 0 &&
                        !_isAlreadyBorrowed(book))
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmBorrow(book);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Borrow Book',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (book.isDigital) const SizedBox(width: 8),
                    if (book.isDigital)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _downloadEBook(book);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06B6D4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Read Now',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
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

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  bool _isAlreadyBorrowed(LibraryBook book) {
    final libraryState = ref.read(libraryProvider);
    return libraryState.borrows.any((b) =>
        (b.bookId == book.id ||
            b.bookTitle.toLowerCase() == book.title.toLowerCase()) &&
        b.status != 'returned' &&
        b.status != 'cancelled');
  }

  void _confirmCancelBorrow(LibraryBorrow borrow) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Borrow Request',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to cancel your borrow request for "${borrow.bookTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(libraryProvider.notifier)
                  .cancelBorrowRequest(borrow.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('✅ Borrow request cancelled successfully!'),
                      backgroundColor: Color(0xFF10B981)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('❌ Failed to cancel borrow request.'),
                      backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelRequest(LibraryBookRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Acquisition Request',
            style: TextStyle(
                fontFamily: AppFonts.heading, fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to cancel your request for "${request.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(libraryProvider.notifier)
                  .cancelBookRequest(request.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('✅ Acquisition request cancelled successfully!'),
                      backgroundColor: Color(0xFF10B981)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('❌ Failed to cancel acquisition request.'),
                      backgroundColor: Color(0xFFEF4444)),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}

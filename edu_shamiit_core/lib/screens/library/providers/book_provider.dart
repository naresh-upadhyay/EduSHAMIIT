import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book_models.dart';
import '../services/library_api_service.dart';

class BookState {
  final bool isLoading;
  final bool isStatsLoading;
  final bool isFilterOptionsLoading;
  final bool isActionLoading;
  final List<BookModel> books;
  final BookStatsModel stats;
  final BookFilterOptionsModel filterOptions;
  final BookModel? selectedBook;
  final List<BookCopyModel> selectedBookCopies;
  final bool isDrawerOpen;
  final Set<String> selectedBookIds;
  
  // Search & Filter state
  final String searchQuery;
  final String selectedCategory;
  final String selectedAuthor;
  final String selectedPublisher;
  final String selectedStatus;
  final String selectedAvailability;
  final String selectedFormatFilter; // 'ALL', 'PHYSICAL', 'EBOOK', 'AUDIOBOOK', 'VIDEOBOOK', 'JOURNAL'
  final String selectedAccessFilter; // 'ALL', 'PUBLIC', 'RESTRICTED'
  final String? selectedLanguage;
  final String? selectedBookType;
  final String? selectedRack;
  final int? yearMin;
  final int? yearMax;

  // View Mode
  final String viewMode; // 'TABLE' or 'CARDS'

  // Pagination & Sorting
  final String sortBy;
  final String sortOrder;
  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final int totalPages;

  // Tabs & Drawers
  final int activeTab;
  final bool isAccessDrawerOpen;
  final List<DigitalAccessPermissionModel> selectedBookPermissions;
  final DigitalAnalyticsModel? selectedBookAnalytics;

  // Feedback
  final String? errorMessage;
  final String? successMessage;

  const BookState({
    this.isLoading = false,
    this.isStatsLoading = false,
    this.isFilterOptionsLoading = false,
    this.isActionLoading = false,
    this.books = const [],
    this.stats = const BookStatsModel(),
    this.filterOptions = const BookFilterOptionsModel(),
    this.selectedBook,
    this.selectedBookCopies = const [],
    this.isDrawerOpen = false,
    this.selectedBookIds = const {},
    this.searchQuery = '',
    this.selectedCategory = 'All Categories',
    this.selectedAuthor = 'All Authors',
    this.selectedPublisher = 'All Publishers',
    this.selectedStatus = 'ACTIVE',
    this.selectedAvailability = 'ALL',
    this.selectedFormatFilter = 'ALL',
    this.selectedAccessFilter = 'ALL',
    this.selectedLanguage,
    this.selectedBookType,
    this.selectedRack,
    this.yearMin,
    this.yearMax,
    this.viewMode = 'TABLE',
    this.sortBy = 'title',
    this.sortOrder = 'ASC',
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalRecords = 0,
    this.totalPages = 1,
    this.activeTab = 1,
    this.isAccessDrawerOpen = false,
    this.selectedBookPermissions = const [],
    this.selectedBookAnalytics,
    this.errorMessage,
    this.successMessage,
  });

  BookState copyWith({
    bool? isLoading,
    bool? isStatsLoading,
    bool? isFilterOptionsLoading,
    bool? isActionLoading,
    List<BookModel>? books,
    BookStatsModel? stats,
    BookFilterOptionsModel? filterOptions,
    BookModel? selectedBook,
    bool clearSelectedBook = false,
    List<BookCopyModel>? selectedBookCopies,
    bool? isDrawerOpen,
    Set<String>? selectedBookIds,
    String? searchQuery,
    String? selectedCategory,
    String? selectedAuthor,
    String? selectedPublisher,
    String? selectedStatus,
    String? selectedAvailability,
    String? selectedFormatFilter,
    String? selectedAccessFilter,
    String? selectedLanguage,
    bool clearLanguage = false,
    String? selectedBookType,
    bool clearBookType = false,
    String? selectedRack,
    bool clearRack = false,
    int? yearMin,
    bool clearYearMin = false,
    int? yearMax,
    bool clearYearMax = false,
    String? viewMode,
    String? sortBy,
    String? sortOrder,
    int? currentPage,
    int? pageSize,
    int? totalRecords,
    int? totalPages,
    int? activeTab,
    bool? isAccessDrawerOpen,
    List<DigitalAccessPermissionModel>? selectedBookPermissions,
    DigitalAnalyticsModel? selectedBookAnalytics,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successMessage,
    bool clearSuccessMessage = false,
  }) {
    return BookState(
      isLoading: isLoading ?? this.isLoading,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      isFilterOptionsLoading: isFilterOptionsLoading ?? this.isFilterOptionsLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      books: books ?? this.books,
      stats: stats ?? this.stats,
      filterOptions: filterOptions ?? this.filterOptions,
      selectedBook: clearSelectedBook ? null : (selectedBook ?? this.selectedBook),
      selectedBookCopies: selectedBookCopies ?? this.selectedBookCopies,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      selectedBookIds: selectedBookIds ?? this.selectedBookIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedAuthor: selectedAuthor ?? this.selectedAuthor,
      selectedPublisher: selectedPublisher ?? this.selectedPublisher,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedAvailability: selectedAvailability ?? this.selectedAvailability,
      selectedFormatFilter: selectedFormatFilter ?? this.selectedFormatFilter,
      selectedAccessFilter: selectedAccessFilter ?? this.selectedAccessFilter,
      selectedLanguage: clearLanguage ? null : (selectedLanguage ?? this.selectedLanguage),
      selectedBookType: clearBookType ? null : (selectedBookType ?? this.selectedBookType),
      selectedRack: clearRack ? null : (selectedRack ?? this.selectedRack),
      yearMin: clearYearMin ? null : (yearMin ?? this.yearMin),
      yearMax: clearYearMax ? null : (yearMax ?? this.yearMax),
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalRecords: totalRecords ?? this.totalRecords,
      totalPages: totalPages ?? this.totalPages,
      activeTab: activeTab ?? this.activeTab,
      isAccessDrawerOpen: isAccessDrawerOpen ?? this.isAccessDrawerOpen,
      selectedBookPermissions: selectedBookPermissions ?? this.selectedBookPermissions,
      selectedBookAnalytics: selectedBookAnalytics ?? this.selectedBookAnalytics,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }
}

class BookNotifier extends StateNotifier<BookState> {

  final LibraryApiService _apiService;
  Timer? _debounceTimer;

  BookNotifier(this._apiService) : super(const BookState()) {
    initialize();
  }

  Future<void> initialize() async {
    await Future.wait([
      loadStats(),
      loadFilterOptions(),
      loadBooks(),
    ]);
  }

  Future<void> loadStats() async {
    try {
      state = state.copyWith(isStatsLoading: true);
      final stats = await _apiService.fetchBookStats();
      state = state.copyWith(stats: stats, isStatsLoading: false);
    } catch (e) {
      state = state.copyWith(isStatsLoading: false);
    }
  }

  Future<void> loadFilterOptions() async {
    try {
      state = state.copyWith(isFilterOptionsLoading: true);
      final options = await _apiService.fetchFilterOptions();
      state = state.copyWith(filterOptions: options, isFilterOptionsLoading: false);
    } catch (e) {
      state = state.copyWith(isFilterOptionsLoading: false);
    }
  }

  Future<void> loadBooks() async {
    try {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
      final res = await _apiService.fetchBooks(
        search: state.searchQuery,
        category: state.selectedCategory,
        author: state.selectedAuthor,
        publisher: state.selectedPublisher,
        language: state.selectedLanguage,
        bookType: state.selectedBookType,
        rack: state.selectedRack,
        status: state.selectedStatus,
        availability: state.selectedAvailability,
        publicationYearMin: state.yearMin,
        publicationYearMax: state.yearMax,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: state.currentPage,
        pageSize: state.pageSize,
      );

      final books = res['books'] as List<BookModel>;
      final totalRecords = res['totalRecords'] as int;
      final totalPages = res['totalPages'] as int;

      state = state.copyWith(
        books: books,
        totalRecords: totalRecords,
        totalPages: totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load books: ${e.toString()}',
      );
    }
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query, currentPage: 1);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      loadBooks();
    });
  }

  void setSearchQuery(String query) => setSearch(query);

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category, currentPage: 1);
    loadBooks();
  }

  void setAuthor(String author) {
    state = state.copyWith(selectedAuthor: author, currentPage: 1);
    loadBooks();
  }

  void setPublisher(String publisher) {
    state = state.copyWith(selectedPublisher: publisher, currentPage: 1);
    loadBooks();
  }

  void setStatus(String status) {
    state = state.copyWith(selectedStatus: status, currentPage: 1);
    loadBooks();
  }

  void setAvailability(String availability) {
    state = state.copyWith(selectedAvailability: availability, currentPage: 1);
    loadBooks();
  }

  void filterByKpi(String filterType) {
    if (filterType == 'AVAILABLE') {
      state = state.copyWith(selectedAvailability: 'AVAILABLE', selectedStatus: 'ACTIVE', currentPage: 1);
    } else if (filterType == 'ISSUED') {
      state = state.copyWith(selectedAvailability: 'FULLY_ISSUED', selectedStatus: 'ACTIVE', currentPage: 1);
    } else if (filterType == 'OVERDUE') {
      state = state.copyWith(selectedAvailability: 'OVERDUE', selectedStatus: 'ACTIVE', currentPage: 1);
    } else if (filterType == 'LOW') {
      state = state.copyWith(selectedAvailability: 'ALL', selectedStatus: 'ACTIVE', currentPage: 1);
    } else {
      clearFilters();
      return;
    }
    loadBooks();
  }

  void setAdvancedFilters({
    String? language,
    String? bookType,
    String? rack,
    int? yearMin,
    int? yearMax,
  }) {
    String formatFilter = 'ALL';
    if (bookType != null && bookType.isNotEmpty && bookType != 'All Formats') {
      final btUpper = bookType.toUpperCase();
      if (btUpper.contains('AUDIO')) {
        formatFilter = 'AUDIOBOOK';
      } else if (btUpper.contains('VIDEO')) {
        formatFilter = 'VIDEOBOOK';
      } else if (btUpper.contains('EBOOK') || btUpper.contains('E-BOOK') || btUpper.contains('DIGITAL')) {
        formatFilter = 'EBOOK';
      } else if (btUpper.contains('PHYSICAL') || btUpper.contains('PAPERBACK') || btUpper.contains('HARDCOVER')) {
        formatFilter = 'PHYSICAL';
      }
    }
    state = state.copyWith(
      selectedLanguage: language,
      clearLanguage: language == null,
      selectedBookType: (bookType == null || bookType == 'All Formats') ? null : bookType,
      clearBookType: (bookType == null || bookType == 'All Formats'),
      selectedFormatFilter: formatFilter,
      selectedRack: rack,
      clearRack: rack == null,
      yearMin: yearMin,
      clearYearMin: yearMin == null,
      yearMax: yearMax,
      clearYearMax: yearMax == null,
      currentPage: 1,
    );
    loadBooks();
  }

  void clearFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedCategory: 'All Categories',
      selectedAuthor: 'All Authors',
      selectedPublisher: 'All Publishers',
      selectedStatus: 'ACTIVE',
      selectedAvailability: 'ALL',
      selectedFormatFilter: 'ALL',
      selectedAccessFilter: 'ALL',
      clearLanguage: true,
      clearBookType: true,
      clearRack: true,
      clearYearMin: true,
      clearYearMax: true,
      currentPage: 1,
    );
    loadBooks();
  }

  void setPage(int page) {
    if (page < 1 || (page > state.totalPages && state.totalPages > 0)) return;
    state = state.copyWith(currentPage: page);
    loadBooks();
  }

  void setPageSize(int pageSize) {
    state = state.copyWith(pageSize: pageSize, currentPage: 1);
    loadBooks();
  }

  void setSorting(String column, String direction) {
    state = state.copyWith(sortBy: column, sortOrder: direction, currentPage: 1);
    loadBooks();
  }

  void setActiveTab(int tabIndex) {
    state = state.copyWith(activeTab: tabIndex);
  }

  void toggleBookSelection(String bookId) {
    final updated = Set<String>.from(state.selectedBookIds);
    if (updated.contains(bookId)) {
      updated.remove(bookId);
    } else {
      updated.add(bookId);
    }
    state = state.copyWith(selectedBookIds: updated);
  }

  void selectAllCurrentPage() {
    final updated = Set<String>.from(state.selectedBookIds);
    final currentPageIds = state.books.map((b) => b.id).toSet();
    if (updated.containsAll(currentPageIds)) {
      updated.removeAll(currentPageIds);
    } else {
      updated.addAll(currentPageIds);
    }
    state = state.copyWith(selectedBookIds: updated);
  }

  void clearSelection() {
    state = state.copyWith(selectedBookIds: const {});
  }

  Future<void> selectBookForDrawer(String bookId) async {
    try {
      state = state.copyWith(isActionLoading: true, isDrawerOpen: true);
      final details = await _apiService.fetchBookDetails(bookId);
      state = state.copyWith(
        selectedBook: details['book'] as BookModel,
        selectedBookCopies: details['copies'] as List<BookCopyModel>,
        isActionLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: 'Failed to fetch book details: ${e.toString()}',
      );
    }
  }

  void closeDrawer() {
    state = state.copyWith(isDrawerOpen: false, clearSelectedBook: true, selectedBookCopies: const []);
  }

  Future<bool> createBook(Map<String, dynamic> payload) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true, clearSuccessMessage: true);
      final res = await _apiService.createBook(payload);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Book created successfully.',
      );
      await Future.wait([loadStats(), loadFilterOptions(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> updateBook(String bookId, Map<String, dynamic> payload) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true, clearSuccessMessage: true);
      final res = await _apiService.updateBook(bookId, payload);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Book updated successfully.',
      );
      if (state.selectedBook?.id == bookId) {
        selectBookForDrawer(bookId);
      }
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> archiveBook(String bookId) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.archiveBook(bookId);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Book archived.',
      );
      if (state.selectedBook?.id == bookId) {
        closeDrawer();
      }
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> restoreBook(String bookId) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.restoreBook(bookId);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Book restored.',
      );
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> addBookCopies(String bookId, Map<String, dynamic> payload) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.addBookCopies(bookId, payload);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Copies added successfully.',
      );
      if (state.selectedBook?.id == bookId) {
        selectBookForDrawer(bookId);
      }
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> updateBookCopy(String copyId, Map<String, dynamic> payload) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.updateBookCopy(copyId, payload);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Copy updated.',
      );
      if (state.selectedBook != null) {
        selectBookForDrawer(state.selectedBook!.id);
      }
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> archiveBookCopy(String copyId) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.archiveBookCopy(copyId);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Copy archived.',
      );
      if (state.selectedBook != null) {
        selectBookForDrawer(state.selectedBook!.id);
      }
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> performBulkAction(String action, {String? categoryName, String? categoryId, String? rack, String? shelf, String? tag}) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final payload = {
        'book_ids': state.selectedBookIds.toList(),
        'action': action,
        if (categoryName != null) 'category_name': categoryName,
        if (categoryId != null) 'category_id': categoryId,
        if (rack != null) 'rack_location': rack,
        if (shelf != null) 'shelf_location': shelf,
        if (tag != null) 'tag': tag,
      };
      final res = await _apiService.performBulkAction(payload);
      state = state.copyWith(
        isActionLoading: false,
        selectedBookIds: const {},
        successMessage: res['message']?.toString() ?? 'Bulk operation completed.',
      );
      await Future.wait([loadStats(), loadBooks()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> importBooks(List<Map<String, dynamic>> rows, {String mode = 'COMMIT'}) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.importBooks(rows, mode: mode);
      state = state.copyWith(isActionLoading: false);
      if (mode == 'COMMIT') {
        state = state.copyWith(successMessage: 'Books import completed successfully.');
        await Future.wait([loadStats(), loadFilterOptions(), loadBooks()]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      rethrow;
    }
  }

  void setViewMode(String mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setFormatFilter(String format) {
    state = state.copyWith(
      selectedFormatFilter: format,
      selectedBookType: format == 'ALL' ? null : format,
      clearBookType: format == 'ALL',
      currentPage: 1,
    );
    loadBooks();
  }


  void setAccessFilter(String access) {
    state = state.copyWith(selectedAccessFilter: access, currentPage: 1);
    loadBooks();
  }

  Future<void> openAccessDrawer(BookModel book) async {
    try {
      state = state.copyWith(
        selectedBook: book,
        isAccessDrawerOpen: true,
        isActionLoading: true,
      );
      final perms = await _apiService.fetchBookPermissions(book.id);
      final analytics = await _apiService.fetchBookDigitalAnalytics(book.id);
      state = state.copyWith(
        selectedBookPermissions: perms,
        selectedBookAnalytics: analytics,
        isActionLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isActionLoading: false);
    }
  }

  void closeAccessDrawer() {
    state = state.copyWith(isAccessDrawerOpen: false);
  }

  Future<bool> grantDigitalPermission(String bookId, Map<String, dynamic> payload) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.grantDigitalPermission(bookId, payload);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Permission granted.',
      );
      if (state.isAccessDrawerOpen && state.selectedBook != null) {
        openAccessDrawer(state.selectedBook!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> revokeDigitalPermission(String bookId, String userId) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.revokeDigitalPermission(bookId, userId);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Permission revoked.',
      );
      if (state.isAccessDrawerOpen && state.selectedBook != null) {
        openAccessDrawer(state.selectedBook!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<bool> requestDigitalAccess(String bookId, {String? reason, String? accessScope}) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.requestDigitalAccess(bookId, reason: reason, accessScope: accessScope);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Access request submitted.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> fetchDigitalStreamToken(String bookId, {String? fileId}) async {
    return await _apiService.fetchDigitalStreamToken(bookId, fileId: fileId);
  }

  Future<bool> recordDigitalProgress(String bookId, Map<String, dynamic> payload) async {
    try {
      await _apiService.recordDigitalProgress(bookId, payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addBookmarkOrHighlight(String bookId, Map<String, dynamic> payload) async {
    try {
      await _apiService.createBookInteraction(bookId, payload);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeInteraction(String bookId, String interactionId) async {
    try {
      await _apiService.deleteBookInteraction(bookId, interactionId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitBookReview(String bookId, Map<String, dynamic> payload) async {
    try {
      state = state.copyWith(isActionLoading: true, clearErrorMessage: true);
      final res = await _apiService.createBookReview(bookId, payload);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Review submitted.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> askAi(String bookId, Map<String, dynamic> payload) async {
    return await _apiService.askAiReadingAssistant(bookId, payload);
  }

  void clearNotifications() {
    state = state.copyWith(clearErrorMessage: true, clearSuccessMessage: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}


final libraryApiServiceProvider = Provider<LibraryApiService>((ref) => LibraryApiService());

final bookProvider = StateNotifierProvider<BookNotifier, BookState>((ref) {
  final apiService = ref.watch(libraryApiServiceProvider);
  return BookNotifier(apiService);
});

import '../../../../services/api_service.dart';
import '../models/book_models.dart';

class LibraryApiService {
  final ApiService _api = ApiService();

  /// Fetch aggregated KPI metrics for the Books tab header
  Future<BookStatsModel> fetchBookStats() async {
    final res = await _api.get('/library/books/stats', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return BookStatsModel.fromJson(data);
  }

  /// Fetch dynamic dropdown filter options
  Future<BookFilterOptionsModel> fetchFilterOptions() async {
    final res = await _api.get('/library/books/filter-options', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return BookFilterOptionsModel.fromJson(data);
  }

  /// Fetch paginated, multi-filtered list of books
  Future<Map<String, dynamic>> fetchBooks({
    String? search,
    String? category,
    String? author,
    String? publisher,
    String? language,
    String? bookType,
    String? rack,
    String status = 'ACTIVE',
    String availability = 'ALL',
    int? publicationYearMin,
    int? publicationYearMax,
    String sortBy = 'title',
    String sortOrder = 'ASC',
    int page = 1,
    int pageSize = 10,
  }) async {
    final queryParams = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (category != null && category.isNotEmpty && category != 'All Categories') 'category': category,
      if (author != null && author.isNotEmpty && author != 'All Authors') 'author': author,
      if (publisher != null && publisher.isNotEmpty && publisher != 'All Publishers') 'publisher': publisher,
      if (language != null && language.isNotEmpty) 'language': language,
      if (bookType != null && bookType.isNotEmpty) 'book_type': bookType,
      if (rack != null && rack.isNotEmpty) 'rack': rack,
      'status': status,
      if (availability != 'ALL') 'availability': availability,
      if (publicationYearMin != null) 'publication_year_min': publicationYearMin,
      if (publicationYearMax != null) 'publication_year_max': publicationYearMax,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'page': page,
      'page_size': pageSize,
    };

    final res = await _api.get('/library/books', query: queryParams, useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    final books = rawList.map((e) => BookModel.fromJson(Map<String, dynamic>.from(e))).toList();
    final pagination = res['pagination'] as Map<String, dynamic>? ?? {};

    return {
      'books': books,
      'page': pagination['page'] ?? page,
      'pageSize': pagination['page_size'] ?? pageSize,
      'totalRecords': pagination['total_records'] ?? books.length,
      'totalPages': pagination['total_pages'] ?? 1,
    };
  }

  /// Fetch full book details with physical copies list
  Future<Map<String, dynamic>> fetchBookDetails(String bookId) async {
    final res = await _api.get('/library/books/$bookId', useCache: false);
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    final bookMap = Map<String, dynamic>.from(data['book'] is Map ? data['book'] as Map : data);
    
    if (data['digital_files'] != null && !bookMap.containsKey('digital_files')) {
      bookMap['digital_files'] = data['digital_files'];
    }
    if (data['access_status'] != null && !bookMap.containsKey('access_status')) {
      bookMap['access_status'] = data['access_status'];
    }
    if (data['user_progress'] != null && !bookMap.containsKey('user_progress')) {
      bookMap['user_progress'] = data['user_progress'];
    }

    final book = BookModel.fromJson(bookMap);
    final rawCopies = data['copies'] is List ? data['copies'] as List : [];
    final copies = rawCopies.map((e) => BookCopyModel.fromJson(Map<String, dynamic>.from(e))).toList();

    return {
      'book': book,
      'copies': copies,
    };
  }


  /// Live ISBN duplicate checking
  Future<Map<String, dynamic>> checkIsbn({String? isbn13, String? isbn10}) async {
    final payload = {
      if (isbn13 != null) 'isbn13': isbn13,
      if (isbn10 != null) 'isbn10': isbn10,
    };
    final res = await _api.post('/library/books/check-isbn', payload);
    return res;
  }

  /// Create a new book title + initial physical copies
  Future<Map<String, dynamic>> createBook(Map<String, dynamic> payload) async {
    return await _api.post('/library/books', payload);
  }

  /// Update bibliographic details
  Future<Map<String, dynamic>> updateBook(String bookId, Map<String, dynamic> payload) async {
    return await _api.patch('/library/books/$bookId', payload);
  }

  /// Archive a book title
  Future<Map<String, dynamic>> archiveBook(String bookId) async {
    return await _api.delete('/library/books/$bookId');
  }

  /// Restore an archived book title
  Future<Map<String, dynamic>> restoreBook(String bookId) async {
    return await _api.post('/library/books/$bookId/restore', {});
  }

  /// Permanently delete book where business rules permit
  Future<Map<String, dynamic>> deleteBook(String bookId, {bool forceDelete = true}) async {
    return await _api.delete('/library/books/$bookId?force_delete=$forceDelete');
  }

  /// Fetch physical copies for a book
  Future<List<BookCopyModel>> fetchBookCopies(String bookId) async {
    final res = await _api.get('/library/books/$bookId/copies', useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    return rawList.map((e) => BookCopyModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Add batch physical copies to a book
  Future<Map<String, dynamic>> addBookCopies(String bookId, Map<String, dynamic> payload) async {
    return await _api.post('/library/books/$bookId/copies', payload);
  }

  /// Update copy status, location, condition, notes
  Future<Map<String, dynamic>> updateBookCopy(String copyId, Map<String, dynamic> payload) async {
    return await _api.patch('/library/book-copies/$copyId', payload);
  }

  /// Archive a physical copy
  Future<Map<String, dynamic>> archiveBookCopy(String copyId) async {
    return await _api.delete('/library/book-copies/$copyId');
  }

  /// Scan barcode / QR code to lookup book copy
  Future<Map<String, dynamic>> lookupByScan(String code) async {
    return await _api.get('/library/lookup-scan', query: {'code': code}, useCache: false);
  }

  /// Perform bulk operations on selected books
  Future<Map<String, dynamic>> performBulkAction(Map<String, dynamic> payload) async {
    return await _api.post('/library/books/bulk', payload);
  }

  /// Import books CSV/Excel rows with preview/commit
  Future<Map<String, dynamic>> importBooks(List<Map<String, dynamic>> rows, {String mode = 'COMMIT'}) async {
    return await _api.post('/library/books/import', {
      'rows': rows,
      'mode': mode,
    });
  }

  /// Upload book cover image file bytes
  Future<String> uploadCoverImage(List<int> bytes, String filename) async {
    final res = await _api.multipartPostBytes(
      '/library/upload-cover',
      bytes,
      filename,
      'file',
    );
    if (res['success'] == true && res['data']?['url'] != null) {
      return res['data']['url'] as String;
    }
    throw res['detail'] ?? res['message'] ?? 'Failed to upload cover image';
  }

  /// Export books to CSV string
  Future<String> exportBooksCsv({
    String? search,
    String? category,
    String status = 'ACTIVE',
  }) async {
    final queryParams = <String, dynamic>{
      'format': 'csv',
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty && category != 'All Categories') 'category': category,
      'status': status,
    };
    return await _api.getString('/library/books/export', query: queryParams);
  }

  // ===========================================================================
  // UNIFIED DIGITAL LIBRARY & DRM-LITE STREAMING METHODS
  // ===========================================================================

  /// Obtain expiring DRM-lite signed streaming token for in-app reader/player
  Future<Map<String, dynamic>> fetchDigitalStreamToken(String bookId, {String? fileId}) async {
    final url = fileId != null
        ? '/library/books/$bookId/digital-stream-token?file_id=$fileId'
        : '/library/books/$bookId/digital-stream-token';
    return await _api.post(url, {});
  }

  /// Check current user's digital access permission
  Future<Map<String, dynamic>> checkDigitalAccess(String bookId) async {
    return await _api.post('/library/books/$bookId/check-access', {});
  }

  /// Submit digital access request (integrates into Requests module)
  Future<Map<String, dynamic>> requestDigitalAccess(String bookId, {String? reason, String? accessScope}) async {
    return await _api.post('/library/books/$bookId/request-digital-access', {
      'reason': reason ?? 'Request for digital access to this title.',
      'access_scope': accessScope ?? 'FULL',
    });
  }

  /// Fetch all granted & pending permissions for a book (Librarian Drawer)
  Future<List<DigitalAccessPermissionModel>> fetchBookPermissions(String bookId) async {
    final res = await _api.get('/library/books/$bookId/permissions', useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    return rawList.map((e) => DigitalAccessPermissionModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Librarian grant or approve digital permission
  Future<Map<String, dynamic>> grantDigitalPermission(String bookId, Map<String, dynamic> payload) async {
    return await _api.post('/library/books/$bookId/permissions/grant', payload);
  }

  /// Librarian revoke digital permission
  Future<Map<String, dynamic>> revokeDigitalPermission(String bookId, String userId) async {
    return await _api.post('/library/books/$bookId/permissions/revoke?user_id=$userId', {});
  }

  /// Sync reading or listening progress
  Future<Map<String, dynamic>> recordDigitalProgress(String bookId, Map<String, dynamic> payload) async {
    return await _api.post('/library/books/$bookId/progress', payload);
  }

  /// Fetch current user's reading or listening progress
  Future<ReadingProgressModel?> fetchDigitalProgress(String bookId, {String mediaType = 'EBOOK'}) async {
    final res = await _api.get('/library/books/$bookId/progress', query: {'media_type': mediaType}, useCache: false);
    if (res['data'] != null && res['data'] is Map) {
      return ReadingProgressModel.fromJson(Map<String, dynamic>.from(res['data'] as Map));
    }
    return null;
  }

  /// Fetch user's bookmarks, highlights, and annotations
  Future<List<BookInteractionModel>> fetchBookInteractions(String bookId) async {
    final res = await _api.get('/library/books/$bookId/interactions', useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    return rawList.map((e) => BookInteractionModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Create bookmark, highlight, or note
  Future<Map<String, dynamic>> createBookInteraction(String bookId, Map<String, dynamic> payload) async {
    return await _api.post('/library/books/$bookId/interactions', payload);
  }

  /// Delete bookmark, highlight, or note
  Future<Map<String, dynamic>> deleteBookInteraction(String bookId, String interactionId) async {
    return await _api.delete('/library/books/$bookId/interactions/$interactionId');
  }

  /// Fetch published reviews and ratings
  Future<List<BookReviewModel>> fetchBookReviews(String bookId) async {
    final res = await _api.get('/library/books/$bookId/reviews', useCache: false);
    final rawList = res['data'] is List ? res['data'] as List : [];
    return rawList.map((e) => BookReviewModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Submit rating and review
  Future<Map<String, dynamic>> createBookReview(String bookId, Map<String, dynamic> payload) async {
    return await _api.post('/library/books/$bookId/reviews', payload);
  }

  /// Fetch digital analytics metrics for a book
  Future<DigitalAnalyticsModel> fetchBookDigitalAnalytics(String bookId) async {
    final res = await _api.get('/library/books/$bookId/digital-analytics', useCache: false);
    final data = res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
    return DigitalAnalyticsModel.fromJson(data);
  }

  /// Upload multi-format digital asset (PDF, EPUB, MP3, MP4, WebM)
  Future<Map<String, dynamic>> uploadDigitalFile(List<int> bytes, String fileName) async {
    final res = await _api.multipartPostBytes('/library/upload-digital-file', bytes, fileName, 'file');
    return res['data'] is Map ? Map<String, dynamic>.from(res['data'] as Map) : <String, dynamic>{};
  }

  /// In-App EduSHAMIIT AI Reading Assistant Query
  Future<Map<String, dynamic>> askAiReadingAssistant(String bookId, Map<String, dynamic> payload) async {
    return await _api.post('/library/books/$bookId/ai-assist', payload);
  }
}




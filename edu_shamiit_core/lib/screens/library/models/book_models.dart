import '../../../config/app_config.dart';

/// Bibliographic Catalogue Record Model
class BookModel {

  final String id;
  final String schoolId;
  final String title;
  final String? subtitle;
  final String author;
  final List<String>? coAuthors;
  final String? publisher;
  final String? edition;
  final int? publicationYear;
  final String? financialYear;
  final int? pages;
  final String? description;
  final String? isbn10;
  final String? isbn13;
  final String? isbn;
  final String? categoryId;
  final String categoryName;
  final String? languageId;
  final String languageName;
  final String? bookTypeId;
  final String bookTypeName;
  final String? rackLocation;
  final String? shelfLocation;
  final String? coverUrl;
  final int totalCopies;
  final int availableCopies;
  final int issuedCopies;
  final int reservedCopies;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final String? primaryBarcode;
  final String? primaryAccessionNumber;
  final String? primaryCondition;
  final int overdueCopiesCount;
  final String? supplier;
  final double? purchasePrice;
  final String? acquisitionType;
  final String? invoiceRef;
  final DateTime? purchaseDate;

  // Digital & Access Control Properties
  final bool isDigital;
  final String digitalVisibility; // 'PUBLIC', 'RESTRICTED', 'UNLISTED'
  final String accessMode; // 'ALL', 'STUDENT_ONLY', 'TEACHER_ONLY', 'RESTRICTED_ROLES', 'CUSTOM'
  final bool requiresPermission;
  final List<String> allowedRoles;
  final List<String> allowedGrades;
  final List<String> allowedDepartments;
  final int? defaultAccessDurationDays;
  final bool allowNotes;
  final bool allowHighlights;
  final bool allowBookmarks;
  final bool allowCopyText;
  final bool allowScreenshots;
  final int maxConcurrentDevices;

  // Engagement & Metrics
  final double rating;
  final int totalReviews;
  final int viewCount;
  final int readCount;
  final int listenCount;
  final int watchCount;
  final int totalReadingSeconds;
  final int totalListeningSeconds;
  final int totalWatchingSeconds;

  // Academic Classification
  final String? previewUrl;
  final String? subject;
  final String? gradeLevel;
  final String? curriculum;
  final String? difficultyLevel;
  final String? ageGroup;
  final DateTime? publishedAt;

  // Dynamic Attached Assets & User Context
  final List<DigitalFileModel> digitalFiles;
  final String? userPermissionStatus; // 'PUBLIC', 'APPROVED', 'PENDING', 'EXPIRED', 'PERMISSION_REQUIRED'
  final ReadingProgressModel? userProgress;

  const BookModel({
    required this.id,
    required this.schoolId,
    required this.title,
    this.subtitle,
    required this.author,
    this.coAuthors,
    this.publisher,
    this.edition,
    this.publicationYear,
    this.financialYear,
    this.pages,
    this.description,
    this.isbn10,
    this.isbn13,
    this.isbn,
    this.categoryId,
    required this.categoryName,
    this.languageId,
    this.languageName = 'English',
    this.bookTypeId,
    this.bookTypeName = 'Physical Book',
    this.rackLocation,
    this.shelfLocation,
    this.coverUrl,
    this.totalCopies = 0,
    this.availableCopies = 0,
    this.issuedCopies = 0,
    this.reservedCopies = 0,
    this.status = 'ACTIVE',
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.primaryBarcode,
    this.primaryAccessionNumber,
    this.primaryCondition,
    this.overdueCopiesCount = 0,
    this.supplier,
    this.purchasePrice,
    this.acquisitionType,
    this.invoiceRef,
    this.purchaseDate,
    this.isDigital = false,
    this.digitalVisibility = 'PUBLIC',
    this.accessMode = 'ALL',
    this.requiresPermission = false,
    this.allowedRoles = const [],
    this.allowedGrades = const [],
    this.allowedDepartments = const [],
    this.defaultAccessDurationDays,
    this.allowNotes = true,
    this.allowHighlights = true,
    this.allowBookmarks = true,
    this.allowCopyText = false,
    this.allowScreenshots = false,
    this.maxConcurrentDevices = 2,
    this.rating = 0.0,
    this.totalReviews = 0,
    this.viewCount = 0,
    this.readCount = 0,
    this.listenCount = 0,
    this.watchCount = 0,
    this.totalReadingSeconds = 0,
    this.totalListeningSeconds = 0,
    this.totalWatchingSeconds = 0,
    this.previewUrl,
    this.subject,
    this.gradeLevel,
    this.curriculum,
    this.difficultyLevel = 'Intermediate',
    this.ageGroup,
    this.publishedAt,
    this.digitalFiles = const [],
    this.userPermissionStatus,
    this.userProgress,
  });

  bool get isArchived => archivedAt != null || status.toUpperCase() == 'ARCHIVED';
  bool get hasOverdue => overdueCopiesCount > 0;
  String get displayIsbn => isbn13 ?? isbn10 ?? isbn ?? 'N/A';
  String get displayLocation {
    final parts = [rackLocation, shelfLocation].where((s) => s != null && s.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Main Section' : parts.join(' - ');
  }

  // Format Helpers
  bool get isAudiobook => bookTypeName.toLowerCase().contains('audio');
  bool get isVideoBook => bookTypeName.toLowerCase().contains('video');
  bool get isEBook => bookTypeName.toLowerCase().contains('ebook') || bookTypeName.toLowerCase().contains('e-book') || (bookTypeName.toLowerCase().contains('digital') && !isAudiobook && !isVideoBook);
  bool get isJournal => bookTypeName.toLowerCase().contains('journal');
  bool get isMagazine => bookTypeName.toLowerCase().contains('magazine');
  bool get isResearchPaper => bookTypeName.toLowerCase().contains('research') || bookTypeName.toLowerCase().contains('paper');
  bool get isPhysical => bookTypeName.toLowerCase().contains('physical') || bookTypeName.toLowerCase().contains('paperback') || bookTypeName.toLowerCase().contains('hardcover') || (!isAudiobook && !isVideoBook && !isEBook && !bookTypeName.toLowerCase().contains('digital'));

  // Dual-Edition Availability Helpers
  bool get hasPhysicalEdition => totalCopies > 0 || isPhysical;
  bool get hasDigitalEdition => isDigital || digitalFiles.isNotEmpty || isEBook || isAudiobook || isVideoBook;
  bool get hasBothEditions => hasPhysicalEdition && hasDigitalEdition;
  bool get isUnrestrictedDigital => hasDigitalEdition && (!requiresPermission && digitalVisibility.toUpperCase() != 'RESTRICTED');

  String get formattedRating => rating > 0 ? rating.toStringAsFixed(1) : 'New';
  String get formattedReadTime {
    final totalSec = totalReadingSeconds + totalListeningSeconds + totalWatchingSeconds;
    if (totalSec < 60) return '$totalSec sec';
    if (totalSec < 3600) return '${(totalSec / 60).round()} min';
    return '${(totalSec / 3600).toStringAsFixed(1)} hrs';
  }

  factory BookModel.fromJson(Map<String, dynamic> json) {
    List<String>? parsedCoAuthors;
    if (json['co_authors'] != null && json['co_authors'] is List) {
      parsedCoAuthors = (json['co_authors'] as List).map((e) => e.toString()).toList();
    }

    List<DigitalFileModel> parsedFiles = [];
    if (json['digital_files'] != null && json['digital_files'] is List) {
      for (var f in (json['digital_files'] as List)) {
        if (f is Map) {
          try {
            parsedFiles.add(DigitalFileModel.fromJson(Map<String, dynamic>.from(f)));
          } catch (_) {}
        }
      }
    }

    ReadingProgressModel? progress;
    if (json['user_progress'] != null && json['user_progress'] is Map) {
      progress = ReadingProgressModel.fromJson(Map<String, dynamic>.from(json['user_progress'] as Map));
    } else if (json['user_progress'] is List && (json['user_progress'] as List).isNotEmpty) {
      progress = ReadingProgressModel.fromJson(Map<String, dynamic>.from((json['user_progress'] as List).first as Map));
    }

    final String bTypeName = json['book_type_name']?.toString() ?? 'Physical Book';
    final String typeLower = bTypeName.toLowerCase();
    final bool computedIsDigital = json['is_digital'] == true ||
        json['is_digital']?.toString().toLowerCase() == 'true' ||
        json['is_digital']?.toString() == 't' ||
        json['is_digital']?.toString() == '1' ||
        typeLower.contains('ebook') ||
        typeLower.contains('e-book') ||
        typeLower.contains('audio') ||
        typeLower.contains('video') ||
        typeLower.contains('digital') ||
        parsedFiles.isNotEmpty;

    return BookModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      subtitle: json['subtitle']?.toString(),
      author: json['author']?.toString() ?? 'Unknown Author',
      coAuthors: parsedCoAuthors,
      publisher: json['publisher']?.toString(),
      edition: json['edition']?.toString(),
      publicationYear: json['publication_year'] is int ? json['publication_year'] : int.tryParse(json['publication_year']?.toString() ?? ''),
      financialYear: json['financial_year']?.toString(),
      pages: json['pages'] is int ? json['pages'] : int.tryParse(json['pages']?.toString() ?? ''),
      description: json['description']?.toString(),
      isbn10: json['isbn10']?.toString(),
      isbn13: json['isbn13']?.toString(),
      isbn: json['isbn']?.toString(),
      categoryId: json['category_id']?.toString(),
      categoryName: json['category_name']?.toString() ?? json['category']?.toString() ?? 'General',
      languageId: json['language_id']?.toString(),
      languageName: json['language_name']?.toString() ?? 'English',
      bookTypeId: json['book_type_id']?.toString(),
      bookTypeName: bTypeName,
      rackLocation: json['rack_location']?.toString(),
      shelfLocation: json['shelf_location']?.toString(),
      coverUrl: json['cover_url'] != null && json['cover_url'].toString().isNotEmpty
          ? AppConfig.resolveUrl(json['cover_url'].toString())
          : null,
      previewUrl: json['preview_url'] != null && json['preview_url'].toString().isNotEmpty
          ? AppConfig.resolveUrl(json['preview_url'].toString())
          : null,
      totalCopies: json['total_copies'] is int ? json['total_copies'] : (int.tryParse(json['total_copies']?.toString() ?? '') ?? 0),

      availableCopies: json['available_copies'] is int ? json['available_copies'] : (int.tryParse(json['available_copies']?.toString() ?? '') ?? 0),
      issuedCopies: json['issued_copies'] is int ? json['issued_copies'] : (int.tryParse(json['issued_copies']?.toString() ?? '') ?? 0),
      reservedCopies: json['reserved_copies'] is int ? json['reserved_copies'] : (int.tryParse(json['reserved_copies']?.toString() ?? '') ?? 0),
      status: json['status']?.toString() ?? 'ACTIVE',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      archivedAt: json['archived_at'] != null ? DateTime.tryParse(json['archived_at'].toString()) : null,
      primaryBarcode: json['primary_barcode']?.toString(),
      primaryAccessionNumber: json['primary_accession_number']?.toString(),
      primaryCondition: json['primary_condition']?.toString() ?? json['condition']?.toString(),
      overdueCopiesCount: json['overdue_copies_count'] is int ? json['overdue_copies_count'] : (int.tryParse(json['overdue_copies_count']?.toString() ?? '') ?? 0),
      supplier: json['supplier']?.toString(),
      purchasePrice: json['purchase_price'] is num ? (json['purchase_price'] as num).toDouble() : double.tryParse(json['purchase_price']?.toString() ?? ''),
      acquisitionType: json['acquisition_type']?.toString(),
      invoiceRef: json['invoice_ref']?.toString(),
      purchaseDate: json['purchase_date'] != null ? DateTime.tryParse(json['purchase_date'].toString()) : null,
      isDigital: computedIsDigital,
      digitalVisibility: json['digital_visibility']?.toString() ?? 'PUBLIC',
      accessMode: json['access_mode']?.toString() ?? 'ALL',
      requiresPermission: json['requires_permission'] == true,
      allowedRoles: (json['allowed_roles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      allowedGrades: (json['allowed_grades'] as List?)?.map((e) => e.toString()).toList() ?? const [],

      allowedDepartments: (json['allowed_departments'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      defaultAccessDurationDays: json['default_access_duration_days'] is int ? json['default_access_duration_days'] : int.tryParse(json['default_access_duration_days']?.toString() ?? ''),
      allowNotes: json['allow_notes'] != false,
      allowHighlights: json['allow_highlights'] != false,
      allowBookmarks: json['allow_bookmarks'] != false,
      allowCopyText: json['allow_copy_text'] == true,
      allowScreenshots: json['allow_screenshots'] == true,
      maxConcurrentDevices: json['max_concurrent_devices'] is int ? json['max_concurrent_devices'] : 2,
      rating: json['rating'] is num ? (json['rating'] as num).toDouble() : 0.0,
      totalReviews: json['total_reviews'] is int ? json['total_reviews'] : (int.tryParse(json['total_reviews']?.toString() ?? '') ?? 0),
      viewCount: json['view_count'] is int ? json['view_count'] : (int.tryParse(json['view_count']?.toString() ?? '') ?? 0),
      readCount: json['read_count'] is int ? json['read_count'] : (int.tryParse(json['read_count']?.toString() ?? '') ?? 0),
      listenCount: json['listen_count'] is int ? json['listen_count'] : (int.tryParse(json['listen_count']?.toString() ?? '') ?? 0),
      watchCount: json['watch_count'] is int ? json['watch_count'] : (int.tryParse(json['watch_count']?.toString() ?? '') ?? 0),
      totalReadingSeconds: json['total_reading_seconds'] is int ? json['total_reading_seconds'] : (int.tryParse(json['total_reading_seconds']?.toString() ?? '') ?? 0),
      totalListeningSeconds: json['total_listening_seconds'] is int ? json['total_listening_seconds'] : (int.tryParse(json['total_listening_seconds']?.toString() ?? '') ?? 0),
      totalWatchingSeconds: json['total_watching_seconds'] is int ? json['total_watching_seconds'] : (int.tryParse(json['total_watching_seconds']?.toString() ?? '') ?? 0),
      subject: json['subject']?.toString(),

      gradeLevel: json['grade_level']?.toString(),
      curriculum: json['curriculum']?.toString(),
      difficultyLevel: json['difficulty_level']?.toString() ?? 'Intermediate',
      ageGroup: json['age_group']?.toString(),
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
      digitalFiles: parsedFiles,
      userPermissionStatus: json['user_permission_status']?.toString() ?? (json['access_status'] != null ? (json['access_status']['status']?.toString()) : null),
      userProgress: progress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'title': title,
      'subtitle': subtitle,
      'author': author,
      'co_authors': coAuthors,
      'publisher': publisher,
      'edition': edition,
      'publication_year': publicationYear,
      'financial_year': financialYear,
      'pages': pages,
      'description': description,
      'isbn10': isbn10,
      'isbn13': isbn13,
      'isbn': isbn,
      'category_id': categoryId,
      'category_name': categoryName,
      'language_id': languageId,
      'language_name': languageName,
      'book_type_id': bookTypeId,
      'book_type_name': bookTypeName,
      'rack_location': rackLocation,
      'shelf_location': shelfLocation,
      'cover_url': coverUrl,
      'total_copies': totalCopies,
      'available_copies': availableCopies,
      'issued_copies': issuedCopies,
      'reserved_copies': reservedCopies,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
      'primary_barcode': primaryBarcode,
      'primary_accession_number': primaryAccessionNumber,
      'overdue_copies_count': overdueCopiesCount,
      'is_digital': isDigital,
      'digital_visibility': digitalVisibility,
      'access_mode': accessMode,
      'requires_permission': requiresPermission,
      'rating': rating,
      'view_count': viewCount,
      'read_count': readCount,
      'listen_count': listenCount,
      'watch_count': watchCount,
    };
  }
}


/// Physical Book Copy Model
class BookCopyModel {
  final String id;
  final String bookId;
  final String schoolId;
  final String accessionNumber;
  final String barcode;
  final String qrCode;
  final int copyNumber;
  final String condition;
  final String status;
  final String? libraryName;
  final String? location;
  final String? rack;
  final String? shelf;
  final DateTime? acquisitionDate;
  final String? supplier;
  final double purchasePrice;
  final String? notes;
  final String? currentBorrowerId;
  final String? borrowerName;
  final String? borrowerAdmissionNo;
  final String? borrowerEmail;
  final DateTime? borrowedAt;
  final DateTime? dueDate;
  final DateTime? lastIssuedDate;
  final DateTime? lastReturnedDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const BookCopyModel({
    required this.id,
    required this.bookId,
    required this.schoolId,
    required this.accessionNumber,
    required this.barcode,
    required this.qrCode,
    this.copyNumber = 1,
    this.condition = 'GOOD',
    this.status = 'AVAILABLE',
    this.libraryName = 'Main Campus Library',
    this.location,
    this.rack,
    this.shelf,
    this.acquisitionDate,
    this.supplier,
    this.purchasePrice = 0.00,
    this.notes,
    this.currentBorrowerId,
    this.borrowerName,
    this.borrowerAdmissionNo,
    this.borrowerEmail,
    this.borrowedAt,
    this.dueDate,
    this.lastIssuedDate,
    this.lastReturnedDate,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  bool get isAvailable => status.toUpperCase() == 'AVAILABLE';
  bool get isIssued => status.toUpperCase() == 'ISSUED';
  bool get isOverdue => status.toUpperCase() == 'OVERDUE' || (isIssued && dueDate != null && dueDate!.isBefore(DateTime.now()));
  bool get isReserved => status.toUpperCase() == 'RESERVED';
  bool get isLostOrDamaged => status.toUpperCase() == 'LOST' || status.toUpperCase() == 'DAMAGED';

  factory BookCopyModel.fromJson(Map<String, dynamic> json) {
    return BookCopyModel(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      accessionNumber: json['accession_number']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? '',
      copyNumber: json['copy_number'] is int ? json['copy_number'] : (int.tryParse(json['copy_number']?.toString() ?? '') ?? 1),
      condition: json['condition']?.toString() ?? 'GOOD',
      status: json['status']?.toString() ?? 'AVAILABLE',
      libraryName: json['library_name']?.toString() ?? 'Main Campus Library',
      location: json['location']?.toString(),
      rack: json['rack']?.toString(),
      shelf: json['shelf']?.toString(),
      acquisitionDate: json['acquisition_date'] != null ? DateTime.tryParse(json['acquisition_date'].toString()) : null,
      supplier: json['supplier']?.toString(),
      purchasePrice: json['purchase_price'] is num ? (json['purchase_price'] as num).toDouble() : (double.tryParse(json['purchase_price']?.toString() ?? '') ?? 0.0),
      notes: json['notes']?.toString(),
      currentBorrowerId: json['current_borrower_id']?.toString(),
      borrowerName: json['borrower_name']?.toString(),
      borrowerAdmissionNo: json['borrower_admission_no']?.toString(),
      borrowerEmail: json['borrower_email']?.toString(),
      borrowedAt: json['borrowed_at'] != null ? DateTime.tryParse(json['borrowed_at'].toString()) : null,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      lastIssuedDate: json['last_issued_date'] != null ? DateTime.tryParse(json['last_issued_date'].toString()) : null,
      lastReturnedDate: json['last_returned_date'] != null ? DateTime.tryParse(json['last_returned_date'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now(),
      archivedAt: json['archived_at'] != null ? DateTime.tryParse(json['archived_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'school_id': schoolId,
      'accession_number': accessionNumber,
      'barcode': barcode,
      'qr_code': qrCode,
      'copy_number': copyNumber,
      'condition': condition,
      'status': status,
      'library_name': libraryName,
      'location': location,
      'rack': rack,
      'shelf': shelf,
      'acquisition_date': acquisitionDate?.toIso8601String(),
      'supplier': supplier,
      'purchase_price': purchasePrice,
      'notes': notes,
      'current_borrower_id': currentBorrowerId,
      'borrower_name': borrowerName,
      'borrower_admission_no': borrowerAdmissionNo,
      'borrower_email': borrowerEmail,
      'borrowed_at': borrowedAt?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'last_issued_date': lastIssuedDate?.toIso8601String(),
      'last_returned_date': lastReturnedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }
}

/// Aggregated KPI Metrics Model
class BookStatsModel {
  final int totalTitles;
  final int totalCopies;
  final int availableBooks;
  final int availableCopies;
  final int issuedBooks;
  final int issuedCopies;
  final int overdueBooks;
  final int overdueCopies;
  final int reservedCopies;
  final int lostDamagedCopies;
  final int lowAvailabilityBooks;
  final int archivedBooks;

  const BookStatsModel({
    this.totalTitles = 0,
    this.totalCopies = 0,
    this.availableBooks = 0,
    this.availableCopies = 0,
    this.issuedBooks = 0,
    this.issuedCopies = 0,
    this.overdueBooks = 0,
    this.overdueCopies = 0,
    this.reservedCopies = 0,
    this.lostDamagedCopies = 0,
    this.lowAvailabilityBooks = 0,
    this.archivedBooks = 0,
  });

  factory BookStatsModel.fromJson(Map<String, dynamic> json) {
    return BookStatsModel(
      totalTitles: json['total_titles'] is int ? json['total_titles'] : (int.tryParse(json['total_titles']?.toString() ?? '') ?? 0),
      totalCopies: json['total_copies'] is int ? json['total_copies'] : (int.tryParse(json['total_copies']?.toString() ?? '') ?? 0),
      availableBooks: json['available_books'] is int ? json['available_books'] : (int.tryParse(json['available_books']?.toString() ?? '') ?? 0),
      availableCopies: json['available_copies'] is int ? json['available_copies'] : (int.tryParse(json['available_copies']?.toString() ?? '') ?? 0),
      issuedBooks: json['issued_books'] is int ? json['issued_books'] : (int.tryParse(json['issued_books']?.toString() ?? '') ?? 0),
      issuedCopies: json['issued_copies'] is int ? json['issued_copies'] : (int.tryParse(json['issued_copies']?.toString() ?? '') ?? 0),
      overdueBooks: json['overdue_books'] is int ? json['overdue_books'] : (int.tryParse(json['overdue_books']?.toString() ?? '') ?? 0),
      overdueCopies: json['overdue_copies'] is int ? json['overdue_copies'] : (int.tryParse(json['overdue_copies']?.toString() ?? '') ?? 0),
      reservedCopies: json['reserved_copies'] is int ? json['reserved_copies'] : (int.tryParse(json['reserved_copies']?.toString() ?? '') ?? 0),
      lostDamagedCopies: json['lost_damaged_copies'] is int ? json['lost_damaged_copies'] : (int.tryParse(json['lost_damaged_copies']?.toString() ?? '') ?? 0),
      lowAvailabilityBooks: json['low_availability_books'] is int ? json['low_availability_books'] : (int.tryParse(json['low_availability_books']?.toString() ?? '') ?? 0),
      archivedBooks: json['archived_books'] is int ? json['archived_books'] : (int.tryParse(json['archived_books']?.toString() ?? '') ?? 0),
    );
  }
}

/// Dynamic Filter Options Model (Lookup-driven)
class BookFilterOptionsModel {
  final List<String> categories;
  final List<String> authors;
  final List<String> publishers;
  final List<String> years;
  final List<String> languages;
  final List<String> bookTypes;
  final List<String> conditions;
  final List<String> acquisitionTypes;
  final List<String> racks;
  final List<String> classes;
  final List<String> subjects;
  final List<AppRoleOptionModel> roles;

  const BookFilterOptionsModel({
    this.categories = const [],
    this.authors = const [],
    this.publishers = const [],
    this.years = const [],
    this.languages = const [],
    this.bookTypes = const [],
    this.conditions = const [],
    this.acquisitionTypes = const [],
    this.racks = const [],
    this.classes = const [],
    this.subjects = const [],
    this.roles = const [],
  });

  factory BookFilterOptionsModel.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'] as List?;
    List<AppRoleOptionModel> parsedRoles = [];
    if (rawRoles != null) {
      for (final r in rawRoles) {
        if (r is Map) {
          parsedRoles.add(AppRoleOptionModel.fromJson(Map<String, dynamic>.from(r)));
        } else if (r != null) {
          final s = r.toString();
          parsedRoles.add(AppRoleOptionModel(code: s.toUpperCase(), name: s, displayName: s));
        }
      }
    }

    return BookFilterOptionsModel(
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? [],
      authors: (json['authors'] as List?)?.map((e) => e.toString()).toList() ?? [],
      publishers: (json['publishers'] as List?)?.map((e) => e.toString()).toList() ?? [],
      years: (json['years'] as List?)?.map((e) => e.toString()).toList() ?? [],
      languages: (json['languages'] as List?)?.map((e) => e.toString()).toList() ?? [],
      bookTypes: (json['book_types'] as List?)?.map((e) => e.toString()).toList() ?? [],
      conditions: (json['conditions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      acquisitionTypes: (json['acquisition_types'] as List?)?.map((e) => e.toString()).toList() ?? [],
      racks: (json['racks'] as List?)?.map((e) => e.toString()).toList() ?? [],
      classes: (json['classes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      subjects: (json['subjects'] as List?)?.map((e) => e.toString()).toList() ?? [],
      roles: parsedRoles,
    );
  }
}

/// Dynamic Role Option Model (from app_roles)
class AppRoleOptionModel {
  final String code;
  final String name;
  final String displayName;

  const AppRoleOptionModel({
    required this.code,
    required this.name,
    required this.displayName,
  });

  factory AppRoleOptionModel.fromJson(Map<String, dynamic> json) {
    return AppRoleOptionModel(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['name']?.toString() ?? '',
    );
  }
}

/// Digital Media File Model (Attached to Digital Books)
class DigitalFileModel {
  final String id;
  final String bookId;
  final String schoolId;
  final String fileType; // EBOOK_PDF, EBOOK_EPUB, EBOOK_HTML, AUDIO_MP3, AUDIO_M4A, VIDEO_MP4, VIDEO_HLS
  final String sourceType; // FILE_UPLOAD, DIRECT_LINK, LIVE_STREAM, YOUTUBE_STREAM, EXTERNAL_LINK
  final String? title;
  final String storageKey;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final int durationSeconds;
  final int pageCount;
  final String processingStatus; // READY, PROCESSING, FAILED, ENCRYPTED
  final bool isEncrypted;
  final String? streamUrl;
  final bool isPrimary;
  final bool isLiveStream;
  final int sortOrder;
  final DateTime createdAt;

  const DigitalFileModel({
    required this.id,
    required this.bookId,
    required this.schoolId,
    required this.fileType,
    this.sourceType = 'FILE_UPLOAD',
    this.title,
    required this.storageKey,
    required this.fileName,
    required this.mimeType,
    this.fileSizeBytes = 0,
    this.durationSeconds = 0,
    this.pageCount = 0,
    this.processingStatus = 'READY',
    this.isEncrypted = false,
    this.streamUrl,
    this.isPrimary = true,
    this.isLiveStream = false,
    this.sortOrder = 0,
    required this.createdAt,
  });

  String get displayTitle => (title != null && title!.trim().isNotEmpty) ? title!.trim() : fileName;

  bool get isPdf => fileType == 'EBOOK_PDF' || mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
  bool get isEpub => fileType == 'EBOOK_EPUB' || mimeType.contains('epub') || fileName.toLowerCase().endsWith('.epub');
  bool get isAudio => fileType.startsWith('AUDIO') || mimeType.startsWith('audio');
  bool get isVideo => fileType.startsWith('VIDEO') || mimeType.startsWith('video');

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDuration {
    if (isLiveStream) return '🔴 LIVE';
    if (durationSeconds <= 0) return '';
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    if (mins < 60) return '$mins min ${secs}s';
    final hrs = mins ~/ 60;
    final remMins = mins % 60;
    return '$hrs hr ${remMins}m';
  }

  factory DigitalFileModel.fromJson(Map<String, dynamic> json) {
    return DigitalFileModel(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      fileType: json['file_type']?.toString() ?? 'EBOOK_PDF',
      sourceType: json['source_type']?.toString() ?? 'FILE_UPLOAD',
      title: json['title']?.toString(),
      storageKey: json['storage_key']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? 'File',
      mimeType: json['mime_type']?.toString() ?? 'application/pdf',
      fileSizeBytes: json['file_size_bytes'] is int ? json['file_size_bytes'] : (int.tryParse(json['file_size_bytes']?.toString() ?? '') ?? 0),
      durationSeconds: json['duration_seconds'] is int ? json['duration_seconds'] : (int.tryParse(json['duration_seconds']?.toString() ?? '') ?? 0),
      pageCount: json['page_count'] is int ? json['page_count'] : (int.tryParse(json['page_count']?.toString() ?? '') ?? 0),
      processingStatus: json['processing_status']?.toString() ?? 'READY',
      isEncrypted: json['is_encrypted'] == true,
      streamUrl: json['stream_url'] != null && json['stream_url'].toString().isNotEmpty
          ? AppConfig.resolveUrl(json['stream_url'].toString())
          : null,

      isPrimary: json['is_primary'] != false,
      isLiveStream: json['is_live_stream'] == true,
      sortOrder: json['sort_order'] is int ? json['sort_order'] : (int.tryParse(json['sort_order']?.toString() ?? '') ?? 0),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'school_id': schoolId,
      'file_type': fileType,
      'source_type': sourceType,
      'title': title,
      'storage_key': storageKey,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'duration_seconds': durationSeconds,
      'page_count': pageCount,
      'processing_status': processingStatus,
      'is_encrypted': isEncrypted,
      'stream_url': streamUrl,
      'is_primary': isPrimary,
      'is_live_stream': isLiveStream,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Digital Access Permission Model (Librarian Granted Access)
class DigitalAccessPermissionModel {
  final String id;
  final String bookId;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userRole;
  final String? userAvatar;
  final String status; // PENDING, APPROVED, REJECTED, EXPIRED, REVOKED
  final String accessScope; // FULL, READ_ONLY, LISTEN_ONLY, WATCH_ONLY
  final String? grantedByName;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final String? reason;

  const DigitalAccessPermissionModel({
    required this.id,
    required this.bookId,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userRole,
    this.userAvatar,
    this.status = 'APPROVED',
    this.accessScope = 'FULL',
    this.grantedByName,
    required this.grantedAt,
    this.expiresAt,
    this.reason,
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isActive => status == 'APPROVED' && !isExpired;

  factory DigitalAccessPermissionModel.fromJson(Map<String, dynamic> json) {
    return DigitalAccessPermissionModel(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['full_name']?.toString() ?? json['user_name']?.toString(),
      userEmail: json['email']?.toString(),
      userRole: json['user_role']?.toString(),
      userAvatar: json['avatar_url']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      accessScope: json['access_scope']?.toString() ?? 'FULL',
      grantedByName: json['granted_by_name']?.toString(),
      grantedAt: json['granted_at'] != null ? DateTime.tryParse(json['granted_at'].toString()) ?? DateTime.now() : DateTime.now(),
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      reason: json['reason']?.toString(),
    );
  }
}

/// Reading, Audio & Video Progress Model
class ReadingProgressModel {
  final String id;
  final String bookId;
  final String userId;
  final String mediaType; // EBOOK, AUDIOBOOK, VIDEOBOOK
  final int currentPage;
  final int totalPages;
  final double progressPct;
  final double positionSeconds;
  final double totalDurationSeconds;
  final double playbackSpeed;
  final int timeSpentSeconds;
  final bool isCompleted;
  final DateTime lastReadAt;

  const ReadingProgressModel({
    required this.id,
    required this.bookId,
    required this.userId,
    this.mediaType = 'EBOOK',
    this.currentPage = 1,
    this.totalPages = 1,
    this.progressPct = 0.0,
    this.positionSeconds = 0.0,
    this.totalDurationSeconds = 0.0,
    this.playbackSpeed = 1.0,
    this.timeSpentSeconds = 0,
    this.isCompleted = false,
    required this.lastReadAt,
  });

  String get formattedProgress => '${progressPct.toStringAsFixed(0)}%';

  factory ReadingProgressModel.fromJson(Map<String, dynamic> json) {
    return ReadingProgressModel(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'EBOOK',
      currentPage: json['current_page'] is int ? json['current_page'] : (int.tryParse(json['current_page']?.toString() ?? '') ?? 1),
      totalPages: json['total_pages'] is int ? json['total_pages'] : (int.tryParse(json['total_pages']?.toString() ?? '') ?? 1),
      progressPct: json['progress_pct'] is num ? (json['progress_pct'] as num).toDouble() : 0.0,
      positionSeconds: json['position_seconds'] is num ? (json['position_seconds'] as num).toDouble() : 0.0,
      totalDurationSeconds: json['total_duration_seconds'] is num ? (json['total_duration_seconds'] as num).toDouble() : 0.0,
      playbackSpeed: json['playback_speed'] is num ? (json['playback_speed'] as num).toDouble() : 1.0,
      timeSpentSeconds: json['time_spent_seconds'] is int ? json['time_spent_seconds'] : (int.tryParse(json['time_spent_seconds']?.toString() ?? '') ?? 0),
      isCompleted: json['is_completed'] == true,
      lastReadAt: json['last_read_at'] != null ? DateTime.tryParse(json['last_read_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Book Interaction & Annotation Model (Bookmarks, Highlights, Notes)
class BookInteractionModel {
  final String id;
  final String bookId;
  final String userId;
  final String interactionType; // BOOKMARK, HIGHLIGHT, NOTE, FAVORITE, READ_LATER, COMPLETED
  final int? pageNumber;
  final double? timestampSeconds;
  final String? selectedText;
  final String highlightColor;
  final String? noteContent;
  final String? chapterTitle;
  final DateTime createdAt;

  const BookInteractionModel({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.interactionType,
    this.pageNumber,
    this.timestampSeconds,
    this.selectedText,
    this.highlightColor = '#FEF08A',
    this.noteContent,
    this.chapterTitle,
    required this.createdAt,
  });

  factory BookInteractionModel.fromJson(Map<String, dynamic> json) {
    return BookInteractionModel(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      interactionType: json['interaction_type']?.toString() ?? 'BOOKMARK',
      pageNumber: json['page_number'] is int ? json['page_number'] : int.tryParse(json['page_number']?.toString() ?? ''),
      timestampSeconds: json['timestamp_seconds'] is num ? (json['timestamp_seconds'] as num).toDouble() : null,
      selectedText: json['selected_text']?.toString(),
      highlightColor: json['highlight_color']?.toString() ?? '#FEF08A',
      noteContent: json['note_content']?.toString(),
      chapterTitle: json['chapter_title']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Book Review & Rating Model
class BookReviewModel {
  final String id;
  final String bookId;
  final String userId;
  final String reviewerName;
  final String? reviewerAvatar;
  final int rating;
  final String? reviewTitle;
  final String? reviewText;
  final String reactionEmoji;
  final String status;
  final int helpfulCount;
  final DateTime createdAt;

  const BookReviewModel({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.reviewerName,
    this.reviewerAvatar,
    required this.rating,
    this.reviewTitle,
    this.reviewText,
    this.reactionEmoji = '👍',
    this.status = 'PUBLISHED',
    this.helpfulCount = 0,
    required this.createdAt,
  });

  factory BookReviewModel.fromJson(Map<String, dynamic> json) {
    return BookReviewModel(
      id: json['id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      reviewerName: json['reviewer_name']?.toString() ?? 'Library Member',
      reviewerAvatar: json['reviewer_avatar']?.toString(),
      rating: json['rating'] is int ? json['rating'] : (int.tryParse(json['rating']?.toString() ?? '') ?? 5),
      reviewTitle: json['review_title']?.toString(),
      reviewText: json['review_text']?.toString(),
      reactionEmoji: json['reaction_emoji']?.toString() ?? '👍',
      status: json['status']?.toString() ?? 'PUBLISHED',
      helpfulCount: json['helpful_count'] is int ? json['helpful_count'] : (int.tryParse(json['helpful_count']?.toString() ?? '') ?? 0),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

/// Digital Analytics Model
class DigitalAnalyticsModel {
  final int totalReads;
  final int totalListens;
  final int totalWatches;
  final double totalReadingHours;
  final double totalListeningHours;
  final double totalWatchingHours;
  final double avgCompletionPct;
  final int uniqueReaders;
  final int totalBookmarks;
  final int totalHighlights;
  final int totalNotes;

  const DigitalAnalyticsModel({
    this.totalReads = 0,
    this.totalListens = 0,
    this.totalWatches = 0,
    this.totalReadingHours = 0.0,
    this.totalListeningHours = 0.0,
    this.totalWatchingHours = 0.0,
    this.avgCompletionPct = 0.0,
    this.uniqueReaders = 0,
    this.totalBookmarks = 0,
    this.totalHighlights = 0,
    this.totalNotes = 0,
  });

  factory DigitalAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return DigitalAnalyticsModel(
      totalReads: json['total_reads'] is int ? json['total_reads'] : (int.tryParse(json['total_reads']?.toString() ?? '') ?? 0),
      totalListens: json['total_listens'] is int ? json['total_listens'] : (int.tryParse(json['total_listens']?.toString() ?? '') ?? 0),
      totalWatches: json['total_watches'] is int ? json['total_watches'] : (int.tryParse(json['total_watches']?.toString() ?? '') ?? 0),
      totalReadingHours: json['total_reading_hours'] is num ? (json['total_reading_hours'] as num).toDouble() : 0.0,
      totalListeningHours: json['total_listening_hours'] is num ? (json['total_listening_hours'] as num).toDouble() : 0.0,
      totalWatchingHours: json['total_watching_hours'] is num ? (json['total_watching_hours'] as num).toDouble() : 0.0,
      avgCompletionPct: json['avg_completion_pct'] is num ? (json['avg_completion_pct'] as num).toDouble() : 0.0,
      uniqueReaders: json['unique_readers'] is int ? json['unique_readers'] : (int.tryParse(json['unique_readers']?.toString() ?? '') ?? 0),
      totalBookmarks: json['total_bookmarks'] is int ? json['total_bookmarks'] : (int.tryParse(json['total_bookmarks']?.toString() ?? '') ?? 0),
      totalHighlights: json['total_highlights'] is int ? json['total_highlights'] : (int.tryParse(json['total_highlights']?.toString() ?? '') ?? 0),
      totalNotes: json['total_notes'] is int ? json['total_notes'] : (int.tryParse(json['total_notes']?.toString() ?? '') ?? 0),
    );
  }
}


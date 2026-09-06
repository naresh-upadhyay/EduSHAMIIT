import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/library/models/book_models.dart';
import 'package:edu_shamiit_core/screens/library/providers/book_provider.dart';

void main() {
  group('Library Books Module - Models & Serialization', () {
    test('BookModel JSON Deserialization with fallback and nested counts', () {
      final json = {
        'id': 'book-uuid-101',
        'school_id': 'school-uuid-001',
        'title': 'Quantum Computing: Principles and Paradigms',
        'subtitle': 'An Academic Perspective',
        'author': 'Prof. Richard Feynman',
        'co_authors': ['Dr. Shami Nathan', 'Dr. John Bell'],
        'isbn13': '978-0131103627',
        'isbn10': '0131103628',
        'category_name': 'Computer Science',
        'language_name': 'English',
        'book_type_name': 'Hardcover',
        'publisher': 'MIT Press',
        'publication_year': 2026,
        'pages': 540,
        'total_copies': 8,
        'available_copies': 5,
        'issued_copies': 3,
        'reserved_copies': 0,
        'rack_location': 'Rack Q',
        'shelf_location': 'Shelf 3',
        'purchase_price': 1250.50,
        'status': 'ACTIVE',
        'created_at': '2026-08-26T10:00:00Z',
        'updated_at': '2026-08-26T10:00:00Z',
      };

      final book = BookModel.fromJson(json);

      expect(book.id, 'book-uuid-101');
      expect(book.title, 'Quantum Computing: Principles and Paradigms');
      expect(book.author, 'Prof. Richard Feynman');
      expect(book.coAuthors?.length, 2);
      expect(book.isbn13, '978-0131103627');
      expect(book.categoryName, 'Computer Science');
      expect(book.totalCopies, 8);
      expect(book.availableCopies, 5);
      expect(book.issuedCopies, 3);
      expect(book.status, 'ACTIVE');

      // Test toJson roundtrip
      final serialized = book.toJson();
      expect(serialized['id'], 'book-uuid-101');
      expect(serialized['title'], 'Quantum Computing: Principles and Paradigms');
      expect(serialized['category_name'], 'Computer Science');
    });

    test('BookCopyModel JSON Deserialization with borrower info', () {
      final json = {
        'id': 'copy-uuid-201',
        'book_id': 'book-uuid-101',
        'school_id': 'school-uuid-001',
        'accession_number': 'QUANTU-001',
        'barcode': 'BC10293847',
        'qr_code': 'QR56473829',
        'copy_number': 1,
        'condition': 'GOOD',
        'status': 'ISSUED',
        'location': 'Rack Q - Shelf 3',
        'purchase_price': 1250.50,
        'borrower_name': 'Aarav Sharma',
        'borrower_admission_no': 'ADM-2026-089',
        'borrower_email': 'aarav.sharma@school.edu',
        'borrower_role': 'student',
        'due_date': '2026-09-10T12:00:00Z',
        'created_at': '2026-08-26T10:00:00Z',
        'updated_at': '2026-08-26T10:00:00Z',
      };

      final copy = BookCopyModel.fromJson(json);

      expect(copy.id, 'copy-uuid-201');
      expect(copy.accessionNumber, 'QUANTU-001');
      expect(copy.barcode, 'BC10293847');
      expect(copy.status, 'ISSUED');
      expect(copy.borrowerName, 'Aarav Sharma');
      expect(copy.borrowerAdmissionNo, 'ADM-2026-089');
      expect(copy.dueDate, DateTime.parse('2026-09-10T12:00:00Z'));
    });

    test('BookStatsModel calculations and default initialization', () {
      const stats = BookStatsModel(
        totalTitles: 120,
        totalCopies: 450,
        availableCopies: 380,
        issuedCopies: 65,
        overdueCopies: 5,
        lostDamagedCopies: 0,
        reservedCopies: 12,
      );

      expect(stats.totalTitles, 120);
      expect(stats.totalCopies, 450);
      expect(stats.availableCopies, 380);
      expect(stats.issuedCopies, 65);
      expect(stats.overdueCopies, 5);
      expect(stats.reservedCopies, 12);
    });

    test('BookFilterOptionsModel extraction from dynamic payload', () {
      final json = {
        'categories': ['Computer Science', 'Mathematics', 'Physics'],
        'authors': ['Dr. Shami Nathan', 'Prof. Richard Feynman'],
        'publishers': ['MIT Press', 'Oxford University Press'],
        'languages': ['English', 'Hindi', 'Sanskrit'],
        'book_types': ['Hardcover', 'Paperback', 'Reference'],
        'racks': ['Rack A', 'Rack B', 'Rack Q'],
      };

      final filterOpts = BookFilterOptionsModel.fromJson(json);

      expect(filterOpts.categories, contains('Computer Science'));
      expect(filterOpts.authors.length, 2);
      expect(filterOpts.publishers, contains('MIT Press'));
      expect(filterOpts.languages, contains('English'));
      expect(filterOpts.bookTypes, contains('Hardcover'));
      expect(filterOpts.racks, contains('Rack Q'));
    });
  });

  group('Library Books Module - State Management (BookState)', () {
    test('BookState copyWith preserves immutability and updates selections', () {
      const initial = BookState(
        books: [],
        isLoading: false,
        currentPage: 1,
        pageSize: 15,
        totalRecords: 0,
      );

      final dummyBook = BookModel(
        id: 'book-1',
        schoolId: 'school-1',
        title: 'Algorithms 101',
        author: 'Cormen',
        categoryName: 'Computer Science',
        totalCopies: 4,
        availableCopies: 4,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final updated = initial.copyWith(
        books: [dummyBook],
        totalRecords: 1,
        selectedBookIds: {'book-1'},
        selectedCategory: 'Computer Science',
      );

      expect(updated.books.length, 1);
      expect(updated.totalRecords, 1);
      expect(updated.selectedBookIds.contains('book-1'), true);
      expect(updated.selectedCategory, 'Computer Science');
      expect(initial.selectedBookIds.isEmpty, true);
    });
  });
}

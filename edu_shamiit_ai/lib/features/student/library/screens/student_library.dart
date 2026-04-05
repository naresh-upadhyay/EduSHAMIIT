import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentLibrary extends ConsumerStatefulWidget {
  const StudentLibrary({super.key});

  @override
  ConsumerState<StudentLibrary> createState() => _StudentLibraryState();
}

class _StudentLibraryState extends ConsumerState<StudentLibrary> {
  int _selectedTab = 0; // 0=My Books, 1=Browse, 2=Digital, 3=Request

  final List<Map<String, dynamic>> _myBooks = [
    {
      'title': 'NCERT Physics Part II',
      'author': 'By NCERT · Class XII',
      'dueDate': 'April 5',
      'status': 'on_time',
      'icon': '📘',
      'color': const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
    },
    {
      'title': 'H.C. Verma Vol.1',
      'author': 'By H.C. Verma',
      'dueDate': 'March 30',
      'status': 'overdue_soon',
      'icon': '📙',
      'color': const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
    },
    {
      'title': 'R.D. Sharma Class X',
      'author': 'By R.D. Sharma',
      'dueDate': 'April 10',
      'status': 'on_time',
      'icon': '📗',
      'color': const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)]),
    },
  ];

  final List<Map<String, dynamic>> _browseBooks = [
    {
      'title': 'The Alchemist',
      'author': 'Paulo Coelho · Fiction',
      'status': 'Available (3 copies)',
      'icon': '📕',
      'color': const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFF97316)]),
    },
    {
      'title': 'Wings of Fire',
      'author': 'A.P.J. Abdul Kalam · Autobiography',
      'status': 'Available (1 copy)',
      'icon': '📗',
      'color': const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF5FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B0764), Color(0xFF6D28D9)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Library',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white15,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🤖 Recommend',
                        style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text('🔍', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 8),
                      Text(
                        'Search books, journals...',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildTabChip('My Books (3)', 0),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                if (_selectedTab == 0) ..._buildMyBooksTab(),
                if (_selectedTab == 1) ..._buildBrowseTab(),
                if (_selectedTab == 2) ..._buildDigitalTab(),
                if (_selectedTab == 3) ..._buildRequestTab(),
                const SizedBox(height: 50),
              ],
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF6D28D9) : const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF6D28D9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMyBooksTab() {
    return _myBooks.map((book) {
      final isOverdue = book['status'] == 'overdue_soon';
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 66,
              decoration: BoxDecoration(
                gradient: book['color'] as Gradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(book['icon']!, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title']!,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book['author']!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: StudentColors.text3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        isOverdue ? '⚠️ Return by: ${book['dueDate']}' : 'Return by: ${book['dueDate']} ✅',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? StudentColors.error : StudentColors.success,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => _showRenewDialog(book),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOverdue ? StudentColors.warningBg : StudentColors.primaryLight,
                          foregroundColor: isOverdue ? StudentColors.warning : StudentColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('🔄 Renew', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildBrowseTab() {
    return _browseBooks.map((book) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 66,
              decoration: BoxDecoration(
                gradient: book['color'] as Gradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(book['icon']!, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title']!,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book['author']!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: StudentColors.text3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book['status']!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: StudentColors.success,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () => _showBorrowDialog(book),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StudentColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('📖 Borrow Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildDigitalTab() {
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 66,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('💻', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NCERT Physics XII (Digital)',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'eBook · PDF · 28 MB',
                    style: TextStyle(fontSize: 10, color: StudentColors.text3),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '📥 Download / Read Online',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: StudentColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildRequestTab() {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📋 Request a Book',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildRequestField('Book Title', 'Enter book title'),
            const SizedBox(height: 8),
            _buildRequestField('Author Name', 'Enter author name'),
            const SizedBox(height: 8),
            _buildRequestField('ISBN (optional)', 'Enter ISBN'),
            const SizedBox(height: 8),
            TextFormField(
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Why do you need this book?',
                filled: true,
                fillColor: StudentColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: StudentColors.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _showRequestSuccess(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '📤 Submit Request',
                  style: TextStyle(fontFamily: AppFonts.heading, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildRequestField(String hint, String placeholder) {
    return TextFormField(
      decoration: InputDecoration(
        hintText: placeholder,
        filled: true,
        fillColor: StudentColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StudentColors.border),
        ),
      ),
    );
  }

  void _showRenewDialog(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📗 Book Renewed!'),
        content: Text('Your book "${book['title']}" has been renewed for 15 additional days.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBorrowDialog(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📖 Borrow Book'),
        content: Text('Would you like to borrow "${book['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Book borrowed successfully!')),
              );
            },
            child: const Text('Borrow'),
          ),
        ],
      ),
    );
  }

  void _showRequestSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📋 Book Request Submitted!'),
        content: const Text('Your book request has been submitted. The librarian will notify you when the book is available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
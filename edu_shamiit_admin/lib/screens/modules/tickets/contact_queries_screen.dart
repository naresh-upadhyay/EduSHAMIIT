import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class ContactQueriesScreen extends ConsumerStatefulWidget {
  const ContactQueriesScreen({super.key});

  @override
  ConsumerState<ContactQueriesScreen> createState() => _ContactQueriesScreenState();
}

class _ContactQueriesScreenState extends ConsumerState<ContactQueriesScreen> {
  List<dynamic> _queries = [];
  int _totalRecords = 0;
  bool _isLoading = true;

  dynamic _selectedQuery;
  final _responseController = TextEditingController();
  final _searchController = TextEditingController();

  // Pagination & Filtering state
  int _currentPage = 1;
  final int _pageSize = 10;
  String _searchQuery = "";
  String _selectedStatus = "All";

  final List<String> _statuses = ['All', 'Pending', 'In Progress', 'Resolved'];

  @override
  void initState() {
    super.initState();
    _fetchQueries();
  }

  @override
  void dispose() {
    _responseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchQueries() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'page_size': _pageSize.toString(),
      };

      if (_selectedStatus != "All") {
        queryParams['status'] = _selectedStatus;
      }
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }

      final res = await ApiService().get('/contact/admin/queries', query: queryParams, useCache: false);
      if (res['success'] == true) {
        setState(() {
          _queries = res['data'] as List<dynamic>? ?? [];
          _totalRecords = res['total'] as int? ?? 0;
        });

        // Auto-select first query if list is not empty and none is currently selected
        if (_queries.isNotEmpty && _selectedQuery == null) {
          _selectQuery(_queries.first);
        }
      }
    } catch (e) {
      _showSnackBar('Error loading queries: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectQuery(dynamic query) {
    setState(() {
      _selectedQuery = query;
      _responseController.text = query['response'] ?? '';
    });
  }

  Future<void> _updateQuery(String status) async {
    if (_selectedQuery == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        'status': status,
        'response': _responseController.text.trim(),
      };

      final queryId = _selectedQuery['id'];
      final res = await ApiService().put('/contact/admin/queries/$queryId', payload);

      if (res['success'] == true) {
        _showSnackBar('Query updated successfully!', Colors.green);
        _selectedQuery = res['data'];
        await _fetchQueries();
      } else {
        _showSnackBar(res['detail'] ?? 'Failed to update query', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error updating query: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    final textMuted = isDark ? Colors.white30 : const Color(0xFF94A3B8);
    const accentColor = Color(0xFF6366F1);

    final isWideScreen = MediaQuery.of(context).size.width >= 1000;

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: _isLoading && _queries.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Public Contact Queries',
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Monitor and respond to queries sent by public users.',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _fetchQueries,
                          icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                          label: Text('Refresh', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Filter controls
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Search queries by sender name, subject, or message...',
                                hintStyle: GoogleFonts.dmSans(color: textMuted),
                                prefixIcon: Icon(Icons.search, color: textMuted),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _currentPage = 1;
                                });
                                _fetchQueries();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              dropdownColor: cardBg,
                              onChanged: (val) {
                                setState(() {
                                  _selectedStatus = val ?? 'All';
                                  _currentPage = 1;
                                });
                                _fetchQueries();
                              },
                              items: _statuses.map((s) {
                                return DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s == 'All' ? 'All Statuses' : '$s Status', style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary)),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Content Area
                    Expanded(
                      child: isWideScreen
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left List Pane
                                Expanded(
                                  flex: 4,
                                  child: _buildListPane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                                ),
                                const SizedBox(width: 24),
                                // Right Detail Pane
                                Expanded(
                                  flex: 6,
                                  child: _buildDetailPane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: _selectedQuery == null 
                                      ? _buildListPane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor) 
                                      : _buildDetailPane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
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

  Widget _buildListPane(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    if (_queries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: textMuted),
            const SizedBox(height: 16),
            Text(
              'No Contact Queries Found',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: _queries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final query = _queries[index];
              final isSelected = _selectedQuery != null && _selectedQuery['id'] == query['id'];

              final selectedBg = isDark 
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                  : const Color(0xFFEEF2FF);
              
              final selectedBorder = isDark
                  ? accentColor
                  : const Color(0xFF818CF8);

              return InkWell(
                onTap: () => _selectQuery(query),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedBg : cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? selectedBorder : borderColor,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              query['full_name'] ?? 'Anonymous',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          _buildStatusBadge(query['status'], isDark),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        query['subject'] ?? 'No Subject',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        query['message'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              query['email'] ?? '',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(query['created_at']),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildPaginationControls(textSecondary),
      ],
    );
  }

  Widget _buildDetailPane(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    if (_selectedQuery == null) {
      return Center(
        child: Text(
          'Select a query to view details',
          style: GoogleFonts.dmSans(color: textSecondary),
        ),
      );
    }

    final query = _selectedQuery;
    final canRespond = query['status'] != 'Resolved';
    final String initial = (query['full_name'] ?? 'A').toString().trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detail Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query['subject'] ?? 'No Subject',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${query['full_name']} (${query['email']})',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(query['status'], isDark),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(query['created_at']),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),

          // Message Card
          Text(
            'Query Message:',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              query['message'] ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Response area
          Text(
            'Official Response:',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (canRespond) ...[
            Expanded(
              child: TextField(
                controller: _responseController,
                maxLines: null,
                expands: true,
                style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type your official response here...',
                  hintStyle: GoogleFonts.dmSans(color: textMuted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (MediaQuery.of(context).size.width < 1000)
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedQuery = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Back to List'),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _updateQuery('In Progress'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Mark In Progress'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _updateQuery('Resolved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Resolve & Close'),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFBBF7D0)),
              ),
              child: Text(
                query['response'] != null && query['response'].isNotEmpty
                    ? query['response']
                    : 'No response entered. Marked as resolved.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: isDark ? Colors.green.shade300 : const Color(0xFF14532D),
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(),
            if (MediaQuery.of(context).size.width < 1000)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedQuery = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Back to List'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status, bool isDark) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Resolved':
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFDCFCE7);
        fg = isDark ? Colors.green.shade300 : const Color(0xFF15803D);
        break;
      case 'In Progress':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFEF3C7);
        fg = isDark ? Colors.amber.shade300 : const Color(0xFFD97706);
        break;
      case 'Pending':
      default:
        bg = isDark ? Colors.white10 : const Color(0xFFF1F5F9);
        fg = isDark ? Colors.white54 : const Color(0xFF475569);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'Pending',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildPaginationControls(Color textSecondary) {
    final totalPages = (_totalRecords / _pageSize).ceil();
    final hasNext = _currentPage < totalPages;
    final hasPrev = _currentPage > 1;

    return Row(
      children: [
        Text(
          'Total: $_totalRecords records',
          style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: hasPrev
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                  _fetchQueries();
                }
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        Text(
          'Page $_currentPage of ${totalPages > 0 ? totalPages : 1}',
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: hasNext
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                  _fetchQueries();
                }
              : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Next'),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

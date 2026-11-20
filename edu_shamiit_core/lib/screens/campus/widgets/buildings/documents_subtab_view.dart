import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../common/campus_pagination_bar.dart';

class DocumentsSubtabView extends StatefulWidget {
  final BuildingModel building;
  final List<BuildingDocumentModel> documents;
  final bool isLoading;
  final VoidCallback onAddDocument;
  final ValueChanged<BuildingDocumentModel> onEditDocument;
  final ValueChanged<BuildingDocumentModel> onDeleteDocument;

  const DocumentsSubtabView({
    super.key,
    required this.building,
    required this.documents,
    this.isLoading = false,
    required this.onAddDocument,
    required this.onEditDocument,
    required this.onDeleteDocument,
  });

  @override
  State<DocumentsSubtabView> createState() => _DocumentsSubtabViewState();
}

class _DocumentsSubtabViewState extends State<DocumentsSubtabView> {
  String _searchQuery = '';
  String? _selectedType;
  int _page = 1;
  int _pageSize = 10;
  int? _sortColIndex = 0;
  bool _sortAsc = true;

  void _handleSort(int colIndex, bool asc) {
    setState(() {
      _sortColIndex = colIndex;
      _sortAsc = asc;
    });
  }

  bool _checkExpired(BuildingDocumentModel doc) {
    if (doc.expiryDate == null) return false;
    final exp = DateTime.tryParse(doc.expiryDate!);
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var filtered = widget.documents.where((d) {
      if (_selectedType != null && _selectedType!.isNotEmpty && d.documentType != _selectedType) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = d.documentName.toLowerCase();
        final auth = (d.issuingAuthority ?? '').toLowerCase();
        if (!name.contains(q) && !auth.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortColIndex) {
        case 0:
          cmp = a.documentName.compareTo(b.documentName);
          break;
        case 1:
          cmp = a.documentType.compareTo(b.documentType);
          break;
        case 2:
          cmp = (a.issuingAuthority ?? '').compareTo(b.issuingAuthority ?? '');
          break;
        case 3:
          cmp = (a.issueDate ?? '').compareTo(b.issueDate ?? '');
          break;
        case 4:
          cmp = (a.expiryDate ?? '').compareTo(b.expiryDate ?? '');
          break;
        case 5:
          cmp = a.status.compareTo(b.status);
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });

    final totalCount = filtered.length;
    final totalPages = math.max(1, (totalCount / _pageSize).ceil());
    if (_page > totalPages) _page = totalPages;

    final startIndex = (totalCount == 0) ? 0 : (_page - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalCount);
    final pagedItems = (startIndex < totalCount) ? filtered.sublist(startIndex, endIndex) : <BuildingDocumentModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header & Action Row
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text(
              'Compliance & Documents (${widget.building.code})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddDocument,
              icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
              label: const Text('Upload Document', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. Compact Search & Filter Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search title or authority...',
                      hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 15),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _page = 1;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedType,
                    hint: const Text('All Categories', style: TextStyle(fontSize: 11.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Categories', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Occupancy Certificate', child: Text('Occupancy Certificate', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Fire Safety NOC', child: Text('Fire Safety NOC', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Structural Fitness', child: Text('Structural Fitness', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Environmental Clearance', child: Text('Environmental Clearance', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Building Sanction Plan', child: Text('Building Sanction Plan', style: TextStyle(fontSize: 11.5))),
                      DropdownMenuItem(value: 'Insurance Policy', child: Text('Insurance Policy', style: TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedType = v;
                      _page = 1;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 3. Documents Data Table
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No documents attached yet. Click "+ Upload Document" to attach permits or blueprints.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortColIndex,
                          sortAscending: _sortAsc,
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          headingRowHeight: 34,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 35,
                          columnSpacing: 16,
                          horizontalMargin: 12,
                          columns: [
                            DataColumn(
                              label: const Text('Document Title', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Category', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Issuing Authority', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Issue Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Expiry Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            DataColumn(
                              label: const Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onSort: (idx, asc) => _handleSort(idx, asc),
                            ),
                            const DataColumn(
                              label: Text('Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          rows: pagedItems.map((item) {
                            final isExpired = _checkExpired(item);
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.documentName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.documentType,
                                      style: const TextStyle(color: Color(0xFF2563EB), fontSize: 10.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(item.issuingAuthority ?? '—', style: const TextStyle(fontSize: 11.5)),
                                ),
                                DataCell(
                                  Text(item.issueDate?.substring(0, 10) ?? '—', style: const TextStyle(fontSize: 11)),
                                ),
                                DataCell(
                                  Text(item.expiryDate?.substring(0, 10) ?? 'Permanent', style: const TextStyle(fontSize: 11)),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isExpired ? Colors.red : const Color(0xFF059669)).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isExpired ? 'Expired' : item.status,
                                      style: TextStyle(
                                        color: isExpired ? Colors.red : const Color(0xFF059669),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 15),
                                        tooltip: 'Edit Document',
                                        onPressed: () => widget.onEditDocument(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                                        tooltip: 'Delete Document',
                                        onPressed: () => widget.onDeleteDocument(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 8),

        // Pagination Bar
        CampusPaginationBar(
          currentPage: _page,
          pageSize: _pageSize,
          totalCount: totalCount,
          itemLabel: 'documents',
          onPageChanged: (p) => setState(() => _page = p),
          onPageSizeChanged: (s) => setState(() {
            _pageSize = s;
            _page = 1;
          }),
        ),
      ],
    );
  }
}

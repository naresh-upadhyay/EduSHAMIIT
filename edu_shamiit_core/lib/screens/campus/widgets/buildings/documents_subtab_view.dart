import 'package:flutter/material.dart';
import '../../models/campus_models.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = widget.documents.where((d) {
      if (_selectedType != null && _selectedType!.isNotEmpty && d.documentType != _selectedType) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = d.documentName.toLowerCase();
        final type = d.documentType.toLowerCase();
        final auth = (d.issuingAuthority ?? '').toLowerCase();
        if (!name.contains(q) && !type.contains(q) && !auth.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalCount = widget.documents.length;
    final now = DateTime.now();
    final validCount = widget.documents.where((d) {
      if (d.status.toLowerCase() == 'expired') return false;
      if (d.expiryDate != null) {
        final exp = DateTime.tryParse(d.expiryDate!);
        if (exp != null && exp.isBefore(now)) return false;
      }
      return true;
    }).length;
    final expiredCount = totalCount - validCount;

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
              'Compliance, Permits & Documents (${widget.building.code})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: widget.onAddDocument,
              icon: const Icon(Icons.upload_file, size: 15, color: Colors.white),
              label: const Text('Upload Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Mini KPI Cards
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(child: _buildMetricTile('Total Documents', '$totalCount', Icons.folder_open_outlined, const Color(0xFF2563EB), isDark)),
              Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Active & Valid', '$validCount', Icons.verified_outlined, const Color(0xFF059669), isDark)),
              Container(width: 1, height: 36, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(child: _buildMetricTile('Expired / Needs Renewal', '$expiredCount', Icons.warning_amber_outlined, const Color(0xFFDC2626), isDark)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Search & Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search document title or issuing authority...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 38,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedType,
                    hint: const Text('All Categories', style: TextStyle(fontSize: 12.5)),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Categories', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Occupancy Certificate', child: Text('Occupancy Certificate', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Fire Safety NOC', child: Text('Fire Safety NOC', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Structural Fitness', child: Text('Structural Fitness', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Environmental Clearance', child: Text('Environmental Clearance', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Building Sanction Plan', child: Text('Building Sanction Plan', style: TextStyle(fontSize: 12.5))),
                      DropdownMenuItem(value: 'Insurance Policy', child: Text('Insurance Policy', style: TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Documents Data Table
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(10),
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
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              'No documents attached yet. Click "+ Upload Document" to attach permits, certificates or blueprints.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          ),
                          headingRowHeight: 44,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 52,
                          columnSpacing: 22,
                          horizontalMargin: 16,
                          columns: const [
                            DataColumn(label: Text('Document Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Issuing Authority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Issue Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Expiry Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                          ],
                          rows: filtered.map((item) {
                            final isExpired = _checkExpired(item);
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.documentName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.documentType,
                                      style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(item.issuingAuthority ?? '—', style: const TextStyle(fontSize: 12)),
                                ),
                                DataCell(
                                  Text(item.issueDate?.substring(0, 10) ?? '—', style: const TextStyle(fontSize: 11.5)),
                                ),
                                DataCell(
                                  Text(item.expiryDate?.substring(0, 10) ?? 'Permanent', style: const TextStyle(fontSize: 11.5)),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isExpired ? Colors.red : const Color(0xFF059669)).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isExpired ? 'Expired' : 'Valid',
                                      style: TextStyle(
                                        color: isExpired ? Colors.red : const Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item.fileUrl.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.open_in_new, size: 16, color: Color(0xFF2563EB)),
                                          tooltip: 'View Document File',
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('File URL: ${item.fileUrl}')),
                                            );
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16),
                                        tooltip: 'Edit Document',
                                        onPressed: () => widget.onEditDocument(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        tooltip: 'Delete Document',
                                        onPressed: () => widget.onDeleteDocument(item),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
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
      ],
    );
  }

  bool _checkExpired(BuildingDocumentModel doc) {
    if (doc.status.toLowerCase() == 'expired') return true;
    if (doc.expiryDate != null) {
      final exp = DateTime.tryParse(doc.expiryDate!);
      if (exp != null && exp.isBefore(DateTime.now())) return true;
    }
    return false;
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 1),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }
}

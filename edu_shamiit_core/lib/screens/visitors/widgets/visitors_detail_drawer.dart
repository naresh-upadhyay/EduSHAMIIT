import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/js_helper.dart';
import '../providers/visitors_provider.dart';
import '../models/visitor_models.dart';
import '../utils/visitor_avatar_helper.dart';
import 'dialogs/visitor_restriction_dialog.dart';
import 'dialogs/visitor_upload_document_dialog.dart';

class VisitorsDetailDrawer extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onPrintGatePass;
  final VoidCallback? onExtendVisit;
  final VoidCallback? onEdit;

  const VisitorsDetailDrawer({
    super.key,
    required this.onClose,
    this.onPrintGatePass,
    this.onExtendVisit,
    this.onEdit,
  });

  @override
  ConsumerState<VisitorsDetailDrawer> createState() => _VisitorsDetailDrawerState();
}

class _VisitorsDetailDrawerState extends ConsumerState<VisitorsDetailDrawer> {
  int _activeDrawerTab = 0; // 0: Overview, 1: Documents, 2: Visit History
  int _docPage = 1;
  static const int _docPageSize = 5;
  int _historyPage = 1;
  static const int _historyPageSize = 5;
  String? _lastVisitId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final item = state.selectedVisit;
    final detail = state.selectedDetail;

    if (item == null) return const SizedBox.shrink();

    if (item.id != _lastVisitId) {
      _lastVisitId = item.id;
      _docPage = 1;
      _historyPage = 1;
    }

    final visitorName = detail?.visitorName ?? item.visitorName;
    final visitorPhone = detail?.phone ?? item.phone;
    final visitorType = detail?.visitorType ?? item.category;
    final idType = detail?.idType ?? 'Aadhaar Card';
    final idNumber = detail?.idNumberMasked ?? 'XXXX-XXXX-1234';
    final photoUrl = detail?.photoUrl ?? item.photoUrl;
    final status = detail?.status ?? item.status;
    final purpose = detail?.purpose ?? item.purpose;
    final location = detail?.location ?? item.location;
    final host = detail?.hostName ?? item.hostName;
    final checkIn = detail?.checkInAt ?? item.checkInAt;
    final expectedOut = detail?.expectedOutAt ?? item.expectedOutAt ?? '-';
    final duration = detail?.durationText ?? '1 hr 45 mins (ongoing)';
    final vehicleNo = detail?.vehicleNumber ?? item.vehicleNumber ?? 'UP16 AB 1234';
    final remarks = detail?.remarks ?? item.remarks ?? 'Meeting regarding academic progress';

    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drawer Header: "Visitor Details", [Edit], [Close]
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Text(
                  'Visitor Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                  label: const Text('Edit', style: TextStyle(fontSize: 12.5, color: Color(0xFF2563EB))),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 2. Profile Card matching screenshot
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Big Circular Avatar
                VisitorAvatar(
                  photoUrl: photoUrl,
                  name: visitorName,
                  radius: 34,
                  fontSize: 24,
                ),
                const SizedBox(width: 16),
                // Identity Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              visitorName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (status.toLowerCase() == 'blocked' || status.toLowerCase() == 'blacklisted' || status.toLowerCase() == 'restricted')
                                  ? const Color(0xFFFEE2E2)
                                  : (status.toLowerCase() == 'inside'
                                      ? const Color(0xFFDCFCE7)
                                      : (status.toLowerCase() == 'overstay'
                                          ? const Color(0xFFFEE2E2)
                                          : (status.toLowerCase() == 'scheduled'
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFF1F5F9)))),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: (status.toLowerCase() == 'blocked' || status.toLowerCase() == 'blacklisted' || status.toLowerCase() == 'restricted')
                                    ? const Color(0xFFDC2626)
                                    : (status.toLowerCase() == 'inside'
                                        ? const Color(0xFF15803D)
                                        : (status.toLowerCase() == 'overstay'
                                            ? const Color(0xFFB91C1C)
                                            : (status.toLowerCase() == 'scheduled'
                                                ? const Color(0xFFB45309)
                                                : const Color(0xFF64748B)))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildProfileRow('Type', visitorType, isDark, highlight: true),
                      const SizedBox(height: 3),
                      _buildProfileRow('Phone', visitorPhone, isDark),
                      const SizedBox(height: 3),
                      _buildProfileRow('ID Type', idType, isDark),
                      const SizedBox(height: 3),
                      _buildProfileRow('ID Number', idNumber, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Sub-tabs (Overview, Documents, Visit History)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                _buildDrawerTab('Overview', 0, isDark),
                _buildDrawerTab('Documents (${detail?.documents.length ?? 2})', 1, isDark),
                _buildDrawerTab('Visit History (${detail?.visitHistory.length ?? 3})', 2, isDark),
              ],
            ),
          ),

          // 4. Tab Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _activeDrawerTab == 0
                  ? _buildOverviewTab(item, visitorName, purpose, location, host, checkIn, expectedOut, duration, vehicleNo, remarks, status, item.id, isDark)
                  : (_activeDrawerTab == 1
                      ? _buildDocumentsTab(detail?.documents ?? [], isDark)
                      : _buildVisitHistoryTab(detail?.visitHistory ?? [], isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
            color: highlight
                ? const Color(0xFF2563EB)
                : (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerTab(String title, int index, bool isDark) {
    final isSelected = _activeDrawerTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeDrawerTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    VisitorItem item,
    String visitorName,
    String purpose,
    String location,
    String host,
    String checkIn,
    String expectedOut,
    String duration,
    String vehicleNo,
    String remarks,
    String status,
    String visitId,
    bool isDark,
  ) {
    final notifier = ref.read(visitorsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailRow(Icons.flag_outlined, 'Purpose', purpose, isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.place_outlined, 'Location', location, isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.person_outline_rounded, 'Host', host, isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.login_rounded, 'Check In', _formatDateTime(checkIn), isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.logout_rounded, 'Expected Out', _formatDateTime(expectedOut), isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.timer_outlined, 'Duration', duration, isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.directions_car_outlined, 'Vehicle No.', vehicleNo, isDark),
        const SizedBox(height: 12),
        _buildDetailRow(Icons.sticky_note_2_outlined, 'Remarks', remarks, isDark),

        const SizedBox(height: 24),
        // Action Buttons
        if (status.toLowerCase() == 'blocked' || status.toLowerCase() == 'blacklisted' || status.toLowerCase() == 'restricted') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Row(
              children: [
                Icon(Icons.block_rounded, size: 20, color: Color(0xFFDC2626)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Visitor is blocked / blacklisted. Gate pass issuance and campus entry are prohibited.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          if (status.toLowerCase() == 'inside' || status.toLowerCase() == 'overstay') ...[
            // Check Out (Green button)
            ElevatedButton.icon(
              onPressed: () => notifier.checkOutVisit(visitId),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
              label: const Text('Check Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            // Extend Visit (Blue button)
            ElevatedButton.icon(
              onPressed: widget.onExtendVisit ?? () => notifier.extendVisit(visitId, extensionMinutes: 60),
              icon: const Icon(Icons.access_time_rounded, size: 18, color: Colors.white),
              label: const Text('Extend Visit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Print Gate Pass (Outlined button)
          OutlinedButton.icon(
            onPressed: widget.onPrintGatePass,
            icon: const Icon(Icons.print_outlined, size: 18, color: Color(0xFF334155)),
            label: const Text('Print Gate Pass', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        // Blacklist / Unblock Visitor Button
        if (status.toLowerCase() == 'blocked' || status.toLowerCase() == 'blacklisted')
          ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Unblock Visitor'),
                  content: Text('Lift security restriction and unblock access for $visitorName?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                      child: const Text('Confirm Unblock'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await notifier.unblockVisitor(item.visitorId);
              }
            },
            icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
            label: const Text('Unblock Visitor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () {
              final visit = ref.read(visitorsProvider).selectedVisit;
              if (visit != null) {
                showDialog(
                  context: context,
                  builder: (ctx) => VisitorRestrictionDialog(initialVisitor: visit),
                );
              }
            },
            icon: const Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
            label: const Text('Blacklist Visitor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(List<Map<String, dynamic>> documents, bool isDark) {
    final docs = documents;
    final visit = ref.read(visitorsProvider).selectedVisit;

    final totalDocs = docs.length;
    final totalPages = (totalDocs / _docPageSize).ceil().clamp(1, 999999);
    final currentPage = _docPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _docPageSize;
    final endIndex = (startIndex + _docPageSize).clamp(0, totalDocs);
    final pagedDocs = docs.isNotEmpty ? docs.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documents (${docs.length})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (visit != null)
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => VisitorUploadDocumentDialog(
                      visitorId: visit.visitorId,
                      visitId: visit.id,
                      visitorName: visit.visitorName,
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                label: const Text('Upload Document', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.folder_open_rounded, size: 36, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No documents attached',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload ID proof, pass photo, or official clearance.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                if (visit != null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => VisitorUploadDocumentDialog(
                          visitorId: visit.visitorId,
                          visitId: visit.id,
                          visitorName: visit.visitorName,
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                    label: const Text('Upload Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          )
        else ...[
          ...pagedDocs.map((d) {
            final docId = d['id']?.toString();
            final docName = d['document_name']?.toString() ?? d['name']?.toString() ?? 'Document.pdf';
            final docType = d['document_type']?.toString() ?? d['type']?.toString() ?? 'ID Proof';
            final status = d['verification_status']?.toString() ?? d['status']?.toString() ?? 'VERIFIED';
            final fileUrl = d['file_url']?.toString() ?? d['url']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          docName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '$docType • $status',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                    onPressed: () {
                      if (fileUrl != null && fileUrl.isNotEmpty) {
                        downloadFileWeb(fileUrl, docName);
                      }
                    },
                  ),
                  if (docId != null && docId.isNotEmpty && visit != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      onPressed: () {
                        ref.read(visitorsProvider.notifier).deleteDocument(docId, visitId: visit.id);
                      },
                    ),
                ],
              ),
            );
          }),
        ],
        _buildPaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalDocs,
          startIndex: startIndex,
          endIndex: endIndex,
          itemLabel: 'documents',
          isDark: isDark,
          onPageChanged: (newPage) => setState(() => _docPage = newPage),
        ),
      ],
    );
  }

  Widget _buildVisitHistoryTab(List<Map<String, dynamic>> history, bool isDark) {
    final hist = history.isNotEmpty
        ? history
        : [
            {'purpose': 'Meet Student', 'destination': 'Main Gate', 'check_in_at': '12 May 2024, 09:15 AM', 'status': 'Inside'},
            {'purpose': 'Fee Inquiry', 'destination': 'Accounts Office', 'check_in_at': '14 Apr 2024, 11:30 AM', 'status': 'Completed'},
            {'purpose': 'Parent Teacher Meet', 'destination': 'Class 10 A', 'check_in_at': '10 Jan 2024, 10:00 AM', 'status': 'Completed'},
          ];

    final totalHist = hist.length;
    final totalPages = (totalHist / _historyPageSize).ceil().clamp(1, 999999);
    final currentPage = _historyPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _historyPageSize;
    final endIndex = (startIndex + _historyPageSize).clamp(0, totalHist);
    final pagedHist = hist.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...pagedHist.map((h) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      h['purpose']?.toString() ?? 'Visit',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        h['status']?.toString() ?? 'Completed',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Destination: ${h['destination'] ?? 'Main Gate'}',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                Text(
                  'Time: ${h['check_in_at'] ?? '-'}',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }),
        _buildPaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          totalItems: totalHist,
          startIndex: startIndex,
          endIndex: endIndex,
          itemLabel: 'visits',
          isDark: isDark,
          onPageChanged: (newPage) => setState(() => _historyPage = newPage),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required String itemLabel,
    required bool isDark,
    required ValueChanged<int> onPageChanged,
  }) {
    if (totalItems <= 5) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${startIndex + 1} - $endIndex of $totalItems $itemLabel',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                color: currentPage > 1
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                color: currentPage < totalPages
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${hour.toString().padLeft(2, '0')}:$min $ampm';
    } catch (_) {
      return raw;
    }
  }
}

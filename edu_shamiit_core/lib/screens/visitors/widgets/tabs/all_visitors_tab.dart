import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../visitors_kpi_cards.dart';
import '../visitors_filter_bar.dart';
import '../visitors_data_table.dart';
import '../visitors_bottom_analytics.dart';
import '../dialogs/visitor_registration_dialog.dart';
import '../dialogs/visitor_gate_pass_dialog.dart';
import '../dialogs/visitor_extend_dialog.dart';
import '../dialogs/visitors_more_filters_dialog.dart';
import '../dialogs/visitor_upload_document_dialog.dart';
import '../../utils/visitor_avatar_helper.dart';
import '../../../../utils/js_helper.dart';

class AllVisitorsTab extends ConsumerStatefulWidget {
  const AllVisitorsTab({super.key});

  @override
  ConsumerState<AllVisitorsTab> createState() => _AllVisitorsTabState();
}

class _AllVisitorsTabState extends ConsumerState<AllVisitorsTab> {
  int _activeInspectorTab = 0; // 0: Overview, 1: Documents (2), 2: Visit History (3)
  int _docPage = 1;
  static const int _docPageSize = 5;
  int _historyPage = 1;
  static const int _historyPageSize = 5;
  String? _lastVisitId;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(visitorsProvider.notifier);
    final state = ref.watch(visitorsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visits = state.visits;
    final selectedVisit = state.selectedVisit ?? (visits.isNotEmpty ? visits.first : null);
    final detail = state.selectedDetail;

    if (selectedVisit?.id != _lastVisitId) {
      _lastVisitId = selectedVisit?.id;
      _docPage = 1;
      _historyPage = 1;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Cards Bar (Total Visitors, Currently Inside, Checked In Today, Checked Out Today, Overstay, Scheduled Today)
          const VisitorsKPICards(),
          const SizedBox(height: 16),

          // 2. Search & Dynamic Filters Bar
          VisitorsFilterBar(
            onRegisterVisitor: () {
              showDialog(
                context: context,
                builder: (ctx) => const VisitorRegistrationDialog(),
              );
            },
            onMoreFilters: () {
              showDialog(
                context: context,
                builder: (ctx) => const VisitorsMoreFiltersDialog(),
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Main Workspace: Left (Visitors Table) and Right (Visitor Details + Location Chart + Recent Visitors)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1120;

              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Main Visitors Table
                  VisitorsDataTable(
                    onSelectVisitor: (visit) {
                      notifier.openVisitDetail(visit);
                    },
                    onEditVisitor: (visit) {
                      showDialog(
                        context: context,
                        builder: (ctx) => VisitorRegistrationDialog(existingVisit: visit),
                      );
                    },
                  ),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Visitor Details Card
                  _buildVisitorDetailsCard(context, isDark, state, notifier, selectedVisit, detail),
                  const SizedBox(height: 16),

                  // 2. Today's Visitors by Location (Bar Chart)
                  LocationBarChartCard(
                    onViewAll: () {
                      notifier.setLocationFilter('All Locations');
                    },
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: leftColumn),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftColumn,
                    const SizedBox(height: 16),
                    rightColumn,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  Widget _buildVisitorDetailsCard(
    BuildContext context,
    bool isDark,
    VisitorsState state,
    VisitorsNotifier notifier,
    VisitorItem? visit,
    VisitorDetail360? detail,
  ) {
    if (visit == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            'Select a visitor to view details',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      );
    }

    final name = detail?.visitorName ?? visit.visitorName;
    final phone = detail?.phone ?? visit.phone;
    final email = detail?.email ?? 'rajesh@gmail.com';
    final idType = detail?.idType ?? 'Aadhaar Card';
    final idNumber = detail?.idNumberMasked ?? 'XXXX-XXXX-1234';
    final photoUrl = detail?.photoUrl ?? visit.photoUrl;
    final status = detail?.status ?? visit.status;
    final type = detail?.visitorType ?? visit.category;
    final purpose = detail?.purpose ?? visit.purpose;
    final location = detail?.location ?? visit.location;
    final host = detail?.hostName ?? visit.hostName;
    final checkIn = detail?.checkInAt ?? visit.checkInAt;
    final expectedOut = detail?.expectedOutAt ?? visit.expectedOutAt ?? '12 May 2024, 11:00 AM';
    final duration = detail?.durationText ?? '1 hr 45 mins (ongoing)';
    final vehicleNo = detail?.vehicleNumber ?? visit.vehicleNumber ?? 'UP16 AB 1234';
    final remarks = detail?.remarks ?? visit.remarks ?? 'Meeting regarding academic progress';
    final docCount = detail?.documents.length ?? 0;
    final histCount = detail?.visitHistory.length ?? 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "Visitor Details", "Edit"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Visitor Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => VisitorRegistrationDialog(existingVisit: visit),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Identity Banner: Avatar, Name, Status Badge, Contact Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VisitorAvatar(
                      photoUrl: photoUrl,
                      name: name,
                      radius: 30,
                      fontSize: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildMiniInfoRow('Type', type, isDark, isBadge: true),
                          const SizedBox(height: 3),
                          _buildMiniInfoRow('Phone', phone, isDark),
                          const SizedBox(height: 3),
                          _buildMiniInfoRow('Email', email, isDark),
                          const SizedBox(height: 3),
                          _buildMiniInfoRow('ID Type', idType, isDark),
                          const SizedBox(height: 3),
                          _buildMiniInfoRow('ID Number', idNumber, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs: Overview | Documents ($docCount) | Visit History ($histCount)
          Row(
            children: [
              _buildInspectorTab('Overview', 0),
              _buildInspectorTab('Documents ($docCount)', 1),
              _buildInspectorTab('Visit History ($histCount)', 2),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Tab Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _activeInspectorTab == 0
                ? _buildOverviewTab(
                    context, isDark, state, notifier, visit,
                    purpose: purpose,
                    location: location,
                    host: host,
                    checkIn: checkIn,
                    expectedOut: expectedOut,
                    duration: duration,
                    vehicleNo: vehicleNo,
                    remarks: remarks,
                    status: status,
                  )
                : _activeInspectorTab == 1
                    ? _buildDocumentsTab(context, isDark, detail, visit)
                    : _buildVisitHistoryTab(context, isDark, detail, visit, state.visits),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoRow(String label, String value, bool isDark, {bool isBadge = false}) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 4),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(4)),
            child: Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          )
        else
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    switch (status.toLowerCase()) {
      case 'inside':
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        break;
      case 'checked out':
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        break;
      case 'overstay':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        break;
      case 'blocked':
      case 'blacklisted':
      case 'restricted':
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: text)),
    );
  }

  Widget _buildInspectorTab(String title, int index) {
    final isSelected = _activeInspectorTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeInspectorTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(
    BuildContext context,
    bool isDark,
    VisitorsState state,
    VisitorsNotifier notifier,
    VisitorItem visit, {
    required String purpose,
    required String location,
    required String host,
    required String checkIn,
    required String expectedOut,
    required String duration,
    required String vehicleNo,
    required String remarks,
    required String status,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailRow(Icons.my_location_rounded, 'Purpose', purpose, isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.place_outlined, 'Location', location, isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.person_outline, 'Host', host, isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.login_rounded, 'Check In', _formatDateTime(checkIn), isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.logout_rounded, 'Expected Out', _formatDateTime(expectedOut), isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.access_time_rounded, 'Duration', duration, isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.directions_car_outlined, 'Vehicle No.', vehicleNo, isDark),
        const SizedBox(height: 10),
        _buildDetailRow(Icons.sticky_note_2_outlined, 'Remarks', remarks, isDark),

        const SizedBox(height: 20),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.lock_open_rounded, color: Color(0xFF16A34A)),
                        SizedBox(width: 8),
                        Text('Lift Restriction / Unblock'),
                      ],
                    ),
                    content: Text('Lift security restriction and restore campus access for ${visit.visitorName}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await notifier.unblockVisitor(visit.visitorId.isNotEmpty ? visit.visitorId : visit.id);
                          if (ctx.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Security restriction lifted for ${visit.visitorName}')),
                            );
                          }
                        },
                        child: const Text('Confirm Unblock', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.lock_open_rounded, size: 16, color: Colors.white),
              label: const Text('Unblock Visitor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ] else ...[
          // Action Buttons: [ Check Out ] (green) [ Extend Visit ] (blue)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await notifier.checkOutVisit(visit.id);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                  label: const Text('Check Out', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => VisitorExtendDialog(visit: visit),
                    );
                  },
                  icon: const Icon(Icons.more_time_rounded, size: 16, color: Colors.white),
                  label: const Text('Extend Visit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Full-width: Print Gate Pass (Outline button matching Image 3)
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => VisitorGatePassDialog(visit: visit),
              );
            },
            icon: Icon(Icons.print_outlined, size: 16, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
            label: Text('Print Gate Pass', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(BuildContext context, bool isDark, VisitorDetail360? detail, VisitorItem? visit) {
    final docs = detail?.documents ?? [];
    final totalDocs = docs.length;
    final totalPages = (totalDocs / _docPageSize).ceil().clamp(1, 999999);
    final currentPage = _docPage.clamp(1, totalPages);
    final startIndex = (currentPage - 1) * _docPageSize;
    final endIndex = (startIndex + _docPageSize).clamp(0, totalDocs);
    final pagedDocs = docs.isNotEmpty ? docs.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Action Bar with Upload Document Button
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
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
        const SizedBox(height: 10),

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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_open_rounded, size: 32, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                Text(
                  'No documents attached yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aadhaar, Driving License, or ID proofs uploaded will show here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                if (visit != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
                        label: const Text('Upload Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
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
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF2563EB)),
                        label: const Text('Full Form Edit', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => VisitorRegistrationDialog(existingVisit: visit),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          )
        else ...[
          ...pagedDocs.map((d) {
              final docId = d['id']?.toString();
              final docName = d['document_name']?.toString() ?? d['name']?.toString() ?? 'Attached Document';
              final docType = d['document_type']?.toString() ?? d['type']?.toString() ?? 'ID Proof';
              final status = d['verification_status']?.toString() ?? d['status']?.toString() ?? 'VERIFIED';
              final fileUrl = d['file_url']?.toString() ?? d['url']?.toString();
              final isPdf = docName.toLowerCase().endsWith('.pdf');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
                      color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            docName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  docType,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                              ),
                              Text(
                                '• $status',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                      tooltip: 'Download $docName',
                      onPressed: () {
                        if (fileUrl != null && fileUrl.isNotEmpty) {
                          downloadFileWeb(fileUrl, docName);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Downloading $docName...')),
                        );
                      },
                    ),
                    if (docId != null && docId.isNotEmpty && visit != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Delete $docName',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Document'),
                              content: Text('Are you sure you want to delete "$docName"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(visitorsProvider.notifier).deleteDocument(docId, visitId: visit.id);
                          }
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
          prevKey: const Key('tab_docs_prev'),
          nextKey: const Key('tab_docs_next'),
          onPageChanged: (newPage) => setState(() => _docPage = newPage),
        ),
      ],
    );
  }

  Widget _buildVisitHistoryTab(BuildContext context, bool isDark, VisitorDetail360? detail, VisitorItem? visit, List<VisitorItem> allVisits) {
    List<Map<String, dynamic>> hist = [];
    if (detail != null && detail.visitHistory.isNotEmpty) {
      hist = List<Map<String, dynamic>>.from(detail.visitHistory);
    } else if (visit != null) {
      // Find matching visits for this visitor from the list
      final matchingVisits = allVisits.where(
        (v) => (v.visitorId == visit.visitorId && v.visitorId.isNotEmpty) ||
               (v.phone == visit.phone && v.phone.isNotEmpty) ||
               v.visitorName.toLowerCase() == visit.visitorName.toLowerCase()
      ).toList();

      if (matchingVisits.isNotEmpty) {
        hist = matchingVisits.map((v) => {
          'id': v.id,
          'visit_number': v.visitNumber,
          'purpose': v.purpose,
          'host_name': v.hostName,
          'destination': v.location,
          'check_in_at': v.checkInAt,
          'actual_check_out_at': v.actualCheckOutAt,
          'status': v.status,
          'is_current': v.id == visit.id,
        }).toList();
      } else {
        hist = [{
          'id': visit.id,
          'visit_number': visit.visitNumber,
          'purpose': visit.purpose,
          'host_name': visit.hostName,
          'destination': visit.location,
          'check_in_at': visit.checkInAt,
          'actual_check_out_at': visit.actualCheckOutAt,
          'status': visit.status,
          'is_current': true,
        }];
      }
    }

    if (hist.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.history_rounded, size: 36, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              'No visit history available',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );
    }

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
          final purpose = h['purpose']?.toString() ?? 'General Visit';
          final status = h['status']?.toString() ?? 'Completed';
          final destination = h['destination']?.toString() ?? 'Main Gate';
          final host = h['host_name']?.toString() ?? '-';
          final checkIn = _formatDateTime(h['check_in_at']?.toString());
          final isCurrent = h['is_current'] == true || (visit != null && h['id'] == visit.id);

          Color statusColor = const Color(0xFF15803D);
          Color statusBg = const Color(0xFFDCFCE7);
          if (status == 'Inside') {
            statusColor = const Color(0xFF16A34A);
            statusBg = const Color(0xFFDCFCE7);
          } else if (status == 'Overstay') {
            statusColor = const Color(0xFFDC2626);
            statusBg = const Color(0xFFFEE2E2);
          } else if (status == 'Blocked' || status == 'Blacklisted') {
            statusColor = const Color(0xFFDC2626);
            statusBg = const Color(0xFFFEE2E2);
          } else if (status == 'Scheduled') {
            statusColor = const Color(0xFF7E22CE);
            statusBg = const Color(0xFFF3E8FF);
          } else {
            statusColor = const Color(0xFF475569);
            statusBg = const Color(0xFFF1F5F9);
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent
                    ? const Color(0xFF3B82F6)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isCurrent ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              purpose,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Current',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Destination: $destination • Host: $host',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Check-In: $checkIn',
                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
          prevKey: const Key('tab_history_prev'),
          nextKey: const Key('tab_history_next'),
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
    Key? prevKey,
    Key? nextKey,
  }) {
    if (totalItems <= 5) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '${startIndex + 1}-$endIndex of $totalItems',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: prevKey,
                icon: const Icon(Icons.chevron_left_rounded, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: currentPage > 1
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '$currentPage/$totalPages',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                key: nextKey,
                icon: const Icon(Icons.chevron_right_rounded, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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

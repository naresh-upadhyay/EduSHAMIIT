import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../../models/hostel_leave_outing_models.dart';
import '../../providers/hostel_provider.dart';
import 'gate_pass_dialog.dart';
import 'scannable_hostel_qr_widget.dart';
import 'hostel_gate_pass_print_dialog.dart';

class HostelLeaveDetailDrawer extends ConsumerStatefulWidget {
  final LeaveOutingRequestItem request;
  final VoidCallback onClose;

  const HostelLeaveDetailDrawer({
    super.key,
    required this.request,
    required this.onClose,
  });

  @override
  ConsumerState<HostelLeaveDetailDrawer> createState() => _HostelLeaveDetailDrawerState();
}

class _HostelLeaveDetailDrawerState extends ConsumerState<HostelLeaveDetailDrawer> {
  int _activeTab = 0; // 0: Overview, 1: Approval, 2: Gate Pass, 3: Movement, 4: Documents, 5: Activity

  static const List<String> _tabs = [
    'Overview',
    'Approval',
    'Gate Pass',
    'Movement',
    'Documents',
    'Activity',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use current selectedLeaveRequest if available for live updates, fallback to widget.request
    final req = (state.selectedLeaveRequest?.id == widget.request.id)
        ? state.selectedLeaveRequest!
        : widget.request;

    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 500 ? 460.0 : (screenWidth * 0.95).clamp(300.0, 460.0);

    return Container(
      width: drawerWidth,
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
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header (Student avatar, name, request number, status, close button)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFEFF6FF),
                  backgroundImage: req.studentAvatar != null ? NetworkImage(req.studentAvatar!) : null,
                  child: req.studentAvatar == null
                      ? Text(
                          req.studentName.isNotEmpty ? req.studentName[0] : 'S',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              req.studentName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusChip(req.status, isDark),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${req.requestNumber} • ${req.classSectionDisplay}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => notifier.refreshSelectedLeaveRequest(req.id),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Refresh Details',
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close Inspector',
                ),
              ],
            ),
          ),

          // 2. Subtabs Bar with badges
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_tabs.length, (idx) {
                  final isSelected = _activeTab == idx;
                  String tabTitle = _tabs[idx];
                  int? countBadge;
                  if (idx == 4 && req.documents.isNotEmpty) countBadge = req.documents.length;
                  if (idx == 5) countBadge = req.internalNotes.length + req.timeline.length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = idx),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                              width: 2.2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tabTitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                            if (countBadge != null && countBadge > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$countBadge',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // 3. Tab Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildTabContent(req, notifier, isDark),
            ),
          ),

          // 4. Action Footer Bar
          _buildActionFooter(req, notifier, isDark),
        ],
      ),
    );
  }

  Widget _buildTabContent(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    switch (_activeTab) {
      case 0:
        return _buildOverviewTab(req, notifier, isDark);
      case 1:
        return _buildApprovalTab(req, notifier, isDark);
      case 2:
        return _buildGatePassTab(req, notifier, isDark);
      case 3:
        return _buildMovementTab(req, notifier, isDark);
      case 4:
        return _buildDocumentsTab(req, notifier, isDark);
      case 5:
        return _buildActivityTab(req, notifier, isDark);
      default:
        return const SizedBox();
    }
  }

  // ===========================================================================
  // TAB 0: OVERVIEW TAB (With Full Edit / Delete CRUD)
  // ===========================================================================
  Widget _buildOverviewTab(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action toolbar: Edit Details & Delete Request
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showEditRequestDialog(context, req, notifier, isDark),
              icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
              label: const Text('Edit Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
              ),
            ),
            TextButton.icon(
              onPressed: () => _confirmDeleteRequest(context, req, notifier, isDark),
              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
              label: const Text('Delete Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Movement Information', isDark),
        const SizedBox(height: 10),
        _buildInfoRow('Request Type', req.requestType == 'LEAVE' ? 'Leave (Extended)' : 'Outing (Short Visit)', isDark),
        _buildInfoRow('Sub-Type', req.requestSubtype ?? 'Personal', isDark),
        _buildInfoRow('Reason', req.reason, isDark),
        _buildInfoRow('Destination', req.destination, isDark),
        if (req.destinationAddress != null && req.destinationAddress!.isNotEmpty)
          _buildInfoRow('Address', req.destinationAddress!, isDark),
        _buildInfoRow('From Date', req.fromDateFormatted ?? req.displayFromDate, isDark),
        _buildInfoRow('Expected Return', req.toDateFormatted ?? req.displayToDate, isDark),
        _buildInfoRow('Duration', req.displayDuration, isDark),
        if (req.isEmergency) _buildInfoRow('Priority', 'EMERGENCY LEAVE (High Priority)', isDark, isHighlight: true),

        const SizedBox(height: 18),
        _buildSectionHeader('Hostel & Room Assignment', isDark),
        const SizedBox(height: 10),
        _buildInfoRow('Hostel', req.hostelName?.isNotEmpty == true ? req.hostelName! : '-', isDark),
        _buildInfoRow('Room Number', req.roomNumber?.isNotEmpty == true ? req.roomNumber! : '-', isDark),
        _buildInfoRow('Bed Number', req.bedNumber?.isNotEmpty == true ? req.bedNumber! : '-', isDark),

        const SizedBox(height: 18),
        _buildSectionHeader('Guardian & Verification', isDark),
        const SizedBox(height: 10),
        _buildInfoRow('Guardian Name', req.guardianName?.isNotEmpty == true ? req.guardianName! : 'Not Provided', isDark),
        _buildInfoRow('Guardian Phone', req.guardianPhone?.isNotEmpty == true ? req.guardianPhone! : 'Not Provided', isDark),
        _buildInfoRow('Relationship', req.guardianRelationship ?? 'Father', isDark),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: Text('Parent Verified', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: req.guardianConfirmed
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  req.guardianConfirmed ? 'Verified via Phone/SMS' : 'Pending Verification',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: req.guardianConfirmed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        _buildSectionHeader('Transport & Accompaniment', isDark),
        const SizedBox(height: 10),
        _buildInfoRow('Accompanied By', req.accompaniedBy?.isNotEmpty == true ? req.accompaniedBy! : 'SELF', isDark),
        if (req.companionName != null && req.companionName!.isNotEmpty)
          _buildInfoRow('Companion Name', req.companionName!, isDark),
        _buildInfoRow('Transport Mode', req.transportMode ?? 'WALK', isDark),
        if (req.vehicleNumber != null && req.vehicleNumber!.isNotEmpty)
          _buildInfoRow('Vehicle No.', req.vehicleNumber!, isDark),
        if (req.specialInstructions != null && req.specialInstructions!.isNotEmpty)
          _buildInfoRow('Instructions', req.specialInstructions!, isDark),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: APPROVAL TAB (With Interactive Decision & Verification Controls)
  // ===========================================================================
  Widget _buildApprovalTab(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Approval Status & Decision Desk', isDark),
        const SizedBox(height: 12),

        // Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: req.status == 'APPROVED'
                ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4))
                : req.status == 'REJECTED'
                    ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
                    : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: req.status == 'APPROVED'
                  ? (isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0))
                  : req.status == 'REJECTED'
                      ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA))
                      : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        req.status == 'APPROVED'
                            ? Icons.check_circle_rounded
                            : req.status == 'REJECTED'
                                ? Icons.cancel_rounded
                                : Icons.access_time_filled_rounded,
                        color: req.status == 'APPROVED'
                            ? const Color(0xFF16A34A)
                            : req.status == 'REJECTED'
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFD97706),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        req.status == 'APPROVED'
                            ? 'Approved'
                            : req.status == 'REJECTED'
                                ? 'Rejected'
                                : 'Pending Approval',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: req.status == 'APPROVED'
                              ? const Color(0xFF16A34A)
                              : req.status == 'REJECTED'
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  if (req.status == 'APPROVED')
                    OutlinedButton(
                      onPressed: () => _confirmRevokeApproval(context, req, notifier, isDark),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD97706)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Revoke', style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              if (req.approvedByName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Reviewed by: ${req.approvedByName}${req.approvedAt != null ? " on ${_formatDateTime(req.approvedAt!)}" : ""}',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
              ],
              if (req.approvalRemarks != null && req.approvalRemarks!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Remarks: ${req.approvalRemarks}',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
              if (req.rejectionReason != null && req.rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Rejection Reason: ${req.rejectionReason}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Guardian Verification Toggle Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(
                req.guardianConfirmed ? Icons.verified_user_rounded : Icons.phone_in_talk_outlined,
                color: req.guardianConfirmed ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Guardian Telephonic Verification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      req.guardianConfirmed
                          ? 'Parent confirmation is verified'
                          : 'Call ${req.guardianPhone ?? "guardian"} to verify movement',
                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  notifier.toggleGuardianConfirmation(req.id, !req.guardianConfirmed);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: req.guardianConfirmed ? const Color(0xFF64748B) : const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: Text(
                  req.guardianConfirmed ? 'Clear' : 'Mark Verified',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Decision Action Buttons if Pending
        if (req.status == 'PENDING') ...[
          _buildSectionHeader('Take Approval Action', isDark),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmApproval(context, req, notifier),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmRejection(context, req, notifier),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // TAB 2: GATE PASS TAB (Full Pass Generation, QR View, Token Copy, Download)
  // ===========================================================================
  Widget _buildGatePassTab(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    final hasPass = req.passNumber != null || req.gatePass != null;

    if (!hasPass && req.status != 'APPROVED' && req.status != 'EXITED' && req.status != 'RETURNED') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 54, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Digital Gate Pass Not Issued Yet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Approve this request or generate a gate pass manually below.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => notifier.generateLeaveGatePass(req.id),
                icon: const Icon(Icons.add_task_rounded, size: 16, color: Colors.white),
                label: const Text('Generate Gate Pass Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ),
        ),
      );
    }

    final passNum = req.passNumber ?? req.gatePass?.passNumber ?? 'GP-2024-0012';
    final token = req.gatePass?.verificationToken ?? 'TOKEN-${req.id.substring(0, 8)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ScannableHostelQrWidget(
                passNumber: passNum,
                qrBase64: req.gatePass?.qrBase64 ?? req.qrBase64,
                size: 140,
              ),
              const SizedBox(height: 14),
              Text(
                passNum,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Valid for ${req.studentName} (${req.classSectionDisplay})',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              // Token with copy action
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gate Pass verification token copied to clipboard!')),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(token, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => HostelGatePassPrintDialog(
                    request: req,
                    gatePass: req.gatePass,
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
              label: const Text('Print Gate Pass Badge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => GatePassDialog(requestId: req.id),
                );
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Verification Terminal'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => notifier.generateLeaveGatePass(req.id),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
              label: const Text('Regenerate Token', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: MOVEMENT TAB (Full Exit/Return Recording, Reset, and History Log)
  // ===========================================================================
  Widget _buildMovementTab(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Actual Movement Log', isDark),
            if (req.actualExitAt != null)
              TextButton.icon(
                onPressed: () => _confirmResetMovement(context, req, notifier, isDark),
                icon: const Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFFD97706)),
                label: const Text('Reset', style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Step 1: Campus Exit
        _buildMovementStepCard(
          title: 'Campus Exit',
          time: req.actualExitAt != null ? _formatDateTime(req.actualExitAt!) : 'Not recorded yet',
          isDone: req.actualExitAt != null,
          gate: req.exitGate ?? 'Main Gate',
          verifiedBy: req.exitVerifiedByName ?? 'Security Guard',
          remarks: req.exitRemarks,
          onAction: () => _showRecordExitDialog(context, req, notifier, isDark),
          actionLabel: req.actualExitAt == null ? 'Record Exit' : 'Edit Exit',
          isDark: isDark,
        ),
        const SizedBox(height: 14),

        // Step 2: Campus Return
        _buildMovementStepCard(
          title: 'Campus Return',
          time: req.actualReturnAt != null ? _formatDateTime(req.actualReturnAt!) : 'Not recorded yet',
          isDone: req.actualReturnAt != null,
          gate: req.returnGate ?? 'Main Gate',
          verifiedBy: req.returnVerifiedByName ?? 'Security Guard',
          remarks: req.returnRemarks,
          onAction: () => _showRecordReturnDialog(context, req, notifier, isDark),
          actionLabel: req.actualReturnAt == null ? 'Record Return' : 'Edit Return',
          isDark: isDark,
        ),

        const SizedBox(height: 20),
        _buildSectionHeader('Movement Direct Actions', isDark),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordExitDialog(context, req, notifier, isDark),
                icon: const Icon(Icons.directions_walk_rounded, size: 16, color: Colors.white),
                label: const Text('Record Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordReturnDialog(context, req, notifier, isDark),
                icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                label: const Text('Record Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMovementStepCard({
    required String title,
    required String time,
    required bool isDone,
    required String gate,
    required String verifiedBy,
    String? remarks,
    required VoidCallback onAction,
    required String actionLabel,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDone
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: isDone
                  ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    InkWell(
                      onTap: onAction,
                      child: Text(actionLabel, style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('$time • $gate', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                if (remarks != null && remarks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Note: $remarks', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: DOCUMENTS TAB (Full CRUD: Upload, Preview, Download, Delete)
  // ===========================================================================
  Widget _buildDocumentsTab(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    final docs = req.documents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "+ Upload Document" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Supporting Documents (${docs.length})',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showUploadDocumentDialog(context, req, notifier, isDark),
              icon: const Icon(Icons.cloud_upload_outlined, size: 15, color: Colors.white),
              label: const Text('Upload Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (docs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    'No supporting documents attached.',
                    style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Upload parent consent letters, medical certificates, or tickets.',
                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showUploadDocumentDialog(context, req, notifier, isDark),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Attach First Document'),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildDocumentCard(context, req, doc, notifier, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    LeaveOutingRequestItem req,
    LeaveOutingDocumentItem doc,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final docName = doc.documentName.toLowerCase();
    final cType = doc.contentType.toLowerCase();
    final isImage = docName.endsWith('.jpg') ||
        docName.endsWith('.jpeg') ||
        docName.endsWith('.png') ||
        docName.endsWith('.webp') ||
        docName.endsWith('.gif') ||
        docName.endsWith('.bmp') ||
        cType.startsWith('image/');
    final isPdf = !isImage && (docName.endsWith('.pdf') || cType.contains('pdf'));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Type Icon Badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isPdf
                  ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2))
                  : isImage
                      ? (isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF))
                      : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf
                  ? Icons.picture_as_pdf_rounded
                  : isImage
                      ? Icons.image_rounded
                      : Icons.description_rounded,
              color: isPdf
                  ? const Color(0xFFDC2626)
                  : isImage
                      ? const Color(0xFF9333EA)
                      : const Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.documentName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doc.documentType,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${doc.fileSizeFormatted} • Uploaded ${doc.uploadedAt != null ? _formatDateTime(doc.uploadedAt!) : "Recently"} by ${doc.uploadedByName ?? "Staff"}',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: ${doc.notes}',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action Buttons: View, Download, Delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                color: const Color(0xFF2563EB),
                tooltip: 'Preview Document',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () => _previewDocument(context, req, doc, notifier, isDark),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.download_rounded, size: 18),
                color: const Color(0xFF16A34A),
                tooltip: 'Download File',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () => notifier.downloadAndSaveLeaveDocument(req.id, doc.id, doc.documentName),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: const Color(0xFFDC2626),
                tooltip: 'Delete Document',
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteDocument(context, req, doc, notifier, isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 5: ACTIVITY TAB (Chronological Audit Trail & Add/Delete Internal Notes)
  // ===========================================================================
  Widget _buildActivityTab(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with "+ Add Note" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildSectionHeader('Audit Trail & Staff Notes', isDark)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _showAddNoteDialog(context, req, notifier, isDark),
              icon: const Icon(Icons.add_comment_outlined, size: 14, color: Color(0xFF2563EB)),
              label: const Text('Add Note', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Staff Internal Notes List
        if (req.internalNotes.isNotEmpty) ...[
          Text('Internal Staff Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
          const SizedBox(height: 8),
          ...req.internalNotes.map((note) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(note.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.note, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        const SizedBox(height: 3),
                        Text(
                          '${note.authorName ?? "Warden"} • ${note.createdAt != null ? _formatDateTime(note.createdAt!) : "Recently"}',
                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => notifier.deleteLeaveInternalNote(req.id, note.id),
                    tooltip: 'Delete Note',
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        // 2. Chronological System Events
        Text('System Activity Log (IST)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
        const SizedBox(height: 8),
        if (req.timeline.isNotEmpty) ...[
          ...req.timeline.map((event) {
            final title = event['title']?.toString() ?? 'Activity Event';
            final time = event['timestamp']?.toString() ?? '';
            final actor = event['actor']?.toString() ?? 'System';
            final remarks = event['remarks']?.toString();
            final actorStr = (remarks != null && remarks.isNotEmpty) ? '$actor ($remarks)' : actor;
            return _buildAuditItem(title, time, 'By $actorStr', isDark);
          }),
        ] else ...[
          _buildAuditItem('Request Submitted', req.requestedOnFormatted ?? 'Recently', 'By ${req.studentName}', isDark),
          if (req.approvedAt != null)
            _buildAuditItem('Request Approved', _formatDateTime(req.approvedAt!), 'By ${req.approvedByName ?? "Warden"}', isDark),
          if (req.passNumber != null)
            _buildAuditItem('Digital Gate Pass Issued', 'Pass #${req.passNumber}', 'Issued for student', isDark, passNumber: req.passNumber),
          if (req.actualExitAt != null)
            _buildAuditItem('Campus Exit Recorded', _formatDateTime(req.actualExitAt!), 'By Gate Security (${req.exitGate ?? "Main Gate"})', isDark),
          if (req.actualReturnAt != null)
            _buildAuditItem('Campus Return Recorded', _formatDateTime(req.actualReturnAt!), 'By Gate Security (${req.returnGate ?? "Main Gate"})', isDark),
        ],
      ],
    );
  }

  // ===========================================================================
  // MODALS & CRUD DIALOGS
  // ===========================================================================

  void _showUploadDocumentDialog(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    String selectedType = 'Parent Consent';
    String? selectedFileName;
    int? selectedFileSize;
    Uint8List? selectedBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.cloud_upload_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Attach Supporting Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Document Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Parent Consent Letter',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Suggestion Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['Parent Consent Letter', 'Medical Certificate', 'Travel Ticket', 'Gate Permission'].map((preset) {
                      return ActionChip(
                        label: Text(preset, style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setModalState(() {
                            final ext = (selectedFileName != null && selectedFileName!.contains('.'))
                                ? '.${selectedFileName!.split('.').last.toLowerCase()}'
                                : '';
                            titleController.text = '$preset$ext';
                            if (preset.contains('Medical')) selectedType = 'Medical Certificate';
                            if (preset.contains('Ticket')) selectedType = 'Travel Ticket';
                            if (preset.contains('Consent')) selectedType = 'Parent Consent';
                            if (preset.contains('Permission')) selectedType = 'Permission Slip';
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  Text('Document Category *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  AppSearchableDropdownFormField<String>.fromMenuItems(
                    initialValue: selectedType,
                    items: const [
                      DropdownMenuItem(value: 'Parent Consent', child: Text('Parent Consent')),
                      DropdownMenuItem(value: 'Medical Certificate', child: Text('Medical Certificate')),
                      DropdownMenuItem(value: 'Travel Ticket', child: Text('Travel Ticket')),
                      DropdownMenuItem(value: 'Permission Slip', child: Text('Permission Slip')),
                      DropdownMenuItem(value: 'Identity Proof', child: Text('Identity Proof')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // File Picker area
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    ),
                    child: Column(
                      children: [
                        Icon(selectedFileName != null ? Icons.check_circle_outline : Icons.attach_file_rounded, size: 28, color: selectedFileName != null ? const Color(0xFF16A34A) : const Color(0xFF2563EB)),
                        const SizedBox(height: 6),
                        Text(
                          selectedFileName ?? 'Select File from Device (PDF, JPG, PNG, WEBP)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'webp'],
                              withData: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final f = result.files.first;
                              final pickedExt = f.name.contains('.') ? '.${f.name.split('.').last.toLowerCase()}' : '';
                              setModalState(() {
                                selectedFileName = f.name;
                                selectedFileSize = f.size;
                                selectedBytes = f.bytes;
                                if (titleController.text.trim().isEmpty) {
                                  titleController.text = f.name;
                                } else {
                                  final base = titleController.text.trim().replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                                  titleController.text = '$base$pickedExt';
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(selectedFileName != null ? 'Change File' : 'Browse Files'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text('Notes / Observations (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Received signed consent copy by father',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                var title = titleController.text.trim();
                if (title.isEmpty) return;

                final actualExt = (selectedFileName != null && selectedFileName!.contains('.'))
                    ? '.${selectedFileName!.split('.').last.toLowerCase()}'
                    : (title.contains('.') ? '.${title.split('.').last.toLowerCase()}' : '.pdf');

                if (!title.toLowerCase().endsWith(actualExt)) {
                  final base = title.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
                  title = '$base$actualExt';
                }

                final sizeBytes = selectedFileSize ?? (selectedBytes != null ? selectedBytes!.length : 150000);
                final sizeKb = sizeBytes / 1024.0;
                final sizeFmt = sizeKb < 1024 ? '${sizeKb.toStringAsFixed(1)} KB' : '${(sizeKb / 1024.0).toStringAsFixed(1)} MB';
                final lower = actualExt.toLowerCase();
                final cType = lower == '.png'
                    ? 'image/png'
                    : (lower == '.jpg' || lower == '.jpeg'
                        ? 'image/jpeg'
                        : (lower == '.webp'
                            ? 'image/webp'
                            : (lower == '.docx'
                                ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                                : 'application/pdf')));

                final docPayload = <String, dynamic>{
                  'document_name': title,
                  'document_type': selectedType,
                  'file_url': selectedBytes != null
                      ? 'data:$cType;base64,${base64Encode(selectedBytes!)}'
                      : 'https://edushamiit.edu/documents/${Uri.encodeComponent(title)}',
                  'file_size_bytes': sizeBytes,
                  'file_size_formatted': sizeFmt,
                  'content_type': cType,
                  'notes': notesController.text.trim(),
                  if (selectedBytes != null) 'file_bytes': selectedBytes,
                  if (selectedBytes != null) 'file_base64': base64Encode(selectedBytes!),
                };

                Navigator.pop(ctx);
                notifier.uploadLeaveDocument(req.id, docPayload);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Upload Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _previewDocument(
    BuildContext context,
    LeaveOutingRequestItem req,
    LeaveOutingDocumentItem doc,
    HostelNotifier notifier,
    bool isDark,
  ) {
    Uint8List? previewImageBytes;
    final url = doc.fileUrl ?? '';
    if (url.startsWith('data:image/')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          previewImageBytes = base64Decode(url.substring(commaIdx + 1));
        }
      } catch (_) {}
    }

    final docName = doc.documentName.toLowerCase();
    final cType = doc.contentType.toLowerCase();
    final isImage = docName.endsWith('.jpg') ||
        docName.endsWith('.jpeg') ||
        docName.endsWith('.png') ||
        docName.endsWith('.webp') ||
        docName.endsWith('.gif') ||
        cType.startsWith('image/') ||
        previewImageBytes != null;
    final isPdf = !isImage && (docName.endsWith('.pdf') || url.contains('pdf') || cType.contains('pdf'));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Icon(
              isImage
                  ? Icons.image_rounded
                  : (isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded),
              color: isImage
                  ? const Color(0xFF9333EA)
                  : (isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                doc.documentName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: previewImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          previewImageBytes,
                          fit: BoxFit.contain,
                        ),
                      )
                    : (isImage && (url.startsWith('http://') || url.startsWith('https://'))
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFFEF4444)),
                                    const SizedBox(height: 8),
                                    Text(doc.documentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    const Text('Image archive record attached', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isPdf
                                      ? Icons.picture_as_pdf_rounded
                                      : (isImage ? Icons.image_rounded : Icons.document_scanner_rounded),
                                  size: 54,
                                  color: isPdf
                                      ? const Color(0xFFDC2626)
                                      : (isImage ? const Color(0xFF9333EA) : const Color(0xFF2563EB)),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  doc.documentType,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc.fileSizeFormatted,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Verified Digital Archive Record',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )),
              ),
              const SizedBox(height: 12),
              if (doc.notes != null && doc.notes!.isNotEmpty)
                Text(
                  'Notes: ${doc.notes}',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              notifier.downloadAndSaveLeaveDocument(req.id, doc.id, doc.documentName);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDocument(
    BuildContext context,
    LeaveOutingRequestItem req,
    LeaveOutingDocumentItem doc,
    HostelNotifier notifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Delete Supporting Document'),
        content: Text('Are you sure you want to permanently remove "${doc.documentName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteLeaveDocument(req.id, doc.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final noteController = TextEditingController();
    String category = 'General';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text('Add Internal Staff Note'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchableDropdownFormField<String>.fromMenuItems(
                  initialValue: category,
                  items: const [
                    DropdownMenuItem(value: 'General', child: Text('General Note')),
                    DropdownMenuItem(value: 'Guardian Verification', child: Text('Guardian Verification')),
                    DropdownMenuItem(value: 'Disciplinary', child: Text('Disciplinary Note')),
                    DropdownMenuItem(value: 'Medical', child: Text('Medical Observation')),
                    DropdownMenuItem(value: 'Security', child: Text('Gate Security Note')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => category = val);
                  },
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter internal observation or guardian conversation log...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final txt = noteController.text.trim();
                if (txt.isEmpty) return;
                Navigator.pop(ctx);
                notifier.addLeaveInternalNote(req.id, note: txt, category: category);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Save Note', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRequestDialog(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final reasonController = TextEditingController(text: req.reason);
    final destinationController = TextEditingController(text: req.destination);
    final addressController = TextEditingController(text: req.destinationAddress ?? '');
    final instructionsController = TextEditingController(text: req.specialInstructions ?? '');
    final guardianNameController = TextEditingController(text: req.guardianName ?? '');
    final guardianPhoneController = TextEditingController(text: req.guardianPhone ?? '');
    final vehicleController = TextEditingController(text: req.vehicleNumber ?? '');
    String reqType = req.requestType;
    String reqSubtype = req.requestSubtype ?? 'Personal';
    String transportMode = req.transportMode ?? 'WALK';
    bool isEmergency = req.isEmergency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Edit Request Details (${req.requestNumber})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppSearchableDropdownFormField<String>.fromMenuItems(
                          initialValue: ['LEAVE', 'OUTING'].contains(reqType.toUpperCase()) ? reqType.toUpperCase() : 'LEAVE',
                          items: const [
                            DropdownMenuItem(value: 'LEAVE', child: Text('Leave (Extended)')),
                            DropdownMenuItem(value: 'OUTING', child: Text('Outing (Short)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModalState(() => reqType = v);
                          },
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppSearchableDropdownFormField<String>.fromMenuItems(
                          initialValue: ['Personal', 'Home Leave', 'Medical Leave', 'Market Visit', 'Coaching', 'Emergency'].contains(reqSubtype)
                              ? reqSubtype
                              : 'Personal',
                          items: const [
                            DropdownMenuItem(value: 'Personal', child: Text('Personal')),
                            DropdownMenuItem(value: 'Home Leave', child: Text('Home Leave')),
                            DropdownMenuItem(value: 'Medical Leave', child: Text('Medical Leave')),
                            DropdownMenuItem(value: 'Market Visit', child: Text('Market Visit')),
                            DropdownMenuItem(value: 'Coaching', child: Text('Coaching')),
                            DropdownMenuItem(value: 'Emergency', child: Text('Emergency')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModalState(() => reqSubtype = v);
                          },
                          decoration: const InputDecoration(labelText: 'Subtype', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason for Movement *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destinationController,
                    decoration: const InputDecoration(labelText: 'Destination City / Area *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Full Address / Contact Location', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: guardianNameController,
                          decoration: const InputDecoration(labelText: 'Guardian Name', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: guardianPhoneController,
                          decoration: const InputDecoration(labelText: 'Guardian Phone', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppSearchableDropdownFormField<String>.fromMenuItems(
                          initialValue: ['WALK', 'CAB', 'AUTO', 'BUS', 'TRAIN', 'PERSONAL_CAR'].contains(transportMode)
                              ? transportMode
                              : 'WALK',
                          items: const [
                            DropdownMenuItem(value: 'WALK', child: Text('On Foot / Walk')),
                            DropdownMenuItem(value: 'CAB', child: Text('Taxi / Cab')),
                            DropdownMenuItem(value: 'AUTO', child: Text('Auto Rickshaw')),
                            DropdownMenuItem(value: 'BUS', child: Text('Bus')),
                            DropdownMenuItem(value: 'TRAIN', child: Text('Train')),
                            DropdownMenuItem(value: 'PERSONAL_CAR', child: Text('Personal Vehicle')),
                          ],
                          onChanged: (v) {
                            if (v != null) setModalState(() => transportMode = v);
                          },
                          decoration: const InputDecoration(labelText: 'Transport Mode', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: vehicleController,
                          decoration: const InputDecoration(labelText: 'Vehicle Number', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsController,
                    decoration: const InputDecoration(labelText: 'Special Instructions / Notes', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Emergency Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: isEmergency,
                    onChanged: (v) => setModalState(() => isEmergency = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                final dest = destinationController.text.trim();
                if (reason.isEmpty || dest.isEmpty) return;

                final payload = {
                  'student_id': req.studentId,
                  'request_type': reqType,
                  'request_subtype': reqSubtype,
                  'reason': reason,
                  'destination': dest,
                  'destination_address': addressController.text.trim(),
                  'special_instructions': instructionsController.text.trim(),
                  'guardian_name': guardianNameController.text.trim(),
                  'guardian_phone': guardianPhoneController.text.trim(),
                  'transport_mode': transportMode,
                  'vehicle_number': vehicleController.text.trim(),
                  'is_emergency': isEmergency,
                  'start_at': req.startAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
                  'expected_return_at': req.expectedReturnAt?.toIso8601String() ?? DateTime.now().add(const Duration(days: 1)).toIso8601String(),
                };

                Navigator.pop(ctx);
                notifier.updateLeaveRequestDetails(req.id, payload);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRequest(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Delete Movement Request'),
        content: Text('Permanently delete request ${req.requestNumber} for ${req.studentName}? Any issued gate pass will also be invalidated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.deleteLeaveRequest(req.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRecordExitDialog(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final uniqueGates = <String>{
      'Main Gate',
      'Main Security Gate',
      'North Gate',
      'Gate 2 (Hostel Quad)',
      'Girls Hostel Gate',
      'South Gate',
      if (req.exitGate != null && req.exitGate!.trim().isNotEmpty) req.exitGate!.trim(),
    }.toList();
    String gate = (req.exitGate != null && req.exitGate!.trim().isNotEmpty)
        ? req.exitGate!.trim()
        : 'Main Gate';
    if (!uniqueGates.contains(gate)) {
      gate = uniqueGates.first;
    }
    final remarksController = TextEditingController(text: req.exitRemarks ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Record Exit: ${req.studentName}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchableDropdownFormField<String>.fromMenuItems(
                  key: ValueKey('exit_gate_$gate'),
                  initialValue: gate,
                  items: uniqueGates
                      .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => gate = v);
                  },
                  decoration: const InputDecoration(labelText: 'Departure Gate', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(labelText: 'Security Remarks / Officer Notes', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                notifier.markMovementExit(req.id, gate: gate, remarks: remarksController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Record Exit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordReturnDialog(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final uniqueGates = <String>{
      'Main Gate',
      'Main Security Gate',
      'North Gate',
      'Gate 2 (Hostel Quad)',
      'Girls Hostel Gate',
      'South Gate',
      if (req.returnGate != null && req.returnGate!.trim().isNotEmpty) req.returnGate!.trim(),
    }.toList();
    String gate = (req.returnGate != null && req.returnGate!.trim().isNotEmpty)
        ? req.returnGate!.trim()
        : 'Main Gate';
    if (!uniqueGates.contains(gate)) {
      gate = uniqueGates.first;
    }
    final remarksController = TextEditingController(text: req.returnRemarks ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Record Return: ${req.studentName}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSearchableDropdownFormField<String>.fromMenuItems(
                  key: ValueKey('return_gate_$gate'),
                  initialValue: gate,
                  items: uniqueGates
                      .map((g) => DropdownMenuItem<String>(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => gate = v);
                  },
                  decoration: const InputDecoration(labelText: 'Arrival Gate', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(labelText: 'Security Verification Remarks', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                notifier.markMovementReturn(req.id, gate: gate, remarks: remarksController.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Record Return', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetMovement(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Reset Movement Record'),
        content: const Text('Reset exit/return log and return request status back to Approved?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.resetLeaveMovement(req.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            child: const Text('Reset Movement', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRevokeApproval(
    BuildContext context,
    LeaveOutingRequestItem req,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Revoke Request Approval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('State reason for revoking approval. Status will revert to Pending.'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'e.g. Parental cancellation request', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.revokeLeaveApproval(req.id, reason: reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            child: const Text('Confirm Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmApproval(BuildContext context, LeaveOutingRequestItem req, HostelNotifier notifier) {
    final remarksController = TextEditingController(text: 'Approved by Warden.');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Approve Movement Request', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Approve ${req.requestType.toLowerCase()} request for ${req.studentName}? A digital gate pass will be generated.',
              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(labelText: 'Approval Remarks / Conditions', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.approveLeaveRequest(req.id, remarks: remarksController.text.trim(), version: req.version);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Approve Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmRejection(BuildContext context, LeaveOutingRequestItem req, HostelNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Reject Movement Request', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify reason for rejecting ${req.studentName}\'s request:',
              style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. Incomplete permissions or disciplinary hold',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              notifier.rejectLeaveRequest(req.id, reason: reasonController.text.trim(), version: req.version);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(LeaveOutingRequestItem req, HostelNotifier notifier, bool isDark) {
    final status = req.status.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          if (status == 'PENDING' || status == 'NEW' || status == 'ACTIVE') ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _confirmApproval(context, req, notifier),
                icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmRejection(context, req, notifier),
                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ] else if (status == 'APPROVED') ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordExitDialog(context, req, notifier, isDark),
                icon: const Icon(Icons.directions_walk_rounded, size: 16, color: Colors.white),
                label: const Text('Mark Exit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ] else if (status == 'EXITED' || status == 'OVERDUE' || status == 'OVERDUE_RETURN') ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRecordReturnDialog(context, req, notifier, isDark),
                icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                label: const Text('Mark Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onClose,
                child: const Text('Close Inspector'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
                color: isHighlight
                    ? const Color(0xFFEF4444)
                    : isDark
                        ? Colors.white
                        : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditItem(String event, String time, String actor, bool isDark, {String? passNumber}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 7, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  passNumber != null ? '$passNumber • $actor' : '$time • $actor',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, bool isDark) {
    Color bg = const Color(0xFFEFF6FF);
    Color fg = const Color(0xFF2563EB);

    final s = status.toUpperCase();
    if (s == 'APPROVED') {
      bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (s == 'REJECTED') {
      bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    } else if (s == 'PENDING') {
      bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (s == 'EXITED') {
      bg = isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF3E8FF);
      fg = const Color(0xFF9333EA);
    } else if (s == 'RETURNED') {
      bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFD1FAE5);
      fg = const Color(0xFF059669);
    } else if (s == 'OVERDUE') {
      bg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  DateTime _toIst(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(const Duration(hours: 5, minutes: 30));
  }

  String _formatDateTime(DateTime dt) {
    final ist = _toIst(dt);
    final h = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final m = ist.minute.toString().padLeft(2, '0');
    final ampm = ist.hour >= 12 ? 'PM' : 'AM';
    return '${ist.day.toString().padLeft(2, '0')} ${_monthName(ist.month)} ${ist.year}, $h:$m $ampm';
  }

  
  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}

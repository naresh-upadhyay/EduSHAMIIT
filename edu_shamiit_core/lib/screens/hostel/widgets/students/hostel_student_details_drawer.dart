import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../dialogs/transfer_hostel_student_dialog.dart';
import '../dialogs/release_bed_dialog.dart';
import '../dialogs/checkout_hostel_student_dialog.dart';
import '../dialogs/hostel_id_card_dialog.dart';
import '../complaints/dialogs/raise_complaint_dialog.dart';
import '../leave/create_leave_outing_dialog.dart';
import '../../../../utils/download_helper.dart';

class HostelStudentDetailsDrawer extends ConsumerWidget {
  const HostelStudentDetailsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final detail = state.selectedStudentDetail;

    if (state.isStudentDetailLoading) {
      return Container(
        decoration: _containerDecoration(isDark),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 12),
              Text('Loading student 360 profile...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    if (detail == null) {
      return Container(
        decoration: _containerDecoration(isDark),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Select a student from the roster to view their 360 details',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: _containerDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Top Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Student Details',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                _buildDrawerTopMenu(context, detail, notifier, isDark),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Card (Avatar, Name, Status, Subtitle)
                  _buildHeroProfile(detail, isDark),
                  const SizedBox(height: 16),

                  // 5 Inner Tabs
                  _buildInnerTabBar(state.studentDrawerTab, notifier, isDark),
                  const SizedBox(height: 16),

                  // Inner Tab View Content
                  _buildInnerTabContent(context, ref, state.studentDrawerTab, detail, notifier, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _containerDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Widget _buildHeroProfile(HostelStudentDetail360 detail, bool isDark) {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
          backgroundImage: detail.avatarUrl != null && detail.avatarUrl!.startsWith('http')
              ? NetworkImage(detail.avatarUrl!)
              : null,
          child: detail.avatarUrl == null || !detail.avatarUrl!.startsWith('http')
              ? Text(
                  detail.studentName.isNotEmpty ? detail.studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                )
              : null,
        ),
        const SizedBox(height: 10),

        // Name + Active Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              detail.studentName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: detail.status == 'Leave'
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: detail.status == 'Leave'
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    detail.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: detail.status == 'Leave'
                          ? const Color(0xFFB45309)
                          : const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Subtitle 1: Roll No | Class
        Text(
          'Roll: ${detail.rollNo}  |  Class: ${detail.className}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),

        // Subtitle 2: Hostel | Room | Bed
        Text(
          '${detail.hostelName}  |  Room: ${detail.roomNumber}  |  Bed: ${detail.bedNo}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildInnerTabBar(int activeTab, HostelNotifier notifier, bool isDark) {
    const tabs = ['Overview', 'Details', 'Fees', 'Leave/Outing', 'Documents'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final title = entry.value;
          final isSelected = activeTab == idx;

          return Expanded(
            child: InkWell(
              onTap: () => notifier.setStudentDrawerTab(idx),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInnerTabContent(
    BuildContext context,
    WidgetRef ref,
    int tabIndex,
    HostelStudentDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    switch (tabIndex) {
      case 0:
        return _buildOverviewTab(context, detail, notifier, isDark);
      case 1:
        return _buildDetailsTab(detail, isDark);
      case 2:
        return _buildFeesTab(context, detail, isDark);
      case 3:
        return _buildLeaveOutingTab(context, ref, detail, notifier, isDark);
      case 4:
        return _buildDocumentsTab(context, ref, detail, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // INNER TAB 0: OVERVIEW (Screenshot Pixel-Match)
  // ==========================================================================
  Widget _buildOverviewTab(
    BuildContext context,
    HostelStudentDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 2-Column Info Grid matching Screenshot
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              _buildInfoGridRow('Date of Admission', detail.admissionDate, 'Hostel', detail.hostelName, isDark),
              const Divider(height: 14),
              _buildInfoGridRow('Room & Bed', detail.roomAndBed, 'Hostel Type', detail.hostelType, isDark),
              const Divider(height: 14),
              _buildInfoGridRow('Fee Plan', detail.feePlan, 'Blood Group', detail.bloodGroup, isDark),
              const Divider(height: 14),
              _buildInfoGridRow('Emergency Contact', detail.emergencyContact, 'Address', detail.address, isDark),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. QUICK ACTIONS (8 Buttons matching Screenshot)
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickActionButton(
              label: 'Change Room',
              icon: Icons.swap_horiz_rounded,
              bgColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
              textColor: const Color(0xFF2563EB),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => TransferHostelStudentDialog(student: _asRosterItem(detail)),
                );
              },
            ),
            _buildQuickActionButton(
              label: 'Leave/Outing',
              icon: Icons.exit_to_app_rounded,
              bgColor: isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.3) : const Color(0xFFF5F3FF),
              textColor: const Color(0xFF7C3AED),
              onTap: () => notifier.setStudentDrawerTab(3),
            ),
            _buildQuickActionButton(
              label: 'Fee Details',
              icon: Icons.payments_outlined,
              bgColor: isDark ? const Color(0xFF14532D).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
              textColor: const Color(0xFF16A34A),
              onTap: () => notifier.setStudentDrawerTab(2),
            ),
            _buildQuickActionButton(
              label: 'Generate ID Card',
              icon: Icons.badge_outlined,
              bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
              textColor: const Color(0xFFD97706),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => HostelIdCardDialog(student: detail),
                );
              },
            ),
            _buildQuickActionButton(
              label: 'Add Complaint',
              icon: Icons.report_problem_outlined,
              bgColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFFF1F2),
              textColor: const Color(0xFFE11D48),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => RaiseComplaintDialog(
                    initialStudentName: detail.studentName,
                    initialRoomNumber: detail.roomNumber,
                    initialHostelName: detail.hostelName,
                  ),
                );
              },
            ),
            _buildQuickActionButton(
              label: 'View Documents',
              icon: Icons.folder_shared_outlined,
              bgColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF),
              textColor: const Color(0xFF4F46E5),
              onTap: () => notifier.setStudentDrawerTab(4),
            ),
            _buildQuickActionButton(
              label: 'Send Message',
              icon: Icons.chat_bubble_outline_rounded,
              bgColor: isDark ? const Color(0xFF134E4A).withValues(alpha: 0.3) : const Color(0xFFF0FDFA),
              textColor: const Color(0xFF0D9488),
              onTap: () => _showMessageDialog(context, detail, isDark),
            ),
            _buildQuickActionButton(
              label: 'More Actions',
              icon: Icons.more_horiz_rounded,
              bgColor: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF8FAFC),
              textColor: const Color(0xFF64748B),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => _buildMoreActionsSheet(context, detail, notifier),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. RECENT ACTIVITIES TIMELINE matching Screenshot
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activities',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            InkWell(
              onTap: () => _showActivitiesDialog(context, detail, isDark),
              child: const Text(
                'View All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Timeline items
        Column(
          children: detail.activities.map((act) {
            final isLast = act == detail.activities.last;
            return _buildTimelineItem(act, isLast, isDark);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoGridRow(String label1, String value1, String label2, String value2, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label1,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label2,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 148,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(HostelStudentActivity act, bool isLast, bool isDark) {
    Color dotColor = const Color(0xFF2563EB);
    if (act.badgeColor == 'green') dotColor = const Color(0xFF16A34A);
    if (act.badgeColor == 'orange') dotColor = const Color(0xFFEA580C);
    if (act.badgeColor == 'purple') dotColor = const Color(0xFF7C3AED);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Connector line drawn behind dots
        if (!isLast)
          Positioned(
            top: 7,
            bottom: -7,
            left: 7.25,
            child: Container(
              width: 1.5,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator with dot
              SizedBox(
                width: 16,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      act.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      act.subtext,
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
        ),
      ],
    );
  }

  // ==========================================================================
  // INNER TAB 1: DETAILS
  // ==========================================================================
  Widget _buildDetailsTab(HostelStudentDetail360 detail, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Personal & Family Information', isDark),
        const SizedBox(height: 8),
        _buildDetailRow('Gender', detail.gender.isNotEmpty ? detail.gender : 'Not Specified', isDark),
        _buildDetailRow('Father\'s Name', detail.fatherName.isNotEmpty ? detail.fatherName : 'Not Specified', isDark),
        _buildDetailRow('Mother\'s Name', detail.motherName.isNotEmpty ? detail.motherName : 'Not Specified', isDark),
        _buildDetailRow('Guardian Relation', detail.guardianRelation.isNotEmpty ? detail.guardianRelation : 'Guardian', isDark),
        _buildDetailRow('Primary Phone', detail.phone.isNotEmpty ? detail.phone : 'Not Specified', isDark),
        _buildDetailRow('Email Address', detail.email.isNotEmpty ? detail.email : 'Not Specified', isDark),
        _buildDetailRow('Permanent Address', detail.address.isNotEmpty ? detail.address : 'Not Specified', isDark),
      ],
    );
  }

  // ==========================================================================
  // INNER TAB 2: FEES
  // ==========================================================================
  Widget _buildFeesTab(BuildContext context, HostelStudentDetail360 detail, bool isDark) {
    final fee = detail.feeSummary;
    final planName = fee['plan_name']?.toString() ?? detail.feePlan;
    final initialPaid = detail.initialPaymentAmount > 0
        ? detail.initialPaymentAmount
        : ((fee['initial_payment_amount'] as num?)?.toDouble() ?? 0.0);
    final billed = fee['billed_amount'] ?? 6000.0;
    final paid = fee['paid_amount'] ?? 6000.0;
    final dues = fee['outstanding_dues'] ?? 0.0;
    final invoices = (fee['recent_invoices'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fee Plan & Initial Payment Info Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_repeat_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 6),
                  Text('Billing Plan: $planName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(
                'Initial Paid: ₹${initialPaid.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ),

        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSmallFeeCard('Total Billed', '₹$billed', const Color(0xFF2563EB), isDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallFeeCard('Paid Amount', '₹$paid', const Color(0xFF16A34A), isDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSmallFeeCard('Pending Dues', '₹$dues', const Color(0xFFDC2626), isDark),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionHeader('Recent Invoices & Receipts', isDark),
        const SizedBox(height: 8),

        if (invoices.isEmpty)
          const Text('No recent invoice records', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
        else
          ...invoices.map((inv) {
            final m = inv as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['invoice_no'] ?? 'INV', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(m['date'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ],
                  ),
                  Text('₹${m['amount']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(m['status'] ?? 'PAID', style: const TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSmallFeeCard(String title, String val, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ==========================================================================
  // INNER TAB 3: LEAVE / OUTING (Dynamic From DB)
  // ==========================================================================
  Widget _buildLeaveOutingTab(
    BuildContext context,
    WidgetRef ref,
    HostelStudentDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    final leaves = detail.leaves;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Outing & Gate Passes (${leaves.length})', isDark),
            ElevatedButton.icon(
              onPressed: () async {
                final res = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => CreateLeaveOutingDialog(
                    initialType: 'OUTING',
                    initialStudentId: detail.studentId,
                    initialStudentName: detail.studentName,
                    initialStudentClass: detail.className,
                    initialStudentHostel: detail.hostelName,
                    initialStudentRoom: detail.roomNumber,
                    initialGuardianName: detail.guardianName,
                    initialGuardianPhone: detail.emergencyContact,
                  ),
                );
                if (res == true) {
                  await notifier.fetchStudentDetail(detail.studentId);
                  await notifier.loadLeaveOutingData(refreshKPIs: true);
                }
              },
              icon: const Icon(Icons.add, size: 14, color: Colors.white),
              label: const Text('New Pass', style: TextStyle(fontSize: 11, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 28),
                backgroundColor: const Color(0xFF7C3AED),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (leaves.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk_rounded, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No Movements or Passes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click "+ New Pass" above to submit a movement request.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...leaves.map((l) {
            Color statusColor;
            switch (l.status.toUpperCase()) {
              case 'APPROVED':
                statusColor = const Color(0xFF16A34A);
                break;
              case 'PENDING':
                statusColor = const Color(0xFFD97706);
                break;
              case 'EXITED':
                statusColor = const Color(0xFF2563EB);
                break;
              case 'REJECTED':
                statusColor = const Color(0xFFDC2626);
                break;
              default:
                statusColor = const Color(0xFF64748B);
            }
            final title = l.reason.isNotEmpty ? l.reason : l.requestSubtype;
            final passTag = (l.passNumber.isNotEmpty) ? 'Pass #${l.passNumber} · ' : '';

            return Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.status,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$passTag${l.leaveType} · Out: ${l.startDate} · Return: ${l.endDate}${l.destination.isNotEmpty ? ' · Dest: ${l.destination}' : ''}',
                    style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================================================
  // INNER TAB 4: DOCUMENTS (Dynamic Upload, Download & Delete from DB)
  // ==========================================================================
  Widget _buildDocumentsTab(BuildContext context, WidgetRef ref, HostelStudentDetail360 detail, bool isDark) {
    final docs = detail.documents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Verified Documents (${docs.length})', isDark),
            ElevatedButton.icon(
              onPressed: () => _showUploadDocumentDialog(context, ref, detail, isDark),
              icon: const Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
              label: const Text('Upload', style: TextStyle(fontSize: 11, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 28),
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_rounded, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No Documents Uploaded',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click "Upload" above to attach verified student records.',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...docs.map((d) {
            final isPdf = d.fileExtension == 'PDF';
            final isImage = d.fileExtension == 'JPG' || d.fileExtension == 'PNG' || d.fileExtension == 'JPEG';
            final docIcon = isPdf
                ? Icons.picture_as_pdf_rounded
                : isImage
                    ? Icons.image_rounded
                    : Icons.description_rounded;
            final iconColor = isPdf
                ? const Color(0xFFDC2626)
                : isImage
                    ? const Color(0xFF0D9488)
                    : const Color(0xFF2563EB);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(docIcon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.documentName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${d.fileExtension} · ${d.fileSizeFormatted} · ${d.documentType.replaceAll('_', ' ')}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                    splashRadius: 16,
                    tooltip: 'Download',
                    onPressed: () async {
                      final ext = d.fileExtension.toLowerCase();
                      final baseName = d.documentName.replaceAll(RegExp(r'\s+'), '_');
                      final filename = baseName.toLowerCase().endsWith('.$ext') ? baseName : '$baseName.$ext';

                      // 1. Download real original bytes from backend download endpoint
                      final realBytes = await ref.read(hostelProvider.notifier).downloadStudentDocument(d.id);
                      if (realBytes != null && realBytes.isNotEmpty) {
                        await getDownloadHelper().downloadBytes(realBytes, filename);
                      } else if (d.fileUrl.isNotEmpty && d.fileUrl.startsWith('http')) {
                        // 2. Direct public URL fallback
                        await getDownloadHelper().downloadFile(d.fileUrl, filename);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to download document: file content is not available'),
                              backgroundColor: Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloaded ${d.documentName} successfully'),
                            backgroundColor: const Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    splashRadius: 16,
                    tooltip: 'Delete Document',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Document?'),
                          content: Text('Are you sure you want to delete "${d.documentName}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(hostelProvider.notifier).deleteStudentDocument(d.id);
                      }
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showUploadDocumentDialog(BuildContext context, WidgetRef ref, HostelStudentDetail360 detail, bool isDark) {
    final nameController = TextEditingController();
    String docType = 'ADMISSION_FORM';
    PlatformFile? pickedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.upload_file_rounded, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  'Upload Student Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attach a verified official document for ${detail.studentName}.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Document Type *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: docType,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ADMISSION_FORM', child: Text('Admission Form (Signed)')),
                        DropdownMenuItem(value: 'MEDICAL_CERTIFICATE', child: Text('Medical Fitness Certificate')),
                        DropdownMenuItem(value: 'GUARDIAN_CONSENT', child: Text('Guardian Consent Letter')),
                        DropdownMenuItem(value: 'ID_PROOF', child: Text('Aadhaar / Identity Proof')),
                        DropdownMenuItem(value: 'FEE_RECEIPT', child: Text('Fee Payment Receipt')),
                        DropdownMenuItem(value: 'DISCIPLINARY', child: Text('Disciplinary / Undertaking')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other Verified Document')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            docType = v;
                            if (nameController.text.isEmpty) {
                              if (v == 'ADMISSION_FORM') nameController.text = 'Signed Admission Form';
                              if (v == 'MEDICAL_CERTIFICATE') nameController.text = 'Medical Fitness Certificate';
                              if (v == 'GUARDIAN_CONSENT') nameController.text = 'Guardian Consent Letter';
                              if (v == 'ID_PROOF') nameController.text = 'Identity Proof';
                              if (v == 'FEE_RECEIPT') nameController.text = 'Initial Fee Receipt';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Document Title / Label *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Hostel Admission Form (Signed)',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Select File *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: [
                              'pdf', 'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg',
                              'doc', 'docx', 'xls', 'xlsx', 'csv', 'ppt', 'pptx', 'txt'
                            ],
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            setDialogState(() {
                              pickedFile = result.files.first;
                              if (nameController.text.trim().isEmpty) {
                                nameController.text = pickedFile!.name.split('.').first;
                              }
                            });
                          }
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pickedFile != null
                                ? const Color(0xFF16A34A)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            style: BorderStyle.solid,
                          ),
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              pickedFile != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                              color: pickedFile != null ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pickedFile != null ? pickedFile!.name : 'Click to select file (PDF, Image, DOCX)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: pickedFile != null ? FontWeight.w600 : FontWeight.normal,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (pickedFile != null)
                                    Text(
                                      '${(pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (pickedFile == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a document file first')),
                          );
                          return;
                        }

                        final title = nameController.text.trim().isNotEmpty
                            ? nameController.text.trim()
                            : pickedFile!.name;
                        final filename = pickedFile!.name;
                        final size = pickedFile!.size;
                        final ext = filename.split('.').last.toLowerCase();
                        final String mime;
                        switch (ext) {
                          case 'pdf': mime = 'application/pdf'; break;
                          case 'jpg':
                          case 'jpeg': mime = 'image/jpeg'; break;
                          case 'png': mime = 'image/png'; break;
                          case 'webp': mime = 'image/webp'; break;
                          case 'gif': mime = 'image/gif'; break;
                          case 'bmp': mime = 'image/bmp'; break;
                          case 'svg': mime = 'image/svg+xml'; break;
                          case 'doc': mime = 'application/msword'; break;
                          case 'docx': mime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'; break;
                          case 'xls': mime = 'application/vnd.ms-excel'; break;
                          case 'xlsx': mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; break;
                          case 'csv': mime = 'text/csv'; break;
                          case 'ppt': mime = 'application/vnd.ms-powerpoint'; break;
                          case 'pptx': mime = 'application/vnd.openxmlformats-officedocument.presentationml.presentation'; break;
                          case 'txt': mime = 'text/plain'; break;
                          default: mime = 'application/octet-stream';
                        }

                        setDialogState(() => isUploading = true);
                        await ref.read(hostelProvider.notifier).uploadStudentDocument(
                          studentId: detail.studentId,
                          documentName: title,
                          documentType: docType,
                          fileSizeBytes: size,
                          mimeType: mime,
                          admissionId: detail.admissionId,
                          fileBytes: pickedFile!.bytes,
                          fileName: filename,
                        );
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                      },
                icon: isUploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                label: const Text('Upload Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMessageDialog(BuildContext context, HostelStudentDetail360 detail, bool isDark) {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0D9488)),
            const SizedBox(width: 8),
            Text('Message ${detail.studentName}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient: ${detail.studentName} (Contact: ${detail.emergencyContact})',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter message or emergency warden notice here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Message dispatched to ${detail.studentName} & Emergency Contact (${detail.emergencyContact})'),
                  backgroundColor: const Color(0xFF16A34A),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('Send Notice', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActivitiesDialog(BuildContext context, HostelStudentDetail360 detail, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Activity Log — ${detail.studentName}'),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          height: 380,
          child: detail.activities.isEmpty
              ? const Center(child: Text('No activities recorded yet'))
              : ListView.builder(
                  itemCount: detail.activities.length,
                  itemBuilder: (ctx, i) {
                    final act = detail.activities[i];
                    return _buildTimelineItem(act, i == detail.activities.length - 1, isDark);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTopMenu(
    BuildContext context,
    HostelStudentDetail360 detail,
    HostelNotifier notifier,
    bool isDark,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
      splashRadius: 18,
      onSelected: (val) {
        if (val == 'transfer') {
          showDialog(
            context: context,
            builder: (ctx) => TransferHostelStudentDialog(student: _asRosterItem(detail)),
          );
        } else if (val == 'release') {
          showDialog(
            context: context,
            builder: (ctx) => ReleaseBedDialog(student: _asRosterItem(detail)),
          );
        } else if (val == 'checkout') {
          showDialog(
            context: context,
            builder: (ctx) => CheckoutHostelStudentDialog(student: _asRosterItem(detail)),
          );
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'transfer',
          child: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 16),
              SizedBox(width: 8),
              Text('Change Room / Bed', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'release',
          child: Row(
            children: [
              Icon(Icons.bed_outlined, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Release Bed Allocation', style: TextStyle(fontSize: 13, color: Color(0xFFD97706))),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'checkout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Check Out Student', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoreActionsSheet(
    BuildContext context,
    HostelStudentDetail360 detail,
    HostelNotifier notifier,
  ) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB)),
            title: const Text('Transfer Student to Another Room'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => TransferHostelStudentDialog(student: _asRosterItem(detail)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bed_outlined, color: Color(0xFFD97706)),
            title: const Text('Release Bed (Awaiting Allocation)'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => ReleaseBedDialog(student: _asRosterItem(detail)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            title: const Text('Complete Authorized Check-Out'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => CheckoutHostelStudentDialog(student: _asRosterItem(detail)),
              );
            },
          ),
        ],
      ),
    );
  }

  HostelStudentRosterItem _asRosterItem(HostelStudentDetail360 detail) {
    return HostelStudentRosterItem(
      id: detail.admissionId,
      admissionId: detail.admissionId,
      allocationId: detail.allocationId,
      studentId: detail.studentId,
      photoUrl: detail.avatarUrl,
      studentName: detail.studentName,
      rollNo: detail.rollNo,
      className: detail.className,
      hostelId: detail.hostelId,
      hostelName: detail.hostelName,
      buildingId: detail.buildingId,
      roomId: detail.roomId,
      roomNumber: detail.roomNumber,
      bedId: detail.bedId,
      bedNo: detail.bedNo,
      status: detail.status,
      rawStatus: detail.admissionStatus,
      feeStatus: detail.feeSummary['fee_status'] ?? 'Paid',
      admissionDate: detail.admissionDate,
      gender: detail.gender,
      bloodGroup: detail.bloodGroup,
      emergencyContact: detail.emergencyContact,
      address: detail.address,
      feePlan: detail.feePlan,
      hostelType: detail.hostelType,
    );
  }
}

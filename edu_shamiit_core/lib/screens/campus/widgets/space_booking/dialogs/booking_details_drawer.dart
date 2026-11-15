import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/space_booking_models.dart';
import '../../../providers/space_booking_provider.dart';

class BookingDetailsDrawer extends ConsumerStatefulWidget {
  final SpaceBookingRequestItem item;

  const BookingDetailsDrawer({
    super.key,
    required this.item,
  });

  @override
  ConsumerState<BookingDetailsDrawer> createState() => _BookingDetailsDrawerState();
}

class _BookingDetailsDrawerState extends ConsumerState<BookingDetailsDrawer> {
  final TextEditingController _remarksCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(spaceBookingProvider.notifier);
    final item = widget.item;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final drawerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final drawerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Drawer(
      width: 480,
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: drawerBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.bookingRef.isNotEmpty ? item.bookingRef : 'Booking Details',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(item.status, isDark),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Space Details Card
                    _buildSectionHeader('Space Information', Icons.room_preferences_outlined, textPrimary),
                    _buildInfoCard([
                      _buildInfoRow('Space / Room', item.spaceDisplay, textSecondary, textPrimary),
                      _buildInfoRow('Building', item.buildingName, textSecondary, textPrimary),
                      _buildInfoRow('Category / Purpose', '${item.category} • ${item.purpose}', textSecondary, textPrimary),
                      _buildInfoRow('Priority', item.priority, textSecondary, textPrimary),
                    ], cardBg, drawerBorder),
                    const SizedBox(height: 16),

                    // Schedule & Timings Card
                    _buildSectionHeader('Schedule & Timing', Icons.schedule_outlined, textPrimary),
                    _buildInfoCard([
                      _buildInfoRow('Date', item.bookingDate, textSecondary, textPrimary),
                      _buildInfoRow('Time Range', '${item.startTime} – ${item.endTime}', textSecondary, textPrimary),
                      _buildInfoRow('Schedule Summary', item.formattedSchedule, textSecondary, textPrimary),
                      _buildInfoRow('Attendees Expected', '${item.attendeeCount} persons', textSecondary, textPrimary),
                    ], cardBg, drawerBorder),
                    const SizedBox(height: 16),

                    // Organizer Details Card
                    _buildSectionHeader('Organizer / Requester', Icons.person_outline, textPrimary),
                    _buildInfoCard([
                      _buildInfoRow('Organizer Name', item.organizerName, textSecondary, textPrimary),
                      _buildInfoRow('Institution Role', item.organizerRole, textSecondary, textPrimary),
                      _buildInfoRow('Requested By', item.requestedByDisplay, textSecondary, textPrimary),
                    ], cardBg, drawerBorder),
                    const SizedBox(height: 16),

                    // Approval Workflow Status
                    _buildSectionHeader('Approval Progression', Icons.verified_user_outlined, textPrimary),
                    _buildApprovalStepTimeline(item, cardBg, drawerBorder, textPrimary),
                    const SizedBox(height: 16),

                    // Action Comments / Remarks
                    _buildSectionHeader('Approval / Review Remarks', Icons.chat_bubble_outline, textPrimary),
                    TextFormField(
                      controller: _remarksCtrl,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add review comments or check-in condition notes...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: drawerBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: drawerBorder)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: drawerBorder)),
              ),
              child: Row(
                children: [
                  // Reject Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              final ok = await notifier.decideApproval(item.id, 'REJECT', comments: _remarksCtrl.text.trim());
                              setState(() => _isLoading = false);
                              if (ok && mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Booking "${item.title}" has been rejected')),
                                );
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: BorderSide(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Approve Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              final ok = await notifier.decideApproval(item.id, 'APPROVE', comments: _remarksCtrl.text.trim());
                              setState(() => _isLoading = false);
                              if (ok && mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Booking "${item.title}" approved successfully!')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children, Color cardBg, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textSecondary, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, color: textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStepTimeline(SpaceBookingRequestItem item, Color cardBg, Color border, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Step 1: Booking Request Submitted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
              ),
              const Text('Done', style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.status == 'Approved' || item.status == 'Confirmed'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.status == 'Approved' || item.status == 'Confirmed' ? Icons.check : Icons.access_time,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Step 2: Campus Administrator Approval', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
              ),
              Text(
                item.status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.status == 'Approved' || item.status == 'Confirmed'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7);
    Color fg = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
    if (status == 'Approved' || status == 'Confirmed') {
      bg = isDark ? const Color(0xFF065F46).withValues(alpha: 0.5) : const Color(0xFFDCFCE7);
      fg = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    } else if (status == 'Rejected') {
      bg = isDark ? const Color(0xFF991B1B).withValues(alpha: 0.5) : const Color(0xFFFEE2E2);
      fg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../constants/app_fonts.dart';
import '../../models/attendance_models.dart';

class AttendanceOverrideDialog extends StatefulWidget {
  final AttendanceStudentRowModel? student;
  final List<AttendanceStudentRowModel>? bulkStudents;
  final String? periodLabel;
  final int? periodNumber;
  final AttendanceStatus targetStatus;
  final VoidCallback? onCancel;
  final Function(String reason) onConfirm;

  const AttendanceOverrideDialog({
    super.key,
    this.student,
    this.bulkStudents,
    this.periodLabel,
    this.periodNumber,
    required this.targetStatus,
    this.onCancel,
    required this.onConfirm,
  });

  @override
  State<AttendanceOverrideDialog> createState() => _AttendanceOverrideDialogState();
}

class _AttendanceOverrideDialogState extends State<AttendanceOverrideDialog> {
  final TextEditingController _reasonController = TextEditingController();
  bool _hasError = false;

  final List<String> _quickReasons = const [
    'Principal Approved Exemption',
    'Medical Note / Certificate Submitted',
    'Correction of Entry Error',
    'Bus Delay / Transport Issue',
    'Official School Activity / Duty',
    'Parent Contacted & Verified',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isBulk = (widget.bulkStudents != null && widget.bulkStudents!.isNotEmpty);
    final studentCount = widget.bulkStudents?.length ?? 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: screenWidth < 520 ? double.infinity : 500,
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_open_rounded, color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBulk
                                ? 'Override & Unlock ($studentCount Students)'
                                : (widget.periodLabel != null
                                    ? 'Override & Unlock ${widget.periodLabel}'
                                    : 'Override Locked Attendance'),
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBulk
                                ? 'One or more selected records are currently locked.'
                                : 'Attendance record is currently locked.',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Warning Notice Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isBulk
                              ? 'Changing attendance will override and unlock the selected records to ${widget.targetStatus.label}. An audit log will be created.'
                              : 'Submitting this override will unlock the record to ${widget.targetStatus.label} and record your audit justification.',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Student Summary Pill / Target Info
                if (widget.student != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                          child: Text(
                            widget.student!.rollNumber.isNotEmpty ? widget.student!.rollNumber : '#',
                            style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.student!.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.periodLabel != null
                                    ? '${widget.student!.className} • ${widget.periodLabel}'
                                    : (widget.student!.sectionName.isNotEmpty
                                        ? '${widget.student!.className} • ${widget.student!.sectionName}'
                                        : widget.student!.className),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Target Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.targetStatus.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: widget.targetStatus.borderColor),
                          ),
                          child: Text(
                            widget.targetStatus.label,
                            style: TextStyle(color: widget.targetStatus.color, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (isBulk) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.groups_rounded, color: Color(0xFF4F46E5), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bulk Override for $studentCount Selected Students',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.targetStatus.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: widget.targetStatus.borderColor),
                          ),
                          child: Text(
                            'New: ${widget.targetStatus.label}',
                            style: TextStyle(color: widget.targetStatus.color, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Mandatory Reason Field
                Text(
                  'Override Reason (Mandatory)*',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  autofocus: true,
                  onChanged: (_) {
                    if (_hasError) setState(() => _hasError = false);
                  },
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'e.g. Principal approved exemption / Medical proof provided',
                    hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    errorText: _hasError ? 'Reason is required to override locked record' : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick Reason Suggestions
                Text(
                  'Quick Reasons:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReasons.map((reason) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _reasonController.text = reason;
                          _hasError = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _reasonController.text == reason
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: _reasonController.text == reason
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onCancel?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final reason = _reasonController.text.trim();
                        if (reason.isEmpty) {
                          setState(() => _hasError = true);
                          return;
                        }
                        Navigator.of(context).pop();
                        widget.onConfirm(reason);
                      },
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('Confirm Override & Unlock', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

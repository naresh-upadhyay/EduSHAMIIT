import 'package:flutter/material.dart';
import '../../../../constants/app_fonts.dart';
import '../../../../widgets/image_preview_dialog.dart';
import '../../models/attendance_models.dart';

class StudentAttendanceDrawer extends StatelessWidget {
  final AttendanceStudentRowModel student;
  final String dateStr;
  final List<AttendanceScheduleItemModel> schedules;
  final VoidCallback onClose;

  const StudentAttendanceDrawer({
    Key? key,
    required this.student,
    required this.dateStr,
    this.schedules = const [],
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 400,
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Student Attendance Details',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (student.avatarUrl != null) {
                              showDialog(
                                context: context,
                                builder: (_) => ImagePreviewDialog(imageUrl: student.avatarUrl!),
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF4F46E5).withOpacity(0.15),
                            backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                            child: student.avatarUrl == null
                                ? Text(
                                    student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S',
                                    style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 20),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${student.className} • ${student.sectionName}',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Roll No: ${student.rollNumber}  |  Adm: ${student.admissionNumber}',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Today's Status Banner
                  Text(
                    "Today's Attendance ($dateStr)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: student.status.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: student.status.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 14, color: student.status.color),
                        const SizedBox(width: 8),
                        Text(
                          student.status.label.toUpperCase(),
                          style: TextStyle(color: student.status.color, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        if (student.isLocked)
                          Row(
                            children: [
                              const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              const Text(
                                'Locked (All-Day)',
                                style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (student.remarks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Remarks: ${student.remarks}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  if (student.isOverridden) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_reset_rounded, size: 14, color: Color(0xFFD97706)),
                              SizedBox(width: 6),
                              Text(
                                'Manually Overridden',
                                style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${student.overrideReason ?? "N/A"}',
                            style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Today's Scheduled Periods Breakdown
                  const Text(
                    "Today's Schedule Breakdown",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  if (schedules.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          'No individual periods scheduled for today',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: schedules.map((sched) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: sched.subjectColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${sched.periodLabel} • ${sched.subjectName}',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    Text(
                                      '${sched.timeRange}  |  ${sched.teacherName}',
                                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: student.status.backgroundColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  student.status.code,
                                  style: TextStyle(color: student.status.color, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),

                  // 30-Day Attendance Health
                  const Text(
                    'Past 30 Days Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Overall Rate', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                            Text('88.5%', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            value: 0.885,
                            minHeight: 8,
                            backgroundColor: Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
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
    );
  }
}

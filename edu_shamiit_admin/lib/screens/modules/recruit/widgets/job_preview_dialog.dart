import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class JobPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onJobChanged;

  const JobPreviewDialog({
    super.key,
    required this.job,
    this.onJobChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = job['job_title'] ?? 'Role Details';
    final code = job['job_code'] ?? 'JOB-CODE';
    final dept = job['department'] ?? 'General';
    final workMode = job['work_mode'] ?? 'On-site';
    final empType = job['employment_type'] ?? 'Full-time';
    final location = job['location'] ?? 'Main Campus';
    final campus = job['campus'] ?? 'Main Branch';
    final status = job['publishing_status'] ?? 'Active';
    final isPublic = job['is_public'] == true;
    final slug = job['slug'] ?? job['id']?.toString() ?? '';
    final vacancies = job['vacancies'] ?? 1;
    final exp = job['experience_required'] ?? 'Not specified';
    final quals = job['qualifications'] ?? 'Not specified';
    final desc = job['description'] ?? 'No detailed description provided.';
    final responsibilities = job['responsibilities'];
    final benefits = job['benefits'];

    final minSal = job['salary_min'];
    final maxSal = job['salary_max'];
    final payFreq = job['pay_frequency'] ?? 'Monthly';
    final isSalaryPublic = job['is_salary_public'] == true;

    String salaryText = 'Competitive';
    if (minSal != null && maxSal != null) {
      salaryText = '₹${NumberFormat('#,##,###').format(minSal)} - ₹${NumberFormat('#,##,###').format(maxSal)} / $payFreq';
    } else if (minSal != null) {
      salaryText = 'From ₹${NumberFormat('#,##,###').format(minSal)} / $payFreq';
    } else if (maxSal != null) {
      salaryText = 'Up to ₹${NumberFormat('#,##,###').format(maxSal)} / $payFreq';
    }
    if (!isSalaryPublic) {
      salaryText += ' (Private / Confidential)';
    }

    final postedDate = job['job_posting_date'] != null
        ? DateFormat('dd MMMM yyyy').format(DateTime.parse(job['job_posting_date'].toString()))
        : 'Recently';
    final deadline = job['application_deadline'] != null
        ? DateFormat('dd MMMM yyyy').format(DateTime.parse(job['application_deadline'].toString()))
        : 'Open until filled';

    final reqSkills = List<String>.from(job['required_skills'] ?? []);
    final prefSkills = List<String>.from(job['preferred_skills'] ?? []);

    Color statusBg;
    Color statusColor;
    if (status == 'Active') {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      statusColor = const Color(0xFF10B981);
    } else if (status == 'Paused') {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      statusColor = const Color(0xFFD97706);
    } else if (status == 'Draft') {
      statusBg = const Color(0xFF64748B).withValues(alpha: 0.12);
      statusColor = const Color(0xFF64748B);
    } else {
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusColor = const Color(0xFFEF4444);
    }

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 850),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business_center_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isPublic
                                    ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                    : const Color(0xFF64748B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPublic ? Icons.public : Icons.lock_outline,
                                    size: 12,
                                    color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPublic ? 'Public Careers' : 'Internal Only',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$code • $dept • $empType • $workMode • $location ($campus)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Key Info Grid
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildInfoCard(
                          context,
                          icon: Icons.group_outlined,
                          title: 'Vacancies',
                          value: '$vacancies Openings',
                          color: const Color(0xFF4F46E5),
                        ),
                        _buildInfoCard(
                          context,
                          icon: Icons.work_history_outlined,
                          title: 'Experience Required',
                          value: exp,
                          color: const Color(0xFF0284C7),
                        ),
                        _buildInfoCard(
                          context,
                          icon: Icons.payments_outlined,
                          title: 'Salary & Compensation',
                          value: salaryText,
                          color: const Color(0xFF10B981),
                        ),
                        _buildInfoCard(
                          context,
                          icon: Icons.event_available_outlined,
                          title: 'Application Deadline',
                          value: deadline,
                          color: const Color(0xFFD97706),
                        ),
                        _buildInfoCard(
                          context,
                          icon: Icons.schedule_rounded,
                          title: 'Posted On',
                          value: postedDate,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Role Description
                    _buildSectionHeader(context, 'Role Description', Icons.description_outlined),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Key Responsibilities
                    if (responsibilities != null && responsibilities.toString().trim().isNotEmpty) ...[
                      _buildSectionHeader(context, 'Key Responsibilities', Icons.task_alt_rounded),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          responsibilities.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Qualifications & Requirements
                    _buildSectionHeader(context, 'Qualifications & Requirements', Icons.school_outlined),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Qualifications: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Expanded(child: Text(quals, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Experience: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Expanded(child: Text(exp, style: const TextStyle(fontSize: 13))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Skills
                    if (reqSkills.isNotEmpty || prefSkills.isNotEmpty) ...[
                      _buildSectionHeader(context, 'Required & Preferred Skills', Icons.stars_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...reqSkills.map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  s,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                ),
                              )),
                          ...prefSkills.map((s) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '$s (Preferred)',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                                ),
                              )),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Benefits
                    if (benefits != null && benefits.toString().trim().isNotEmpty) ...[
                      _buildSectionHeader(context, 'Benefits & Perks', Icons.card_giftcard_rounded),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          benefits.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Public Link Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isPublic
                            ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPublic
                              ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPublic ? Icons.link_rounded : Icons.info_outline,
                            color: isPublic ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPublic ? 'Public Job Portal Link' : 'Job is currently marked Internal / Private',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isPublic ? const Color(0xFF1E40AF) : const Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isPublic
                                      ? '${Uri.base.origin}/careers/jobs/$slug'
                                      : 'To allow candidates to find and apply from the Careers portal, set visibility to Public.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isPublic && slug.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final url = '${Uri.base.origin}/careers/jobs/$slug';
                                await Clipboard.setData(ClipboardData(text: url));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Public link copied: $url'), backgroundColor: const Color(0xFF16A34A)),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 14),
                              label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (isPublic && slug.isNotEmpty) ...[
                        SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go('/careers/jobs/$slug');
                            },
                            icon: const Icon(Icons.open_in_new, size: 15, color: Colors.white),
                            label: const Text('View on Public Careers', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      SizedBox(
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final url = '${Uri.base.origin}/careers/jobs/$slug';
                            await Clipboard.setData(ClipboardData(text: url));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isPublic
                                        ? 'Public link copied: $url'
                                        : 'Link copied! Note: Job is currently Private. Publish to Careers for candidates to view.',
                                  ),
                                  backgroundColor: isPublic ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Copy Link', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

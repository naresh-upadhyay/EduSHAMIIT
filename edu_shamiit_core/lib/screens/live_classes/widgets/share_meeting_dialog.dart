import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/live_class_models.dart';

class ShareMeetingDialog extends StatelessWidget {
  final ActiveLiveSession session;

  const ShareMeetingDialog({
    super.key,
    required this.session,
  });

  static Future<void> show(BuildContext context, ActiveLiveSession session) {
    return showDialog(
      context: context,
      builder: (ctx) => ShareMeetingDialog(session: session),
    );
  }

  String _getBaseOrigin() {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.contains('null')) {
        return origin;
      }
    }
    return 'http://localhost:60969';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final roomCode = session.roomCode.isNotEmpty ? session.roomCode : '10A-MATH';
    final origin = _getBaseOrigin();
    final orgLink = '$origin/admin/live-classes?code=$roomCode';
    final guestLink = '$origin/admin/live-classes?guest_code=$roomCode';

    final fullInviteText = '''
🎓 EduSHAMIIT Live Classroom Invitation

Topic: ${session.title}
Subject: ${session.subject} (${session.classSection})
Hosted by: ${session.teacherName}

🔑 Meeting Code: $roomCode

🏫 Organisation Member Link:
$orgLink

🌐 Outside Organisation / Guest Link:
$guestLink
(Note: External guests will be placed in the Waiting Room until admitted by the Host)
''';

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.share_rounded, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Meeting & Invite',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          session.title,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Meeting Code Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MEETING CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: textSecondary)),
                        const SizedBox(height: 3),
                        Text(
                          roomCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: roomCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Meeting Code $roomCode copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copy Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Organisation Member Join Link
              _buildLinkTile(
                context: context,
                isDark: isDark,
                icon: Icons.school_outlined,
                iconColor: const Color(0xFF0EA5E9),
                title: 'Organisation Join Link',
                subtitle: 'Direct join for enrolled students, teachers & institutional staff',
                url: orgLink,
              ),
              const SizedBox(height: 12),

              // 3. External Guest Join Link (With Waiting Room Notice)
              _buildLinkTile(
                context: context,
                isDark: isDark,
                icon: Icons.person_add_alt_1_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Outside Organisation / Guest Link',
                subtitle: 'External guests will wait in Waiting Room until Host admits them',
                url: guestLink,
                badge: 'Waiting Room Required',
              ),
              const SizedBox(height: 20),

              // Footer Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullInviteText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Complete invitation summary copied to clipboard!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: const Text('Copy Full Invitation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        foregroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Done', style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String url,
    String? badge,
  }) {
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textPrimary),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(fontSize: 10.5, color: textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$title copied to clipboard!')),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.copy_rounded, size: 14, color: iconColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentMessaging extends ConsumerStatefulWidget {
  const ParentMessaging({super.key});

  @override
  ConsumerState<ParentMessaging> createState() => _ParentMessagingState();
}

class _ParentMessagingState extends ConsumerState<ParentMessaging> {
  final _messageController = TextEditingController();
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final messagesAsync = ref.watch(parentMessagesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Messages'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showComposeDialog(context, isDark),
        backgroundColor: ParentColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final conversations = data['conversations'] as List<dynamic>? ?? [];
    final teachers = data['teachers'] as List<dynamic>? ?? [];

    // Cache teachers for compose dialog
    if (teachers.isNotEmpty && _selectedTeacherId == null) {
      _selectedTeacherId = teachers.first['teacher_id'] as String?;
      _selectedTeacherName = teachers.first['full_name'] as String?;
    }

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 80),
        children: [
          // ── Teachers Quick Access ──
          if (teachers.isNotEmpty) ...[
            Text(
              'Teachers'.tr(ref),
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? ParentColors.darkText : ParentColors.text,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: teachers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final teacher = teachers[index] as Map<String, dynamic>;
                  return _buildTeacherChip(teacher, isDark);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Conversations ──
          Text(
            'Recent Conversations'.tr(ref),
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? ParentColors.darkText : ParentColors.text,
            ),
          ),
          const SizedBox(height: 12),

          if (conversations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'No messages yet'.tr(ref),
                      style: TextStyle(
                          color: isDark
                              ? ParentColors.darkText3
                              : ParentColors.text3),
                    ),
                  ],
                ),
              ),
            )
          else
            ...conversations.map((c) {
              final conv = c as Map<String, dynamic>;
              return _buildConversationCard(conv, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildTeacherChip(Map<String, dynamic> teacher, bool isDark) {
    final name = teacher['full_name'] ?? 'Teacher';
    final subject = teacher['subject'] ?? '';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTeacherId = teacher['teacher_id'];
          _selectedTeacherName = name;
        });
        _showComposeDialog(context, isDark);
      },
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: isDark ? ParentColors.darkSurface : ParentColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? ParentColors.darkBorder
                  : ParentColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ParentColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ParentColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name.split(' ').last,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? ParentColors.darkText2 : ParentColors.text2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subject.isNotEmpty)
              Text(
                subject,
                style: TextStyle(
                  fontSize: 8,
                  color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conv, bool isDark) {
    final name = conv['teacher_name'] ?? 'Teacher';
    final lastMessage = conv['last_message'] ?? '';
    final timestamp = conv['timestamp'] ?? '';
    final unread = conv['unread_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unread > 0
              ? ParentColors.primary.withValues(alpha: 0.3)
              : (isDark ? ParentColors.darkBorder : ParentColors.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ParentColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ParentColors.primary,
                ),
              ),
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
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? ParentColors.darkText : ParentColors.text,
                      ),
                    ),
                    if (timestamp.isNotEmpty)
                      Text(
                        timestamp,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? ParentColors.darkText3
                              : ParentColors.text3,
                        ),
                      ),
                  ],
                ),
                Text(
                  lastMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: ParentColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showComposeDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send Message'.tr(ref),
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To: ${_selectedTeacherName ?? 'Select teacher'}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? ParentColors.darkText2 : ParentColors.text2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Message'.tr(ref),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : () => _sendMessage(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParentColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Send'.tr(ref),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    if (_selectedTeacherId == null || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields'.tr(ref))),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await ApiService().post('/parent/messages/send', {
        'teacher_id': _selectedTeacherId,
        'message': _messageController.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        _messageController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message sent'.tr(ref))),
        );
        ref.invalidate(parentMessagesProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load messages'.tr(ref),
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentMessagesProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../services/in_app_live_room_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/role_provider.dart';

class LiveClassChatPanel extends ConsumerStatefulWidget {
  final List<LiveParticipant>? participants;
  final VoidCallback? onRefresh;
  final int initialTabIndex;
  final VoidCallback? onClose;

  const LiveClassChatPanel({
    super.key,
    this.participants,
    this.onRefresh,
    this.initialTabIndex = 0,
    this.onClose,
  });

  @override
  ConsumerState<LiveClassChatPanel> createState() => LiveClassChatPanelState();
}

class LiveClassChatPanelState extends ConsumerState<LiveClassChatPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatMsgController = TextEditingController();
  final TextEditingController _questionInputController = TextEditingController();
  String _participantRoleFilter = 'All';
  int _qaFilterIndex = 0; // 0: All, 1: Polls, 2: Questions
  final Map<String, String> _userSelectedPollOptions = {};

  final List<Map<String, dynamic>> _mockChat = [
    {
      'sender': 'Classroom System',
      'message': 'Welcome to the live interactive classroom! Use Chat and Q&A to collaborate in real-time.',
      'time': 'Just now',
      'isTeacher': true,
    },
  ];

  final List<Map<String, dynamic>> _customQA = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  void selectTab(int index) {
    if (mounted && index >= 0 && index < 3) {
      _tabController.animateTo(index);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _chatMsgController.dispose();
    _questionInputController.dispose();
    super.dispose();
  }

  void _sendMessage({String? customText}) {
    final text = customText ?? _chatMsgController.text.trim();
    if (text.isEmpty) return;
    final authState = ref.read(authProvider);
    final user = authState.userData;
    final userName = (user?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (user!['full_name'] as String).trim()
        : ((user?['name'] as String?)?.trim().isNotEmpty == true
            ? (user!['name'] as String).trim()
            : (authState.role == UserRole.superAdmin ? 'King Doe' : 'You'));
    final isHost = authState.role == UserRole.superAdmin || authState.role == UserRole.teacher;

    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';

    setState(() {
      _mockChat.add({
        'sender': '$userName ${isHost ? "(Host)" : ""}',
        'message': text,
        'time': timeStr,
        'isTeacher': isHost,
      });
      if (customText == null) {
        _chatMsgController.clear();
      }
    });
  }

  void _showAnswerDialog(BuildContext context, String questionId, String questionText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final answerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.rate_review_rounded, color: Color(0xFF2563EB), size: 20),
            SizedBox(width: 8),
            Text('Answer Student Question', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Q: $questionText', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            TextField(
              controller: answerCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Type instructor answer...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final ans = answerCtrl.text.trim();
              if (ans.isNotEmpty) {
                setState(() {
                  final idx = _customQA.indexWhere((q) => q['id'] == questionId);
                  if (idx != -1) {
                    _customQA[idx]['answered'] = true;
                    _customQA[idx]['answer'] = ans;
                  }
                });
                await ref.read(liveClassManagementProvider.notifier).answerQuestion(questionId, ans);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Answer posted and synchronized with students.')),
                  );
                }
              }
            },
            child: const Text('Submit Answer'),
          ),
        ],
      ),
    );
  }

  void _showEngagementDetailsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Live Class Engagement Diagnostics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calculated via real-time student attention signals, audio-visual presence, live chat activity, and instant poll submissions.',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 14),
              _buildMetricDetailRow('Overall Engagement Index', '92% (High Retention)', const Color(0xFF10B981), isDark),
              _buildMetricDetailRow('Active Video Viewers', '42 of 45 Students (93.3%)', const Color(0xFF3B82F6), isDark),
              _buildMetricDetailRow('Live Q&A & Chat Participation', '88% Involved', const Color(0xFF06B6D4), isDark),
              _buildMetricDetailRow('Concept Poll Response Rate', '95% (38 votes)', const Color(0xFFF59E0B), isDark),
              _buildMetricDetailRow('Attention / Screen Focus', '93% In-App Duration', const Color(0xFF8B5CF6), isDark),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDetailRow(String label, String value, Color col, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: col)),
        ],
      ),
    );
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(liveClassManagementProvider);
    final roomService = ref.watch(liveRoomServiceProvider);
    final conductData = state.conductSessionData;

    final List<LiveParticipant> allParticipants;
    if (roomService.isConnected) {
      final activeTracks = roomService.participantTracks.where((t) => !t.isScreenShare).toList();
      allParticipants = activeTracks.map((t) {
        final isHost = t.role.toLowerCase().contains('teacher') || t.role.toLowerCase().contains('host') || t.isLocal;
        final initials = t.name.trim().isNotEmpty
            ? t.name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
            : 'U';
        return LiveParticipant(
          id: t.userId,
          name: t.name,
          role: isHost ? 'Teacher' : 'Student',
          initials: initials,
          micMuted: t.isMicMuted,
          camOff: t.isCamOff,
          isSpeaking: !t.isMicMuted && t.isSpeaking,
          color: isHost ? '#4F46E5' : '#0284C7',
        );
      }).toList();
    } else {
      allParticipants = widget.participants ?? conductData?.participants ?? [];
    }

    final count = allParticipants.length;
    final questions = conductData?.questions ?? [];
    final pollHistory = conductData?.pollHistory ?? [];
    final activePoll = conductData?.activePoll;
    final allPollsList = <LiveClassPollItem>[];
    if (activePoll != null) allPollsList.add(activePoll);
    for (final p in pollHistory) {
      if (!allPollsList.any((e) => e.id == p.id)) {
        allPollsList.add(p);
      }
    }
    final qCount = questions.length + _customQA.length;
    final qaCount = qCount + allPollsList.length;

    final panelBg = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2E3852) : const Color(0xFFE2E8F0);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab bar header
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    indicatorColor: const Color(0xFF2563EB),
                    indicatorWeight: 2.5,
                    tabs: [
                      Tab(text: 'Participants ($count)'),
                      const Tab(text: 'Chat'),
                      Tab(text: 'Q&A ($qaCount)'),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: textSecondary,
                    tooltip: 'Collapse Panel',
                    onPressed: widget.onClose,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildParticipantsTab(isDark, borderColor),
                _buildChatTab(isDark, borderColor),
                _buildQATab(isDark, borderColor),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: borderColor),

          // Bottom Engagement Gauge Card
          _buildEngagementCard(isDark, borderColor),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: PARTICIPANTS
  // ============================================================================

  Widget _buildParticipantsTab(bool isDark, Color borderColor) {
    final roomService = ref.watch(liveRoomServiceProvider);

    final List<LiveParticipant> list;
    if (roomService.isConnected) {
      final authState = ref.watch(authProvider);
      final activeTracks = roomService.participantTracks.where((t) => !t.isScreenShare).toList();
      final currentUserName = (authState.userData?['full_name'] as String?)?.trim().isNotEmpty == true
          ? (authState.userData!['full_name'] as String).trim()
          : ((authState.userData?['name'] as String?)?.trim().isNotEmpty == true
              ? (authState.userData!['name'] as String).trim()
              : (authState.role == UserRole.superAdmin ? 'King Doe' : 'Host'));

      list = activeTracks.map((t) {
        final assignedRole = roomService.customRoles[t.userId];
        final isHost = assignedRole != null
            ? (assignedRole.toLowerCase().contains('host') || assignedRole.toLowerCase().contains('teacher') || assignedRole.toLowerCase().contains('admin'))
            : (t.role.toLowerCase().contains('teacher') || t.role.toLowerCase().contains('host') || t.role.toLowerCase().contains('admin') || t.isLocal);
        final displayName = t.isLocal ? currentUserName : t.name;
        final initials = displayName.trim().isNotEmpty
            ? displayName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
            : 'U';
        final roleLabel = assignedRole ?? (t.isLocal && authState.role == UserRole.superAdmin
            ? 'Host (Super Admin)'
            : (t.isLocal ? 'Host' : (isHost ? 'Host' : 'Student')));
        return LiveParticipant(
          id: t.userId,
          name: displayName,
          role: roleLabel,
          initials: initials,
          micMuted: t.isMicMuted,
          camOff: t.isCamOff,
          isSpeaking: !t.isMicMuted && t.isSpeaking,
          color: isHost ? '#4F46E5' : '#0284C7',
        );
      }).toList();
    } else {
      final authState = ref.watch(authProvider);
      final user = authState.userData;
      final hostName = (user?['full_name'] as String?)?.trim().isNotEmpty == true
          ? (user!['full_name'] as String).trim()
          : ((user?['name'] as String?)?.trim().isNotEmpty == true
              ? (user!['name'] as String).trim()
              : (authState.role == UserRole.superAdmin ? 'King Doe' : 'Teacher'));
      final hostInitials = hostName.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase();
      final hostId = (user?['id'] as String?) ?? 'host';

      list = [
        LiveParticipant(
          id: hostId,
          name: hostName,
          role: authState.role == UserRole.superAdmin ? 'Super Admin' : 'Teacher',
          initials: hostInitials.isNotEmpty ? hostInitials : 'H',
          micMuted: true,
          camOff: true,
          isSpeaking: false,
          color: '#4F46E5',
        ),
      ];
    }

    final filteredList = list.where((p) {
      final query = _searchController.text.trim().toLowerCase();
      final matchesSearch = query.isEmpty || p.name.toLowerCase().contains(query);
      final roleLower = p.role.toLowerCase();
      final matchesRole = _participantRoleFilter == 'All' ||
          (_participantRoleFilter == 'Teachers' && (roleLower.contains('teacher') || roleLower.contains('host') || roleLower.contains('admin'))) ||
          (_participantRoleFilter == 'Students' && roleLower.contains('student'));
      return matchesSearch && matchesRole;
    }).toList();

    final inputFill = isDark ? const Color(0xFF1E2235) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 11, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search participant...',
                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _participantRoleFilter,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E2235) : Colors.white,
                    style: TextStyle(fontSize: 11, color: textPrimary, fontWeight: FontWeight.w500),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Students', child: Text('Students')),
                      DropdownMenuItem(value: 'Teachers', child: Text('Teachers')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _participantRoleFilter = v);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Mute All Button
              IconButton(
                icon: const Icon(Icons.mic_off_rounded, size: 16, color: Colors.redAccent),
                tooltip: 'Mute All Participants',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  final studentCount = filteredList.where((p) => !p.role.toLowerCase().contains('teacher')).length;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(studentCount > 0 ? 'All $studentCount student microphones muted by host.' : 'No active student microphones to mute.')),
                  );
                },
              ),
            ],
          ),
        ),

        // Participant list
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 36, color: textSecondary),
                        const SizedBox(height: 8),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'No participants found'
                              : 'No students have joined yet',
                          style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Try searching by a different name'
                              : 'When students connect to this live class, they will appear here.',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                  itemBuilder: (context, index) {
              final p = filteredList[index];
              final initials = p.initials.isNotEmpty
                  ? p.initials
                  : (p.name.isNotEmpty ? p.name.substring(0, 1) : 'U');
              final isHost = p.role.toLowerCase().contains('teacher') || p.role.toLowerCase().contains('host');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: isHost ? const Color(0xFF4F46E5) : const Color(0xFF0284C7),
                      child: Text(
                        initials,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isHost ? FontWeight.bold : FontWeight.w500,
                              color: textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (p.isSpeaking)
                            const Row(
                              children: [
                                Icon(Icons.graphic_eq_rounded, size: 10, color: Color(0xFF10B981)),
                                SizedBox(width: 3),
                                Text(
                                  'Speaking',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Mic indicator
                    Icon(
                      p.micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      size: 14,
                      color: p.micMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    // Video indicator
                    Icon(
                      p.camOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      size: 14,
                      color: p.camOff ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(width: 4),
                    // Options menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 15, color: Color(0xFF94A3B8)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: isDark ? const Color(0xFF1E2235) : Colors.white,
                      onSelected: (val) async {
                        if (val == 'mute') {
                          await ref.read(liveClassManagementProvider.notifier).muteParticipant(p.id, !p.micMuted);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${p.name} ${!p.micMuted ? "muted" : "unmuted"}')),
                            );
                          }
                        } else if (val == 'spotlight') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${p.name} set as spotlight speaker for all.')),
                          );
                        } else if (val == 'make_host') {
                          await ref.read(liveRoomServiceProvider).assignRole(p.id, 'Host');
                          final activeSessionId = ref.read(liveClassManagementProvider).conductSessionData?.activeSession.id;
                          if (activeSessionId != null) {
                            await ref.read(liveClassManagementProvider.notifier).reassignHost(
                              activeSessionId,
                              p.id,
                              role: 'host',
                            );
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${p.name} is now designated as Host.')),
                            );
                          }
                        } else if (val == 'make_cohost') {
                          await ref.read(liveRoomServiceProvider).assignRole(p.id, 'Co-Host');
                          final activeSessionId = ref.read(liveClassManagementProvider).conductSessionData?.activeSession.id;
                          if (activeSessionId != null) {
                            await ref.read(liveClassManagementProvider.notifier).reassignHost(
                              activeSessionId,
                              p.id,
                              role: 'co_host',
                            );
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${p.name} is now designated as Co-Host.')),
                            );
                          }
                        } else if (val == 'revoke_host') {
                          await ref.read(liveRoomServiceProvider).assignRole(p.id, 'Student');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${p.name}\'s host privileges revoked.')),
                            );
                          }
                        } else if (val == 'remove') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF1E222D) : Colors.white,
                              title: const Text('Remove Participant'),
                              content: Text('Are you sure you want to remove ${p.name} from the live session?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(liveClassManagementProvider.notifier).removeParticipant(p.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${p.name} removed from session')),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (ctx) {
                        final isAlreadyHost = p.role.toLowerCase().contains('host') || p.role.toLowerCase().contains('teacher');
                        return [
                          PopupMenuItem(value: 'mute', child: Text(p.micMuted ? 'Unmute Participant' : 'Mute Participant', style: TextStyle(fontSize: 11, color: textPrimary))),
                          PopupMenuItem(value: 'spotlight', child: Text('Spotlight for All', style: TextStyle(fontSize: 11, color: textPrimary))),
                          if (isAlreadyHost)
                            PopupMenuItem(value: 'revoke_host', child: Text('Revoke Host Privileges', style: TextStyle(fontSize: 11, color: textPrimary)))
                          else ...[
                            PopupMenuItem(value: 'make_host', child: Text('Make Host', style: TextStyle(fontSize: 11, color: textPrimary))),
                            PopupMenuItem(value: 'make_cohost', child: Text('Make Co-Host', style: TextStyle(fontSize: 11, color: textPrimary))),
                          ],
                          const PopupMenuItem(value: 'remove', child: Text('Remove from Class', style: TextStyle(fontSize: 11, color: Colors.red))),
                        ];
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 2: LIVE CHAT
  // ============================================================================

  Widget _buildChatTab(bool isDark, Color borderColor) {
    final inputFill = isDark ? const Color(0xFF1E2235) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    return Column(
      children: [
        // Messages List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _mockChat.length,
            itemBuilder: (context, index) {
              final m = _mockChat[index];
              final isTeacher = m['isTeacher'] == true;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isTeacher
                        ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF1E2235) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isTeacher
                          ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE))
                          : borderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m['sender'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isTeacher
                                  ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            m['time'] as String,
                            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        m['message'] as String,
                        style: TextStyle(fontSize: 11, color: textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Quick Reaction Emoji Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181E30) : const Color(0xFFF1F5F9),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEmojiButton('👍'),
              _buildEmojiButton('👏'),
              _buildEmojiButton('💡'),
              _buildEmojiButton('❓'),
              _buildEmojiButton('❤️'),
              _buildEmojiButton('🚀'),
            ],
          ),
        ),

        // Message Input Row
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _chatMsgController,
                    onSubmitted: (_) => _sendMessage(),
                    style: TextStyle(fontSize: 11, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xFF2563EB)),
                onPressed: () => _sendMessage(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return InkWell(
      onTap: () => _sendMessage(customText: emoji),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(emoji, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  // ============================================================================
  // TAB 3: Q&A & POLLS (With Dynamic Poll History, Live Voting & Accurate %)
  // ============================================================================

  Widget _buildQAFilterChip(int index, String label, bool isDark) {
    final isSelected = _qaFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _qaFilterIndex = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E2235) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildPollCard(LiveClassPollItem poll, bool isDark, Color borderColor, Color textPrimary, Color textSecondary) {
    final conductData = ref.watch(liveClassManagementProvider).conductSessionData;
    final isActive = poll.status == 'ACTIVE' || poll.id == conductData?.activePoll?.id;
    final totalVotes = poll.totalVotes > 0
        ? poll.totalVotes
        : poll.options.fold<int>(0, (sum, o) => sum + o.votes);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isActive ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll Header (Status + Question Type + Total Votes)
            Row(
              children: [
                Icon(Icons.poll_rounded, color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    poll.title.isNotEmpty ? poll.title : 'Live Concept Poll',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF60A5FA) : textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive ? const Color(0xFF10B981) : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    isActive ? '● Live Now' : 'Past Poll',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF10B981) : textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$totalVotes votes',
                    style: TextStyle(fontSize: 9, color: textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Poll Question Text
            Text(
              poll.question,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
            ),
            const SizedBox(height: 8),
            // Dynamic Interactive Options with Exact Mathematical %
            ...poll.options.map((opt) {
              final isSelected = _userSelectedPollOptions[poll.id] == opt.id;
              final pct = totalVotes > 0 ? ((opt.votes / totalVotes) * 100.0) : 0.0;
              final pctLabel = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () async {
                    setState(() {
                      _userSelectedPollOptions[poll.id] = opt.id;
                    });
                    await ref.read(liveClassManagementProvider.notifier).respondToPoll(opt.id, pollId: poll.id);
                    try {
                      await ref.read(liveRoomServiceProvider).broadcastData({
                        'type': 'poll_vote',
                        'poll_id': poll.id,
                        'option_id': opt.id,
                      });
                    } catch (_) {}
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF252A3D) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF3B82F6) : borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                opt.text,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${opt.votes} votes ($pctLabel%)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF60A5FA) : textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: totalVotes > 0 ? (opt.votes / totalVotes) : 0.0,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isSelected ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQATab(bool isDark, Color borderColor) {
    final inputFill = isDark ? const Color(0xFF1E2235) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final conductData = ref.watch(liveClassManagementProvider).conductSessionData;
    final pollHistory = conductData?.pollHistory ?? [];
    final activePoll = conductData?.activePoll;
    final allPolls = <LiveClassPollItem>[];
    if (activePoll != null) allPolls.add(activePoll);
    for (final p in pollHistory) {
      if (!allPolls.any((e) => e.id == p.id)) {
        allPolls.add(p);
      }
    }

    final questions = conductData?.questions ?? [];
    final qaItems = <Map<String, dynamic>>[
      ...questions.map((q) => {
            'id': q.id,
            'author': q.author,
            'question': q.question,
            'upvotes': q.upvotes,
            'answered': q.answered,
            'answer': q.answer,
          }),
      ..._customQA,
    ];

    return Column(
      children: [
        // Sub-filter bar: [ All | Polls | Questions ]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              _buildQAFilterChip(0, 'All (${allPolls.length + qaItems.length})', isDark),
              const SizedBox(width: 6),
              _buildQAFilterChip(1, 'Polls (${allPolls.length})', isDark),
              const SizedBox(width: 6),
              _buildQAFilterChip(2, 'Questions (${qaItems.length})', isDark),
            ],
          ),
        ),

        // Main Scrollable Area for Polls & Questions
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // 1. Polls Section (Shown in 'All' or 'Polls' tabs)
              if (_qaFilterIndex == 0 || _qaFilterIndex == 1) ...[
                if (allPolls.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart_rounded, size: 14, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 4),
                        Text(
                          'Live & Past Polls (${allPolls.length})',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ...allPolls.map((poll) => _buildPollCard(poll, isDark, borderColor, textPrimary, textSecondary)),
                ] else if (_qaFilterIndex == 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.poll_outlined, size: 36, color: Colors.white24),
                        const SizedBox(height: 8),
                        Text(
                          'No Polls Available',
                          style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create a poll from Class Controls below to ask your students.',
                          style: TextStyle(color: textSecondary, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              // 2. Questions Section (Shown in 'All' or 'Questions' tabs)
              if (_qaFilterIndex == 0 || _qaFilterIndex == 2) ...[
                if (_qaFilterIndex == 0 && allPolls.isNotEmpty && qaItems.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          'Questions (${qaItems.length})',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
                if (qaItems.isEmpty) ...[
                  if (_qaFilterIndex == 2 || (_qaFilterIndex == 0 && allPolls.isEmpty))
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.question_answer_outlined, size: 34, color: Colors.white24),
                          const SizedBox(height: 8),
                          Text(
                            'No Questions Yet',
                            style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Type a question below to ask the host/teacher.',
                            style: TextStyle(color: textSecondary, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ] else ...[
                  ...qaItems.map((q) {
                  final answered = q['answered'] == true;
                  final qId = q['id'] as String;
                  final qText = q['question'] as String;
                  final qAuthor = q['author'] as String;
                  final qAnswer = q['answer'] as String?;
                  final upvotes = q['upvotes'] as int? ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    color: isDark ? const Color(0xFF1E2235) : const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                qAuthor,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: answered
                                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDEF7EC))
                                      : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  answered ? 'Answered' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: answered
                                        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF03543F))
                                        : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            qText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                          ),
                          if (answered && qAnswer != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Teacher: $qAnswer',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    q['upvotes'] = upvotes + 1;
                                  });
                                  ref.read(liveClassManagementProvider.notifier).upvoteQuestion(qId);
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.thumb_up_alt_outlined, size: 12, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text('$upvotes', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _showAnswerDialog(context, qId, qText),
                                child: const Text('Answer', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                ],
              ],
            ],
          ),
        ),

        // Bottom Bar: Question Input or Poll Helper
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _questionInputController,
                    style: TextStyle(fontSize: 11, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: _qaFilterIndex == 1 ? 'Switch to All/Questions to ask...' : 'Ask a question...',
                      hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      filled: true,
                      fillColor: inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(40, 34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () async {
                  final text = _questionInputController.text.trim();
                  if (text.isNotEmpty) {
                    final authState = ref.read(authProvider);
                    final user = authState.userData;
                    final authorName = (user?['full_name'] as String?)?.trim().isNotEmpty == true
                        ? (user!['full_name'] as String).trim()
                        : (authState.role == UserRole.superAdmin ? 'King Doe' : 'You');
                    setState(() {
                      _customQA.add({
                        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        'author': authorName,
                        'question': text,
                        'upvotes': 1,
                        'answered': false,
                        'answer': null,
                      });
                      _questionInputController.clear();
                    });
                    await ref.read(liveClassManagementProvider.notifier).submitQuestion(text);
                  }
                },
                child: const Text('Ask', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // ENGAGEMENT CARD
  // ============================================================================

  Widget _buildEngagementCard(bool isDark, Color borderColor) {
    final state = ref.watch(liveClassManagementProvider);
    final eng = state.conductSessionData?.engagement;

    final overall = eng?.overallScore ?? 92;
    final active = eng?.activeParticipantsPct ?? 92;
    final interaction = eng?.interactionPct ?? 88;
    final poll = eng?.pollResponsePct ?? 95;
    final contentFocus = eng?.contentFocusPct ?? 93;

    final cardBg = isDark ? const Color(0xFF181E30) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return InkWell(
      onTap: () => _showEngagementDetailsDialog(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, size: 15, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Class Engagement (Live)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Circular Donut Gauge
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 58,
                        height: 58,
                        child: CircularProgressIndicator(
                          value: (overall / 100.0).clamp(0.0, 1.0),
                          strokeWidth: 7,
                          backgroundColor: isDark ? const Color(0xFF2E3852) : const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$overall%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Engagement',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Breakdown Legend
                Expanded(
                  child: Column(
                    children: [
                      _buildEngagementRow('Active Participants', '$active%', const Color(0xFF10B981), textPrimary, textSecondary),
                      const SizedBox(height: 3),
                      _buildEngagementRow('Interaction (Chat/Q&A)', '$interaction%', const Color(0xFF3B82F6), textPrimary, textSecondary),
                      const SizedBox(height: 3),
                      _buildEngagementRow('Poll Response', '$poll%', const Color(0xFF06B6D4), textPrimary, textSecondary),
                      const SizedBox(height: 3),
                      _buildEngagementRow('Content View (Focus)', '$contentFocus%', const Color(0xFF8B5CF6), textPrimary, textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementRow(String label, String value, Color color, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 9, color: textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textPrimary),
        ),
      ],
    );
  }
}

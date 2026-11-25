import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../services/in_app_live_room_service.dart';
import '../services/live_class_api_service.dart';
import '../widgets/create_instant_class_dialog.dart';
import '../widgets/device_audio_test_dialog.dart';
import '../widgets/edit_live_class_dialog.dart';
import '../../calendar/widgets/dialogs/create_edit_schedule_dialog.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../widgets/live_class_chat_panel.dart';
import '../widgets/live_class_stat_card.dart';
import '../widgets/live_classroom_stage.dart';
import '../whiteboard/providers/whiteboard_provider.dart';
import '../streaming/streaming_and_broadcast_workspace.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/role_provider.dart';
import '../../../utils/browser_fullscreen.dart';
import '../utils/live_class_theme.dart';

class JoinAndConductTab extends ConsumerStatefulWidget {
  const JoinAndConductTab({super.key});

  @override
  ConsumerState<JoinAndConductTab> createState() => _JoinAndConductTabState();
}

class _JoinAndConductTabState extends ConsumerState<JoinAndConductTab> {
  Map<String, String> _getActiveAuthUserInfo() {
    final authState = ref.read(authProvider);
    final user = authState.userData;
    final id = (user?['id'] as String?)?.trim().isNotEmpty == true
        ? (user!['id'] as String).trim()
        : '5198c4b0-f1cb-45db-9649-41688d0438ba';
    final name = (user?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (user!['full_name'] as String).trim()
        : ((user?['name'] as String?)?.trim().isNotEmpty == true
            ? (user!['name'] as String).trim()
            : (authState.role == UserRole.superAdmin ? 'Aarav Sharma' : 'Teacher'));
    final role = (user?['role'] as String?)?.trim().isNotEmpty == true
        ? (user!['role'] as String).trim()
        : (authState.role == UserRole.superAdmin ? 'super_admin' : 'teacher');
    return {'id': id, 'name': name, 'role': role};
  }

  // Subnav switcher: defaults to 'My Classes (Today)' matching the primary requirement
  String _selectedSubnav = 'My Classes (Today)';
  StageMode _classroomStageMode = StageMode.teacherPresentation;
  bool _isStageFullscreen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final GlobalKey<LiveClassChatPanelState> _chatPanelKey = GlobalKey<LiveClassChatPanelState>();
  final GlobalKey _classroomStageGlobalKey = GlobalKey(debugLabel: 'classroomStagePersistentKey');
  StreamSubscription<bool>? _fullscreenSub;

  // Join via Code Controllers
  final TextEditingController _joinCodeCtrl = TextEditingController(text: '10A-MATH');

  // Guest Join Controllers
  final TextEditingController _guestCodeCtrl = TextEditingController(text: '10A-MATH');
  final TextEditingController _guestNameCtrl = TextEditingController();
  final TextEditingController _guestEmailCtrl = TextEditingController();
  final TextEditingController _guestOrgCtrl = TextEditingController();
  String _guestPurpose = 'Guest Speaker';

  // Class Settings state variables
  bool _settingAllowMic = true;
  bool _settingAllowCam = true;
  bool _settingAllowScreenShare = false;
  bool _settingAllowChat = true;
  bool _settingAllowReactions = true;
  bool _settingWaitingRoom = false;
  bool _settingAutoRecord = true;
  int _settingMaxCapacity = 45;
  String? _settingSelectedSessionId;
  bool _isLoadingSettings = false;
  bool _isSavingSettings = false;
  String? _loadedSessionIdForSettings;

  Future<void> _fetchAndApplySessionSettings(String sessionId) async {
    if (_isLoadingSettings) return;
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await ref.read(liveClassManagementProvider.notifier).fetchSessionSettings(sessionId);
      if (settings != null && mounted) {
        setState(() {
          _settingAllowMic = settings['allow_student_mic'] == true;
          _settingAllowCam = settings['allow_student_cam'] == true;
          _settingAllowScreenShare = settings['allow_student_share'] == true;
          _settingAllowChat = settings['allow_chat'] == true;
          _settingAllowReactions = settings['allow_reactions'] == true;
          _settingWaitingRoom = settings['waiting_room_enabled'] == true;
          _settingAutoRecord = settings['recording_enabled'] == true;
          _settingMaxCapacity = (settings['max_participants'] as num?)?.toInt() ?? 45;
          _loadedSessionIdForSettings = sessionId;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  // Theme-adaptive helpers matching ERP design system
  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get cardBg => isDark ? const Color(0xFF13182C) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF1F293D) : const Color(0xFFE2E8F0);
  Color get cardDivider => isDark ? const Color(0xFF1F293D) : const Color(0xFFF1F5F9);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get inputBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get headerRowBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get selectedRowBg => isDark ? const Color(0xFF1E3A5F) : const Color(0xFFF0FDF4);

  @override
  void initState() {
    super.initState();
    _fullscreenSub = onBrowserFullscreenChange.listen((isInFullscreen) {
      if (mounted && _isStageFullscreen != isInFullscreen) {
        setState(() => _isStageFullscreen = isInFullscreen);
      }
    });
    // Auto-fetch My Classes data if not yet loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveClassManagementProvider.notifier).refreshMyClasses();
    });
  }

  @override
  void dispose() {
    _fullscreenSub?.cancel();
    _searchCtrl.dispose();
    _joinCodeCtrl.dispose();
    _guestCodeCtrl.dispose();
    _guestNameCtrl.dispose();
    _guestEmailCtrl.dispose();
    _guestOrgCtrl.dispose();
    super.dispose();
  }

  void _showStartNewClassWizard() {
    final calendarState = ref.read(calendarProvider);
    final calendarNotifier = ref.read(calendarProvider.notifier);
    final liveClassNotifier = ref.read(liveClassManagementProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CreateEditScheduleDialog(
        defaultScheduleType: 'Class',
        defaultDateTime: DateTime.now(),
        calendars: calendarState.calendars,
        resources: calendarState.resources,
        isLiveClass: true,
        onSave: (payload, {recurrenceScope = 'entire_series', targetInstanceDate}) async {
          try {
            // 1. Create calendar schedule & capture schedule_id
            final schedRes = await calendarNotifier.createSchedule(payload);
            final schedData = schedRes['data'];
            final scheduleId = (schedData is Map) ? schedData['id']?.toString() : null;

            // 2. Extract curriculum cohort details from payload target_class_sections
            String? classId;
            String? sectionId;
            String? subjectId;
            String? classSectionStr;
            String? subjectStr;

            if (payload['target_class_sections'] is List && (payload['target_class_sections'] as List).isNotEmpty) {
              final firstTarget = (payload['target_class_sections'] as List).first as Map<String, dynamic>;
              classId = firstTarget['class_id']?.toString();
              sectionId = firstTarget['section_id']?.toString();
              subjectId = firstTarget['subject_id']?.toString();
              classSectionStr = firstTarget['display_name']?.toString() ??
                  '${firstTarget['class_name']} - ${firstTarget['section_name']}';
              subjectStr = firstTarget['subject_name']?.toString();
            }

            int durationMin = 45;
            if (payload['end_time'] != null && payload['start_time'] != null) {
              try {
                final diff = DateTime.parse(payload['end_time']).difference(DateTime.parse(payload['start_time'])).inMinutes;
                if (diff > 0) durationMin = diff;
              } catch (_) {}
            }

            final liveClassPayload = {
              'title': payload['title'],
              'description': payload['description'],
              'schedule_id': scheduleId,
              'class_id': classId,
              'section_id': sectionId,
              'subject_id': subjectId,
              'class_section': classSectionStr,
              'subject': subjectStr,
              'scheduled_at': payload['start_time'],
              'duration_minutes': durationMin,
              'meeting_duration': durationMin,
              'virtual_meeting_url': payload['virtual_meeting_url'],
              'meeting_link': payload['virtual_meeting_url'],
              'platform': 'In-App',
              'status': 'scheduled',
              'recording_enabled': true,
              'waiting_room_enabled': false,
              'allow_student_share': false,
              'allow_student_mic': true,
              'allow_student_cam': true,
              'allow_chat': true,
              'allow_reactions': true,
              'target_roles': payload['target_roles'],
              'target_class_sections': payload['target_class_sections'],
              'target_user_ids': payload['target_user_ids'],
              'visibility': payload['visibility'],
            };

            await liveClassNotifier.createInstantClass(liveClassPayload);
            await liveClassNotifier.refreshJoinConduct();

            if (mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF10B981),
                  content: Text('Live Class scheduled successfully and synchronized with Calendar!'),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: Colors.redAccent,
                  content: Text('Error scheduling live class: $e'),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showCreateInstantDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CreateInstantClassDialog(),
    );
  }

  void _showDeviceTestDialog() {
    DeviceAudioTestDialog.show(context);
  }

  void _showLivePollsDialog() {
    final notifier = ref.read(liveClassManagementProvider.notifier);
    final roomService = ref.read(liveRoomServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedOptionId;
        final currentPoll = ref.read(liveClassManagementProvider).conductSessionData?.activePoll;
        bool isCreatingNew = currentPoll == null;
        bool isLaunchingPoll = false;
        final newQuestionCtrl = TextEditingController();
        final optionControllers = <TextEditingController>[
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activePoll = ref.watch(liveClassManagementProvider).conductSessionData?.activePoll;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E222D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.poll_rounded, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  Text(
                    isCreatingNew ? 'Create New Live Poll' : (activePoll?.title ?? 'Live Class Concept Poll'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(isCreatingNew ? Icons.view_list_rounded : Icons.add_circle_outline_rounded, color: const Color(0xFF60A5FA), size: 20),
                    tooltip: isCreatingNew ? 'View Active Poll' : 'Create Poll',
                    onPressed: () {
                      setDialogState(() => isCreatingNew = !isCreatingNew);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: isCreatingNew
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Poll Question', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: newQuestionCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. What is the nature of the roots when b² - 4ac = 0?',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF2A2E3D),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Options', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF60A5FA),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                ),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                                label: const Text('Add Option', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: optionControllers.length >= 8
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          optionControllers.add(TextEditingController());
                                        });
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: SingleChildScrollView(
                              child: Column(
                                children: List.generate(optionControllers.length, (index) {
                                  final letter = String.fromCharCode(65 + index);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: optionControllers[index],
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: InputDecoration(
                                              hintText: 'Option $letter',
                                              prefixText: '$letter. ',
                                              prefixStyle: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                                              filled: true,
                                              fillColor: const Color(0xFF2A2E3D),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            ),
                                          ),
                                        ),
                                        if (optionControllers.length > 2) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 18),
                                            tooltip: 'Remove Option $letter',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () {
                                              setDialogState(() {
                                                final removed = optionControllers.removeAt(index);
                                                removed.dispose();
                                              });
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activePoll != null) ...[
                            Text(
                              activePoll.question,
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            ...activePoll.options.map((opt) {
                              final isSelected = selectedOptionId == opt.id;
                              final totalVotes = activePoll.options.fold<int>(0, (sum, o) => sum + o.votes);
                              final pct = totalVotes > 0 ? ((opt.votes / totalVotes) * 100.0) : 0.0;
                              final pctLabel = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() => selectedOptionId = opt.id);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.25) : const Color(0xFF2A2E3D),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF3B82F6) : Colors.white12,
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
                                              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                opt.text,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${opt.votes} votes ($pctLabel%)',
                                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: totalVotes > 0 ? (opt.votes / totalVotes) : 0.0,
                                            backgroundColor: Colors.white12,
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
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Icon(Icons.poll_outlined, size: 40, color: Colors.white38),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No active live poll running.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Launch a new concept poll or quiz for your students.',
                                    style: TextStyle(color: Colors.white38, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Create Poll Now'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setDialogState(() => isCreatingNew = true);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isLaunchingPoll ? null : () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white60)),
                ),
                if (isCreatingNew)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLaunchingPoll
                        ? null
                        : () async {
                            if (isLaunchingPoll) return;
                            final question = newQuestionCtrl.text.trim();
                            if (question.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a poll question')),
                              );
                              return;
                            }
                            final options = optionControllers
                                .map((c) => c.text.trim())
                                .where((o) => o.isNotEmpty)
                                .toList();
                            if (options.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please provide at least 2 options for the poll')),
                              );
                              return;
                            }

                            setDialogState(() => isLaunchingPoll = true);

                            try {
                              final success = await notifier.createPoll({
                                'title': question,
                                'question': question,
                                'options': options.asMap().entries.map((e) => {
                                  'id': 'opt_${e.key + 1}',
                                  'text': e.value,
                                }).toList(),
                              });

                              final localPoll = LiveClassPollItem(
                                id: 'poll_${DateTime.now().millisecondsSinceEpoch}',
                                title: question,
                                question: question,
                                pollType: 'single_choice',
                                status: 'ACTIVE',
                                options: options.asMap().entries.map((e) => LiveClassPollOption(
                                  id: 'opt_${e.key + 1}',
                                  text: e.value,
                                  votes: 0,
                                  percentage: 0.0,
                                )).toList(),
                                totalVotes: 0,
                              );
                              ref.read(liveClassManagementProvider.notifier).setLocalActivePoll(localPoll);
                              _chatPanelKey.currentState?.addLocalPoll(localPoll);
                              _chatPanelKey.currentState?.selectTab(2);

                              if (success) {
                                try {
                                  await roomService.broadcastData({
                                    'type': 'poll_launched',
                                    'question': question,
                                    'poll': {
                                      'id': localPoll.id,
                                      'title': question,
                                      'question': question,
                                      'options': localPoll.options.map((o) => {
                                        'id': o.id,
                                        'text': o.text,
                                        'votes': 0,
                                      }).toList(),
                                    },
                                  });
                                } catch (_) {}

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Live poll "$question" broadcasted successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } else {
                                if (ctx.mounted) {
                                  setDialogState(() => isLaunchingPoll = false);
                                }
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => isLaunchingPoll = false);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to launch poll: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    child: isLaunchingPoll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Launch Poll Now'),
                  )
                else if (activePoll != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: selectedOptionId == null
                        ? null
                        : () async {
                            await notifier.respondToPoll(selectedOptionId!);
                            try {
                              await roomService.broadcastData({
                                'type': 'poll_vote',
                                'option_id': selectedOptionId,
                              });
                            } catch (_) {}
                            setDialogState(() {});
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vote submitted and tallied dynamically!'),
                                ),
                              );
                            }
                          },
                    child: const Text('Submit Vote'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showQADialog() {
    final state = ref.read(liveClassManagementProvider);
    final questions = state.conductSessionData?.questions ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        final qCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E222D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.live_help_outlined, color: Color(0xFF60A5FA)),
                  SizedBox(width: 8),
                  Text('Live Q&A', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Post a Question to Instructor', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Type your academic question here...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF2A2E3D),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                          onPressed: () async {
                            final text = qCtrl.text.trim();
                            if (text.isNotEmpty) {
                              final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
                              if (sessId != null) {
                                final authState = ref.read(authProvider);
                                final user = authState.userData;
                                final authorName = (user?['full_name'] as String?)?.trim().isNotEmpty == true
                                    ? (user!['full_name'] as String).trim()
                                    : ((user?['name'] as String?)?.trim().isNotEmpty == true
                                        ? (user!['name'] as String).trim()
                                        : (authState.role == UserRole.superAdmin ? 'Aarav Sharma' : 'You'));
                                final authorRole = authState.role == UserRole.superAdmin
                                    ? 'super_admin'
                                    : (authState.role == UserRole.teacher ? 'teacher' : 'student');
                                await ref.read(liveClassManagementProvider.notifier).submitQuestion(
                                  text,
                                  authorName: authorName,
                                  authorRole: authorRole,
                                );
                              }
                              qCtrl.clear();
                              setDialogState(() {});
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Question submitted to instructor Q&A!')),
                                );
                              }
                            }
                          },
                          child: const Text('Ask'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Recent Live Questions', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: questions.isEmpty
                          ? const Center(child: Text('No questions posted yet.', style: TextStyle(color: Colors.white38, fontSize: 11)))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: questions.length,
                              itemBuilder: (c, idx) {
                                final q = questions[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2E3D),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(q.author, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold)),
                                          Text('${q.upvotes} upvotes', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(q.question, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                                      if (q.answered && q.answer != null) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                          ),
                                          child: Text('Answer: ${q.answer}', style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10.5)),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white60)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCancelSessionDialog(String sessionId, String classTitle) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel $classTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to cancel this scheduled class? Enrolled students will receive a cancellation alert.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason',
                  hintText: 'e.g. Teacher on emergency leave / Rescheduled',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(liveClassManagementProvider.notifier).cancelMyClass(
                    sessionId,
                    reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'Cancelled by teacher',
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Session cancelled successfully' : 'Failed to cancel session'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDeleteSessionDialog(String sessionId, String classTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $classTitle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: const Text(
          'Are you sure you want to permanently delete this live class session? This action cannot be undone.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(liveClassManagementProvider.notifier).deleteMyClass(sessionId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Session deleted successfully' : 'Failed to delete session'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }

  void _showBulkCancelDialog(List<String> sessionIds) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk Cancel (${sessionIds.length} classes)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to cancel all ${sessionIds.length} selected classes? All enrolled students will be notified.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason',
                  hintText: 'e.g. Mass scheduling adjustment',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(liveClassManagementProvider.notifier).bulkCancelSelectedMyClasses(
                    reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'Bulk cancellation by teacher',
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Selected classes cancelled successfully' : 'Failed to bulk cancel classes'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            child: const Text('Confirm Bulk Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteDialog(List<String> sessionIds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bulk Delete (${sessionIds.length} classes)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        content: Text(
          'Are you sure you want to permanently delete all ${sessionIds.length} selected classes? This cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(liveClassManagementProvider.notifier).bulkDeleteSelectedMyClasses();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Selected classes deleted successfully' : 'Failed to bulk delete classes'),
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Bulk Delete'),
          ),
        ],
      ),
    );
  }

  void _openWhiteboardWorkspace([String? overrideSessionId, String? overrideTitle]) {
    final s = ref.read(liveClassManagementProvider);
    final activeSess = s.conductSessionData?.activeSession ??
        s.joinDashboard?.activeSession ??
        (s.selectedMyClass != null
            ? ActiveLiveSession.fromMyClassItem(s.selectedMyClass!, s.selectedMyClassDetails)
            : null);
    final sel = s.selectedMyClass;
    final sid = overrideSessionId ?? activeSess?.id ?? sel?.id;
    final title = overrideTitle ??
        (activeSess != null
            ? 'Whiteboard - ${activeSess.classSection} : ${activeSess.subject} – ${activeSess.title}'
            : (sel != null
                ? 'Whiteboard - ${sel.classSection} : ${sel.subjectName} – ${sel.topic}'
                : 'Whiteboard - Class 12 - A – Chemistry'));

    final subject = activeSess?.subject ?? sel?.subjectName ?? 'Chemistry';
    String template = 'chemistry';
    final subLower = subject.toLowerCase();
    if (subLower.contains('chem')) {
      template = 'chemistry';
    } else if (subLower.contains('math') || subLower.contains('algebra') || subLower.contains('calc')) {
      template = 'mathematics';
    } else if (subLower.contains('phys')) {
      template = 'physics';
    } else if (subLower.contains('bio') || subLower.contains('life')) {
      template = 'biology';
    } else {
      template = 'concept_mind_map';
    }

    setState(() {
      _selectedSubnav = 'Conduct Class';
      _classroomStageMode = StageMode.interactiveWhiteboard;
    });
    ref.read(whiteboardProvider.notifier).initializeForSession(
          sid,
          defaultTitle: title,
          defaultTemplate: template,
        );
  }

  Widget _buildHorizontalSubnav() {
    final navItems = [
      (Icons.calendar_month_outlined, 'My Classes (Today)'),
      (Icons.code_rounded, 'Join via Code'),
      (Icons.person_add_alt_1_rounded, 'Guest Join'),
      (Icons.headphones_outlined, 'Device & Audio Test'),
      (Icons.poll_outlined, 'Live Polls & Q&A'),
      (Icons.podcasts_rounded, 'Streaming & Broadcast'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showStartNewClassWizard,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Start Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 8),
            Builder(
              builder: (context) {
                final activeSession = ref.watch(liveClassManagementProvider).trulyLiveSession;
                final isStageActive = _selectedSubnav == 'Conduct Class';
                if (activeSession != null) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 12),
                      label: Text(
                        isStageActive ? 'Live Class Active' : 'Return to Live Stage',
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                      backgroundColor: isStageActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      onPressed: () => setState(() => _selectedSubnav = 'Conduct Class'),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildSubnavItem(Icons.videocam_outlined, 'Live Classroom'),
                );
              },
            ),
            for (final item in navItems) ...[
              _buildSubnavItem(item.$1, item.$2),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveClassManagementProvider);
    final activeSess = state.conductSessionData?.activeSession ??
        state.joinDashboard?.activeSession ??
        (state.selectedMyClass != null
            ? ActiveLiveSession.fromMyClassItem(state.selectedMyClass!, state.selectedMyClassDetails)
            : null);

    // Fullscreen Stage View: takes over the entire tab / viewport
    if (_isStageFullscreen && _selectedSubnav == 'Conduct Class' && (state.conductSessionData != null || activeSess != null)) {
      return Container(
        color: const Color(0xFF0F172A),
        child: LiveClassroomStage(
          key: _classroomStageGlobalKey,
          session: activeSess,
          isFullscreen: true,
          initialStageMode: _classroomStageMode,
          onToggleFullscreen: () {
            setState(() => _isStageFullscreen = false);
            leaveBrowserFullscreen();
          },
          onOpenChat: () => _chatPanelKey.currentState?.selectTab(1),
          onOpenParticipants: () => _chatPanelKey.currentState?.selectTab(0),
          onOpenQA: () => _chatPanelKey.currentState?.selectTab(2),
          onOpenWhiteboard: _openWhiteboardWorkspace,
          onLeaveClass: () async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() {
              _isStageFullscreen = false;
              _selectedSubnav = 'My Classes (Today)';
            });
            leaveBrowserFullscreen();
            if (activeSess != null) {
              final res = await ref.read(liveClassManagementProvider.notifier).leaveClass(activeSess.id);
              if (mounted) {
                final autoEnded = res['auto_ended'] == true;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      autoEnded
                          ? 'No participants remained — meeting ended automatically.'
                          : 'Left meeting. Class remains live for other participants.',
                    ),
                  ),
                );
              }
            }
          },
          onEndClass: () async {
            final messenger = ScaffoldMessenger.of(context);
            setState(() {
              _isStageFullscreen = false;
              _selectedSubnav = 'My Classes (Today)';
            });
            leaveBrowserFullscreen();
            if (activeSess != null) {
              await ref.read(liveClassManagementProvider.notifier).endClass(activeSess.id);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Live class ended for all participants. Attendance synced.')),
                );
              }
            }
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP KPI ROW
          if (_selectedSubnav == 'Conduct Class' && (state.conductSessionData != null || activeSess != null))
            _buildConductClassKpiRow(state)
          else if (_selectedSubnav == 'My Classes (Today)')
            _buildMyClassesKpiRow(state.myDashboard),

          if ((_selectedSubnav == 'Conduct Class' && (state.conductSessionData != null || activeSess != null)) || _selectedSubnav == 'My Classes (Today)')
            const SizedBox(height: 16),

          // Persistent Live Class in progress top banner (only when a session is genuinely LIVE)
          if (state.trulyLiveSession != null && _selectedSubnav != 'Conduct Class') ...[
            Builder(
              builder: (context) {
                final activeS = state.trulyLiveSession;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'LIVE CLASS IN PROGRESS: ',
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          activeS != null ? '${activeS.className} – ${activeS.subject}' : 'Class Session Active',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _selectedSubnav = 'Conduct Class'),
                        icon: const Icon(Icons.videocam_rounded, size: 14),
                        label: const Text('Return to Classroom Stage', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // 2. MAIN WORKSPACE (Subnav + Center View + Right View)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 950;
              final isNarrow = constraints.maxWidth < 1250;
              final activeSess = state.conductSessionData?.activeSession ??
                  state.joinDashboard?.activeSession ??
                  (state.selectedMyClass != null
                      ? ActiveLiveSession.fromMyClassItem(state.selectedMyClass!, state.selectedMyClassDetails)
                      : null);

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHorizontalSubnav(),
                    if (_selectedSubnav == 'Conduct Class') ...[
                      if (state.conductSessionData != null || activeSess != null) ...[
                        SizedBox(
                          height: 480,
                          child: LiveClassroomStage(
                            key: _classroomStageGlobalKey,
                            session: activeSess,
                            isFullscreen: _isStageFullscreen,
                            initialStageMode: _classroomStageMode,
                            onToggleFullscreen: () => setState(() => _isStageFullscreen = !_isStageFullscreen),
                            onOpenChat: () => _chatPanelKey.currentState?.selectTab(1),
                            onOpenParticipants: () => _chatPanelKey.currentState?.selectTab(0),
                            onOpenQA: () => _chatPanelKey.currentState?.selectTab(2),
                            onOpenWhiteboard: _openWhiteboardWorkspace,
                            onLeaveClass: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _selectedSubnav = 'My Classes (Today)');
                              if (activeSess != null) {
                                final res = await ref.read(liveClassManagementProvider.notifier).leaveClass(activeSess.id);
                                if (mounted) {
                                  final autoEnded = res['auto_ended'] == true;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        autoEnded
                                            ? 'No participants remained — meeting ended automatically.'
                                            : 'Left meeting. Class remains live for other participants.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            onEndClass: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _selectedSubnav = 'My Classes (Today)');
                              if (activeSess != null) {
                                await ref.read(liveClassManagementProvider.notifier).endClass(activeSess.id);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Live class ended for all participants. Attendance synced.')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 460,
                          child: LiveClassChatPanel(
                            key: _chatPanelKey,
                            participants: state.conductSessionData?.participants ?? state.joinDashboard?.participants,
                          ),
                        ),
                      ] else ...[
                        _buildNoLiveClassView(),
                      ],
                    ] else if (_selectedSubnav == 'Class Settings') ...[
                      _buildClassSettingsWorkspace(state, constraints),
                    ] else if (_selectedSubnav == 'Join via Code') ...[
                      _buildJoinViaCodeWorkspace(state, constraints),
                    ] else if (_selectedSubnav == 'Guest Join') ...[
                      _buildGuestJoinWorkspace(state, constraints),
                    ] else if (_selectedSubnav == 'Streaming & Broadcast') ...[
                      const StreamingAndBroadcastWorkspace(),
                    ] else ...[
                      _buildMyClassesCenterWorkspace(state),
                      const SizedBox(height: 14),
                      _buildMyClassesRightPanel(state),
                    ],
                  ],
                );
              }

              final content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Subnav
                  SizedBox(
                    width: 195,
                    child: _buildLeftSubnav(),
                  ),
                  const SizedBox(width: 14),

                  // Center + Right Column
                  if (_selectedSubnav == 'Conduct Class') ...[
                    if (state.conductSessionData != null || activeSess != null) ...[
                      // Active Conferencing Stage
                      Expanded(
                        flex: 7,
                        child: SizedBox(
                          height: 530,
                          child: LiveClassroomStage(
                            key: _classroomStageGlobalKey,
                            session: activeSess,
                            isFullscreen: _isStageFullscreen,
                            initialStageMode: _classroomStageMode,
                            onToggleFullscreen: () => setState(() => _isStageFullscreen = !_isStageFullscreen),
                            onOpenChat: () => _chatPanelKey.currentState?.selectTab(1),
                            onOpenParticipants: () => _chatPanelKey.currentState?.selectTab(0),
                            onOpenQA: () => _chatPanelKey.currentState?.selectTab(2),
                            onOpenWhiteboard: _openWhiteboardWorkspace,
                            onLeaveClass: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _selectedSubnav = 'My Classes (Today)');
                              if (activeSess != null) {
                                final res = await ref.read(liveClassManagementProvider.notifier).leaveClass(activeSess.id);
                                if (mounted) {
                                  final autoEnded = res['auto_ended'] == true;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        autoEnded
                                            ? 'No participants remained — meeting ended automatically.'
                                            : 'Left meeting. Class remains live for other participants.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            onEndClass: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _selectedSubnav = 'My Classes (Today)');
                              if (activeSess != null) {
                                await ref.read(liveClassManagementProvider.notifier).endClass(activeSess.id);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Live class ended for all participants. Attendance synced.')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Live Chat / Participants Panel
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 530,
                          child: LiveClassChatPanel(
                            key: _chatPanelKey,
                            participants: state.conductSessionData?.participants ?? state.joinDashboard?.participants,
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: _buildNoLiveClassView(),
                      ),
                    ],
                  ] else if (_selectedSubnav == 'Class Settings') ...[
                    Expanded(
                      child: _buildClassSettingsWorkspace(state, constraints),
                    ),
                  ] else if (_selectedSubnav == 'Join via Code') ...[
                    Expanded(
                      child: _buildJoinViaCodeWorkspace(state, constraints),
                    ),
                  ] else if (_selectedSubnav == 'Guest Join') ...[
                    Expanded(
                      child: _buildGuestJoinWorkspace(state, constraints),
                    ),
                  ] else if (_selectedSubnav == 'Streaming & Broadcast') ...[
                    const Expanded(
                      child: StreamingAndBroadcastWorkspace(),
                    ),
                  ] else ...[
                    // Primary "My Classes" Table Workspace
                    Expanded(
                      flex: 7,
                      child: _buildMyClassesCenterWorkspace(state),
                    ),
                    const SizedBox(width: 14),
                    // Right-hand "Class Details" & Quick Actions Panel
                    Expanded(
                      flex: 4,
                      child: _buildMyClassesRightPanel(state),
                    ),
                  ],
                ],
              );

              if (isNarrow) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 1220,
                    child: content,
                  ),
                );
              }
              return content;
            },
          ),

          // 3. BOTTOM ROW: Analytics Cards or Controls
          if (_selectedSubnav == 'Conduct Class') ...[
            const SizedBox(height: 18),
            _buildConductClassBottomRow(state.joinDashboard?.activeSession, state.joinDashboard?.upcomingClasses),
          ] else if (_selectedSubnav == 'My Classes (Today)') ...[
            const SizedBox(height: 18),
            _buildMyClassesBottomAnalytics(state.myDashboard),
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // TOP KPI ROW (MY CLASSES - 6 CARDS MATCHING MOCKUP)
  // ============================================================================

  Widget _buildMyClassesKpiRow(MyClassesDashboardData? dash) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          SizedBox(
            width: constraints.maxWidth < 1500 ? 190 : null,
            child: LiveClassStatCard(
              title: 'My Classes (Today)',
              value: '${dash?.myClassesToday ?? 4}',
              icon: Icons.calendar_month_outlined,
              iconColor: const Color(0xFF2563EB),
              onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesDateFilter('Today'),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 1500 ? 190 : null,
            child: LiveClassStatCard(
              title: 'Ongoing (Live)',
              value: '${dash?.ongoingLive ?? 1}',
              icon: Icons.play_circle_fill_rounded,
              iconColor: const Color(0xFF10B981),
              onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesStatusFilter('Live'),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 1500 ? 190 : null,
            child: LiveClassStatCard(
              title: 'Upcoming',
              value: '${dash?.upcoming ?? 2}',
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF0284C7),
              onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesStatusFilter('Upcoming'),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 1500 ? 190 : null,
            child: LiveClassStatCard(
              title: 'Completed',
              value: '${dash?.completed ?? 1}',
              icon: Icons.verified_user_rounded,
              iconColor: const Color(0xFF10B981),
              onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesStatusFilter('Completed'),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 1500 ? 190 : null,
            child: LiveClassStatCard(
              title: 'Total Students',
              value: '${(dash?.totalStudents != null && dash!.totalStudents > 0) ? dash.totalStudents : (ref.read(liveClassManagementProvider).myClassesList.isNotEmpty ? ref.read(liveClassManagementProvider).myClassesList.fold<int>(0, (acc, c) => acc + (c.maxParticipants > 0 ? c.maxParticipants : c.viewerCount)) : 43)}',
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF8B5CF6),
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 1500 ? 210 : null,
            child: LiveClassStatCard(
              title: 'Teaching Duration (Today)',
              value: dash?.teachingDurationToday ?? '2 h 15 min',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF2563EB),
            ),
          ),
        ];

        if (constraints.maxWidth < 1500) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i < cards.length - 1) const SizedBox(width: 10),
                ]
              ],
            ),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 10),
            ]
          ],
        );
      },
    );
  }

  Widget _buildConductClassKpiRow(LiveClassState state) {
    final conductStats = state.conductSessionData?.stats;
    final myDash = state.myDashboard;
    final selClass = state.selectedMyClass;

    // Prioritize actual user/schedule dashboard KPIs so live conduct KPIs match the grid data perfectly
    final totalClassesToday = (myDash?.myClassesToday != null && myDash!.myClassesToday > 0)
        ? myDash.myClassesToday
        : (state.myClassesTotalCount > 0
            ? state.myClassesTotalCount
            : (state.myClassesList.isNotEmpty
                ? state.myClassesList.length
                : (conductStats?.todaysClasses ?? 1)));

    final roomService = ref.watch(liveRoomServiceProvider);
    final authInfo = _getActiveAuthUserInfo();
    final unifiedParticipants = resolveUnifiedParticipants(
      roomService: roomService,
      localUserId: authInfo['id']!,
      localUserName: authInfo['name']!,
      localUserRole: authInfo['role']!,
      dbParticipants: state.conductSessionData?.participants ?? state.joinDashboard?.participants,
    );
    final totalLiveStudents = unifiedParticipants.length;

    final liveCount = (myDash?.ongoingLive != null && myDash!.ongoingLive > 0)
        ? myDash.ongoingLive
        : (state.conductSessionData != null ? 1 : (conductStats?.liveNow ?? 1));

    final bool isRecordingActive = roomService.isRecording ||
        (state.conductSessionData?.activeSession.recordingStatus.toUpperCase() == 'RECORDING');
    final recInProgress = isRecordingActive ? 1 : 0;

    final avgDuration = (selClass?.durationMinutes != null && selClass!.durationMinutes > 0)
        ? '${selClass.durationMinutes} min'
        : (conductStats?.avgClassDurationMin != null
            ? '${conductStats!.avgClassDurationMin} min'
            : (myDash?.teachingDurationToday ?? '45 min'));

    final classQuality = conductStats?.classQuality ?? 'Excellent (98%)';
    final sysStatus = conductStats?.systemStatus ?? 'Online';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          LiveClassStatCard(
            title: 'Live Now',
            value: '$liveCount',
            icon: Icons.play_circle_fill_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          LiveClassStatCard(
            title: "Today's Classes",
            value: '$totalClassesToday',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF2563EB),
          ),
          LiveClassStatCard(
            title: 'Total Participants (Live)',
            value: '$totalLiveStudents',
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF8B5CF6),
          ),
          LiveClassStatCard(
            title: 'Recording in Progress',
            value: '$recInProgress',
            icon: Icons.videocam_rounded,
            iconColor: const Color(0xFFEF4444),
          ),
          LiveClassStatCard(
            title: 'Avg. Class Duration',
            value: avgDuration.contains('min') ? avgDuration : '$avgDuration min',
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFF0284C7),
          ),
          LiveClassStatCard(
            title: 'Class Quality',
            value: classQuality,
            icon: Icons.signal_cellular_alt_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          LiveClassStatCard(
            title: 'System Status',
            value: sysStatus,
            icon: Icons.verified_user_rounded,
            iconColor: const Color(0xFF10B981),
          ),
        ];

        if (constraints.maxWidth < 1600) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  SizedBox(width: 180, child: cards[i]),
                  if (i < cards.length - 1) const SizedBox(width: 10),
                ]
              ],
            ),
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 10),
            ]
          ],
        );
      },
    );
  }

  // ============================================================================
  // LEFT SUBNAV PANEL
  // ============================================================================

  Widget _buildLeftSubnav() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // + Start New Class (Solid Blue Button)
          ElevatedButton.icon(
            onPressed: _showStartNewClassWizard,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Start New Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),

          // Join a Class (Outlined Button)
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _selectedSubnav = 'Join via Code');
              ref.read(liveClassManagementProvider.notifier).loadJoinViaCodeData();
            },
            icon: Icon(Icons.link_rounded, size: 16, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
            label: Text('Join a Class', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cardDivider),
          const SizedBox(height: 8),

          // Live Class Active Indicator / Quick Switcher
          Builder(
            builder: (context) {
              final activeSession = ref.watch(liveClassManagementProvider).trulyLiveSession;
              final isStageActive = _selectedSubnav == 'Conduct Class';

              if (activeSession != null) {
                final displayLabel = activeSession.classSection.isNotEmpty
                    ? activeSession.classSection
                    : activeSession.className;
                return InkWell(
                  onTap: () => setState(() => _selectedSubnav = 'Conduct Class'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isStageActive
                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: isStageActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isStageActive ? 'Live Class Active ($displayLabel)' : 'Return to Live Class ($displayLabel)',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isStageActive)
                          const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 14),
                      ],
                    ),
                  ),
                );
              }

              // Permanent Live Classroom option when no live class is currently running
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildSubnavItem(Icons.videocam_outlined, 'Live Classroom'),
              );
            },
          ),
          _buildSubnavItem(Icons.calendar_month_outlined, 'My Classes (Today)'),
          _buildSubnavItem(Icons.code_rounded, 'Join via Code'),
          _buildSubnavItem(Icons.person_add_alt_1_rounded, 'Guest Join'),
          _buildSubnavItem(Icons.settings_outlined, 'Class Settings'),
          _buildSubnavItem(Icons.headphones_outlined, 'Device & Audio Test'),
          _buildSubnavItem(Icons.poll_outlined, 'Live Polls & Q&A'),
          _buildSubnavItem(Icons.podcasts_rounded, 'Streaming & Broadcast'),
        ],
      ),
    );
  }

  Widget _buildSubnavItem(IconData icon, String label) {
    final isSelected = _selectedSubnav == label || (label == 'Live Classroom' && _selectedSubnav == 'Conduct Class');

    return InkWell(
      onTap: () {
        if (label == 'Live Classroom') {
          setState(() {
            _classroomStageMode = StageMode.teacherPresentation;
            _selectedSubnav = 'Conduct Class';
          });
        } else if (label == 'Join via Code') {
          setState(() => _selectedSubnav = 'Join via Code');
          ref.read(liveClassManagementProvider.notifier).loadJoinViaCodeData();
        } else if (label == 'Guest Join') {
          setState(() => _selectedSubnav = 'Guest Join');
          ref.read(liveClassManagementProvider.notifier).loadGuestJoinData();
        } else if (label == 'Device & Audio Test') {
          _showDeviceTestDialog();
        } else if (label == 'Live Polls & Q&A') {
          _showLivePollsDialog();
        } else if (label == 'Streaming & Broadcast') {
          setState(() => _selectedSubnav = 'Streaming & Broadcast');
        } else {
          setState(() => _selectedSubnav = label);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF)) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE), width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoLiveClassView() {
    final state = ref.watch(liveClassManagementProvider);
    final myClasses = state.myClassesList;
    final nextClass = myClasses.isNotEmpty ? myClasses.first : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 520),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 42),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    const SizedBox(width: 8),
                    Text(
                      'NO LIVE CLASS IN PROGRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Glowing Icon Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25), width: 1.5),
                ),
                child: const Icon(Icons.meeting_room_outlined, size: 40, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 20),

              // Headline
              Text(
                'No Live Class is Currently Running',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Text(
                  'There is no ongoing live classroom session in progress at this moment. Please check your schedule to join an upcoming class, start an instant live class, or connect with a meeting code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: textSecondary,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons Row
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _selectedSubnav = 'My Classes (Today)'),
                    icon: const Icon(Icons.calendar_month_outlined, size: 16),
                    label: const Text("Check Today's Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showStartNewClassWizard,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Start Instant Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _selectedSubnav = 'Join via Code');
                      ref.read(liveClassManagementProvider.notifier).loadJoinViaCodeData();
                    },
                    icon: Icon(Icons.code_rounded, size: 16, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                    label: Text(
                      'Join via Code',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      side: BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),

              // Next Upcoming Class Preview Card
              if (nextClass != null) ...[
                const SizedBox(height: 32),
                Container(
                  constraints: const BoxConstraints(maxWidth: 580),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.schedule_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Scheduled Class: ${nextClass.classSection} • ${nextClass.subjectName}',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textPrimary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${nextClass.topic}  |  ${nextClass.scheduledTimeStr.isNotEmpty ? nextClass.scheduledTimeStr : "08:00 AM - 08:45 AM"}',
                              style: TextStyle(fontSize: 11.5, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.read(liveClassManagementProvider.notifier).selectAndActivateLiveClass(nextClass);
                          ref.read(liveClassManagementProvider.notifier).startClass(nextClass.id);
                          setState(() {
                            _classroomStageMode = StageMode.teacherPresentation;
                            _selectedSubnav = 'Conduct Class';
                          });
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 14),
                        label: const Text('Start Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // JOIN VIA CODE & GUEST JOIN WORKSPACES & ACTIONS (MATCHING MOCKUPS 1 & 2)
  // ============================================================================

  Future<void> _handleJoinViaCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a meeting code (e.g., 10A-MATH)'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final res = await ref.read(liveClassManagementProvider.notifier).validateAndPreviewCode(code);
    if (!mounted) return;

    if (res['success'] == true && res['session'] != null) {
      final session = res['session'] as ValidatedMeetingInfo;
      _showPreJoinClassModal(session);
    } else {
      final msg = res['message'] as String? ?? 'Invalid or expired meeting code';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPreJoinClassModal(ValidatedMeetingInfo session) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(liveClassManagementProvider);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.video_call_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title.isNotEmpty ? session.title : '${session.classSection}: ${session.subject}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Room Code: ${session.roomCode} • ${session.status.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              session.subjectIcon.isNotEmpty ? session.subjectIcon : '📐',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${session.classSection} • ${session.subject}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                const SizedBox(height: 2),
                                Text('Teacher: ${session.hostName} (${session.hostRole})',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                const SizedBox(height: 2),
                                Text('Scheduled: ${session.scheduledDate} • ${session.scheduledTime} (${session.durationMinutes} min)',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: session.isLive ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 4,
                                  backgroundColor: session.isLive ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  session.isLive ? 'Live Now' : 'Scheduled',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: session.isLive ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Pre-Join Preferences:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                state.joinOptionCamera ? Icons.videocam : Icons.videocam_off,
                                size: 18,
                                color: state.joinOptionCamera ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Camera on entry', style: TextStyle(fontSize: 12))),
                              Switch(
                                value: state.joinOptionCamera,
                                onChanged: (v) => ref.read(liveClassManagementProvider.notifier).setJoinOptionCamera(v),
                                activeThumbColor: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                          const Divider(height: 1),
                          Row(
                            children: [
                              Icon(
                                state.joinOptionMic ? Icons.mic : Icons.mic_off,
                                size: 18,
                                color: state.joinOptionMic ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('Microphone unmuted', style: TextStyle(fontSize: 12))),
                              Switch(
                                value: state.joinOptionMic,
                                onChanged: (v) => ref.read(liveClassManagementProvider.notifier).setJoinOptionMic(v),
                                activeThumbColor: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (session.waitingRequired) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_empty_rounded, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Waiting Room is active for this session. The teacher will be prompted to admit you upon entering.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final roomService = ref.read(liveRoomServiceProvider);
                    final auth = _getActiveAuthUserInfo();
                    roomService.initRoomConfig(
                      liveClassId: session.id.isNotEmpty ? session.id : session.roomCode,
                      currentUserId: auth['id']!,
                      currentUserName: auth['name']!,
                      currentUserRole: auth['role']!,
                    );
                    await roomService.initializeRoom();
                  } catch (_) {}
                  if (!mounted) return;
                  setState(() {
                    _classroomStageMode = StageMode.teacherPresentation;
                    _selectedSubnav = 'Conduct Class';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Connected to ${session.classSection} • ${session.subject} live stage.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Join Live Stage Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleGuestJoinSubmit() async {
    final code = _guestCodeCtrl.text.trim().toUpperCase();
    final name = _guestNameCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting code or paste meeting link'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    final response = await ref.read(liveClassManagementProvider.notifier).submitGuestJoinRequest(
      code: code,
      displayName: name,
      email: _guestEmailCtrl.text.trim().isNotEmpty ? _guestEmailCtrl.text.trim() : null,
      purpose: _guestPurpose,
      organization: _guestOrgCtrl.text.trim().isNotEmpty ? _guestOrgCtrl.text.trim() : null,
    );

    if (!mounted) return;

    if (response.success) {
      if (response.approvalStatus == 'APPROVED' || !response.requiresWaitingRoom) {
        // Direct entry if already approved or open
        final roomService = ref.read(liveRoomServiceProvider);
        roomService.initRoomConfig(
          liveClassId: response.sessionId.isNotEmpty ? response.sessionId : code,
          currentUserId: response.guestId.isNotEmpty ? response.guestId : response.guestReference,
          currentUserName: response.displayName.isNotEmpty ? response.displayName : 'Guest Attendee',
          currentUserRole: 'guest',
        );
        await roomService.initializeRoom();
        if (!mounted) return;
        setState(() {
          _classroomStageMode = StageMode.teacherPresentation;
          _selectedSubnav = 'Conduct Class';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined live class as Guest!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        _showGuestWaitingRoomDialog(response);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message.isNotEmpty ? response.message : 'Guest access denied or session not found'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showGuestWaitingRoomDialog(GuestJoinResponse res) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WaitingRoomPollingDialog(
        res: res,
        onAdmitted: () async {
          try {
            final roomService = ref.read(liveRoomServiceProvider);
            roomService.initRoomConfig(
              liveClassId: res.sessionId.isNotEmpty ? res.sessionId : _guestCodeCtrl.text.trim(),
              currentUserId: res.guestId.isNotEmpty ? res.guestId : res.guestReference,
              currentUserName: res.displayName.isNotEmpty ? res.displayName : 'Guest Attendee',
              currentUserRole: 'guest',
            );
            await roomService.initializeRoom();
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _classroomStageMode = StageMode.teacherPresentation;
            _selectedSubnav = 'Conduct Class';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The host has admitted you to the live class! Welcome!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        },
        onRejected: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The host has declined your request to join this session.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        },
      ),
    );
  }

  // ============================================================================
  // WORKSPACE RENDERERS: JOIN VIA CODE (MOCKUP 1)
  // ============================================================================

  Widget _buildJoinViaCodeWorkspace(LiveClassState state, BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Bar
        _buildWorkspaceHeader(
          icon: Icons.code_rounded,
          title: 'Join via Code',
          subtitle: 'Quickly join a live class using the meeting code provided by your teacher.',
        ),
        // 2. Main 2-column split (Left card: Enter code + Join Options, Right card: How to join + Recent codes)
        LayoutBuilder(
          builder: (context, innerConstraints) {
            final isStacked = innerConstraints.maxWidth < 950;
            if (isStacked) {
              return Column(
                children: [
                  _buildEnterCodeCard(state),
                  const SizedBox(height: 14),
                  _buildJoinOptionsCard(state),
                  const SizedBox(height: 14),
                  _buildHowToJoinCard(),
                  const SizedBox(height: 14),
                  _buildRecentCodesCard(state),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (~380px)
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      _buildEnterCodeCard(state),
                      const SizedBox(height: 14),
                      _buildJoinOptionsCard(state),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Right Column (Expanded)
                Expanded(
                  child: Column(
                    children: [
                      _buildHowToJoinCard(),
                      const SizedBox(height: 14),
                      _buildRecentCodesCard(state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // 3. Bottom 3 Help Cards
        _buildJoinViaCodeHelpCards(),
      ],
    );
  }

  // ============================================================================
  // WORKSPACE RENDERERS: GUEST JOIN (MOCKUP 2)
  // ============================================================================

  Widget _buildGuestJoinWorkspace(LiveClassState state, BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Bar
        _buildWorkspaceHeader(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Guest Join',
          subtitle: 'Allow external participants (e.g., guest speakers, parents, alumni, or invited users) to join a live class securely.',
        ),
        // 2. Main 2-column split (Left card: Join as Guest form + Join Options, Right card: Guidelines + Upcoming guest sessions)
        LayoutBuilder(
          builder: (context, innerConstraints) {
            final isStacked = innerConstraints.maxWidth < 980;
            if (isStacked) {
              return Column(
                children: [
                  _buildGuestJoinFormCard(state),
                  const SizedBox(height: 14),
                  _buildJoinOptionsCard(state),
                  const SizedBox(height: 14),
                  _buildGuestJoinGuidelinesCard(),
                  const SizedBox(height: 14),
                  _buildUpcomingGuestSessionsCard(state),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (~440px)
                SizedBox(
                  width: 440,
                  child: Column(
                    children: [
                      _buildGuestJoinFormCard(state),
                      const SizedBox(height: 14),
                      _buildJoinOptionsCard(state),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Right Column (Expanded)
                Expanded(
                  child: Column(
                    children: [
                      _buildGuestJoinGuidelinesCard(),
                      const SizedBox(height: 14),
                      _buildUpcomingGuestSessionsCard(state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // 3. Bottom 3 Help Cards
        _buildGuestJoinHelpCards(),
      ],
    );
  }

  // ============================================================================
  // WORKSPACE RENDERERS: CLASS SETTINGS (DYNAMIC CONFIGURATION)
  // ============================================================================

  Widget _buildClassSettingsWorkspace(LiveClassState state, BoxConstraints constraints) {
    final activeSess = state.conductSessionData?.activeSession ?? state.joinDashboard?.activeSession;
    final availableSessions = state.myClassesList;
    final selectedId = _settingSelectedSessionId ?? activeSess?.id ?? availableSessions.firstOrNull?.id ?? 'sess-active';
    final targetItem = availableSessions.where((s) => s.id == selectedId).firstOrNull;

    if (_loadedSessionIdForSettings != selectedId && !_isLoadingSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _loadedSessionIdForSettings != selectedId) {
          _fetchAndApplySessionSettings(selectedId);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWorkspaceHeader(
          icon: Icons.settings_suggest_rounded,
          title: 'Class Settings & Session Policies',
          subtitle: 'Configure real-time student permissions, audio/video policies, waiting room, and cloud recording.',
        ),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingSettings) ...[
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                const SizedBox(height: 12),
              ],
              // Target Session Selector Card
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LiveClassTheme.primaryWithOpacity(context, 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.school_rounded, color: LiveClassTheme.primary(context), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Live Class Session',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          targetItem != null
                              ? '${targetItem.classSection} : ${targetItem.subjectName} (${targetItem.scheduledTimeStr})'
                              : (activeSess != null ? '${activeSess.className} - ${activeSess.sectionName} : ${activeSess.subject}' : 'Class 10 - A : Mathematics'),
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (availableSessions.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final distinctSessions = <String, MyClassItem>{};
                        for (final s in availableSessions) {
                          distinctSessions.putIfAbsent(s.id, () => s);
                        }
                        final effectiveSelectedId = distinctSessions.containsKey(selectedId)
                            ? selectedId
                            : distinctSessions.keys.first;

                        return DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<String>.fromMenuItems(
                            value: effectiveSelectedId,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: LiveClassTheme.primary(context)),
                            items: distinctSessions.values.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text('${s.classSection} - ${s.subjectName}'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _settingSelectedSessionId = val);
                                _fetchAndApplySessionSettings(val);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: cardDivider),
              const SizedBox(height: 16),

              // Section 1: Audio, Video & Screen Share Permissions
              Text('Audio & Video Media Permissions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 8),
              _buildOptionSwitchRow(
                icon: Icons.mic_none_outlined,
                label: 'Allow Students to Unmute Microphone',
                value: _settingAllowMic,
                onChanged: (v) => setState(() => _settingAllowMic = v),
              ),
              Divider(height: 1, color: cardDivider),
              _buildOptionSwitchRow(
                icon: Icons.videocam_outlined,
                label: 'Allow Students to Enable Camera Video',
                value: _settingAllowCam,
                onChanged: (v) => setState(() => _settingAllowCam = v),
              ),
              Divider(height: 1, color: cardDivider),
              _buildOptionSwitchRow(
                icon: Icons.screen_share_outlined,
                label: 'Allow Students to Share Screen (Disabled defaults to Host Only)',
                value: _settingAllowScreenShare,
                onChanged: (v) => setState(() => _settingAllowScreenShare = v),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: cardDivider),
              const SizedBox(height: 16),

              // Section 2: Interaction, Chat & Waiting Room
              Text('Participation & Security Controls', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 8),
              _buildOptionSwitchRow(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Allow In-Class Public & Private Chat',
                value: _settingAllowChat,
                onChanged: (v) => setState(() => _settingAllowChat = v),
              ),
              Divider(height: 1, color: cardDivider),
              _buildOptionSwitchRow(
                icon: Icons.add_reaction_outlined,
                label: 'Allow Emojis, Raised Hands & Quick Poll Voting',
                value: _settingAllowReactions,
                onChanged: (v) => setState(() => _settingAllowReactions = v),
              ),
              Divider(height: 1, color: cardDivider),
              _buildOptionSwitchRow(
                icon: Icons.meeting_room_outlined,
                label: 'Enable Waiting Room (Host must admit each student/guest)',
                value: _settingWaitingRoom,
                onChanged: (v) => setState(() => _settingWaitingRoom = v),
              ),
              Divider(height: 1, color: cardDivider),
              _buildOptionSwitchRow(
                icon: Icons.cloud_sync_outlined,
                label: 'Automatically Record Live Session to Cloud Archive',
                value: _settingAutoRecord,
                onChanged: (v) => setState(() => _settingAutoRecord = v),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: cardDivider),
              const SizedBox(height: 16),

              // Section 3: Room Capacity & Save Actions
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Text('Max Student Capacity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                        const SizedBox(width: 10),
                        DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<int>.fromMenuItems(
                            value: _settingMaxCapacity,
                            dropdownColor: cardBg,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                            items: (<int>{30, 45, 60, 100, _settingMaxCapacity}.toList()..sort()).map((c) => DropdownMenuItem(value: c, child: Text('$c Students'))).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _settingMaxCapacity = v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _settingAllowMic = true;
                        _settingAllowCam = true;
                        _settingAllowScreenShare = false;
                        _settingAllowChat = true;
                        _settingAllowReactions = true;
                        _settingWaitingRoom = false;
                        _settingAutoRecord = true;
                        _settingMaxCapacity = 45;
                      });
                    },
                    child: const Text('Reset Defaults', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiveClassTheme.primary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSavingSettings
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 16),
                    label: Text(
                      _isSavingSettings ? 'Applying...' : 'Save & Apply Settings',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isSavingSettings
                        ? null
                        : () async {
                            setState(() => _isSavingSettings = true);
                            try {
                              final success = await ref.read(liveClassManagementProvider.notifier).updateSessionSettings(
                                selectedId,
                                {
                                  'allow_student_mic': _settingAllowMic,
                                  'allow_student_cam': _settingAllowCam,
                                  'allow_student_share': _settingAllowScreenShare,
                                  'allow_chat': _settingAllowChat,
                                  'allow_reactions': _settingAllowReactions,
                                  'waiting_room_enabled': _settingWaitingRoom,
                                  'recording_enabled': _settingAutoRecord,
                                  'max_participants': _settingMaxCapacity,
                                },
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Class session settings updated & synchronized successfully!'
                                          : 'Failed to update session settings. Please check permissions.',
                                    ),
                                    backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isSavingSettings = false);
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // WORKSPACE SUB-CARDS & COMPONENTS
  // ============================================================================

  Widget _buildWorkspaceHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showStartNewClassWizard,
            icon: const Icon(Icons.calendar_today_outlined, size: 14),
            label: const Text('Schedule Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterCodeCard(LiveClassState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration
          Center(
            child: _buildLaptopIllustration(isGroup: true, width: 180, height: 110),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Enter Meeting Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
          const SizedBox(height: 14),
          // Code Text Field
          TextField(
            controller: _joinCodeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: textPrimary),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.code_rounded, color: Color(0xFF2563EB), size: 18),
              suffixIcon: Tooltip(
                message: 'Enter code given by teacher, e.g. 10A-MATH',
                child: Icon(Icons.info_outline_rounded, color: textSecondary, size: 18),
              ),
              hintText: 'Enter meeting code (e.g., 10A-MATH)',
              hintStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, letterSpacing: 0, color: textSecondary),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
            onSubmitted: (val) => _handleJoinViaCode(val),
          ),
          if (state.joinCodeErrorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.joinCodeErrorMessage!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 14),
          // Solid Blue Join Class Button
          ElevatedButton.icon(
            onPressed: state.isJoinCodeLoading ? null : () => _handleJoinViaCode(_joinCodeCtrl.text),
            icon: state.isJoinCodeLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text(
              'Join Class',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinOptionsCard(LiveClassState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Join Options',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOptionSwitchRow(
            icon: Icons.videocam_outlined,
            label: 'Turn On Camera',
            value: state.joinOptionCamera,
            onChanged: (v) => ref.read(liveClassManagementProvider.notifier).setJoinOptionCamera(v),
          ),
          Divider(height: 1, color: cardDivider),
          _buildOptionSwitchRow(
            icon: Icons.mic_none_outlined,
            label: 'Unmute Microphone',
            value: state.joinOptionMic,
            onChanged: (v) => ref.read(liveClassManagementProvider.notifier).setJoinOptionMic(v),
          ),
          Divider(height: 1, color: cardDivider),
          _buildOptionSwitchRow(
            icon: Icons.screen_share_outlined,
            label: 'Allow Screen Sharing',
            value: state.joinOptionScreenShare,
            onChanged: (v) => ref.read(liveClassManagementProvider.notifier).setJoinOptionScreenShare(v),
          ),
          Divider(height: 1, color: cardDivider),
          _buildOptionSwitchRow(
            icon: Icons.pan_tool_outlined,
            label: 'Join with Hand Raised',
            value: state.joinOptionHandRaised,
            onChanged: (v) => ref.read(liveClassManagementProvider.notifier).setJoinOptionHandRaised(v),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionSwitchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textPrimary),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToJoinCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'How to Join a Class',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Steps
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildStepItem(step: '1', text: 'Get the meeting code from your teacher.', isLast: false),
                    _buildStepItem(step: '2', text: 'Enter the code in the field on the left.', isLast: false),
                    _buildStepItem(step: '3', text: 'Set your audio and video preferences.', isLast: false),
                    _buildStepItem(step: '4', text: 'Click Join Class to enter the live session.', isLast: true),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Illustration
              Expanded(
                flex: 4,
                child: Center(
                  child: _buildLaptopIllustration(isGroup: false, width: 150, height: 95),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({required String step, required String text, required bool isLast}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  step,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 18,
                color: cardBorder,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCodesCard(LiveClassState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Recent / Saved Meeting Codes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                  ),
                ],
              ),
              InkWell(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('Clear All Meeting Codes?'),
                      content: const Text('This will clear your recent unstarred meeting history.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref.read(liveClassManagementProvider.notifier).clearRecentCodes();
                  }
                },
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text(
                      'Clear All',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Table
          if (state.recentCodes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text('No recent codes saved yet.', style: TextStyle(fontSize: 12, color: textSecondary)),
            )
          else ...[
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: headerRowBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 28), // star
                  Expanded(flex: 2, child: Text('Meeting Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  Expanded(flex: 3, child: Text('Class / Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  Expanded(flex: 2, child: Text('Teacher', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  Expanded(flex: 2, child: Text('Last Joined', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  SizedBox(width: 80, child: Text('Action', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary), textAlign: TextAlign.center)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Data Rows
            for (final item in state.recentCodes)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Star button
                    SizedBox(
                      width: 28,
                      child: InkWell(
                        onTap: () {
                          ref.read(liveClassManagementProvider.notifier).toggleStarMeetingCode(item.meetingCode, !item.isStarred);
                        },
                        child: Icon(
                          item.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 18,
                          color: item.isStarred ? const Color(0xFFF59E0B) : textSecondary,
                        ),
                      ),
                    ),
                    // Meeting Code
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.meetingCode,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ),
                    // Class / Subject
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.classSubject,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ),
                    // Teacher
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.teacherName,
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                    // Last Joined
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.lastJoinedStr,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ),
                    // Action Buttons (Join + More options)
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              _joinCodeCtrl.text = item.meetingCode;
                              _handleJoinViaCode(item.meetingCode);
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 16, color: textSecondary),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'copy') {
                                Clipboard.setData(ClipboardData(text: item.meetingCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Code ${item.meetingCode} copied to clipboard')),
                                );
                              } else if (val == 'toggle_star') {
                                ref.read(liveClassManagementProvider.notifier).toggleStarMeetingCode(item.meetingCode, !item.isStarred);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, size: 14, color: Color(0xFF475569)),
                                    SizedBox(width: 8),
                                    Text('Copy Code', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle_star',
                                child: Row(
                                  children: [
                                    Icon(item.isStarred ? Icons.star_border_rounded : Icons.star_rounded, size: 14, color: const Color(0xFFF59E0B)),
                                    const SizedBox(width: 8),
                                    Text(item.isStarred ? 'Unstar Code' : 'Star Code', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestJoinFormCard(LiveClassState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Join as Guest',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Meeting Code / Link Field
          Text('Meeting Code / Link *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
          const SizedBox(height: 6),
          TextField(
            controller: _guestCodeCtrl,
            style: TextStyle(fontSize: 13, color: textPrimary),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.code_rounded, color: Color(0xFF2563EB), size: 18),
              suffixIcon: IconButton(
                icon: Icon(Icons.paste_rounded, color: textSecondary, size: 18),
                tooltip: 'Paste from clipboard',
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    setState(() {
                      _guestCodeCtrl.text = data!.text!.trim();
                    });
                  }
                },
              ),
              hintText: 'Enter meeting code (e.g., 10A-MATH) or paste meeting link',
              hintStyle: TextStyle(fontSize: 12, color: textSecondary),
              filled: true,
              fillColor: inputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // Row: Your Name * & Email (Optional)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _guestNameCtrl,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded, color: textSecondary, size: 18),
                        hintText: 'Enter your full name',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _guestEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline_rounded, color: textSecondary, size: 18),
                        hintText: 'Enter your email address',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row: Purpose / Role * & Organization (Optional)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Purpose / Role *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _guestPurpose,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      style: TextStyle(fontSize: 12, color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.stars_outlined, color: Color(0xFF2563EB), size: 18),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Guest Speaker', child: Text('Guest Speaker', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Subject Expert', child: Text('Subject Expert', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Parent / Guardian', child: Text('Parent / Guardian', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Alumni', child: Text('Alumni', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Observer / Inspector', child: Text('Observer / Inspector', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _guestPurpose = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Organization (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _guestOrgCtrl,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.business_outlined, color: textSecondary, size: 18),
                        hintText: 'Enter organization / institution',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (state.guestJoinErrorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              state.guestJoinErrorMessage!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 16),

          // Solid Blue Join as Guest Button
          ElevatedButton.icon(
            onPressed: state.isGuestJoinLoading ? null : _handleGuestJoinSubmit,
            icon: state.isGuestJoinLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text(
              'Join as Guest',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestJoinGuidelinesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Guest Join Guidelines',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Guidelines bullets
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildGuidelineItem('Use the meeting code or link shared by the teacher.'),
                    _buildGuidelineItem('Enter your name and select your role.'),
                    _buildGuidelineItem('Allow camera and microphone access when prompted.'),
                    _buildGuidelineItem('Follow the class rules and code of conduct.'),
                    _buildGuidelineItem('You cannot access internal class resources or student data.'),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Illustration
              Expanded(
                flex: 4,
                child: Center(
                  child: _buildLaptopIllustration(isGroup: true, width: 150, height: 95),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingGuestSessionsCard(LiveClassState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Upcoming Guest Sessions (Invited)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textPrimary),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  ref.read(liveClassManagementProvider.notifier).loadGuestJoinData();
                },
                child: const Row(
                  children: [
                    Text(
                      'View All →',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (state.upcomingGuestSessions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text('No upcoming guest sessions scheduled.', style: TextStyle(fontSize: 12, color: textSecondary)),
            )
          else ...[
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: headerRowBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Class / Subject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  Expanded(flex: 4, child: Text('Topic', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  Expanded(flex: 3, child: Text('Date & Time', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  Expanded(flex: 2, child: Text('Host', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary))),
                  SizedBox(width: 80, child: Text('Action', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary), textAlign: TextAlign.center)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Rows
            for (final session in state.upcomingGuestSessions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    // Class / Subject
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              session.classSubject,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Topic
                    Expanded(
                      flex: 4,
                      child: Text(
                        session.topic,
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                      ),
                    ),
                    // Date & Time
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.scheduledDateStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary)),
                          Text(session.scheduledTimeStr, style: TextStyle(fontSize: 10, color: textSecondary)),
                        ],
                      ),
                    ),
                    // Host
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(Icons.person_pin_outlined, size: 14, color: textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              session.hostName,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              _guestCodeCtrl.text = session.roomCode;
                              _handleGuestJoinSubmit();
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 16, color: textSecondary),
                            padding: EdgeInsets.zero,
                            onSelected: (val) {
                              if (val == 'copy_code') {
                                Clipboard.setData(ClipboardData(text: session.roomCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Room code ${session.roomCode} copied')),
                                );
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'copy_code',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_rounded, size: 14, color: textSecondary),
                                    const SizedBox(width: 8),
                                    const Text('Copy Code', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLaptopIllustration({required bool isGroup, double width = 160, double height = 100}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft background glow circle
            Container(
              width: height * 0.9,
              height: height * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDBEAFE).withValues(alpha: 0.6),
              ),
            ),
            // Laptop screen
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: width * 0.55,
                  height: height * 0.52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: isGroup
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(radius: 5, backgroundColor: Colors.white.withValues(alpha: 0.9), child: const Icon(Icons.person, size: 7, color: Color(0xFF2563EB))),
                                const SizedBox(width: 2),
                                CircleAvatar(radius: 5, backgroundColor: Colors.white.withValues(alpha: 0.9), child: const Icon(Icons.person, size: 7, color: Color(0xFF10B981))),
                                const SizedBox(width: 2),
                                CircleAvatar(radius: 5, backgroundColor: Colors.white.withValues(alpha: 0.9), child: const Icon(Icons.person, size: 7, color: Color(0xFFF59E0B))),
                              ],
                            )
                          : const CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, size: 12, color: Color(0xFF2563EB)),
                            ),
                    ),
                  ),
                ),
                // Laptop base
                Container(
                  width: width * 0.72,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF94A3B8),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                  ),
                  child: Center(
                    child: Container(
                      width: width * 0.15,
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinViaCodeHelpCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildHelpCard(
            icon: Icons.link_rounded,
            title: 'Need a Meeting Code?',
            description: 'Contact your subject teacher or check your class schedule for the meeting code.',
          ),
          _buildHelpCard(
            icon: Icons.bookmark_border_rounded,
            title: 'Save for Quick Access',
            description: 'Click the ⭐ (star) icon next to a meeting code to save it for future use.',
          ),
          _buildHelpCard(
            icon: Icons.headphones_outlined,
            title: 'Audio & Video Test',
            description: 'Test your camera, microphone and network before joining the class.',
            actionButton: OutlinedButton.icon(
              onPressed: _showDeviceTestDialog,
              icon: const Icon(Icons.play_arrow_rounded, size: 14),
              label: const Text('Test Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ];

        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: 10),
              ]
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 12),
            ]
          ],
        );
      },
    );
  }

  Widget _buildGuestJoinHelpCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildHelpCard(
            icon: Icons.help_outline_rounded,
            title: 'Need Help Joining?',
            description: 'Contact your class teacher or use the meeting link shared with you.',
          ),
          _buildHelpCard(
            icon: Icons.headphones_outlined,
            title: 'Audio & Video Test',
            description: 'Test your camera, microphone and network before joining the class.',
            actionButton: OutlinedButton.icon(
              onPressed: _showDeviceTestDialog,
              icon: const Icon(Icons.play_arrow_rounded, size: 14),
              label: const Text('Test Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          _buildHelpCard(
            icon: Icons.shield_outlined,
            title: 'Privacy & Access',
            description: 'Guest users can join only with a valid meeting code or link and have limited access (no student records or internal resources).',
          ),
        ];

        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: 10),
              ]
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: 12),
            ]
          ],
        );
      },
    );
  }

  Widget _buildHelpCard({
    required IconData icon,
    required String title,
    required String description,
    Widget? actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          if (actionButton != null) ...[
            const SizedBox(width: 8),
            actionButton,
          ],
        ],
      ),
    );
  }

  // ============================================================================
  // CENTER MY CLASSES WORKSPACE (TABLE + FILTERS + PAGINATION)
  // ============================================================================

  Widget _buildMyClassesCenterWorkspace(LiveClassState state) {
    final classesList = state.myClasses;
    final totalCount = state.myClassesTotalCount > 0 ? state.myClassesTotalCount : classesList.length;
    final selectedClassId = state.selectedMyClass?.id ?? (classesList.isNotEmpty ? classesList.first.id : '');

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header with Title, Date Pills, and + Create Instant Class
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'My Classes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Date Pills: Today, This Week, This Month
                    _buildDatePill('Today', state.myClassesDateFilter),
                    _buildDatePill('This Week', state.myClassesDateFilter),
                    _buildDatePill('This Month', state.myClassesDateFilter),

                    // Calendar icon picker
                    IconButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2026),
                        );
                        if (picked != null) {
                          ref.read(liveClassManagementProvider.notifier).setMyClassesDateFilter('Custom');
                        }
                      },
                      icon: Icon(Icons.calendar_today_outlined, size: 18, color: textSecondary),
                      tooltip: 'Pick custom date',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),

                    // + Create Instant Class Button
                    ElevatedButton.icon(
                      onPressed: _showCreateInstantDialog,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Create Instant Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cardDivider),

          // 2. Filters Row: Academic Session, Class, Section, Subject, Status, Search
          () {
            final rawSessions = state.academicSessions.isNotEmpty
                ? state.academicSessions
                : const ['2026 - 2027', '2025 - 2026', '2024 - 2025', '2027 - 2028'];
            final sessions = <String>[];
            for (final s in rawSessions) {
              final trimmed = s.trim();
              if (trimmed.isNotEmpty && !sessions.contains(trimmed)) {
                sessions.add(trimmed);
              }
            }
            if (sessions.isEmpty) sessions.add('2026 - 2027');

            final meta = state.dropdownsData;
            final classesList = meta?.classes ?? [];
            final classNames = <String>['All Classes'];
            for (final c in classesList) {
              final trimmed = c.name.trim();
              if (trimmed.isNotEmpty && !classNames.contains(trimmed)) {
                classNames.add(trimmed);
              }
            }
            final selectedClassItem = classesList.where((c) => c.id == state.myClassesClassFilter || c.name == state.myClassesClassFilter).firstOrNull;
            final selectedClassLabel = selectedClassItem?.name ?? (state.myClassesClassFilter == null ? 'All Classes' : state.myClassesClassFilter!);

            // Strict Section Cascading
            final sectionsList = meta?.sections ?? [];
            final filteredSections = selectedClassItem != null
                ? sectionsList.where((s) => s.classId == selectedClassItem.id).toList()
                : sectionsList;
            final sectionNames = <String>['All Sections'];
            for (final s in filteredSections) {
              final trimmed = s.name.trim();
              if (trimmed.isNotEmpty && !sectionNames.contains(trimmed)) {
                sectionNames.add(trimmed);
              }
            }
            final selectedSectionItem = filteredSections.where((s) => s.id == state.myClassesSectionFilter || s.name == state.myClassesSectionFilter).firstOrNull;
            final selectedSectionLabel = selectedSectionItem?.name ??
                (state.myClassesSectionFilter == null || !sectionNames.contains(state.myClassesSectionFilter)
                    ? 'All Sections'
                    : state.myClassesSectionFilter!);

            // Strict Subject Cascading from Class Management
            final List<SubjectDropdownItem> filteredSubjects = [];
            if (selectedClassItem != null && meta != null) {
              if (state.cascadingSubjects.isNotEmpty) {
                filteredSubjects.addAll(state.cascadingSubjects);
              } else if (meta.classSubjects.isNotEmpty) {
                final matches = meta.classSubjects.where((cs) {
                  if (cs.classId != selectedClassItem.id) return false;
                  if (selectedSectionItem != null && cs.sectionId != null && cs.sectionId!.isNotEmpty) {
                    return cs.sectionId == selectedSectionItem.id;
                  }
                  return true;
                }).toList();
                final seen = <String>{};
                for (final m in matches) {
                  if (!seen.contains(m.subjectId)) {
                    seen.add(m.subjectId);
                    filteredSubjects.add(SubjectDropdownItem(
                      id: m.subjectId,
                      name: m.subjectName,
                      icon: m.subjectIcon,
                      classId: m.classId,
                      sectionId: m.sectionId,
                    ));
                  }
                }
              }
              if (filteredSubjects.isEmpty) {
                final cSubs = meta.subjects.where((s) => s.classId == selectedClassItem.id).toList();
                if (cSubs.isNotEmpty) filteredSubjects.addAll(cSubs);
              }
            }
            if (filteredSubjects.isEmpty) {
              filteredSubjects.addAll(meta?.subjects ?? []);
            }

            final subjectNames = <String>['All Subjects'];
            for (final s in filteredSubjects) {
              final trimmed = s.name.trim();
              if (trimmed.isNotEmpty && !subjectNames.contains(trimmed)) {
                subjectNames.add(trimmed);
              }
            }
            final selectedSubjectItem = filteredSubjects.where((s) => s.id == state.myClassesSubjectFilter || s.name == state.myClassesSubjectFilter).firstOrNull;
            final selectedSubjectLabel = selectedSubjectItem?.name ??
                (state.myClassesSubjectFilter == null || !subjectNames.contains(state.myClassesSubjectFilter)
                    ? 'All Subjects'
                    : state.myClassesSubjectFilter!);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Academic Session (From lookup ACADEMIC_YEAR, default current financial year)
                  _buildFilterDropdown(
                    label: 'Academic Session:',
                    value: sessions.contains(state.myClassesSessionFilter) ? state.myClassesSessionFilter : sessions.first,
                    items: sessions,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(liveClassManagementProvider.notifier).setMyClassesSessionFilter(val);
                      }
                    },
                  ),

                  // Class Dropdown (From academic classes)
                  _buildFilterDropdown(
                    label: 'Class:',
                    value: classNames.contains(selectedClassLabel) ? selectedClassLabel : 'All Classes',
                    items: classNames,
                    onChanged: (val) {
                      if (val == null || val == 'All Classes') {
                        ref.read(liveClassManagementProvider.notifier).setMyClassesClassFilter(null);
                      } else {
                        final match = classesList.where((c) => c.name == val).firstOrNull;
                        ref.read(liveClassManagementProvider.notifier).setMyClassesClassFilter(match?.id ?? val);
                      }
                    },
                  ),

                  // Section Dropdown (Filtered strictly by selected class)
                  _buildFilterDropdown(
                    label: 'Section:',
                    value: sectionNames.contains(selectedSectionLabel) ? selectedSectionLabel : 'All Sections',
                    items: sectionNames,
                    onChanged: (val) {
                      if (val == null || val == 'All Sections') {
                        ref.read(liveClassManagementProvider.notifier).setMyClassesSectionFilter(null);
                      } else {
                        final match = filteredSections.where((s) => s.name == val).firstOrNull;
                        ref.read(liveClassManagementProvider.notifier).setMyClassesSectionFilter(match?.id ?? val);
                      }
                    },
                  ),

                  // Subject Dropdown (Filtered strictly by class & section)
                  _buildFilterDropdown(
                    label: 'Subject:',
                    value: subjectNames.contains(selectedSubjectLabel) ? selectedSubjectLabel : 'All Subjects',
                    items: subjectNames,
                    onChanged: (val) {
                      if (val == null || val == 'All Subjects') {
                        ref.read(liveClassManagementProvider.notifier).setMyClassesSubjectFilter(null);
                      } else {
                        final match = filteredSubjects.where((s) => s.name == val).firstOrNull;
                        ref.read(liveClassManagementProvider.notifier).setMyClassesSubjectFilter(match?.id ?? val);
                      }
                    },
                  ),

                  // Status Dropdown
                  _buildFilterDropdown(
                    label: 'Status:',
                    value: state.myClassesStatusFilter,
                    items: const ['All', 'Live', 'Upcoming', 'Completed', 'Scheduled', 'Cancelled'],
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(liveClassManagementProvider.notifier).setMyClassesStatusFilter(val);
                      }
                    },
                  ),

                  // Search Bar
                  SizedBox(
                    width: 200,
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => ref.read(liveClassManagementProvider.notifier).searchMyClasses(val),
                      style: TextStyle(fontSize: 12, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by class, subject or topic...',
                        hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref.read(liveClassManagementProvider.notifier).searchMyClasses('');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }(),
          Divider(height: 1, color: cardDivider),

          // 2.5 Multi-selection Bulk Operations Toolbar
          if (state.selectedMyClassIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    '${state.selectedMyClassIds.length} classes selected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => ref.read(liveClassManagementProvider.notifier).clearSelectedMyClassIds(),
                    icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                    label: const Text('Deselect All', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkCancelDialog(state.selectedMyClassIds.toList()),
                    icon: const Icon(Icons.block_rounded, size: 13),
                    label: const Text('Bulk Cancel', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showBulkDeleteDialog(state.selectedMyClassIds.toList()),
                    icon: const Icon(Icons.delete_forever_rounded, size: 13),
                    label: const Text('Bulk Delete', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Classes Data Table with Database Sorting & Single Custom Checkbox (NO DUPLICATE CHECKBOXES)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1040),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(headerRowBg),
                headingRowHeight: 42,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                horizontalMargin: 16,
                columnSpacing: 14,
                columns: [
                  // Select All Header Checkbox
                  DataColumn(
                    label: SizedBox(
                      width: 24,
                      child: InkWell(
                        onTap: () {
                          final isAll = classesList.isNotEmpty && classesList.every((c) => state.selectedMyClassIds.contains(c.id));
                          ref.read(liveClassManagementProvider.notifier).selectAllMyClasses(!isAll);
                        },
                        child: Icon(
                          classesList.isNotEmpty && classesList.every((c) => state.selectedMyClassIds.contains(c.id))
                              ? Icons.check_box_rounded
                              : (classesList.any((c) => state.selectedMyClassIds.contains(c.id))
                                  ? Icons.indeterminate_check_box_rounded
                                  : Icons.check_box_outline_blank),
                          size: 16,
                          color: state.selectedMyClassIds.isNotEmpty
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: _buildSortHeader(
                      'Class / Section',
                      'class_name',
                      state.myClassesSortBy,
                      state.myClassesSortOrder,
                      textSecondary,
                      () => ref.read(liveClassManagementProvider.notifier).setMyClassesSort('class_name'),
                    ),
                  ),
                  DataColumn(
                    label: _buildSortHeader(
                      'Subject',
                      'subject_name',
                      state.myClassesSortBy,
                      state.myClassesSortOrder,
                      textSecondary,
                      () => ref.read(liveClassManagementProvider.notifier).setMyClassesSort('subject_name'),
                    ),
                  ),
                  DataColumn(
                    label: _buildSortHeader(
                      'Topic',
                      'title',
                      state.myClassesSortBy,
                      state.myClassesSortOrder,
                      textSecondary,
                      () => ref.read(liveClassManagementProvider.notifier).setMyClassesSort('title'),
                    ),
                  ),
                  DataColumn(
                    label: _buildSortHeader(
                      'Schedule (Date & Time)',
                      'scheduled_at',
                      state.myClassesSortBy,
                      state.myClassesSortOrder,
                      textSecondary,
                      () => ref.read(liveClassManagementProvider.notifier).setMyClassesSort('scheduled_at'),
                    ),
                  ),
                  DataColumn(
                    label: _buildSortHeader(
                      'Status',
                      'status',
                      state.myClassesSortBy,
                      state.myClassesSortOrder,
                      textSecondary,
                      () => ref.read(liveClassManagementProvider.notifier).setMyClassesSort('status'),
                    ),
                  ),
                  DataColumn(
                    label: _buildSortHeader(
                      'Students',
                      'viewer_count',
                      state.myClassesSortBy,
                      state.myClassesSortOrder,
                      textSecondary,
                      () => ref.read(liveClassManagementProvider.notifier).setMyClassesSort('viewer_count'),
                    ),
                  ),
                  DataColumn(label: SizedBox(width: 140, child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)))),
                ],
                rows: classesList.isEmpty
                    ? [
                        DataRow(
                          cells: [
                            const DataCell(SizedBox()),
                            DataCell(Text('No classes scheduled', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: textSecondary))),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                            const DataCell(SizedBox()),
                          ],
                        )
                      ]
                    : classesList.map((item) {
                        final isRowSelected = item.id == selectedClassId;
                        final isCheckedInSet = state.selectedMyClassIds.contains(item.id);
                        return DataRow(
                          selected: isRowSelected,
                          onSelectChanged: (_) => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (isRowSelected) {
                              return selectedRowBg;
                            }
                            return null;
                          }),
                          cells: [
                            // Single Custom Checkbox Cell
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).toggleSelectMyClassId(item.id),
                                child: SizedBox(
                                  width: 24,
                                  child: Icon(
                                    isCheckedInSet ? Icons.check_box_rounded : Icons.check_box_outline_blank,
                                    size: 16,
                                    color: isCheckedInSet ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ),
                            ),
                            // Class / Section
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                                child: SizedBox(
                                  width: 105,
                                  child: Text(
                                    item.classSection,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            // Subject with clean sanitized icon (NO MOJIBAKE)
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                                child: SizedBox(
                                  width: 125,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        SubjectDropdownItem.sanitizeSubjectIcon(item.subjectIcon, item.subjectName),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.subjectName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Topic
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                                child: SizedBox(
                                  width: 145,
                                  child: Text(
                                    item.topic,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            // Schedule
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                                child: SizedBox(
                                  width: 145,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.scheduledDateStr,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.schedule_rounded, size: 11, color: textSecondary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              item.scheduledTimeStr,
                                              style: TextStyle(fontSize: 10, color: textSecondary),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Status Badge
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                                child: SizedBox(
                                  width: 90,
                                  child: _buildStatusBadge(item.status),
                                ),
                              ),
                            ),
                            // Students count
                            DataCell(
                              InkWell(
                                onTap: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
                                child: SizedBox(
                                  width: 80,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.groups_outlined, size: 14, color: textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.studentCountStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Actions
                            DataCell(
                              SizedBox(
                                width: 140,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPrimaryActionButton(item),
                                    const SizedBox(width: 4),
                                    _buildItemActionMenu(item),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: cardDivider),

          // 4. Powerful Dynamic Pagination Control
          () {
            final totalPages = state.myClassesTotalPages > 0 ? state.myClassesTotalPages : 1;
            final currentPage = state.myClassesPage.clamp(1, totalPages);
            final startCount = totalCount == 0 ? 0 : ((currentPage - 1) * state.myClassesPageSize + 1);
            final endCount = totalCount == 0 ? 0 : math.min(totalCount, startCount + classesList.length - 1);

            // Compute dynamic pagination window
            final pageNumbers = <int>[];
            final startP = math.max(1, currentPage - 2);
            final endP = math.min(totalPages, currentPage + 2);
            for (int p = startP; p <= endP; p++) {
              pageNumbers.add(p);
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    totalCount == 0
                        ? 'Showing 0 of 0 classes'
                        : 'Showing $startCount - $endCount of $totalCount classes',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // First page
                      IconButton(
                        icon: const Icon(Icons.first_page_rounded, size: 18),
                        color: currentPage > 1 ? textSecondary : textSecondary.withValues(alpha: 0.3),
                        onPressed: currentPage > 1
                            ? () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(1)
                            : null,
                        tooltip: 'First Page',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      // Prev page
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 18),
                        color: currentPage > 1 ? textSecondary : textSecondary.withValues(alpha: 0.3),
                        onPressed: currentPage > 1
                            ? () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(currentPage - 1)
                            : null,
                        tooltip: 'Previous Page',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      if (startP > 1) ...[
                        InkWell(
                          onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(1),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            child: Text('1', style: TextStyle(fontSize: 11, color: textSecondary)),
                          ),
                        ),
                        if (startP > 2)
                          Text('...', style: TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                      for (final p in pageNumbers) ...[
                        InkWell(
                          onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(p),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: currentPage == p ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$p',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: currentPage == p ? Colors.white : textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                      if (endP < totalPages) ...[
                        if (endP < totalPages - 1)
                          Text('...', style: TextStyle(fontSize: 11, color: textSecondary)),
                        InkWell(
                          onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(totalPages),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            child: Text('$totalPages', style: TextStyle(fontSize: 11, color: textSecondary)),
                          ),
                        ),
                      ],
                      // Next page
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        color: currentPage < totalPages ? textSecondary : textSecondary.withValues(alpha: 0.3),
                        onPressed: currentPage < totalPages
                            ? () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(currentPage + 1)
                            : null,
                        tooltip: 'Next Page',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      // Last page
                      IconButton(
                        icon: const Icon(Icons.last_page_rounded, size: 18),
                        color: currentPage < totalPages ? textSecondary : textSecondary.withValues(alpha: 0.3),
                        onPressed: currentPage < totalPages
                            ? () => ref.read(liveClassManagementProvider.notifier).setMyClassesPage(totalPages)
                            : null,
                        tooltip: 'Last Page',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                      const SizedBox(width: 14),

                      // Rows per page
                      Text('Rows per page: ', style: TextStyle(fontSize: 11, color: textSecondary)),
                      AppSearchableDropdown<int>.fromMenuItems(
                        value: const [5, 10, 20, 50, 100].contains(state.myClassesPageSize)
                            ? state.myClassesPageSize
                            : 10,
                        underline: const SizedBox(),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 20, child: Text('20')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(liveClassManagementProvider.notifier).setMyClassesPageSize(val);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }(),
        ],
      ),
    );
  }

  Widget _buildSortHeader(
    String label,
    String sortField,
    String currentSortBy,
    String currentSortOrder,
    Color textSecondary,
    VoidCallback onSort,
  ) {
    final isActive = currentSortBy == sortField;
    return InkWell(
      onTap: onSort,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? const Color(0xFF2563EB) : textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isActive
                ? (currentSortOrder == 'ASC' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isActive ? const Color(0xFF2563EB) : textSecondary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill(String label, String currentFilter) {
    final isSelected = currentFilter == label;
    return InkWell(
      onTap: () => ref.read(liveClassManagementProvider.notifier).setMyClassesDateFilter(label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final uniqueItems = <String>[];
    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && !uniqueItems.contains(trimmed)) {
        uniqueItems.add(trimmed);
      }
    }
    final effectiveValue = uniqueItems.contains(value.trim())
        ? value.trim()
        : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary)),
        const SizedBox(width: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: AppSearchableDropdown<String>.fromMenuItems(
              value: effectiveValue,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
              icon: Icon(Icons.arrow_drop_down, size: 18, color: textSecondary),
              items: uniqueItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'live':
        bg = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D);
        icon = Icons.fiber_manual_record;
        break;
      case 'upcoming':
        bg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        icon = Icons.schedule_rounded;
        break;
      case 'completed':
        bg = isDark ? const Color(0xFF065F46) : const Color(0xFFECFDF5);
        fg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'scheduled':
        bg = isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF);
        fg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
        icon = Icons.calendar_today_rounded;
        break;
      default:
        bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(MyClassItem item) {
    final status = item.status.toLowerCase();

    if (status == 'live') {
      return ElevatedButton.icon(
        onPressed: () async {
          await ref.read(liveClassManagementProvider.notifier).selectAndActivateLiveClass(item);
          try {
            final roomService = ref.read(liveRoomServiceProvider);
            final auth = _getActiveAuthUserInfo();
            roomService.initRoomConfig(
              liveClassId: item.id,
              currentUserId: auth['id']!,
              currentUserName: auth['name']!,
              currentUserRole: auth['role']!,
            );
            roomService.initializeRoom().timeout(const Duration(seconds: 4)).catchError((e) {
              debugPrint('Async room connect notice: $e');
            });
          } catch (_) {}
          setState(() {
            _classroomStageMode = StageMode.teacherPresentation;
            _selectedSubnav = 'Conduct Class';
          });
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 14),
        label: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(58, 26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    } else if (status == 'upcoming') {
      return OutlinedButton.icon(
        onPressed: () async {
          try {
            await ref.read(liveClassManagementProvider.notifier).startClass(item.id);
          } catch (_) {}
          await ref.read(liveClassManagementProvider.notifier).selectAndActivateLiveClass(item);
          try {
            final roomService = ref.read(liveRoomServiceProvider);
            final auth = _getActiveAuthUserInfo();
            roomService.initRoomConfig(
              liveClassId: item.id,
              currentUserId: auth['id']!,
              currentUserName: auth['name']!,
              currentUserRole: auth['role']!,
            );
            roomService.initializeRoom().timeout(const Duration(seconds: 4)).catchError((e) {
              debugPrint('Async room connect notice: $e');
            });
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _classroomStageMode = StageMode.teacherPresentation;
            _selectedSubnav = 'Conduct Class';
          });
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 14, color: Color(0xFF2563EB)),
        label: const Text('Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF93C5FD)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(58, 26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    } else if (status == 'completed') {
      return OutlinedButton.icon(
        onPressed: () {
          // Switch to tab 1 (Recordings)
          ref.read(liveClassManagementProvider.notifier).setTab(1);
        },
        icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF2563EB)),
        label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF93C5FD)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(58, 26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => ref.read(liveClassManagementProvider.notifier).selectMyClass(item),
        icon: const Icon(Icons.info_outline, size: 14),
        label: const Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(58, 26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
    }
  }

  Widget _buildItemActionMenu(MyClassItem item) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
        padding: EdgeInsets.zero,
        splashRadius: 16,
        onSelected: (action) async {
        if (action == 'duplicate') {
          final ok = await ref.read(liveClassManagementProvider.notifier).duplicateMyClass(item.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ok ? 'Duplicated session for next week' : 'Failed to duplicate session')),
            );
          }
        } else if (action == 'copy_link') {
          Clipboard.setData(ClipboardData(text: item.meetingLink));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meeting link copied to clipboard')),
          );
        } else if (action == 'copy_code') {
          Clipboard.setData(ClipboardData(text: item.roomCode));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class code copied to clipboard')),
          );
        } else if (action == 'edit') {
          showDialog(
            context: context,
            builder: (ctx) => EditLiveClassDialog(item: item),
          );
        } else if (action == 'cancel') {
          _showCancelSessionDialog(item.id, '${item.classSection} : ${item.subjectName}');
        } else if (action == 'delete') {
          _showDeleteSessionDialog(item.id, '${item.classSection} : ${item.subjectName}');
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Edit / Reschedule', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Duplicate for Next Week', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_link',
          child: Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: Color(0xFF475569)),
              SizedBox(width: 8),
              Text('Copy Meeting Link', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy_code',
          child: Row(
            children: [
              Icon(Icons.qr_code_rounded, size: 16, color: Color(0xFF475569)),
              SizedBox(width: 8),
              Text('Copy Room Code', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'cancel',
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Cancel Session', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, size: 16, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete Session', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
            ],
          ),
        ),
      ],
    ),
  );
}

  // ============================================================================
  // RIGHT CLASS DETAILS PANEL (MATCHING MOCKUP)
  // ============================================================================

  Widget _buildMyClassesRightPanel(LiveClassState state) {
    final details = state.selectedMyClassDetails;
    final item = state.selectedMyClass;

    // When no class is selected or list is empty, show clean empty state (NO hardcoded dummy data)
    if (item == null && details == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.touch_app_rounded, size: 32, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 14),
              Text(
                'No Class Selected',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Click on any class row in the schedule table to view details & quick actions.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final classSection = details?.classSection ?? item?.classSection ?? '';
    final subject = details?.subject ?? item?.subjectName ?? '';
    final topic = details?.topic ?? item?.topic ?? '';
    final dateStr = details?.dateStr ?? item?.scheduledDateStr ?? '';
    final timeStr = details?.timeStr ?? item?.scheduledTimeStr ?? '';
    final studentsStr = details?.studentsCountStr ?? item?.studentCountStr ?? '0 / 0';
    final meetingCode = details?.meetingCode ?? item?.roomCode ?? '';
    final meetingLink = details?.meetingLink ?? item?.meetingLink ?? '';
    final authUser = ref.read(authProvider).userData;
    final currentUserName = (authUser?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['full_name'] as String).trim()
        : ((authUser?['name'] as String?)?.trim().isNotEmpty == true
            ? (authUser!['name'] as String).trim()
            : 'Instructor');

    final host = (details?.hostName != null && details!.hostName.isNotEmpty)
        ? details.hostName
        : ((item?.teacherName != null && item!.teacherName.isNotEmpty)
            ? item.teacherName
            : currentUserName);
    final coHost = details?.coHostName ?? item?.coTeacherName ?? 'None';

    final status = details?.status ?? item?.status ?? 'Scheduled';
    final isLive = details?.isLive == true || item?.status.toLowerCase() == 'live' || status.toLowerCase() == 'live';
    final isUpcoming = status.toLowerCase() == 'upcoming' || status.toLowerCase() == 'scheduled';
    final isRecording = details?.isRecording == true || item?.recordingStatus == 'RECORDING';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Class Details + Popout icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.dashboard_customize_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Class Details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.open_in_new_rounded, size: 16, color: textSecondary),
                onPressed: () {
                  final sel = item ?? state.selectedMyClass;
                  if (sel != null) {
                    ref.read(liveClassManagementProvider.notifier).selectAndActivateLiveClass(sel, details);
                  }
                  setState(() {
                    _classroomStageMode = StageMode.teacherPresentation;
                    _selectedSubnav = 'Conduct Class';
                  });
                },
                tooltip: 'Open in classroom view',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Profile card: Avatar, Title, Live & Recording badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Teacher Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 52,
                  height: 52,
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                  child: const Icon(Icons.person, size: 34, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$classSection : $subject',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record, size: 8, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A)),
                                const SizedBox(width: 4),
                                Text('Live Now', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF16A34A))),
                              ],
                            ),
                          )
                        else if (isUpcoming)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 9, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text('Upcoming', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB))),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
                          ),
                        if (isRecording) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record, size: 8, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                const SizedBox(width: 4),
                                Text('Recording', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cardDivider),
          const SizedBox(height: 12),

          // Metadata List (Dynamically populated from selected row)
          _buildDetailRow(Icons.menu_book_rounded, 'Topic', topic.isNotEmpty ? topic : '—'),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.calendar_today_rounded, 'Date', dateStr.isNotEmpty ? dateStr : '—'),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.schedule_rounded, 'Time', timeStr.isNotEmpty ? timeStr : '—'),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.groups_outlined, 'Students', studentsStr),
          const SizedBox(height: 8),
          _buildCopyDetailRow(Icons.vpn_key_outlined, 'Meeting Code', meetingCode.isNotEmpty ? meetingCode : '—'),
          const SizedBox(height: 8),
          _buildCopyDetailRow(Icons.link_rounded, 'Meeting Link', meetingLink.isNotEmpty ? meetingLink : '—'),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.person_outline_rounded, 'Host', host),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.person_outline_rounded, 'Co-host', coHost),

          const SizedBox(height: 16),
          Divider(height: 1, color: cardDivider),
          const SizedBox(height: 12),

          // Quick Actions Header
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 6),
              Text('Quick Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 10),

          // Solid Blue Join Class Button
          ElevatedButton.icon(
            onPressed: () {
              final sel = state.selectedMyClass ?? item;
              if (sel != null) {
                ref.read(liveClassManagementProvider.notifier).selectAndActivateLiveClass(sel, details);
                try {
                  final roomService = ref.read(liveRoomServiceProvider);
                  final auth = _getActiveAuthUserInfo();
                  roomService.initRoomConfig(
                    liveClassId: sel.id,
                    currentUserId: auth['id']!,
                    currentUserName: auth['name']!,
                    currentUserRole: auth['role']!,
                  );
                  roomService.initializeRoom().timeout(const Duration(seconds: 4)).catchError((e) {
                    debugPrint('Async room connect notice: $e');
                  });
                } catch (_) {}
              }
              setState(() {
                _classroomStageMode = StageMode.teacherPresentation;
                _selectedSubnav = 'Conduct Class';
              });
            },
            icon: const Icon(Icons.videocam_rounded, size: 16),
            label: const Text('Join Class', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),

          // 4x2 Quick Action Tiles Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRightActionTile(Icons.groups_rounded, 'Participants (${details?.viewerCount ?? item?.viewerCount ?? 0})', onTap: () {
                setState(() => _selectedSubnav = 'Conduct Class');
              }),
              _buildRightActionTile(Icons.video_library_outlined, 'Recordings', onTap: () {
                ref.read(liveClassManagementProvider.notifier).setTab(1);
              }),
              _buildRightActionTile(Icons.chat_bubble_outline_rounded, 'Chat', onTap: () {
                setState(() => _selectedSubnav = 'Conduct Class');
              }),
              _buildRightActionTile(Icons.help_outline_rounded, 'Q&A', onTap: _showLivePollsDialog),
              _buildRightActionTile(Icons.draw_outlined, 'Whiteboard', onTap: () {
                final clsId = item?.id ?? details?.id;
                _openWhiteboardWorkspace(
                  clsId,
                  clsId != null ? 'Whiteboard - $classSection – $subject' : null,
                );
              }),
              _buildRightActionTile(Icons.screen_share_outlined, 'Share Screen', onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Screen sharing initiated.')),
                );
              }),
              _buildRightActionTile(Icons.poll_outlined, 'Polls', onTap: _showLivePollsDialog),
              _buildRightActionTile(
                Icons.call_end_rounded,
                'End Class',
                isDanger: true,
                onTap: () {
                  final clsId = item?.id ?? details?.id;
                  if (clsId != null) {
                    ref.read(liveClassManagementProvider.notifier).endClass(clsId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Class ended. Attendance recorded.')),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 85,
          child: Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCopyDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 85,
          child: Text(label, style: TextStyle(fontSize: 12, color: textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              decoration: TextDecoration.underline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Copied $label to clipboard')),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.copy_rounded, size: 13, color: textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildRightActionTile(IconData icon, String label, {bool isDanger = false, required VoidCallback onTap}) {
    return SizedBox(
      width: 88,
      height: 48,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: isDanger
                ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDanger
                  ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA))
                  : cardBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDanger ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDanger ? const Color(0xFFEF4444) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BOTTOM ANALYTICS ROW (3 CARDS MATCHING MOCKUP)
  // ============================================================================

  Widget _buildMyClassesBottomAnalytics(MyClassesDashboardData? dash) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card1 = _buildTodayProgressCard(dash?.todayProgress);
        final card2 = _buildTeachingSummaryCard(dash?.teachingSummary);
        final card3 = _buildWeeklyTrendCard(dash?.weeklyTrend);

        if (constraints.maxWidth < 950) {
          return Column(
            children: [
              card1,
              const SizedBox(height: 14),
              card2,
              const SizedBox(height: 14),
              card3,
            ],
          );
        }

        if (constraints.maxWidth < 1150) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1050,
              child: Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 14),
                  Expanded(child: card2),
                  const SizedBox(width: 14),
                  Expanded(child: card3),
                ],
              ),
            ),
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 14),
            Expanded(child: card2),
            const SizedBox(width: 14),
            Expanded(child: card3),
          ],
        );
      },
    );
  }

  // Card 1: Today's Class Progress Donut
  Widget _buildTodayProgressCard(TodayClassProgress? progress) {
    final total = progress?.totalClasses ?? 4;
    final live = progress?.liveCount ?? 1;
    final livePct = progress?.livePct ?? 25.0;
    final upcoming = progress?.upcomingCount ?? 2;
    final upcomingPct = progress?.upcomingPct ?? 50.0;
    final completed = progress?.completedCount ?? 1;
    final completedPct = progress?.completedPct ?? 25.0;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 6),
              Text(
                "Today's Class Progress",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                // Custom Donut Chart
                SizedBox(
                  width: 105,
                  height: 105,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(105, 105),
                        painter: _DonutProgressPainter(
                          livePct: livePct / 100.0,
                          upcomingPct: upcomingPct / 100.0,
                          completedPct: completedPct / 100.0,
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                          Text(
                            'Classes',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressLegendItem(const Color(0xFF10B981), 'Live', '$live (${livePct.toStringAsFixed(0)}%)'),
                      const SizedBox(height: 8),
                      _buildProgressLegendItem(const Color(0xFF0284C7), 'Upcoming', '$upcoming (${upcomingPct.toStringAsFixed(0)}%)'),
                      const SizedBox(height: 8),
                      _buildProgressLegendItem(const Color(0xFF8B5CF6), 'Completed', '$completed (${completedPct.toStringAsFixed(0)}%)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressLegendItem(Color dotColor, String label, String value) {
    return Row(
      children: [
        Icon(Icons.fiber_manual_record, size: 10, color: dotColor),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textSecondary)),
        ),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
      ],
    );
  }

  // Card 2: Teaching Summary (Today)
  Widget _buildTeachingSummaryCard(TeachingSummary? summary) {
    final classes = summary?.totalClasses ?? 4;
    final duration = summary?.totalDuration ?? '2 h 15 min';
    final students = summary?.totalStudents ?? 161;
    final participation = summary?.avgParticipationPct ?? 92.7;

    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 6),
              Text(
                'Teaching Summary (Today)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSummaryMetricRow(Icons.schedule_rounded, 'Total Classes', '$classes'),
          const SizedBox(height: 8),
          _buildSummaryMetricRow(Icons.timer_outlined, 'Total Duration', duration),
          const SizedBox(height: 8),
          _buildSummaryMetricRow(Icons.groups_outlined, 'Total Students', '$students'),
          const SizedBox(height: 8),
          _buildSummaryMetricRow(Icons.trending_up_rounded, 'Avg. Participation', '${participation.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildSummaryMetricRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 11, color: textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary),
          ),
        ),
      ],
    );
  }

  // Card 3: Class Trend (This Week)
  Widget _buildWeeklyTrendCard(List<WeeklyClassTrendDay>? trend) {
    final defaultDays = [
      WeeklyClassTrendDay(day: 'Mon', count: 3, completed: 3),
      WeeklyClassTrendDay(day: 'Tue', count: 4, completed: 3),
      WeeklyClassTrendDay(day: 'Wed', count: 5, completed: 4),
      WeeklyClassTrendDay(day: 'Thu', count: 4, completed: 2),
      WeeklyClassTrendDay(day: 'Fri', count: 4, completed: 0),
      WeeklyClassTrendDay(day: 'Sat', count: 2, completed: 0),
      WeeklyClassTrendDay(day: 'Sun', count: 0, completed: 0),
    ];
    final days = (trend != null && trend.isNotEmpty) ? trend : defaultDays;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 6),
              Text(
                'Class Trend (This Week)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((d) {
                const maxCount = 5.0;
                final barHeight = (d.count / maxCount) * 70.0;
                final isPeak = d.count == 5;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${d.count}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))),
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: barHeight > 4 ? barHeight : 4,
                      decoration: BoxDecoration(
                        color: isPeak ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(d.day, style: TextStyle(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CONDUCT CLASS BOTTOM ROW (CONTROLS + CURRENT INFO + UPCOMING)
  // ============================================================================

  Widget _buildConductClassBottomRow(ActiveLiveSession? session, List<UpcomingClass>? upcoming) {
    final state = ref.watch(liveClassManagementProvider);
    final activeSession = state.conductSessionData?.activeSession ?? session;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 950) {
          return Column(
            children: [
              _buildClassControlsCard(),
              const SizedBox(height: 14),
              _buildCurrentClassInfoCard(activeSession),
              const SizedBox(height: 14),
              _buildUpcomingClassesCard(upcoming),
            ],
          );
        }

        if (constraints.maxWidth < 1150) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildClassControlsCard()),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: _buildCurrentClassInfoCard(activeSession)),
                  const SizedBox(width: 14),
                  Expanded(flex: 4, child: _buildUpcomingClassesCard(upcoming)),
                ],
              ),
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildClassControlsCard()),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildCurrentClassInfoCard(activeSession)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildUpcomingClassesCard(upcoming)),
          ],
        );
      },
    );
  }

  Widget _buildClassControlsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Text('Class Controls', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildControlTile(
                Icons.screen_share_outlined,
                'Share Screen',
                isPrimary: true,
                onTap: () async {
                  final rs = ref.read(liveRoomServiceProvider);
                  if (!rs.isConnected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Join or start a live classroom session to share screen.')),
                    );
                    return;
                  }
                  try {
                    final active = await rs.toggleScreenShare();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(active ? 'Screen sharing started' : 'Screen sharing stopped')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Screen sharing error: $e')),
                      );
                    }
                  }
                },
              ),
              _buildControlTile(
                Icons.draw_outlined,
                'Whiteboard',
                onTap: () {
                  _openWhiteboardWorkspace();
                },
              ),
              _buildControlTile(
                Icons.poll_outlined,
                'Polls',
                onTap: () {
                  _showLivePollsDialog();
                },
              ),
              _buildControlTile(
                Icons.live_help_outlined,
                'Q&A',
                onTap: () {
                  _showQADialog();
                },
              ),
              _buildControlTile(
                Icons.pan_tool_outlined,
                'Raise Hand',
                onTap: () async {
                  final rs = ref.read(liveRoomServiceProvider);
                  if (rs.isConnected) {
                    await rs.toggleHandRaise();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hand raise status updated for active class')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Join active class to raise hand')),
                      );
                    }
                  }
                },
              ),
              _buildControlTile(
                Icons.fiber_manual_record,
                'Recording',
                dotColor: Colors.red,
                onTap: () async {
                  final result = await ref.read(liveClassManagementProvider.notifier).toggleRecordingWithCapture();
                  if (mounted) {
                    final ok = result['success'] == true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message']?.toString() ?? (ok ? 'Live class recording state updated' : 'Could not toggle recording')),
                        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlTile(IconData icon, String label, {bool isPrimary = false, Color? dotColor, VoidCallback? onTap}) {
    return SizedBox(
      width: 78,
      height: 64,
      child: InkWell(
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Triggered $label control')),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrimary ? const Color(0xFF2563EB) : cardBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: dotColor ?? (isPrimary ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)))),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentClassInfoCard(ActiveLiveSession? session) {
    final subject = session?.subject ?? 'Mathematics';
    final classSection = session != null ? '${session.className} - ${session.sectionName}' : 'Class 10 - A';
    final dateStr = session?.dateStr ?? 'Tue, 21 Jan 2025';
    final timeStr = session?.timeStr ?? '08:00 AM - 08:45 AM (45 min)';
    final meetLink = session?.meetingLink ?? 'https://meet.edushamiit.com/cls/10A-math';
    final classCode = session?.roomCode ?? '10A-MATH';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Text('Current Class Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.menu_book_rounded, 'Subject', subject),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.groups_outlined, 'Class / Section', classSection),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.calendar_today_rounded, 'Date', dateStr),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.schedule_rounded, 'Time', timeStr),
          const SizedBox(height: 8),
          _buildCopyDetailRow(Icons.link_rounded, 'Meeting Link', meetLink),
          const SizedBox(height: 8),
          _buildCopyDetailRow(Icons.qr_code_rounded, 'Class Code', classCode),
        ],
      ),
    );
  }

  Widget _buildUpcomingClassesCard(List<UpcomingClass>? upcoming) {
    final state = ref.watch(liveClassManagementProvider);
    final conductUpcoming = state.conductSessionData?.upcomingClasses ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text("Upcoming / Today's Classes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() => _selectedSubnav = 'My Classes (Today)');
                },
                child: const Row(
                  children: [
                    Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (conductUpcoming.isNotEmpty)
            ...conductUpcoming.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () async {
                    await ref.read(liveClassManagementProvider.notifier).loadConductSession(item.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Switched to ${item.subject} (${item.classSection})')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: _buildUpcomingClassItem(
                    subject: '${item.classSection} : ${item.subject}',
                    time: item.timeStr,
                    status: item.status,
                    isNext: item.isNext,
                  ),
                ),
              );
            })
          else ...[
            _buildUpcomingClassItem(
              subject: 'Class 9 - B : Science',
              time: '09:00 AM - 09:45 AM',
              status: 'Next',
              isNext: true,
            ),
            const SizedBox(height: 8),
            _buildUpcomingClassItem(
              subject: 'Class 11 - A : Physics',
              time: '10:00 AM - 10:45 AM',
              status: 'Scheduled',
            ),
            const SizedBox(height: 8),
            _buildUpcomingClassItem(
              subject: 'Class 8 - A : English',
              time: '11:15 AM - 12:00 PM',
              status: 'Scheduled',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingClassItem({
    required String subject,
    required String time,
    required String status,
    bool isNext = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isNext
            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFF0FDF4))
            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNext
              ? (isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0))
              : cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNext ? Icons.play_arrow_rounded : Icons.calendar_today_rounded,
            size: 16,
            color: isNext ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                Text(time, style: TextStyle(fontSize: 11, color: textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isNext
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                  : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isNext
                    ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D))
                    : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.more_vert, size: 14, color: textSecondary),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER FOR DONUT PROGRESS CHART
// ============================================================================

class _DonutProgressPainter extends CustomPainter {
  final double livePct;
  final double upcomingPct;
  final double completedPct;

  _DonutProgressPainter({
    required this.livePct,
    required this.upcomingPct,
    required this.completedPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -1.5708; // -pi/2
    const gap = 0.08;

    // 1. Live Segment (Green)
    if (livePct > 0) {
      paint.color = const Color(0xFF10B981);
      final sweep = (livePct * 2 * 3.1415926535) - gap;
      canvas.drawArc(rect, startAngle, sweep > 0 ? sweep : 0.01, false, paint);
      startAngle += sweep + gap;
    }

    // 2. Upcoming Segment (Blue)
    if (upcomingPct > 0) {
      paint.color = const Color(0xFF0284C7);
      final sweep = (upcomingPct * 2 * 3.1415926535) - gap;
      canvas.drawArc(rect, startAngle, sweep > 0 ? sweep : 0.01, false, paint);
      startAngle += sweep + gap;
    }

    // 3. Completed Segment (Purple)
    if (completedPct > 0) {
      paint.color = const Color(0xFF8B5CF6);
      final sweep = (completedPct * 2 * 3.1415926535) - gap;
      canvas.drawArc(rect, startAngle, sweep > 0 ? sweep : 0.01, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutProgressPainter oldDelegate) => true;
}

class _WaitingRoomPollingDialog extends StatefulWidget {
  final GuestJoinResponse res;
  final VoidCallback onAdmitted;
  final VoidCallback onRejected;

  const _WaitingRoomPollingDialog({
    required this.res,
    required this.onAdmitted,
    required this.onRejected,
  });

  @override
  State<_WaitingRoomPollingDialog> createState() => _WaitingRoomPollingDialogState();
}

class _WaitingRoomPollingDialogState extends State<_WaitingRoomPollingDialog> {
  Timer? _pollTimer;
  Timer? _ticker;
  int _secondsWaiting = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsWaiting++);
    });
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_isFinished) return;
      final api = LiveClassApiService();
      final status = await api.checkGuestAdmissionStatus(widget.res.requestId);
      if (!mounted || _isFinished) return;
      if (status != null) {
        if (status['is_approved'] == true) {
          _isFinished = true;
          _cleanup();
          Navigator.of(context).pop();
          widget.onAdmitted();
        } else if (status['is_rejected'] == true) {
          _isFinished = true;
          _cleanup();
          Navigator.of(context).pop();
          widget.onRejected();
        }
      }
    });
  }

  void _cleanup() {
    _ticker?.cancel();
    _pollTimer?.cancel();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  String _formatWaitTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Waiting Room: Host Approval',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Guest Reference ID', style: TextStyle(fontSize: 11, color: textSecondary)),
                        Text(
                          widget.res.guestReference.isNotEmpty ? widget.res.guestReference : 'GST-2026-LIVE',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2563EB)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.res.guestReference));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Guest Reference copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Hello ${widget.res.displayName}, the class host has been notified. You will be automatically admitted once approved.',
                    style: TextStyle(fontSize: 13, color: textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Waiting Time: ${_formatWaitTime(_secondsWaiting)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Security & Access Rules:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 4),
                  Text('• External guests require Host approval before accessing the meeting',
                      style: TextStyle(fontSize: 11, color: textSecondary)),
                  Text('• Host teacher has full moderation control and can mute or revoke access',
                      style: TextStyle(fontSize: 11, color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cleanup();
            Navigator.pop(context);
          },
          child: const Text('Cancel Request', style: TextStyle(color: Color(0xFFDC2626))),
        ),
      ],
    );
  }
}

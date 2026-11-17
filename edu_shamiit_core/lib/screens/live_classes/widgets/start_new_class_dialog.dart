import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../calendar/widgets/dialogs/create_edit_schedule_dialog.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../providers/live_class_management_provider.dart';

/// Unified Start New Live Class Dialog that directly reuses the
/// Calendar screen's tabbed CreateEditScheduleDialog architecture.
class StartNewClassDialog extends ConsumerWidget {
  const StartNewClassDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarProvider);
    final calendarNotifier = ref.read(calendarProvider.notifier);
    final liveClassNotifier = ref.read(liveClassManagementProvider.notifier);

    return CreateEditScheduleDialog(
      defaultScheduleType: 'Class',
      defaultDateTime: DateTime.now(),
      calendars: calendarState.calendars,
      resources: calendarState.resources,
      isLiveClass: true,
      onSave: (payload, {recurrenceScope = 'entire_series', targetInstanceDate}) async {
        try {
          // 1. Create calendar schedule
          await calendarNotifier.createSchedule(payload);

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
            'max_participants': 50,
          };

          await liveClassNotifier.createInstantClass(liveClassPayload);
          await liveClassNotifier.refreshJoinConduct();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF10B981),
                content: Text('Live Class scheduled successfully and synchronized with Calendar!'),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.redAccent,
                content: Text('Error scheduling live class: $e'),
              ),
            );
          }
        }
      },
    );
  }
}

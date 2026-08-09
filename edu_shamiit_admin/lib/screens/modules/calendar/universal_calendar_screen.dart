import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'models/calendar_models.dart';
import 'providers/calendar_provider.dart';
import 'widgets/calendar_header.dart';
import 'widgets/calendar_filter_bar.dart';
import 'widgets/calendar_legend_bar.dart';
import 'widgets/calendar_right_panel.dart';
import 'widgets/views/calendar_week_view.dart';
import 'widgets/views/calendar_day_view.dart';
import 'widgets/views/calendar_month_view.dart';
import 'widgets/views/calendar_agenda_view.dart';
import 'widgets/views/calendar_timeline_view.dart';
import 'widgets/dialogs/create_edit_schedule_dialog.dart';
import 'widgets/dialogs/event_detail_dialog.dart';
import 'widgets/dialogs/quick_event_create_popover.dart';
import 'widgets/dialogs/conflict_warning_dialog.dart';
import 'widgets/dialogs/recurrence_scope_dialog.dart';
import 'widgets/dialogs/add_calendar_dialog.dart';

class UniversalCalendarScreen extends ConsumerStatefulWidget {
  const UniversalCalendarScreen({super.key});

  @override
  ConsumerState<UniversalCalendarScreen> createState() => _UniversalCalendarScreenState();
}

class _UniversalCalendarScreenState extends ConsumerState<UniversalCalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(calendarProvider.notifier).loadAll();
      }
    });
  }

  // Open Full Create Schedule Modal
  void _openCreateScheduleModal({String? scheduleType, DateTime? dateTime, int? hour, ScheduleModel? editSchedule}) {
    final state = ref.read(calendarProvider);
    final notifier = ref.read(calendarProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return CreateEditScheduleDialog(
          initialSchedule: editSchedule,
          defaultScheduleType: scheduleType,
          defaultDateTime: dateTime ?? state.selectedDate,
          defaultHour: hour,
          calendars: state.calendars,
          resources: state.resources,
          onSave: (payload, {recurrenceScope = 'entire_series', targetInstanceDate}) async {
            if (editSchedule != null) {
              final res = await notifier.updateSchedule(
                editSchedule.id,
                payload,
                recurrenceScope: recurrenceScope,
                targetInstanceDate: targetInstanceDate,
              );
              if (!mounted) return;
              if (res['success'] == true) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Schedule updated successfully')),
                );
              } else if (res['error'] != null) {
                _handleConflictError(res['error']);
              }
            } else {
              final res = await notifier.createSchedule(payload);
              if (!mounted) return;
              if (res['success'] == true) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Schedule created successfully')),
                );
              } else if (res['error'] != null) {
                _handleConflictError(res['error']);
              }
            }
          },
        );
      },
    );
  }

  // Handle Smart Conflict Warning Dialog
  void _handleConflictError(dynamic errorData) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (errorData is Map && errorData['code'] == 'SCHEDULE_CONFLICT') {
      final conflicts = errorData['conflicts'] as List<dynamic>? ?? [];
      showDialog(
        context: context,
        builder: (ctx) {
          return ConflictWarningDialog(
            conflicts: conflicts,
            onContinueAnyway: () {
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Override applied.')),
                );
              }
            },
            onFindAvailableTime: () {
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Finding next available open time slot...')),
                );
              }
            },
          );
        },
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(errorData.toString())),
      );
    }
  }

  // Open Rich Event Detail Popup
  void _openEventDetailPopup(ScheduleModel schedule) {
    final notifier = ref.read(calendarProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return EventDetailDialog(
          schedule: schedule,
          onEdit: () {
            _openCreateScheduleModal(editSchedule: schedule);
          },
          onDuplicate: () async {
            await notifier.duplicateSchedule(schedule.id);
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Schedule duplicated successfully')),
            );
          },
          onDelete: () {
            _handleDeleteSchedule(schedule);
          },
          onCancel: (reason) async {
            final ok = await notifier.cancelSchedule(schedule.id, reason: reason);
            if (!mounted) return;
            if (ok) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Schedule cancelled successfully.')),
              );
            } else {
              messenger.showSnackBar(
                const SnackBar(content: Text('Failed to cancel schedule or permission denied.')),
              );
            }
          },
          onRSVP: (status, reason) async {
            final notifier = ref.read(calendarProvider.notifier);
            final messenger = ScaffoldMessenger.of(context);
            final ok = await notifier.submitRSVP(schedule.id, status, declineReason: reason);
            if (!mounted) return;
            if (ok) {
              messenger.showSnackBar(
                SnackBar(content: Text('RSVP saved as ${status.toUpperCase()}.')),
              );
            }
          },
          onAddComment: (commentText) async {
            final notifier = ref.read(calendarProvider.notifier);
            await notifier.addComment(schedule.id, commentText);
          },
        );
      },
    );
  }

  // Handle Delete with Recurrence Scope
  void _handleDeleteSchedule(ScheduleModel schedule) {
    final notifier = ref.read(calendarProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (schedule.isRecurring || schedule.recurringParentId != null) {
      showDialog(
        context: context,
        builder: (ctx) {
          return RecurrenceScopeDialog(
            actionTitle: 'Delete Recurring Schedule',
            onScopeSelected: (scope) async {
              final instanceDate = schedule.startTime.toIso8601String().split('T')[0];
              await notifier.deleteSchedule(
                schedule.id,
                recurrenceScope: scope,
                targetInstanceDate: instanceDate,
              );
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Recurring schedule deleted.')),
              );
            },
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Schedule?'),
            content: Text('Are you sure you want to delete "${schedule.title}"? You can restore recently deleted schedules.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await notifier.deleteSchedule(schedule.id);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Schedule deleted successfully.')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    }
  }

  // Handle Click on Empty Calendar Slot -> Quick Event Create Popover
  void _onSlotClick(DateTime dateTime, int hour) {
    final notifier = ref.read(calendarProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return QuickEventCreatePopover(
          selectedDate: dateTime,
          hour: hour,
          onSave: (title, type, start, end) async {
            final payload = {
              'title': title,
              'schedule_type': type,
              'start_time': start.toIso8601String(),
              'end_time': end.toIso8601String(),
              'category': 'General',
              'color': '#4F46E5',
            };
            final res = await notifier.createSchedule(payload);
            if (!mounted) return;
            if (res['success'] == true) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Schedule created.')),
              );
            }
          },
          onMoreOptions: () {
            _openCreateScheduleModal(dateTime: dateTime, hour: hour);
          },
        );
      },
    );
  }

  // Open Add Custom Calendar Dialog
  void _openAddCalendarDialog() {
    final notifier = ref.read(calendarProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AddCalendarDialog(
          onSave: (name, color, type) async {
            final success = await notifier.createCalendar(name, color, type);
            if (!mounted) return;
            if (success) {
              messenger.showSnackBar(
                SnackBar(content: Text("Calendar '$name' created.")),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Work Area (Header + Filter Bar + Active View + Legend)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                CalendarHeaderWidget(
                  onCreateSchedule: () => _openCreateScheduleModal(),
                  onSelectScheduleType: (type) => _openCreateScheduleModal(scheduleType: type),
                ),

                // Calendar Filter Pills Bar
                CalendarFilterBarWidget(
                  onAddCalendar: _openAddCalendarDialog,
                ),

                // Dynamic Calendar View Stage
                Expanded(
                  child: _buildActiveView(state),
                ),

                // Bottom Legend Bar
                const CalendarLegendBarWidget(),
              ],
            ),
          ),

          // Right Intelligence Panel (Desktop)
          if (isDesktop && state.isRightPanelOpen)
            CalendarRightPanelWidget(
              onSelectSchedule: (schedule) => _openEventDetailPopup(schedule),
              onOpenCreate: () => _openCreateScheduleModal(),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveView(CalendarState state) {
    switch (state.viewMode) {
      case CalendarViewMode.day:
        return CalendarDayView(
          selectedDate: state.selectedDate,
          schedules: state.schedules,
          onEventTap: _openEventDetailPopup,
          onSlotTap: _onSlotClick,
        );
      case CalendarViewMode.threeDay:
      case CalendarViewMode.week:
        return CalendarWeekViewWidget(
          selectedDate: state.selectedDate,
          schedules: state.schedules,
          onEventTap: _openEventDetailPopup,
          onSlotTap: _onSlotClick,
        );
      case CalendarViewMode.month:
        return CalendarMonthView(
          selectedDate: state.selectedDate,
          schedules: state.schedules,
          onEventTap: _openEventDetailPopup,
          onSlotTap: _onSlotClick,
        );
      case CalendarViewMode.agenda:
      case CalendarViewMode.year:
        return CalendarAgendaView(
          selectedDate: state.selectedDate,
          schedules: state.schedules,
          onEventTap: _openEventDetailPopup,
        );
      case CalendarViewMode.timeline:
        return CalendarTimelineView(
          selectedDate: state.selectedDate,
          schedules: state.schedules,
          resources: state.resources,
          onEventTap: _openEventDetailPopup,
        );
    }
  }
}

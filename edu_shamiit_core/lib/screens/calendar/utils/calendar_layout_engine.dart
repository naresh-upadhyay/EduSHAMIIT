import 'package:flutter/material.dart';
import '../models/calendar_models.dart';

class PositionedCalendarEvent {
  final ScheduleModel event;
  final int laneIndex;
  final int totalLanes;
  final double top;
  final double height;

  PositionedCalendarEvent({
    required this.event,
    required this.laneIndex,
    required this.totalLanes,
    required this.top,
    required this.height,
  });
}

class CalendarLayoutEngine {
  /// Computes side-by-side positioning for overlapping / duplicated events
  /// using an Interval Graph greedy lane assignment algorithm (similar to Google Calendar).
  static List<PositionedCalendarEvent> computePositionedEvents(
    List<ScheduleModel> dayEvents,
    DateTime day, {
    double hourHeight = 60.0,
    double minHeight = 24.0,
  }) {
    if (dayEvents.isEmpty) return [];

    // 1. Sort by startTime ascending, then duration descending, then id
    final sorted = List<ScheduleModel>.from(dayEvents)..sort((a, b) {
      final startComp = a.startTime.compareTo(b.startTime);
      if (startComp != 0) return startComp;
      final durA = a.endTime.difference(a.startTime);
      final durB = b.endTime.difference(b.startTime);
      final durComp = durB.compareTo(durA);
      if (durComp != 0) return durComp;
      return a.id.compareTo(b.id);
    });

    // 2. Group into overlapping clusters
    final List<List<ScheduleModel>> clusters = [];
    List<ScheduleModel> currentCluster = [];
    DateTime? clusterEnd;

    for (final event in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster.add(event);
        clusterEnd = event.endTime;
      } else {
        if (event.startTime.isBefore(clusterEnd!)) {
          currentCluster.add(event);
          if (event.endTime.isAfter(clusterEnd)) {
            clusterEnd = event.endTime;
          }
        } else {
          clusters.add(currentCluster);
          currentCluster = [event];
          clusterEnd = event.endTime;
        }
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<PositionedCalendarEvent> result = [];

    // 3. Assign lanes within each cluster
    for (final cluster in clusters) {
      final List<DateTime> laneEndTimes = [];
      final List<int> assignedLanes = [];

      for (final event in cluster) {
        int assignedLane = -1;
        for (int i = 0; i < laneEndTimes.length; i++) {
          if (!laneEndTimes[i].isAfter(event.startTime)) {
            assignedLane = i;
            laneEndTimes[i] = event.endTime;
            break;
          }
        }
        if (assignedLane == -1) {
          assignedLane = laneEndTimes.length;
          laneEndTimes.add(event.endTime);
        }
        assignedLanes.add(assignedLane);
      }

      final totalLanes = laneEndTimes.length;

      for (int i = 0; i < cluster.length; i++) {
        final event = cluster[i];
        final lane = assignedLanes[i];

        final isStartDay = DateUtils.isSameDay(event.startTime, day);
        final isEndDay = DateUtils.isSameDay(event.endTime, day);

        final startMin = isStartDay ? (event.startTime.hour * 60 + event.startTime.minute) : 0;
        final endMin = isEndDay ? (event.endTime.hour * 60 + event.endTime.minute) : (24 * 60);
        final durationMin = (endMin - startMin).clamp(20, 24 * 60);

        final top = (startMin / 60.0) * hourHeight;
        final height = ((durationMin / 60.0) * hourHeight).clamp(minHeight, 24 * hourHeight);

        result.add(PositionedCalendarEvent(
          event: event,
          laneIndex: lane,
          totalLanes: totalLanes,
          top: top,
          height: height,
        ));
      }
    }

    return result;
  }
}

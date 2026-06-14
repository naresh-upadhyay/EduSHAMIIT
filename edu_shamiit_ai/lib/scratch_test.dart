import 'dart:convert';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

void main() {
  final rawJson = '{"id": "24728472-a4d8-4a21-bf92-594e765218ea", "title": "parabola", "exam_date": "2026-06-12", "start_time": "2026-06-12T09:00:00+00:00", "created_at": "2026-06-11T13:48:19.604127+00:00", "exam_type": "online", "exam_category": "Unit Test"}';
  final exam = TeacherExam.fromJson(json.decode(rawJson));
  print('startTime: ${exam.startTime}');
}

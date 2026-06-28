import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart';
import 'dart:convert';

void main() {
  test('Test parsing of start_time and new stats/status fields', () {
    const rawJson =
        '{"id": "24728472-a4d8-4a21-bf92-594e765218ea", "title": "parabola", "exam_date": "2026-06-12", "start_time": "2026-06-12T09:00:00+00:00", "created_at": "2026-06-11T13:48:19.604127+00:00", "exam_type": "online", "exam_category": "Unit Test", "question_count": 5, "joined_count": 10, "completed_count": 8, "status": "ready"}';
    final exam = TeacherExam.fromJson(json.decode(rawJson));
    print('exam.startTime: ${exam.startTime}');
    print('exam.questionCount: ${exam.questionCount}');
    print('exam.joinedCount: ${exam.joinedCount}');
    print('exam.completedCount: ${exam.completedCount}');
    print('exam.status: ${exam.status}');

    expect(exam.startTime, isNotNull);
    expect(exam.questionCount, equals(5));
    expect(exam.joinedCount, equals(10));
    expect(exam.completedCount, equals(8));
    expect(exam.status, equals('ready'));
  });
}

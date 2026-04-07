/// Mock data constants for API fallback
/// This file contains mock data that will be used when API calls fail
/// To disable mock data, simply delete this file

class MockData {
  // Common response wrapper
  static Map<String, dynamic> _wrapData(dynamic data) {
    return {
      'success': true,
      'school_id': '11111111-1111-1111-1111-111111111111',
      'data': data,
    };
  }

  // ============================================
  // STUDENT PROFILE
  // ============================================
  static Map<String, dynamic> studentProfile = _wrapData({
    'student_id': 'STU-2024-1082',
    'name': 'Arjun Kumar',
    'class': 'X-A',
    'roll_no': '18',
    'section': 'A',
    'gender': 'Male',
    'date_of_birth': '2009-10-12',
    'blood_group': 'O+',
    'email': 'arjun.kumar@eduverse.in',
    'phone': '+91-9876543210',
    'address': '42, Rajpur Road, Dehradun, Uttarakhand',
    'guardian_name': 'Rajesh Kumar',
    'guardian_phone': '+91-9876543210',
    'house': 'Blue House',
    'admission_no': 'EV/2024/1082',
    'session': '2024-25',
  });

  // ============================================
  // ATTENDANCE
  // ============================================
  static Map<String, dynamic> attendanceSummary = _wrapData({
    'total_days': 172,
    'present_days': 162,
    'absent_days': 10,
    'percentage': 94.0,
    'monthly_breakdown': [
      {'month': 'January', 'present': 20, 'absent': 0, 'total': 20},
      {'month': 'February', 'present': 22, 'absent': 2, 'total': 24},
      {'month': 'March', 'present': 25, 'absent': 1, 'total': 26},
    ],
  });

  static List<dynamic> attendanceRecords = [
    {'date': '2026-03-26', 'status': 'present', 'period': 'full'},
    {'date': '2026-03-25', 'status': 'present', 'period': 'full'},
    {'date': '2026-03-24', 'status': 'present', 'period': 'full'},
    {'date': '2026-03-23', 'status': 'absent', 'period': 'full'},
    {'date': '2026-03-22', 'status': 'present', 'period': 'full'},
  ];

  // ============================================
  // HOMEWORK
  // ============================================
  static List<dynamic> homeworkAssignments = [
    {
      'id': 'HW001',
      'subject': 'Mathematics',
      'title': 'Integration Practice Set — Chapter 7',
      'description': 'Solve all 5 problems from page 128-130. Show full working.',
      'due_date': '2026-03-27T17:00:00',
      'status': 'pending',
      'teacher_name': 'Mr. R. Sharma',
      'max_marks': 25,
    },
    {
      'id': 'HW002',
      'subject': 'Chemistry',
      'title': 'Titration Lab Report — Acid-Base',
      'description': 'Write a detailed lab report with aim, theory, observations, and conclusion.',
      'due_date': '2026-03-28T17:00:00',
      'status': 'pending',
      'teacher_name': 'Dr. S. Mehta',
      'max_marks': 20,
    },
    {
      'id': 'HW003',
      'subject': 'English',
      'title': 'Essay: The Role of AI in Education',
      'description': 'Write a 500-word essay with pros, cons and personal perspective.',
      'due_date': '2026-03-30T17:00:00',
      'status': 'pending',
      'teacher_name': 'Ms. P. Gupta',
      'max_marks': 15,
    },
  ];

  // ============================================
  // EXAMS & RESULTS
  // ============================================
  static List<dynamic> upcomingExams = [
    {
      'id': 'EX001',
      'subject': 'Mathematics',
      'title': 'Final Exam',
      'date': '2026-03-28T09:00:00',
      'duration_minutes': 180,
      'venue': 'Hall A',
      'max_marks': 100,
    },
    {
      'id': 'EX002',
      'subject': 'Physics',
      'title': 'Final Exam',
      'date': '2026-03-30T09:00:00',
      'duration_minutes': 180,
      'venue': 'Hall B',
      'max_marks': 100,
    },
    {
      'id': 'EX003',
      'subject': 'Chemistry',
      'title': 'Final Exam',
      'date': '2026-04-01T09:00:00',
      'duration_minutes': 180,
      'venue': 'Lab 2',
      'max_marks': 100,
    },
  ];

  static List<dynamic> examResults = [
    {
      'id': 'R001',
      'subject': 'Mathematics',
      'exam_type': 'Mid-Term',
      'marks_obtained': 95,
      'max_marks': 100,
      'percentage': 95.0,
      'grade': 'A+',
      'date': '2026-02-15',
    },
    {
      'id': 'R002',
      'subject': 'Physics',
      'exam_type': 'Mid-Term',
      'marks_obtained': 89,
      'max_marks': 100,
      'percentage': 89.0,
      'grade': 'A',
      'date': '2026-02-16',
    },
    {
      'id': 'R003',
      'subject': 'Chemistry',
      'exam_type': 'Mid-Term',
      'marks_obtained': 91,
      'max_marks': 100,
      'percentage': 91.0,
      'grade': 'A',
      'date': '2026-02-17',
    },
  ];

  // ============================================
  // FEES
  // ============================================
  static List<dynamic> feeRecords = [
    {
      'id': 'FEE001',
      'type': 'Tuition Fee — Q4',
      'amount': 8500,
      'due_date': '2026-04-05',
      'status': 'pending',
      'description': 'Quarter 4 tuition fee',
    },
    {
      'id': 'FEE002',
      'type': 'Transport Fee — Mar',
      'amount': 2000,
      'due_date': '2026-03-31',
      'status': 'partial',
      'paid_amount': 1000,
      'description': 'Monthly transport fee',
    },
    {
      'id': 'FEE003',
      'type': 'Lab Fee — Annual',
      'amount': 2000,
      'due_date': '2026-01-15',
      'status': 'paid',
      'paid_amount': 2000,
      'description': 'Annual laboratory fee',
    },
  ];

  // ============================================
  // TIMETABLE
  // ============================================
  static List<dynamic> timetable = [
    {
      'period': 1,
      'subject': 'Mathematics',
      'teacher': 'Mr. R. Sharma',
      'room': '301',
      'start_time': '08:00',
      'end_time': '09:00',
    },
    {
      'period': 2,
      'subject': 'Physics',
      'teacher': 'Dr. A. Verma',
      'room': 'Lab 2',
      'start_time': '09:00',
      'end_time': '10:00',
    },
    {
      'period': 3,
      'subject': 'English',
      'teacher': 'Ms. P. Gupta',
      'room': '204',
      'start_time': '10:20',
      'end_time': '11:20',
    },
    {
      'period': 4,
      'subject': 'Chemistry',
      'teacher': 'Dr. S. Mehta',
      'room': 'Lab 1',
      'start_time': '11:20',
      'end_time': '12:20',
    },
    {
      'period': 5,
      'subject': 'History',
      'teacher': 'Mrs. K. Rao',
      'room': '102',
      'start_time': '13:00',
      'end_time': '14:00',
    },
    {
      'period': 6,
      'subject': 'Computer Science',
      'teacher': 'Mr. V. Jain',
      'room': 'Lab 3',
      'start_time': '14:00',
      'end_time': '15:00',
    },
  ];

  // ============================================
  // LIVE CLASSES
  // ============================================
  static List<dynamic> liveClasses = [
    {
      'id': 'LC001',
      'subject': 'Physics',
      'title': 'Optics Chapter 9',
      'teacher': 'Dr. A. Verma',
      'status': 'live',
      'started_at': '2026-03-27T09:00:00',
      'meeting_link': 'https://meet.eduverse.in/physics-optics',
      'participants': 34,
    },
    {
      'id': 'LC002',
      'subject': 'Mathematics',
      'title': 'Integration by Parts',
      'teacher': 'Mr. R. Sharma',
      'status': 'scheduled',
      'scheduled_at': '2026-03-27T14:00:00',
      'meeting_link': 'https://meet.eduverse.in/math-integration',
    },
  ];

  // ============================================
  // NOTICES
  // ============================================
  static List<dynamic> notices = [
    {
      'id': 'N001',
      'title': 'Exam Hall Ticket Collection',
      'category': 'urgent',
      'content': 'Collect your hall tickets from the school office between 9:00 AM — 3:00 PM.',
      'date': '2026-03-22',
      'author': 'Principal',
    },
    {
      'id': 'N002',
      'title': 'Fee Payment Deadline Extended',
      'category': 'urgent',
      'content': 'Fee submission deadline extended to April 5, 2026.',
      'date': '2026-03-20',
      'author': 'Accounts Department',
    },
    {
      'id': 'N003',
      'title': 'Annual Sports Day Registration',
      'category': 'event',
      'content': 'Register for Sports Day events by March 29.',
      'date': '2026-03-18',
      'author': 'Sports Dept.',
    },
  ];

  // ============================================
  // NOTIFICATIONS
  // ============================================
  static List<dynamic> notifications = [
    {
      'id': 'NOT001',
      'title': 'Homework Due Today!',
      'message': 'Integration Practice Set due at 5 PM',
      'type': 'academic',
      'read': false,
      'timestamp': '2026-03-27T09:30:00',
    },
    {
      'id': 'NOT002',
      'title': 'Fee Reminder',
      'message': '₹12,500 due by April 5',
      'type': 'administrative',
      'read': false,
      'timestamp': '2026-03-27T08:00:00',
    },
    {
      'id': 'NOT003',
      'title': 'Results Published!',
      'message': 'Term 2 results are now available',
      'type': 'academic',
      'read': true,
      'timestamp': '2026-03-27T06:00:00',
    },
  ];

  // ============================================
  // EVENTS
  // ============================================
  static List<dynamic> events = [
    {
      'id': 'EVT001',
      'title': 'Annual Sports Day',
      'description': '100m Sprint, Long Jump, Relay Race, Cricket & Badminton.',
      'date': '2026-04-05T08:00:00',
      'venue': 'Sports Ground',
      'registered': true,
    },
    {
      'id': 'EVT002',
      'title': 'Science Exhibition 2026',
      'description': 'Top 3 winners get scholarships. Open to all classes.',
      'date': '2026-04-10T09:00:00',
      'venue': 'School Hall',
      'registered': false,
    },
    {
      'id': 'EVT003',
      'title': 'Inter-School Debate',
      'description': 'Annual debate competition with neighboring schools.',
      'date': '2026-04-15T10:00:00',
      'venue': 'Auditorium',
      'registered': false,
    },
  ];

  // ============================================
  // ACHIEVEMENTS
  // ============================================
  static List<dynamic> achievements = [
    {
      'id': 'ACH001',
      'title': 'Academic Excellence',
      'description': 'Scored 90%+ in Term 2 exams.',
      'icon': '🏆',
      'earned': true,
      'earned_date': '2026-03-15',
      'xp': 500,
    },
    {
      'id': 'ACH002',
      'title': '18-Day Streak',
      'description': 'Logged in 18 consecutive days.',
      'icon': '🔥',
      'earned': true,
      'earned_date': '2026-03-27',
      'xp': 200,
    },
    {
      'id': 'ACH003',
      'title': 'Zero Late Submissions',
      'description': 'All homework on time this term.',
      'icon': '✅',
      'earned': true,
      'earned_date': '2026-03-01',
      'xp': 300,
    },
  ];

  // ============================================
  // LEADERBOARD
  // ============================================
  static List<dynamic> leaderboard = [
    {'rank': 1, 'name': 'Priya Mehta', 'score': 92.8, 'xp': 2680},
    {'rank': 2, 'name': 'Rahul Verma', 'score': 94.2, 'xp': 3120},
    {'rank': 3, 'name': 'Arjun Kumar (You)', 'score': 91.4, 'xp': 2450},
    {'rank': 4, 'name': 'Sneha Patel', 'score': 89.6, 'xp': 2120},
    {'rank': 5, 'name': 'Vikram Singh', 'score': 88.2, 'xp': 1980},
  ];

  // ============================================
  // LEAVE
  // ============================================
  static List<dynamic> leaveApplications = [
    {
      'id': 'LV001',
      'type': 'Family Event',
      'start_date': '2026-04-12',
      'end_date': '2026-04-14',
      'reason': "Attend my sister's wedding.",
      'status': 'pending',
      'applied_date': '2026-03-25',
    },
    {
      'id': 'LV002',
      'type': 'Sick Leave',
      'start_date': '2026-02-08',
      'end_date': '2026-02-09',
      'reason': 'Suffering from viral fever.',
      'status': 'approved',
      'applied_date': '2026-02-07',
    },
  ];

  // ============================================
  // LIBRARY
  // ============================================
  static List<dynamic> libraryBooks = [
    {
      'id': 'LIB001',
      'title': 'NCERT Physics Part II',
      'author': 'NCERT',
      'category': 'Textbook',
      'available': true,
      'copies': 5,
    },
    {
      'id': 'LIB002',
      'title': 'H.C. Verma Vol.1',
      'author': 'H.C. Verma',
      'category': 'Reference',
      'available': true,
      'copies': 3,
    },
    {
      'id': 'LIB003',
      'title': 'R.D. Sharma Class X',
      'author': 'R.D. Sharma',
      'category': 'Textbook',
      'available': false,
      'copies': 0,
    },
  ];

  static List<dynamic> issuedBooks = [
    {
      'id': 'ISS001',
      'title': 'NCERT Physics Part II',
      'issue_date': '2026-03-10',
      'due_date': '2026-04-05',
      'status': 'issued',
    },
    {
      'id': 'ISS002',
      'title': 'H.C. Verma Vol.1',
      'issue_date': '2026-03-05',
      'due_date': '2026-03-30',
      'status': 'overdue',
    },
  ];

  // ============================================
  // COURSES
  // ============================================
  static List<dynamic> courses = [
    {
      'id': 'CRS001',
      'name': 'Mathematics',
      'teacher': 'Mr. R. Sharma',
      'chapters': 42,
      'progress': 78,
      'score': 95,
    },
    {
      'id': 'CRS002',
      'name': 'Physics',
      'teacher': 'Dr. A. Verma',
      'chapters': 38,
      'progress': 72,
      'score': 89,
    },
    {
      'id': 'CRS003',
      'name': 'Chemistry',
      'teacher': 'Dr. S. Mehta',
      'chapters': 35,
      'progress': 80,
      'score': 91,
    },
    {
      'id': 'CRS004',
      'name': 'English',
      'teacher': 'Ms. P. Gupta',
      'chapters': 28,
      'progress': 85,
      'score': 92,
    },
  ];

  // ============================================
  // MESSAGES
  // ============================================
  static List<dynamic> messages = [
    {
      'id': 'MSG001',
      'sender_id': 'TCH001',
      'sender_name': 'Mr. R. Sharma',
      'content': 'Sure, I\'ll cover integration by parts one more time.',
      'timestamp': '2026-03-27T15:25:00',
      'is_sent': false,
    },
    {
      'id': 'MSG002',
      'sender_id': 'STU-2024-1082',
      'sender_name': 'Arjun Kumar',
      'content': 'Sir, can you explain integration by parts one more time?',
      'timestamp': '2026-03-27T15:20:00',
      'is_sent': true,
    },
  ];

  // ============================================
  // TRANSPORT
  // ============================================
  static Map<String, dynamic> transportRoute = _wrapData({
    'route_no': '7B',
    'bus_no': 'HR-29-3847',
    'driver_name': 'Mr. Singh',
    'driver_phone': '+91-9876543211',
    'current_location': {'lat': 30.3165, 'lng': 78.0322},
    'eta_minutes': 8,
    'stops': [
      {'name': 'School Gate', 'time': '15:30', 'status': 'upcoming'},
      {'name': 'Civil Lines', 'time': '15:42', 'status': 'completed'},
      {'name': 'Rajpur Stop (Yours)', 'time': '15:50', 'status': 'upcoming'},
      {'name': 'Shastri Nagar', 'time': '16:00', 'status': 'upcoming'},
    ],
    'students_onboard': 38,
  });

  // ============================================
  // PERFORMANCE ANALYTICS
  // ============================================
  static List<dynamic> performanceAnalytics = [
    {
      'subject': 'Mathematics',
      'current_score': 95,
      'trend': 'improving',
      'weak_areas': ['Integration', 'Calculus'],
      'strong_areas': ['Algebra', 'Trigonometry'],
    },
    {
      'subject': 'Physics',
      'current_score': 89,
      'trend': 'stable',
      'weak_areas': ['Optics'],
      'strong_areas': ['Mechanics', 'Thermodynamics'],
    },
    {
      'subject': 'Chemistry',
      'current_score': 91,
      'trend': 'improving',
      'weak_areas': ['Electrochemistry'],
      'strong_areas': ['Organic Chemistry', 'Periodic Table'],
    },
  ];
}
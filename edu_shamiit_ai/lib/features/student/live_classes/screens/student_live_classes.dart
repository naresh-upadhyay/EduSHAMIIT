import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/live_classes_provider.dart';

class StudentLiveClasses extends ConsumerStatefulWidget {
  const StudentLiveClasses({super.key});

  @override
  ConsumerState<StudentLiveClasses> createState() => _StudentLiveClassesState();
}

class _StudentLiveClassesState extends ConsumerState<StudentLiveClasses> {
  @override
  Widget build(BuildContext context) {
    final liveClassesState = ref.watch(liveClassesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live Classes',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '?? ${liveClassesState.liveNow.length} Live Now',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: liveClassesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : liveClassesState.error != null
                    ? Center(child: Text('Error: ${liveClassesState.error}'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Live Now Section
                          const Text(
                            '?? LIVE NOW',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.error,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...liveClassesState.liveNow.map((cls) => _buildLiveCard(cls)),
                          
                          const SizedBox(height: 20),
                          
                          // Upcoming Section
                          const Text(
                            '?? UPCOMING TODAY',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.text3,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (liveClassesState.upcoming.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No upcoming classes today', style: TextStyle(fontSize: 11, color: StudentColors.text3)),
                            ),
                          ...liveClassesState.upcoming.map((cls) => _buildUpcomingCard(cls)),
                          
                          const SizedBox(height: 20),
                          
                          // Recorded Section
                          const Text(
                            '?? RECORDED CLASSES',
                            style: TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: StudentColors.text3,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (liveClassesState.recorded.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('No recorded classes', style: TextStyle(fontSize: 11, color: StudentColors.text3)),
                            ),
                          ...liveClassesState.recorded.map((cls) => _buildRecordedCard(cls)),
                          
                          const SizedBox(height: 50),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Video thumbnail area
          Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: cls.color ?? const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                Center(child: Text(cls.icon, style: const TextStyle(fontSize: 40))),
                // LIVE badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: StudentColors.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Viewers count
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '?? ${cls.viewers ?? 0} watching',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                // Teacher avatar
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StudentColors.primary, width: 2),
                    ),
                    child: const Center(child: Text('?????', style: TextStyle(fontSize: 20))),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cls.teacher} � ${cls.started ?? ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _joinClass(cls),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StudentColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('? Join Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: StudentColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StudentColors.border),
                      ),
                      child: const Icon(Icons.notifications_none, size: 18, color: StudentColors.text2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(cls.icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cls.teacher} � ${cls.time ?? ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: StudentColors.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cls.timeUntil ?? '',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: StudentColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordedCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StudentColors.border),
            ),
            child: const Center(child: Text('??', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cls.date ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _playRecording(cls),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('? Play', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _joinClass(LiveClassModel cls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _LiveClassDetailScreen(classData: cls),
      ),
    );
  }

  void _playRecording(LiveClassModel cls) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('?? Playing: ${cls.subject}')),
    );
  }
}

// Live Class Detail Screen (YouTube-style)
class _LiveClassDetailScreen extends StatefulWidget {
  final LiveClassModel classData;

  const _LiveClassDetailScreen({required this.classData});

  @override
  State<_LiveClassDetailScreen> createState() => _LiveClassDetailScreenState();
}

class _LiveClassDetailScreenState extends State<_LiveClassDetailScreen> {
  final List<Map<String, dynamic>> _comments = [
    {
      'user': 'Dr. A. Verma',
      'avatar': '?????',
      'text': 'Today we\'ll cover Chapter 9: Optics. Please keep your NCERT books open on page 312. Ask doubts in the comment section!',
      'time': '25 min ago',
      'likes': 45,
      'pinned': true,
    },
    {
      'user': 'Priya M',
      'avatar': 'P',
      'text': 'Sir, can you explain the ILATE rule once more?',
      'time': '20 min ago',
      'likes': 12,
    },
    {
      'user': 'Rahul V',
      'avatar': 'R',
      'text': 'This is the best explanation! Understood everything clearly ??',
      'time': '18 min ago',
      'likes': 8,
    },
    {
      'user': 'Neha S',
      'avatar': 'N',
      'text': 'Can we get a practice problem after this section? ??',
      'time': '15 min ago',
      'likes': 5,
    },
  ];

  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Video Player Area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.classData.icon, style: const TextStyle(fontSize: 60)),
                        const SizedBox(height: 8),
                        const Text(
                          'Live Class in Progress',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                // LIVE badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'LIVE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Viewers
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '??? ${widget.classData.viewers}.2k',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Teacher PIP
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 56,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: StudentColors.primary, width: 2),
                    ),
                    child: const Center(child: Text('?????', style: TextStyle(fontSize: 24))),
                  ),
                ),
                // Progress bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    color: Colors.white24,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.35,
                      child: Container(color: StudentColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Video Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classData.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.classData.viewers}.2k views � ${widget.classData.started ?? ''}',
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
                const SizedBox(height: 12),
                // Channel row
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Center(child: Text('?????', style: TextStyle(fontSize: 14))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.classData.teacher,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Mathematics Dept.',
                            style: TextStyle(fontSize: 9, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StudentColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Subscribe', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                // Action buttons
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildActionChip('?? 342'),
                      _buildActionChip('?? 12'),
                      _buildActionChip('?? Share'),
                      _buildActionChip('?? Save'),
                      _buildActionChip('?? Notes'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Comments header
          const Divider(color: Colors.white10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Text(
                  '?? Comments',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  '248',
                  style: TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.w500),
                ),
                Spacer(),
                Text(
                  'Sort by ?',
                  style: TextStyle(fontSize: 10, color: StudentColors.info, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return _buildComment(comment);
              },
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('??', style: TextStyle(fontSize: 12))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a public comment...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.white10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: (value) => _addComment(value),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addComment(_commentController.text),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, size: 13, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.primaries[DateTime.now().millisecond % Colors.primaries.length],
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(child: Text(comment['avatar'], style: const TextStyle(fontSize: 10))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['user']!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comment['time']!,
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment['text']!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('?? ${comment['likes']}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    const SizedBox(width: 10),
                    const Text('?? Reply', style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addComment(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _comments.insert(0, {
        'user': 'Arjun K (You)',
        'avatar': '??',
        'text': text,
        'time': 'Just now',
        'likes': 0,
      });
      _commentController.clear();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
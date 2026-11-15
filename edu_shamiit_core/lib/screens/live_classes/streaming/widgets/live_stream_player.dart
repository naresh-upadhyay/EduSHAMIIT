import 'package:flutter/material.dart';

class LiveStreamPlayer extends StatefulWidget {
  final String title;
  final String formattedDuration;
  final int viewers;
  final VoidCallback? onToggleFullscreen;

  const LiveStreamPlayer({
    super.key,
    required this.title,
    required this.formattedDuration,
    required this.viewers,
    this.onToggleFullscreen,
  });

  @override
  State<LiveStreamPlayer> createState() => _LiveStreamPlayerState();
}

class _LiveStreamPlayerState extends State<LiveStreamPlayer> {
  bool _isPlaying = true;
  bool _isMuted = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Simulated Classroom Video Stream Feed
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Chalkboard / Classroom Background
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B3B2B), // Blackboard dark green
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF475569), width: 3),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Quadratic Equations',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'serif',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ax\u00B2 + bx + c = 0',
                            style: TextStyle(
                              color: Colors.amber.shade200,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'x = (-b \u00B1 \u221A(b\u00B2 - 4ac)) / 2a',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'serif',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Teacher PIP overlay at bottom left of video
                  Positioned(
                    bottom: 50,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Color(0xFF2563EB),
                            child: Text(
                              'RK',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'R. Kumar (Teacher)',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.mic, color: Colors.greenAccent, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Header Overlay (LIVE pill + Viewers count)
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Red LIVE pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Viewers Glass Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group, color: Colors.white70, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        '${widget.viewers} watching',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Video Control Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _isPlaying = !_isPlaying),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _isMuted = !_isMuted),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        value: 1.0,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                        minHeight: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.closed_caption, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  const Icon(Icons.settings, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: widget.onToggleFullscreen,
                    child: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

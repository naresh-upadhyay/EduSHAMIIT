import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:edu_shamiit_core/screens/exams/services/exams_api_service.dart';
import 'package:edu_shamiit_core/screens/exams/utils/exam_nav_helper.dart';
import 'package:edu_shamiit_core/screens/exams/widgets/monitoring_donut_chart.dart';
import 'package:edu_shamiit_core/utils/download_helper.dart';

class LiveMonitoringScreen extends ConsumerStatefulWidget {
  final String examId;
  final Map<String, dynamic>? initialMonitoringDataForTest;

  const LiveMonitoringScreen({
    super.key,
    required this.examId,
    this.initialMonitoringDataForTest,
  });

  @override
  ConsumerState<LiveMonitoringScreen> createState() =>
      _LiveMonitoringScreenState();
}

enum _GridViewMode { grid4, grid2, list }

class _MonitorPalette {
  final bool isDark;
  final Color scaffoldBg;
  final Color cardBg;
  final Color subtleBg;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;
  final Color accentBlue;
  final Color greenBg;
  final Color greenText;
  final Color amberBg;
  final Color amberText;
  final Color redBg;
  final Color redText;
  final Color purpleBg;
  final Color purpleText;

  const _MonitorPalette({
    required this.isDark,
    required this.scaffoldBg,
    required this.cardBg,
    required this.subtleBg,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
    required this.accentBlue,
    required this.greenBg,
    required this.greenText,
    required this.amberBg,
    required this.amberText,
    required this.redBg,
    required this.redText,
    required this.purpleBg,
    required this.purpleText,
  });

  factory _MonitorPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _MonitorPalette(
        isDark: true,
        scaffoldBg: Color(0xFF0B1120),
        cardBg: Color(0xFF111827),
        subtleBg: Color(0xFF1E293B),
        borderColor: Color(0xFF283548),
        primaryText: Color(0xFFF1F5F9),
        secondaryText: Color(0xFF94A3B8),
        accentBlue: Color(0xFF60A5FA),
        greenBg: Color(0xFF064E3B),
        greenText: Color(0xFF34D399),
        amberBg: Color(0xFF451A03),
        amberText: Color(0xFFFBBF24),
        redBg: Color(0xFF450A0A),
        redText: Color(0xFFF87171),
        purpleBg: Color(0xFF2E1065),
        purpleText: Color(0xFFC084FC),
      );
    }
    return const _MonitorPalette(
      isDark: false,
      scaffoldBg: Color(0xFFF4F7FB),
      cardBg: Colors.white,
      subtleBg: Color(0xFFF8FAFC),
      borderColor: Color(0xFFE2E8F0),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF64748B),
      accentBlue: Color(0xFF2563EB),
      greenBg: Color(0xFFECFDF5),
      greenText: Color(0xFF16A34A),
      amberBg: Color(0xFFFFFBEB),
      amberText: Color(0xFFD97706),
      redBg: Color(0xFFFEF2F2),
      redText: Color(0xFFDC2626),
      purpleBg: Color(0xFFF5F3FF),
      purpleText: Color(0xFF7C3AED),
    );
  }
}

class _LiveMonitoringScreenState extends ConsumerState<LiveMonitoringScreen> {
  final ExamsApiService _apiService = ExamsApiService.instance;

  bool _isLoading = true;
  String? _errorMessage;

  // Overview state
  Map<String, dynamic> _exam = {};
  Map<String, dynamic> _monitoringSession = {};
  Map<String, dynamic> _kpis = {};
  List<Map<String, dynamic>> _statusBreakdown = [];
  List<Map<String, dynamic>> _announcements = [];
  int _examRemainingSeconds = 0;

  // Main navigation & grid state
  int _activeMainTab = 0; // 0: Live Monitoring, 1: Student List, 2: Violations, 3: Audit Logs, 4: Controls
  _GridViewMode _gridMode = _GridViewMode.grid4;
  final String _selectedClassFilter = 'All';
  String _selectedStatusFilter = 'All';
  String _selectedViolationFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  int _currentPage = 1;
  int _pageSize = 8;
  int _totalCandidates = 0;
  int _totalPages = 1;

  List<Map<String, dynamic>> _candidates = [];
  final Set<String> _selectedCandidateIds = {};

  // Right inspector panel
  String? _inspectedCandidateId;
  Map<String, dynamic>? _inspectedDetail;
  int _inspectorSubTab = 0; // 0: Monitoring, 1: Activity, 2: Violations, 3: More
  bool _showScreenSharePreview = false;
  bool _listenAudioSelected = false;

  // Violation reports & audit log state
  List<Map<String, dynamic>> _incidents = [];
  Map<String, dynamic> _incidentsSummary = {};
  String _incidentSeverityFilter = 'all';
  String _incidentStatusFilter = 'all';
  List<Map<String, dynamic>> _auditLogs = [];

  // Announcement composer state (Exam Controls tab)
  final TextEditingController _annTitleCtrl = TextEditingController(text: 'Important Invigilator Notice');
  final TextEditingController _annMsgCtrl = TextEditingController();
  String _annPriority = 'normal';
  String _annTargetScope = 'all';
  bool _annRequiresAck = false;
  bool _isSendingAnnouncement = false;

  // Real-time infrastructure
  Timer? _countdownTimer;
  Timer? _fallbackRefreshTimer;
  Timer? _debounceRefreshTimer;
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _wsReconnectTimer;
  bool _wsConnected = false;

  // LiveKit invigilator subscription room
  lk.Room? _livekitRoom;
  lk.EventsListener<lk.RoomEvent>? _livekitListener;
  bool _livekitConnected = false;
  final Map<String, lk.VideoTrack> _remoteCameraTracks = {};
  final Map<String, lk.VideoTrack> _remoteScreenTracks = {};
  final Map<String, lk.AudioTrack> _remoteAudioTracks = {};
  bool _isTestMode = false;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fallbackRefreshTimer?.cancel();
    _debounceRefreshTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _wsSub?.cancel();
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _disposeLivekitRoom();
    _searchCtrl.dispose();
    _annTitleCtrl.dispose();
    _annMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _disposeLivekitRoom() async {
    try {
      await _livekitListener?.dispose();
      await _livekitRoom?.disconnect();
      await _livekitRoom?.dispose();
    } catch (_) {}
    _livekitListener = null;
    _livekitRoom = null;
    _livekitConnected = false;
    _remoteCameraTracks.clear();
    _remoteScreenTracks.clear();
    _remoteAudioTracks.clear();
  }

  void _initScreen() {
    final seed = widget.initialMonitoringDataForTest;
    if (seed != null) {
      _isTestMode = true;
      _applyTestSeed(seed);
      return;
    }

    _loadInitialMonitoring();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final isExamPaused = (_monitoringSession['status'] ?? '') == 'PAUSED';
      if (!isExamPaused && _examRemainingSeconds > 0) {
        setState(() => _examRemainingSeconds--);
      }
      if (_inspectedDetail != null && _inspectedDetail!['candidate'] is Map) {
        final cand = _inspectedDetail!['candidate'] as Map<String, dynamic>;
        final paused = cand['is_paused'] == true || isExamPaused;
        final rem = (cand['remaining_seconds'] as num?)?.toInt() ?? 0;
        if (!paused && rem > 0) {
          cand['remaining_seconds'] = rem - 1;
        }
      }
    });
    _fallbackRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _refreshMonitoringData(silent: true);
      }
    });
  }

  void _applyTestSeed(Map<String, dynamic> seed) {
    final overview = Map<String, dynamic>.from(seed['overview'] as Map? ?? {});
    final candRes = Map<String, dynamic>.from(seed['candidates'] as Map? ?? {});
    final incRes = Map<String, dynamic>.from(seed['incidents'] as Map? ?? {});
    final logRes = Map<String, dynamic>.from(seed['audit_logs'] as Map? ?? {});

    final rawCands = List<dynamic>.from(candRes['candidates'] as List? ?? []);
    final cands = rawCands.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    setState(() {
      _isLoading = false;
      _exam = Map<String, dynamic>.from(overview['exam'] as Map? ?? {});
      _monitoringSession = Map<String, dynamic>.from(overview['monitoring_session'] as Map? ?? {});
      _kpis = Map<String, dynamic>.from(overview['kpis'] as Map? ?? {});
      _statusBreakdown = List<dynamic>.from(overview['status_breakdown'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _announcements = List<dynamic>.from(overview['announcements'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _examRemainingSeconds = (_exam['exam_remaining_seconds'] as num?)?.toInt() ?? 5256;
      _candidates = cands;
      final pg = Map<String, dynamic>.from(candRes['pagination'] as Map? ?? {});
      _totalCandidates = (pg['total'] as num?)?.toInt() ?? cands.length;
      _totalPages = (pg['total_pages'] as num?)?.toInt() ?? 1;
      _incidents = List<dynamic>.from(incRes['incidents'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _incidentsSummary = Map<String, dynamic>.from(incRes['summary'] as Map? ?? {});
      _auditLogs = List<dynamic>.from(logRes['logs'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (cands.isNotEmpty) {
        _inspectedCandidateId = cands.first['candidate_id']?.toString();
        _inspectedDetail = seed['candidate_detail'] is Map
            ? Map<String, dynamic>.from(seed['candidate_detail'] as Map)
            : {
                'candidate': cands.first,
                'incidents': _incidents.where((i) => i['candidate_id'] == _inspectedCandidateId).toList(),
                'actions': _auditLogs.where((a) => a['candidate_id'] == _inspectedCandidateId).toList(),
                'reentry_requests': [],
                'time_adjustments': [],
              };
      }
    });
  }

  Future<void> _loadInitialMonitoring() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ov = await _apiService.getMonitoringOverview(widget.examId);
      if (!mounted) return;
      _applyOverviewResponse(ov);
      await Future.wait([
        _loadCandidates(),
        _loadIncidents(),
        _loadAuditLogs(),
      ]);
      if (mounted) {
        setState(() => _isLoading = false);
      }

      _connectMonitoringWebSocket();
      _connectLivekitInvigilatorRoom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applyOverviewResponse(Map<String, dynamic> ov) {
    final exam = Map<String, dynamic>.from(ov['exam'] as Map? ?? {});
    setState(() {
      _exam = exam;
      _monitoringSession = Map<String, dynamic>.from(ov['monitoring_session'] as Map? ?? {});
      _kpis = Map<String, dynamic>.from(ov['kpis'] as Map? ?? {});
      _statusBreakdown = List<dynamic>.from(ov['status_breakdown'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _announcements = List<dynamic>.from(ov['announcements'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (exam['exam_remaining_seconds'] != null) {
        _examRemainingSeconds = (exam['exam_remaining_seconds'] as num).toInt();
      }
    });
  }

  Future<void> _refreshMonitoringData({bool silent = false}) async {
    if (_isTestMode) return;
    try {
      final ov = await _apiService.getMonitoringOverview(widget.examId);
      if (!mounted) return;
      _applyOverviewResponse(ov);
      await _loadCandidates();
      if (_inspectedCandidateId != null) {
        await _loadCandidateDetail(_inspectedCandidateId!);
      }
      if (_activeMainTab == 2) await _loadIncidents();
      if (_activeMainTab == 3) await _loadAuditLogs();
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadCandidates() async {
    if (_isTestMode) {
      return;
    }
    try {
      final res = await _apiService.getMonitoringCandidates(
        widget.examId,
        status: _selectedStatusFilter == 'All' ? null : _selectedStatusFilter,
        violationFilter: _selectedViolationFilter == 'All' ? null : _selectedViolationFilter,
        classFilter: _selectedClassFilter == 'All' ? null : _selectedClassFilter,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final list = List<dynamic>.from(res['candidates'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final pg = Map<String, dynamic>.from(res['pagination'] as Map? ?? {});

      setState(() {
        _candidates = list;
        _totalCandidates = (pg['total'] as num?)?.toInt() ?? list.length;
        _totalPages = (pg['total_pages'] as num?)?.toInt() ?? 1;
        if (_inspectedCandidateId == null && list.isNotEmpty) {
          _inspectedCandidateId = list.first['candidate_id']?.toString();
        }
      });

      if (_inspectedCandidateId != null && _inspectedDetail == null) {
        _loadCandidateDetail(_inspectedCandidateId!);
      }
    } catch (_) {}
  }

  Future<void> _loadCandidateDetail(String candidateId) async {
    setState(() => _inspectedCandidateId = candidateId);
    if (_isTestMode) {
      final match = _candidates.firstWhere(
        (c) => c['candidate_id']?.toString() == candidateId,
        orElse: () => _candidates.isNotEmpty ? _candidates.first : <String, dynamic>{},
      );
      setState(() {
        _inspectedDetail = {
          'candidate': match,
          'incidents': _incidents.where((i) => i['candidate_id'] == candidateId).toList(),
          'actions': _auditLogs.where((a) => a['candidate_id'] == candidateId).toList(),
          'reentry_requests': [],
          'time_adjustments': [],
        };
      });
      return;
    }
    try {
      final detail = await _apiService.getMonitoringCandidateDetail(widget.examId, candidateId);
      if (!mounted) return;
      setState(() => _inspectedDetail = detail);
    } catch (_) {}
  }

  Future<void> _loadIncidents() async {
    if (_isTestMode) return;
    try {
      final res = await _apiService.getMonitoringIncidents(
        widget.examId,
        severity: _incidentSeverityFilter == 'all' ? null : _incidentSeverityFilter,
        status: _incidentStatusFilter == 'all' ? null : _incidentStatusFilter,
      );
      if (!mounted) return;
      setState(() {
        _incidents = List<dynamic>.from(res['incidents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _incidentsSummary = Map<String, dynamic>.from(res['summary'] as Map? ?? {});
      });
    } catch (_) {}
  }

  Future<void> _loadAuditLogs() async {
    if (_isTestMode) return;
    try {
      final res = await _apiService.getMonitoringAuditLogs(widget.examId);
      if (!mounted) return;
      setState(() {
        _auditLogs = List<dynamic>.from(res['logs'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {}
  }

  // ==========================================================================
  // LIVEKIT INVIGILATOR SUBSCRIPTION
  // ==========================================================================

  Future<void> _connectLivekitInvigilatorRoom() async {
    if (_isTestMode) return;
    try {
      final tokenRes = await _apiService.getExamMonitoringLivekitToken(widget.examId, mode: 'invigilator');
      final token = tokenRes['token']?.toString() ?? '';
      final url = tokenRes['livekit_url']?.toString() ?? '';
      if (token.isEmpty || url.isEmpty) return;

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      room.addListener(_syncLivekitRemoteTracks);
      final listener = room.createListener();
      listener
        ..on<lk.TrackSubscribedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.TrackUnsubscribedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.TrackPublishedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.TrackUnpublishedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.ParticipantConnectedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.ParticipantDisconnectedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.TrackMutedEvent>((_) => _syncLivekitRemoteTracks())
        ..on<lk.TrackUnmutedEvent>((_) => _syncLivekitRemoteTracks());
      _livekitListener = listener;

      await room.connect(url, token);
      if (!mounted) {
        await listener.dispose();
        await room.disconnect();
        await room.dispose();
        return;
      }
      _livekitRoom = room;
      setState(() => _livekitConnected = true);
      _syncLivekitRemoteTracks();
    } catch (_) {
      if (mounted) setState(() => _livekitConnected = false);
    }
  }

  String _candidateIdFromIdentity(String identity) {
    var raw = identity.trim().toLowerCase();
    if (raw.startsWith('candidate_')) {
      raw = raw.substring('candidate_'.length);
    }
    return raw;
  }

  void _syncLivekitRemoteTracks() {
    if (!mounted || _livekitRoom == null) return;
    final cams = <String, lk.VideoTrack>{};
    final screens = <String, lk.VideoTrack>{};
    final audios = <String, lk.AudioTrack>{};

    for (final p in _livekitRoom!.remoteParticipants.values) {
      final cid = _candidateIdFromIdentity(p.identity);
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (track != null && !pub.muted) {
          if (pub.source == lk.TrackSource.screenShareVideo) {
            screens[cid] = track;
          } else {
            cams[cid] = track;
          }
        }
      }
      for (final pub in p.audioTrackPublications) {
        final track = pub.track;
        if (track != null) {
          final allowAudio = _listenAudioSelected && _inspectedCandidateId?.trim().toLowerCase() == cid;
          if (allowAudio) {
            pub.enable();
            try {
              _livekitRoom?.startAudio();
              track.start();
            } catch (e) {
              debugPrint('[Monitoring] Audio start error: $e');
            }
          } else {
            try {
              track.stop();
            } catch (_) {}
            pub.disable();
          }
          audios[cid] = track;
        }
      }
    }

    setState(() {
      _remoteCameraTracks
        ..clear()
        ..addAll(cams);
      _remoteScreenTracks
        ..clear()
        ..addAll(screens);
      _remoteAudioTracks
        ..clear()
        ..addAll(audios);
    });
  }

  // ==========================================================================
  // AUTHENTICATED WEBSOCKET REAL-TIME UPDATES
  // ==========================================================================

  Future<void> _connectMonitoringWebSocket() async {
    if (_isTestMode) return;
    _wsReconnectTimer?.cancel();
    await _wsSub?.cancel();
    try {
      await _wsChannel?.sink.close();
    } catch (_) {}

    try {
      final uri = await _apiService.buildMonitoringWsUri(widget.examId, isInvigilator: true);
      final channel = WebSocketChannel.connect(uri);
      _wsChannel = channel;
      _wsSub = channel.stream.listen(
        (raw) {
          try {
            final msg = json.decode(raw.toString());
            if (msg is Map) {
              _handleWsEnvelope(Map<String, dynamic>.from(msg));
            }
          } catch (_) {}
        },
        onDone: () {
          if (mounted) setState(() => _wsConnected = false);
          _scheduleWsReconnect();
        },
        onError: (_) {
          if (mounted) setState(() => _wsConnected = false);
          _scheduleWsReconnect();
        },
      );
      if (mounted) setState(() => _wsConnected = true);
    } catch (_) {
      if (mounted) setState(() => _wsConnected = false);
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    if (!mounted || _isTestMode) return;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 5), _connectMonitoringWebSocket);
  }

  void _handleWsEnvelope(Map<String, dynamic> msg) {
    final ev = (msg['event'] ?? '').toString();
    if (ev == 'pong') return;

    if (ev == 'reentry_requested' && mounted) {
      final data = msg['data'] is Map ? Map<String, dynamic>.from(msg['data']) : <String, dynamic>{};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Re-entry requested by ${data['candidate_name'] ?? 'a candidate'}'),
          backgroundColor: const Color(0xFFD97706),
        ),
      );
    }

    // Coalesce burst events cleanly into 1 refresh every 450ms
    _debounceRefreshTimer?.cancel();
    _debounceRefreshTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _refreshMonitoringData(silent: true);
    });
  }

  // ==========================================================================
  // FORMATTING HELPERS
  // ==========================================================================

  String _formatDurationHMS(int secs) {
    if (secs < 0) secs = 0;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDurationLabel(dynamic minutes) {
    if (_exam['duration_display'] != null && _exam['duration_display'].toString().trim().isNotEmpty) {
      return _exam['duration_display'].toString().trim();
    }
    final m = (minutes as num?)?.toInt() ?? (_exam['duration_minutes'] as num?)?.toInt() ?? 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final rem = m % 60;
      return rem == 0 ? '$h ${h == 1 ? "Hour" : "Hours"}' : '${h}h ${rem}m';
    }
    return '$m Mins';
  }

  String _formatDateLabel(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return 'Scheduled';
    final str = raw.toString().trim();
    if (RegExp(r'^[A-Za-z]{3}\s+\d{1,2},\s+\d{4}$').hasMatch(str)) {
      return str;
    }
    final dt = DateTime.tryParse(str);
    if (dt == null) return str;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
  }

  String _formatTimeWindow() {
    if (_exam['time_window'] != null && _exam['time_window'].toString().trim().isNotEmpty) {
      return _exam['time_window'].toString().trim();
    }
    final sRaw = _exam['start_time'];
    final eRaw = _exam['end_time'];
    final dur = (_exam['duration_minutes'] as num?)?.toInt() ?? 60;

    String cleanTime(dynamic r) {
      if (r == null) return '';
      final s = r.toString().trim();
      if (s.isEmpty) return '';
      if (RegExp(r'^\d{1,2}:\d{2}\s+(?:AM|PM)$', caseSensitive: false).hasMatch(s)) {
        return s.toUpperCase();
      }
      final ampmMatch = RegExp(r'(\d{1,2}:\d{2}\s+(?:AM|PM))', caseSensitive: false).firstMatch(s);
      if (ampmMatch != null) {
        return ampmMatch.group(1)!.toUpperCase();
      }
      final timePartMatch = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?').firstMatch(s);
      if (timePartMatch != null) {
        int h = int.tryParse(timePartMatch.group(1)!) ?? 0;
        final m = int.tryParse(timePartMatch.group(2)!) ?? 0;
        final ampm = h >= 12 ? 'PM' : 'AM';
        h = h % 12 == 0 ? 12 : h % 12;
        return '$h:${m.toString().padLeft(2, '0')} $ampm';
      }
      return s;
    }

    final sFormatted = cleanTime(sRaw);
    var eFormatted = cleanTime(eRaw);

    if (sFormatted.isNotEmpty && eFormatted.isEmpty) {
      final timePartMatch = RegExp(r'(\d{1,2}):(\d{2})\s+(AM|PM)', caseSensitive: false).firstMatch(sFormatted);
      if (timePartMatch != null) {
        var h = int.tryParse(timePartMatch.group(1)!) ?? 9;
        final m = int.tryParse(timePartMatch.group(2)!) ?? 0;
        final isPm = timePartMatch.group(3)!.toUpperCase() == 'PM';
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        final startMins = h * 60 + m;
        final endMins = (startMins + dur) % (24 * 60);
        var endH = endMins ~/ 60;
        final endM = endMins % 60;
        final endAmpm = endH >= 12 ? 'PM' : 'AM';
        endH = endH % 12 == 0 ? 12 : endH % 12;
        eFormatted = '$endH:${endM.toString().padLeft(2, '0')} $endAmpm';
      }
    }

    if (sFormatted.isNotEmpty && eFormatted.isNotEmpty) {
      return '$sFormatted - $eFormatted';
    } else if (sFormatted.isNotEmpty) {
      return sFormatted;
    }
    return '$dur mins window';
  }

  String _formatRelativeTime(dynamic raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return raw.toString();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 15) return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  ({String label, Color bg, Color fg, Color border}) _statusStyle(
    String monStatus,
    int warningsCount,
    _MonitorPalette palette,
  ) {
    switch (monStatus.toUpperCase()) {
      case 'VIOLATION':
      case 'UNDER_REVIEW':
        return (
          label: 'Violation ($warningsCount)',
          bg: palette.redBg,
          fg: palette.redText,
          border: palette.redText.withValues(alpha: 0.4),
        );
      case 'WARNING':
      case 'RECONNECTING':
        return (
          label: 'Warning ($warningsCount)',
          bg: palette.amberBg,
          fg: palette.amberText,
          border: palette.amberText.withValues(alpha: 0.4),
        );
      case 'PAUSED':
        return (
          label: 'Paused',
          bg: palette.purpleBg,
          fg: palette.purpleText,
          border: palette.purpleText.withValues(alpha: 0.4),
        );
      case 'DISCONNECTED':
        return (
          label: 'Disconnected',
          bg: palette.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          fg: palette.secondaryText,
          border: palette.borderColor,
        );
      case 'SUBMITTED':
      case 'AUTO_SUBMITTED':
        return (
          label: monStatus.toUpperCase() == 'AUTO_SUBMITTED' ? 'Auto-Submitted' : 'Submitted',
          bg: palette.isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
          fg: const Color(0xFF0284C7),
          border: const Color(0xFF0284C7).withValues(alpha: 0.35),
        );
      case 'TERMINATED':
        return (
          label: 'Terminated',
          bg: palette.redBg,
          fg: palette.redText,
          border: palette.redText.withValues(alpha: 0.5),
        );
      case 'NOT_STARTED':
      case 'READY':
        return (
          label: monStatus.toUpperCase() == 'READY' ? 'Ready' : 'Not Started',
          bg: palette.subtleBg,
          fg: palette.secondaryText,
          border: palette.borderColor,
        );
      case 'ACTIVE':
      default:
        return (
          label: 'In Exam',
          bg: palette.greenBg,
          fg: palette.greenText,
          border: palette.greenText.withValues(alpha: 0.35),
        );
    }
  }

  // ==========================================================================
  // INVIGILATOR ACTIONS & DIALOGS
  // ==========================================================================

  Future<void> _executeAction({
    required String actionType,
    required List<String> candidateIds,
    String? reason,
    String? message,
    int? minutes,
  }) async {
    if (_isTestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Executed $actionType on ${candidateIds.length} candidate(s)')),
      );
      return;
    }

    try {
      final res = await _apiService.executeInvigilatorAction(
        widget.examId,
        actionType: actionType,
        candidateIds: candidateIds,
        reason: reason,
        message: message,
        minutes: minutes,
        idempotencyKey: '${actionType}_${candidateIds.join(",")}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      );

      // Instant WebRTC Data Channel dispatch directly to student devices via LiveKit SFU (<30ms)
      try {
        final payloadBytes = utf8.encode(json.encode({
          'event': 'invigilator_command',
          'data': {
            'command': actionType,
            'action_type': actionType,
            'reason': reason ?? message ?? '',
            'message': message ?? reason ?? '',
            'minutes': minutes,
            'candidate_ids': candidateIds,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }));

        final targetIdentities = <String>[];
        for (final cid in candidateIds) {
          targetIdentities.add(cid);
          if (!cid.startsWith('candidate_')) {
            targetIdentities.add('candidate_$cid');
          }
        }

        try {
          await _livekitRoom?.localParticipant?.publishData(
            payloadBytes,
            destinationIdentities: targetIdentities,
          );
        } catch (_) {
          await _livekitRoom?.localParticipant?.publishData(payloadBytes);
        }
      } catch (e) {
        debugPrint('[Monitoring] DataChannel publish error: $e');
      }
      if (!mounted) return;
      final cnt = res['affected_count'] ?? candidateIds.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${actionType.replaceAll('_', ' ').toUpperCase()} completed ($cnt candidate(s))'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      // Optimistic instant state updates for proctoring actions
      if (actionType == 'force_disable_cam' || actionType == 'turn_off_cam') {
        for (final cid in candidateIds) {
          _remoteCameraTracks.remove(cid);
          if (_inspectedCandidateId == cid && _inspectedDetail != null && _inspectedDetail!['candidate'] is Map) {
            (_inspectedDetail!['candidate'] as Map)['camera_active'] = false;
          }
          for (final cand in _candidates) {
            if (cand['student_id']?.toString() == cid || cand['candidate_id']?.toString() == cid) {
              cand['camera_active'] = false;
            }
          }
        }
        setState(() {});
      } else if (actionType == 'enable_cam' || actionType == 'turn_on_cam') {
        for (final cid in candidateIds) {
          if (_inspectedCandidateId == cid && _inspectedDetail != null && _inspectedDetail!['candidate'] is Map) {
            (_inspectedDetail!['candidate'] as Map)['camera_active'] = true;
          }
          for (final cand in _candidates) {
            if (cand['student_id']?.toString() == cid || cand['candidate_id']?.toString() == cid) {
              cand['camera_active'] = true;
            }
          }
        }
        setState(() {});
      } else if (actionType == 'force_mute_mic' || actionType == 'turn_off_mic') {
        for (final cid in candidateIds) {
          _remoteAudioTracks.remove(cid);
          if (_inspectedCandidateId == cid && _inspectedDetail != null && _inspectedDetail!['candidate'] is Map) {
            (_inspectedDetail!['candidate'] as Map)['mic_active'] = false;
          }
          for (final cand in _candidates) {
            if (cand['student_id']?.toString() == cid || cand['candidate_id']?.toString() == cid) {
              cand['mic_active'] = false;
            }
          }
        }
        setState(() {});
      } else if (actionType == 'unmute_mic' || actionType == 'turn_on_mic') {
        for (final cid in candidateIds) {
          if (_inspectedCandidateId == cid && _inspectedDetail != null && _inspectedDetail!['candidate'] is Map) {
            (_inspectedDetail!['candidate'] as Map)['mic_active'] = true;
          }
          for (final cand in _candidates) {
            if (cand['student_id']?.toString() == cid || cand['candidate_id']?.toString() == cid) {
              cand['mic_active'] = true;
            }
          }
        }
        setState(() {});
      }

      await _refreshMonitoringData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _openWarnDialog(List<String> candidateIds, String label) {
    final palette = _MonitorPalette.of(context);
    final ctrl = TextEditingController(
      text: 'Suspicious activity detected. Please keep your face visible and stay on the exam screen.',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        title: Text('Send Warning — $label', style: TextStyle(color: palette.primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Focus on Screen'),
                    onPressed: () => ctrl.text = 'Please keep your eyes on the screen and avoid looking away.',
                  ),
                  ActionChip(
                    label: const Text('Enable Camera'),
                    onPressed: () => ctrl.text = 'Your camera feed is obscured or off. Please ensure clear visibility.',
                  ),
                  ActionChip(
                    label: const Text('Stop Tab Switching'),
                    onPressed: () => ctrl.text = 'Multiple tab switches detected. Further violations may terminate your exam.',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: TextStyle(color: palette.primaryText, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Warning Message',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final msg = ctrl.text.trim();
              Navigator.of(ctx).pop();
              _executeAction(actionType: 'warn', candidateIds: candidateIds, reason: msg, message: msg);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
  }

  void _openExtraTimeDialog(List<String> candidateIds, String label) {
    final palette = _MonitorPalette.of(context);
    int mins = 10;
    final reasonCtrl = TextEditingController(text: 'Technical / connectivity interruption accommodation');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: palette.cardBg,
          title: Text('Grant Extra Time — $label', style: TextStyle(color: palette.primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select minutes to add:', style: TextStyle(color: palette.secondaryText, fontSize: 12.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [5, 10, 15, 30].map((m) {
                    return ChoiceChip(
                      label: Text('+$m min'),
                      selected: mins == m,
                      onSelected: (_) => setS(() => mins = m),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: TextStyle(color: palette.primaryText, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Audit Reason (Required)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final r = reasonCtrl.text.trim();
                if (r.isEmpty) return;
                Navigator.of(ctx).pop();
                _executeAction(actionType: 'extend_time', candidateIds: candidateIds, minutes: mins, reason: r);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: Text('Grant +$mins Mins'),
            ),
          ],
        ),
      ),
    );
  }

  void _openStopExamDialog(List<String> candidateIds, String label) {
    final palette = _MonitorPalette.of(context);
    String mode = 'terminate';
    final reasonCtrl = TextEditingController(text: 'Severe proctoring rule violation / malpractice');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: palette.cardBg,
          title: Row(
            children: [
              Icon(Icons.gavel_rounded, color: palette.redText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stop Exam — $label',
                  style: TextStyle(color: palette.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioGroup<String>(
                  groupValue: mode,
                  onChanged: (v) {
                    if (v != null) setS(() => mode = v);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        value: 'terminate',
                        title: Text('Terminate Attempt', style: TextStyle(color: palette.primaryText, fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text('Immediately locks session & prevents further edits.', style: TextStyle(color: palette.secondaryText, fontSize: 12)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        value: 'force_submit',
                        title: Text('Force Submit Existing Answers', style: TextStyle(color: palette.primaryText, fontSize: 13.5, fontWeight: FontWeight.w600)),
                        subtitle: Text('Marks session Auto-Submitted preserving saved work.', style: TextStyle(color: palette.secondaryText, fontSize: 12)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: TextStyle(color: palette.primaryText, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Mandatory Reason (Audit Logged)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final r = reasonCtrl.text.trim();
                if (r.isEmpty) return;
                Navigator.of(ctx).pop();
                _executeAction(actionType: mode, candidateIds: candidateIds, reason: r);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: Text(mode == 'terminate' ? 'Terminate Session' : 'Force Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsvReport() async {
    if (_isTestMode) return;
    try {
      final bytes = await _apiService.exportMonitoringReportCsv(widget.examId);
      await getDownloadHelper().downloadBytes(
        bytes,
        'exam_monitoring_report_${widget.examId.substring(0, 8)}.csv',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monitoring report CSV downloaded.'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================================================
  // MAIN BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final palette = _MonitorPalette.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.scaffoldBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: palette.accentBlue),
              const SizedBox(height: 14),
              Text('Loading Live Monitoring Console...', style: TextStyle(color: palette.secondaryText)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: palette.scaffoldBg,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 460),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 46, color: palette.redText),
                const SizedBox(height: 14),
                Text('Monitoring Access Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.primaryText)),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: palette.secondaryText, fontSize: 13)),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => safeGoBack(context),
                  style: ElevatedButton.styleFrom(backgroundColor: palette.accentBlue, foregroundColor: Colors.white),
                  child: const Text('Back to Examinations'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = width >= 1100;
          final isMobile = width < 680;
          final hPad = isMobile ? 12.0 : 20.0;

          return RefreshIndicator(
            onRefresh: () => _refreshMonitoringData(silent: false),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopHeader(palette, isMobile),
                  const SizedBox(height: 12),
                  _buildExamContextBar(palette, isMobile),
                  const SizedBox(height: 12),
                  _buildKpiRow(palette, width),
                  if (((_kpis['pending_reentry_requests'] as num?)?.toInt() ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    _buildPendingReentryBanner(palette),
                  ],
                  const SizedBox(height: 14),
                  _buildMainNavigationTabs(palette),
                  const SizedBox(height: 14),
                  if (_activeMainTab == 0) _buildLiveMonitoringTab(palette, width, isDesktop, isMobile),
                  if (_activeMainTab == 1) _buildStudentListTab(palette, isMobile),
                  if (_activeMainTab == 2) _buildViolationReportsTab(palette, isMobile),
                  if (_activeMainTab == 3) _buildIncidentLogsTab(palette, isMobile),
                  if (_activeMainTab == 4) _buildExamControlsTab(palette, isDesktop, isMobile),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 1. HEADER, CONTEXT STRIP, KPIs & TABS
  // ==========================================================================

  Widget _buildTopHeader(_MonitorPalette palette, bool isMobile) {
    final isExamPaused = (_monitoringSession['status'] ?? '') == 'PAUSED';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runAlignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => safeGoBack(context),
              icon: Icon(Icons.arrow_back_rounded, color: palette.primaryText),
              tooltip: 'Back to Examinations',
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.accentBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.live_tv_rounded, color: palette.accentBlue, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Exam Monitoring',
                        style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w800, color: palette.primaryText),
                      ),
                      Text(
                        '(Live Proctoring)',
                        style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w600, color: palette.secondaryText),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _wsConnected ? palette.greenBg : palette.amberBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _wsConnected ? palette.greenText : palette.amberText,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _wsConnected ? 'Live Sync' : (_livekitConnected ? 'Room Active' : 'Polling'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _wsConnected ? palette.greenText : palette.amberText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Monitor students in real-time, detect violations and take proctoring actions',
                    style: TextStyle(fontSize: 12.5, color: palette.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _activeMainTab = _activeMainTab == 3 ? 0 : 3),
              icon: const Icon(Icons.receipt_long_rounded, size: 16),
              label: Text(_activeMainTab == 3 ? 'Back to Live Grid' : 'Switch to Logs'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.primaryText,
                backgroundColor: palette.cardBg,
                side: BorderSide(color: palette.borderColor),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'pause_resume') {
                  if (_isTestMode) return;
                  await _apiService.executeExamMonitoringControl(
                    widget.examId,
                    controlAction: isExamPaused ? 'resume_exam' : 'pause_exam',
                    reason: isExamPaused ? 'Exam resumed from header menu' : 'Exam paused from header menu',
                  );
                  _refreshMonitoringData(silent: true);
                } else if (val == 'export_csv') {
                  _exportCsvReport();
                } else if (val == 'controls') {
                  setState(() => _activeMainTab = 4);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pause_resume',
                  child: Row(
                    children: [
                      Icon(isExamPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(isExamPaused ? 'Resume Entire Exam' : 'Pause Entire Exam'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'controls',
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Threshold & Exam Controls'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_csv',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Export Incident & Audit CSV'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.accentBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Monitoring Settings',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExamContextBar(_MonitorPalette palette, bool isMobile) {
    final title = (_exam['title'] ?? 'Examination').toString();
    final subject = (_exam['subject_name'] ?? 'General').toString();
    final classesList = _exam['target_classes'] is List ? (_exam['target_classes'] as List).join(', ') : '';
    final subTitle = [if (classesList.isNotEmpty) classesList, subject].join(' • ');
    final isPaused = (_monitoringSession['status'] ?? '') == 'PAUSED';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: isMobile ? 10 : 20,
        runSpacing: isMobile ? 8 : 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.subtleBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.borderColor),
                ),
                child: Icon(Icons.assignment_rounded, color: palette.accentBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 200 : 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: palette.primaryText),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subTitle.isNotEmpty ? subTitle : 'Scheduled Examination',
                        style: TextStyle(fontSize: 12, color: palette.secondaryText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildContextMeta(Icons.calendar_today_rounded, 'Exam Date', _formatDateLabel(_exam['exam_date'] ?? _exam['exam_date_raw'] ?? _exam['start_time']), palette),
          _buildContextMeta(Icons.schedule_rounded, 'Exam Time', _formatTimeWindow(), palette),
          _buildContextMeta(Icons.timer_outlined, 'Duration', _formatDurationLabel(_exam['duration_minutes']), palette),
          _buildContextMeta(
            Icons.hourglass_bottom_rounded,
            'Time Remaining',
            _formatDurationHMS(_examRemainingSeconds),
            palette,
            valueColor: isPaused ? palette.purpleText : palette.accentBlue,
            isBold: true,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, size: 17, color: palette.secondaryText),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exam Mode', style: TextStyle(fontSize: 11, color: palette.secondaryText)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPaused
                                ? palette.purpleText
                                : ((_exam['exam_mode'] ?? _exam['exam_type'] ?? 'online').toString().toLowerCase() == 'offline'
                                    ? const Color(0xFFD97706)
                                    : palette.greenText),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isPaused
                                ? 'Paused (Proctored)'
                                : ((_exam['exam_mode'] ?? _exam['exam_type'] ?? 'online').toString().toLowerCase() == 'offline'
                                    ? 'Offline (Invigilation)'
                                    : 'Online (Proctored)'),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.primaryText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextMeta(
    IconData icon,
    String label,
    String value,
    _MonitorPalette palette, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: valueColor ?? palette.secondaryText),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: palette.secondaryText),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isBold ? 16 : 13,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                  color: valueColor ?? palette.primaryText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(_MonitorPalette palette, double width) {
    final total = (_kpis['total_students'] as num?)?.toInt() ?? 0;
    final online = (_kpis['online_in_exam'] as num?)?.toInt() ?? 0;
    final inProg = (_kpis['in_progress'] as num?)?.toInt() ?? 0;
    final violations = (_kpis['violations'] as num?)?.toInt() ?? 0;
    final disconn = (_kpis['disconnected'] as num?)?.toInt() ?? 0;
    final completed = (_kpis['completed'] as num?)?.toInt() ?? 0;

    final cards = [
      (label: 'Total Students', value: '$total', icon: Icons.people_alt_rounded, bg: palette.greenBg, fg: palette.greenText, filterKey: 'All'),
      (label: 'Online / In Exam', value: '$online', icon: Icons.desktop_windows_rounded, bg: const Color(0xFFDBEAFE), fg: const Color(0xFF2563EB), filterKey: 'active'),
      (label: 'In Progress', value: '$inProg', icon: Icons.hourglass_top_rounded, bg: palette.amberBg, fg: palette.amberText, filterKey: 'in_exam'),
      (label: 'Violations', value: '$violations', icon: Icons.warning_rounded, bg: palette.purpleBg, fg: palette.purpleText, filterKey: 'flagged_vio'),
      (label: 'Exited / Disconnected', value: '$disconn', icon: Icons.logout_rounded, bg: palette.redBg, fg: palette.redText, filterKey: 'disconnected'),
      (label: 'Completed', value: '$completed', icon: Icons.check_circle_rounded, bg: palette.subtleBg, fg: palette.secondaryText, filterKey: 'completed'),
    ];

    final int cols = width >= 1100 ? 6 : (width >= 680 ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 74,
      ),
      itemBuilder: (_, idx) {
        final item = cards[idx];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _currentPage = 1;
              if (item.filterKey == 'flagged_vio') {
                _selectedStatusFilter = 'All';
                _selectedViolationFilter = 'with_violations';
              } else {
                _selectedViolationFilter = 'All';
                _selectedStatusFilter = item.filterKey;
              }
            });
            _loadCandidates();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.isDark ? item.fg.withValues(alpha: 0.16) : item.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.fg, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(fontSize: 11, color: palette.secondaryText, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.value,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: palette.primaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingReentryBanner(_MonitorPalette palette) {
    final cnt = (_kpis['pending_reentry_requests'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.amberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.amberText.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_open_rounded, color: palette.amberText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$cnt candidate(s) requested re-entry approval after interruption.',
              style: TextStyle(color: palette.primaryText, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedViolationFilter = 'pending_reentry';
                _activeMainTab = 0;
                _currentPage = 1;
              });
              _loadCandidates();
            },
            child: Text('Review Requests', style: TextStyle(color: palette.amberText, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainNavigationTabs(_MonitorPalette palette) {
    const tabs = [
      (icon: Icons.live_tv_rounded, label: 'Live Monitoring'),
      (icon: Icons.groups_rounded, label: 'Student List'),
      (icon: Icons.warning_amber_rounded, label: 'Violation Reports'),
      (icon: Icons.receipt_long_rounded, label: 'Incident Logs'),
      (icon: Icons.tune_rounded, label: 'Exam Controls'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (idx) {
            final selected = _activeMainTab == idx;
            return InkWell(
              onTap: () {
                setState(() => _activeMainTab = idx);
                if (idx == 2) _loadIncidents();
                if (idx == 3) _loadAuditLogs();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? palette.accentBlue : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tabs[idx].icon, size: 17, color: selected ? palette.accentBlue : palette.secondaryText),
                    const SizedBox(width: 7),
                    Text(
                      tabs[idx].label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? palette.accentBlue : palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ==========================================================================
  // 2. TAB 1 — LIVE MONITORING (GRID + TABLE + DETAILS + DONUT)
  // ==========================================================================

  Widget _buildLiveMonitoringTab(
    _MonitorPalette palette,
    double width,
    bool isDesktop,
    bool isMobile,
  ) {
    final leftPane = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.borderColor),
          ),
          child: Column(
            children: [
              _buildGridToolbar(palette, isMobile),
              const SizedBox(height: 14),
              _buildCandidateCardsOrList(palette, width, isDesktop, isMobile),
              const SizedBox(height: 12),
              _buildPaginationBar(palette, isMobile),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildBottomStudentsTableCard(palette, isMobile),
      ],
    );

    final rightPane = Column(
      children: [
        _buildStudentDetailsCard(palette),
        const SizedBox(height: 14),
        _buildDonutCard(palette),
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 20, child: leftPane),
          const SizedBox(width: 14),
          Expanded(flex: 10, child: rightPane),
        ],
      );
    }

    return Column(
      children: [
        leftPane,
        const SizedBox(height: 14),
        rightPane,
      ],
    );
  }

  Widget _buildGridToolbar(_MonitorPalette palette, bool isMobile) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.subtleBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _gridToggleBtn(Icons.grid_view_rounded, _GridViewMode.grid4, palette, 'Grid 4x2'),
              _gridToggleBtn(Icons.view_agenda_rounded, _GridViewMode.grid2, palette, 'Large 2x2'),
              _gridToggleBtn(Icons.view_list_rounded, _GridViewMode.list, palette, 'Compact List'),
            ],
          ),
        ),
        _buildDropdownFilter(
          value: _selectedStatusFilter,
          items: const {
            'All': 'All Status',
            'in_exam': 'In Exam',
            'warning': 'Warning',
            'violation': 'Violation',
            'paused': 'Paused',
            'disconnected': 'Disconnected',
            'completed': 'Completed',
            'not_started': 'Not Started',
          },
          palette: palette,
          onChanged: (v) {
            setState(() {
              _selectedStatusFilter = v;
              _currentPage = 1;
            });
            _loadCandidates();
          },
        ),
        _buildDropdownFilter(
          value: _selectedViolationFilter,
          items: const {
            'All': 'All Violations',
            'with_violations': 'With Violations',
            'high': 'High Risk (>=2)',
            'pending_reentry': 'Pending Re-entry',
            'clean': 'Clean (0)',
          },
          palette: palette,
          onChanged: (v) {
            setState(() {
              _selectedViolationFilter = v;
              _currentPage = 1;
            });
            _loadCandidates();
          },
        ),
        SizedBox(
          width: isMobile ? 220 : 230,
          height: 36,
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(fontSize: 12.5, color: palette.primaryText),
            onSubmitted: (v) {
              setState(() {
                _searchQuery = v;
                _currentPage = 1;
              });
              _loadCandidates();
            },
            onChanged: (v) {
              _searchQuery = v;
              if (v.isEmpty) {
                setState(() => _currentPage = 1);
                _loadCandidates();
              }
            },
            decoration: InputDecoration(
              hintText: 'Search student by name or roll...',
              hintStyle: TextStyle(fontSize: 12, color: palette.secondaryText),
              prefixIcon: Icon(Icons.search_rounded, size: 17, color: palette.secondaryText),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: palette.subtleBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.borderColor),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => _refreshMonitoringData(silent: false),
          icon: Icon(Icons.refresh_rounded, size: 19, color: palette.secondaryText),
          tooltip: 'Refresh Live State',
        ),
      ],
    );
  }

  Widget _gridToggleBtn(IconData icon, _GridViewMode mode, _MonitorPalette palette, String tip) {
    final active = _gridMode == mode;
    return IconButton(
      onPressed: () => setState(() => _gridMode = mode),
      icon: Icon(icon, size: 17, color: active ? palette.accentBlue : palette.secondaryText),
      tooltip: tip,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required Map<String, String> items,
    required _MonitorPalette palette,
    required ValueChanged<String> onChanged,
  }) {
    final safeVal = items.containsKey(value) ? value : items.keys.first;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: palette.subtleBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeVal,
          dropdownColor: palette.cardBg,
          style: TextStyle(fontSize: 12.5, color: palette.primaryText, fontWeight: FontWeight.w500),
          items: items.entries
              .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildCandidateCardsOrList(
    _MonitorPalette palette,
    double width,
    bool isDesktop,
    bool isMobile,
  ) {
    if (_candidates.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.groups_2_outlined, size: 44, color: palette.secondaryText),
            const SizedBox(height: 10),
            Text('No candidates match the current filters.', style: TextStyle(color: palette.secondaryText, fontSize: 13.5)),
          ],
        ),
      );
    }

    if (_gridMode == _GridViewMode.list) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _candidates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, idx) => _buildCompactCandidateTile(_candidates[idx], palette),
      );
    }

    final int cols = isDesktop
        ? (_gridMode == _GridViewMode.grid2 ? 2 : 4)
        : (isMobile ? 1 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _candidates.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: _gridMode == _GridViewMode.grid2 ? 1.45 : 1.08,
      ),
      itemBuilder: (_, idx) => _buildCandidateFeedCard(_candidates[idx], palette),
    );
  }

  Widget _buildCandidateFeedCard(Map<String, dynamic> cand, _MonitorPalette palette) {
    final cid = (cand['candidate_id'] ?? '').toString().trim().toLowerCase();
    final name = (cand['full_name'] ?? 'Candidate').toString();
    final roll = (cand['roll_number'] ?? '').toString();
    final monStatus = (cand['monitoring_status'] ?? 'NOT_STARTED').toString();
    final warnings = (cand['warnings_count'] as num?)?.toInt() ?? 0;
    final selected = cid == (_inspectedCandidateId?.trim().toLowerCase());
    final st = _statusStyle(monStatus, warnings, palette);

    final camTrack = _remoteCameraTracks[cid];
    final screenTrack = _remoteScreenTracks[cid];
    final activeTrack = camTrack ?? screenTrack;

    final camActive = cand['camera_active'] == true || camTrack != null;
    final micActive = cand['mic_active'] == true || _remoteAudioTracks.containsKey(cid);
    final screenActive = cand['screen_share_active'] == true || screenTrack != null;
    final hasReentry = cand['pending_request_id'] != null;

    return InkWell(
      onTap: () => _loadCandidateDetail(cid),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.subtleBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? palette.accentBlue : st.border,
            width: selected ? 2.0 : 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video feed / honest permission status surface
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (activeTrack != null)
                      lk.VideoTrackRenderer(activeTrack)
                    else
                      _buildHonestFeedPlaceholder(cand, palette),

                    // Top bar overlay: Status Badge + Menu
                    Positioned(
                      top: 6,
                      left: 6,
                      right: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: st.bg.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: st.border),
                              ),
                              child: Text(
                                st.label,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: st.fg),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: palette.cardBg.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.more_vert_rounded, size: 15, color: palette.primaryText),
                            ),
                            onSelected: (act) => _handleCandidateMenuAction(act, cand),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'inspect', child: Text('Inspect Candidate')),
                              const PopupMenuItem(value: 'warn', child: Text('Send Warning')),
                              const PopupMenuItem(value: 'give_chance', child: Text('Give Chance')),
                              const PopupMenuItem(value: 'extend_time', child: Text('Grant Extra Time')),
                              PopupMenuItem(
                                value: cand['is_paused'] == true ? 'resume' : 'pause',
                                child: Text(cand['is_paused'] == true ? 'Resume Session' : 'Pause Session'),
                              ),
                              PopupMenuItem(
                                value: camActive ? 'turn_off_cam' : 'turn_on_cam',
                                child: Row(
                                  children: [
                                    Icon(camActive ? Icons.videocam_off_rounded : Icons.videocam_rounded, size: 16, color: camActive ? palette.amberText : palette.accentBlue),
                                    const SizedBox(width: 8),
                                    Text(camActive ? 'Turn Off Camera' : 'Turn On Camera'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: micActive ? 'turn_off_mic' : 'turn_on_mic',
                                child: Row(
                                  children: [
                                    Icon(micActive ? Icons.mic_off_rounded : Icons.mic_rounded, size: 16, color: micActive ? palette.amberText : palette.greenText),
                                    const SizedBox(width: 8),
                                    Text(micActive ? 'Turn Off Microphone' : 'Turn On Microphone'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(value: 'approve_reentry', child: Text('Allow Rejoin')),
                              const PopupMenuItem(value: 'stop', child: Text('Stop / Terminate Exam')),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (hasReentry)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.amberText,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Re-entry Req',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Footer metadata + honest device states
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: palette.cardBg,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cand['is_online'] == true ? palette.greenText : palette.secondaryText,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.primaryText),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          roll.isNotEmpty ? 'Roll: $roll' : (cand['class_name'] ?? '').toString(),
                          style: TextStyle(fontSize: 10.5, color: palette.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _hwIcon(Icons.videocam_rounded, camActive, palette),
                  const SizedBox(width: 4),
                  _hwIcon(Icons.mic_rounded, micActive, palette),
                  const SizedBox(width: 4),
                  _hwIcon(Icons.screen_share_rounded, screenActive, palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hwIcon(IconData icon, bool active, _MonitorPalette palette) {
    return Icon(
      icon,
      size: 14,
      color: active ? palette.accentBlue : palette.secondaryText.withValues(alpha: 0.45),
    );
  }

  Widget _buildHonestFeedPlaceholder(Map<String, dynamic> cand, _MonitorPalette palette) {
    final monStatus = (cand['monitoring_status'] ?? 'NOT_STARTED').toString().toUpperCase();
    final camPerm = (cand['camera_permission_state'] ?? 'NOT_CHECKED').toString().toUpperCase();

    IconData ic = Icons.videocam_off_rounded;
    String msg = 'Camera Feed Inactive';
    if (monStatus == 'DISCONNECTED') {
      ic = Icons.wifi_off_rounded;
      msg = 'Candidate Disconnected';
    } else if (monStatus == 'NOT_STARTED' || monStatus == 'READY') {
      ic = Icons.schedule_rounded;
      msg = 'Not Started Yet';
    } else if (monStatus == 'SUBMITTED' || monStatus == 'AUTO_SUBMITTED') {
      ic = Icons.task_alt_rounded;
      msg = 'Exam Submitted';
    } else if (monStatus == 'TERMINATED') {
      ic = Icons.block_rounded;
      msg = 'Session Terminated';
    }

    final isOffline = (_exam['exam_mode'] ?? _exam['exam_type'] ?? 'online').toString().toLowerCase() == 'offline';
    if (isOffline) {
      ic = Icons.assignment_outlined;
      if (monStatus == 'SUBMITTED' || monStatus == 'AUTO_SUBMITTED') {
        msg = 'Exam Submitted';
      } else if (monStatus == 'ACTIVE' || monStatus == 'IN_EXAM') {
        msg = 'Writing Paper Exam';
      } else {
        msg = 'Not Started Yet';
      }
    } else if (camPerm == 'DENIED') {
      msg = 'Camera Permission Denied';
    } else if (camPerm == 'NOT_CHECKED') {
      msg = 'Camera Pending / No Track';
    }

    return Container(
      color: palette.isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 28, color: palette.secondaryText),
          const SizedBox(height: 5),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: palette.secondaryText, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCandidateTile(Map<String, dynamic> cand, _MonitorPalette palette) {
    final cid = (cand['candidate_id'] ?? '').toString().trim().toLowerCase();
    final st = _statusStyle(
      (cand['monitoring_status'] ?? 'NOT_STARTED').toString(),
      (cand['warnings_count'] as num?)?.toInt() ?? 0,
      palette,
    );
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: () => _loadCandidateDetail(cid),
        tileColor: cid == _inspectedCandidateId ? palette.accentBlue.withValues(alpha: 0.08) : palette.subtleBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cid == _inspectedCandidateId ? palette.accentBlue : palette.borderColor),
        ),
        leading: CircleAvatar(
          backgroundColor: st.bg,
          child: Text(
            (cand['full_name'] ?? 'C').toString().substring(0, 1).toUpperCase(),
            style: TextStyle(color: st.fg, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('${cand['full_name']} (Roll: ${cand['roll_number'] ?? '-'})', style: TextStyle(color: palette.primaryText, fontSize: 13.5, fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Answered ${cand['answered_count'] ?? 0}/${cand['total_questions'] ?? 0} • ${cand['network_status'] ?? 'GOOD'}',
          style: TextStyle(color: palette.secondaryText, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
          child: Text(st.label, style: TextStyle(color: st.fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildPaginationBar(_MonitorPalette palette, bool isMobile) {
    final start = _totalCandidates == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final end = (_currentPage * _pageSize).clamp(0, _totalCandidates);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          'Showing $start - $end of $_totalCandidates students',
          style: TextStyle(fontSize: 12, color: palette.secondaryText),
        ),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _loadCandidates();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Text('Page $_currentPage of $_totalPages', style: TextStyle(fontSize: 12, color: palette.primaryText, fontWeight: FontWeight.w600)),
            IconButton(
              onPressed: _currentPage < _totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _loadCandidates();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 10),
            Text('Rows per page:', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: _pageSize,
              dropdownColor: palette.cardBg,
              style: TextStyle(fontSize: 12, color: palette.primaryText, fontWeight: FontWeight.w600),
              items: const [4, 8, 12, 24].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
              onChanged: (n) {
                if (n != null) {
                  setState(() {
                    _pageSize = n;
                    _currentPage = 1;
                  });
                  _loadCandidates();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomStudentsTableCard(_MonitorPalette palette, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.groups_rounded, color: palette.accentBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Students ($_totalCandidates)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.primaryText),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PopupMenuButton<String>(
                    enabled: _selectedCandidateIds.isNotEmpty,
                    onSelected: (act) {
                      final ids = _selectedCandidateIds.toList();
                      if (act == 'warn') _openWarnDialog(ids, '${ids.length} Selected');
                      if (act == 'extend') _openExtraTimeDialog(ids, '${ids.length} Selected');
                      if (act == 'pause') _executeAction(actionType: 'pause', candidateIds: ids, reason: 'Bulk paused by invigilator');
                      if (act == 'resume') _executeAction(actionType: 'resume', candidateIds: ids, reason: 'Bulk resumed by invigilator');
                      if (act == 'mute') _executeAction(actionType: 'force_mute_mic', candidateIds: ids, reason: 'Muted via bulk control');
                      if (act == 'unmute') _executeAction(actionType: 'unmute_mic', candidateIds: ids, reason: 'Unmuted via bulk control');
                      if (act == 'disable_cam') _executeAction(actionType: 'force_disable_cam', candidateIds: ids, reason: 'Turned off camera via bulk control');
                      if (act == 'enable_cam') _executeAction(actionType: 'enable_cam', candidateIds: ids, reason: 'Turned on camera via bulk control');
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'warn', child: Text('Warn Selected')),
                      PopupMenuItem(value: 'extend', child: Text('Grant Extra Time')),
                      PopupMenuItem(value: 'pause', child: Text('Pause Selected')),
                      PopupMenuItem(value: 'resume', child: Text('Resume Selected')),
                      PopupMenuItem(value: 'mute', child: Text('Turn Off Mic Selected')),
                      PopupMenuItem(value: 'unmute', child: Text('Turn On Mic Selected')),
                      PopupMenuItem(value: 'disable_cam', child: Text('Turn Off Cam Selected')),
                      PopupMenuItem(value: 'enable_cam', child: Text('Turn On Cam Selected')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedCandidateIds.isEmpty ? palette.subtleBg : palette.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _selectedCandidateIds.isEmpty ? palette.borderColor : palette.accentBlue),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCandidateIds.isEmpty ? 'Bulk Actions' : 'Bulk Actions (${_selectedCandidateIds.length})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: _selectedCandidateIds.isEmpty ? palette.secondaryText : palette.accentBlue,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: _selectedCandidateIds.isEmpty ? palette.secondaryText : palette.accentBlue),
                        ],
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportCsvReport,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Export Report'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      side: BorderSide(color: palette.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: isMobile ? 640 : 720),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(palette.subtleBg),
                horizontalMargin: 10,
                columnSpacing: 16,
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: _candidates.isNotEmpty && _candidates.every((c) => _selectedCandidateIds.contains(c['candidate_id']?.toString())),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            for (final c in _candidates) {
                              final id = c['candidate_id']?.toString();
                              if (id != null) _selectedCandidateIds.add(id);
                            }
                          } else {
                            _selectedCandidateIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(label: Text('#')),
                  const DataColumn(label: Text('Roll No.')),
                  const DataColumn(label: Text('Student Name')),
                  const DataColumn(label: Text('Status')),
                  const DataColumn(label: Text('Violations')),
                  const DataColumn(label: Text('Last Activity')),
                  const DataColumn(label: Text('Action')),
                ],
                rows: List.generate(_candidates.length, (i) {
                  final cand = _candidates[i];
                  final cid = (cand['candidate_id'] ?? '').toString().trim().toLowerCase();
                  final st = _statusStyle(
                    (cand['monitoring_status'] ?? 'NOT_STARTED').toString(),
                    (cand['warnings_count'] as num?)?.toInt() ?? 0,
                    palette,
                  );
                  final rowNum = (_currentPage - 1) * _pageSize + i + 1;
                  final isSel = _selectedCandidateIds.contains(cid);

                  return DataRow(
                    selected: cid == _inspectedCandidateId,
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSel,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedCandidateIds.add(cid);
                              } else {
                                _selectedCandidateIds.remove(cid);
                              }
                            });
                          },
                        ),
                      ),
                      DataCell(Text('$rowNum', style: TextStyle(color: palette.secondaryText, fontSize: 12.5))),
                      DataCell(Text('${cand['roll_number'] ?? '-'}', style: TextStyle(color: palette.primaryText, fontSize: 12.5))),
                      DataCell(
                        InkWell(
                          onTap: () => _loadCandidateDetail(cid),
                          child: Text(
                            (cand['full_name'] ?? 'Candidate').toString(),
                            style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
                          child: Text(st.label, style: TextStyle(color: st.fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      DataCell(Text('${cand['warnings_count'] ?? 0}', style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.w700))),
                      DataCell(
                        Text(
                          '${_formatRelativeTime(cand['last_activity_at'])}${cand['last_incident_title'] != null ? ' (${cand['last_incident_title']})' : ''}',
                          style: TextStyle(color: palette.secondaryText, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.desktop_windows_outlined, size: 17, color: palette.accentBlue),
                              tooltip: 'Inspect Candidate',
                              onPressed: () => _loadCandidateDetail(cid),
                            ),
                            IconButton(
                              icon: Icon(Icons.warning_amber_rounded, size: 17, color: palette.amberText),
                              tooltip: 'Send Warning',
                              onPressed: () => _openWarnDialog([cid], (cand['full_name'] ?? '').toString()),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, size: 17, color: palette.secondaryText),
                              onSelected: (act) => _handleCandidateMenuAction(act, cand),
                              itemBuilder: (_) {
                                final rowCamOn = cand['camera_active'] == true || _remoteCameraTracks.containsKey(cid);
                                final rowMicOn = cand['mic_active'] == true || _remoteAudioTracks.containsKey(cid);
                                return [
                                  const PopupMenuItem(value: 'give_chance', child: Text('Give Chance')),
                                  const PopupMenuItem(value: 'extend_time', child: Text('Grant Extra Time')),
                                  PopupMenuItem(
                                    value: rowCamOn ? 'turn_off_cam' : 'turn_on_cam',
                                    child: Text(rowCamOn ? 'Turn Off Camera' : 'Turn On Camera'),
                                  ),
                                  PopupMenuItem(
                                    value: rowMicOn ? 'turn_off_mic' : 'turn_on_mic',
                                    child: Text(rowMicOn ? 'Turn Off Microphone' : 'Turn On Microphone'),
                                  ),
                                  const PopupMenuItem(value: 'approve_reentry', child: Text('Allow Rejoin')),
                                  const PopupMenuItem(value: 'stop', child: Text('Stop Exam')),
                                ];
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCandidateMenuAction(String act, Map<String, dynamic> cand) {
    final cid = (cand['candidate_id'] ?? '').toString().trim().toLowerCase();
    final name = (cand['full_name'] ?? 'Candidate').toString();
    if (act == 'inspect') {
      _loadCandidateDetail(cid);
    } else if (act == 'warn') {
      _openWarnDialog([cid], name);
    } else if (act == 'give_chance') {
      _executeAction(actionType: 'give_chance', candidateIds: [cid], reason: 'Extra chance granted by invigilator');
    } else if (act == 'extend_time') {
      _openExtraTimeDialog([cid], name);
    } else if (act == 'pause') {
      _executeAction(actionType: 'pause', candidateIds: [cid], reason: 'Session paused by invigilator');
    } else if (act == 'resume') {
      _executeAction(actionType: 'resume', candidateIds: [cid], reason: 'Session resumed by invigilator');
    } else if (act == 'approve_reentry') {
      _executeAction(actionType: 'approve_reentry', candidateIds: [cid], reason: 'Re-entry approved by invigilator');
    } else if (act == 'turn_off_cam') {
      _executeAction(actionType: 'force_disable_cam', candidateIds: [cid], reason: 'Camera turned off by invigilator');
    } else if (act == 'turn_on_cam') {
      _executeAction(actionType: 'enable_cam', candidateIds: [cid], reason: 'Camera enabled by invigilator');
    } else if (act == 'turn_off_mic') {
      _executeAction(actionType: 'force_mute_mic', candidateIds: [cid], reason: 'Microphone muted by invigilator');
    } else if (act == 'turn_on_mic') {
      _executeAction(actionType: 'unmute_mic', candidateIds: [cid], reason: 'Microphone unmuted by invigilator');
    } else if (act == 'stop') {
      _openStopExamDialog([cid], name);
    }
  }

  // ==========================================================================
  // 3. RIGHT INSPECTOR PANEL (STUDENT DETAILS + PROCTORING ACTIONS + DONUT)
  // ==========================================================================

  Widget _buildStudentDetailsCard(_MonitorPalette palette) {
    final cand = _inspectedDetail?['candidate'] is Map
        ? Map<String, dynamic>.from(_inspectedDetail!['candidate'] as Map)
        : (_candidates.isNotEmpty ? _candidates.first : null);

    if (cand == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.borderColor),
        ),
        child: Center(
          child: Text('Select a student to inspect live details.', style: TextStyle(color: palette.secondaryText)),
        ),
      );
    }

    final cid = (cand['candidate_id'] ?? '').toString().trim().toLowerCase();
    final name = (cand['full_name'] ?? 'Candidate').toString();
    final roll = (cand['roll_number'] ?? '').toString();
    final className = (cand['class_name'] ?? '').toString();
    final monStatus = (cand['monitoring_status'] ?? 'NOT_STARTED').toString();
    final warnings = (cand['warnings_count'] as num?)?.toInt() ?? 0;
    final st = _statusStyle(monStatus, warnings, palette);

    final camTrack = _remoteCameraTracks[cid];
    final screenTrack = _remoteScreenTracks[cid];
    final hasLiveTrack = camTrack != null || screenTrack != null;
    final isCamOn = cand['camera_active'] == true || camTrack != null;
    final isMicOn = cand['mic_active'] == true || _remoteAudioTracks.containsKey(cid);
    final incidents = List<dynamic>.from(_inspectedDetail?['incidents'] as List? ?? []);
    final actions = List<dynamic>.from(_inspectedDetail?['actions'] as List? ?? []);
    final reentries = List<dynamic>.from(_inspectedDetail?['reentry_requests'] as List? ?? []);
    final pendingReq = cand['pending_request_id'] != null || reentries.any((r) => (r is Map && r['status'] == 'pending'));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_rounded, size: 18, color: palette.accentBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Student Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.primaryText)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasLiveTrack || cand['is_online'] == true ? palette.greenBg : palette.subtleBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasLiveTrack || cand['is_online'] == true ? palette.greenText : palette.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      hasLiveTrack ? 'Live' : (cand['is_online'] == true ? 'Online' : 'Offline'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: hasLiveTrack || cand['is_online'] == true ? palette.greenText : palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: palette.accentBlue.withValues(alpha: 0.14),
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.accentBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.primaryText)),
                    Text(
                      'Roll No: ${roll.isEmpty ? '-' : roll}${className.isNotEmpty ? ' • $className' : ''}',
                      style: TextStyle(fontSize: 12, color: palette.secondaryText),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(8)),
                child: Text(st.label, style: TextStyle(color: st.fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Inner Subtabs: Monitoring | Activity | Violations | More
          Row(
            children: [
              _detailTabBtn('Monitoring', 0, palette),
              _detailTabBtn('Activity', 1, palette),
              _detailTabBtn('Violations (${incidents.length})', 2, palette),
              _detailTabBtn('More', 3, palette),
            ],
          ),
          Divider(height: 1, color: palette.borderColor),
          const SizedBox(height: 12),

          if (_inspectorSubTab == 0) ...[
            // Live Video / Screen Share Inspector Box
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_showScreenSharePreview && screenTrack != null)
                      lk.VideoTrackRenderer(screenTrack)
                    else if (!_showScreenSharePreview && camTrack != null)
                      lk.VideoTrackRenderer(camTrack)
                    else
                      _buildHonestFeedPlaceholder(cand, palette),

                    if (screenTrack != null || camTrack != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _showScreenSharePreview = false),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Camera',
                                    style: TextStyle(
                                      color: !_showScreenSharePreview ? Colors.lightBlueAccent : Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() => _showScreenSharePreview = true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Screen',
                                    style: TextStyle(
                                      color: _showScreenSharePreview ? Colors.lightBlueAccent : Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            _telemetryRow(
              Icons.videocam_rounded,
              'Camera',
              cand['camera_active'] == true || camTrack != null
                  ? 'Active'
                  : (cand['camera_permission_state'] ?? 'Pending').toString(),
              cand['camera_active'] == true || camTrack != null ? palette.greenText : palette.amberText,
              palette,
            ),
            _telemetryRow(
              Icons.mic_rounded,
              'Microphone',
              cand['mic_active'] == true || _remoteAudioTracks.containsKey(cid)
                  ? 'Active'
                  : (cand['mic_permission_state'] ?? 'Pending').toString(),
              cand['mic_active'] == true || _remoteAudioTracks.containsKey(cid) ? palette.greenText : palette.amberText,
              palette,
              trailing: (cand['mic_active'] == true || _remoteAudioTracks.containsKey(cid))
                  ? InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        setState(() => _listenAudioSelected = !_listenAudioSelected);
                        try {
                          await _livekitRoom?.startAudio();
                        } catch (_) {}
                        _syncLivekitRemoteTracks();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _listenAudioSelected ? palette.greenBg : palette.subtleBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _listenAudioSelected ? palette.greenText : palette.borderColor,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _listenAudioSelected ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                              size: 13,
                              color: _listenAudioSelected ? palette.greenText : palette.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _listenAudioSelected ? 'Listening' : 'Listen',
                              style: TextStyle(
                                fontSize: 11,
                                color: _listenAudioSelected ? palette.greenText : palette.accentBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
            _telemetryRow(
              Icons.screen_share_rounded,
              'Screen Share',
              cand['screen_share_active'] == true ? 'Shared' : (cand['screen_share_state'] ?? 'Not Shared').toString(),
              cand['screen_share_active'] == true ? palette.greenText : palette.secondaryText,
              palette,
            ),
            _telemetryRow(
              Icons.wifi_rounded,
              'Internet Quality',
              '${cand['network_status'] ?? 'GOOD'}${cand['latency_ms'] != null ? ' (${cand['latency_ms']}ms)' : ''}',
              (cand['network_status'] ?? 'GOOD') == 'OFFLINE' ? palette.redText : palette.greenText,
              palette,
            ),
            _telemetryRow(
              Icons.sync_rounded,
              'Progress & Sync',
              '${cand['answered_count'] ?? 0}/${cand['total_questions'] ?? 0} answered • ${_formatRelativeTime(cand['last_answer_sync_at'])}',
              palette.primaryText,
              palette,
            ),
            _telemetryRow(
              Icons.timer_outlined,
              'Time Left',
              '${_formatDurationHMS((cand['remaining_seconds'] as num?)?.toInt() ?? 0)}${(cand['extra_minutes'] as num?)?.toInt() != 0 && cand['extra_minutes'] != null ? ' (+${cand['extra_minutes']}m)' : ''}',
              palette.accentBlue,
              palette,
            ),

            if (pendingReq) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.amberBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.amberText.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Re-entry Request', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: palette.primaryText)),
                    const SizedBox(height: 4),
                    Text(
                      (cand['reentry_reason'] ?? 'Candidate requested permission to rejoin.').toString(),
                      style: TextStyle(fontSize: 12, color: palette.secondaryText),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _executeAction(actionType: 'approve_reentry', candidateIds: [cid], reason: 'Re-entry request approved'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8)),
                            child: const Text('Approve Rejoin', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _executeAction(actionType: 'reject_reentry', candidateIds: [cid], reason: 'Re-entry request declined'),
                            style: OutlinedButton.styleFrom(foregroundColor: palette.redText, padding: const EdgeInsets.symmetric(vertical: 8)),
                            child: const Text('Reject', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: palette.accentBlue),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Proctoring Actions',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: palette.primaryText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (_, box) {
                final gridCols = box.maxWidth < 340 ? 2 : 3;
                final ratio = box.maxWidth < 340 ? 2.55 : 2.25;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: gridCols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: ratio,
                  children: [
                    _actionBtn('Give Chance', Icons.verified_user_outlined, palette.accentBlue, () => _executeAction(actionType: 'give_chance', candidateIds: [cid], reason: 'Extra chance granted by invigilator'), palette),
                    _actionBtn('Send Warning', Icons.warning_amber_rounded, palette.amberText, () => _openWarnDialog([cid], name), palette, filledBg: palette.amberBg),
                    _actionBtn('Stop Exam', Icons.stop_circle_outlined, palette.redText, () => _openStopExamDialog([cid], name), palette, filledBg: palette.redBg),
                    _actionBtn(
                      cand['is_paused'] == true ? 'Resume' : (monStatus == 'DISCONNECTED' ? 'Allow Rejoin' : 'Pause'),
                      cand['is_paused'] == true ? Icons.play_arrow_rounded : (monStatus == 'DISCONNECTED' ? Icons.login_rounded : Icons.pause_rounded),
                      palette.primaryText,
                      () => _executeAction(
                        actionType: cand['is_paused'] == true ? 'resume' : (monStatus == 'DISCONNECTED' ? 'approve_reentry' : 'pause'),
                        candidateIds: [cid],
                        reason: 'Invigilator control',
                      ),
                      palette,
                    ),
                    _actionBtn(
                      isMicOn ? 'Turn Off Mic' : 'Turn On Mic',
                      isMicOn ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isMicOn ? palette.primaryText : palette.greenText,
                      () => _executeAction(
                        actionType: isMicOn ? 'force_mute_mic' : 'unmute_mic',
                        candidateIds: [cid],
                        reason: isMicOn ? 'Mic muted by invigilator' : 'Mic unmuted by invigilator',
                      ),
                      palette,
                      filledBg: isMicOn ? null : palette.greenBg,
                    ),
                    _actionBtn(
                      isCamOn ? 'Turn Off Cam' : 'Turn On Cam',
                      isCamOn ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      isCamOn ? palette.primaryText : palette.accentBlue,
                      () => _executeAction(
                        actionType: isCamOn ? 'force_disable_cam' : 'enable_cam',
                        candidateIds: [cid],
                        reason: isCamOn ? 'Camera disabled by invigilator' : 'Camera enabled by invigilator',
                      ),
                      palette,
                      filledBg: isCamOn ? null : palette.accentBlue.withValues(alpha: 0.14),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openExtraTimeDialog([cid], name),
                  icon: const Icon(Icons.more_time_rounded, size: 15),
                  label: const Text('+ Extra Time', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _executeAction(actionType: 'request_camera', candidateIds: [cid], reason: 'Please re-enable your camera feed'),
                  icon: const Icon(Icons.videocam_rounded, size: 15),
                  label: const Text('Req Cam Check', style: TextStyle(fontSize: 12)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _executeAction(actionType: 'escalate', candidateIds: [cid], reason: 'Escalated to Chief Invigilator for review'),
                  icon: Icon(Icons.flag_rounded, size: 15, color: palette.redText),
                  label: Text('Escalate', style: TextStyle(fontSize: 12, color: palette.redText)),
                ),
              ],
            ),
          ] else if (_inspectorSubTab == 1) ...[
            if (actions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('No invigilator actions logged yet.', style: TextStyle(color: palette.secondaryText, fontSize: 12.5))),
              )
            else
              ...actions.take(10).map((a) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.history_rounded, size: 18, color: palette.accentBlue),
                    title: Text('${(a['action_type'] ?? '').toString().toUpperCase()} by ${a['actor_name'] ?? 'Invigilator'}', style: TextStyle(color: palette.primaryText, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('${a['reason'] ?? ''} • ${_formatRelativeTime(a['created_at'])}', style: TextStyle(color: palette.secondaryText, fontSize: 11.5)),
                  )),
          ] else if (_inspectorSubTab == 2) ...[
            if (incidents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Clean session — 0 violations detected.', style: TextStyle(color: palette.greenText, fontSize: 12.5, fontWeight: FontWeight.w600))),
              )
            else
              ...incidents.take(10).map((inc) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.warning_amber_rounded, size: 18, color: palette.redText),
                    title: Text((inc['title'] ?? 'Violation').toString(), style: TextStyle(color: palette.primaryText, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('${inc['severity'] ?? 'medium'} • ${inc['status'] ?? 'open'} • ${_formatRelativeTime(inc['occurred_at'])}', style: TextStyle(color: palette.secondaryText, fontSize: 11.5)),
                  )),
          ] else ...[
            _telemetryRow(Icons.computer_rounded, 'Browser / Device', (cand['browser_info'] ?? 'Web Browser').toString(), palette.primaryText, palette),
            _telemetryRow(Icons.restart_alt_rounded, 'Re-entries Used', '${cand['reentry_count'] ?? 0} / ${cand['max_reentry_attempts'] ?? 2}', palette.primaryText, palette),
            _telemetryRow(Icons.message_outlined, 'Last Notice', (cand['teacher_message'] ?? 'None').toString(), palette.secondaryText, palette),
          ],
        ],
      ),
    );
  }

  Widget _detailTabBtn(String label, int idx, _MonitorPalette palette) {
    final active = _inspectorSubTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _inspectorSubTab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: active ? palette.accentBlue : Colors.transparent, width: 2),
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? palette.accentBlue : palette.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _telemetryRow(
    IconData icon,
    String label,
    String value,
    Color valColor,
    _MonitorPalette palette, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: palette.secondaryText),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: palette.secondaryText)),
          const Spacer(),
          if (trailing != null) trailing,
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    _MonitorPalette palette, {
    Color? filledBg,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: filledBg ?? palette.subtleBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutCard(_MonitorPalette palette) {
    final total = (_kpis['total_students'] as num?)?.toInt() ?? 0;
    final inExam = (_kpis['online_in_exam'] as num?)?.toInt() ?? 0;
    return MonitoringDonutSummaryCard(
      activeInExam: inExam,
      totalStudents: total,
      breakdown: _statusBreakdown,
      cardBg: palette.cardBg,
      borderColor: palette.borderColor,
      primaryText: palette.primaryText,
      secondaryText: palette.secondaryText,
    );
  }

  // ==========================================================================
  // 4. SECONDARY TABS: STUDENT LIST, VIOLATION REPORTS, INCIDENT LOGS, CONTROLS
  // ==========================================================================

  Widget _buildStudentListTab(_MonitorPalette palette, bool isMobile) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.borderColor),
          ),
          child: _buildGridToolbar(palette, isMobile),
        ),
        const SizedBox(height: 12),
        _buildBottomStudentsTableCard(palette, isMobile),
      ],
    );
  }

  Widget _buildViolationReportsTab(_MonitorPalette palette, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Violation Reports (${_incidentsSummary['total'] ?? _incidents.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.primaryText)),
                  Text('Review, acknowledge, resolve, or escalate automated and invigilator-flagged incidents.', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  _buildDropdownFilter(
                    value: _incidentSeverityFilter,
                    items: const {
                      'all': 'All Severities',
                      'low': 'Low',
                      'medium': 'Medium',
                      'high': 'High',
                      'critical': 'Critical',
                    },
                    palette: palette,
                    onChanged: (v) {
                      setState(() => _incidentSeverityFilter = v);
                      _loadIncidents();
                    },
                  ),
                  _buildDropdownFilter(
                    value: _incidentStatusFilter,
                    items: const {
                      'all': 'All Statuses',
                      'open': 'Open',
                      'acknowledged': 'Acknowledged',
                      'escalated': 'Escalated',
                      'resolved': 'Resolved',
                    },
                    palette: palette,
                    onChanged: (v) {
                      setState(() => _incidentStatusFilter = v);
                      _loadIncidents();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_incidents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No proctoring incidents match the selected filters.', style: TextStyle(color: palette.secondaryText))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _incidents.length,
              separatorBuilder: (_, __) => Divider(color: palette.borderColor),
              itemBuilder: (_, idx) {
                final inc = _incidents[idx];
                final sev = (inc['severity'] ?? 'medium').toString().toLowerCase();
                final status = (inc['status'] ?? 'open').toString();
                final sevColor = sev == 'critical' || sev == 'high' ? palette.redText : palette.amberText;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: sevColor.withValues(alpha: 0.14),
                    child: Icon(Icons.warning_amber_rounded, color: sevColor, size: 20),
                  ),
                  title: Text(
                    '${inc['candidate_name'] ?? 'Candidate'} • ${inc['title'] ?? inc['violation_type']}',
                    style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    '${inc['description'] ?? ''} (${sev.toUpperCase()} • Source: ${inc['detection_source'] ?? 'browser'} • ${_formatRelativeTime(inc['occurred_at'])})',
                    style: TextStyle(color: palette.secondaryText, fontSize: 12),
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (status != 'resolved' && !_isTestMode)
                        TextButton(
                          onPressed: () async {
                            await _apiService.resolveMonitoringIncident(
                              widget.examId,
                              inc['id'].toString(),
                              status: 'resolved',
                              resolutionNote: 'Reviewed & resolved by invigilator',
                            );
                            _loadIncidents();
                            _refreshMonitoringData(silent: true);
                          },
                          child: const Text('Resolve'),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildIncidentLogsTab(_MonitorPalette palette, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invigilation Audit Logs (${_auditLogs.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.primaryText)),
                  Text('Immutable chronological record of every proctoring decision, intervention & control.', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _exportCsvReport,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export Audit CSV'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_auditLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No interventions logged yet.', style: TextStyle(color: palette.secondaryText))),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _auditLogs.length,
              separatorBuilder: (_, __) => Divider(color: palette.borderColor),
              itemBuilder: (_, idx) {
                final log = _auditLogs[idx];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.security_rounded, color: palette.accentBlue),
                  title: Text(
                    '${(log['action_type'] ?? '').toString().toUpperCase()} — ${log['candidate_name'] ?? 'Exam-Wide'}',
                    style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  subtitle: Text(
                    'By ${log['actor_name'] ?? 'Invigilator'} (${log['actor_role'] ?? 'staff'}) • ${log['reason'] ?? ''} • ${_formatRelativeTime(log['created_at'])}',
                    style: TextStyle(color: palette.secondaryText, fontSize: 12),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExamControlsTab(_MonitorPalette palette, bool isDesktop, bool isMobile) {
    final isPaused = (_monitoringSession['status'] ?? '') == 'PAUSED';
    final reentryOpen = _monitoringSession['reentry_window_open'] != false;

    final controlsCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exam-Wide Controls', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.primaryText)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _isTestMode
                    ? null
                    : () async {
                        await _apiService.executeExamMonitoringControl(
                          widget.examId,
                          controlAction: isPaused ? 'resume_exam' : 'pause_exam',
                          reason: isPaused ? 'Invigilator resumed exam' : 'Invigilator paused entire exam',
                        );
                        _refreshMonitoringData(silent: true);
                      },
                icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                label: Text(isPaused ? 'Resume Entire Exam' : 'Pause Entire Exam'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaused ? palette.greenText : palette.amberText,
                  foregroundColor: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isTestMode
                    ? null
                    : () async {
                        await _apiService.executeExamMonitoringControl(
                          widget.examId,
                          controlAction: 'extend_exam_deadline',
                          minutes: 15,
                          reason: 'Global +15 min technical buffer',
                        );
                        _refreshMonitoringData(silent: true);
                      },
                icon: const Icon(Icons.more_time_rounded),
                label: const Text('Extend All +15 Mins'),
              ),
              OutlinedButton.icon(
                onPressed: _isTestMode
                    ? null
                    : () async {
                        await _apiService.executeExamMonitoringControl(
                          widget.examId,
                          controlAction: reentryOpen ? 'close_reentry' : 'open_reentry',
                          reason: reentryOpen ? 'Closed re-entry window' : 'Reopened re-entry window',
                        );
                        _refreshMonitoringData(silent: true);
                      },
                icon: Icon(reentryOpen ? Icons.lock_outline_rounded : Icons.lock_open_rounded),
                label: Text(reentryOpen ? 'Close Re-entry Window' : 'Open Re-entry Window'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.redBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.redText.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.emergency_rounded, color: palette.redText),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency Submit All Active Sessions', style: TextStyle(fontWeight: FontWeight.w800, color: palette.redText, fontSize: 13.5)),
                      Text('Immediately finalizes and collects all ongoing candidate attempts.', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isTestMode ? null : _confirmEmergencySubmitAll,
                  style: ElevatedButton.styleFrom(backgroundColor: palette.redText, foregroundColor: Colors.white),
                  child: const Text('Submit All'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final announcementCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Broadcast Live Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.primaryText)),
          const SizedBox(height: 10),
          TextField(
            controller: _annTitleCtrl,
            style: TextStyle(color: palette.primaryText, fontSize: 13),
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _annMsgCtrl,
            maxLines: 3,
            style: TextStyle(color: palette.primaryText, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Announcement Message',
              hintText: 'Type clarification or urgent instructions...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDropdownFilter(
                value: _annPriority,
                items: const {'normal': 'Normal Priority', 'important': 'Important', 'urgent': 'Urgent Alert'},
                palette: palette,
                onChanged: (v) => setState(() => _annPriority = v),
              ),
              _buildDropdownFilter(
                value: _annTargetScope,
                items: const {
                  'all': 'All Candidates',
                  'active': 'Only In Exam',
                  'flagged': 'Flagged / Warning',
                  'disconnected': 'Disconnected Only',
                },
                palette: palette,
                onChanged: (v) => setState(() => _annTargetScope = v),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(value: _annRequiresAck, onChanged: (v) => setState(() => _annRequiresAck = v == true)),
                  Text('Require Ack', style: TextStyle(fontSize: 12.5, color: palette.primaryText)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isSendingAnnouncement || _isTestMode ? null : _sendAnnouncement,
                icon: const Icon(Icons.campaign_rounded, size: 16),
                label: Text(_isSendingAnnouncement ? 'Sending...' : 'Broadcast Now'),
                style: ElevatedButton.styleFrom(backgroundColor: palette.accentBlue, foregroundColor: Colors.white),
              ),
            ],
          ),
          if (_announcements.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Recent Announcements', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.primaryText)),
            const SizedBox(height: 6),
            ..._announcements.take(4).map((a) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text((a['title'] ?? '').toString(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.primaryText)),
                  subtitle: Text('${a['message'] ?? ''} • Ack: ${a['ack_count'] ?? 0}/${a['recipient_count'] ?? 0}', style: TextStyle(fontSize: 11.5, color: palette.secondaryText)),
                )),
          ],
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: controlsCard),
          const SizedBox(width: 14),
          Expanded(child: announcementCard),
        ],
      );
    }
    return Column(
      children: [
        controlsCard,
        const SizedBox(height: 14),
        announcementCard,
      ],
    );
  }

  Future<void> _sendAnnouncement() async {
    final msg = _annMsgCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _isSendingAnnouncement = true);
    try {
      await _apiService.sendMonitoringAnnouncement(
        widget.examId,
        title: _annTitleCtrl.text.trim().isEmpty ? 'Examination Announcement' : _annTitleCtrl.text.trim(),
        message: msg,
        priority: _annPriority,
        targetScope: _annTargetScope,
        requiresAcknowledgement: _annRequiresAck,
      );
      _annMsgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement broadcast to targeted candidates.'), backgroundColor: Color(0xFF16A34A)),
        );
      }
      _refreshMonitoringData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingAnnouncement = false);
    }
  }

  void _confirmEmergencySubmitAll() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Emergency Submit All'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type SUBMIT ALL to force-submit every active candidate attempt immediately.'),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'SUBMIT ALL', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim() != 'SUBMIT ALL') return;
              Navigator.of(ctx).pop();
              await _apiService.executeExamMonitoringControl(
                widget.examId,
                controlAction: 'emergency_submit_all',
                reason: 'Emergency submit all confirmed by invigilator',
              );
              _refreshMonitoringData(silent: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Execute Emergency Submit'),
          ),
        ],
      ),
    );
  }
}

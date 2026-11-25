import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/common_components.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => MonitoringScreenState();
}

class MonitoringScreenState extends State<MonitoringScreen> {
  bool _isLoading = true;
  String _timeframe = '24h';
  SmsStatistics _stats = SmsStatistics();
  Map<String, dynamic> _diag = {};
  List<SimInfo> _sims = [];
  StreamSubscription? _wsSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    refresh();
    _wsSub = WebSocketService().stream.listen((_) {
      if (mounted) refresh();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait([
        ApiService().getSmsStatistics(timeframe: _timeframe),
        PlatformBridge.getDiagnostics(),
        ApiService().getSimConfiguration(),
      ]);
      if (!mounted) return;
      final simCfg = results[2] as Map<String, dynamic>;
      setState(() {
        _stats = results[0] as SmsStatistics;
        _diag = results[1] as Map<String, dynamic>;
        _sims = (simCfg['sims'] as List<SimInfo>?) ?? [];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatUptime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLive = WebSocketService().isConnected || ApiService().connectionState == GatewayConnectionState.online;
    final battery = (_diag['battery_level'] as num?)?.toInt() ?? 0;
    final netType = (_diag['network_type'] as String?) ?? 'Unknown';
    final uptime = (_diag['uptime_seconds'] as num?)?.toInt() ?? 0;
    final pendingUploads = (_diag['pending_uploads_count'] as num?)?.toInt() ?? 0;

    return SkyHeaderContainer(
      child: Column(
        children: [
          AppTopBar(
            title: 'Real-Time Monitoring',
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isLive
                      ? (isDark ? AppColors.successGreen.withValues(alpha: 0.18) : AppColors.successGreenBg)
                      : (isDark ? AppColors.errorRed.withValues(alpha: 0.18) : AppColors.errorRedBg),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLive ? AppColors.successGreen : AppColors.errorRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLive ? 'Live' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isLive ? AppColors.successGreen : AppColors.errorRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Collecting live gateway telemetry...')
                : RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MiniMetricTile(
                                icon: Icons.send_rounded,
                                color: AppColors.primaryBlue,
                                val: NumberFormat.decimalPattern().format(_stats.sentToday),
                                label: 'Sent Today',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MiniMetricTile(
                                icon: Icons.inbox_rounded,
                                color: AppColors.successGreen,
                                val: NumberFormat.decimalPattern().format(_stats.receivedToday),
                                label: 'Received',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MiniMetricTile(
                                icon: Icons.check_circle_rounded,
                                color: AppColors.successGreen,
                                val: '${_stats.deliveryRate.toStringAsFixed(1)}%',
                                label: 'Success',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MiniMetricTile(
                                icon: Icons.error_rounded,
                                color: AppColors.errorRed,
                                val: NumberFormat.decimalPattern().format(_stats.failedToday),
                                label: 'Failed',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Message Activity Chart
                        StatusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  const Text('Message Activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const _LegendDot(color: AppColors.primaryBlue, label: 'Sent'),
                                      const SizedBox(width: 8),
                                      const _LegendDot(color: AppColors.successGreen, label: 'Received'),
                                      const SizedBox(width: 8),
                                      DropdownButton<String>(
                                        value: _timeframe,
                                        isDense: true,
                                        underline: const SizedBox.shrink(),
                                        items: const [
                                          DropdownMenuItem(value: '24h', child: Text('24h', style: TextStyle(fontSize: 12))),
                                          DropdownMenuItem(value: '7d', child: Text('7d', style: TextStyle(fontSize: 12))),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() => _timeframe = v);
                                            refresh();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 145,
                                child: _stats.hourlyActivity.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No hourly traffic recorded yet',
                                          style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
                                        ),
                                      )
                                    : CustomPaint(
                                        painter: _ActivityLineChartPainter(_stats.hourlyActivity),
                                        size: Size.infinite,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SIM Usage Donut + Device Health
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: StatusCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SIM Usage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                    const SizedBox(height: 10),
                                    _buildSimUsageBody(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: StatusCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Device Health', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                    const SizedBox(height: 10),
                                    _HealthLine(Icons.battery_charging_full_rounded, AppColors.successGreen, 'Battery', '$battery%'),
                                    const SizedBox(height: 6),
                                    _HealthLine(Icons.network_cell_rounded, AppColors.primaryBlue, 'Network', netType),
                                    const SizedBox(height: 6),
                                    _HealthLine(Icons.timer_outlined, AppColors.purple, 'Uptime', _formatUptime(uptime)),
                                    const SizedBox(height: 6),
                                    _HealthLine(Icons.queue_rounded, AppColors.warningOrange, 'Queue', '${_stats.queueSize + pendingUploads}'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Application-wise SMS Usage
                        StatusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Application-Wise SMS Usage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 10),
                              if (_stats.appUsage.isEmpty)
                                const Text('No application traffic recorded yet.', style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText))
                              else
                                ..._stats.appUsage.map((app) {
                                  final name = (app['application_source'] ?? 'Unknown').toString();
                                  final cnt = (app['count'] as num?)?.toInt() ?? 0;
                                  final maxCnt = math.max(1, (_stats.appUsage.first['count'] as num?)?.toInt() ?? 1);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text('$cnt SMS', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        LinearProgressIndicator(
                                          value: cnt / maxCnt,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(6),
                                          color: AppColors.primaryBlue,
                                          backgroundColor: isDark
                                              ? AppColors.primaryBlue.withValues(alpha: 0.2)
                                              : AppColors.primaryBlueLight,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Live Activity Feed
                        SectionHeader(
                          title: 'Live Activity Feed',
                          actionLabel: 'See All →',
                          onAction: _showAllEventsSheet,
                        ),
                        const SizedBox(height: 4),
                        if (_stats.recentEvents.isEmpty)
                          const StatusCard(
                            child: Text(
                              'No live events yet. Events appear as SMS, SIM, and sync actions occur.',
                              style: TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
                            ),
                          )
                        else
                          ..._stats.recentEvents.take(15).map(
                                (ev) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: StatusCard(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: ev.eventType.contains('FAILED')
                                                ? AppColors.errorRed
                                                : (ev.eventType.contains('DELIVERED') || ev.eventType.contains('RECEIVED'))
                                                    ? AppColors.successGreen
                                                    : AppColors.primaryBlue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ev.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              if (ev.description != null && ev.description!.isNotEmpty)
                                                Text(
                                                  ev.description!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 110),
                                          child: Text(
                                            ev.eventType.replaceAll('_', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.mutedText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
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
    );
  }

  Widget _buildSimUsageBody() {
    final entries = _stats.simUsage.isNotEmpty
        ? _stats.simUsage
        : _sims
            .map((s) => {
                  'sim_slot': s.simSlotIndex,
                  'carrier_name': s.carrierName,
                  'total': s.sentCount + s.receivedCount,
                })
            .toList();

    final totalSum = entries.fold<int>(0, (acc, e) => acc + ((e['total'] as num?)?.toInt() ?? 0));
    if (entries.isEmpty || totalSum == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No SIM traffic yet', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: CustomPaint(painter: _SimDonutPainter(entries, totalSum)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final tot = (item['total'] as num?)?.toInt() ?? 0;
              final pct = ((tot * 100) / totalSum).round();
              final slot = (item['sim_slot'] as num?)?.toInt() ?? idx;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: idx == 0 ? AppColors.primaryBlue : AppColors.successGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'SIM ${slot + 1}: $pct%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showAllEventsSheet() {
    showAppBottomSheet(
      context: context,
      icon: Icons.bolt_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'All Gateway Events',
      subtitle: 'Recent hardware, SIM, and sync telemetry',
      builder: (_) => _stats.recentEvents.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Events Recorded',
              subtitle: 'Real-time SMS and SIM events will appear here.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: _stats.recentEvents
                  .map(
                    (ev) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: StatusCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              ev.eventType.contains('FAILED') ? Icons.error_outline : Icons.bolt_rounded,
                              size: 18,
                              color: ev.eventType.contains('FAILED') ? AppColors.errorRed : AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  if (ev.description != null && ev.description!.isNotEmpty)
                                    Text(
                                      ev.description!,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                ev.eventType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 10, color: AppColors.mutedText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String val;
  final String label;
  const _MiniMetricTile({required this.icon, required this.color, required this.val, required this.label});

  @override
  Widget build(BuildContext context) {
    return StatusCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HealthLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String val;
  const _HealthLine(this.icon, this.color, this.label, this.val);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _ActivityLineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> buckets;
  _ActivityLineChartPainter(this.buckets);

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    const leftPad = 30.0;
    const bottomPad = 18.0;
    const topPad = 8.0;
    final chartW = math.max(10.0, size.width - leftPad);
    final chartH = math.max(10.0, size.height - bottomPad - topPad);

    final rawMax = buckets.fold<double>(0, (acc, b) {
      final s = (b['sent'] as num?)?.toDouble() ?? 0;
      final r = (b['received'] as num?)?.toDouble() ?? 0;
      return math.max(acc, math.max(s, r));
    });
    final maxY = math.max(4.0, (rawMax / 2).ceil() * 2.0);

    final gridPaint = Paint()..color = AppColors.divider..strokeWidth = 1;
    const labelStyle = TextStyle(fontSize: 10, color: AppColors.secondaryText, fontWeight: FontWeight.w600);

    for (int i = 0; i <= 2; i++) {
      final y = topPad + chartH * i / 2;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final tickVal = ((maxY * (2 - i)) / 2).round().toString();
      final tp = TextPainter(
        text: TextSpan(text: tickVal, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final stepIndices = buckets.length <= 4
        ? List.generate(buckets.length, (i) => i)
        : [0, buckets.length ~/ 3, (buckets.length * 2) ~/ 3, buckets.length - 1];
    for (final idx in stepIndices.toSet()) {
      final x = buckets.length == 1 ? leftPad + chartW / 2 : leftPad + (idx * chartW) / (buckets.length - 1);
      final lbl = (buckets[idx]['label'] ?? '').toString();
      final tp = TextPainter(
        text: TextSpan(text: lbl, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (x - tp.width / 2).clamp(leftPad, size.width - tp.width);
      tp.paint(canvas, Offset(dx, size.height - bottomPad + 3));
    }

    void drawSeries(String key, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      final dotPaint = Paint()..color = color;
      final path = Path();
      for (int i = 0; i < buckets.length; i++) {
        final x = buckets.length == 1 ? leftPad + chartW / 2 : leftPad + (i * chartW) / (buckets.length - 1);
        final v = (buckets[i][key] as num?)?.toDouble() ?? 0;
        final y = topPad + chartH - (v / maxY) * chartH;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3.2, dotPaint);
      }
      canvas.drawPath(path, paint);
    }

    drawSeries('sent', AppColors.primaryBlue);
    drawSeries('received', AppColors.successGreen);
  }

  @override
  bool shouldRepaint(covariant _ActivityLineChartPainter oldDelegate) => true;
}

class _SimDonutPainter extends CustomPainter {
  final List<Map<String, dynamic>> entries;
  final int total;
  _SimDonutPainter(this.entries, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    double start = -math.pi / 2;
    for (int i = 0; i < entries.length; i++) {
      final val = (entries[i]['total'] as num?)?.toDouble() ?? 0;
      final sweep = (val / total) * 2 * math.pi;
      final paint = Paint()
        ..color = i == 0 ? AppColors.primaryBlue : AppColors.successGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11;
      canvas.drawArc(rect.deflate(6), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SimDonutPainter oldDelegate) => true;
}

class DrawerTotals {
  final double todayAmount;
  final int todayCount;
  final String todayFormatted;

  final double monthAmount;
  final int monthCount;
  final String monthFormatted;

  final double yearAmount;
  final int yearCount;
  final String yearFormatted;

  const DrawerTotals({
    required this.todayAmount,
    required this.todayCount,
    required this.todayFormatted,
    required this.monthAmount,
    required this.monthCount,
    required this.monthFormatted,
    required this.yearAmount,
    required this.yearCount,
    required this.yearFormatted,
  });

  factory DrawerTotals.fromJson(Map<String, dynamic> json) {
    final t = json['today'] as Map<String, dynamic>? ?? {};
    final m = json['this_month'] as Map<String, dynamic>? ?? {};
    final y = json['this_year'] as Map<String, dynamic>? ?? {};
    return DrawerTotals(
      todayAmount: (t['amount'] as num?)?.toDouble() ?? 0.0,
      todayCount: (t['count'] as num?)?.toInt() ?? 0,
      todayFormatted: t['formatted'] as String? ?? '₹0.00',
      monthAmount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      monthCount: (m['count'] as num?)?.toInt() ?? 0,
      monthFormatted: m['formatted'] as String? ?? '₹0.00',
      yearAmount: (y['amount'] as num?)?.toDouble() ?? 0.0,
      yearCount: (y['count'] as num?)?.toInt() ?? 0,
      yearFormatted: y['formatted'] as String? ?? '₹0.00',
    );
  }

  factory DrawerTotals.fallback() {
    return const DrawerTotals(
      todayAmount: 0.0,
      todayCount: 0,
      todayFormatted: '₹0.00',
      monthAmount: 0.0,
      monthCount: 0,
      monthFormatted: '₹0.00',
      yearAmount: 0.0,
      yearCount: 0,
      yearFormatted: '₹0.00',
    );
  }
}

class ChartDataPoint {
  final String label;
  final double amount;
  final int count;

  const ChartDataPoint({
    required this.label,
    required this.amount,
    required this.count,
  });

  factory ChartDataPoint.fromJson(Map<String, dynamic> json) {
    return ChartDataPoint(
      label: json['label'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AppShareItem {
  final String name;
  final int share;
  final double amount;
  final String colorHex;

  const AppShareItem({
    required this.name,
    required this.share,
    required this.amount,
    required this.colorHex,
  });

  factory AppShareItem.fromJson(Map<String, dynamic> json) {
    return AppShareItem(
      name: json['name'] as String? ?? '',
      share: (json['share'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['color'] as String? ?? '#2563EB',
    );
  }
}

class MatchedPaymentsAnalytics {
  final String timeframe;
  final DrawerTotals drawerTotals;
  final List<ChartDataPoint> chartData;
  final double totalVolume;
  final String formattedVolume;
  final int matchedCount;
  final double avgTicketSize;
  final String formattedAvgTicket;
  final List<AppShareItem> appBreakdown;

  const MatchedPaymentsAnalytics({
    required this.timeframe,
    required this.drawerTotals,
    required this.chartData,
    required this.totalVolume,
    required this.formattedVolume,
    required this.matchedCount,
    required this.avgTicketSize,
    required this.formattedAvgTicket,
    required this.appBreakdown,
  });

  factory MatchedPaymentsAnalytics.fromJson(Map<String, dynamic> json) {
    final s = json['summary'] as Map<String, dynamic>? ?? {};
    final List<dynamic> pointsRaw = json['chart_data'] as List<dynamic>? ?? [];
    final List<dynamic> appsRaw = s['app_breakdown'] as List<dynamic>? ?? [];
    return MatchedPaymentsAnalytics(
      timeframe: json['timeframe'] as String? ?? 'today',
      drawerTotals: DrawerTotals.fromJson(json['drawer_totals'] as Map<String, dynamic>? ?? {}),
      chartData: pointsRaw.map((e) => ChartDataPoint.fromJson(e as Map<String, dynamic>)).toList(),
      totalVolume: (s['total_volume'] as num?)?.toDouble() ?? 0.0,
      formattedVolume: s['formatted_volume'] as String? ?? '₹0.00',
      matchedCount: (s['matched_count'] as num?)?.toInt() ?? 0,
      avgTicketSize: (s['avg_ticket_size'] as num?)?.toDouble() ?? 0.0,
      formattedAvgTicket: s['formatted_avg_ticket'] as String? ?? '₹0.00',
      appBreakdown: appsRaw.map((e) => AppShareItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  factory MatchedPaymentsAnalytics.fallback(String tf) {
    return MatchedPaymentsAnalytics.empty(tf);
  }

  factory MatchedPaymentsAnalytics.empty(String tf) {
    List<ChartDataPoint> pts;
    if (tf == 'today') {
      pts = const [
        ChartDataPoint(label: '00:00', amount: 0, count: 0),
        ChartDataPoint(label: '02:00', amount: 0, count: 0),
        ChartDataPoint(label: '04:00', amount: 0, count: 0),
        ChartDataPoint(label: '06:00', amount: 0, count: 0),
        ChartDataPoint(label: '08:00', amount: 0, count: 0),
        ChartDataPoint(label: '10:00', amount: 0, count: 0),
        ChartDataPoint(label: '12:00', amount: 0, count: 0),
        ChartDataPoint(label: '14:00', amount: 0, count: 0),
        ChartDataPoint(label: '16:00', amount: 0, count: 0),
        ChartDataPoint(label: '18:00', amount: 0, count: 0),
        ChartDataPoint(label: '20:00', amount: 0, count: 0),
        ChartDataPoint(label: '22:00', amount: 0, count: 0),
      ];
    } else if (tf == 'week') {
      final now = DateTime.now();
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      pts = List.generate(7, (i) {
        final d = now.subtract(Duration(days: 6 - i));
        final dayLabel = '${days[d.weekday - 1]} (${d.day})';
        return ChartDataPoint(label: dayLabel, amount: 0, count: 0);
      });
    } else if (tf == 'month') {
      pts = const [
        ChartDataPoint(label: 'Week 1', amount: 0, count: 0),
        ChartDataPoint(label: 'Week 2', amount: 0, count: 0),
        ChartDataPoint(label: 'Week 3', amount: 0, count: 0),
        ChartDataPoint(label: 'Week 4', amount: 0, count: 0),
      ];
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      pts = months.map((m) => ChartDataPoint(label: m, amount: 0, count: 0)).toList();
    }

    return MatchedPaymentsAnalytics(
      timeframe: tf,
      drawerTotals: const DrawerTotals(
        todayAmount: 0.0,
        todayCount: 0,
        todayFormatted: '₹0.00',
        monthAmount: 0.0,
        monthCount: 0,
        monthFormatted: '₹0.00',
        yearAmount: 0.0,
        yearCount: 0,
        yearFormatted: '₹0.00',
      ),
      chartData: pts,
      totalVolume: 0.0,
      formattedVolume: '₹0.00',
      matchedCount: 0,
      avgTicketSize: 0.0,
      formattedAvgTicket: '₹0.00',
      appBreakdown: const [],
    );
  }
}

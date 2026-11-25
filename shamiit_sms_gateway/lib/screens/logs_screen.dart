import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/common_components.dart';
import 'message_details_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => LogsScreenState();
}

class LogsScreenState extends State<LogsScreen> {
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  bool _isLoading = true;
  String? _error;

  String _selectedStatus = 'All';
  int? _selectedSimSlot;
  String _selectedDirection = 'ALL';
  String _applicationFilter = '';
  DateTimeRange? _dateRange;

  List<SmsMessageRecord> _messages = [];
  int _totalAllCount = 0;
  StreamSubscription? _wsSub;

  final List<String> _tabs = ['All', 'Sent', 'Received', 'Delivered', 'Failed', 'Queued', 'Scheduled'];

  @override
  void initState() {
    super.initState();
    refresh();
    _wsSub = WebSocketService().stream.listen((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      String? statusParam;
      String? directionParam = _selectedDirection;
      switch (_selectedStatus) {
        case 'Sent':
          statusParam = 'SENT';
          break;
        case 'Received':
          directionParam = 'INBOUND';
          break;
        case 'Delivered':
          statusParam = 'DELIVERED';
          break;
        case 'Failed':
          statusParam = 'FAILED';
          break;
        case 'Queued':
          statusParam = 'QUEUED';
          break;
        case 'Scheduled':
          statusParam = 'SCHEDULED';
          break;
        default:
          statusParam = null;
      }

      final items = await ApiService().getSmsHistory(
        status: statusParam,
        direction: directionParam,
        simSlot: _selectedSimSlot,
        application: _applicationFilter.isNotEmpty ? _applicationFilter : null,
        search: _searchCtrl.text,
        startDate: _dateRange?.start.toUtc().toIso8601String(),
        endDate: _dateRange?.end.add(const Duration(days: 1)).toUtc().toIso8601String(),
        limit: 150,
      );
      if (!mounted) return;
      setState(() {
        _messages = items;
        if (_selectedStatus == 'All' &&
            _selectedSimSlot == null &&
            _selectedDirection == 'ALL' &&
            _searchCtrl.text.trim().isEmpty &&
            _dateRange == null &&
            _applicationFilter.isEmpty) {
          _totalAllCount = items.length;
        }
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: _dateRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      refresh();
    }
  }

  void _showAdvancedFilters() {
    final appCtrl = TextEditingController(text: _applicationFilter);
    String dirDraft = _selectedDirection;
    showAppBottomSheet(
      context: context,
      icon: Icons.filter_alt_outlined,
      iconColor: AppColors.primaryBlue,
      title: 'Filter SMS Logs',
      subtitle: 'Filter by direction & originating application',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: dirDraft,
              decoration: const InputDecoration(labelText: 'Message Direction'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Directions')),
                DropdownMenuItem(value: 'OUTBOUND', child: Text('Outbound (Sent)')),
                DropdownMenuItem(value: 'INBOUND', child: Text('Inbound (Received)')),
              ],
              onChanged: (v) => setSheet(() => dirDraft = v ?? 'ALL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: appCtrl,
              decoration: const InputDecoration(
                labelText: 'Application Source',
                hintText: 'e.g. EduSHAMIIT, Apna School',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedDirection = 'ALL';
                        _selectedSimSlot = null;
                        _dateRange = null;
                        _applicationFilter = '';
                      });
                      Navigator.pop(ctx);
                      refresh();
                    },
                    child: const Text('Reset All'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Apply Filters'),
                    onPressed: () {
                      setState(() {
                        _selectedDirection = dirDraft;
                        _applicationFilter = appCtrl.text.trim();
                      });
                      Navigator.pop(ctx);
                      refresh();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateRange == null
        ? 'All Dates'
        : '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}';

    return SkyHeaderContainer(
      child: Column(
        children: [
          AppTopBar(
            title: 'SMS Logs',
            actions: [
              IconButton(
                icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded),
                onPressed: () => setState(() => _showSearch = !_showSearch),
              ),
              IconButton(
                icon: const Icon(Icons.filter_alt_outlined),
                onPressed: _showAdvancedFilters,
              ),
            ],
          ),
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppSearchBar(
                controller: _searchCtrl,
                onChanged: (_) => refresh(),
                onClear: refresh,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilterChips(
              options: _tabs
                  .map((t) => t == 'All' ? 'All (${NumberFormat.decimalPattern().format(_selectedStatus == 'All' ? _messages.length : _totalAllCount)})' : t)
                  .toList(),
              selected: _selectedStatus == 'All'
                  ? 'All (${NumberFormat.decimalPattern().format(_messages.length)})'
                  : _selectedStatus,
              onSelected: (val) {
                setState(() => _selectedStatus = val.startsWith('All') ? 'All' : val);
                refresh();
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: StatusCard(
                    onTap: _pickDateRange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 17, color: AppColors.primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatusCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedSimSlot,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All SIM', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 0, child: Text('SIM 1', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 1, child: Text('SIM 2', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedSimSlot = v);
                          refresh();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const LoadingState(message: 'Loading SMS logs...')
                : _error != null && _messages.isEmpty
                    ? ErrorState(message: _error!, onRetry: refresh)
                    : _messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'No SMS Records Found',
                            subtitle: 'Messages matching the active filters will appear here.',
                          )
                        : RefreshIndicator(
                            onRefresh: refresh,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              itemCount: _messages.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final m = _messages[idx];
                                return MessageListItem(
                                  message: m,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MessageDetailsScreen(
                                        messageUuid: m.messageUuid,
                                        initialRecord: m,
                                      ),
                                    ),
                                  ).then((_) => refresh()),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

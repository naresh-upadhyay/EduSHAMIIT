import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportTab extends ConsumerStatefulWidget {
  const SupportTab({super.key});

  @override
  ConsumerState<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends ConsumerState<SupportTab> {
  List<dynamic> _tickets = [];
  Map<String, dynamic> _stats = {};
  int _totalRecords = 0;
  bool _isLoading = true;

  dynamic _selectedTicket;
  List<dynamic> _messages = [];
  bool _isLoadingMessages = false;
  List<dynamic> _attachments = [];
  bool _isLoadingAttachments = false;
  String _activeTab = 'Conversation'; // 'Conversation', 'Notes', 'Attachments'

  final _replyController = TextEditingController();
  final _searchController = TextEditingController();
  String _messageType = 'conversation'; // 'conversation' or 'note'

  // Pagination & Filtering state
  int _currentPage = 0;
  int _pageSize = 10;
  String _searchQuery = "";
  String _selectedStatus = "All Status";
  String _selectedPriority = "All Priorities";
  String _selectedCategory = "All Categories";
  String _selectedInstitution = "All Institutions";

  List<dynamic> _schools = [];
  List<dynamic> _users = [];
  bool _isWideScreen = false;

  // View state for mobile/webview responsive design
  bool _isCreating = false;
  String _currentView = 'list'; // 'list', 'create', 'details'

  // Create form state variables
  final _createSubjectController = TextEditingController();
  final _createDescriptionController = TextEditingController();
  String _createCategory = 'Login / Access';
  String _createPriority = 'Low';
  String? _createSchoolId;
  String? _createRequestedById;

  final List<String> _categories = [
    'Login / Access',
    'Academics',
    'Fees',
    'Documents',
    'Notifications',
    'Library',
    'Transport',
    'Performance',
    'User Management',
    'System',
    'Others'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];
  final List<String> _statuses = ['Open', 'In Progress', 'Pending User', 'Resolved', 'Closed'];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _searchController.dispose();
    _createSubjectController.dispose();
    _createDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([
      _fetchSchools(),
      _fetchUsers(),
    ]);
    if (_schools.isNotEmpty) {
      _createSchoolId = _schools.first['id'].toString();
    }
    if (_users.isNotEmpty) {
      _createRequestedById = _users.first['id'].toString();
    }
    _fetchTickets();
  }

  Future<void> _fetchSchools() async {
    try {
      final res = await ApiService().get('/admin/schools', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _schools = res['data']['schools'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      print("Error fetching schools: $e");
    }
  }

  Future<void> _fetchUsers() async {
    try {
      final res = await ApiService().get('/auth/users', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _users = res['data'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final queryParams = <String, String>{
        'page': (_currentPage + 1).toString(),
        'page_size': _pageSize.toString(),
      };
      if (_selectedStatus != "All Status") {
        queryParams['status'] = _selectedStatus;
      }
      if (_selectedPriority != "All Priorities") {
        queryParams['priority'] = _selectedPriority;
      }
      if (_selectedCategory != "All Categories") {
        queryParams['category'] = _selectedCategory;
      }
      if (_selectedInstitution != "All Institutions") {
        queryParams['school_id'] = _selectedInstitution;
      }
      if (_searchQuery.isNotEmpty) {
        queryParams['search'] = _searchQuery;
      }

      final uri = Uri(path: '/admin/tickets', queryParameters: queryParams);
      final res = await ApiService().get(uri.toString(), useCache: false);
      if (res['success'] == true) {
        setState(() {
          _tickets = res['data']['tickets'] as List<dynamic>? ?? [];
          _totalRecords = res['data']['total_records'] as int? ?? 0;
          _stats = res['data']['stats'] as Map<String, dynamic>? ?? {};

          if (_tickets.isNotEmpty) {
            final currentId = _selectedTicket?['id'];
            final found = _tickets.firstWhere((t) => t['id'] == currentId, orElse: () => null);
            _selectedTicket = found ?? _tickets.first;
            _fetchTicketMessages(_selectedTicket['id']);
          } else {
            _selectedTicket = null;
            _messages = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load tickets: $e")),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTicketMessages(String ticketId) async {
    setState(() {
      _isLoadingMessages = true;
    });
    // Fetch both messages and attachments
    _fetchTicketAttachments(ticketId);
    try {
      final res = await ApiService().get('/admin/tickets/$ticketId/messages', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _messages = res['data'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      print("Error loading messages: $e");
    } finally {
      setState(() {
        _isLoadingMessages = false;
      });
    }
  }

  Future<void> _fetchTicketAttachments(String ticketId) async {
    setState(() {
      _isLoadingAttachments = true;
    });
    try {
      final res = await ApiService().get('/admin/tickets/$ticketId/attachments', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _attachments = res['data'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      print("Error loading attachments: $e");
    } finally {
      setState(() {
        _isLoadingAttachments = false;
      });
    }
  }

  Future<void> _uploadAttachment() async {
    if (_selectedTicket == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _isLoadingAttachments = true;
      });

      final response = await ApiService().multipartPostBytes(
        '/admin/tickets/${_selectedTicket['id']}/attachments',
        bytes,
        picked.name,
        'file',
      );

      if (response['success'] == true) {
        _fetchTicketAttachments(_selectedTicket['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attachment uploaded successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        throw Exception(response['detail'] ?? 'Failed to upload attachment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAttachments = false;
        });
      }
    }
  }

  Future<void> _postMessage() async {
    if (_replyController.text.trim().isEmpty || _selectedTicket == null) return;
    final messageText = _replyController.text.trim();
    _replyController.clear();

    final currentUser = ref.read(authProvider).userData;
    final senderId = currentUser?['id'];
    if (senderId == null) return;

    try {
      final payload = {
        'sender_id': senderId,
        'message': messageText,
        'message_type': _messageType
      };
      final res = await ApiService().post('/admin/tickets/${_selectedTicket['id']}/messages', payload);
      if (res['success'] == true) {
        setState(() {
          _messages.add(res['data']);
        });
        _fetchTickets(); // Refresh lists
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send reply: $e")),
        );
      }
    }
  }

  Future<void> _updateTicketStatus(String status) async {
    if (_selectedTicket == null) return;
    try {
      final res = await ApiService().put('/admin/tickets/${_selectedTicket['id']}', {'status': status});
      if (res['success'] == true) {
        setState(() {
          _selectedTicket['status'] = status;
        });
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ticket status updated to $status")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e")),
        );
      }
    }
  }

  Future<void> _updateTicketPriority(String priority) async {
    if (_selectedTicket == null) return;
    try {
      final res = await ApiService().put('/admin/tickets/${_selectedTicket['id']}', {'priority': priority});
      if (res['success'] == true) {
        setState(() {
          _selectedTicket['priority'] = priority;
        });
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ticket priority updated to $priority")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update priority: $e")),
        );
      }
    }
  }

  Future<void> _updateTicketCategory(String category) async {
    if (_selectedTicket == null) return;
    try {
      final res = await ApiService().put('/admin/tickets/${_selectedTicket['id']}', {'category': category});
      if (res['success'] == true) {
        setState(() {
          _selectedTicket['category'] = category;
        });
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Ticket category updated to $category")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update category: $e")),
        );
      }
    }
  }

  Future<void> _updateTicketAssignment(String? userId) async {
    if (_selectedTicket == null) return;
    try {
      final res = await ApiService().put('/admin/tickets/${_selectedTicket['id']}', {'assigned_to_id': userId ?? ""});
      if (res['success'] == true) {
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ticket assignment updated successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update assignment: $e")),
        );
      }
    }
  }

  Future<void> _assignTicketToMe() async {
    if (_selectedTicket == null) return;
    final currentUser = ref.read(authProvider).userData;
    final staffId = currentUser?['id'];
    if (staffId == null) return;

    try {
      final res = await ApiService().put('/admin/tickets/${_selectedTicket['id']}', {'assigned_to_id': staffId});
      if (res['success'] == true) {
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ticket assigned to you successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to assign ticket: $e")),
        );
      }
    }
  }

  Future<void> _deleteTicket(String id) async {
    try {
      final res = await ApiService().delete('/admin/tickets/$id');
      if (res['success'] == true) {
        setState(() {
          if (_selectedTicket?['id'] == id) {
            _selectedTicket = null;
          }
          _currentView = 'list';
        });
        _fetchTickets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ticket deleted successfully!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete ticket: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    _isWideScreen = MediaQuery.of(context).size.width >= 1100;

    if (_isWideScreen) {
      // Desktop / Tablet Landscape Split-Screen View
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        body: Row(
          children: [
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme, isDark),
                    const SizedBox(height: 24),
                    _buildMetricsGrid(isDark),
                    const SizedBox(height: 24),
                    _buildFiltersRow(theme, isDark),
                    const SizedBox(height: 16),
                    _buildTicketsTable(theme, isDark),
                    const SizedBox(height: 16),
                    _buildPaginationFooter(theme, isDark),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                ),
                child: _isCreating
                    ? _buildCreateTicketForm(theme, isDark)
                    : _buildDetailsPanel(theme, isDark),
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile / Webview Navigation Stack View (Zero popup dialog overlays)
      Widget currentBody;
      if (_currentView == 'create') {
        currentBody = _buildCreateTicketForm(theme, isDark);
      } else if (_currentView == 'details') {
        currentBody = _buildDetailsPanel(theme, isDark);
      } else {
        currentBody = SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, isDark),
              const SizedBox(height: 16),
              _buildMetricsGrid(isDark),
              const SizedBox(height: 16),
              _buildFiltersRow(theme, isDark),
              const SizedBox(height: 16),
              _buildTicketsTable(theme, isDark),
              const SizedBox(height: 16),
              _buildPaginationFooter(theme, isDark),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
        body: SafeArea(child: currentBody),
      );
    }
  }

  // ===========================================================
  // UI Builder Components
  // ===========================================================

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IT Support Tickets',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage and resolve technical issues reported by users across all institutions.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontFamily: 'Outfit',
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _isCreating = true;
              _currentView = 'create';
            });
          },
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: const Text('New Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    const double cardWidth = 150.0;
    final cardStats = [
      {'title': 'Total Tickets', 'key': 'total', 'icon': Icons.all_inbox_rounded, 'color': const Color(0xFF4F46E5)},
      {'title': 'Open Tickets', 'key': 'open', 'icon': Icons.folder_open_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': 'In Progress', 'key': 'in_progress', 'icon': Icons.loop_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Pending User', 'key': 'pending', 'icon': Icons.hourglass_empty_rounded, 'color': const Color(0xFFEC4899)},
      {'title': 'Resolved', 'key': 'resolved', 'icon': Icons.check_circle_outline_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Closed', 'key': 'closed', 'icon': Icons.cancel_outlined, 'color': const Color(0xFFEF4444)},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cardStats.length,
        itemBuilder: (context, index) {
          final item = cardStats[index];
          final statKey = item['key']!;
          final statData = _stats[statKey] ?? {'value': 0, 'trend': '0.0%', 'is_up': true};
          final int value = statData['value'] ?? 0;
          final String trend = statData['trend'] ?? '0.0%';
          final bool isUp = statData['is_up'] ?? true;
          final Color accentColor = item['color'] as Color;

          return Container(
            width: cardWidth,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['title'] as String,
                      style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Icon(item['icon'] as IconData, color: accentColor.withOpacity(0.8), size: 16),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value.toString(),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    Row(
                      children: [
                        Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 10),
                        const SizedBox(width: 2),
                        Text(
                          trend,
                          style: TextStyle(
                            color: isUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltersRow(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 0;
                    });
                    _fetchTickets();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search tickets...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 16),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = "";
                    });
                    _fetchTickets();
                  },
                ),
            ],
          ),
          const Divider(height: 12, color: Colors.white10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdownFilter(_selectedStatus, ["All Status", ..._statuses], (val) {
                  setState(() {
                    _selectedStatus = val!;
                    _currentPage = 0;
                  });
                  _fetchTickets();
                }, theme, isDark),
                const SizedBox(width: 8),
                _buildDropdownFilter(_selectedPriority, ["All Priorities", ..._priorities], (val) {
                  setState(() {
                    _selectedPriority = val!;
                    _currentPage = 0;
                  });
                  _fetchTickets();
                }, theme, isDark),
                const SizedBox(width: 8),
                _buildDropdownFilter(_selectedCategory, ["All Categories", ..._categories], (val) {
                  setState(() {
                    _selectedCategory = val!;
                    _currentPage = 0;
                  });
                  _fetchTickets();
                }, theme, isDark),
                const SizedBox(width: 8),
                _buildDropdownFilter(
                  _selectedInstitution,
                  ["All Institutions", ..._schools.map((s) => s['id'].toString())],
                  (val) {
                    setState(() {
                      _selectedInstitution = val!;
                      _currentPage = 0;
                    });
                    _fetchTickets();
                  },
                  theme,
                  isDark,
                  displayMapper: (val) {
                    if (val == "All Institutions") return val;
                    final sch = _schools.firstWhere((s) => s['id'] == val, orElse: () => null);
                    return sch != null ? sch['name'].toString() : val;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(
    String value,
    List<String> items,
    void Function(String?) onChanged,
    ThemeData theme,
    bool isDark, {
    String Function(String)? displayMapper,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: theme.cardColor,
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(displayMapper != null ? displayMapper(item) : item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTicketsTable(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.inbox, color: isDark ? Colors.white24 : Colors.black26, size: 40),
              const SizedBox(height: 12),
              Text('No support tickets found.', style: TextStyle(color: isDark ? Colors.white60 : Colors.black45, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 20,
          headingRowHeight: 44,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 72,
          columns: [
            DataColumn(label: FittedBox(child: Text('Ticket ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Requested By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Institution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Updated On', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
            DataColumn(label: FittedBox(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF0F172A))))),
          ],
          rows: _tickets.map((ticket) {
            final isSelected = _selectedTicket?['id'] == ticket['id'];
            final reqUser = ticket['requested_by'] ?? {};
            final school = ticket['school'] ?? {};

            final String updatedOnRaw = ticket['updated_at'] ?? ticket['created_at'] ?? '';
            String formattedDate = '';
            if (updatedOnRaw.isNotEmpty) {
              try {
                final date = DateTime.parse(updatedOnRaw);
                formattedDate = DateFormat('MMM dd, yyyy\nhh:mm a').format(date);
              } catch (_) {
                formattedDate = updatedOnRaw;
              }
            }

            return DataRow(
              selected: isSelected,
              onSelectChanged: (_) {
                setState(() {
                  _selectedTicket = ticket;
                  _isCreating = false;
                  _currentView = 'details';
                });
                _fetchTicketMessages(ticket['id']);
              },
              cells: [
                DataCell(Text(ticket['ticket_code'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(ticket['subject'] ?? '', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(ticket['category'] ?? 'Others', style: const TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(ticket['description'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(_buildPriorityBadge(ticket['priority'] ?? 'Low')),
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF4F46E5),
                        backgroundImage: reqUser['avatar_url'] != null ? NetworkImage(reqUser['avatar_url']) : null,
                        child: reqUser['avatar_url'] == null
                            ? Text(
                                (reqUser['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(reqUser['full_name'] ?? 'Unknown User', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(reqUser['role'] != null ? reqUser['role'].toString().toUpperCase() : 'USER', style: const TextStyle(color: Color(0xFF64748B), fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Container(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      school['name'] ?? 'Global System',
                      style: TextStyle(color: isDark ? Colors.white60 : const Color(0xFF0F172A), fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(_buildStatusBadge(ticket['status'] ?? 'Open')),
                DataCell(Text(formattedDate, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10))),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                    onPressed: () {
                      _showConfirmDeleteDialog(ticket['id']);
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg = const Color(0xFF10B981).withOpacity(0.1);
    Color fg = const Color(0xFF10B981);

    if (priority == 'High') {
      bg = const Color(0xFFEF4444).withOpacity(0.1);
      fg = const Color(0xFFEF4444);
    } else if (priority == 'Medium') {
      bg = const Color(0xFFF59E0B).withOpacity(0.1);
      fg = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(priority, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFF3B82F6).withOpacity(0.1);
    Color fg = const Color(0xFF3B82F6);

    switch (status) {
      case 'In Progress':
        bg = const Color(0xFF8B5CF6).withOpacity(0.1);
        fg = const Color(0xFF8B5CF6);
        break;
      case 'Pending User':
        bg = const Color(0xFFF59E0B).withOpacity(0.1);
        fg = const Color(0xFFF59E0B);
        break;
      case 'Resolved':
        bg = const Color(0xFF10B981).withOpacity(0.1);
        fg = const Color(0xFF10B981);
        break;
      case 'Closed':
        bg = const Color(0xFF64748B).withOpacity(0.1);
        fg = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPaginationFooter(ThemeData theme, bool isDark) {
    final totalPages = max(1, (_totalRecords / _pageSize).ceil());
    final startIndex = _currentPage * _pageSize;
    final endIndex = min(startIndex + _pageSize, _totalRecords);

    final showingText = Text(
      "Showing ${startIndex + 1} to $endIndex of $_totalRecords tickets",
      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
    );

    final pageSizeSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("Show", style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 11)),
        const SizedBox(width: 6),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _pageSize,
              dropdownColor: theme.cardColor,
              icon: const Icon(Icons.arrow_drop_down, size: 14),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _pageSize = val;
                    _currentPage = 0;
                  });
                  _fetchTickets();
                }
              },
              items: [5, 10, 20, 50].map((int val) {
                return DropdownMenuItem<int>(
                  value: val,
                  child: Text(val.toString()),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text("entries", style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 11)),
      ],
    );

    final navigationControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _currentPage > 0
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                  _fetchTickets();
                }
              : null,
          icon: const Icon(Icons.arrow_back_ios, size: 12),
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          disabledColor: isDark ? Colors.white24 : Colors.black26,
        ),
        ...List.generate(totalPages, (index) {
          final isCurrent = index == _currentPage;
          return InkWell(
            onTap: () {
              setState(() {
                _currentPage = index;
              });
              _fetchTickets();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF4F46E5) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (index + 1).toString(),
                style: TextStyle(
                  color: isCurrent ? Colors.white : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
        IconButton(
          onPressed: _currentPage < (totalPages - 1)
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                  _fetchTickets();
                }
              : null,
          icon: const Icon(Icons.arrow_forward_ios, size: 12),
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          disabledColor: isDark ? Colors.white24 : Colors.black26,
        ),
      ],
    );

    final width = MediaQuery.of(context).size.width;
    final isMobilePagination = width < 600;

    return isMobilePagination
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  showingText,
                  pageSizeSelector,
                ],
              ),
              const SizedBox(height: 10),
              navigationControls,
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  showingText,
                  const SizedBox(width: 16),
                  pageSizeSelector,
                ],
              ),
              navigationControls,
            ],
          );
  }

  Widget _buildDetailsPanel(ThemeData theme, bool isDark) {
    if (_selectedTicket == null) {
      return const Center(child: Text("Select a ticket to view details"));
    }

    final reqUser = _selectedTicket['requested_by'] ?? {};
    final school = _selectedTicket['school'] ?? {};
    final assignedUser = _selectedTicket['assigned_to'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket Header Info
                Padding(
                  padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (!_isWideScreen)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            setState(() {
                              _currentView = 'list';
                            });
                          },
                        ),
                      Text(
                        "Ticket ID: ${_selectedTicket['ticket_code']}",
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildStatusBadge(_selectedTicket['status'] ?? 'Open'),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          _showConfirmDeleteDialog(_selectedTicket['id']);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _selectedTicket['subject'] ?? '',
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedTicket['description'] ?? '',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white10),

        // Quick Metadata Grid (Full CRUD Editable Dropdowns)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              _buildDetailAttributeRow("Requested By", reqUser['full_name'] ?? 'Unknown User', isDark),
              _buildDetailAttributeRow("Institution", school['name'] ?? 'Global System', isDark),
              _buildDetailAttributeRowWidget(
                "Category",
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTicket['category'] ?? 'Others',
                    isDense: true,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                    onChanged: (val) {
                      if (val != null) _updateTicketCategory(val);
                    },
                    items: _categories.map((String c) {
                      return DropdownMenuItem<String>(value: c, child: Text(c));
                    }).toList(),
                  ),
                ),
                isDark,
              ),
              _buildDetailAttributeRowWidget(
                "Priority",
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTicket['priority'] ?? 'Low',
                    isDense: true,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                    onChanged: (val) {
                      if (val != null) _updateTicketPriority(val);
                    },
                    items: _priorities.map((String p) {
                      return DropdownMenuItem<String>(value: p, child: Text(p));
                    }).toList(),
                  ),
                ),
                isDark,
              ),
              _buildDetailAttributeRowWidget(
                "Assigned To",
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: assignedUser != null ? assignedUser['id'].toString() : null,
                    isDense: true,
                    hint: const Text("Not Assigned", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                    onChanged: (val) {
                      _updateTicketAssignment(val);
                    },
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("Not Assigned"),
                      ),
                      ..._users.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['id'].toString(),
                          child: Text(u['full_name'].toString()),
                        );
                      }),
                    ],
                  ),
                ),
                isDark,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white10),

        // Action Buttons Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Status:', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _statuses.map((status) {
                  final isCurrent = _selectedTicket['status'] == status;
                  return InkWell(
                    onTap: () => _updateTicketStatus(status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF4F46E5) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCurrent ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isCurrent ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF0F172A)),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Colors.white10),

        // Tabs Header
        Row(
          children: ['Conversation', 'Notes', 'Attachments'].map((tabName) {
            final isActive = _activeTab == tabName;
            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _activeTab = tabName;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: isActive ? const Color(0xFF4F46E5) : Colors.transparent, width: 2)),
                  ),
                  child: Center(
                    child: Text(
                      tabName,
                      style: TextStyle(
                        color: isActive ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const Divider(height: 1, color: Colors.white10),

        // Conversation list or Notes / Attachments placeholder
        Expanded(child: _buildTabContent(theme, isDark)),

        // Reply input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              // Message Type Switcher
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Reply Customer', style: TextStyle(fontSize: 10)),
                    selected: _messageType == 'conversation',
                    onSelected: (val) {
                      setState(() {
                        _messageType = 'conversation';
                      });
                    },
                    selectedColor: const Color(0xFF4F46E5).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Internal Note', style: TextStyle(fontSize: 10)),
                    selected: _messageType == 'note',
                    onSelected: (val) {
                      setState(() {
                        _messageType = 'note';
                      });
                    },
                    selectedColor: Colors.amber.withOpacity(0.2),
                    checkmarkColor: Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
                      ),
                      child: TextField(
                        controller: _replyController,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                        decoration: InputDecoration(
                          hintText: _messageType == 'conversation' ? 'Type your reply...' : 'Type internal note (staff only)...',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF4F46E5)),
                    onPressed: _postMessage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailAttributeRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDetailAttributeRowWidget(String label, Widget valueWidget, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
          valueWidget,
        ],
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, bool isDark) {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeTab == 'Attachments') {
      return _buildAttachmentsTab(isDark);
    }

    final typeFilter = _activeTab == 'Conversation' ? 'conversation' : 'note';
    final filteredMsgs = _messages.where((m) => m['message_type'] == typeFilter).toList();

    if (filteredMsgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _activeTab == 'Conversation' ? "No public conversation logs." : "No internal staff notes.",
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMsgs.length,
      itemBuilder: (context, index) {
        final msg = filteredMsgs[index];
        final sender = msg['sender'] ?? {};
        final bool isNote = msg['message_type'] == 'note';

        final String dateRaw = msg['created_at'] ?? '';
        String formattedDate = '';
        if (dateRaw.isNotEmpty) {
          try {
            formattedDate = DateFormat('MMM dd, hh:mm a').format(DateTime.parse(dateRaw));
          } catch (_) {
            formattedDate = dateRaw;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isNote
                ? Colors.amber.withOpacity(0.05)
                : (isDark ? Colors.white.withOpacity(0.01) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isNote ? Colors.amber.withOpacity(0.3) : (isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF4F46E5),
                backgroundImage: sender['avatar_url'] != null ? NetworkImage(sender['avatar_url']) : null,
                child: sender['avatar_url'] == null
                    ? Text(
                        (sender['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sender['full_name'] ?? 'Unknown User',
                          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(formattedDate, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg['message'] ?? '',
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsTab(bool isDark) {
    if (_isLoadingAttachments) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Files & Documents (${_attachments.length})",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _uploadAttachment,
                icon: const Icon(Icons.upload_file_rounded, size: 14),
                label: const Text("Upload File", style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _attachments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.attachment_rounded, size: 28, color: isDark ? Colors.white30 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          "No attachments uploaded yet.",
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _attachments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final att = _attachments[index];
                      final uploaderId = att['uploaded_by']?.toString();
                      final uploader = _users.firstWhere((u) => u['id'].toString() == uploaderId, orElse: () => {});
                      final dateStr = att['created_at'] != null
                          ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(att['created_at']))
                          : '';
                      final sizeKb = att['file_size'] != null
                          ? '${(att['file_size'] / 1024).toStringAsFixed(1)} KB'
                          : 'Unknown Size';

                      IconData fileIcon = Icons.insert_drive_file_outlined;
                      Color fileColor = const Color(0xFF64748B);
                      final type = att['file_type']?.toString().toLowerCase() ?? '';
                      if (type.contains('image')) {
                        fileIcon = Icons.image_outlined;
                        fileColor = const Color(0xFF10B981);
                      } else if (type.contains('pdf')) {
                        fileIcon = Icons.picture_as_pdf_outlined;
                        fileColor = const Color(0xFFEF4444);
                      } else if (type.contains('zip') || type.contains('tar')) {
                        fileIcon = Icons.folder_zip_outlined;
                        fileColor = const Color(0xFFF59E0B);
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: fileColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(fileIcon, color: fileColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    att['file_name'] ?? 'attachment',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Size: $sizeKb • Uploaded by: ${uploader['full_name'] ?? 'Staff'} • $dateStr",
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF4F46E5), size: 18),
                              onPressed: () async {
                                final url = att['file_url']?.toString() ?? '';
                                if (url.isNotEmpty) {
                                  try {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not open file: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================
  // Inline/FullScreen Responsive Create Ticket View Form
  // ===========================================================

  Widget _buildCreateTicketForm(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!_isWideScreen)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _isCreating = false;
                      _currentView = 'list';
                    });
                  },
                ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.support_agent_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create New Support Ticket',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          TextField(
            controller: _createSubjectController,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
            decoration: _buildInputDecoration('Subject', 'e.g. Printer offline', Icons.title, theme, isDark),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _createDescriptionController,
            maxLines: 3,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
            decoration: _buildInputDecoration('Description', 'Provide details of the problem...', Icons.description, theme, isDark),
          ),
          const SizedBox(height: 16),

          _buildDialogDropdown("Category", _createCategory, _categories, (val) {
            setState(() {
              _createCategory = val!;
            });
          }, theme, isDark),
          const SizedBox(height: 16),

          _buildDialogDropdown("Priority", _createPriority, _priorities, (val) {
            setState(() {
              _createPriority = val!;
            });
          }, theme, isDark),
          const SizedBox(height: 16),

          if (_schools.isNotEmpty)
            _buildDialogDropdown(
              "Institution",
              _createSchoolId ?? _schools.first['id'].toString(),
              _schools.map((s) => s['id'].toString()).toList(),
              (val) {
                setState(() {
                  _createSchoolId = val!;
                });
              },
              theme,
              isDark,
              displayMapper: (id) {
                final match = _schools.firstWhere((s) => s['id'].toString() == id, orElse: () => null);
                return match != null ? match['name'].toString() : id;
              },
            ),
          const SizedBox(height: 16),

          if (_users.isNotEmpty)
            _buildDialogDropdown(
              "Requested By",
              _createRequestedById ?? _users.first['id'].toString(),
              _users.map((u) => u['id'].toString()).toList(),
              (val) {
                setState(() {
                  _createRequestedById = val!;
                });
              },
              theme,
              isDark,
              displayMapper: (id) {
                final match = _users.firstWhere((u) => u['id'].toString() == id, orElse: () => null);
                return match != null ? match['full_name'].toString() : id;
              },
            ),

          const SizedBox(height: 24),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isCreating = false;
                    _currentView = 'list';
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () async {
                  if (_createSubjectController.text.trim().isEmpty) return;
                  try {
                    final payload = {
                      'subject': _createSubjectController.text.trim(),
                      'description': _createDescriptionController.text.trim(),
                      'category': _createCategory,
                      'priority': _createPriority,
                      'school_id': _createSchoolId ?? _schools.first['id'].toString(),
                      'requested_by_id': _createRequestedById ?? _users.first['id'].toString()
                    };
                    final res = await ApiService().post('/admin/tickets', payload);
                    if (res['success'] == true) {
                      _createSubjectController.clear();
                      _createDescriptionController.clear();
                      setState(() {
                        _isCreating = false;
                        _currentView = 'list';
                      });
                      _fetchTickets();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Support ticket created successfully!")),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to create ticket: $e")),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConfirmDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('Delete Ticket', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A))),
          content: Text('Are you sure you want to delete this support ticket permanently?', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteTicket(id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
    ThemeData theme,
    bool isDark, {
    String Function(String)? displayMapper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: theme.cardColor,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(displayMapper != null ? displayMapper(item) : item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon, ThemeData theme, bool isDark) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 16),
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }
}

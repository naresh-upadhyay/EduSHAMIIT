import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'package:edu_shamiit_admin/core/file_download_helper.dart';

import 'widgets/manage_categories_dialog.dart';
import 'widgets/create_policy_dialog.dart';
import 'widgets/upload_document_dialog.dart';
import 'widgets/policy_detail_drawer.dart';
import 'widgets/document_detail_drawer.dart';
import 'widgets/template_detail_drawer.dart';
import 'widgets/request_acknowledgement_dialog.dart';
import 'widgets/policy_acknowledgement_dialog.dart';
import 'widgets/template_editor_dialog.dart';
import 'widgets/reports_dialog.dart';

class HRPoliciesScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialItemsForTesting;
  final Set<String>? initialSelectedIdsForTesting;

  const HRPoliciesScreen({
    super.key,
    this.initialItemsForTesting,
    this.initialSelectedIdsForTesting,
  });

  @override
  State<HRPoliciesScreen> createState() => _HRPoliciesScreenState();
}

class _HRPoliciesScreenState extends State<HRPoliciesScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Global State
  bool _isLoadingMetrics = true;
  bool _isLoadingTable = true;
  String? _errorMessage;

  // KPIs
  Map<String, dynamic> _metrics = {
    'total_policies': 0,
    'total_documents': 0,
    'total_templates': 0,
    'total_categories': 0,
    'recently_updated': 0,
    'my_acknowledgements': 0,
    'pending_acknowledgements': 0,
    'expiring_soon': 0,
    'review_due': 0,
    'compliance_rate': 100.0,
    'policies_trend': '0% vs last month',
    'documents_trend': '0% vs last month',
    'categories_trend': '0% vs last month',
    'recently_trend': '0% vs last month',
  };

  // Categories
  List<dynamic> _categories = [];

  // Workspace Tabs: 0: Policies, 1: Documents, 2: Templates, 3: Expiring Soon, 4: My Acknowledgements
  int _activeWorkspaceTab = 0;
  final List<String> _workspaceTabs = [
    'Policies',
    'Documents',
    'Templates',
    'Expiring Soon',
    'My Acknowledgements',
  ];

  // Document Type filters
  List<String> _documentTypeFilterOptions = ['All Types', 'Policy', 'Guideline', 'Contract', 'Form', 'Handbook'];
  String _selectedCategoryFilter = 'All Categories';
  String _selectedTypeFilter = 'All Types';
  String _sortBy = 'latest';

  // Table Data & Pagination
  List<dynamic> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  int _pageSize = 10;

  // Multi-select state
  Set<String> _selectedItemIds = {};

  // Grid Sorting State
  int? _sortColumnIndex = 5; // Default sort by 'Last Updated'
  bool _sortAscending = false; // Default sort descending (most recent first)

  String _searchQuery = '';

  Timer? _debounceTimer;
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    if (widget.initialItemsForTesting != null) {
      _items = List.from(widget.initialItemsForTesting!);
      if (_sortColumnIndex != null) {
        _sortItemsList(_items, _sortColumnIndex!, _sortAscending);
      }
      _isLoadingTable = false;
      _isLoadingMetrics = false;
      if (widget.initialSelectedIdsForTesting != null) {
        _selectedItemIds = Set.from(widget.initialSelectedIdsForTesting!);
      }
    } else {
      _loadInitialData();
    }
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadTypeLookups(true);
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchMetrics(),
      _fetchCategories(),
      _fetchTableData(),
      _loadTypeLookups(true),
    ]);
    if (_metrics['total_templates'] == null || _metrics['total_templates'] == 0) {
      try {
        final tRes = await _api.get('/hr/templates', useCache: false);
        if (tRes['success'] == true && mounted) {
          final tList = tRes['data'] as List<dynamic>? ?? [];
          if (tList.isNotEmpty) {
            setState(() {
              _metrics['total_templates'] = tList.length;
            });
          }
        }
      } catch (_) {}
    }
    if (_metrics['my_acknowledgements'] == null || _metrics['my_acknowledgements'] == 0) {
      try {
        final aRes = await _api.get('/hr/acknowledgements/my', useCache: false);
        if (aRes['success'] == true && mounted) {
          final aList = aRes['data'] as List<dynamic>? ?? [];
          if (aList.isNotEmpty) {
            setState(() {
              _metrics['my_acknowledgements'] = aList.length;
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadTypeLookups([bool forceRefresh = true]) async {
    final types = await HRLookupHelper.instance.getLookupLabels('HR_DOCUMENT_TYPE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _documentTypeFilterOptions = ['All Types', ...types];
        if (!_documentTypeFilterOptions.contains(_selectedTypeFilter)) {
          _selectedTypeFilter = 'All Types';
        }
      });
    }
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoadingMetrics = true);
    try {
      final res = await _api.get('/hr/stats', useCache: false);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _metrics = data['metrics'] ?? _metrics;
          _isLoadingMetrics = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingMetrics = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await _api.get('/hr/categories', useCache: false);
      if (res['success'] == true && mounted) {
        setState(() {
          _categories = res['data'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTableData() async {
    setState(() => _isLoadingTable = true);
    _selectedItemIds.clear();

    try {
      Map<String, dynamic> query = {
        'page': _currentPage,
        'page_size': _pageSize,
        'search': _searchQuery,
        'sort_by': _sortBy,
      };

      if (_selectedCategoryFilter != 'All Categories') {
        query['category'] = _selectedCategoryFilter;
      }
      if (_selectedTypeFilter != 'All Types') {
        query['type'] = _selectedTypeFilter;
      }

      String endpoint = '/hr/policies';
      if (_activeWorkspaceTab == 0) {
        endpoint = '/hr/policies';
      } else if (_activeWorkspaceTab == 1) {
        endpoint = '/hr/documents';
      } else if (_activeWorkspaceTab == 2) {
        endpoint = '/hr/templates';
      } else if (_activeWorkspaceTab == 3) {
        endpoint = '/hr/documents/expiring';
        query['days'] = 90;
      } else if (_activeWorkspaceTab == 4) {
        endpoint = '/hr/acknowledgements/my';
      }

      final res = await _api.get(endpoint, query: query, useCache: false);
      if (res['success'] == true) {
        final data = res['data'] as List<dynamic>? ?? [];
        final meta = res['meta'] as Map<String, dynamic>? ?? {};

        setState(() {
          _items = List.from(data);
          if (_sortColumnIndex != null) {
            _sortItemsList(_items, _sortColumnIndex!, _sortAscending);
          }
          _totalRecords = meta['total'] ?? data.length;
          _totalPages = meta['total_pages'] ?? ((_totalRecords / _pageSize).ceil()).clamp(1, 9999);
          if (_activeWorkspaceTab == 2 && _totalRecords > 0) {
            _metrics['total_templates'] = _totalRecords;
          }
          if (_activeWorkspaceTab == 4) {
            _metrics['my_acknowledgements'] = _totalRecords;
          }
          _isLoadingTable = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load records';
          _isLoadingTable = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingTable = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _searchQuery = query.trim();
        _currentPage = 1;
      });
      _fetchTableData();
    });
  }

  Future<void> _switchWorkspaceTab(int tabIndex) async {
    setState(() {
      _activeWorkspaceTab = tabIndex;
      _currentPage = 1;
      _searchController.clear();
      _searchQuery = '';
      _selectedCategoryFilter = 'All Categories';
      _selectedTypeFilter = 'All Types';
    });

    if (tabIndex == 2) {
      final types = await HRLookupHelper.instance.getLookupLabels('HR_TEMPLATE_TYPE');
      if (mounted && _activeWorkspaceTab == 2) {
        setState(() {
          _documentTypeFilterOptions = ['All Types', ...types];
        });
      }
    } else {
      final types = await HRLookupHelper.instance.getLookupLabels('HR_DOCUMENT_TYPE');
      if (mounted && _activeWorkspaceTab != 2) {
        setState(() {
          _documentTypeFilterOptions = ['All Types', ...types];
        });
      }
    }

    _fetchTableData();
  }

  void _openPolicyDrawer(String policyId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Policy Drawer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          child: PolicyDetailDrawer(
            policyId: policyId,
            onPolicyUpdated: () {
              _fetchTableData();
              _fetchMetrics();
            },
          ),
        ),
      ),
    );
  }

  void _openDocumentDrawer(String docId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Document Drawer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          child: DocumentDetailDrawer(
            documentId: docId,
            onDocumentUpdated: () {
              _fetchTableData();
              _fetchMetrics();
            },
          ),
        ),
      ),
    );
  }

  void _openTemplateDrawer(Map<String, dynamic> template) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Template Drawer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          child: TemplateDetailDrawer(
            templateId: template['id']?.toString() ?? '',
            initialData: template,
            onTemplateUpdated: () {
              _fetchTableData();
              _fetchMetrics();
            },
          ),
        ),
      ),
    );
  }

  void _openTemplateEditor(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (_) => TemplateEditorDialog(
        initialTemplate: template,
        initialTemplateId: template['id']?.toString(),
        onTemplatesChanged: () {
          _fetchTableData();
          _fetchMetrics();
        },
      ),
    );
  }

  String _getCurrentEntityType() {
    if (_activeWorkspaceTab == 0) return 'policy';
    if (_activeWorkspaceTab == 2) return 'template';
    if (_activeWorkspaceTab == 4) return 'acknowledgement';
    return 'document';
  }

  String _getItemTitle(dynamic item) {
    final isTemplate = _activeWorkspaceTab == 2 || item.containsKey('template_code') || item.containsKey('template_name');
    final isAck = _activeWorkspaceTab == 4 || item.containsKey('user_id');
    return (isTemplate
            ? (item['template_name'] ?? item['title'] ?? 'Template')
            : isAck
                ? (item['policy_title'] ?? item['title'] ?? 'Policy Sign-off')
                : (item['title'] ?? item['document_name'] ?? item['policy_title'] ?? 'Document'))
        .toString();
  }

  String _getItemType(dynamic item) {
    final isPolicy = _activeWorkspaceTab == 0 || item.containsKey('policy_code');
    final isTemplate = _activeWorkspaceTab == 2 || item.containsKey('template_code') || item.containsKey('template_name');
    final isAck = _activeWorkspaceTab == 4 || item.containsKey('user_id');
    return (isTemplate
            ? (item['template_type'] ?? 'Template')
            : isAck
                ? 'Sign-off'
                : (item['document_type'] ?? (isPolicy ? 'Policy' : 'Document')))
        .toString();
  }

  String _getItemVersion(dynamic item) {
    final isTemplate = _activeWorkspaceTab == 2 || item.containsKey('template_code') || item.containsKey('template_name');
    return (isTemplate
            ? (item['template_code'] ?? 'TMPL')
            : (item['current_version'] ?? item['version_number'] ?? 'v1.0'))
        .toString();
  }

  DateTime _getItemDate(dynamic item) {
    final isAck = _activeWorkspaceTab == 4 || item.containsKey('user_id');
    final raw = isAck
        ? (item['acknowledged_at'] ?? item['deadline'] ?? item['created_at'])
        : (item['updated_at'] ?? item['created_at']);
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _getItemStatusOrSize(dynamic item) {
    final isPolicy = _activeWorkspaceTab == 0 || item.containsKey('policy_code');
    final isTemplate = _activeWorkspaceTab == 2 || item.containsKey('template_code') || item.containsKey('template_name');
    final isAck = _activeWorkspaceTab == 4 || item.containsKey('user_id');
    if (isTemplate) {
      return (item['is_active'] != false) ? 'ACTIVE' : 'INACTIVE';
    } else if (isPolicy) {
      return (item['status'] ?? 'ACTIVE').toString();
    } else if (isAck) {
      return (item['status'] ?? 'PENDING').toString();
    } else {
      final rawBytes = item['file_size_bytes'] ?? item['file_size'] ?? item['size_bytes'] ?? item['size'];
      return _formatBytes(rawBytes);
    }
  }

  void _sortGrid(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortItemsList(_items, columnIndex, ascending);
    });
  }

  void _sortItemsList(List<dynamic> list, int columnIndex, bool ascending) {
    list.sort((a, b) {
      int result = 0;
      switch (columnIndex) {
        case 1: // Document / Policy Name
          final nameA = _getItemTitle(a).toLowerCase();
          final nameB = _getItemTitle(b).toLowerCase();
          result = nameA.compareTo(nameB);
          break;
        case 2: // Category
          final catA = (a['category_name'] ?? 'General').toString().toLowerCase();
          final catB = (b['category_name'] ?? 'General').toString().toLowerCase();
          result = catA.compareTo(catB);
          break;
        case 3: // Type
          final typeA = _getItemType(a).toLowerCase();
          final typeB = _getItemType(b).toLowerCase();
          result = typeA.compareTo(typeB);
          break;
        case 4: // Version
          final verA = _getItemVersion(a).toLowerCase();
          final verB = _getItemVersion(b).toLowerCase();
          result = verA.compareTo(verB);
          break;
        case 5: // Last Updated
          final dateA = _getItemDate(a);
          final dateB = _getItemDate(b);
          result = dateA.compareTo(dateB);
          break;
        case 6: // Size / Status
          final isPolicyA = _activeWorkspaceTab == 0 || a.containsKey('policy_code');
          final isPolicyB = _activeWorkspaceTab == 0 || b.containsKey('policy_code');
          final isTplA = _activeWorkspaceTab == 2 || a.containsKey('template_code');
          final isAckA = _activeWorkspaceTab == 4 || a.containsKey('user_id');
          if (!isPolicyA && !isPolicyB && !isTplA && !isAckA) {
            final bytesA = int.tryParse((a['file_size_bytes'] ?? a['file_size'] ?? 0).toString()) ?? 0;
            final bytesB = int.tryParse((b['file_size_bytes'] ?? b['file_size'] ?? 0).toString()) ?? 0;
            result = bytesA.compareTo(bytesB);
          } else {
            final statA = _getItemStatusOrSize(a).toLowerCase();
            final statB = _getItemStatusOrSize(b).toLowerCase();
            result = statA.compareTo(statB);
          }
          break;
        default:
          result = 0;
      }
      return ascending ? result : -result;
    });
  }

  Future<void> _executeBulkAction(String action) async {
    if (_selectedItemIds.isEmpty) return;

    if (action == 'download') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Packaging ${_selectedItemIds.length} item(s) into ZIP archive...'),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      try {
        final bytes = await _api.postBytes('/hr/bulk/download', {
          'action': 'download',
          'entity_type': _getCurrentEntityType(),
          'ids': _selectedItemIds.toList(),
        });

        if (bytes.isNotEmpty) {
          final zipName = 'hr_documents_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.zip';
          downloadBytes(bytes, zipName, mimeType: 'application/zip');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully downloaded ${_selectedItemIds.length} item(s) as $zipName'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } else {
          throw Exception('Server returned empty file archive.');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download archive: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    if (action == 'change_category') {
      if (_categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No categories available to assign.'), backgroundColor: Colors.amber),
        );
        return;
      }
      Map<String, dynamic> selectedCategory = _categories.first;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            title: const Text('Move to Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select destination category for ${_selectedItemIds.length} selected item(s):',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: AppSearchableDropdown<Map<String, dynamic>>.fromMenuItems(
                      value: selectedCategory,
                      isExpanded: true,
                      items: _categories.map((c) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: c,
                          child: Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() => selectedCategory = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apply Category', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;

      try {
        final res = await _api.post('/hr/bulk', {
          'action': 'change_category',
          'entity_type': _getCurrentEntityType(),
          'ids': _selectedItemIds.toList(),
          'category_id': selectedCategory['id'],
          'category_name': selectedCategory['name'],
        });

        if (res['success'] == true) {
          _selectedItemIds.clear();
          _fetchTableData();
          _fetchMetrics();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully moved ${res['affected_count']} item(s) to "${selectedCategory['name']}"'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update category: $e'), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    final isDelete = action == 'delete';
    final actionTitle = isDelete ? 'Delete Selected Items' : 'Archive Selected Items';
    final actionPrompt = isDelete
        ? 'Are you sure you want to permanently delete ${_selectedItemIds.length} selected item(s)? This action cannot be undone.'
        : 'Are you sure you want to archive ${_selectedItemIds.length} selected item(s)? Archived items can be restored at any time.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(actionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(actionPrompt, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDelete ? const Color(0xFFEF4444) : Colors.amber.shade800,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isDelete ? 'Delete' : 'Archive', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/hr/bulk', {
        'action': action,
        'entity_type': _getCurrentEntityType(),
        'ids': _selectedItemIds.toList(),
      });

      if (res['success'] == true) {
        _selectedItemIds.clear();
        _fetchTableData();
        _fetchMetrics();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully ${action}d ${res['affected_count']} item(s)'),
              backgroundColor: isDelete ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk action failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4F46E5);
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF4F46E5);
    }
  }


  String _formatBytes(dynamic bytes) {
    if (bytes == null) return '0 B';
    final int b = int.tryParse(bytes.toString()) ?? 0;
    if (b <= 0) return '0 B';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _getFileTypeBadge(String? fileName, String? docType) {
    final name = (fileName ?? docType ?? '').toLowerCase();
    Color badgeColor = const Color(0xFF4F46E5);
    String label = 'DOC';

    if (name.endsWith('.pdf') || name.contains('pdf')) {
      badgeColor = const Color(0xFFEF4444);
      label = 'PDF';
    } else if (name.endsWith('.docx') || name.endsWith('.doc') || name.contains('doc')) {
      badgeColor = const Color(0xFF0284C7);
      label = 'DOCX';
    } else if (name.endsWith('.xlsx') || name.endsWith('.xls') || name.contains('xls')) {
      badgeColor = const Color(0xFF10B981);
      label = 'XLSX';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Unified HR Management Header (Active Tab: Policies)
          HRManagementHeader(
            activeTab: HRTab.policies,
            title: 'Policies & Documents',
            subtitle: 'Manage all institutional policies, guidelines and important documents in one secure workspace.',
            icon: Icons.folder_shared_rounded,
            onRefresh: () {
              _fetchTableData();
              _fetchMetrics();
            },
            isRefreshing: _isLoadingMetrics || _isLoadingTable,
            actions: [
              OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ManageCategoriesDialog(
                      onCategoriesChanged: () {
                        _fetchCategories();
                        _fetchMetrics();
                      },
                    ),
                  );
                },
                icon: Icon(Icons.grid_view_rounded, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                label: Text(
                  'Manage Categories',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => UploadDocumentDialog(
                      onDocumentUploaded: () {
                        _fetchTableData();
                        _fetchMetrics();
                      },
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Upload Document',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              PopupMenuButton<String>(
                icon: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                onSelected: (val) {
                  if (val == 'create_policy') {
                    showDialog(
                      context: context,
                      builder: (_) => CreatePolicyDialog(
                        onPolicyCreated: () {
                          _fetchTableData();
                          _fetchMetrics();
                        },
                      ),
                    );
                  } else if (val == 'request_signoff') {
                    showDialog(
                      context: context,
                      builder: (_) => RequestAcknowledgementDialog(
                        onRequested: () {
                          _fetchTableData();
                          _fetchMetrics();
                        },
                      ),
                    );
                  } else if (val == 'templates') {
                    showDialog(
                      context: context,
                      builder: (_) => TemplateEditorDialog(
                        onTemplatesChanged: _fetchTableData,
                      ),
                    );
                  } else if (val == 'reports') {
                    showDialog(
                      context: context,
                      builder: (_) => const ReportsDialog(),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'create_policy',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF4F46E5)),
                        SizedBox(width: 10),
                        Text('Create Policy'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'request_signoff',
                    child: Row(
                      children: [
                        Icon(Icons.how_to_reg_outlined, size: 18, color: Color(0xFF0284C7)),
                        SizedBox(width: 10),
                        Text('Request Sign-off'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'templates',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 18, color: Color(0xFF10B981)),
                        SizedBox(width: 10),
                        Text('Letter Templates'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reports',
                    child: Row(
                      children: [
                        Icon(Icons.analytics_outlined, size: 18, color: Color(0xFFF59E0B)),
                        SizedBox(width: 10),
                        Text('Compliance Reports'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 3. Scrollable Dashboard & Workspace Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Section (4 Cards matching Screenshot + Compliance Pills)
                  _buildKpiSection(isDark),
                  const SizedBox(height: 24),

                  // Full-Width Workspace Navigation Tabs
                  _buildWorkspaceTabs(isDark),
                  const SizedBox(height: 16),

                  // Full-Width Document Library Data Table
                  _buildDocumentLibraryTable(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildKpiSection(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double cardWidth;
        if (width >= 1100) {
          cardWidth = (width - (16 * 3)) / 4;
        } else if (width >= 580) {
          cardWidth = (width - 16) / 2;
        } else {
          cardWidth = width;
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Card 1: Total Policies
            _buildKpiCard(
              title: 'Total Policies',
              value: '${_metrics['total_policies'] ?? 0}',
              trend: _metrics['policies_trend']?.toString() ?? '0% vs last month',
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF4F46E5),
              width: cardWidth,
              isDark: isDark,
              onTap: () => _switchWorkspaceTab(0),
            ),
            // Card 2: Total Documents
            _buildKpiCard(
              title: 'Total Documents',
              value: '${_metrics['total_documents'] ?? 0}',
              trend: _metrics['documents_trend']?.toString() ?? '0% vs last month',
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF0284C7),
              width: cardWidth,
              isDark: isDark,
              onTap: () => _switchWorkspaceTab(1),
            ),
            // Card 3: Categories
            _buildKpiCard(
              title: 'Categories',
              value: '${_metrics['total_categories'] ?? 0}',
              trend: _metrics['categories_trend']?.toString() ?? '0% vs last month',
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF10B981),
              width: cardWidth,
              isDark: isDark,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ManageCategoriesDialog(onCategoriesChanged: _fetchCategories),
                );
              },
            ),
            // Card 4: Recently Updated
            _buildKpiCard(
              title: 'Recently Updated',
              value: '${_metrics['recently_updated'] ?? 0}',
              trend: _metrics['recently_trend']?.toString() ?? '0% vs last month',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFFF59E0B),
              width: cardWidth,
              isDark: isDark,
              onTap: () {
                setState(() => _sortBy = 'latest');
                _fetchTableData();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color iconColor,
    required double width,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoadingMetrics ? '...' : value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 11,
                        color: trend.startsWith('↑') ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildWorkspaceTabs(bool isDark) {
    final tabIcons = [
      Icons.shield_outlined,
      Icons.folder_shared_outlined,
      Icons.description_outlined,
      Icons.schedule_outlined,
      Icons.verified_user_outlined,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_workspaceTabs.length, (idx) {
            final isSelected = _activeWorkspaceTab == idx;
            final tabIcon = idx < tabIcons.length ? tabIcons[idx] : Icons.folder_outlined;

            dynamic badgeVal;
            if (idx == 0) {
              badgeVal = _metrics['total_policies'];
            } else if (idx == 1) {
              badgeVal = _metrics['total_documents'];
            } else if (idx == 2) {
              badgeVal = _metrics['total_templates'];
            } else if (idx == 3) {
              badgeVal = _metrics['expiring_soon'];
            } else if (idx == 4) {
              badgeVal = _metrics['my_acknowledgements'] ?? _metrics['pending_signoffs'];
            }

            final badgeStr = badgeVal != null && badgeVal.toString() != '0' ? badgeVal.toString() : null;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => _switchWorkspaceTab(idx),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tabIcon,
                        size: 15,
                        color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _workspaceTabs[idx],
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (badgeStr != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeStr,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
    double? width,
  }) {
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<T>.fromMenuItems(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatusOrSizeBadge(String text, bool isDark, {bool isAck = false}) {
    final upper = text.toUpperCase().trim();

    if (upper.endsWith('MB') || upper.endsWith('KB') || upper.endsWith(' B') || upper.endsWith('BYTES')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attachment_rounded, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Color bg;
    Color fg;
    Color border;
    IconData icon;

    if (upper == 'ACKNOWLEDGED' || upper == 'ACTIVE' || upper == 'APPROVED' || upper == 'PUBLISHED') {
      fg = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      bg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF10B981).withValues(alpha: 0.3);
      icon = Icons.check_circle_rounded;
    } else if (upper == 'PENDING' || upper.contains('SOON')) {
      fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      bg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFFF59E0B).withValues(alpha: 0.3);
      icon = Icons.schedule_rounded;
    } else if (upper == 'UNDER REVIEW' || upper == 'UNDER_REVIEW' || upper == 'SUBMITTED') {
      fg = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
      bg = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF6366F1).withValues(alpha: 0.3);
      icon = Icons.rate_review_rounded;
    } else if (upper == 'DRAFT') {
      fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      bg = const Color(0xFF64748B).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF64748B).withValues(alpha: 0.3);
      icon = Icons.edit_note_rounded;
    } else {
      fg = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      bg = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFFEF4444).withValues(alpha: 0.3);
      icon = Icons.cancel_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    final upper = type.toUpperCase().trim();
    Color fg;
    Color bg;
    Color border;
    IconData icon;

    if (upper.contains('POLICY')) {
      fg = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
      bg = const Color(0xFF6366F1).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF6366F1).withValues(alpha: 0.25);
      icon = Icons.shield_outlined;
    } else if (upper.contains('SIGN-OFF') || upper.contains('SIGNOFF') || upper.contains('ACK')) {
      fg = isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
      bg = const Color(0xFF14B8A6).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF14B8A6).withValues(alpha: 0.25);
      icon = Icons.verified_user_outlined;
    } else if (upper.contains('TEMPLATE')) {
      fg = isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED);
      bg = const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF8B5CF6).withValues(alpha: 0.25);
      icon = Icons.description_outlined;
    } else {
      fg = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      bg = const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.18 : 0.1);
      border = const Color(0xFF0EA5E9).withValues(alpha: 0.25);
      icon = Icons.article_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String category, bool isDark) {
    Color catColor = const Color(0xFF4F46E5);
    for (final c in _categories) {
      if ((c['name'] as String?)?.toLowerCase() == category.toLowerCase()) {
        if (c['color_code'] != null) {
          catColor = _parseColor(c['color_code'] as String);
        }
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: catColor.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: catColor.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: catColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: catColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentLibraryTable(bool isDark) {
    final hasActiveFilter = _searchQuery.isNotEmpty ||
        _selectedCategoryFilter != 'All Categories' ||
        _selectedTypeFilter != 'All Types' ||
        _sortBy != 'latest';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Section Header with count badge
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isCompact = headerConstraints.maxWidth < 420;
              final titleWrap = Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Document Library',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (_totalRecords > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_totalRecords records',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                ],
              );

              final resetButton = hasActiveFilter
                  ? TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _selectedCategoryFilter = 'All Categories';
                          _selectedTypeFilter = 'All Types';
                          _sortBy = 'latest';
                          _currentPage = 1;
                        });
                        _fetchTableData();
                      },
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
                      label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : const SizedBox.shrink();

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWrap,
                    if (hasActiveFilter) ...[
                      const SizedBox(height: 6),
                      resetButton,
                    ],
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleWrap,
                  if (hasActiveFilter) resetButton,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Filter & Search Controls Bar
          LayoutBuilder(
            builder: (context, filterConstraints) {
              final isNarrow = filterConstraints.maxWidth < 920;

              final searchWidget = TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search documents by name, category, or keywords...',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                  ),
                ),
              );

              final catDropdown = _buildDropdownFilter<String>(
                value: _selectedCategoryFilter,
                width: isNarrow ? null : 160,
                isDark: isDark,
                items: [
                  'All Categories',
                  ..._categories.map<String>((c) => c['name'] as String),
                ].map((c) => DropdownMenuItem(value: c, child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategoryFilter = val;
                      _currentPage = 1;
                    });
                    _fetchTableData();
                  }
                },
              );

              final typeDropdown = _buildDropdownFilter<String>(
                value: _documentTypeFilterOptions.contains(_selectedTypeFilter) ? _selectedTypeFilter : 'All Types',
                width: isNarrow ? null : 135,
                isDark: isDark,
                items: _documentTypeFilterOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTypeFilter = val;
                      _currentPage = 1;
                    });
                    _fetchTableData();
                  }
                },
              );

              final sortDropdown = _buildDropdownFilter<String>(
                value: _sortBy,
                width: isNarrow ? null : 155,
                isDark: isDark,
                items: const [
                  DropdownMenuItem(value: 'latest', child: Text('Sort by: Latest', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'name_asc', child: Text('Sort: Name A-Z', maxLines: 1, overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'expiry_soon', child: Text('Sort: Expiry Soonest', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                    _fetchTableData();
                  }
                },
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchWidget,
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: filterConstraints.maxWidth < 450 ? filterConstraints.maxWidth : (filterConstraints.maxWidth - 20) / 2 > 150 ? (filterConstraints.maxWidth - 20) / 2 : 150,
                          child: catDropdown,
                        ),
                        SizedBox(
                          width: filterConstraints.maxWidth < 450 ? filterConstraints.maxWidth : (filterConstraints.maxWidth - 20) / 2 > 130 ? (filterConstraints.maxWidth - 20) / 2 : 130,
                          child: typeDropdown,
                        ),
                        SizedBox(
                          width: filterConstraints.maxWidth < 450 ? filterConstraints.maxWidth : 160,
                          child: sortDropdown,
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchWidget),
                  const SizedBox(width: 12),
                  catDropdown,
                  const SizedBox(width: 10),
                  typeDropdown,
                  const SizedBox(width: 10),
                  sortDropdown,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Bulk Actions Bar (Responsive banner)
          _buildBulkActionBar(isDark),

          // Data Table
          _isLoadingTable
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 36, color: Colors.red),
                            const SizedBox(height: 8),
                            Text('Error: $_errorMessage'),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchTableData, child: const Text('Retry')),
                          ],
                        ),
                      ),
                    )
                  : _items.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildDataTable(isDark),

          const SizedBox(height: 16),
          // Pagination Controls
          _buildPaginationFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded, size: 40, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 16),
            Text(
              _activeWorkspaceTab == 0
                  ? 'No Policies Found'
                  : _activeWorkspaceTab == 4
                      ? 'No Pending Acknowledgements'
                      : 'No Documents Found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _activeWorkspaceTab == 0
                  ? 'Author your first institutional policy to set governance and compliance rules.'
                  : _activeWorkspaceTab == 4
                      ? 'You are fully compliant! All required policies have been acknowledged.'
                      : 'Upload HR documents to keep important institutional records organized.',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            if (_activeWorkspaceTab == 0)
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => CreatePolicyDialog(onPolicyCreated: _fetchTableData),
                  );
                },
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Create Policy', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              )
            else if (_activeWorkspaceTab != 4)
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => UploadDocumentDialog(onDocumentUploaded: _fetchTableData),
                  );
                },
                icon: const Icon(Icons.upload, size: 16, color: Colors.white),
                label: const Text('Upload Document', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionBar(bool isDark) {
    if (_selectedItemIds.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text(
                '${_selectedItemIds.length} items selected',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5), fontSize: 12.5),
              ),
            ],
          ),
        );

        final actionButtons = Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Archive Selected
            OutlinedButton.icon(
              onPressed: () => _executeBulkAction('archive'),
              icon: const Icon(Icons.archive_outlined, size: 15, color: Colors.amber),
              label: const Text('Archive Selected', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            // Download All (ZIP)
            ElevatedButton.icon(
              onPressed: () => _executeBulkAction('download'),
              icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
              label: const Text('Download All', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            // Change Category
            OutlinedButton.icon(
              onPressed: () => _executeBulkAction('change_category'),
              icon: Icon(Icons.folder_open_rounded, size: 15, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              label: Text('Change Category', style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            // Delete Selected
            OutlinedButton.icon(
              onPressed: () => _executeBulkAction('delete'),
              icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
              label: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            // Clear selection
            IconButton(
              onPressed: () => setState(() => _selectedItemIds.clear()),
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Deselect all',
              visualDensity: VisualDensity.compact,
            ),
          ],
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.35) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        badge,
                        IconButton(
                          onPressed: () => setState(() => _selectedItemIds.clear()),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Deselect all',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    actionButtons,
                  ],
                )
              : Row(
                  children: [
                    badge,
                    const Spacer(),
                    actionButtons,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDataTable(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Proportional column dimensions
        const double colCheckbox = 44.0;
        const double colCategory = 140.0;
        const double colType = 95.0;
        const double colVersion = 85.0;
        const double colLastUpdated = 120.0;
        const double colStatus = 145.0;
        const double colActions = 100.0;
        const double horizontalMargin = 16.0;
        const double columnSpacing = 16.0;

        // 8 columns have 7 column spacings, plus 2 horizontal margins:
        const double totalFixedAndGaps = colCheckbox +
            colCategory +
            colType +
            colVersion +
            colLastUpdated +
            colStatus +
            colActions +
            (horizontalMargin * 2) +
            (columnSpacing * 7); // = 729 + 32 + 112 = 873.0

        // Document name column dynamically expands to fill all remaining width!
        final double colName = math.max(280.0, availableWidth - totalFixedAndGaps);
        final double totalTableWidth = math.max(availableWidth, totalFixedAndGaps + colName);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalTableWidth,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 44,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 64,
              horizontalMargin: horizontalMargin,
              columnSpacing: columnSpacing,
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
              dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9).withValues(alpha: 0.8);
                }
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF4F46E5).withValues(alpha: 0.08);
                }
                return null;
              }),
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: colCheckbox,
                    child: Checkbox(
                      tristate: true,
                      value: _items.isEmpty
                          ? false
                          : (_selectedItemIds.length == _items.length
                              ? true
                              : (_selectedItemIds.isNotEmpty ? null : false)),
                      onChanged: (val) {
                        setState(() {
                          if (val == true || (_selectedItemIds.isNotEmpty && _selectedItemIds.length < _items.length)) {
                            _selectedItemIds = _items.map<String>((i) => i['id'] as String).toSet();
                          } else {
                            _selectedItemIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: colName - 22,
                    child: const Text('Document / Policy Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: 'Sort by Document / Policy Name',
                  onSort: (colIdx, asc) => _sortGrid(colIdx, asc),
                ),
                DataColumn(
                  label: const SizedBox(
                    width: colCategory - 20,
                    child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: 'Sort by Category',
                  onSort: (colIdx, asc) => _sortGrid(colIdx, asc),
                ),
                DataColumn(
                  label: const SizedBox(
                    width: colType - 20,
                    child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: 'Sort by Type',
                  onSort: (colIdx, asc) => _sortGrid(colIdx, asc),
                ),
                DataColumn(
                  label: const SizedBox(
                    width: colVersion - 20,
                    child: Text('Version', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: 'Sort by Version',
                  onSort: (colIdx, asc) => _sortGrid(colIdx, asc),
                ),
                DataColumn(
                  label: const SizedBox(
                    width: colLastUpdated - 20,
                    child: Text('Last Updated', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: 'Sort by Last Updated',
                  onSort: (colIdx, asc) => _sortGrid(colIdx, asc),
                ),
                DataColumn(
                  label: const SizedBox(
                    width: colStatus - 20,
                    child: Text('Size / Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                  tooltip: 'Sort by Size / Status',
                  onSort: (colIdx, asc) => _sortGrid(colIdx, asc),
                ),
                const DataColumn(
                  label: SizedBox(
                    width: colActions,
                    child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              rows: _items.map((item) {
                final id = item['id'] as String;
                final isSelected = _selectedItemIds.contains(id);
                final isPolicy = _activeWorkspaceTab == 0 || item.containsKey('policy_code');
                final isTemplate = _activeWorkspaceTab == 2 || item.containsKey('template_code') || item.containsKey('template_name');
                final isAck = _activeWorkspaceTab == 4 || item.containsKey('user_id');

                final title = _getItemTitle(item);
                final desc = isTemplate
                    ? (item['description'] ?? 'Reusable letter/document template')
                    : isAck
                        ? (item['policy_description'] ?? item['description'] ?? '')
                        : (item['description'] ?? item['policy_description'] ?? '');

                final category = item['category_name'] ?? 'General';
                final type = _getItemType(item);
                final version = _getItemVersion(item);

                final updated = isAck
                    ? (item['acknowledged_at'] ?? item['deadline'] ?? item['created_at'])
                    : (item['updated_at'] ?? item['created_at']);

                final statusOrSize = _getItemStatusOrSize(item);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedItemIds.add(id);
                      } else {
                        _selectedItemIds.remove(id);
                      }
                    });
                  },
                  cells: [
                    DataCell(
                      SizedBox(
                        width: colCheckbox,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedItemIds.add(id);
                              } else {
                                _selectedItemIds.remove(id);
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colName,
                        child: InkWell(
                          onTap: () {
                            if (isAck) {
                              showDialog(
                                context: context,
                                builder: (_) => PolicyAcknowledgementDialog(
                                  acknowledgement: item,
                                  onAcknowledged: _fetchTableData,
                                  onOpenPolicyDrawer: (polId) => _openPolicyDrawer(polId),
                                ),
                              );
                            } else if (isTemplate) {
                              _openTemplateDrawer(item);
                            } else if (isPolicy) {
                              _openPolicyDrawer(id);
                            } else {
                              _openDocumentDrawer(id);
                            }
                          },
                          child: Row(
                            children: [
                              isTemplate
                                  ? Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.description_outlined, size: 18, color: Color(0xFF4F46E5)),
                                    )
                                  : isAck
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF10B981)),
                                        )
                                      : _getFileTypeBadge(item['file_name'], item['document_type']),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (desc.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        desc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colCategory,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildCategoryBadge(category, isDark),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colType,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildTypeBadge(type, isDark),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colVersion,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              version.toString().startsWith('v') || isTemplate ? version.toString() : 'v$version',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colLastUpdated,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                updated != null ? _dateFormat.format(DateTime.parse(updated.toString())) : '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colStatus,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildStatusOrSizeBadge(statusOrSize, isDark, isAck: isAck),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: colActions,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.visibility_outlined),
                                tooltip: isTemplate ? 'View & Preview Template' : (isAck ? 'View Acknowledgement' : 'View Details'),
                                onPressed: () {
                                  if (isAck) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => PolicyAcknowledgementDialog(
                                        acknowledgement: item,
                                        onAcknowledged: _fetchTableData,
                                        onOpenPolicyDrawer: (polId) => _openPolicyDrawer(polId),
                                      ),
                                    );
                                  } else if (isTemplate) {
                                    _openTemplateDrawer(item);
                                  } else if (isPolicy) {
                                    _openPolicyDrawer(id);
                                  } else {
                                    _openDocumentDrawer(id);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                tooltip: 'More actions',
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (action) async {
                                  if (action == 'view_template' || (action == 'view' && isTemplate)) {
                                    _openTemplateDrawer(item);
                                  } else if (action == 'edit_template') {
                                    _openTemplateEditor(item);
                                  } else if (action == 'copy_template') {
                                    final content = item['content_html'] ?? item['template_name'] ?? '';
                                    Clipboard.setData(ClipboardData(text: content));
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Template markup copied to clipboard!'), backgroundColor: Color(0xFF10B981)),
                                      );
                                    }
                                  } else if (action == 'delete_template') {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Deactivate Template'),
                                      content: Text('Are you sure you want to deactivate "${item['template_name'] ?? 'this template'}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    try {
                                      await _api.delete('/hr/templates/$id');
                                      _fetchTableData();
                                      _fetchMetrics();
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Template deactivated.'), backgroundColor: Color(0xFF10B981)),
                                      );
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                } else if (action == 'view_ack') {
                                  showDialog(
                                    context: context,
                                    builder: (_) => PolicyAcknowledgementDialog(
                                      acknowledgement: item,
                                      onAcknowledged: _fetchTableData,
                                      onOpenPolicyDrawer: (polId) => _openPolicyDrawer(polId),
                                    ),
                                  );
                                } else if (action == 'view_policy_ack') {
                                  final policyId = item['policy_id']?.toString();
                                  if (policyId != null && policyId.isNotEmpty) {
                                    _openPolicyDrawer(policyId);
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (_) => PolicyAcknowledgementDialog(
                                        acknowledgement: item,
                                        onAcknowledged: _fetchTableData,
                                        onOpenPolicyDrawer: (polId) => _openPolicyDrawer(polId),
                                      ),
                                    );
                                  }
                                } else if (action == 'view') {
                                  if (isAck) {
                                    final policyId = item['policy_id']?.toString();
                                    if (policyId != null && policyId.isNotEmpty) {
                                      _openPolicyDrawer(policyId);
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (_) => PolicyAcknowledgementDialog(
                                          acknowledgement: item,
                                          onAcknowledged: _fetchTableData,
                                          onOpenPolicyDrawer: (polId) => _openPolicyDrawer(polId),
                                        ),
                                      );
                                    }
                                  } else if (isTemplate) {
                                    _openTemplateDrawer(item);
                                  } else if (isPolicy) {
                                    _openPolicyDrawer(id);
                                  } else {
                                    _openDocumentDrawer(id);
                                  }
                                } else if (action == 'archive') {
                                  _selectedItemIds = {id};
                                  _executeBulkAction('archive');
                                }
                              },
                              itemBuilder: (ctx) {
                                if (isTemplate) {
                                  return [
                                    const PopupMenuItem(
                                      value: 'view_template',
                                      child: Row(
                                        children: [
                                          Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF4F46E5)),
                                          SizedBox(width: 8),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit_template',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0284C7)),
                                          SizedBox(width: 8),
                                          Text('Edit Template'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'copy_template',
                                      child: Row(
                                        children: [
                                          Icon(Icons.copy_rounded, size: 16),
                                          SizedBox(width: 8),
                                          Text('Copy Markup'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete_template',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Deactivate Template', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ];
                                } else if (isAck) {
                                  final isAcknowledged = (item['status'] ?? '').toString().toUpperCase() == 'ACKNOWLEDGED';
                                  return [
                                    PopupMenuItem(
                                      value: 'view_ack',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isAcknowledged ? Icons.verified_rounded : Icons.edit_document,
                                            size: 16,
                                            color: isAcknowledged ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(isAcknowledged ? 'View Signed Details' : 'Sign & Acknowledge'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'view_policy_ack',
                                      child: Row(
                                        children: [
                                          Icon(Icons.policy_outlined, size: 16, color: Color(0xFF0284C7)),
                                          SizedBox(width: 8),
                                          Text('View Policy 360 Details'),
                                        ],
                                      ),
                                    ),
                                  ];
                                } else if (isPolicy) {
                                  return [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF4F46E5)),
                                          SizedBox(width: 8),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'archive',
                                      child: Row(
                                        children: [
                                          Icon(Icons.archive_outlined, size: 16),
                                          SizedBox(width: 8),
                                          Text('Archive'),
                                        ],
                                      ),
                                    ),
                                  ];
                                } else {
                                  return [
                                    const PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(Icons.remove_red_eye_outlined, size: 16, color: Color(0xFF4F46E5)),
                                          SizedBox(width: 8),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'archive',
                                      child: Row(
                                        children: [
                                          Icon(Icons.archive_outlined, size: 16),
                                          SizedBox(width: 8),
                                          Text('Archive'),
                                        ],
                                      ),
                                    ),
                                  ];
                                }
                              },
                            ),
                          ),
                        ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationFooter(bool isDark) {
    if (_totalRecords == 0) {
      return Text(
        'Showing 0 records',
        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      );
    }
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = (_currentPage * _pageSize).clamp(1, _totalRecords);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        final infoWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Showing $start to $end of $_totalRecords documents',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 14),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: AppSearchableDropdown<int>.fromMenuItems(
                  value: _pageSize,
                  isDense: true,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 / page')),
                    DropdownMenuItem(value: 10, child: Text('10 / page')),
                    DropdownMenuItem(value: 20, child: Text('20 / page')),
                    DropdownMenuItem(value: 50, child: Text('50 / page')),
                    DropdownMenuItem(value: 100, child: Text('100 / page')),
                  ],
                  onChanged: (newSize) {
                    if (newSize != null && newSize != _pageSize) {
                      setState(() {
                        _pageSize = newSize;
                        _currentPage = 1;
                      });
                      _fetchTableData();
                    }
                  },
                ),
              ),
            ),
          ],
        );

        final navWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _fetchTableData();
                    }
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$_currentPage',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Text('of $_totalPages', style: const TextStyle(fontSize: 12)),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _currentPage < _totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _fetchTableData();
                    }
                  : null,
            ),
          ],
        );

        if (isCompact) {
          return Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              infoWidget,
              navWidget,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            infoWidget,
            navWidget,
          ],
        );
      },
    );
  }


}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class VaultSecretsScreen extends StatefulWidget {
  const VaultSecretsScreen({super.key});

  @override
  State<VaultSecretsScreen> createState() => _VaultSecretsScreenState();
}

class _VaultSecretsScreenState extends State<VaultSecretsScreen> {
  List<dynamic> _secrets = [];
  bool _isLoading = true;
  dynamic _selectedSecret;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _pathFilter = "All Paths";
  String _typeFilter = "All Types";
  String _statusFilter = "All Status";

  // Pagination state
  int _currentPage = 1;
  int _pageSize = 10;

  // Decryption & Loading cache
  final Map<String, String> _revealedSecrets = {};
  final Set<String> _loadingSecretIds = {};

  // Version History state
  List<dynamic> _secretVersions = [];
  bool _isLoadingVersions = false;

  @override
  void initState() {
    super.initState();
    _fetchSecrets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSecrets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await ApiService().get('/admin/vault/secrets', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _secrets = res['data'] as List<dynamic>? ?? [];
          _isLoading = false;
        });

        // Maintain selection or select first secret by default
        if (_secrets.isNotEmpty) {
          if (_selectedSecret != null) {
            final updatedSec = _secrets.firstWhere(
              (s) => s['id'] == _selectedSecret['id'],
              orElse: () => _secrets.first,
            );
            _selectSecret(updatedSec);
          } else {
            _selectSecret(_secrets.first);
          }
        } else {
          setState(() {
            _selectedSecret = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to load secrets: $e', Colors.red);
    }
  }

  void _selectSecret(dynamic secret) {
    setState(() {
      _selectedSecret = secret;
      _secretVersions = [];
    });
    _fetchSecretVersions(secret['id']);
  }

  Future<void> _fetchSecretVersions(String secretId) async {
    setState(() {
      _isLoadingVersions = true;
    });
    try {
      final res = await ApiService().get('/admin/vault/secrets/$secretId/versions', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _secretVersions = res['data'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {
      // Silently catch version loading errors
    } finally {
      setState(() {
        _isLoadingVersions = false;
      });
    }
  }

  Future<void> _revealSecret(String id) async {
    if (_revealedSecrets.containsKey(id)) {
      setState(() {
        _revealedSecrets.remove(id);
      });
      return;
    }

    setState(() {
      _loadingSecretIds.add(id);
    });

    try {
      final res = await ApiService().get('/admin/vault/secrets/$id/value', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _revealedSecrets[id] = res['value']?.toString() ?? '';
          _loadingSecretIds.remove(id);
        });
      }
    } catch (e) {
      setState(() {
        _loadingSecretIds.remove(id);
      });
      _showSnackBar('Failed to decrypt secret: $e', Colors.red);
    }
  }

  Future<void> _saveSecret({
    String? id,
    required String name,
    required String value,
    required String description,
    required String path,
    required String type,
    DateTime? nextRotation,
    String? status,
  }) async {
    try {
      final payload = {
        'name': name,
        'value': value,
        'description': description,
        'path': path,
        'secret_type': type,
        'next_rotation': nextRotation?.toIso8601String(),
        'status': status ?? 'Active',
      };

      if (id == null) {
        await ApiService().post('/admin/vault/secrets', payload);
        _showSnackBar('Secret created successfully!', Colors.green);
      } else {
        await ApiService().put('/admin/vault/secrets/$id', payload);
        _revealedSecrets.remove(id);
        _showSnackBar('Secret rotated/updated successfully!', Colors.green);
      }
      
      _fetchSecrets();
    } catch (e) {
      _showSnackBar('Failed to save secret: $e', Colors.red);
    }
  }

  Future<void> _deleteSecret(String id) async {
    try {
      await ApiService().delete('/admin/vault/secrets/$id');
      _revealedSecrets.remove(id);
      setState(() {
        _selectedSecret = null;
      });
      _fetchSecrets();
      _showSnackBar('Secret deleted successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to delete secret: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showCreateOrEditDialog([dynamic secret]) {
    final isEdit = secret != null;
    final nameController = TextEditingController(text: isEdit ? secret['name'] : '');
    final descController = TextEditingController(text: isEdit ? secret['description'] : '');
    final valController = TextEditingController();
    final pathController = TextEditingController(text: isEdit ? secret['path'] : 'secret/data/');
    
    String selectedType = isEdit ? secret['secret_type'] : 'API Key';
    DateTime? selectedNextRotation = isEdit && secret['next_rotation'] != null
        ? DateTime.parse(secret['next_rotation'])
        : DateTime.now().add(const Duration(days: 30));

    bool isDecryptingValue = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            // Pre-fill secret value if editing and not already fetched
            if (isEdit && valController.text.isEmpty && !isDecryptingValue) {
              setModalState(() {
                isDecryptingValue = true;
              });
              ApiService().get('/admin/vault/secrets/${secret['id']}/value', useCache: false).then((res) {
                if (res['success'] == true) {
                  setModalState(() {
                    valController.text = res['value']?.toString() ?? '';
                    isDecryptingValue = false;
                  });
                }
              }).catchError((_) {
                setModalState(() {
                  isDecryptingValue = false;
                });
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width > 560 ? 520 : MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEdit ? Icons.rotate_right_rounded : Icons.add_moderator_rounded,
                              color: const Color(0xFF4F46E5),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            isEdit ? 'Rotate / Update Secret' : 'Create Vault Secret',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Secret Name
                      Text('SECRET NAME', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), letterSpacing: 1.0)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        enabled: !isEdit,
                        style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'e.g. DB Connection String',
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Secret Path
                      Text('VAULT PATH', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), letterSpacing: 1.0)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: pathController,
                        style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'e.g. secret/data/database/prod',
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Type & Next Rotation Picker
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TYPE', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), letterSpacing: 1.0)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedType,
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF13182C) : Colors.white,
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedType = val!;
                                        });
                                      },
                                      items: ['Password', 'API Key', 'Key / Secret', 'Username / Pass', 'Token', 'Private Key', 'Connection String', 'URL'].map((t) {
                                        return DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))));
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('NEXT ROTATION', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), letterSpacing: 1.0)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedNextRotation ?? DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedNextRotation = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          selectedNextRotation != null
                                              ? DateFormat('yyyy-MM-dd').format(selectedNextRotation!)
                                              : 'Never',
                                          style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                        Icon(Icons.calendar_today, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Secret Value
                      Text('SECRET VALUE', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), letterSpacing: 1.0)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: valController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 13, fontFamily: 'monospace', color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: isDecryptingValue ? 'Decrypting value...' : 'Paste your secret keys or tokens here...',
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                          suffixIcon: isDecryptingValue ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text('DESCRIPTION', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : const Color(0xFF94A3B8), letterSpacing: 1.0)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descController,
                        maxLines: 2,
                        style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Add a brief note about this secret\'s usage...',
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text('Cancel', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : const Color(0xFF475569))),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (nameController.text.trim().isEmpty || valController.text.trim().isEmpty) {
                                _showSnackBar('Name and Value are required fields', Colors.red);
                                return;
                              }
                              Navigator.pop(context);
                              _saveSecret(
                                id: isEdit ? secret['id'] : null,
                                name: nameController.text.trim(),
                                value: valController.text.trim(),
                                description: descController.text.trim(),
                                path: pathController.text.trim(),
                                type: selectedType,
                                nextRotation: selectedNextRotation,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: Text(isEdit ? 'Rotate / Update' : 'Create Secret', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVersionsDialog(dynamic secret) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Version History',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isLoadingVersions
                        ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                        : _secretVersions.isEmpty
                            ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No version history found', style: GoogleFonts.dmSans(color: Colors.grey))))
                            : Expanded(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _secretVersions.length,
                                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                                  itemBuilder: (context, index) {
                                    final ver = _secretVersions[index];
                                    final dateStr = ver['created_at'] != null
                                        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(ver['created_at']).toLocal())
                                        : '';

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                        child: Text('v${ver['version']}', style: GoogleFonts.dmSans(color: const Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      title: Text('Version ${ver['version']}', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text('Rotated by ${ver['created_by']} on $dateStr', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey)),
                                      trailing: TextButton.icon(
                                        icon: const Icon(Icons.vpn_key_outlined, size: 14),
                                        label: const Text('Decrypt'),
                                        onPressed: () async {
                                          try {
                                            final res = await ApiService().get('/admin/vault/secrets/versions/${ver['id']}/value', useCache: false);
                                            if (res['success'] == true) {
                                              if (!context.mounted) return;
                                              showDialog(
                                                context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: Text('Decrypted Value (v${ver['version']})'),
                                                    content: SelectableText(res['value']?.toString() ?? '', style: const TextStyle(fontFamily: 'monospace')),
                                                  actions: [
                                                    TextButton(
                                                      child: const Text('Copy'),
                                                      onPressed: () {
                                                        Clipboard.setData(ClipboardData(text: res['value']?.toString() ?? ''));
                                                        _showSnackBar('Copied to clipboard', Colors.green);
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                    TextButton(child: const Text('Close'), onPressed: () => Navigator.pop(context)),
                                                  ],
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            _showSnackBar('Failed to decrypt version value: $e', Colors.red);
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg = isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF13182C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF64748B);
    final textMuted = isDark ? Colors.white30 : const Color(0xFF94A3B8);
    const accentColor = Color(0xFF4F46E5);

    // Apply client side filters
    final filteredSecrets = _secrets.where((s) {
      // 1. Search Query
      final name = (s['name'] ?? '').toString().toLowerCase();
      final desc = (s['description'] ?? '').toString().toLowerCase();
      final path = (s['path'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (!name.contains(query) && !desc.contains(query) && !path.contains(query)) {
        return false;
      }

      // 2. Path Filter
      if (_pathFilter != "All Paths") {
        final pathMatch = _pathFilter.toLowerCase().replaceAll(' paths', '').replaceAll('all ', '');
        if (!path.contains(pathMatch)) {
          return false;
        }
      }

      // 3. Type Filter
      if (_typeFilter != "All Types") {
        final type = (s['secret_type'] ?? '').toString();
        if (type != _typeFilter) {
          return false;
        }
      }

      // 4. Status Filter
      if (_statusFilter != "All Status") {
        final status = (s['status'] ?? '').toString();
        if (status != _statusFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    // Compute Metrics
    final totalSecrets = _secrets.length;
    final activeSecrets = _secrets.where((s) => s['status'] == 'Active').length;
    final expiringSoon = _secrets.where((s) => s['status'] == 'Expiring Soon').length;
    final activePct = totalSecrets > 0 ? (activeSecrets / totalSecrets * 100).toStringAsFixed(1) : '0.0';

    // Last rotation time calculation
    String lastRotationAgo = 'Never';
    String lastRotationStr = 'Never';
    if (_secrets.isNotEmpty) {
      DateTime? latestDate;
      for (final s in _secrets) {
        if (s['updated_at'] != null) {
          final dt = DateTime.parse(s['updated_at']);
          if (latestDate == null || dt.isAfter(latestDate)) {
            latestDate = dt;
          }
        }
      }
      if (latestDate != null) {
        final diff = DateTime.now().difference(latestDate);
        if (diff.inDays == 0) {
          lastRotationAgo = 'Today';
        } else if (diff.inDays == 1) {
          lastRotationAgo = '1 day ago';
        } else {
          lastRotationAgo = '${diff.inDays} days ago';
        }
        lastRotationStr = DateFormat('MMM d, yyyy h:mm a').format(latestDate);
      }
    }

    // Pagination slice
    final maxPage = (filteredSecrets.length / _pageSize).ceil();
    final displayPage = _currentPage > maxPage ? (maxPage > 0 ? maxPage : 1) : _currentPage;
    final startIndex = (displayPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > filteredSecrets.length ? filteredSecrets.length : startIndex + _pageSize;
    final paginatedSecrets = filteredSecrets.isEmpty ? [] : filteredSecrets.sublist(startIndex, endIndex);

    final isWideScreen = MediaQuery.of(context).size.width >= 1200;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final mainLayout = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Block
        _buildHeader(isDark, textPrimary, textSecondary, accentColor, isMobile),
        const SizedBox(height: 16),

        // Metrics Row
        _buildMetricsRow(isDark, cardBg, borderColor, textPrimary, textSecondary, totalSecrets, activeSecrets, activePct, expiringSoon, lastRotationAgo, lastRotationStr, isMobile),
        const SizedBox(height: 16),

        // Filter toolbar
        _buildFilterToolbar(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, isMobile),
        const SizedBox(height: 16),

        // Main Pane Row
        isMobile
            ? SizedBox(
                height: 480,
                child: _selectedSecret != null
                    ? _buildDetailPane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor)
                    : _buildTablePane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, paginatedSecrets, filteredSecrets.length, startIndex, endIndex, displayPage, maxPage),
              )
            : Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Table Pane
                    Expanded(
                      flex: isWideScreen && _selectedSecret != null ? 7 : 10,
                      child: _buildTablePane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor, paginatedSecrets, filteredSecrets.length, startIndex, endIndex, displayPage, maxPage),
                    ),
                    
                    // Right Detail Pane
                    if (_selectedSecret != null) ...[
                      const SizedBox(width: 24),
                      Expanded(
                        flex: isWideScreen ? 3 : 4,
                        child: _buildDetailPane(isDark, cardBg, borderColor, textPrimary, textSecondary, textMuted, accentColor),
                      ),
                    ],
                  ],
                ),
              ),
      ],
    );

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: _isLoading && _secrets.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : Padding(
                padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                child: isMobile
                    ? SingleChildScrollView(child: mainLayout)
                    : mainLayout,
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textPrimary, Color textSecondary, Color accentColor, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Vault Secrets',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateOrEditDialog(),
                icon: const Icon(Icons.add, size: 14, color: Colors.white),
                label: Text('Create', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Securely store and manage sensitive environment variables and credentials.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vault Secrets',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Securely store and manage sensitive information like API keys, passwords, tokens and certificates.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _showCreateOrEditDialog(),
          icon: const Icon(Icons.add, size: 16, color: Colors.white),
          label: Text('Create Secret', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, int total, int active, String activePct, int expiring, String rotationAgo, String rotationStr, bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.lock_outline_rounded, Colors.purple, 'Total Secrets', '$total', 'Across all paths')),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.key_rounded, Colors.blue, 'Active Secrets', '$active', '$activePct% of total')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.watch_later_outlined, Colors.orange, 'Expiring Soon', '$expiring', 'Within 30 days')),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.verified_user_outlined, Colors.green, 'Last Rotation', rotationAgo, rotationStr)),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.lock_outline_rounded, Colors.purple, 'Total Secrets', '$total', 'Across all paths')),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.key_rounded, Colors.blue, 'Active Secrets', '$active', '$activePct% of total')),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.watch_later_outlined, Colors.orange, 'Expiring Soon', '$expiring', 'Within 30 days')),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(isDark, cardBg, borderColor, textPrimary, textSecondary, Icons.verified_user_outlined, Colors.green, 'Last Rotation', rotationAgo, rotationStr)),
      ],
    );
  }

  Widget _buildMetricCard(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, IconData icon, Color color, String title, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.outfit(fontSize: 20, color: textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.dmSans(fontSize: 10, color: textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search box
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search secrets by name or path...',
                        hintStyle: GoogleFonts.dmSans(color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Dropdowns and reset button
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterDropdown(
                  'Path',
                  _pathFilter,
                  ['All Paths', 'database', 'aws', 'google', 'email', 'github', 'security', 'azure', 'slack'],
                  (val) => setState(() {
                    _pathFilter = val!;
                    _currentPage = 1;
                  }),
                  cardBg,
                  textSecondary,
                ),
                _buildFilterDropdown(
                  'Type',
                  _typeFilter,
                  ['All Types', 'Password', 'API Key', 'Key / Secret', 'Username / Pass', 'Token', 'Private Key', 'Connection String', 'URL'],
                  (val) => setState(() {
                    _typeFilter = val!;
                    _currentPage = 1;
                  }),
                  cardBg,
                  textSecondary,
                ),
                _buildFilterDropdown(
                  'Status',
                  _statusFilter,
                  ['All Status', 'Active', 'Expiring Soon', 'Expired'],
                  (val) => setState(() {
                    _statusFilter = val!;
                    _currentPage = 1;
                  }),
                  cardBg,
                  textSecondary,
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = "";
                      _pathFilter = "All Paths";
                      _typeFilter = "All Types";
                      _statusFilter = "All Status";
                      _currentPage = 1;
                    });
                  },
                  icon: const Icon(Icons.filter_list_off, size: 14),
                  label: Text('Reset', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Search box
          Expanded(
            flex: 4,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search secrets by name or path...',
                        hintStyle: GoogleFonts.dmSans(color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Path Filter Dropdown
          _buildFilterDropdown(
            'Path',
            _pathFilter,
            ['All Paths', 'database', 'aws', 'google', 'email', 'github', 'security', 'azure', 'slack'],
            (val) => setState(() {
              _pathFilter = val!;
              _currentPage = 1;
            }),
            cardBg,
            textSecondary,
          ),
          const SizedBox(width: 12),

          // Type Filter Dropdown
          _buildFilterDropdown(
            'Type',
            _typeFilter,
            ['All Types', 'Password', 'API Key', 'Key / Secret', 'Username / Pass', 'Token', 'Private Key', 'Connection String', 'URL'],
            (val) => setState(() {
              _typeFilter = val!;
              _currentPage = 1;
            }),
            cardBg,
            textSecondary,
          ),
          const SizedBox(width: 12),

          // Status Filter Dropdown
          _buildFilterDropdown(
            'Status',
            _statusFilter,
            ['All Status', 'Active', 'Expiring Soon', 'Expired'],
            (val) => setState(() {
              _statusFilter = val!;
              _currentPage = 1;
            }),
            cardBg,
            textSecondary,
          ),
          const SizedBox(width: 12),

          // Filters Reset Button
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = "";
                _pathFilter = "All Paths";
                _typeFilter = "All Types";
                _statusFilter = "All Status";
                _currentPage = 1;
              });
            },
            icon: const Icon(Icons.filter_list_off, size: 16),
            label: Text('Filters', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, Color cardBg, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: cardBg,
          onChanged: onChanged,
          items: items.map((i) {
            return DropdownMenuItem(
              value: i,
              child: Text(
                i,
                style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTablePane(
    bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor,
    List<dynamic> paginated, int totalCount, int start, int end, int displayPage, int maxPage
  ) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Layout
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double containerWidth = constraints.maxWidth - 32;
                const double baseWidth = 860.0;
                final double scale = containerWidth > baseWidth ? containerWidth / baseWidth : 1.0;

                final double colName = (isMobile ? 140.0 : 180.0) * scale;
                final double colPath = 200.0 * scale;
                final double colType = 110.0 * scale;
                final double colModified = 120.0 * scale;
                final double colRotation = 120.0 * scale;
                final double colStatus = (isMobile ? 80.0 : 90.0) * scale;
                final double colActions = (isMobile ? 70.0 : 90.0) * scale;

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        horizontalMargin: 12,
                        columnSpacing: 12,
                        columns: [
                          _buildTableHeaderColumn('Secret Name', textSecondary, width: colName),
                          if (!isMobile) ...[
                            _buildTableHeaderColumn('Path', textSecondary, width: colPath),
                            _buildTableHeaderColumn('Type', textSecondary, width: colType),
                            _buildTableHeaderColumn('Last Modified', textSecondary, width: colModified),
                            _buildTableHeaderColumn('Next Rotation', textSecondary, width: colRotation),
                          ],
                          _buildTableHeaderColumn('Status', textSecondary, width: colStatus),
                          _buildTableHeaderColumn('Actions', textSecondary, width: colActions),
                        ],
                        rows: paginated.map((sec) {
                          final id = sec['id']?.toString() ?? '';
                          final name = sec['name']?.toString() ?? 'Secret';
                          final path = sec['path']?.toString() ?? 'secret/data/';
                          final type = sec['secret_type']?.toString() ?? 'API Key';
                          final status = sec['status']?.toString() ?? 'Active';
                          final desc = sec['description']?.toString() ?? '';

                          final modifiedStr = sec['updated_at'] != null
                              ? DateFormat('dd MMM yyyy\nkk:mm a').format(DateTime.parse(sec['updated_at']).toLocal())
                              : '';
                          final rotationStr = sec['next_rotation'] != null
                              ? DateFormat('dd MMM yyyy\nkk:mm a').format(DateTime.parse(sec['next_rotation']).toLocal())
                              : '-';

                          final isSelected = _selectedSecret != null && _selectedSecret['id'] == id;

                          return DataRow(
                            selected: isSelected,
                            onSelectChanged: (_) => _selectSecret(sec),
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: colName,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                        child: Icon(Icons.code_rounded, size: 12, color: accentColor),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 12, color: textPrimary), overflow: TextOverflow.ellipsis),
                                            if (desc.isNotEmpty && !isMobile) Text(desc, style: GoogleFonts.dmSans(fontSize: 10, color: textSecondary), overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isMobile) ...[
                                DataCell(
                                  SizedBox(
                                    width: colPath,
                                    child: Text(path, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: textSecondary), overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: colType,
                                    child: Text(type, style: GoogleFonts.dmSans(fontSize: 12, color: textPrimary)),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: colModified,
                                    child: Text(modifiedStr, style: GoogleFonts.dmSans(fontSize: 11, color: textSecondary)),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: colRotation,
                                    child: Text(rotationStr, style: GoogleFonts.dmSans(fontSize: 11, color: textSecondary)),
                                  ),
                                ),
                              ],
                              DataCell(
                                SizedBox(
                                  width: colStatus,
                                  child: _buildStatusBadge(status, isDark),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: colActions,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      InkWell(
                                        onTap: () => _revealSecret(id),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                          child: Icon(
                                            _revealedSecrets.containsKey(id) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            size: 14,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, size: 14, color: textSecondary),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        color: cardBg,
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _showCreateOrEditDialog(sec);
                                          } else if (val == 'rotate') {
                                            _showCreateOrEditDialog(sec);
                                          } else if (val == 'delete') {
                                            _confirmDeleteDialog(id, name);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(value: 'edit', child: Text('Edit Details', style: GoogleFonts.dmSans(fontSize: 12, color: textPrimary))),
                                          PopupMenuItem(value: 'rotate', child: Text('Rotate Secret', style: GoogleFonts.dmSans(fontSize: 12, color: textPrimary))),
                                          PopupMenuItem(value: 'delete', child: Text('Delete Secret', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.redAccent))),
                                        ],
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
                  ),
                );
              },
            ),
          ),

          // Pagination Footer
          const Divider(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Showing ${totalCount == 0 ? 0 : start + 1} to $end of $totalCount secrets',
                  style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 16),
                  color: displayPage > 1 ? textPrimary : textMuted,
                  onPressed: displayPage > 1 ? () => setState(() => _currentPage = displayPage - 1) : null,
                ),
                ...List.generate(maxPage, (index) {
                  final pageNum = index + 1;
                  return InkWell(
                    onTap: () => setState(() => _currentPage = pageNum),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: pageNum == displayPage ? accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$pageNum',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pageNum == displayPage ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 16),
                  color: displayPage < maxPage ? textPrimary : textMuted,
                  onPressed: displayPage < maxPage ? () => setState(() => _currentPage = displayPage + 1) : null,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _pageSize,
                      dropdownColor: cardBg,
                      style: GoogleFonts.dmSans(fontSize: 11, color: textSecondary),
                      onChanged: (val) {
                        setState(() {
                          _pageSize = val!;
                          _currentPage = 1;
                        });
                      },
                      items: [5, 10, 20, 50].map((s) {
                        return DropdownMenuItem<int>(value: s, child: Text('$s / page'));
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPane(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary, Color textMuted, Color accentColor) {
    final sec = _selectedSecret;
    final id = sec['id']?.toString() ?? '';
    final name = sec['name']?.toString() ?? '';
    final path = sec['path']?.toString() ?? '';
    final type = sec['secret_type']?.toString() ?? '';
    final status = sec['status']?.toString() ?? 'Active';
    final desc = sec['description']?.toString() ?? '';
    final version = sec['version'] ?? 1;

    final createdStr = sec['created_at'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(sec['created_at']).toLocal()) : '';
    final modifiedStr = sec['updated_at'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(sec['updated_at']).toLocal()) : '';
    final rotationStr = sec['next_rotation'] != null ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(sec['next_rotation']).toLocal()) : 'Never';

    final createdBy = sec['created_by'] ?? 'Super Admin';
    final modifiedBy = sec['modified_by'] ?? 'System';

    final isRevealed = _revealedSecrets.containsKey(id);
    final decryptedVal = _revealedSecrets[id] ?? '';
    final isDecrypting = _loadingSecretIds.contains(id);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pane Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Secret Details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedSecret = null;
                    });
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),

            // Icon & Name & Status Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.code, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _buildStatusBadge(status, isDark),
              ],
            ),
            const SizedBox(height: 20),

            // Metadata list
            _buildDetailRow('Path', path, textSecondary, isCopyable: true),
            _buildDetailRow('Type', type, textSecondary),
            _buildDetailRow('Created On', createdStr, textSecondary),
            _buildDetailRow('Created By', createdBy, textSecondary),
            _buildDetailRow('Last Modified', modifiedStr, textSecondary),
            _buildDetailRow('Modified By', modifiedBy, textSecondary),
            _buildDetailRow('Next Rotation', rotationStr, textSecondary),
            _buildDetailRow('Description', desc.isNotEmpty ? desc : 'No description provided', textSecondary, isLongText: true),

            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Secret Value field
            Text('Secret Value', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: isDecrypting
                        ? const Align(alignment: Alignment.centerLeft, child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                        : SelectableText(
                            isRevealed ? decryptedVal : '••••••••••••••••••••••••',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: isRevealed ? accentColor : textSecondary,
                              fontWeight: isRevealed ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _revealSecret(id),
                    child: Icon(isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: textSecondary),
                  ),
                  if (isRevealed) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: decryptedVal));
                        _showSnackBar('Value copied to clipboard', Colors.green);
                      },
                      child: Icon(Icons.copy, size: 16, color: textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Version Block
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Version', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text('v$version', style: GoogleFonts.dmSans(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showVersionsDialog(sec),
                  child: Text('View all versions', style: GoogleFonts.dmSans(fontSize: 12, color: accentColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            OutlinedButton.icon(
              onPressed: () => _showCreateOrEditDialog(sec),
              icon: Icon(Icons.rotate_left_rounded, size: 16, color: accentColor),
              label: Text('Rotate Secret', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: accentColor)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _confirmDeleteDialog(id, name),
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              label: Text('Delete Secret', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),

            // About Vault Secrets info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user, size: 14, color: accentColor),
                      const SizedBox(width: 6),
                      Text('About Vault Secrets', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All secrets are encrypted using AES-256 encryption and stored securely. Access is controlled through roles and permissions.',
                    style: GoogleFonts.dmSans(fontSize: 10, color: textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      _showSnackBar('Detailed Vault security documentation is available in the help center.', Colors.blue);
                    },
                    child: Text('Learn more →', style: GoogleFonts.dmSans(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color textSecondary, {bool isCopyable = false, bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: isLongText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary, height: 1.4)),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: isCopyable
                              ? TextStyle(fontFamily: 'monospace', fontSize: 12, color: textSecondary)
                              : GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCopyable) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: value));
                            _showSnackBar('Copied to clipboard', Colors.green);
                          },
                          child: const Icon(Icons.copy, size: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  DataColumn _buildTableHeaderColumn(String label, Color color, {double? width}) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Expired':
        bg = isDark ? const Color(0xFF991B1B).withValues(alpha: 0.2) : const Color(0xFFFEE2E2);
        fg = isDark ? Colors.red.shade300 : const Color(0xFF991B1B);
        break;
      case 'Expiring Soon':
        bg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.2) : const Color(0xFFFEF3C7);
        fg = isDark ? Colors.amber.shade300 : const Color(0xFF78350F);
        break;
      case 'Active':
      default:
        bg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFD1FAE5);
        fg = isDark ? Colors.green.shade300 : const Color(0xFF064E3B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  void _confirmDeleteDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete secret "$name" from the hardware vault?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteSecret(id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

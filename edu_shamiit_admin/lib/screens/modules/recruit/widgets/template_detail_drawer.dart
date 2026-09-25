import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_template_presets.dart';
import 'template_editor_dialog.dart';
import 'institutional_document_renderer.dart';

class TemplateDetailDrawer extends StatefulWidget {
  final String templateId;
  final Map<String, dynamic>? initialData;
  final VoidCallback onTemplateUpdated;

  const TemplateDetailDrawer({
    super.key,
    required this.templateId,
    this.initialData,
    required this.onTemplateUpdated,
  });

  @override
  State<TemplateDetailDrawer> createState() => _TemplateDetailDrawerState();
}

class _TemplateDetailDrawerState extends State<TemplateDetailDrawer> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isUpgrading = false;
  String? _errorMessage;
  Map<String, dynamic>? _templateData;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.initialData != null) {
      _templateData = Map<String, dynamic>.from(widget.initialData!);
      _isLoading = false;
    }
    _fetchTemplate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplate() async {
    try {
      final res = await _api.get('/hr/templates/${widget.templateId}', useCache: false);
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _templateData = res['data'] as Map<String, dynamic>;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        if (_templateData == null && mounted) {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to load template details.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (_templateData == null && mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openEditor() {
    showDialog(
      context: context,
      builder: (_) => TemplateEditorDialog(
        initialTemplate: _templateData,
        initialTemplateId: widget.templateId,
        onTemplatesChanged: () {
          _fetchTemplate();
          widget.onTemplateUpdated();
        },
      ),
    );
  }

  Future<void> _upgradeToStandardPreset(String type) async {
    final preset = HRTemplatePresets.getPresetForType(type);
    setState(() => _isUpgrading = true);

    try {
      final res = await _api.patch('/hr/templates/${widget.templateId}', {
        'template_type': type,
        'content_html': preset.contentHtml.trim(),
        'variables': preset.variables,
        'description': preset.description,
      });

      if (res['success'] == true) {
        await _fetchTemplate();
        widget.onTemplateUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully upgraded to standard $type template!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating template: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  void _copyToClipboard(String text, String successMsg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(successMsg),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getTypeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('warn')) return const Color(0xFFEF4444);
    if (t.contains('offer')) return const Color(0xFF3B82F6);
    if (t.contains('appoint')) return const Color(0xFF6366F1);
    if (t.contains('exp') || t.contains('cert')) return const Color(0xFF10B981);
    if (t.contains('reliev')) return const Color(0xFFF59E0B);
    if (t.contains('nda') || t.contains('confid')) return const Color(0xFF8B5CF6);
    if (t.contains('conduct')) return const Color(0xFF06B6D4);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final drawerWidth = width > 700 ? 640.0 : width;

    if (_isLoading && _templateData == null) {
      return Container(
        width: drawerWidth,
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _templateData == null) {
      return Container(
        width: drawerWidth,
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_errorMessage', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchTemplate();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final t = _templateData ?? {};
    final title = t['template_name'] ?? t['title'] ?? 'Document Template';
    final code = t['template_code'] ?? 'TMPL';
    final type = t['template_type'] ?? 'Template';
    final category = t['category_name'] ?? 'General';
    final rawContent = t['content_html'] ?? t['content'] ?? '<p>No content defined for this template.</p>';
    final substituted = HRTemplatePresets.substituteVariables(rawContent, type);
    final rendered = HRTemplatePresets.renderPreview(rawContent, type);
    final isActive = t['is_active'] != false;
    final updatedAt = t['updated_at'] ?? t['created_at'];

    final typeColor = _getTypeColor(type);
    final isWarning = type.toLowerCase().contains('warn');
    final isMismatchedExperience = isWarning && rawContent.contains('This is to certify that');

    return Container(
      width: drawerWidth,
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isWarning ? Icons.warning_amber_rounded : Icons.description_rounded,
                        color: typeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(
                                    color: isActive ? const Color(0xFF10B981) : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Action Bar
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openEditor,
                      icon: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
                      label: const Text('Edit in Studio', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(rendered, 'Rendered sample letter copied!'),
                      icon: Icon(Icons.copy_rounded, size: 14, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                      label: Text('Copy Preview Text', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),

                // Mismatch upgrade banner
                if (isMismatchedExperience) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This template is set as a Warning Letter but still contains default Experience Letter text.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isUpgrading ? null : () => _upgradeToStandardPreset('Warning Letter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: _isUpgrading
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Upgrade to Warning Letter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF4F46E5),
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  indicatorColor: const Color(0xFF4F46E5),
                  tabs: const [
                    Tab(icon: Icon(Icons.remove_red_eye_outlined, size: 16), text: 'Document Preview'),
                    Tab(icon: Icon(Icons.code_rounded, size: 16), text: 'Template Source & Tags'),
                    Tab(icon: Icon(Icons.info_outline_rounded, size: 16), text: 'Variables & Info'),
                  ],
                ),
              ],
            ),
          ),

          // Body Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 0: Document Preview
                _buildDocumentPreviewTab(isDark, title, code, type, substituted, isWarning),

                // Tab 1: Template Source & Tags
                _buildTemplateSourceTab(isDark, rawContent),

                // Tab 2: Variables & Info
                _buildVariablesAndInfoTab(isDark, t, updatedAt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreviewTab(bool isDark, String title, String code, String type, String htmlContent, bool isWarning) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Live Letterhead Preview: dynamic placeholders are populated with realistic $type record values.',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: _openEditor,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('Edit in Studio', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Institutional Letterhead Paper
          Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GREENFIELD INTERNATIONAL INSTITUTION',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'DIVISION OF HUMAN RESOURCES & TALENT MANAGEMENT',
                          style: TextStyle(fontSize: 9, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF4F46E5), size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: const Color(0xFF4F46E5).withValues(alpha: 0.4), thickness: 1.5),
                const SizedBox(height: 14),

                // Meta Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ref: $code-2026', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    Text('Date: ${_dateFormat.format(DateTime.now())}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 18),

                // Disciplinary Banner if warning
                if (isWarning) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('FORMAL DISCIPLINARY & PERFORMANCE RECORD', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Document Title
                Center(
                  child: Text(
                    title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      decoration: TextDecoration.underline,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Rendered Body Text with Rich Tables & Formatting
                InstitutionalDocumentRenderer(
                  htmlContent: htmlContent,
                  templateType: type,
                  isDark: isDark,
                ),
                const SizedBox(height: 40),

                // Signature Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 1,
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        const SizedBox(height: 6),
                        const Text('Authorized Signatory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        const Text('Head of Administration & HR', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('INSTITUTION SEAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
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

  Widget _buildTemplateSourceTab(bool isDark, String rawContent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Template Markup & Variables', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _copyToClipboard(rawContent, 'HTML content copied!'),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Raw Text', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: SelectableText(
              rawContent,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.6,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF312E81),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Standard Dynamic Variables for this Template:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: HRTemplatePresets.allVariables.map((v) {
              final tag = '{{${v.tag}}}';
              final isPresent = rawContent.contains(tag) || rawContent.contains('{${v.tag}}');
              return ActionChip(
                avatar: Icon(
                  isPresent ? Icons.check_circle_rounded : Icons.label_outline_rounded,
                  size: 14,
                  color: isPresent ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                ),
                label: Text(tag, style: TextStyle(fontSize: 11, fontWeight: isPresent ? FontWeight.bold : FontWeight.normal)),
                backgroundColor: isPresent
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : const Color(0xFF4F46E5).withValues(alpha: 0.06),
                onPressed: () => _copyToClipboard(tag, 'Variable tag $tag copied!'),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVariablesAndInfoTab(bool isDark, Map<String, dynamic> t, dynamic updatedAt) {
    const vars = HRTemplatePresets.allVariables;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Template Information', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Template Code', t['template_code'] ?? '—', isDark),
                const Divider(height: 16),
                _buildInfoRow('Letter Type', t['template_type'] ?? '—', isDark),
                const Divider(height: 16),
                _buildInfoRow('Category', t['category_name'] ?? '—', isDark),
                const Divider(height: 16),
                _buildInfoRow('Description', t['description'] ?? 'No description provided.', isDark),
                const Divider(height: 16),
                _buildInfoRow('Status', (t['is_active'] != false) ? 'Active' : 'Inactive', isDark),
                const Divider(height: 16),
                _buildInfoRow('Last Updated', updatedAt != null ? _dateFormat.format(DateTime.parse(updatedAt.toString())) : '—', isDark),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Full Institutional Dynamic Variables Dictionary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vars.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final v = vars[index];
                return ListTile(
                  dense: true,
                  title: Text('{{${v.tag}}}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5))),
                  subtitle: Text('${v.label} · Example: "${v.sampleValue}"', style: const TextStyle(fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    onPressed: () => _copyToClipboard('{{${v.tag}}}', 'Tag {{${v.tag}}} copied!'),
                    tooltip: 'Copy tag',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}

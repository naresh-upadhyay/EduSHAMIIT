import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class PolicyAcknowledgementDialog extends StatefulWidget {
  final Map<String, dynamic> acknowledgement;
  final VoidCallback onAcknowledged;
  final void Function(String policyId)? onOpenPolicyDrawer;

  const PolicyAcknowledgementDialog({
    super.key,
    required this.acknowledgement,
    required this.onAcknowledged,
    this.onOpenPolicyDrawer,
  });

  @override
  State<PolicyAcknowledgementDialog> createState() => _PolicyAcknowledgementDialogState();
}

class _PolicyAcknowledgementDialogState extends State<PolicyAcknowledgementDialog> {
  final ApiService _api = ApiService();
  bool _isLoadingContent = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  Map<String, dynamic>? _policyDetails;
  bool _hasAgreed = false;
  final _signatureController = TextEditingController();
  final _commentController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _fetchPolicyContent();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchPolicyContent() async {
    final policyId = widget.acknowledgement['policy_id'];
    if (policyId == null || policyId.toString().isEmpty) {
      setState(() {
        _isLoadingContent = false;
        _errorMessage = 'No policy identifier associated with this acknowledgement.';
      });
      return;
    }

    try {
      final res = await _api.get('/hr/policies/$policyId', useCache: false);
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _policyDetails = res['data'];
            _isLoadingContent = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to load policy details.';
            _isLoadingContent = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingContent = false;
        });
      }
    }
  }

  Future<void> _submitSignOff() async {
    if (!_hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check the confirmation box to agree to the policy.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_signatureController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digital signature / full name is required.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ackId = widget.acknowledgement['id'];
      final res = await _api.post('/hr/acknowledgements/$ackId/acknowledge', {
        'signature_text': _signatureController.text.trim(),
        'comment': _commentController.text.trim(),
      });

      if (res['success'] == true) {
        widget.onAcknowledged();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Policy acknowledged and signed successfully!'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception(res['message'] ?? 'Submission failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ack = widget.acknowledgement;
    final isMandatory = ack['is_mandatory'] == true;
    final isAcknowledged = (ack['status'] ?? '').toString().toUpperCase() == 'ACKNOWLEDGED';

    final deadlineStr = ack['deadline'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(ack['deadline'].toString()))
        : 'Open';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 820,
        height: 700,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isAcknowledged ? const Color(0xFF10B981) : const Color(0xFF4F46E5)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isAcknowledged ? Icons.verified_rounded : Icons.verified_user_rounded,
                          color: isAcknowledged ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ack['policy_title'] ?? 'Policy Review & Sign-off',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'v${ack['version_number'] ?? '1.0'}',
                                    style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isAcknowledged ? const Color(0xFF10B981) : Colors.amber).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isAcknowledged ? 'SIGNED & ACKNOWLEDGED' : (ack['status'] ?? 'PENDING'),
                                    style: TextStyle(
                                      color: isAcknowledged ? const Color(0xFF10B981) : Colors.amber.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Deadline: $deadlineStr · ${isMandatory ? 'Strictly Mandatory' : 'Standard Advisory'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isMandatory ? Colors.red.shade700 : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                fontWeight: isMandatory ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 24),

            // Policy Content Viewer
            Expanded(
              child: _isLoadingContent
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 36, color: Colors.amber),
                              const SizedBox(height: 10),
                              Text(_errorMessage!, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _fetchPolicyContent, child: const Text('Retry Loading')),
                            ],
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _cleanHtml(_policyDetails?['content_html'] ?? _policyDetails?['description'] ?? 'No policy body text provided.'),
                              style: const TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 16),

            // Acknowledgement Details or Sign-off Form
            if (isAcknowledged)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Institutional Sign-off Recorded & Legally Binding',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Signed By: ${ack['signature_text'] ?? ack['user_name'] ?? 'Employee'} · Date: ${ack['acknowledged_at'] != null ? _dateFormat.format(DateTime.parse(ack['acknowledged_at'].toString())) : 'Completed'}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          ),
                          if (ack['comment'] != null && ack['comment'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Remarks: "${ack['comment']}"',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _hasAgreed,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) => setState(() => _hasAgreed = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'I confirm that I have read, understood, and agree to adhere to the terms and directives outlined in this institutional policy.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _signatureController,
                            decoration: InputDecoration(
                              labelText: 'Digital Signature (Full Legal Name) *',
                              hintText: 'e.g. Dr. Ramesh Kumar',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              labelText: 'Comments / Remarks (Optional)',
                              hintText: 'Any queries or acceptance note...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onOpenPolicyDrawer != null && ack['policy_id'] != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenPolicyDrawer!(ack['policy_id'].toString());
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('View Full Policy (360 Detail)', style: TextStyle(fontSize: 12)),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    if (!isAcknowledged) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitSignOff,
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: Text(_isSubmitting ? 'Signing...' : 'Sign & Acknowledge', style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dialogs/quick_issue_dialog.dart';
import 'dialogs/quick_return_dialog.dart';
import 'dialogs/circulation_barcode_dialog.dart';


class CirculationQuickIssueReturnCard extends ConsumerStatefulWidget {
  const CirculationQuickIssueReturnCard({super.key});

  @override
  ConsumerState<CirculationQuickIssueReturnCard> createState() => _CirculationQuickIssueReturnCardState();
}

class _CirculationQuickIssueReturnCardState extends ConsumerState<CirculationQuickIssueReturnCard> {
  int _activeTab = 0; // 0 = Quick Issue, 1 = Quick Return
  final TextEditingController _memberSearchCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();

  @override
  void dispose() {
    _memberSearchCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Tab Switcher (Quick Issue | Quick Return)
          Row(
            children: [
              _buildTabButton('Quick Issue', 0, isDark),
              const SizedBox(width: 14),
              _buildTabButton('Quick Return', 1, isDark),
            ],
          ),
          const SizedBox(height: 16),

          if (_activeTab == 0) ...[
            // Step Progress (1. Select Member -> 2. Select Book(s) -> 3. Confirm Issue)
            Row(
              children: [
                _buildStepBubble('1', 'Select Member', true, isDark),
                _buildStepDivider(isDark),
                _buildStepBubble('2', 'Select Book(s)', false, isDark),
                _buildStepDivider(isDark),
                _buildStepBubble('3', 'Confirm Issue', false, isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Search Member + Scan Card Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, roll no., phone...',
                      hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    onSubmitted: (val) {
                      showDialog(
                        context: context,
                        builder: (_) => QuickIssueDialog(initialMemberQuery: val),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF6366F1)),
                  label: const Text('Scan / Enter Member ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const CirculationBarcodeDialog(),
                    );
                  },
                ),
              ],
            ),
          ] else ...[
            // Quick Return Body
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeCtrl,
                    decoration: InputDecoration(
                      hintText: 'Scan or enter book barcode / accession / transaction ID...',
                      hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF6366F1)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    onSubmitted: (val) {
                      showDialog(
                        context: context,
                        builder: (_) => QuickReturnDialog(initialBarcodeQuery: val),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Process Return', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => QuickReturnDialog(initialBarcodeQuery: _barcodeCtrl.text),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, bool isDark) {
    final isActive = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 4),
          if (isActive)
            Container(
              height: 2.5,
              width: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1),
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(height: 2.5),
        ],
      ),
    );
  }

  Widget _buildStepBubble(String number, String label, bool isCurrent, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: isCurrent ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          child: Text(
            number,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isDark) {
    return Container(
      width: 20,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
    );
  }
}

import 'package:flutter/material.dart';

class CampusHeaderBar extends StatelessWidget {
  final VoidCallback onAddBuilding;
  final VoidCallback onBulkImport;
  final VoidCallback onExport;

  const CampusHeaderBar({
    super.key,
    required this.onAddBuilding,
    required this.onBulkImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 750;

          final actionButtons = [
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF93C5FD) : primaryColor,
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onBulkImport,
              icon: const Icon(Icons.file_upload_outlined, size: 16),
              label: const Text('Bulk Import', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFF93C5FD) : primaryColor,
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAddBuilding,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Add Building', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campus Management',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage infrastructure & facilities',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actionButtons,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.domain_rounded,
                  color: primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Campus Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage campus infrastructure, facilities, spaces and resources of your institution',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: actionButtons,
              ),
            ],
          );
        },
      ),
    );
  }
}

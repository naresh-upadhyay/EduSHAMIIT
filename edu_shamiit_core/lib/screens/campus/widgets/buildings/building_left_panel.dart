import 'package:flutter/material.dart';
import '../../models/campus_models.dart';

class BuildingLeftPanel extends StatelessWidget {
  final List<BuildingModel> buildings;
  final BuildingModel? selectedBuilding;
  final ValueChanged<BuildingModel> onSelectBuilding;
  final VoidCallback onAddBuilding;
  final ValueChanged<String> onSearch;
  final String searchQuery;

  const BuildingLeftPanel({
    super.key,
    required this.buildings,
    required this.selectedBuilding,
    required this.onSelectBuilding,
    required this.onAddBuilding,
    required this.onSearch,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Add Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Buildings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: onAddBuilding,
                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                  label: const Text('Add', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              onChanged: onSearch,
              decoration: InputDecoration(
                hintText: 'Search building...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Buildings List
          Expanded(
            child: buildings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No buildings found.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: buildings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bld = buildings[index];
                      final isSelected = selectedBuilding?.id == bld.id;

                      return InkWell(
                        onTap: () => onSelectBuilding(bld),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                                : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.4) : Colors.white),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Building Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  child: bld.imageUrl != null && bld.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          bld.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.apartment_rounded,
                                            color: Color(0xFF64748B),
                                            size: 24,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.apartment_rounded,
                                          color: Color(0xFF64748B),
                                          size: 24,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${bld.code} - ${bld.name}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getSubtitle(bld),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        // Rooms badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${bld.totalRooms} Rooms',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            bld.status,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle(BuildingModel bld) {
    if (bld.description != null && bld.description!.isNotEmpty) {
      return bld.description!;
    }
    return '${bld.buildingType} Block';
  }
}

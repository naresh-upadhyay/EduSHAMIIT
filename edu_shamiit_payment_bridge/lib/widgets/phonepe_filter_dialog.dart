import 'package:flutter/material.dart';

class PhonePeFilterState {
  final Set<String> selectedMonths;
  final Set<String> selectedCategories;
  final Set<String> selectedInstruments;
  final Set<String> selectedStatuses;
  final Set<String> selectedPaymentTypes;

  const PhonePeFilterState({
    this.selectedMonths = const {},
    this.selectedCategories = const {},
    this.selectedInstruments = const {},
    this.selectedStatuses = const {},
    this.selectedPaymentTypes = const {},
  });

  bool get isEmpty =>
      selectedMonths.isEmpty &&
      selectedCategories.isEmpty &&
      selectedInstruments.isEmpty &&
      selectedStatuses.isEmpty &&
      selectedPaymentTypes.isEmpty;

  int get totalActiveCount =>
      selectedMonths.length +
      selectedCategories.length +
      selectedInstruments.length +
      selectedStatuses.length +
      selectedPaymentTypes.length;

  PhonePeFilterState copyWith({
    Set<String>? selectedMonths,
    Set<String>? selectedCategories,
    Set<String>? selectedInstruments,
    Set<String>? selectedStatuses,
    Set<String>? selectedPaymentTypes,
  }) {
    return PhonePeFilterState(
      selectedMonths: selectedMonths ?? this.selectedMonths,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedInstruments: selectedInstruments ?? this.selectedInstruments,
      selectedStatuses: selectedStatuses ?? this.selectedStatuses,
      selectedPaymentTypes: selectedPaymentTypes ?? this.selectedPaymentTypes,
    );
  }
}

class PhonePeFilterDialog extends StatefulWidget {
  final PhonePeFilterState initialState;
  final bool isForAlerts;

  const PhonePeFilterDialog({
    super.key,
    required this.initialState,
    this.isForAlerts = false,
  });

  @override
  State<PhonePeFilterDialog> createState() => _PhonePeFilterDialogState();
}

class _PhonePeFilterDialogState extends State<PhonePeFilterDialog> {
  int _activeCategoryIndex = 0;

  late Set<String> _months;
  late Set<String> _categories;
  late Set<String> _instruments;
  late Set<String> _statuses;
  late Set<String> _types;

  final List<String> _availableMonths = [
    'Nov 2026',
    'Oct 2026',
    'Sept 2026',
    'Aug 2026',
    'Jul 2026',
    'Jun 2026',
    'May 2026',
    'Apr 2026',
    'Mar 2026',
    'Feb 2026',
    'Jan 2026',
    'Dec 2025',
  ];

  final List<String> _availableCategories = [
    'School Tuition Fees',
    'Hostel & Boarding',
    'Transport & Bus',
    'Exam & Certification',
    'Books & Uniform',
    'Other Institution Dues',
  ];

  final List<String> _availableInstruments = [
    'PhonePe',
    'Google Pay',
    'Paytm',
    'BHIM UPI',
    'Canara ai1',
    'Bank SMS Alerts',
    'Other UPI Apps',
  ];

  final List<String> _availableStatusesTransactions = [
    'Successful',
    'Pending',
    'Unmatched',
    'Review Required',
    'Refunded',
  ];

  final List<String> _availableStatusesAlerts = [
    'Matched',
    'Unmatched',
    'Review Required',
    'Duplicate',
    'Ignored',
  ];

  final List<String> _availablePaymentTypes = [
    'Credit (Received)',
    'Debit (Sent)',
  ];

  List<String> get _categoriesList => [
        'Months',
        'Categories',
        'Instruments',
        'Payment status',
        'Payment types',
      ];

  @override
  void initState() {
    super.initState();
    _months = Set<String>.from(widget.initialState.selectedMonths);
    _categories = Set<String>.from(widget.initialState.selectedCategories);
    _instruments = Set<String>.from(widget.initialState.selectedInstruments);
    _statuses = Set<String>.from(widget.initialState.selectedStatuses);
    _types = Set<String>.from(widget.initialState.selectedPaymentTypes);
  }

  void _clearAll() {
    setState(() {
      _months.clear();
      _categories.clear();
      _instruments.clear();
      _statuses.clear();
      _types.clear();
    });
  }

  void _apply() {
    final result = PhonePeFilterState(
      selectedMonths: _months,
      selectedCategories: _categories,
      selectedInstruments: _instruments,
      selectedStatuses: _statuses,
      selectedPaymentTypes: _types,
    );
    Navigator.pop(context, result);
  }

  List<String> _getCurrentOptions() {
    switch (_activeCategoryIndex) {
      case 0:
        return _availableMonths;
      case 1:
        return _availableCategories;
      case 2:
        return _availableInstruments;
      case 3:
        return widget.isForAlerts ? _availableStatusesAlerts : _availableStatusesTransactions;
      case 4:
        return _availablePaymentTypes;
      default:
        return [];
    }
  }

  Set<String> _getCurrentSelectedSet() {
    switch (_activeCategoryIndex) {
      case 0:
        return _months;
      case 1:
        return _categories;
      case 2:
        return _instruments;
      case 3:
        return _statuses;
      case 4:
        return _types;
      default:
        return {};
    }
  }

  int _getCategoryCount(int index) {
    switch (index) {
      case 0:
        return _months.length;
      case 1:
        return _categories.length;
      case 2:
        return _instruments.length;
      case 3:
        return _statuses.length;
      case 4:
        return _types.length;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _months.length + _categories.length + _instruments.length + _statuses.length + _types.length;

    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFF121212), // Dark theme matching PhonePe screenshot
        appBar: AppBar(
          backgroundColor: const Color(0xFF181818),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Filters',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: activeCount > 0 ? _clearAll : null,
              child: Text(
                'Clear all',
                style: TextStyle(
                  color: activeCount > 0 ? Colors.white70 : Colors.white30,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const Divider(height: 1, color: Color(0xFF282828)),
            Expanded(
              child: Row(
                children: [
                  // Left Side Tabs Column (matching PhonePe screenshot)
                  Container(
                    width: 140,
                    color: const Color(0xFF1E1E1E),
                    child: ListView.builder(
                      itemCount: _categoriesList.length,
                      itemBuilder: (context, i) {
                        final isSelected = _activeCategoryIndex == i;
                        final count = _getCategoryCount(i);

                        return InkWell(
                          onTap: () => setState(() => _activeCategoryIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF121212) : const Color(0xFF1E1E1E),
                              border: Border(
                                left: BorderSide(
                                  color: isSelected ? const Color(0xFF5F259F) : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _categoriesList[i],
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (count > 0)
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF5F259F),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$count',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Vertical Divider
                  const VerticalDivider(width: 1, color: Color(0xFF282828)),

                  // Right Side Checkbox Options List
                  Expanded(
                    child: Container(
                      color: const Color(0xFF121212),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _getCurrentOptions().length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1E1E1E)),
                        itemBuilder: (context, idx) {
                          final option = _getCurrentOptions()[idx];
                          final selectedSet = _getCurrentSelectedSet();
                          final isChecked = selectedSet.contains(option);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isChecked) {
                                  selectedSet.remove(option);
                                } else {
                                  selectedSet.add(option);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: isChecked ? Colors.white : Colors.white70,
                                        fontSize: 14,
                                        fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isChecked ? const Color(0xFF5F259F) : Colors.white38,
                                        width: 1.5,
                                      ),
                                      color: isChecked ? const Color(0xFF5F259F) : Colors.transparent,
                                    ),
                                    child: isChecked
                                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Apply Action Bar (matching PhonePe screenshot)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF181818),
                border: Border(top: BorderSide(color: Color(0xFF282828))),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F259F), // PhonePe deep purple
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _apply,
                    child: Text(
                      activeCount > 0 ? 'Apply ($activeCount)' : 'Apply',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

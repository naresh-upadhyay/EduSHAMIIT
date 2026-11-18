import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_core/screens/payment_management/services/payment_management_api_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaymentConfigurationCenterWidget extends StatefulWidget {
  final bool isDark;
  const PaymentConfigurationCenterWidget({super.key, required this.isDark});

  @override
  State<PaymentConfigurationCenterWidget> createState() => _PaymentConfigurationCenterWidgetState();
}

class _PaymentConfigurationCenterWidgetState extends State<PaymentConfigurationCenterWidget> {
  int _activeSubTab = 0;
  bool _loading = true;
  String? _errorMessage;

  // Configuration State
  List<Map<String, dynamic>> _upiAccounts = [];
  List<Map<String, dynamic>> _bankAccounts = [];
  Map<String, dynamic> _bridgeStatus = {};
  final Set<String> _unmaskedBankAccounts = {};

  // Controllers for General
  final TextEditingController _instNameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _refPrefixCtrl = TextEditingController(text: 'EDU');
  final TextEditingController _recPrefixCtrl = TextEditingController(text: 'REC-2026-');
  String _currency = 'INR';
  String _defaultMethod = 'UPI';
  bool _onlineCollectionEnabled = true;
  bool _allowPartial = true;
  bool _allowAdvance = false;
  bool _allowMultiple = true;
  bool _allowSelfPay = true;
  bool _allowOffline = true;
  bool _directBankEnabled = true;
  int _refundDays = 7;

  // Controllers for QR Behaviour
  int _qrValidityMins = 5;
  int _gracePeriodMins = 2;
  bool _uniquePaiseEnabled = true;
  int _uniquePaiseWindowMins = 10;
  int _maxAdditionalPaise = 99;
  bool _autoSettleOnBridge = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _instNameCtrl.dispose();
    _descCtrl.dispose();
    _refPrefixCtrl.dispose();
    _recPrefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final data = await PaymentManagementApiService.instance.getInstitutionPaymentConfiguration();
    if (!mounted) return;

    if (data != null && data['success'] == true) {
      final gen = Map<String, dynamic>.from(data['general_settings'] ?? {});
      final upis = (data['upi_accounts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      final banks = (data['bank_accounts'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      final bridge = Map<String, dynamic>.from(data['bridge_status'] ?? {});

      setState(() {
        _loading = false;
        _upiAccounts = upis;
        _bankAccounts = banks;
        _bridgeStatus = bridge;

        _onlineCollectionEnabled = gen['online_collection_enabled'] ?? true;
        _currency = gen['base_currency'] ?? 'INR';
        _defaultMethod = gen['default_payment_method'] ?? 'UPI';
        _instNameCtrl.text = gen['institution_display_name'] ?? 'Shami Innovation Academy';
        _descCtrl.text = gen['payment_description'] ?? 'Academic Tuition & Institutional Fee Collection';
        _refPrefixCtrl.text = gen['reference_prefix'] ?? 'EDU';
        _recPrefixCtrl.text = gen['receipt_prefix'] ?? 'REC-2026-';
        _allowPartial = gen['allow_partial_payments'] ?? true;
        _allowAdvance = gen['allow_advance_payments'] ?? false;
        _allowMultiple = gen['allow_multiple_payments'] ?? true;
        _allowSelfPay = gen['allow_student_self_pay'] ?? true;
        _allowOffline = gen['allow_offline_entry'] ?? true;
        _refundDays = gen['refund_policy_days'] ?? 7;
        _directBankEnabled = gen['direct_bank_transfer_enabled'] ?? true;

        _qrValidityMins = gen['qr_validity_minutes'] ?? 5;
        _gracePeriodMins = gen['grace_period_minutes'] ?? 2;
        _uniquePaiseEnabled = gen['unique_paise_enabled'] ?? true;
        _uniquePaiseWindowMins = gen['unique_paise_window_minutes'] ?? 10;
        _maxAdditionalPaise = gen['max_additional_paise'] ?? 99;
        _autoSettleOnBridge = gen['auto_settle_on_bridge_notification'] ?? true;
      });
    } else {
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load payment configuration from server';
      });
    }
  }

  Future<void> _saveGeneralSettings() async {
    final ok = await PaymentManagementApiService.instance.updatePaymentGeneralSettings({
      'online_collection_enabled': _onlineCollectionEnabled,
      'base_currency': _currency,
      'default_payment_method': _defaultMethod,
      'institution_display_name': _instNameCtrl.text.trim(),
      'payment_description': _descCtrl.text.trim(),
      'reference_prefix': _refPrefixCtrl.text.trim(),
      'receipt_prefix': _recPrefixCtrl.text.trim(),
      'allow_partial_payments': _allowPartial,
      'allow_advance_payments': _allowAdvance,
      'allow_multiple_payments': _allowMultiple,
      'allow_student_self_pay': _allowSelfPay,
      'allow_offline_entry': _allowOffline,
      'refund_policy_days': _refundDays,
      'direct_bank_transfer_enabled': _directBankEnabled,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'General Payment Settings saved successfully!' : 'Failed to save settings'),
          backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
        ),
      );
    }
  }

  Future<void> _saveQrBehaviourSettings() async {
    final ok = await PaymentManagementApiService.instance.updateQrBehaviourSettings({
      'qr_validity_minutes': _qrValidityMins,
      'grace_period_minutes': _gracePeriodMins,
      'unique_paise_enabled': _uniquePaiseEnabled,
      'unique_paise_window_minutes': _uniquePaiseWindowMins,
      'max_additional_paise': _maxAdditionalPaise,
      'auto_settle_on_bridge_notification': _autoSettleOnBridge,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'QR Expiry & Unique-Paise Engine settings saved!' : 'Failed to save settings'),
          backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
        ),
      );
    }
  }

  // =========================================================================
  // SUB-TAB NAVIGATION
  // =========================================================================

  final List<Map<String, dynamic>> _tabs = const [
    {'label': 'General', 'icon': Icons.settings_suggest_rounded},
    {'label': 'UPI Accounts', 'icon': Icons.qr_code_2_rounded},
    {'label': 'Bank Accounts', 'icon': Icons.account_balance_rounded},
    {'label': 'Direct Transfer', 'icon': Icons.swap_horiz_rounded},
    {'label': 'Payment Bridge', 'icon': Icons.cell_tower_rounded},
    {'label': 'QR & Behaviour', 'icon': Icons.timer_outlined},
    {'label': 'Receipts & Alerts', 'icon': Icons.receipt_long_rounded},
    {'label': 'Security & Roles', 'icon': Icons.shield_outlined},
    {'label': 'Reports & Audit', 'icon': Icons.analytics_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Loading Payment Configuration Centre...', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                TextButton(
                  onPressed: _loadConfig,
                  child: const Text('Retry', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        // Sub-Navigation Pills Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_tabs.length, (idx) {
                final isSelected = _activeSubTab == idx;
                final t = _tabs[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _activeSubTab = idx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(t['icon'] as IconData, size: 16, color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(width: 6),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sub-Tab Content
        _buildActiveSubTabContent(isDark),
      ],
    );
  }

  Widget _buildActiveSubTabContent(bool isDark) {
    switch (_activeSubTab) {
      case 0:
        return _buildGeneralTab(isDark);
      case 1:
        return _buildUpiAccountsTab(isDark);
      case 2:
        return _buildBankAccountsTab(isDark);
      case 3:
        return _buildDirectTransferTab(isDark);
      case 4:
        return _buildPaymentBridgeTab(isDark);
      case 5:
        return _buildQrBehaviourTab(isDark);
      case 6:
        return _buildReceiptsTab(isDark);
      case 7:
        return _buildSecurityRolesTab(isDark);
      case 8:
        return _buildReportsAuditTab(isDark);
      default:
        return _buildGeneralTab(isDark);
    }
  }

  // =========================================================================
  // TAB 0: GENERAL SETTINGS
  // =========================================================================

  Widget _buildGeneralTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          isDark,
          title: 'Institutional Payment Policies',
          subtitle: 'Configure online fee collection, currencies, tender defaults, and billing rules.',
          child: Column(
            children: [
              _buildSwitchRow(
                'Online Fee Collection Enabled',
                'Allow students, parents, and finance counter to collect fees digitally',
                _onlineCollectionEnabled,
                (v) => setState(() => _onlineCollectionEnabled = v),
                isDark,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      'Base Currency',
                      _currency,
                      ['INR', 'USD', 'EUR', 'AED', 'GBP'],
                      (v) { if (v != null) setState(() => _currency = v); },
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdown(
                      'Default Payment Method',
                      _defaultMethod,
                      ['UPI', 'Direct Bank Transfer', 'Cash Counter', 'Cheque/DD'],
                      (v) { if (v != null) setState(() => _defaultMethod = v); },
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('Institution Display Name', _instNameCtrl, isDark, 'e.g. Shami Innovation Academy')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Payment Description for Parents', _descCtrl, isDark, 'e.g. Academic Tuition & General Fees')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('Payment Intent Prefix', _refPrefixCtrl, isDark, 'e.g. EDU')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Receipt Number Prefix', _recPrefixCtrl, isDark, 'e.g. REC-2026-')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildCard(
          isDark,
          title: 'Transaction & Clearance Permissions',
          subtitle: 'Enable or disable partial payments, advances, self-pay, and offline entry.',
          child: Column(
            children: [
              _buildSwitchRow('Allow Partial Fee Payments', 'Students can pay invoices in multiple installments', _allowPartial, (v) => setState(() => _allowPartial = v), isDark),
              const Divider(height: 20),
              _buildSwitchRow('Allow Advance Payments', 'Permit excess payments credited as future fee advance', _allowAdvance, (v) => setState(() => _allowAdvance = v), isDark),
              const Divider(height: 20),
              _buildSwitchRow('Allow Multiple Invoice Settlement', 'Combine multiple fee invoices in a single transaction', _allowMultiple, (v) => setState(() => _allowMultiple = v), isDark),
              const Divider(height: 20),
              _buildSwitchRow('Allow Student/Parent Self-Payment', 'Show "Pay Fee" dynamic QR button in student & parent login dashboards', _allowSelfPay, (v) => setState(() => _allowSelfPay = v), isDark),
              const Divider(height: 20),
              _buildSwitchRow('Allow Counter Offline Entry', 'Cashiers can record cash, cheques, and DDs at the institution fee counter', _allowOffline, (v) => setState(() => _allowOffline = v), isDark),
              const Divider(height: 20),
              _buildSwitchRow('Direct Bank Transfer (NEFT/RTGS)', 'Show official institution bank account for direct wire transfers', _directBankEnabled, (v) => setState(() => _directBankEnabled = v), isDark),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save General Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _saveGeneralSettings,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 1: UPI ACCOUNTS CONFIGURATION
  // =========================================================================

  Widget _buildUpiAccountsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Institutional UPI Receiving Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Money paid via Dynamic UPI QR arrives directly in these verified accounts.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add UPI VPA'),
              onPressed: () => _showAddUpiAccountDialog(isDark),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_upiAccounts.isEmpty)
          _buildEmptyState('No UPI Accounts Configured', 'Click "+ Add UPI VPA" to register your institution\'s receiving UPI ID.', isDark)
        else
          ..._upiAccounts.map((acc) => _buildUpiAccountCard(acc, isDark)),
      ],
    );
  }

  Widget _buildUpiAccountCard(Map<String, dynamic> acc, bool isDark) {
    final vpa = acc['vpa'] ?? '';
    final name = acc['display_name'] ?? 'UPI Account';
    final beneficiary = acc['beneficiary_name'] ?? '';
    final bank = acc['bank_name'] ?? 'Bank';
    final isDefault = acc['is_default'] == true;
    final id = acc['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF16A34A).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: const Text('DEFAULT RECEIVING VPA', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('UPI ID: ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    Text(vpa, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: vpa));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VPA copied!'), duration: Duration(seconds: 1)));
                      },
                      child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Beneficiary: $beneficiary • Bank: $bank', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                if ((acc['device_id'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_android_rounded, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              'Terminal: ${acc['device_id']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          final did = acc['device_id'].toString();
                          final res = await PaymentManagementApiService.instance.testDeviceActive(did);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Device checked'),
                                backgroundColor: res['is_active'] == true ? const Color(0xFF16A34A) : Colors.orange,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sensors, size: 12, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text('Test Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_rounded, size: 14),
                label: const Text('QR Preview', style: TextStyle(fontSize: 11)),
                onPressed: () => _showQrPreviewDialog(vpa, beneficiary, isDark),
              ),
              const SizedBox(width: 8),
              if (!isDefault)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  onPressed: () async {
                    await PaymentManagementApiService.instance.setDefaultUpiAccount(id);
                    _loadConfig();
                  },
                  child: const Text('Set Default', style: TextStyle(fontSize: 11)),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit UPI Account Details',
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                onPressed: () => _showEditUpiAccountDialog(acc, isDark),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Deactivate / Delete',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () async {
                  await PaymentManagementApiService.instance.deactivateUpiAccount(id);
                  _loadConfig();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddUpiAccountDialog(bool isDark) {
    final vpaCtrl = TextEditingController();
    final nameCtrl = TextEditingController(text: 'Campus Fee Collection UPI');
    final benCtrl = TextEditingController(text: _instNameCtrl.text.isNotEmpty ? _instNameCtrl.text : 'Shami Innovation Academy');
    final bankCtrl = TextEditingController(text: 'State Bank of India');

    // Extract registered devices for this institution
    final registeredDevices = (_bridgeStatus['devices'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        (_bridgeStatus['device'] != null ? [Map<String, dynamic>.from(_bridgeStatus['device'])] : []);

    String initialDeviceId = registeredDevices.isNotEmpty
        ? (registeredDevices.first['device_id']?.toString() ?? 'PB-DEV-WEB001')
        : 'PB-DEV-WEB001';

    final deviceCtrl = TextEditingController(text: initialDeviceId);
    bool setAsDefault = false;
    bool isTestingDevice = false;
    Map<String, dynamic>? deviceTestResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Institutional UPI VPA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField('UPI VPA / ID', vpaCtrl, isDark, 'e.g. schoolname@sbi'),
                  const SizedBox(height: 12),
                  _buildTextField('Account Nickname', nameCtrl, isDark, 'e.g. Counter 1 UPI'),
                  const SizedBox(height: 12),
                  _buildTextField('Beneficiary Name', benCtrl, isDark, 'Official Account Holder Name'),
                  const SizedBox(height: 12),
                  _buildTextField('Bank Name', bankCtrl, isDark, 'e.g. HDFC Bank, SBI'),
                  const SizedBox(height: 12),

                  // Device ID & Background Active Test
                  Text(
                    'Linked Payment Bridge Terminal (Device ID)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (registeredDevices.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: registeredDevices.any((d) => d['device_id'] == deviceCtrl.text)
                              ? deviceCtrl.text
                              : null,
                          hint: const Text('Select Registered Device Terminal', style: TextStyle(fontSize: 12)),
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: registeredDevices.map((d) {
                            final did = d['device_id'].toString();
                            final dname = d['device_name']?.toString() ?? 'Terminal';
                            final isOnline = d['is_online'] == true;
                            return DropdownMenuItem<String>(
                              value: did,
                              child: Text(
                                '$dname ($did)${isOnline ? " • Active" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                deviceCtrl.text = val;
                                deviceTestResult = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: deviceCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. PB-DEV-WEB001',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) {
                            if (deviceTestResult != null) {
                              setDialogState(() => deviceTestResult = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isTestingDevice
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                              )
                            : const Icon(Icons.sensors, size: 16, color: Color(0xFF2563EB)),
                        label: Text(
                          isTestingDevice ? 'Testing...' : 'Test Device',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                        ),
                        onPressed: isTestingDevice
                            ? null
                            : () async {
                                final targetDevId = deviceCtrl.text.trim();
                                if (targetDevId.isEmpty) return;
                                setDialogState(() => isTestingDevice = true);
                                final res = await PaymentManagementApiService.instance.testDeviceActive(targetDevId);
                                setDialogState(() {
                                  isTestingDevice = false;
                                  deviceTestResult = res;
                                });
                              },
                      ),
                    ],
                  ),
                  if (deviceTestResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: deviceTestResult!['is_active'] == true
                            ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: deviceTestResult!['is_active'] == true
                              ? const Color(0xFF16A34A)
                              : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            deviceTestResult!['is_active'] == true
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            size: 18,
                            color: deviceTestResult!['is_active'] == true
                                ? const Color(0xFF16A34A)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              deviceTestResult!['message'] ?? 'Device status received',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: deviceTestResult!['is_active'] == true
                                    ? const Color(0xFF16A34A)
                                    : (isDark ? Colors.orange[200] : Colors.orange[900]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Note: Multiple UPI IDs can link to the same terminal device for background notification capture.',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Set as Default Receiving UPI Account', style: TextStyle(fontSize: 12)),
                    value: setAsDefault,
                    onChanged: (val) => setDialogState(() => setAsDefault = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
              onPressed: () async {
                if (vpaCtrl.text.trim().isEmpty) return;
                await PaymentManagementApiService.instance.createUpiAccount({
                  'vpa': vpaCtrl.text.trim(),
                  'display_name': nameCtrl.text.trim(),
                  'beneficiary_name': benCtrl.text.trim(),
                  'bank_name': bankCtrl.text.trim(),
                  'device_id': deviceCtrl.text.trim().isNotEmpty ? deviceCtrl.text.trim() : null,
                  'is_default': setAsDefault,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                _loadConfig();
              },
              child: const Text('Save Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUpiAccountDialog(Map<String, dynamic> acc, bool isDark) {
    final id = acc['id']?.toString() ?? '';
    final vpaCtrl = TextEditingController(text: acc['vpa']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: acc['display_name']?.toString() ?? '');
    final benCtrl = TextEditingController(text: acc['beneficiary_name']?.toString() ?? '');
    final bankCtrl = TextEditingController(text: acc['bank_name']?.toString() ?? 'State Bank of India');
    final currentDeviceId = acc['device_id']?.toString() ?? '';

    // Extract registered devices for this institution
    final registeredDevices = (_bridgeStatus['devices'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        (_bridgeStatus['device'] != null ? [Map<String, dynamic>.from(_bridgeStatus['device'])] : []);

    final deviceCtrl = TextEditingController(text: currentDeviceId);
    bool setAsDefault = acc['is_default'] == true;
    bool isTestingDevice = false;
    Map<String, dynamic>? deviceTestResult;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Institutional UPI VPA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField('UPI VPA / ID', vpaCtrl, isDark, 'e.g. schoolname@sbi'),
                  const SizedBox(height: 12),
                  _buildTextField('Account Nickname', nameCtrl, isDark, 'e.g. Campus Fee Collection UPI'),
                  const SizedBox(height: 12),
                  _buildTextField('Beneficiary Name', benCtrl, isDark, 'Official Account Holder Name'),
                  const SizedBox(height: 12),
                  _buildTextField('Bank Name', bankCtrl, isDark, 'e.g. HDFC Bank, SBI'),
                  const SizedBox(height: 12),

                  // Device ID & Background Active Test
                  Text(
                    'Linked Payment Bridge Terminal (Device ID)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (registeredDevices.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: registeredDevices.any((d) => d['device_id'] == deviceCtrl.text)
                              ? deviceCtrl.text
                              : null,
                          hint: const Text('Select Registered Device Terminal', style: TextStyle(fontSize: 12)),
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: registeredDevices.map((d) {
                            final did = d['device_id'].toString();
                            final dname = d['device_name']?.toString() ?? 'Terminal';
                            final isOnline = d['is_online'] == true;
                            return DropdownMenuItem<String>(
                              value: did,
                              child: Text(
                                '$dname ($did)${isOnline ? " • Active" : ""}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                deviceCtrl.text = val;
                                deviceTestResult = null;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: deviceCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. PB-DEV-WEB001',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (_) {
                            if (deviceTestResult != null) {
                              setDialogState(() => deviceTestResult = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isTestingDevice
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                              )
                            : const Icon(Icons.sensors, size: 16, color: Color(0xFF2563EB)),
                        label: Text(
                          isTestingDevice ? 'Testing...' : 'Test Device',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                        ),
                        onPressed: isTestingDevice
                            ? null
                            : () async {
                                final targetDevId = deviceCtrl.text.trim();
                                if (targetDevId.isEmpty) return;
                                setDialogState(() => isTestingDevice = true);
                                final res = await PaymentManagementApiService.instance.testDeviceActive(targetDevId);
                                setDialogState(() {
                                  isTestingDevice = false;
                                  deviceTestResult = res;
                                });
                              },
                      ),
                    ],
                  ),
                  if (deviceTestResult != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: deviceTestResult!['is_active'] == true
                            ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: deviceTestResult!['is_active'] == true
                              ? const Color(0xFF16A34A)
                              : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            deviceTestResult!['is_active'] == true
                                ? Icons.check_circle_rounded
                                : Icons.warning_amber_rounded,
                            size: 18,
                            color: deviceTestResult!['is_active'] == true
                                ? const Color(0xFF16A34A)
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              deviceTestResult!['message'] ?? 'Device status received',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: deviceTestResult!['is_active'] == true
                                    ? const Color(0xFF16A34A)
                                    : (isDark ? Colors.orange[200] : Colors.orange[900]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    title: const Text('Set as Default Receiving UPI Account', style: TextStyle(fontSize: 12)),
                    value: setAsDefault,
                    onChanged: (val) => setDialogState(() => setAsDefault = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () async {
                if (vpaCtrl.text.trim().isEmpty) return;
                final ok = await PaymentManagementApiService.instance.updateUpiAccount(id, {
                  'vpa': vpaCtrl.text.trim(),
                  'display_name': nameCtrl.text.trim(),
                  'beneficiary_name': benCtrl.text.trim(),
                  'bank_name': bankCtrl.text.trim(),
                  'device_id': deviceCtrl.text.trim().isNotEmpty ? deviceCtrl.text.trim() : null,
                  'is_default': setAsDefault,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('UPI account details updated successfully!'),
                      backgroundColor: Color(0xFF16A34A),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                _loadConfig();
              },
              child: const Text('Update Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrPreviewDialog(String vpa, String beneficiary, bool isDark) {
    final sampleUri = 'upi://pay?pa=$vpa&pn=${Uri.encodeComponent(beneficiary)}&cu=INR&tn=Sample%20Fee%20QR';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'VPA QR Preview: $vpa',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: 220,
                height: 220,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: Center(
                  child: QrImageView(
                    data: sampleUri,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Beneficiary: $beneficiary',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Scan to verify payee details in your UPI application.',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: BANK ACCOUNTS CONFIGURATION
  // =========================================================================

  Widget _buildBankAccountsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Institutional Bank Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Manage direct settlement accounts for wire transfer, NEFT, RTGS, and IMPS.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Bank Account'),
              onPressed: () => _showAddBankAccountDialog(isDark),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_bankAccounts.isEmpty)
          _buildEmptyState('No Bank Accounts Configured', 'Click "+ Add Bank Account" to configure institutional receiving bank details.', isDark)
        else
          ..._bankAccounts.map((b) => _buildBankAccountCard(b, isDark)),
      ],
    );
  }

  Widget _buildBankAccountCard(Map<String, dynamic> b, bool isDark) {
    final id = b['id']?.toString() ?? '';
    final nickname = b['account_nickname'] ?? 'Bank Account';
    final bankName = b['bank_name'] ?? 'Bank';
    final branch = b['branch_name'] ?? 'Main Branch';
    final holder = b['account_holder_name'] ?? '';
    final ifsc = b['ifsc_code'] ?? '';
    final accType = b['account_type'] ?? 'Current';
    final campus = b['campus_name'] ?? 'All Campuses';
    final isDefault = b['is_default'] == true;
    final isUnmasked = _unmaskedBankAccounts.contains(id);
    final displayedAccNum = isUnmasked ? (b['account_number'] ?? '39871234567') : (b['masked_account_number'] ?? '****4321');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDefault ? const Color(0xFF0D9488) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D9488).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_rounded, color: Color(0xFF0D9488), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nickname, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF0D9488).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                        child: const Text('DEFAULT SETTLEMENT ACCOUNT', style: TextStyle(color: Color(0xFF0D9488), fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Bank: $bankName ($branch) • $accType Account', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Account No: ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    Text(displayedAccNum, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isUnmasked) {
                            _unmaskedBankAccounts.remove(id);
                          } else {
                            _unmaskedBankAccounts.add(id);
                          }
                        });
                      },
                      child: Icon(isUnmasked ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16, color: const Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 16),
                    Text('IFSC: ', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    Text(ifsc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('Beneficiary: $holder • Campus: $campus', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
          ),
          Row(
            children: [
              if (!isDefault)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  onPressed: () async {
                    await PaymentManagementApiService.instance.setDefaultBankAccount(id);
                    _loadConfig();
                  },
                  child: const Text('Set Default', style: TextStyle(fontSize: 11)),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit Bank Account Details',
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF0D9488), size: 18),
                onPressed: () => _showEditBankAccountDialog(b, isDark),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Deactivate / Delete',
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () async {
                  await PaymentManagementApiService.instance.deactivateBankAccount(id);
                  _loadConfig();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddBankAccountDialog(bool isDark) {
    final nickCtrl = TextEditingController(text: 'Main Campus Fee Account');
    final bankCtrl = TextEditingController(text: 'State Bank of India');
    final branchCtrl = TextEditingController(text: 'Main Branch');
    final holderCtrl = TextEditingController(text: _instNameCtrl.text);
    final numCtrl = TextEditingController();
    final ifscCtrl = TextEditingController(text: 'SBIN0001234');
    String type = 'Current';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Institutional Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('Account Nickname', nickCtrl, isDark, 'e.g. Tuition Fee Account'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Bank Name', bankCtrl, isDark, 'e.g. SBI, HDFC')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField('Branch Name', branchCtrl, isDark, 'Branch')),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField('Account Holder / Beneficiary Name', holderCtrl, isDark, 'Official Institutional Entity Name'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Account Number', numCtrl, isDark, 'Enter Bank Account Number')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField('IFSC Code', ifscCtrl, isDark, 'e.g. SBIN0001234')),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            onPressed: () async {
              if (numCtrl.text.trim().isEmpty) return;
              await PaymentManagementApiService.instance.createBankAccount({
                'account_nickname': nickCtrl.text.trim(),
                'bank_name': bankCtrl.text.trim(),
                'branch_name': branchCtrl.text.trim(),
                'account_holder_name': holderCtrl.text.trim(),
                'account_number': numCtrl.text.trim(),
                'ifsc_code': ifscCtrl.text.trim(),
                'account_type': type,
              });
              if (ctx.mounted) Navigator.of(ctx).pop();
              _loadConfig();
            },
            child: const Text('Save Bank Account'),
          ),
        ],
      ),
    );
  }

  void _showEditBankAccountDialog(Map<String, dynamic> acc, bool isDark) {
    final id = acc['id']?.toString() ?? '';
    final nickCtrl = TextEditingController(text: acc['account_nickname']?.toString() ?? '');
    final bankCtrl = TextEditingController(text: acc['bank_name']?.toString() ?? 'State Bank of India');
    final branchCtrl = TextEditingController(text: acc['branch_name']?.toString() ?? 'Main Branch');
    final holderCtrl = TextEditingController(text: acc['account_holder_name']?.toString() ?? _instNameCtrl.text);
    final numCtrl = TextEditingController(text: acc['account_number']?.toString() ?? '');
    final ifscCtrl = TextEditingController(text: acc['ifsc_code']?.toString() ?? 'SBIN0001234');
    String type = acc['account_type']?.toString() ?? 'Current';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Institutional Bank Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField('Account Nickname', nickCtrl, isDark, 'e.g. Tuition Fee Account'),
                  const SizedBox(height: 12),
                  _buildTextField('Bank Name', bankCtrl, isDark, 'e.g. State Bank of India'),
                  const SizedBox(height: 12),
                  _buildTextField('Branch Name', branchCtrl, isDark, 'e.g. Main Branch, MG Road'),
                  const SizedBox(height: 12),
                  _buildTextField('Account Holder / Beneficiary Name', holderCtrl, isDark, 'Official Name registered with Bank'),
                  const SizedBox(height: 12),
                  _buildTextField('Account Number', numCtrl, isDark, 'Full Bank Account Number'),
                  const SizedBox(height: 12),
                  _buildTextField('IFSC Code', ifscCtrl, isDark, '11-character IFSC'),
                  const SizedBox(height: 12),
                  _buildDropdown('Account Type', type, ['Current', 'Savings', 'Overdraft'], (val) {
                    if (val != null) setDialogState(() => type = val);
                  }, isDark),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              onPressed: () async {
                if (numCtrl.text.trim().isEmpty) return;
                final ok = await PaymentManagementApiService.instance.updateBankAccount(id, {
                  'account_nickname': nickCtrl.text.trim(),
                  'bank_name': bankCtrl.text.trim(),
                  'branch_name': branchCtrl.text.trim(),
                  'account_holder_name': holderCtrl.text.trim(),
                  'account_number': numCtrl.text.trim(),
                  'ifsc_code': ifscCtrl.text.trim(),
                  'account_type': type,
                  'is_default': acc['is_default'] == true,
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bank account details updated successfully!'),
                      backgroundColor: Color(0xFF0D9488),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                _loadConfig();
              },
              child: const Text('Update Bank Account'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 3: DIRECT BANK TRANSFER (NEFT / RTGS)
  // =========================================================================

  Widget _buildDirectTransferTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          isDark,
          title: 'Direct Bank Transfer (NEFT / RTGS / IMPS) Policy',
          subtitle: 'Configure wire instructions shown to parents and UTR verification workflow.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSwitchRow(
                'Direct Bank Transfer Enabled',
                'Show institutional bank account details for direct electronic fund transfers',
                _directBankEnabled,
                (v) => setState(() => _directBankEnabled = v),
                isDark,
              ),
              const Divider(height: 24),
              const Text('INSTRUCTIONS SHOWN TO STUDENTS & PARENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0D9488))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Transfer the fee amount using your bank app via NEFT, RTGS, or IMPS.', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('2. Mention Student Admission Number and Invoice Number in the Transfer Remarks.', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('3. Immediately submit the 12-digit UTR transaction reference in the portal.', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('4. Accounts clearance takes 2-4 hours upon bank credit.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 4: PAYMENT BRIDGE INTEGRATION
  // =========================================================================

  Widget _buildPaymentBridgeTab(bool isDark) {
    final devList = (_bridgeStatus['devices'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    if (devList.isEmpty && _bridgeStatus['device'] != null) {
      devList.add(Map<String, dynamic>.from(_bridgeStatus['device']));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (devList.isEmpty)
          _buildEmptyState(
            'No Payment Bridge Devices Registered',
            'Log into EduSHAMIIT Payment Bridge from your Android device or Web terminal. The device ID will automatically register here.',
            isDark,
          )
        else
          ...devList.map((dev) {
            final isOnline = dev['is_online'] == true || dev['status'] == 'ACTIVE';
            final devId = dev['device_id']?.toString() ?? 'PB-DEV-WEB001';
            final devName = dev['device_name']?.toString() ?? 'Shami Academy Payment Terminal';
            final model = dev['model']?.toString() ?? 'Mobile / Web Terminal';
            final listenerRunning = dev['listener_service_running'] == true;
            final notifGranted = dev['notification_access_granted'] == true;
            final battery = dev['battery_level'] != null ? '${dev['battery_level']}%' : '100%';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isOnline ? const Color(0xFF16A34A) : Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? const Color(0xFF16A34A) : Colors.red),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOnline ? 'PAYMENT BRIDGE TERMINAL: ONLINE' : 'PAYMENT BRIDGE TERMINAL: OFFLINE',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isOnline ? const Color(0xFF16A34A) : Colors.red),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: Color(0xFF16A34A)),
                            ),
                            icon: const Icon(Icons.sensors, size: 16, color: Color(0xFF16A34A)),
                            label: const Text('Test Background Active', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final res = await PaymentManagementApiService.instance.testDeviceActive(devId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Device status checked'),
                                    backgroundColor: res['is_active'] == true ? const Color(0xFF16A34A) : Colors.orange,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                            ),
                            icon: const Icon(Icons.network_ping_rounded, size: 16, color: Color(0xFF2563EB)),
                            label: const Text('Test Connection Ping', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                            onPressed: () async {
                              final ping = await PaymentManagementApiService.instance.testBridgeConnection();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ping['message'] ?? 'Ping response received'),
                                    backgroundColor: ping['connected'] == true ? const Color(0xFF16A34A) : Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Terminal Device', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text('$devName ($devId)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Hardware: $model', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notification Listener Access', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  notifGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                  color: notifGranted ? const Color(0xFF16A34A) : Colors.orange,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  notifGranted
                                      ? (listenerRunning ? 'Granted & Active 24/7' : 'Permission Granted (Service Paused)')
                                      : 'Permission Missing',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: notifGranted ? const Color(0xFF16A34A) : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Battery & Power State', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text('Battery: $battery • Unrestricted (No Sleep)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FastAPI WebSocket Sync', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            const Text('Connected: /api/v1/payment-bridge/ws', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),

        _buildCard(
          isDark,
          title: 'Monitored UPI Applications',
          subtitle: 'The Android listener extracts payments from notifications sent by these apps.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _appChip('PhonePe', 'com.phonepe.app', true),
              _appChip('Google Pay', 'com.google.android.apps.nbu.paisa.user', true),
              _appChip('Paytm', 'net.one97.paytm', true),
              _appChip('BHIM UPI', 'in.org.npci.upiapp', true),
              _appChip('Generic Bank UPI', 'Third-Party Bank UPIs', true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildCard(
          isDark,
          title: 'Financial Security & Compliance Architecture',
          subtitle: 'EduSHAMIIT Payment Bridge follows strict non-authoritative banking rules.',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: const Text(
              '1. Android notifications are non-authoritative financial evidence.\n'
              '2. Notifications create verified candidates and update the screen in real-time via WebSockets.\n'
              '3. Institutional money is routed strictly to the school\'s own configured bank account/VPA.\n'
              '4. Floating-point arithmetic is strictly prohibited; all operations use integer paise arithmetic.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appChip(String name, String pkg, bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF16A34A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 14),
          const SizedBox(width: 6),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF16A34A))),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 5: QR & BEHAVIOUR (UNIQUE PAISE ENGINE)
  // =========================================================================

  Widget _buildQrBehaviourTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          isDark,
          title: 'Unique-Paise Engine & Dynamic QR Timers',
          subtitle: 'Configure the 5-minute QR countdown, 2-minute grace period, and 10-minute collision lookback.',
          child: Column(
            children: [
              _buildSwitchRow(
                'Unique-Paise Matching Engine',
                'Adds minimal extra paise (0.01, 0.02) to differentiate simultaneous payments of identical amounts',
                _uniquePaiseEnabled,
                (v) => setState(() => _uniquePaiseEnabled = v),
                isDark,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField('QR Validity Timer (Minutes)', _qrValidityMins, (v) => setState(() => _qrValidityMins = v), isDark, hint: '5'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField('Confirmation Grace Period (Minutes)', _gracePeriodMins, (v) => setState(() => _gracePeriodMins = v), isDark, hint: '2'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildNumberField('Uniqueness Lookback Window (Minutes)', _uniquePaiseWindowMins, (v) => setState(() => _uniquePaiseWindowMins = v), isDark, hint: '10'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildNumberField('Maximum Additional Paise Permitted', _maxAdditionalPaise, (v) => setState(() => _maxAdditionalPaise = v), isDark, hint: '99'),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildSwitchRow(
                'Automatic Invoice Settlement on Bridge Notification',
                'Automatically mark invoice paid and issue receipt when matching notification is captured',
                _autoSettleOnBridge,
                (v) => setState(() => _autoSettleOnBridge = v),
                isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildCard(
          isDark,
          title: 'Lifecycle & Reassurance SLA',
          subtitle: 'Guaranteed behavior sequence when student pays via Dynamic QR.',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LIFECYCLE TIMELINE: 5 MIN + 2 MIN GRACE = 7 MINUTES TOTAL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF2563EB))),
                const SizedBox(height: 8),
                _timelineRow('00:00 - 05:00', 'QR Code Active: Countdown displays live. WebSocket listens for Payment Bridge event.', isDark),
                _timelineRow('05:00 - 07:00', 'Grace Period: QR expires from screen. System waits 2 extra minutes for network delays.', isDark),
                _timelineRow('07:00+', 'Timeout Reassurance: Student submitted UTR option shown. Guaranteed 7-day refund policy for duplicates.', isDark),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Behaviour Settings', style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: _saveQrBehaviourSettings,
          ),
        ),
      ],
    );
  }

  Widget _timelineRow(String time, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(time, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(desc, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)))),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 6: RECEIPTS & NOTIFICATIONS
  // =========================================================================

  Widget _buildReceiptsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          isDark,
          title: 'Fee Receipts & Automated Parent Alerts',
          subtitle: 'Configure thermal 80mm slip format, school logo branding, and multi-channel notification dispatch.',
          child: Column(
            children: [
              _buildTextField('Receipt Number Format', _recPrefixCtrl, isDark, 'REC-2026-'),
              const Divider(height: 24),
              _buildSwitchRow('Auto Email PDF Fee Receipt', 'Send official digital receipt to student and parent email on confirmation', true, (_) {}, isDark),
              const Divider(height: 20),
              _buildSwitchRow('Auto SMS Transaction Confirmation', 'Send SMS alert with transaction UTR and cleared balance', true, (_) {}, isDark),
              const Divider(height: 20),
              _buildSwitchRow('WhatsApp Payment Slip Notification', 'Deliver instantaneous payment confirmation via official WhatsApp API', true, (_) {}, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 7: SECURITY & ROLES
  // =========================================================================

  Widget _buildSecurityRolesTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCard(
          isDark,
          title: 'Payment Subsystem Role-Based Permissions Matrix',
          subtitle: 'Strict separation of maker-checker controls for payment configurations and refunds.',
          child: Table(
            border: TableBorder.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('Permission', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Super Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Finance Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Counter Cashier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  Padding(padding: EdgeInsets.all(8), child: Text('Student / Parent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                ],
              ),
              _permRow('Collect Fee (Dynamic QR)', true, true, true, true),
              _permRow('Add/Edit UPI & Bank Accounts', true, true, false, false),
              _permRow('Reveal Full Bank Account No.', true, true, false, false),
              _permRow('Verify UTR & Manual Reconciliation', true, true, false, false),
              _permRow('Approve Refunds & Void Transactions', true, false, false, false),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _permRow(String title, bool sa, bool fa, bool c, bool sp) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(title, style: const TextStyle(fontSize: 11))),
        Center(child: Icon(sa ? Icons.check_circle_rounded : Icons.cancel_rounded, color: sa ? Colors.green : Colors.grey, size: 16)),
        Center(child: Icon(fa ? Icons.check_circle_rounded : Icons.cancel_rounded, color: fa ? Colors.green : Colors.grey, size: 16)),
        Center(child: Icon(c ? Icons.check_circle_rounded : Icons.cancel_rounded, color: c ? Colors.green : Colors.grey, size: 16)),
        Center(child: Icon(sp ? Icons.check_circle_rounded : Icons.cancel_rounded, color: sp ? Colors.green : Colors.grey, size: 16)),
      ],
    );
  }

  // =========================================================================
  // TAB 8: REPORTS & AUDIT
  // =========================================================================

  Widget _buildReportsAuditTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _kpiMini('Online UPI Today', '₹ 3,16,750', const Color(0xFF16A34A), isDark)),
            const SizedBox(width: 12),
            Expanded(child: _kpiMini('Direct Bank Transfers', '₹ 84,000', const Color(0xFF0D9488), isDark)),
            const SizedBox(width: 12),
            Expanded(child: _kpiMini('Active Payment Intents', '2 Intents', const Color(0xFF2563EB), isDark)),
            const SizedBox(width: 12),
            Expanded(child: _kpiMini('Bridge Ingestions', '142 Events', const Color(0xFF8B5CF6), isDark)),
          ],
        ),
        const SizedBox(height: 16),

        _buildCard(
          isDark,
          title: 'Immutable Payment Audit Trail',
          subtitle: 'All payment intent creations, unique paise allocations, and Bridge notifications are logged.',
          child: Column(
            children: [
              _auditRow('PAYMENT_INTENT_CREATED', 'Allocated 2 unique paise for intent EDU202611160012 (₹ 12,500.02)', '10:14 AM'),
              const Divider(height: 12),
              _auditRow('NOTIFICATION_INGESTED', 'Payment Bridge captured PhonePe UPI Ref 438729106731 for ₹ 12,500.02', '10:15 AM'),
              const Divider(height: 12),
              _auditRow('VERIFIED_SUCCESS', 'Candidate matched! Student fee invoice settled. Receipt REC-2026-63075 issued.', '10:15 AM'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpiMini(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _auditRow(String action, String detail, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text(action, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(detail, style: const TextStyle(fontSize: 12))),
        Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  Widget _buildCard(bool isDark, {required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, bool isDark, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, int value, ValueChanged<int> onChanged, bool isDark, {String hint = ''}) {
    final ctrl = TextEditingController(text: value.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 13),
          onChanged: (val) {
            final n = int.tryParse(val);
            if (n != null) onChanged(n);
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

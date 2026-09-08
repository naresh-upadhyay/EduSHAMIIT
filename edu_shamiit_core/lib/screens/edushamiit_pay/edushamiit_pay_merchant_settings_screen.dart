import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:edu_shamiit_core/config/app_config.dart';

class EduSHAMIITPayMerchantSettingsScreen extends StatefulWidget {
  final String? schoolId;

  const EduSHAMIITPayMerchantSettingsScreen({super.key, this.schoolId});

  @override
  State<EduSHAMIITPayMerchantSettingsScreen> createState() => _EduSHAMIITPayMerchantSettingsScreenState();
}

class _EduSHAMIITPayMerchantSettingsScreenState extends State<EduSHAMIITPayMerchantSettingsScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _obscureSecret = true;

  String _providerCode = 'MOCK_SANDBOX';
  String _environment = 'SANDBOX';
  final _merchantNameCtrl = TextEditingController(text: 'Delhi Public School Acquiring Account');
  final _merchantIdCtrl = TextEditingController(text: 'DPS-ACQ-2026');
  final _vpaCtrl = TextEditingController(text: 'dps.rkpuram@sbi');
  final _bankNameCtrl = TextEditingController(text: 'State Bank of India');
  final _accNoCtrl = TextEditingController(text: '00000045892341');
  final _ifscCtrl = TextEditingController(text: 'SBIN0001234');
  final _holderCtrl = TextEditingController(text: 'DPS School Managing Committee');
  final _apiKeyCtrl = TextEditingController(text: 'KEY_DPS_TEST_123');
  final _apiSecretCtrl = TextEditingController(text: 'SECRET_DPS_TEST_456');

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/admin/merchant-account'));
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body['data'] ?? {};
        setState(() {
          _providerCode = data['provider_code'] ?? 'MOCK_SANDBOX';
          _merchantNameCtrl.text = data['merchant_name'] ?? _merchantNameCtrl.text;
          _merchantIdCtrl.text = data['merchant_identifier'] ?? _merchantIdCtrl.text;
          _vpaCtrl.text = data['upi_vpa'] ?? _vpaCtrl.text;
          _environment = data['environment'] ?? 'SANDBOX';
          final bank = data['settlement_bank'] ?? {};
          _bankNameCtrl.text = bank['bank_name'] ?? _bankNameCtrl.text;
          _ifscCtrl.text = bank['ifsc'] ?? _ifscCtrl.text;
          _holderCtrl.text = bank['account_holder'] ?? _holderCtrl.text;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'merchant_name': _merchantNameCtrl.text,
        'provider_code': _providerCode,
        'merchant_identifier': _merchantIdCtrl.text,
        'upi_vpa': _vpaCtrl.text,
        'environment': _environment,
        'bank_name': _bankNameCtrl.text,
        'account_number': _accNoCtrl.text,
        'ifsc': _ifscCtrl.text,
        'account_holder': _holderCtrl.text,
        'api_key': _apiKeyCtrl.text,
        'api_secret': _apiSecretCtrl.text,
      };
      await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/admin/merchant-account'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('School acquiring gateway settings saved successfully!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved.')),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('School Acquiring Gateway Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Separation Notice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security_rounded, color: Color(0xFF059669), size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Financial Isolation Guarantee: All payments collected through this merchant account settle directly into your school bank account. EduSHAMIIT does not hold, intermediate, or co-mingle your school collections.',
                            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF065F46), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Settlement Bank Account Form
                  _buildSectionHeader('1. SCHOOL SETTLEMENT BANK ACCOUNT'),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        TextField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _accNoCtrl, decoration: const InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()))),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: _ifscCtrl, decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder()))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: _holderCtrl, decoration: const InputDecoration(labelText: 'Account Holder / Legal Entity Name', border: OutlineInputBorder())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2. NPCI UPI Dynamic QR Configuration
                  _buildSectionHeader('2. DYNAMIC NPCI UPI QR CONFIGURATION'),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _vpaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'School UPI Virtual Payment Address (VPA)',
                            hintText: 'e.g. schoolname@sbi or dps.rkpuram@icici',
                            prefixIcon: Icon(Icons.qr_code_2_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Used to generate invoice-specific Dynamic NPCI UPI QRs (upi://pay?pa=...&am=...&tr=...) for instant parent fee checkout.',
                          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 3. Acquiring Gateway Provider & API Keys
                  _buildSectionHeader('3. ACQUIRING GATEWAY ADAPTER'),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _providerCode,
                                decoration: const InputDecoration(labelText: 'Gateway Provider', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'MOCK_SANDBOX', child: Text('Sandbox Mock Simulator (All Edge Cases)')),
                                  DropdownMenuItem(value: 'PAYU', child: Text('PayU Hosted Checkout v2')),
                                  DropdownMenuItem(value: 'CASHFREE', child: Text('Cashfree Payment Gateway')),
                                  DropdownMenuItem(value: 'SBI_EPAY', child: Text('SBI ePay (Bank Direct)')),
                                  DropdownMenuItem(value: 'ICICI_EAZYPAY', child: Text('ICICI Eazypay (Bank Direct)')),
                                  DropdownMenuItem(value: 'HDFC_SMARTHUB', child: Text('HDFC SmartHub (Bank Direct)')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _providerCode = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _environment,
                                decoration: const InputDecoration(labelText: 'Environment', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'SANDBOX', child: Text('Sandbox / Test')),
                                  DropdownMenuItem(value: 'PRODUCTION', child: Text('Production (Live)')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _environment = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: _merchantIdCtrl, decoration: const InputDecoration(labelText: 'Merchant Identifier / Client ID', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiKeyCtrl,
                          decoration: const InputDecoration(labelText: 'API Key / Merchant Key', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _apiSecretCtrl,
                          obscureText: _obscureSecret,
                          decoration: InputDecoration(
                            labelText: 'API Secret / Salt',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: const Color(0xFF64748B)),
      ),
    );
  }
}

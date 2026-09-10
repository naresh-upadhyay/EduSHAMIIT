import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/config/app_config.dart';

class PaymentGatewaySettingsScreen extends StatefulWidget {
  final String? authToken;

  const PaymentGatewaySettingsScreen({super.key, this.authToken});

  @override
  State<PaymentGatewaySettingsScreen> createState() => _PaymentGatewaySettingsScreenState();
}

class _PaymentGatewaySettingsScreenState extends State<PaymentGatewaySettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _environment = 'TEST'; // 'TEST' or 'PRODUCTION'
  final _merchantKeyController = TextEditingController();
  final _merchantSecretController = TextEditingController();
  final _saltController = TextEditingController();
  final _webhookSecretController = TextEditingController();
  bool _isEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _merchantKeyController.dispose();
    _merchantSecretController.dispose();
    _saltController.dispose();
    _webhookSecretController.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/settings/payu'),
        headers: {
          if (widget.authToken != null) 'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? {};
        setState(() {
          _environment = data['environment'] ?? 'TEST';
          _merchantKeyController.text = data['merchant_key'] ?? '';
          _isEnabled = data['is_enabled'] ?? true;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching gateway settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'environment': _environment,
        'merchant_key': _merchantKeyController.text.trim(),
        'merchant_secret': _merchantSecretController.text.trim(),
        'salt': _saltController.text.trim(),
        'webhook_secret': _webhookSecretController.text.trim(),
        'is_enabled': _isEnabled,
      };

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/payments/settings/payu'),
        headers: {
          'Content-Type': 'application/json',
          if (widget.authToken != null) 'Authorization': 'Bearer ${widget.authToken}',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PayU Payment Gateway configuration saved securely.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchSettings();
      } else {
        final body = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['detail'] ?? 'Failed to save configuration.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving gateway configuration.')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'PayU Payment Gateway Settings',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 640),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payment_outlined, color: Color(0xFF6366F1)),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PayU v2 Non-Seamless Integration',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Manage PayU credentials securely. Secrets are write-only.',
                                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 36),

                      // Environment Toggle
                      Text('Environment', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'TEST', label: Text('TEST / SANDBOX')),
                          ButtonSegment(value: 'PRODUCTION', label: Text('PRODUCTION')),
                        ],
                        selected: {_environment},
                        onSelectionChanged: (set) {
                          setState(() => _environment = set.first);
                        },
                      ),
                      const SizedBox(height: 20),

                      // Merchant Key
                      _buildTextField(_merchantKeyController, 'Merchant Key', 'Enter PayU Merchant Key / Account ID'),
                      const SizedBox(height: 16),

                      // Merchant Secret
                      _buildTextField(_merchantSecretController, 'Merchant Secret', 'Enter PayU Merchant Secret (Write-Only)', obscureText: true),
                      const SizedBox(height: 16),

                      // Salt
                      _buildTextField(_saltController, 'Merchant Salt', 'Enter PayU Salt Key', obscureText: true),
                      const SizedBox(height: 16),

                      // Webhook Secret
                      _buildTextField(_webhookSecretController, 'Webhook Secret', 'Enter Webhook Hash Secret'),
                      const SizedBox(height: 20),

                      // Enabled Switch
                      SwitchListTile(
                        title: Text('Enable PayU Gateway', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('Allow users to pay via PayU Hosted Checkout', style: GoogleFonts.dmSans(fontSize: 12)),
                        value: _isEnabled,
                        activeColor: const Color(0xFF6366F1),
                        onChanged: (val) => setState(() => _isEnabled = val),
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text('Save PayU Credentials', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

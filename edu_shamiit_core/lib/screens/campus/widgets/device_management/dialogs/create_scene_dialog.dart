import 'package:flutter/material.dart';

class CreateCustomSceneDialog extends StatefulWidget {
  final Function(String name, String code, String description) onSave;

  const CreateCustomSceneDialog({super.key, required this.onSave});

  @override
  State<CreateCustomSceneDialog> createState() => _CreateCustomSceneDialogState();
}

class _CreateCustomSceneDialogState extends State<CreateCustomSceneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Create Custom Scene / Preset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Scene Name *', hintText: 'e.g. Science Fair Setup'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(labelText: 'Unique Code *', hintText: 'e.g. science_fair'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description / Targets', hintText: 'e.g. AC 22°C, Stage floodlights 90%, Audio PA On'),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave(_nameCtrl.text.trim(), _codeCtrl.text.trim(), _descCtrl.text.trim());
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Create Scene'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

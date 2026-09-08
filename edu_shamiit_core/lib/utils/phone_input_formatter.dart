import 'package:flutter/services.dart';

/// Formatter that strips any non-numeric digit character (e.g. on paste or typing)
/// and limits input length to exactly 10 digits.
class PasteSanitizerFormatter extends TextInputFormatter {
  final int maxDigits;

  PasteSanitizerFormatter({this.maxDigits = 10});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep only numeric digits 0-9
    String newText = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Limit to max 10 digits
    if (newText.length > maxDigits) {
      newText = newText.substring(0, maxDigits);
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

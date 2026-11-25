class SmsEncodingInfo {
  final String encoding; // GSM7 or UNICODE
  final int characterCount;
  final int segmentCount;
  final int perSegmentLimit;
  final int currentSegmentMax;
  final int remainingInSegment;

  const SmsEncodingInfo({
    required this.encoding,
    required this.characterCount,
    required this.segmentCount,
    required this.perSegmentLimit,
    required this.currentSegmentMax,
    required this.remainingInSegment,
  });

  bool get isMultipart => segmentCount > 1;
  bool get isUnicode => encoding == 'UNICODE';
}

class SmsUtils {
  static const String _gsm7Basic =
      '@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\u001BÆæßÉ !"#¤%&\'()*+,-./0123456789:;<=>?'
      '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà';
  static const String _gsm7Extended = '^{}\\[~]|€';

  static final RegExp _phoneRegex = RegExp(r'^(\+[1-9]\d{6,14}|[6-9]\d{9}|0[6-9]\d{9})$');
  static final RegExp _varRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');

  static String normalizePhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    if (!_phoneRegex.hasMatch(cleaned)) {
      throw FormatException('Invalid phone number: $raw');
    }
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return '+91$cleaned';
    }
    if (RegExp(r'^0[6-9]\d{9}$').hasMatch(cleaned)) {
      return '+91${cleaned.substring(1)}';
    }
    return cleaned;
  }

  static bool isValidPhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    return _phoneRegex.hasMatch(cleaned);
  }

  static List<String> parseMultiplePhones(String rawInput) {
    final tokens = rawInput
        .split(RegExp(r'[,;\n\r\t]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final unique = <String>{};
    for (final t in tokens) {
      if (isValidPhone(t)) {
        unique.add(normalizePhone(t));
      }
    }
    return unique.toList();
  }

  static SmsEncodingInfo analyzeEncoding(String body) {
    if (body.isEmpty) {
      return const SmsEncodingInfo(
        encoding: 'GSM7',
        characterCount: 0,
        segmentCount: 1,
        perSegmentLimit: 160,
        currentSegmentMax: 160,
        remainingInSegment: 160,
      );
    }

    int septets = 0;
    bool isGsm7 = true;
    for (int i = 0; i < body.length; i++) {
      final ch = body[i];
      if (_gsm7Basic.contains(ch)) {
        septets += 1;
      } else if (_gsm7Extended.contains(ch)) {
        septets += 2;
      } else {
        isGsm7 = false;
        break;
      }
    }

    if (isGsm7) {
      if (septets <= 160) {
        return SmsEncodingInfo(
          encoding: 'GSM7',
          characterCount: septets,
          segmentCount: 1,
          perSegmentLimit: 160,
          currentSegmentMax: 160,
          remainingInSegment: 160 - septets,
        );
      }
      final segments = (septets + 152) ~/ 153;
      final maxChars = segments * 153;
      return SmsEncodingInfo(
        encoding: 'GSM7',
        characterCount: septets,
        segmentCount: segments,
        perSegmentLimit: 153,
        currentSegmentMax: maxChars,
        remainingInSegment: maxChars - septets,
      );
    } else {
      final units = body.length;
      if (units <= 70) {
        return SmsEncodingInfo(
          encoding: 'UNICODE',
          characterCount: units,
          segmentCount: 1,
          perSegmentLimit: 70,
          currentSegmentMax: 70,
          remainingInSegment: 70 - units,
        );
      }
      final segments = (units + 66) ~/ 67;
      final maxChars = segments * 67;
      return SmsEncodingInfo(
        encoding: 'UNICODE',
        characterCount: units,
        segmentCount: segments,
        perSegmentLimit: 67,
        currentSegmentMax: maxChars,
        remainingInSegment: maxChars - units,
      );
    }
  }

  static List<String> extractTemplateVariables(String body) {
    return _varRegex
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet()
        .toList()
      ..sort();
  }

  static String renderTemplateStrict(
    String templateBody,
    Map<String, String> values, {
    List<String>? requiredVars,
  }) {
    final detected = extractTemplateVariables(templateBody);
    final req = requiredVars ?? detected;
    final missing = req.where((v) => (values[v] ?? '').trim().isEmpty).toList();
    if (missing.isNotEmpty) {
      throw FormatException('Unresolved required variables: ${missing.join(', ')}');
    }
    var out = templateBody;
    for (final k in detected) {
      final val = values[k];
      if (val != null) {
        out = out.replaceAll('{$k}', val);
      }
    }
    final remaining = extractTemplateVariables(out);
    if (remaining.isNotEmpty) {
      throw FormatException('Unresolved placeholders: ${remaining.join(', ')}');
    }
    return out;
  }
}

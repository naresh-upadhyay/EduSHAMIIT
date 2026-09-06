import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'package:edu_shamiit_core/utils/js_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class BarcodeQrDialog extends StatelessWidget {
  final String title;
  final String isbn;
  final String barcode;
  final String accessionNumber;

  const BarcodeQrDialog({
    super.key,
    required this.title,
    required this.isbn,
    required this.barcode,
    required this.accessionNumber,
  });

  String get _pdfDownloadUrl {
    final queryParams = {
      'title': title,
      'isbn': isbn,
      'barcode': barcode,
      'accession_number': accessionNumber,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/library/books/label-pdf').replace(
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  void _handlePrint(BuildContext context) {
    try {
      printBookLabelHtml(
        title: title,
        isbn: isbn,
        barcode: barcode,
        accessionNumber: accessionNumber,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Print preview opened. Select your printer or "Save as PDF".'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('[BarcodeQrDialog] Print error: $e');
      _handleDownloadPdf(context);
    }
  }

  Future<void> _handleDownloadPdf(BuildContext context) async {
    final filename = 'Book_Label_${accessionNumber.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';
    final url = _pdfDownloadUrl;

    try {
      if (kIsWeb) {
        downloadFileWeb(url, filename);
      } else {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Downloaded $filename')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[BarcodeQrDialog] PDF download error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Book Barcode & QR Label',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Printable Label Card
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Institutional Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'EduSHAMIIT LIBRARY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            accessionNumber,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Book Title & ISBN
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ISBN: $isbn',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),

                    const SizedBox(height: 14),

                    // 1. Real Standard Code 128 Scannable Barcode
                    SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: StandardCode128BarcodePainter(barcode),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      barcode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Color(0xFF1E293B),
                      ),
                    ),

                    const Divider(height: 24),

                    // 2. Real Standard Scannable QR Code
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 88,
                          height: 88,
                          child: CustomPaint(
                            painter: StandardQrCodePainter(barcode),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Check-In / Out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Scan via Mobile App or Gate Scanner',
                              style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'AUTHENTICATED RFID / QR',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Dialog Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  Row(
                    children: [
                      // Download PDF Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFF6366F1)),
                        label: const Text('Download PDF', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onPressed: () => _handleDownloadPdf(context),
                      ),
                      const SizedBox(width: 10),

                      // Print Label Button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Label', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => _handlePrint(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================================
// 1. OFFICIAL ISO/IEC 15417 STANDARD CODE 128 BARCODE GENERATOR
// ============================================================================

class StandardCode128BarcodePainter extends CustomPainter {
  final String data;
  StandardCode128BarcodePainter(this.data);

  static const List<List<int>> _code128Table = [
    [2, 1, 2, 2, 2, 2], // 0: ' '
    [2, 2, 2, 1, 2, 2], // 1: '!'
    [2, 2, 2, 2, 2, 1], // 2: '"'
    [1, 2, 1, 2, 2, 3], // 3: '#'
    [1, 2, 1, 3, 2, 2], // 4: '$'
    [1, 3, 1, 2, 2, 2], // 5: '%'
    [1, 2, 2, 2, 1, 3], // 6: '&'
    [1, 2, 2, 3, 1, 2], // 7: '\''
    [1, 3, 2, 2, 1, 2], // 8: '('
    [2, 2, 1, 2, 1, 3], // 9: ')'
    [2, 2, 1, 3, 1, 2], // 10: '*'
    [2, 3, 1, 2, 1, 2], // 11: '+'
    [1, 1, 2, 2, 3, 2], // 12: ','
    [1, 2, 2, 1, 3, 2], // 13: '-'
    [1, 2, 2, 2, 3, 1], // 14: '.'
    [1, 1, 3, 2, 2, 2], // 15: '/'
    [1, 2, 3, 1, 2, 2], // 16: '0'
    [1, 2, 3, 2, 2, 1], // 17: '1'
    [2, 2, 3, 2, 1, 1], // 18: '2'
    [2, 2, 1, 1, 3, 2], // 19: '3'
    [2, 2, 1, 2, 3, 1], // 20: '4'
    [2, 1, 3, 2, 1, 2], // 21: '5'
    [2, 2, 3, 1, 1, 2], // 22: '6'
    [3, 1, 2, 1, 3, 1], // 23: '7'
    [3, 1, 1, 2, 2, 2], // 24: '8'
    [3, 2, 1, 1, 2, 2], // 25: '9'
    [3, 2, 1, 2, 2, 1], // 26: ':'
    [3, 1, 2, 2, 1, 2], // 27: ';'
    [3, 2, 2, 1, 1, 2], // 28: '<'
    [3, 2, 2, 2, 1, 1], // 29: '='
    [2, 1, 2, 1, 2, 3], // 30: '>'
    [2, 1, 2, 3, 2, 1], // 31: '?'
    [2, 3, 2, 1, 2, 1], // 32: '@'
    [1, 1, 1, 3, 2, 3], // 33: 'A'
    [1, 3, 1, 1, 2, 3], // 34: 'B'
    [1, 3, 1, 3, 2, 1], // 35: 'C'
    [1, 1, 2, 3, 1, 3], // 36: 'D'
    [1, 3, 2, 1, 1, 3], // 37: 'E'
    [1, 3, 2, 3, 1, 1], // 38: 'F'
    [2, 1, 1, 3, 1, 3], // 39: 'G'
    [2, 3, 1, 1, 1, 3], // 40: 'H'
    [2, 3, 1, 3, 1, 1], // 41: 'I'
    [1, 1, 2, 1, 3, 3], // 42: 'J'
    [1, 1, 2, 3, 3, 1], // 43: 'K'
    [1, 3, 2, 1, 3, 1], // 44: 'L'
    [1, 1, 3, 1, 2, 3], // 45: 'M'
    [1, 1, 3, 3, 2, 1], // 46: 'N'
    [1, 3, 3, 1, 2, 1], // 47: 'O'
    [3, 1, 3, 1, 2, 1], // 48: 'P'
    [2, 1, 1, 3, 3, 1], // 49: 'Q'
    [2, 3, 1, 1, 3, 1], // 50: 'R'
    [2, 1, 3, 1, 1, 3], // 51: 'S'
    [2, 1, 3, 3, 1, 1], // 52: 'T'
    [2, 1, 3, 1, 3, 1], // 53: 'U'
    [3, 1, 1, 1, 2, 3], // 54: 'V'
    [3, 1, 1, 3, 2, 1], // 55: 'W'
    [3, 3, 1, 1, 2, 1], // 56: 'X'
    [3, 1, 2, 1, 1, 3], // 57: 'Y'
    [3, 1, 2, 3, 1, 1], // 58: 'Z'
    [3, 3, 2, 1, 1, 1], // 59: '['
    [3, 1, 4, 1, 1, 1], // 60: '\\'
    [2, 2, 1, 4, 1, 1], // 61: ']'
    [4, 3, 1, 1, 1, 1], // 62: '^'
    [1, 1, 1, 2, 2, 4], // 63: '_'
    [1, 1, 1, 4, 2, 2], // 64: '`'
    [1, 2, 1, 1, 2, 4], // 65: 'a'
    [1, 2, 1, 4, 2, 1], // 66: 'b'
    [1, 4, 1, 1, 2, 2], // 67: 'c'
    [1, 4, 1, 2, 2, 1], // 68: 'd'
    [1, 1, 2, 2, 1, 4], // 69: 'e'
    [1, 1, 2, 4, 1, 2], // 70: 'f'
    [1, 2, 2, 1, 1, 4], // 71: 'g'
    [1, 2, 2, 4, 1, 1], // 72: 'h'
    [1, 4, 2, 1, 1, 2], // 73: 'i'
    [1, 4, 2, 2, 1, 1], // 74: 'j'
    [2, 4, 1, 2, 1, 1], // 75: 'k'
    [2, 2, 1, 1, 1, 4], // 76: 'l'
    [4, 1, 3, 1, 1, 1], // 77: 'm'
    [2, 4, 1, 1, 1, 2], // 78: 'n'
    [1, 3, 4, 1, 1, 1], // 79: 'o'
    [1, 1, 1, 2, 4, 2], // 80: 'p'
    [1, 2, 1, 1, 4, 2], // 81: 'q'
    [1, 2, 1, 2, 4, 1], // 82: 'r'
    [1, 1, 4, 2, 1, 2], // 83: 's'
    [1, 2, 4, 1, 1, 2], // 84: 't'
    [1, 2, 4, 2, 1, 1], // 85: 'u'
    [4, 1, 1, 2, 1, 2], // 86: 'v'
    [4, 2, 1, 1, 1, 2], // 87: 'w'
    [4, 2, 1, 2, 1, 1], // 88: 'x'
    [2, 1, 2, 1, 4, 1], // 89: 'y'
    [2, 1, 4, 1, 2, 1], // 90: 'z'
    [4, 1, 2, 1, 2, 1], // 91: '{'
    [1, 1, 1, 1, 4, 3], // 92: '|'
    [1, 1, 1, 3, 4, 1], // 93: '}'
    [1, 3, 1, 1, 4, 1], // 94: '~'
    [1, 1, 4, 1, 1, 3], // 95: DEL
    [1, 1, 4, 3, 1, 1], // 96: FNC3
    [4, 1, 1, 1, 1, 3], // 97: FNC2
    [4, 1, 1, 3, 1, 1], // 98: SHIFT
    [1, 1, 3, 1, 4, 1], // 99: CODE C
    [1, 1, 4, 1, 3, 1], // 100: CODE B
    [3, 1, 1, 1, 4, 1], // 101: FNC4
    [4, 1, 1, 1, 3, 1], // 102: FNC1
    [2, 1, 1, 4, 1, 2], // 103: START A
    [2, 1, 1, 2, 1, 4], // 104: START B
    [2, 1, 1, 2, 3, 2], // 105: START C
    [2, 3, 3, 1, 1, 1, 2], // 106: STOP
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final clean = data.trim().isNotEmpty ? data.trim() : 'BC000001';
    final List<int> patternWidths = [];

    // Quiet zone (10 units)
    patternWidths.addAll([0, 10]);

    // 1. Start Code B (104)
    const startCode = 104;
    patternWidths.addAll(_code128Table[startCode]);

    // 2. Data Characters
    int checksumSum = startCode;
    for (int i = 0; i < clean.length; i++) {
      int ascii = clean.codeUnitAt(i);
      int codeVal = (ascii >= 32 && ascii <= 126) ? (ascii - 32) : 0;
      patternWidths.addAll(_code128Table[codeVal]);
      checksumSum += (i + 1) * codeVal;
    }

    // 3. Checksum Character
    int checksumVal = checksumSum % 103;
    patternWidths.addAll(_code128Table[checksumVal]);

    // 4. Stop Code (106)
    patternWidths.addAll(_code128Table[106]);

    // Quiet zone (10 units)
    patternWidths.addAll([0, 10]);

    // Calculate module scale
    int totalModules = 0;
    for (final w in patternWidths) {
      totalModules += w;
    }

    final moduleWidth = size.width / totalModules;
    double currentX = 0;
    bool isBar = false; // Starts after first quiet zone

    for (final w in patternWidths) {
      final barWidth = w * moduleWidth;
      if (isBar && barWidth > 0) {
        canvas.drawRect(Rect.fromLTWH(currentX, 0, barWidth, size.height), paint);
      }
      currentX += barWidth;
      isBar = !isBar;
    }
  }

  @override
  bool shouldRepaint(covariant StandardCode128BarcodePainter oldDelegate) => oldDelegate.data != data;
}

// ============================================================================
// 2. ISO/IEC 18004 STANDARD QR CODE GENERATOR (REED-SOLOMON ERROR CORRECTION)
// ============================================================================

class StandardQrCodePainter extends CustomPainter {
  final String text;
  StandardQrCodePainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final matrix = _generateQrMatrix(text);
    final matrixSize = matrix.length;
    final cellSize = size.width / matrixSize;

    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        if (matrix[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize * 0.96, cellSize * 0.96),
              const Radius.circular(0.8),
            ),
            paint,
          );
        }
      }
    }
  }

  /// Complete ISO 18004 QR Code Matrix Generator (Version 2 / 25x25)
  List<List<int>> _generateQrMatrix(String content) {
    const size = 25; // Version 2
    final matrix = List.generate(size, (_) => List.filled(size, -1));

    // 1. Draw 7x7 Finder Patterns + Separators
    void drawFinder(int r0, int c0) {
      for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
          final row = r0 + r;
          final col = c0 + c;
          if (row >= 0 && row < size && col >= 0 && col < size) {
            if (r == -1 || r == 7 || c == -1 || c == 7) {
              matrix[row][col] = 0; // White separator
            } else if (r == 0 || r == 6 || c == 0 || c == 6) {
              matrix[row][col] = 1; // Black border
            } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
              matrix[row][col] = 1; // 3x3 inner square
            } else {
              matrix[row][col] = 0; // White inner ring
            }
          }
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(0, size - 7);
    drawFinder(size - 7, 0);

    // 2. Alignment Pattern for Version 2 at (18, 18)
    void drawAlignment(int cr, int cc) {
      for (int r = -2; r <= 2; r++) {
        for (int c = -2; c <= 2; c++) {
          final row = cr + r;
          final col = cc + c;
          if (matrix[row][col] == -1) {
            if (r.abs() == 2 || c.abs() == 2 || (r == 0 && c == 0)) {
              matrix[row][col] = 1;
            } else {
              matrix[row][col] = 0;
            }
          }
        }
      }
    }

    drawAlignment(18, 18);

    // 3. Timing Patterns (Row 6 and Column 6)
    for (int i = 8; i < size - 8; i++) {
      if (matrix[6][i] == -1) matrix[6][i] = (i % 2 == 0) ? 1 : 0;
      if (matrix[i][6] == -1) matrix[i][6] = (i % 2 == 0) ? 1 : 0;
    }

    // Dark Module at (4 * Version + 9, 8) -> (17, 8)
    matrix[17][8] = 1;

    // Reserve Format Information areas
    for (int i = 0; i < 9; i++) {
      if (matrix[8][i] == -1) matrix[8][i] = 0;
      if (matrix[i][8] == -1) matrix[i][8] = 0;
    }
    for (int i = size - 8; i < size; i++) {
      if (matrix[8][i] == -1) matrix[8][i] = 0;
      if (matrix[i][8] == -1) matrix[i][8] = 0;
    }

    // 4. Encode Payload with Byte Mode + Reed-Solomon Parity
    final dataCodewords = _encodeBytePayload(content, 28); // 28 data bytes for V2-M
    final ecCodewords = _computeReedSolomon(dataCodewords, 16); // 16 EC bytes
    final allCodewords = [...dataCodewords, ...ecCodewords];

    // Convert codewords to bitstream
    final bitStream = <int>[];
    for (final b in allCodewords) {
      for (int bit = 7; bit >= 0; bit--) {
        bitStream.add((b >> bit) & 1);
      }
    }

    // 5. Place Data Bits in Matrix (2-column zigzag)
    int bitIndex = 0;
    int col = size - 1;
    bool upward = true;

    while (col > 0) {
      if (col == 6) col--; // Skip vertical timing pattern

      final rows = upward ? List.generate(size, (i) => size - 1 - i) : List.generate(size, (i) => i);
      for (final r in rows) {
        for (int c = col; c >= col - 1; c--) {
          if (matrix[r][c] == -1) {
            int bit = bitIndex < bitStream.length ? bitStream[bitIndex++] : 0;
            // Apply Standard Mask Pattern 0: (row + col) % 2 == 0
            if ((r + c) % 2 == 0) {
              bit ^= 1;
            }
            matrix[r][c] = bit;
          }
        }
      }
      col -= 2;
      upward = !upward;
    }

    // 6. Write Format Info (Level M + Mask 0 = 101010000010010)
    const formatBits = [1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0];

    // Format bits around top-left
    matrix[8][0] = formatBits[0];
    matrix[8][1] = formatBits[1];
    matrix[8][2] = formatBits[2];
    matrix[8][3] = formatBits[3];
    matrix[8][4] = formatBits[4];
    matrix[8][5] = formatBits[5];
    matrix[8][7] = formatBits[6];
    matrix[8][8] = formatBits[7];
    matrix[7][8] = formatBits[8];
    matrix[5][8] = formatBits[9];
    matrix[4][8] = formatBits[10];
    matrix[3][8] = formatBits[11];
    matrix[2][8] = formatBits[12];
    matrix[1][8] = formatBits[13];
    matrix[0][8] = formatBits[14];

    // Format bits around bottom-left & top-right
    for (int i = 0; i < 7; i++) {
      matrix[size - 1 - i][8] = formatBits[i];
    }
    for (int i = 0; i < 8; i++) {
      matrix[8][size - 8 + i] = formatBits[7 + i];
    }

    return matrix;
  }

  /// Encode string to QR Byte Mode data codewords
  List<int> _encodeBytePayload(String str, int totalCapacity) {
    final bytes = str.codeUnits;
    final bitBuffer = <int>[];

    void writeBits(int val, int count) {
      for (int i = count - 1; i >= 0; i--) {
        bitBuffer.add((val >> i) & 1);
      }
    }

    // Byte Mode Indicator: 0100 (4 bits)
    writeBits(4, 4);

    // Character Count Indicator (8 bits for V1-V9)
    writeBits(bytes.length, 8);

    // Data payload
    for (final b in bytes) {
      writeBits(b, 8);
    }

    // Terminator (up to 4 zeroes)
    writeBits(0, 4);

    // Byte alignment
    while (bitBuffer.length % 8 != 0) {
      bitBuffer.add(0);
    }

    // Convert to bytes
    final result = <int>[];
    for (int i = 0; i < bitBuffer.length; i += 8) {
      int b = 0;
      for (int j = 0; j < 8; j++) {
        b = (b << 1) | bitBuffer[i + j];
      }
      result.add(b);
    }

    // Pad bytes 0xEC and 0x11
    final padBytes = [0xEC, 0x11];
    int padIndex = 0;
    while (result.length < totalCapacity) {
      result.add(padBytes[padIndex % 2]);
      padIndex++;
    }

    return result;
  }

  /// Reed-Solomon GF(256) parity byte generator
  List<int> _computeReedSolomon(List<int> data, int ecCount) {
    final expTable = List.filled(512, 0);
    final logTable = List.filled(256, 0);
    int x = 1;
    for (int i = 0; i < 255; i++) {
      expTable[i] = x;
      expTable[i + 255] = x;
      logTable[x] = i;
      x = (x << 1);
      if (x >= 256) x ^= 0x11D; // Primitive polynomial 285
    }

    int gfMul(int a, int b) {
      if (a == 0 || b == 0) return 0;
      return expTable[logTable[a] + logTable[b]];
    }

    // Generator polynomial
    var gen = [1];
    for (int i = 0; i < ecCount; i++) {
      final nextGen = List.filled(gen.length + 1, 0);
      final factor = expTable[i];
      for (int j = 0; j < gen.length; j++) {
        nextGen[j] ^= gfMul(gen[j], factor);
        nextGen[j + 1] ^= gen[j];
      }
      gen = nextGen;
    }

    // Synthetic division
    final res = List.filled(ecCount, 0);
    for (final byte in data) {
      final factor = byte ^ res[0];
      for (int i = 0; i < ecCount - 1; i++) {
        res[i] = res[i + 1] ^ gfMul(gen[gen.length - 2 - i], factor);
      }
      res[ecCount - 1] = gfMul(gen[0], factor);
    }

    return res;
  }

  @override
  bool shouldRepaint(covariant StandardQrCodePainter oldDelegate) => oldDelegate.text != text;
}

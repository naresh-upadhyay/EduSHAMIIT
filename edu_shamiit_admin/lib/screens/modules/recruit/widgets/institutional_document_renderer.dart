import 'package:flutter/material.dart';

/// Ultra-Premium Institutional Document Renderer
/// Parses rich document HTML into native, pixel-perfect Flutter widgets
/// with support for real tables, formatted bullet lists, bold text spans,
/// status badges, callouts, and official signature blocks.
class InstitutionalDocumentRenderer extends StatelessWidget {
  final String htmlContent;
  final String templateType;
  final bool isDark;

  const InstitutionalDocumentRenderer({
    super.key,
    required this.htmlContent,
    required this.templateType,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    if (htmlContent.trim().isEmpty) {
      return Text(
        'No template content entered.',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final blocks = _parseHtmlBlocks(htmlContent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks.map((block) => _buildBlock(context, block)).toList(),
    );
  }

  Widget _buildBlock(BuildContext context, _DocBlock block) {
    switch (block.type) {
      case _DocBlockType.table:
        return _buildTable(block.tableData ?? []);
      case _DocBlockType.unorderedList:
        return _buildList(block.listItems ?? [], isOrdered: false);
      case _DocBlockType.orderedList:
        return _buildList(block.listItems ?? [], isOrdered: true);
      case _DocBlockType.divider:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Divider(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            thickness: 1.2,
          ),
        );
      case _DocBlockType.paragraph:
        return _buildParagraph(block.text ?? '', block.isCentered);
    }
  }

  Widget _buildTable(List<List<_TableCell>> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final altBg = isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFF1F5F9).withValues(alpha: 0.4);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: borderColor, width: 1),
          verticalInside: BorderSide(color: borderColor, width: 1),
        ),
        children: rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final rowCells = entry.value;
          final isHeaderRow = rowIndex == 0 && rowCells.any((c) => c.isHeader);
          final rowBg = isHeaderRow ? headerBg : (rowIndex % 2 == 1 ? altBg : Colors.transparent);

          return TableRow(
            decoration: BoxDecoration(color: rowBg),
            children: rowCells.map((cell) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: _buildCellContent(cell, isHeaderRow),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCellContent(_TableCell cell, bool isHeader) {
    final text = cell.text.trim();

    // Check if cell is a verification badge
    if (text.toLowerCase() == 'verified' || text.toLowerCase().contains('[x] verified') || text.toLowerCase().contains('[ ] verified')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
            SizedBox(width: 4),
            Text(
              'Verified',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF059669),
              ),
            ),
          ],
        ),
      );
    }

    if (text == '[   ]' || text == '[  ]' || text == '[ ]' || text.toLowerCase() == '[ ] verified') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '[ ✓ ]',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: isHeader ? 11 : 12,
        fontWeight: isHeader || cell.isHeader ? FontWeight.bold : FontWeight.normal,
        color: isHeader
            ? (isDark ? Colors.white : const Color(0xFF0F172A))
            : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
        letterSpacing: isHeader ? 0.3 : 0,
      ),
    );
  }

  Widget _buildList(List<String> items, {required bool isOrdered}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.only(left: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final itemText = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isOrdered)
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(right: 10, top: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 10, top: 7),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: _buildRichTextSpan(itemText, isDark: isDark),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildParagraph(String text, bool isCentered) {
    if (text.trim().isEmpty) {
      return const SizedBox(height: 10);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isCentered ? Alignment.center : Alignment.centerLeft,
        child: _buildRichTextSpan(text, isDark: isDark, textAlign: isCentered ? TextAlign.center : TextAlign.left),
      ),
    );
  }

  Widget _buildRichTextSpan(String text, {required bool isDark, TextAlign textAlign = TextAlign.left}) {
    final spans = _parseInlineSpans(text, isDark: isDark);

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      style: TextStyle(
        fontSize: 13,
        height: 1.65,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(String rawText, {required bool isDark}) {
    final List<InlineSpan> spans = [];

    // Clean HTML entities first
    String text = rawText
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');

    // Split text by bold/italic/underline tokens
    final tagRegex = RegExp(r'(<strong>|</strong>|<b>|</b>|<em>|</em>|<i>|</i>|<u>|</u>|<br\s*/?>)', caseSensitive: false);
    final matches = tagRegex.allMatches(text);

    int lastIndex = 0;
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final segment = text.substring(lastIndex, match.start);
        spans.add(TextSpan(
          text: segment,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
            color: isBold
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
          ),
        ));
      }

      final tag = match.group(0)!.toLowerCase();
      if (tag == '<strong>' || tag == '<b>') {
        isBold = true;
      } else if (tag == '</strong>' || tag == '</b>') {
        isBold = false;
      } else if (tag == '<em>' || tag == '<i>') {
        isItalic = true;
      } else if (tag == '</em>' || tag == '</i>') {
        isItalic = false;
      } else if (tag == '<u>') {
        isUnderline = true;
      } else if (tag == '</u>') {
        isUnderline = false;
      } else if (tag.startsWith('<br')) {
        spans.add(const TextSpan(text: '\n'));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final segment = text.substring(lastIndex);
      spans.add(TextSpan(
        text: segment,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
          color: isBold
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
        ),
      ));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }

  List<_DocBlock> _parseHtmlBlocks(String rawHtml) {
    final List<_DocBlock> blocks = [];

    // Normalize newlines
    String content = rawHtml.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Split by block tags: <table>, <ul>, <ol>, <hr>, <p>
    final blockRegex = RegExp(
      r'(<table[\s\S]*?</table>|<ul[\s\S]*?</ul>|<ol[\s\S]*?</ol>|<hr[\s\S]*?>|<p[\s\S]*?</p>)',
      caseSensitive: false,
    );

    int lastIndex = 0;
    final matches = blockRegex.allMatches(content);

    for (final m in matches) {
      // Anything preceding this block as loose text
      if (m.start > lastIndex) {
        final loose = content.substring(lastIndex, m.start).trim();
        if (loose.isNotEmpty) {
          blocks.add(_DocBlock(type: _DocBlockType.paragraph, text: loose));
        }
      }

      final blockHtml = m.group(0)!;
      final lower = blockHtml.toLowerCase();

      if (lower.startsWith('<table')) {
        blocks.add(_parseTable(blockHtml));
      } else if (lower.startsWith('<ul')) {
        blocks.add(_parseList(blockHtml, isOrdered: false));
      } else if (lower.startsWith('<ol')) {
        blocks.add(_parseList(blockHtml, isOrdered: true));
      } else if (lower.startsWith('<hr')) {
        blocks.add(const _DocBlock(type: _DocBlockType.divider));
      } else if (lower.startsWith('<p')) {
        final isCentered = lower.contains('text-align: center') || lower.contains('text-align:center');
        final innerText = blockHtml.replaceAll(RegExp(r'^<p[^>]*>', caseSensitive: false), '').replaceAll(RegExp(r'</p>$', caseSensitive: false), '');
        blocks.add(_DocBlock(type: _DocBlockType.paragraph, text: innerText, isCentered: isCentered));
      }

      lastIndex = m.end;
    }

    if (lastIndex < content.length) {
      final remaining = content.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        blocks.add(_DocBlock(type: _DocBlockType.paragraph, text: remaining));
      }
    }

    return blocks;
  }

  _DocBlock _parseTable(String tableHtml) {
    final rowRegex = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
    final cellRegex = RegExp(r'<(td|th)[^>]*>([\s\S]*?)</\1>', caseSensitive: false);

    final List<List<_TableCell>> rows = [];
    final rowMatches = rowRegex.allMatches(tableHtml);

    for (final rm in rowMatches) {
      final rowHtml = rm.group(1)!;
      final List<_TableCell> cells = [];
      final cellMatches = cellRegex.allMatches(rowHtml);

      for (final cm in cellMatches) {
        final tag = cm.group(1)!.toLowerCase();
        final rawCellText = cm.group(2)!;
        final cleanText = rawCellText
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .trim();

        cells.add(_TableCell(text: cleanText, isHeader: tag == 'th'));
      }

      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    return _DocBlock(type: _DocBlockType.table, tableData: rows);
  }

  _DocBlock _parseList(String listHtml, {required bool isOrdered}) {
    final liRegex = RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false);
    final List<String> items = [];
    final matches = liRegex.allMatches(listHtml);

    for (final m in matches) {
      items.add(m.group(1)!.trim());
    }

    return _DocBlock(
      type: isOrdered ? _DocBlockType.orderedList : _DocBlockType.unorderedList,
      listItems: items,
    );
  }
}

enum _DocBlockType { paragraph, table, unorderedList, orderedList, divider }

class _DocBlock {
  final _DocBlockType type;
  final String? text;
  final bool isCentered;
  final List<List<_TableCell>>? tableData;
  final List<String>? listItems;

  const _DocBlock({
    required this.type,
    this.text,
    this.isCentered = false,
    this.tableData,
    this.listItems,
  });
}

class _TableCell {
  final String text;
  final bool isHeader;

  const _TableCell({required this.text, this.isHeader = false});
}

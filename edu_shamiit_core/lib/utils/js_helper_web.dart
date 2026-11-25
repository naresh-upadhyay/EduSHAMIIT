// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

bool hasMediaDevices() {
  try {
    final result = js.context.callMethod(
        'eval', ["typeof navigator.mediaDevices !== 'undefined'"]);
    return result == true;
  } catch (e) {
    debugPrint('[JSHelper] Error checking media devices: $e');
    return false;
  }
}

void jsAlert(String message) {
  try {
    js.context.callMethod('alert', [message]);
  } catch (e) {
    debugPrint('[JSHelper] Error showing alert: $e');
  }
}

void startWebRingtone() {
  try {
    js.context.callMethod('eval', [
      '''
      if (!window.ringingSynth) {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (AudioContext) {
          const ctx = new AudioContext();
          let isPlaying = false;
          let timer = null;
          
          window.ringingSynth = {
            start: function() {
              if (isPlaying) return;
              isPlaying = true;
              if (ctx.state === 'suspended') {
                ctx.resume();
              }
              
              function playRing() {
                if (!isPlaying) return;
                
                const osc1 = ctx.createOscillator();
                const osc2 = ctx.createOscillator();
                const gain = ctx.createGain();
                
                osc1.type = 'sine';
                osc1.frequency.value = 400;
                
                osc2.type = 'sine';
                osc2.frequency.value = 450;
                
                gain.gain.setValueAtTime(0, ctx.currentTime);
                gain.gain.linearRampToValueAtTime(0.15, ctx.currentTime + 0.1);
                gain.gain.setValueAtTime(0.15, ctx.currentTime + 1.8);
                gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 2.0);
                
                osc1.connect(gain);
                osc2.connect(gain);
                gain.connect(ctx.destination);
                
                osc1.start();
                osc2.start();
                
                osc1.stop(ctx.currentTime + 2.0);
                osc2.stop(ctx.currentTime + 2.0);
                
                timer = setTimeout(() => {
                  if (isPlaying) playRing();
                }, 3000);
              }
              
              playRing();
            },
            stop: function() {
              isPlaying = false;
              if (timer) {
                clearTimeout(timer);
                timer = null;
              }
            }
          };
        }
      }
      if (window.ringingSynth) {
        window.ringingSynth.start();
      }
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error starting web ringtone: $e');
  }
}

void stopWebRingtone() {
  try {
    js.context.callMethod('eval', [
      '''
      if (window.ringingSynth) {
        window.ringingSynth.stop();
      }
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error stopping web ringtone: $e');
  }
}

void playWebHandRaiseChime() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        const ctx = window._eduAudioCtx || (window._eduAudioCtx = new AudioCtx());
        if (ctx.state === 'suspended') ctx.resume();
        const now = ctx.currentTime;
        
        const osc1 = ctx.createOscillator();
        const gain1 = ctx.createGain();
        osc1.type = 'sine';
        osc1.frequency.setValueAtTime(587.33, now);
        gain1.gain.setValueAtTime(0.18, now);
        gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.25);
        osc1.connect(gain1);
        gain1.connect(ctx.destination);
        osc1.start(now);
        osc1.stop(now + 0.25);

        const osc2 = ctx.createOscillator();
        const gain2 = ctx.createGain();
        osc2.type = 'sine';
        osc2.frequency.setValueAtTime(880, now + 0.08);
        gain2.gain.setValueAtTime(0.22, now + 0.08);
        gain2.gain.exponentialRampToValueAtTime(0.001, now + 0.45);
        osc2.connect(gain2);
        gain2.connect(ctx.destination);
        osc2.start(now + 0.08);
        osc2.stop(now + 0.45);
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Hand raise chime notice: $e');
  }
}

void playWebChatMessageChime() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        const ctx = window._eduAudioCtx || (window._eduAudioCtx = new AudioCtx());
        if (ctx.state === 'suspended') ctx.resume();
        const now = ctx.currentTime;
        
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(750, now);
        osc.frequency.exponentialRampToValueAtTime(350, now + 0.09);
        gain.gain.setValueAtTime(0.08, now);
        gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(now);
        osc.stop(now + 0.09);
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Chat chime notice: $e');
  }
}

void playWebParticipantChime() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        if (!AudioCtx) return;
        const ctx = window._eduAudioCtx || (window._eduAudioCtx = new AudioCtx());
        if (ctx.state === 'suspended') ctx.resume();
        const now = ctx.currentTime;
        
        [523.25, 659.25].forEach(freq => {
          const osc = ctx.createOscillator();
          const gain = ctx.createGain();
          osc.type = 'sine';
          osc.frequency.setValueAtTime(freq, now);
          gain.gain.setValueAtTime(0.09, now);
          gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
          osc.connect(gain);
          gain.connect(ctx.destination);
          osc.start(now);
          osc.stop(now + 0.35);
        });
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Participant chime notice: $e');
  }
}

void printBookLabelHtml({
  required String title,
  required String isbn,
  required String barcode,
  required String accessionNumber,
}) {
  try {
    final escapedTitle = title.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final escapedIsbn = isbn.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final escapedBarcode = barcode.replaceAll("'", "\\'").replaceAll('"', '\\"');
    final escapedAcc = accessionNumber.replaceAll("'", "\\'").replaceAll('"', '\\"');

    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank', 'width=520,height=420');
        if (!printWindow) {
          window.print();
          return;
        }
        
        const html = `
          <!DOCTYPE html>
          <html>
          <head>
            <title>Book Label - \${'$escapedAcc'}</title>
            <style>
              @page {
                size: 4in 2.5in;
                margin: 0;
              }
              body {
                margin: 0;
                padding: 12px;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                background: #ffffff;
                color: #0f172a;
                display: flex;
                justify-content: center;
                align-items: center;
                box-sizing: border-box;
              }
              .label-card {
                width: 3.6in;
                min-height: 2.1in;
                border: 1.5px solid #cbd5e1;
                border-radius: 8px;
                padding: 10px 14px;
                box-sizing: border-box;
                display: flex;
                flex-direction: column;
                justify-content: space-between;
                background: #ffffff;
              }
              .header {
                display: flex;
                justify-content: space-between;
                align-items: center;
              }
              .brand {
                font-size: 10px;
                font-weight: 800;
                letter-spacing: 0.8px;
                color: #4f46e5;
              }
              .accession {
                font-size: 10px;
                font-family: monospace;
                font-weight: 700;
                background: #f1f5f9;
                padding: 2px 6px;
                border-radius: 4px;
                color: #1e293b;
              }
              .title-box {
                text-align: center;
                margin: 4px 0 2px 0;
              }
              .book-title {
                font-size: 12px;
                font-weight: 700;
                color: #0f172a;
                line-height: 1.2;
                max-height: 28px;
                overflow: hidden;
              }
              .book-isbn {
                font-size: 9.5px;
                color: #64748b;
                margin-top: 1px;
              }
              .barcode-box {
                text-align: center;
                margin: 4px 0;
              }
              .barcode-text {
                font-family: monospace;
                font-size: 10.5px;
                font-weight: 700;
                letter-spacing: 2px;
                color: #1e293b;
                margin-top: 2px;
              }
              .divider {
                border-top: 1px dashed #e2e8f0;
                margin: 4px 0;
              }
              .footer {
                display: flex;
                align-items: center;
                justify-content: space-between;
              }
              .qr-text h4 {
                margin: 0;
                font-size: 10px;
                font-weight: 700;
                color: #0f172a;
              }
              .qr-text p {
                margin: 1px 0 0 0;
                font-size: 8.5px;
                color: #64748b;
              }
              .qr-text .badge {
                font-size: 7.5px;
                font-weight: 700;
                color: #10b981;
                margin-top: 2px;
              }
              @media print {
                body { padding: 0; }
                .label-card { border: none; width: 100%; height: 100%; }
              }
            </style>
            <script src="https://cdn.jsdelivr.net/npm/jsbarcode@3.11.5/dist/JsBarcode.all.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
          </head>
          <body>
            <div class="label-card">
              <div class="header">
                <div class="brand">EduSHAMIIT LIBRARY</div>
                <div class="accession">\${'$escapedAcc'}</div>
              </div>
              <div class="title-box">
                <div class="book-title">\${'$escapedTitle'}</div>
                <div class="book-isbn">ISBN: \${'$escapedIsbn'}</div>
              </div>
              <div class="barcode-box">
                <svg id="barcode-canvas" style="height: 38px; width: 100%; max-width: 240px;"></svg>
                <div class="barcode-text">\${'$escapedBarcode'}</div>
              </div>
              <div class="divider"></div>
              <div class="footer">
                <div id="qrcode-canvas" style="width: 44px; height: 44px;"></div>
                <div class="qr-text" style="flex: 1; margin-left: 10px;">
                  <h4>Instant Check-In / Out</h4>
                  <p>Scan via Mobile App or Gate Scanner</p>
                  <div class="badge">AUTHENTICATED RFID / QR</div>
                </div>
              </div>
            </div>
            <script>
              window.onload = function() {
                try {
                  if (window.JsBarcode) {
                    JsBarcode("#barcode-canvas", "\${'$escapedBarcode'}", {
                      format: "CODE128",
                      lineColor: "#0f172a",
                      width: 1.6,
                      height: 36,
                      displayValue: false,
                      margin: 0
                    });
                  }
                  if (window.QRCode) {
                    new QRCode(document.getElementById("qrcode-canvas"), {
                      text: "\${'$escapedBarcode'}",
                      width: 44,
                      height: 44,
                      colorDark : "#0f172a",
                      colorLight : "#ffffff",
                      correctLevel : QRCode.CorrectLevel.M
                    });
                  }
                } catch(e) {
                  console.error(e);
                }
                setTimeout(() => {
                  window.focus();
                  window.print();
                }, 400);
              };
            </script>
          </body>
          </html>
        `;
        printWindow.document.open();
        printWindow.document.write(html);
        printWindow.document.close();
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error printing book label: $e');
  }
}

void downloadFileWeb(String url, String filename) {
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  } catch (e) {
    debugPrint('[JSHelper] Error downloading file: $e');
  }
}

void _downloadBlobContent(String content, String filename, String mimeType) {
  try {
    final blob = html.Blob([content], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    // Do NOT revoke or remove synchronously! Chromium needs the URL active while starting download.
    Timer(const Duration(seconds: 15), () {
      try {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      } catch (_) {}
    });
  } catch (e) {
    debugPrint('[JSHelper] Error downloading blob content ($filename): $e');
    try {
      final base64Content = base64Encode(utf8.encode(content));
      final dataUri = 'data:$mimeType;base64,$base64Content';
      final fallbackAnchor = html.AnchorElement(href: dataUri)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(fallbackAnchor);
      fallbackAnchor.click();
      Timer(const Duration(seconds: 5), () {
        try {
          fallbackAnchor.remove();
        } catch (_) {}
      });
    } catch (e2) {
      debugPrint('[JSHelper] Fallback data URI download also failed: $e2');
    }
  }
}

void _printHtmlDocument(String htmlContent, {String title = 'EduSHAMIIT Document'}) {
  try {
    final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);

    // Primary: Trigger tab opening via synthetic anchor click (never blocked as popup by Chrome)
    try {
      final anchor = html.AnchorElement(href: blobUrl)
        ..target = '_blank'
        ..rel = 'noopener noreferrer'
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (clickErr) {
      debugPrint('[JSHelper] Anchor click navigation failed, falling back to window.open: $clickErr');
      try {
        html.window.open(blobUrl, '_blank');
      } catch (_) {}
    }

    // Revoke object URL after enough time for spooling & printing
    Timer(const Duration(minutes: 3), () {
      try {
        html.Url.revokeObjectUrl(blobUrl);
      } catch (_) {}
    });
  } catch (e) {
    debugPrint('[JSHelper] Error in _printHtmlDocument: $e');
  }
}

void _printHtmlViaIframe(String htmlContent) {
  _printHtmlDocument(htmlContent);
}

void downloadStaffPayslipHtml({required Map<String, dynamic> payslip}) {
  try {
    final payslipNum = payslip['payslip_number']?.toString() ?? 'Payslip';
    final htmlContent = _buildStaffPayslipHtmlTemplate(payslip: payslip);
    _downloadBlobContent(htmlContent, '$payslipNum.html', 'text/html;charset=utf-8');
  } catch (e) {
    debugPrint('[JSHelper] Error downloading payslip: $e');
  }
}

void printStaffPayslipHtml({required Map<String, dynamic> payslip}) {
  try {
    final htmlContent = _buildStaffPayslipHtmlTemplate(payslip: payslip);
    _printHtmlDocument(htmlContent, title: 'Salary Payslip');
  } catch (e) {
    debugPrint('[JSHelper] Error printing payslip: $e');
  }
}

String _numberToIndianWords(double amount) {
  if (amount <= 0) return 'Zero Rupees Only';

  final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  String convertChunk(int n) {
    if (n == 0) return '';
    if (n < 20) return units[n];
    if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
    return '${units[n ~/ 100]} Hundred ${convertChunk(n % 100)}'.trim();
  }

  int totalPaise = (amount * 100).round();
  int rupees = totalPaise ~/ 100;
  int paise = totalPaise % 100;

  if (rupees == 0 && paise > 0) {
    return '${convertChunk(paise)} Paise Only';
  }

  String result = '';
  // Crores (1,00,00,000)
  if (rupees >= 10000000) {
    int cr = rupees ~/ 10000000;
    result += '${convertChunk(cr)} Crore ';
    rupees %= 10000000;
  }
  // Lakhs (1,00,000)
  if (rupees >= 100000) {
    int lk = rupees ~/ 100000;
    result += '${convertChunk(lk)} Lakh ';
    rupees %= 100000;
  }
  // Thousands (1,000)
  if (rupees >= 1000) {
    int th = rupees ~/ 1000;
    result += '${convertChunk(th)} Thousand ';
    rupees %= 1000;
  }
  // Hundreds & units
  if (rupees > 0) {
    result += convertChunk(rupees);
  }

  result = '${result.trim()} Rupees';

  if (paise > 0) {
    result += ' and ${convertChunk(paise)} Paise';
  }

  return '$result Only';
}

String _buildStaffPayslipHtmlTemplate({required Map<String, dynamic> payslip}) {
  final staffName = payslip['staff_name']?.toString() ?? 'Faculty Member';
  final empId = payslip['employee_id']?.toString() ?? 'EMP-001';
  final designation = payslip['designation']?.toString() ?? 'Senior Faculty';
  final department = payslip['department']?.toString() ?? 'Academic & Teaching';
  final payslipNum = payslip['payslip_number']?.toString() ?? 'PS-2026-10-0001';
  final monthStr = payslip['month_str']?.toString() ?? '2026-10';

  final bpay = (payslip['basic_pay'] as num?)?.toDouble() ?? 45000.0;
  final hra = (payslip['hra'] as num?)?.toDouble() ?? 18000.0;
  final da = (payslip['da'] as num?)?.toDouble() ?? 7000.0;
  final ta = (payslip['ta'] as num?)?.toDouble() ?? 4000.0;
  final special = (payslip['special_allowance'] as num?)?.toDouble() ?? 3000.0;
  final medical = (payslip['medical_allowance'] as num?)?.toDouble() ?? 0.0;
  final bonus = (payslip['bonus'] as num?)?.toDouble() ?? 0.0;
  final gross = bpay + hra + da + ta + special + medical + bonus;

  final pf = (payslip['pf_deduction'] as num?)?.toDouble() ?? 5400.0;
  final tds = (payslip['tds'] as num?)?.toDouble() ?? 3850.0;
  final ptax = (payslip['professional_tax'] as num?)?.toDouble() ?? 200.0;
  final insurance = (payslip['insurance_deduction'] as num?)?.toDouble() ?? 0.0;
  final advDed = (payslip['advance_deduction'] as num?)?.toDouble() ?? 0.0;
  final otherDed = (payslip['other_deductions'] as num?)?.toDouble() ?? 0.0;
  final totalDed = pf + tds + ptax + insurance + advDed + otherDed;
  final net = gross - totalDed;

  final pMode = payslip['payment_mode']?.toString() ?? 'Direct Bank Transfer (NEFT/RTGS)';
  final txnRef = payslip['transaction_reference']?.toString() ?? 'UTR-DISBURSED';
  final pDate = payslip['payment_date']?.toString().split('T')[0] ?? DateFormat('dd-MM-yyyy').format(DateTime.now());
  final bankName = payslip['bank_name']?.toString() ?? 'State Bank of India';
  final accNum = payslip['account_number']?.toString() ?? '100200300400';
  final ifsc = payslip['ifsc_code']?.toString() ?? 'SBIN0001234';
  final pan = payslip['pan_number']?.toString() ?? 'ABCDE1234F';
  final instName = payslip['institution_name']?.toString() ?? 'EduSHAMIIT International Institute';

  final fmt = NumberFormat('#,##,###.00');
  final netInWords = _numberToIndianWords(net);

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Payslip - $payslipNum</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm 14mm;
    }
    @media print {
      body {
        margin: 0 !important;
        padding: 0 !important;
        background: #ffffff !important;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
      .no-print {
        display: none !important;
      }
      .payslip-wrapper {
        box-shadow: none !important;
        border: 1.5px solid #0f172a !important;
        page-break-inside: avoid !important;
        margin: 0 !important;
      }
    }
    body {
      margin: 0;
      padding: 24px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #f1f5f9;
      color: #0f172a;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .payslip-wrapper {
      width: 100%;
      max-width: 800px;
      background: #ffffff;
      border: 1.5px solid #0f172a;
      border-radius: 6px;
      box-shadow: 0 8px 24px rgba(0,0,0,0.08);
      padding: 28px 32px;
      box-sizing: border-box;
    }
    .inst-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      border-bottom: 2px solid #0f172a;
      padding-bottom: 14px;
      margin-bottom: 16px;
    }
    .brand-section {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .brand-logo {
      width: 48px;
      height: 48px;
      border-radius: 8px;
      background: #0f172a;
      color: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 800;
      font-size: 22px;
    }
    .brand-titles h1 {
      margin: 0;
      font-size: 18px;
      font-weight: 800;
      color: #0f172a;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .brand-titles p {
      margin: 3px 0 0;
      font-size: 11px;
      color: #475569;
    }
    .payslip-badge-block {
      text-align: right;
    }
    .payslip-badge {
      display: inline-block;
      background: #0f172a;
      color: #ffffff;
      font-size: 11px;
      font-weight: 700;
      padding: 5px 12px;
      border-radius: 4px;
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }
    .payslip-ref-info {
      margin-top: 4px;
      font-size: 11px;
      font-weight: 600;
      color: #334155;
    }
    .emp-meta-box {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 10px 16px;
      background: #f8fafc;
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      padding: 12px 16px;
      margin-bottom: 18px;
    }
    .emp-col {
      font-size: 11px;
    }
    .col-lbl {
      color: #64748b;
      font-size: 9.5px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.4px;
      margin-bottom: 2px;
    }
    .col-val {
      color: #0f172a;
      font-size: 12px;
      font-weight: 700;
    }
    .salary-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 16px;
    }
    .salary-table th {
      background: #0f172a;
      color: #ffffff;
      padding: 8px 12px;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .salary-table td {
      padding: 7px 12px;
      font-size: 11.5px;
      border-bottom: 1px solid #e2e8f0;
      border-right: 1px solid #e2e8f0;
    }
    .salary-table td:first-child {
      border-left: 1px solid #e2e8f0;
    }
    .amt-col {
      text-align: right;
      font-weight: 600;
      font-family: 'Courier New', Courier, monospace;
    }
    .row-total td {
      background: #f1f5f9;
      font-weight: 800;
      border-top: 1.5px solid #0f172a;
      border-bottom: 1.5px solid #0f172a;
    }
    .net-salary-card {
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: #f0fdf4;
      border: 1.5px solid #16a34a;
      border-radius: 6px;
      padding: 14px 20px;
      margin-bottom: 14px;
    }
    .net-salary-title {
      font-size: 12px;
      font-weight: 800;
      color: #166534;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .net-salary-words {
      margin-top: 3px;
      font-size: 11px;
      color: #15803d;
      font-weight: 600;
      font-style: italic;
    }
    .net-salary-number {
      font-size: 24px;
      font-weight: 900;
      color: #15803d;
      font-family: 'Courier New', Courier, monospace;
    }
    .loan-alert {
      background: #fffbeb;
      border: 1px solid #fde68a;
      border-radius: 4px;
      padding: 8px 12px;
      font-size: 11px;
      color: #92400e;
      font-weight: 600;
      margin-bottom: 16px;
    }
    .sign-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
      padding-top: 36px;
      margin-top: 20px;
      border-top: 1px dashed #cbd5e1;
    }
    .sign-block {
      text-align: center;
      width: 220px;
    }
    .sign-divider {
      border-top: 1.5px solid #0f172a;
      margin-bottom: 6px;
    }
    .sign-desc {
      font-size: 10px;
      font-weight: 700;
      color: #334155;
      text-transform: uppercase;
    }
    .digital-seal {
      border: 1.5px solid #16a34a;
      color: #16a34a;
      background: #f0fdf4;
      padding: 4px 10px;
      border-radius: 4px;
      font-size: 9.5px;
      font-weight: 800;
      letter-spacing: 0.8px;
      text-transform: uppercase;
      display: inline-block;
      margin-bottom: 6px;
    }
    .payslip-footer-note {
      margin-top: 18px;
      text-align: center;
      font-size: 9.5px;
      color: #64748b;
      border-top: 1px solid #f1f5f9;
      padding-top: 8px;
    }
  </style>
  <script>
    function triggerPrintDialog() {
      try {
        window.focus();
        window.print();
      } catch (err) {
        console.warn('[EduSHAMIIT Payslip Print] Auto-print notice:', err);
      }
    }
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      setTimeout(triggerPrintDialog, 250);
    } else {
      window.addEventListener('DOMContentLoaded', function() { setTimeout(triggerPrintDialog, 250); });
      window.addEventListener('load', function() { setTimeout(triggerPrintDialog, 250); });
    }
  </script>
</head>
<body>
  <div class="no-print" style="width: 100%; max-width: 800px; margin-bottom: 14px; background: #0f172a; color: #ffffff; padding: 12px 18px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(0,0,0,0.15); font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
    <div style="display: flex; align-items: center; gap: 8px;">
      <span style="font-size: 18px;">📄</span>
      <div>
        <div style="font-size: 13px; font-weight: 800;">Official Salary Payslip</div>
        <div style="font-size: 10px; color: #94a3b8;">EduSHAMIIT Institutional Payroll</div>
      </div>
    </div>
    <div style="display: flex; gap: 8px;">
      <button onclick="window.focus(); window.print();" style="background: #16a34a; color: #ffffff; border: none; padding: 7px 16px; border-radius: 6px; font-size: 12px; font-weight: 700; cursor: pointer;">
        Print Payslip
      </button>
      <button onclick="window.close();" style="background: #334155; color: #ffffff; border: none; padding: 7px 14px; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer;">
        Close
      </button>
    </div>
  </div>
  <div class="payslip-wrapper">
    <!-- Institution Header -->
    <div class="inst-header">
      <div class="brand-section">
        <div class="brand-logo">E</div>
        <div class="brand-titles">
          <h1>$instName</h1>
          <p>Institutional Payroll & Human Resources Center | Finance Suite</p>
        </div>
      </div>
      <div class="payslip-badge-block">
        <div class="payslip-badge">Salary Payslip</div>
        <div class="payslip-ref-info">Period: $monthStr | $payslipNum</div>
      </div>
    </div>

    <!-- Employee & Banking Profile Grid -->
    <div class="emp-meta-box">
      <div class="emp-col">
        <div class="col-lbl">Employee Name</div>
        <div class="col-val">$staffName</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Employee ID</div>
        <div class="col-val">$empId</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Designation</div>
        <div class="col-val">$designation</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Department</div>
        <div class="col-val">$department</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Bank Name</div>
        <div class="col-val">$bankName</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Account Number</div>
        <div class="col-val">${accNum.length > 4 ? "•••• ${accNum.substring(accNum.length - 4)}" : accNum}</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">IFSC Code</div>
        <div class="col-val">$ifsc</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">PAN / Tax ID</div>
        <div class="col-val">$pan</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Payment Mode</div>
        <div class="col-val">$pMode</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Transaction Ref / UTR</div>
        <div class="col-val">$txnRef</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Disbursal Date</div>
        <div class="col-val">$pDate</div>
      </div>
      <div class="emp-col">
        <div class="col-lbl">Payable Days</div>
        <div class="col-val">30 / 30 Days</div>
      </div>
    </div>

    <!-- Earnings & Deductions Dual Table -->
    <table class="salary-table">
      <thead>
        <tr>
          <th style="width: 32%;">Earnings & Allowances</th>
          <th style="width: 18%;" class="amt-col">Amount (INR)</th>
          <th style="width: 32%;">Deductions & Recoveries</th>
          <th style="width: 18%;" class="amt-col">Amount (INR)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Basic Salary</td>
          <td class="amt-col">₹ ${fmt.format(bpay)}</td>
          <td>Provident Fund (PF)</td>
          <td class="amt-col">₹ ${fmt.format(pf)}</td>
        </tr>
        <tr>
          <td>House Rent Allowance (HRA)</td>
          <td class="amt-col">₹ ${fmt.format(hra)}</td>
          <td>Tax Deducted at Source (TDS)</td>
          <td class="amt-col">₹ ${fmt.format(tds)}</td>
        </tr>
        <tr>
          <td>Dearness Allowance (DA)</td>
          <td class="amt-col">₹ ${fmt.format(da)}</td>
          <td>Professional Tax (PTax)</td>
          <td class="amt-col">₹ ${fmt.format(ptax)}</td>
        </tr>
        <tr>
          <td>Travel Allowance (TA)</td>
          <td class="amt-col">₹ ${fmt.format(ta)}</td>
          <td>Advance Loan Recovery (EMI)</td>
          <td class="amt-col" style="${advDed > 0 ? 'color: #b45309; font-weight: 700;' : ''}">₹ ${fmt.format(advDed)}</td>
        </tr>
        <tr>
          <td>Special Allowance</td>
          <td class="amt-col">₹ ${fmt.format(special)}</td>
          <td>Other Deductions / LOP</td>
          <td class="amt-col">₹ ${fmt.format(otherDed)}</td>
        </tr>
        <tr>
          <td>Medical Allowance</td>
          <td class="amt-col">₹ ${fmt.format(medical)}</td>
          <td>Insurance / Health Scheme (ESI)</td>
          <td class="amt-col">₹ ${fmt.format(insurance)}</td>
        </tr>
        <tr>
          <td>Performance Bonus / Arrears</td>
          <td class="amt-col">₹ ${fmt.format(bonus)}</td>
          <td>&nbsp;</td>
          <td class="amt-col">&nbsp;</td>
        </tr>
        <tr class="row-total">
          <td>Total Gross Earnings</td>
          <td class="amt-col" style="color: #166534;">₹ ${fmt.format(gross)}</td>
          <td>Total Deductions</td>
          <td class="amt-col" style="color: #991b1b;">₹ ${fmt.format(totalDed)}</td>
        </tr>
      </tbody>
    </table>

    <!-- Net Salary Highlight Card -->
    <div class="net-salary-card">
      <div>
        <div class="net-salary-title">Net Take-Home Salary Transferred</div>
        <div class="net-salary-words">$netInWords</div>
      </div>
      <div class="net-salary-number">₹ ${fmt.format(net)}</div>
    </div>

    <!-- Advance Repayment Callout if applicable -->
    ${advDed > 0 ? '''
    <div class="loan-alert">
      ✓ Note: Salary advance loan deduction of ₹ ${fmt.format(advDed)} has been credited to employee's active loan balance (FIFO) under EduSHAMIIT Ledger.
    </div>
    ''' : ''}

    <!-- Signatures Section -->
    <div class="sign-row">
      <div class="sign-block">
        <div class="sign-divider"></div>
        <div class="sign-desc">Employee Signature / Acknowledgment</div>
      </div>
      <div class="sign-block">
        <div class="digital-seal">✓ Digitally Verified & Disbursed</div>
        <div class="sign-divider"></div>
        <div class="sign-desc">Authorized Signatory / Finance Controller</div>
      </div>
    </div>

    <!-- Legal Footer -->
    <div class="payslip-footer-note">
      This is a computer-generated salary advice authenticated via EduSHAMIIT Financial ERP SSOT. System timestamp: $pDate.
    </div>
  </div>
</body>
</html>''';
}

String _buildStudentFeeReceiptHtmlTemplate({
  required String receiptNumber,
  required String studentName,
  String? className,
  String? rollNumber,
  String? roomNumber,
  String? hostelName,
  required double amount,
  required String paymentMethod,
  required String transactionRef,
  required String paymentDate,
  String? institutionName,
  String? campusName,
}) {
  final inst = institutionName ?? 'EduSHAMIIT';
  final cName = className ?? 'Enrolled Student';
  final rNumber = rollNumber ?? '101';
  final formattedAmount = amount.toStringAsFixed(2);

  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Receipt - $receiptNumber</title>
  <style>
    @page {
      size: 80mm auto;
      margin: 2mm 3mm;
    }
    @media print {
      body {
        margin: 0 !important;
        padding: 0 !important;
        background: #ffffff !important;
        -webkit-print-color-adjust: exact !important;
        print-color-adjust: exact !important;
      }
      .no-print {
        display: none !important;
      }
      .receipt-container {
        box-shadow: none !important;
        border: none !important;
        width: 100% !important;
        max-width: 80mm !important;
        padding: 4px !important;
        margin: 0 auto !important;
      }
    }
    body {
      margin: 0;
      padding: 16px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, monospace, sans-serif;
      background: #f1f5f9;
      color: #0f172a;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .receipt-container {
      width: 80mm;
      max-width: 380px;
      background: #ffffff;
      padding: 24px 20px;
      border-radius: 8px;
      border: 1px solid #e2e8f0;
      box-shadow: 0 4px 14px rgba(0,0,0,0.08);
      box-sizing: border-box;
    }
    .center {
      text-align: center;
    }
    .logo-badge {
      display: inline-block;
      width: 44px;
      height: 44px;
      line-height: 44px;
      background: rgba(37, 99, 235, 0.1);
      border-radius: 50%;
      color: #2563eb;
      font-size: 24px;
      margin-bottom: 8px;
    }
    .brand-title {
      font-size: 16px;
      font-weight: 900;
      letter-spacing: 1.2px;
      margin: 0 0 2px 0;
      color: #0f172a;
    }
    .brand-subtitle {
      font-size: 9.5px;
      font-weight: 600;
      color: #64748b;
      letter-spacing: 0.8px;
      margin: 0 0 4px 0;
    }
    .copy-type {
      font-size: 9px;
      font-weight: 700;
      color: #2563eb;
      letter-spacing: 0.5px;
      margin: 0 0 12px 0;
    }
    .dashed-line {
      border: none;
      border-top: 1.5px dashed #cbd5e1;
      margin: 12px 0;
    }
    .row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      font-size: 11px;
      line-height: 1.5;
      margin-bottom: 5px;
    }
    .lbl {
      color: #64748b;
    }
    .val {
      font-weight: 600;
      color: #0f172a;
      text-align: right;
    }
    .bold {
      font-weight: 800;
    }
    .table-head {
      font-size: 10px;
      font-weight: 800;
      color: #0f172a;
      letter-spacing: 0.5px;
      margin: 8px 0 6px 0;
    }
    .total-box {
      border-top: 1.5px solid #0f172a;
      border-bottom: 1.5px solid #0f172a;
      padding: 8px 0;
      margin: 12px 0;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .total-lbl {
      font-size: 12.5px;
      font-weight: 900;
      color: #0f172a;
    }
    .total-val {
      font-size: 14.5px;
      font-weight: 900;
      color: #16a34a;
    }
    .status-badge {
      display: inline-block;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 10px;
      font-weight: 800;
      background: #dcfce7;
      color: #16a34a;
    }
    .barcode-block {
      text-align: center;
      margin-top: 14px;
    }
    .barcode-text {
      font-size: 14px;
      letter-spacing: 4px;
      font-weight: 900;
      color: #0f172a;
      margin-bottom: 4px;
    }
    .foot-text {
      font-size: 8.5px;
      color: #64748b;
      margin: 2px 0;
    }
    .foot-sub {
      font-size: 8px;
      color: #94a3b8;
      margin: 2px 0;
    }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() {
        try {
          window.focus();
          window.print();
        } catch (e) {
          console.warn('[EduSHAMIIT Receipt Print] Auto-print notice:', e);
        }
      }, 350);
    });
  </script>
</head>
<body>
  <div class="no-print" style="width: 100%; max-width: 380px; margin-bottom: 14px; background: #0f172a; color: #ffffff; padding: 10px 14px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; box-shadow: 0 4px 12px rgba(0,0,0,0.15); font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
    <div style="display: flex; align-items: center; gap: 8px;">
      <span style="font-size: 16px;">🖨️</span>
      <div>
        <div style="font-size: 12px; font-weight: 800; letter-spacing: 0.3px;">Thermal Receipt (80mm)</div>
        <div style="font-size: 9.5px; color: #94a3b8;">EduSHAMIIT Official Receipt</div>
      </div>
    </div>
    <div style="display: flex; gap: 6px;">
      <button onclick="window.focus(); window.print();" style="background: #2563eb; color: #ffffff; border: none; padding: 6px 12px; border-radius: 5px; font-size: 11px; font-weight: 700; cursor: pointer;">
        Print Slip
      </button>
      <button onclick="window.close();" style="background: #334155; color: #ffffff; border: none; padding: 6px 10px; border-radius: 5px; font-size: 11px; font-weight: 600; cursor: pointer;">
        Close
      </button>
    </div>
  </div>
  <div class="receipt-container">
    <div class="center">
      <div class="logo-badge">&#127891;</div>
      <div class="brand-title">$inst CAMPUS</div>
      <div class="brand-subtitle">STUDENT ACCOUNTS & FEE ADMINISTRATION</div>
      <div class="copy-type">OFFICIAL RECEIPT (STUDENT COPY)</div>
    </div>

    <hr class="dashed-line">

    <div class="row">
      <span class="lbl">Receipt No:</span>
      <span class="val bold">$receiptNumber</span>
    </div>
    <div class="row">
      <span class="lbl">Date & Time:</span>
      <span class="val">$paymentDate</span>
    </div>
    <div class="row">
      <span class="lbl">Student:</span>
      <span class="val bold">$studentName</span>
    </div>
    <div class="row">
      <span class="lbl">Class / Roll:</span>
      <span class="val">$cName | Roll: $rNumber</span>
    </div>

    <hr class="dashed-line">

    <div class="row table-head">
      <span>DESCRIPTION</span>
      <span>AMOUNT (INR)</span>
    </div>
    <div class="row">
      <span class="lbl">Tuition & Campus Fees</span>
      <span class="val">₹ $formattedAmount</span>
    </div>

    <div class="total-box">
      <span class="total-lbl">TOTAL PAID:</span>
      <span class="total-val">₹ $formattedAmount</span>
    </div>

    <div class="row">
      <span class="lbl">Payment Mode:</span>
      <span class="val bold">$paymentMethod</span>
    </div>
    <div class="row">
      <span class="lbl">Txn Reference:</span>
      <span class="val">$transactionRef</span>
    </div>
    <div class="row">
      <span class="lbl">Payment Status:</span>
      <span class="val"><span class="status-badge">SUCCESS / CLEARED</span></span>
    </div>

    <hr class="dashed-line">

    <div class="barcode-block">
      <div class="barcode-text">*$receiptNumber*</div>
      <div class="foot-text">Computer generated digital receipt.</div>
      <div class="foot-sub">Verified by EduSHAMIIT Financial Subsystem</div>
    </div>
  </div>
</body>
</html>''';
}

void printStudentFeeReceiptHtml({
  required String receiptNumber,
  required String studentName,
  String? className,
  String? rollNumber,
  String? roomNumber,
  String? hostelName,
  required double amount,
  required String paymentMethod,
  required String transactionRef,
  required String paymentDate,
  String? institutionName,
  String? campusName,
}) {
  try {
    final htmlContent = _buildStudentFeeReceiptHtmlTemplate(
      receiptNumber: receiptNumber,
      studentName: studentName,
      className: className,
      rollNumber: rollNumber,
      roomNumber: roomNumber,
      hostelName: hostelName,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionRef: transactionRef,
      paymentDate: paymentDate,
      institutionName: institutionName,
      campusName: campusName,
    );
    _printHtmlViaIframe(htmlContent);
  } catch (e) {
    debugPrint('[JSHelper] Error printing fee receipt: $e');
  }
}

void downloadStudentFeeReceiptHtml({
  required String receiptNumber,
  required String studentName,
  String? className,
  String? rollNumber,
  String? roomNumber,
  String? hostelName,
  required double amount,
  required String paymentMethod,
  required String transactionRef,
  required String paymentDate,
  String? institutionName,
  String? campusName,
}) {
  try {
    final htmlContent = _buildStudentFeeReceiptHtmlTemplate(
      receiptNumber: receiptNumber,
      studentName: studentName,
      className: className,
      rollNumber: rollNumber,
      roomNumber: roomNumber,
      hostelName: hostelName,
      amount: amount,
      paymentMethod: paymentMethod,
      transactionRef: transactionRef,
      paymentDate: paymentDate,
      institutionName: institutionName,
      campusName: campusName,
    );
    _downloadBlobContent(htmlContent, 'Receipt_$receiptNumber.html', 'text/html;charset=utf-8');
  } catch (e) {
    debugPrint('[JSHelper] Error downloading fee receipt: $e');
  }
}

void downloadCsvWeb(String content, String filename) {
  _downloadBlobContent(content, filename, 'text/csv;charset=utf-8;');
}

void printHostelGatePassHtml({
  required String passNumber,
  required String studentName,
  required String requestType,
  String? studentClass,
  String? rollNumber,
  String? hostelName,
  String? roomNumber,
  String? destination,
  String? reason,
  String? validFrom,
  String? validUntil,
  String? parentPhone,
  bool isThermal = false,
  String? qrBase64,
}) {
  try {
    final html = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Hostel Gate Pass $passNumber</title>
  <style>
    @page { size: auto; margin: 8mm; }
    @media print { .no-print { display: none !important; } }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 16px; color: #0f172a; }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.focus(); window.print(); }, 300);
    });
  </script>
</head>
<body>
  <div class="no-print" style="margin-bottom: 12px;">
    <button onclick="window.focus(); window.print();" style="background: #2563eb; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer;">Print</button>
    <button onclick="window.close();" style="background: #475569; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;">Close</button>
  </div>
  <h1>Hostel Gate Pass $passNumber</h1>
  <p><strong>Student:</strong> $studentName</p>
  <p><strong>Type:</strong> $requestType</p>
  <p><strong>Hostel:</strong> $hostelName | <strong>Room:</strong> $roomNumber</p>
  <p><strong>Valid:</strong> $validFrom - $validUntil</p>
  <p><strong>Destination:</strong> $destination</p>
  <p><strong>Reason:</strong> $reason</p>
</body>
</html>''';
    _printHtmlDocument(html, title: 'Hostel Gate Pass $passNumber');
  } catch (e) {
    debugPrint('[JSHelper] Error printing gate pass: $e');
  }
}

void printHostelReportHtml({
  required String reportTitle,
  required String academicYear,
  required List<String> columns,
  required List<Map<String, dynamic>> records,
}) {
  try {
    final html = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$reportTitle</title>
  <style>
    @page { size: auto; margin: 8mm; }
    @media print { .no-print { display: none !important; } }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 16px; color: #0f172a; }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.focus(); window.print(); }, 300);
    });
  </script>
</head>
<body>
  <div class="no-print" style="margin-bottom: 12px;">
    <button onclick="window.focus(); window.print();" style="background: #2563eb; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer;">Print</button>
    <button onclick="window.close();" style="background: #475569; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;">Close</button>
  </div>
  <h1>$reportTitle</h1>
  <p><strong>Academic Year:</strong> $academicYear</p>
  <p><strong>Total Records:</strong> ${records.length}</p>
</body>
</html>''';
    _printHtmlDocument(html, title: reportTitle);
  } catch (e) {
    debugPrint('[JSHelper] Error printing hostel report: $e');
  }
}

void printVisitorGatePassHtml({
  required String passNumber,
  required String visitorName,
  required String visitorType,
  String? phone,
  String? destination,
  String? hostName,
  String? hostDepartment,
  String? checkInAt,
  String? validUntil,
  String? qrBase64,
  bool isThermal = false,
}) {
  try {
    final html = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Visitor Gate Pass $passNumber</title>
  <style>
    @page { size: auto; margin: 8mm; }
    @media print { .no-print { display: none !important; } }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 16px; color: #0f172a; }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.focus(); window.print(); }, 300);
    });
  </script>
</head>
<body>
  <div class="no-print" style="margin-bottom: 12px;">
    <button onclick="window.focus(); window.print();" style="background: #2563eb; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer;">Print</button>
    <button onclick="window.close();" style="background: #475569; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;">Close</button>
  </div>
  <h1>Visitor Gate Pass $passNumber</h1>
  <p><strong>Visitor:</strong> $visitorName ($visitorType)</p>
  <p><strong>Host:</strong> $hostName ($hostDepartment)</p>
  <p><strong>Destination:</strong> $destination</p>
  <p><strong>Check-in:</strong> $checkInAt | <strong>Valid Until:</strong> $validUntil</p>
</body>
</html>''';
    _printHtmlDocument(html, title: 'Visitor Gate Pass $passNumber');
  } catch (e) {
    debugPrint('[JSHelper] Error printing visitor gate pass: $e');
  }
}

void printMultipleVisitorGatePassesHtml({
  required List<Map<String, dynamic>> passes,
}) {
  try {
    final html = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Batch Visitor Gate Passes</title>
  <style>
    @page { size: auto; margin: 8mm; }
    @media print { .no-print { display: none !important; } }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 16px; color: #0f172a; }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.focus(); window.print(); }, 300);
    });
  </script>
</head>
<body>
  <div class="no-print" style="margin-bottom: 12px;">
    <button onclick="window.focus(); window.print();" style="background: #2563eb; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer;">Print</button>
    <button onclick="window.close();" style="background: #475569; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;">Close</button>
  </div>
  <h1>Batch Visitor Gate Passes</h1>
  <p><strong>Total Passes:</strong> ${passes.length}</p>
</body>
</html>''';
    _printHtmlDocument(html, title: 'Batch Visitor Gate Passes');
  } catch (e) {
    debugPrint('[JSHelper] Error printing multiple visitor gate passes: $e');
  }
}

void printExecutiveSummaryHtml({
  required dynamic report,
}) {
  try {
    final html = '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Executive Summary Report</title>
  <style>
    @page { size: auto; margin: 8mm; }
    @media print { .no-print { display: none !important; } }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 16px; color: #0f172a; }
  </style>
  <script>
    window.addEventListener('load', function() {
      setTimeout(function() { window.focus(); window.print(); }, 300);
    });
  </script>
</head>
<body>
  <div class="no-print" style="margin-bottom: 12px;">
    <button onclick="window.focus(); window.print();" style="background: #2563eb; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer;">Print</button>
    <button onclick="window.close();" style="background: #475569; color: white; border: none; padding: 6px 12px; border-radius: 4px; cursor: pointer;">Close</button>
  </div>
  <h1>Executive Summary Report</h1>
  <pre>$report</pre>
</body>
</html>''';
    _printHtmlDocument(html, title: 'Executive Summary Report');
  } catch (e) {
    debugPrint('[JSHelper] Error printing executive summary: $e');
  }
}

void printCampusInstitutionalDossierHtml({
  required String reportTitle,
  required String period,
  required String facilityScope,
  required List<String> kpiTitles,
  required List<String> kpiValues,
  required List<String> headers,
  required List<List<String>> rows,
}) {
  try {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final kpiCardsHtml = StringBuffer();
    for (int i = 0; i < kpiTitles.length; i++) {
      final val = i < kpiValues.length ? kpiValues[i] : '-';
      kpiCardsHtml.write('''
        <div style="flex: 1; min-width: 150px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 16px; margin: 6px;">
          <div style="font-size: 11px; color: #64748b; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">${kpiTitles[i]}</div>
          <div style="font-size: 20px; font-weight: 700; color: #0f172a; margin-top: 4px;">$val</div>
        </div>
      ''');
    }

    final tableHeadersHtml = headers.map((h) => '<th style="padding: 10px 12px; background: #0f172a; color: #ffffff; text-align: left; font-size: 12px; font-weight: 600; border: 1px solid #334155;">$h</th>').join();

    final tableRowsHtml = StringBuffer();
    for (int r = 0; r < rows.length; r++) {
      final bg = r % 2 == 0 ? '#ffffff' : '#f8fafc';
      final cells = rows[r].map((c) => '<td style="padding: 9px 12px; border: 1px solid #e2e8f0; font-size: 11.5px; color: #334155;">$c</td>').join();
      tableRowsHtml.write('<tr style="background: $bg;">$cells</tr>');
    }

    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>$reportTitle - EduSHAMIIT Executive Dossier</title>
        <meta charset="utf-8">
        <style>
          @page { size: A4 landscape; margin: 12mm 15mm; }
          @media print { .no-print { display: none !important; } }
          body { font-family: 'Segoe UI', Helvetica, Arial, sans-serif; margin: 0; color: #0f172a; background: #fff; }
          .header { border-bottom: 2px solid #2563eb; padding-bottom: 14px; margin-bottom: 18px; display: flex; justify-content: space-between; align-items: flex-start; }
          .title { font-size: 22px; font-weight: 800; color: #1e3a8a; }
          .subtitle { font-size: 12px; color: #64748b; margin-top: 3px; }
          .meta { text-align: right; font-size: 11.5px; color: #475569; }
          .meta strong { color: #0f172a; }
          .kpi-container { display: flex; flex-wrap: wrap; margin-bottom: 18px; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
          .footer { margin-top: 30px; display: flex; justify-content: space-between; font-size: 11px; color: #64748b; border-top: 1px solid #e2e8f0; padding-top: 12px; }
          .sign-block { width: 180px; text-align: center; border-top: 1px dashed #94a3b8; padding-top: 6px; font-weight: 600; font-size: 11.5px; }
        </style>
        <script>
          window.addEventListener('load', function() {
            setTimeout(function() { window.focus(); window.print(); }, 300);
          });
        </script>
      </head>
      <body style="padding: 16px;">
        <div class="no-print" style="margin-bottom: 14px;">
          <button onclick="window.focus(); window.print();" style="background: #2563eb; color: white; border: none; padding: 7px 16px; border-radius: 4px; cursor: pointer; font-weight: 700;">Print Dossier</button>
          <button onclick="window.close();" style="background: #475569; color: white; border: none; padding: 7px 12px; border-radius: 4px; cursor: pointer;">Close</button>
        </div>
        <div class="header">
          <div>
            <div class="title">EduSHAMIIT Institutional Facility & Infrastructure Audit</div>
            <div class="subtitle">$reportTitle • Certified Compliance Dossier</div>
          </div>
          <div class="meta">
            <div>Scope: <strong>$facilityScope</strong></div>
            <div>Audit Period: <strong>$period</strong></div>
            <div>Generated: <strong>$dateStr</strong></div>
          </div>
        </div>

        <div class="kpi-container">
          $kpiCardsHtml
        </div>

        <table>
          <thead>
            <tr>$tableHeadersHtml</tr>
          </thead>
          <tbody>
            $tableRowsHtml
          </tbody>
        </table>

        <div style="margin-top: 40px; display: flex; justify-content: space-around;">
          <div class="sign-block">Campus Facility Director</div>
          <div class="sign-block">Statutory Compliance Auditor</div>
          <div class="sign-block">Principal / Head of Institution</div>
        </div>

        <div class="footer">
          <div>EduSHAMIIT ERP • Secure Institutional Infrastructure System</div>
          <div>Confidential — For Internal & Board Regulatory Use Only</div>
        </div>
      </body>
      </html>
    ''';

    _printHtmlDocument(html, title: reportTitle);
  } catch (e) {
    debugPrint('[JSHelper] Error printing campus dossier: $e');
  }
}

void setupMediaStreamInterception() {
  try {
    js.context.callMethod('eval', [
      '''
      (function() {
        if (window._eduMediaInterceptionInitialized) return;
        window._eduMediaInterceptionInitialized = true;
        window._activeEduStreams = window._activeEduStreams || [];

        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
          const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
          navigator.mediaDevices.getUserMedia = async function(constraints) {
            const stream = await originalGetUserMedia(constraints);
            if (stream) {
              window._activeEduStreams.push(stream);
              const cleanUp = () => {
                window._activeEduStreams = window._activeEduStreams.filter(s => s !== stream);
              };
              stream.addEventListener('inactive', cleanUp);
              stream.getTracks().forEach(t => t.addEventListener('ended', cleanUp));
            }
            return stream;
          };
        }

        if (navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia) {
          const originalGetDisplayMedia = navigator.mediaDevices.getDisplayMedia.bind(navigator.mediaDevices);
          navigator.mediaDevices.getDisplayMedia = async function(constraints) {
            const stream = await originalGetDisplayMedia(constraints);
            if (stream) {
              window._activeEduStreams.push(stream);
              const cleanUp = () => {
                window._activeEduStreams = window._activeEduStreams.filter(s => s !== stream);
              };
              stream.addEventListener('inactive', cleanUp);
              stream.getTracks().forEach(t => t.addEventListener('ended', cleanUp));
            }
            return stream;
          };
        }

        window._eduReleaseHardwareMediaTracks = function(releaseVideo, releaseAudio) {
          try {
            const recMixer = window._eduRecorderAudioMixer;
            const recDestStream = recMixer && recMixer.dest ? recMixer.dest.stream : null;
            const recCanvasStream = window._eduRecorderCanvasStream || null;
            const isProtectedRecStream = (s) => !s || s === recDestStream || s === recCanvasStream || (s._isEduRecorderStream === true);
            const isScreenShareTrack = (t) => {
              try {
                const lbl = (t.label || '').toLowerCase();
                if (lbl.includes('screen') || lbl.includes('window') || lbl.includes('display') || lbl.includes('monitor') || lbl.includes('tab')) {
                  return true;
                }
                const st = typeof t.getSettings === 'function' ? t.getSettings() : {};
                return !!(st && st.displaySurface);
              } catch (_) { return false; }
            };

            // 1. Release active streams recorded by interception
            if (window._activeEduStreams && Array.isArray(window._activeEduStreams)) {
              window._activeEduStreams.forEach(stream => {
                if (isProtectedRecStream(stream)) return;
                try {
                  if (releaseVideo) {
                    stream.getVideoTracks().forEach(track => {
                      // When toggling Camera OFF, never kill an active Screen Share track
                      if (!releaseAudio && isScreenShareTrack(track)) return;
                      try {
                        track.enabled = false;
                        track.stop();
                      } catch (e) {}
                    });
                  }
                  if (releaseAudio) {
                    stream.getAudioTracks().forEach(track => {
                      try {
                        track.enabled = false;
                        track.stop();
                      } catch (e) {}
                    });
                  }
                } catch (e) {}
              });
              window._activeEduStreams = window._activeEduStreams.filter(stream => {
                try {
                  return stream.getTracks().some(t => t.readyState === 'live');
                } catch (e) {
                  return false;
                }
              });
            }

            // 2. Scan all video & audio elements in the DOM (skipping recorder preview & internal elements)
            const mediaEls = document.querySelectorAll('video, audio');
            mediaEls.forEach(el => {
              try {
                if (el.id && el.id.startsWith('rec-video-')) return;
                if (el.getAttribute && el.getAttribute('data-shamiit-recorder') === 'true') return;
                if (el.srcObject) {
                  const stream = el.srcObject;
                  if (isProtectedRecStream(stream)) return;
                  if (stream && typeof stream.getTracks === 'function') {
                    if (releaseVideo) {
                      stream.getVideoTracks().forEach(t => {
                        if (!releaseAudio && isScreenShareTrack(t)) return;
                        try {
                          t.enabled = false;
                          t.stop();
                        } catch (e) {}
                      });
                    }
                    if (releaseAudio) {
                      stream.getAudioTracks().forEach(t => {
                        try {
                          t.enabled = false;
                          t.stop();
                        } catch (e) {}
                      });
                    }
                    const remainingLiveTracks = stream.getTracks().filter(t => t.readyState === 'live');
                    if (remainingLiveTracks.length === 0) {
                      el.srcObject = null;
                    }
                  }
                }
              } catch (e) {}
            });
          } catch (e) {
            console.warn('[EduSHAMIIT] _eduReleaseHardwareMediaTracks error:', e);
          }
        };
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] setupMediaStreamInterception error: $e');
  }
}

void releaseHardwareMediaTracks({bool releaseVideo = true, bool releaseAudio = true}) {
  try {
    js.context.callMethod('eval', [
      '''
      if (typeof window._eduReleaseHardwareMediaTracks === 'function') {
        window._eduReleaseHardwareMediaTracks($releaseVideo, $releaseAudio);
      }
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] releaseHardwareMediaTracks error: $e');
  }
}





// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

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
    js.context.callMethod('eval', [
      '''
      (function() {
        const a = document.createElement('a');
        a.href = '$url';
        a.download = '$filename';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error downloading file: $e');
  }
}

void downloadStaffPayslipHtml({required Map<String, dynamic> payslip}) {
  try {
    final payslipNum = payslip['payslip_number'] ?? 'payslip';
    final html = '<html><body><h1>Payslip $payslipNum</h1><pre>$payslip</pre></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const blob = new Blob([decodeURIComponent('$encodedHtml')], {type: 'text/html'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = '$payslipNum.html';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error downloading payslip: $e');
  }
}

void printStaffPayslipHtml({required Map<String, dynamic> payslip}) {
  try {
    final payslipNum = payslip['payslip_number'] ?? 'payslip';
    final html = '<html><body><h1>Payslip $payslipNum</h1><pre>$payslip</pre></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error printing payslip: $e');
  }
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
      margin: 4mm;
    }
    @media print {
      body {
        margin: 0;
        padding: 0;
        background: #ffffff;
      }
      .receipt-container {
        box-shadow: none !important;
        border: none !important;
        width: 100% !important;
        max-width: 100% !important;
        padding: 0 !important;
      }
    }
    body {
      margin: 0;
      padding: 24px;
      font-family: 'Courier New', Courier, monospace, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f8fafc;
      color: #0f172a;
      display: flex;
      justify-content: center;
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
</head>
<body>
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
    final html = _buildStudentFeeReceiptHtmlTemplate(
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
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
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
    final html = _buildStudentFeeReceiptHtmlTemplate(
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
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const blob = new Blob([decodeURIComponent('$encodedHtml')], {type: 'text/html'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'Receipt_$receiptNumber.html';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error downloading fee receipt: $e');
  }
}

void downloadCsvWeb(String content, String filename) {
  try {
    final encoded = Uri.encodeComponent(content);
    js.context.callMethod('eval', [
      '''
      (function() {
        const blob = new Blob([decodeURIComponent('$encoded')], {type: 'text/csv;charset=utf-8;'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = '$filename';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error downloading CSV: $e');
  }
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
    final html = '<html><body><h1>Hostel Gate Pass $passNumber</h1><p>Student: $studentName</p><p>Type: $requestType</p><p>Hostel: $hostelName Room: $roomNumber</p><p>Valid: $validFrom - $validUntil</p></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
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
    final html = '<html><body><h1>$reportTitle</h1><p>Academic Year: $academicYear</p><p>Total Records: ${records.length}</p></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
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
    final html = '<html><body><h1>Visitor Gate Pass $passNumber</h1><p>Visitor: $visitorName ($visitorType)</p><p>Host: $hostName ($hostDepartment)</p><p>Destination: $destination</p></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error printing visitor gate pass: $e');
  }
}

void printMultipleVisitorGatePassesHtml({
  required List<Map<String, dynamic>> passes,
}) {
  try {
    final html = '<html><body><h1>Batch Visitor Gate Passes</h1><p>Total Passes: ${passes.length}</p></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error printing multiple visitor gate passes: $e');
  }
}

void printExecutiveSummaryHtml({
  required dynamic report,
}) {
  try {
    final html = '<html><body><h1>Executive Summary Report</h1><pre>$report</pre></body></html>';
    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
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
          <div style="font-size: 11px; color: #64748b; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px;">\${kpiTitles[i]}</div>
          <div style="font-size: 20px; font-weight: 700; color: #0f172a; margin-top: 4px;">\$val</div>
        </div>
      ''');
    }

    final tableHeadersHtml = headers.map((h) => '<th style="padding: 10px 12px; background: #0f172a; color: #ffffff; text-align: left; font-size: 12px; font-weight: 600; border: 1px solid #334155;">\$h</th>').join();

    final tableRowsHtml = StringBuffer();
    for (int r = 0; r < rows.length; r++) {
      final bg = r % 2 == 0 ? '#ffffff' : '#f8fafc';
      final cells = rows[r].map((c) => '<td style="padding: 9px 12px; border: 1px solid #e2e8f0; font-size: 11.5px; color: #334155;">\$c</td>').join();
      tableRowsHtml.write('<tr style="background: \$bg;">\$cells</tr>');
    }

    final html = '''
      <!DOCTYPE html>
      <html>
      <head>
        <title>\$reportTitle - EduSHAMIIT Executive Dossier</title>
        <meta charset="utf-8">
        <style>
          @page { size: A4 landscape; margin: 12mm 15mm; }
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
      </head>
      <body>
        <div class="header">
          <div>
            <div class="title">EduSHAMIIT Institutional Facility & Infrastructure Audit</div>
            <div class="subtitle">\$reportTitle • Certified Compliance Dossier</div>
          </div>
          <div class="meta">
            <div>Scope: <strong>\$facilityScope</strong></div>
            <div>Audit Period: <strong>\$period</strong></div>
            <div>Generated: <strong>\$dateStr</strong></div>
          </div>
        </div>

        <div class="kpi-container">
          \$kpiCardsHtml
        </div>

        <table>
          <thead>
            <tr>\$tableHeadersHtml</tr>
          </thead>
          <tbody>
            \$tableRowsHtml
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

    final encodedHtml = Uri.encodeComponent(html);
    js.context.callMethod('eval', [
      '''
      (function() {
        const printWindow = window.open('', '_blank');
        if (printWindow) {
          printWindow.document.write(decodeURIComponent('\$encodedHtml'));
          printWindow.document.close();
          printWindow.focus();
          printWindow.print();
        }
      })();
      '''
    ]);
  } catch (e) {
    debugPrint('[JSHelper] Error printing campus dossier: \$e');
  }
}




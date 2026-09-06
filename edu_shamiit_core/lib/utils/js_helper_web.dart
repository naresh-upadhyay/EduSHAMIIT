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



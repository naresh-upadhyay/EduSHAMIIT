import 'package:flutter/foundation.dart';

bool hasMediaDevices() => true;

void jsAlert(String message) {
  debugPrint('[JS Alert Stub]: $message');
}

void startWebRingtone() {}

void stopWebRingtone() {}
 
void printBookLabelHtml({
  required String title,
  required String isbn,
  required String barcode,
  required String accessionNumber,
}) {
  debugPrint('[Print Label Stub]: $title - $barcode');
}

void downloadFileWeb(String url, String filename) {
  debugPrint('[Download File Stub]: $url -> $filename');
}


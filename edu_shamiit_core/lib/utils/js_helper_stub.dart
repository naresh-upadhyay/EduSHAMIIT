import 'package:flutter/foundation.dart';

bool hasMediaDevices() => true;

void jsAlert(String message) {
  debugPrint('[JS Alert Stub]: $message');
}

void startWebRingtone() {}

void stopWebRingtone() {}

void playWebHandRaiseChime() {}

void playWebChatMessageChime() {}

void playWebParticipantChime() {}

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

void downloadCsvWeb(String content, String filename) {
  debugPrint('[Download CSV Stub]: $filename (${content.length} bytes)');
}

void downloadStaffPayslipHtml({required Map<String, dynamic> payslip}) {
  debugPrint('[Download Payslip Stub]: ${payslip['payslip_number']}');
}

void printStaffPayslipHtml({required Map<String, dynamic> payslip}) {
  debugPrint('[Print Payslip Stub]: ${payslip['payslip_number']}');
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
  debugPrint('[Print Receipt Stub]: $receiptNumber - $studentName');
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
  debugPrint('[Download Receipt Stub]: $receiptNumber - $studentName');
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
  debugPrint('[Print Hostel Gate Pass Stub]: $passNumber - $studentName');
}

void printHostelReportHtml({
  required String reportTitle,
  required String academicYear,
  required List<String> columns,
  required List<Map<String, dynamic>> records,
}) {
  debugPrint('[Print Hostel Report Stub]: $reportTitle (${records.length} records)');
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
  debugPrint('[Print Visitor Gate Pass Stub]: $passNumber - $visitorName');
}

void printMultipleVisitorGatePassesHtml({
  required List<Map<String, dynamic>> passes,
}) {
  debugPrint('[Print Multiple Visitor Gate Passes Stub]: ${passes.length} passes');
}

void printExecutiveSummaryHtml({
  required dynamic report,
}) {
  debugPrint('[Print Executive Summary Stub]: $report');
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
  debugPrint('[Print Campus Institutional Dossier Stub]: $reportTitle - $period ($facilityScope)');
}

void setupMediaStreamInterception() {}

void releaseHardwareMediaTracks({bool releaseVideo = true, bool releaseAudio = true}) {}

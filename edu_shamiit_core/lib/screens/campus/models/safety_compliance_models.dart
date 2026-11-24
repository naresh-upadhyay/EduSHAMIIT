

/// 1. Safety & Statutory Compliance Dashboard KPIs
class SafetyComplianceKpis {
  final double overallCompliancePct;
  final double complianceChangePct;
  final int activeCertificates;
  final int expiringCertificates;
  final int totalInspections;
  final double inspectionsPassedPct;
  final int actionNeededInspections;
  final int openIncidents;
  final int criticalIncidents;
  final int drillsConducted;
  final double avgEvacuationSeconds;
  final String sosReadinessStatus;

  const SafetyComplianceKpis({
    this.overallCompliancePct = 96.4,
    this.complianceChangePct = 2.3,
    this.activeCertificates = 6,
    this.expiringCertificates = 2,
    this.totalInspections = 6,
    this.inspectionsPassedPct = 83.3,
    this.actionNeededInspections = 1,
    this.openIncidents = 0,
    this.criticalIncidents = 0,
    this.drillsConducted = 2,
    this.avgEvacuationSeconds = 146.0,
    this.sosReadinessStatus = '100% Operational',
  });

  factory SafetyComplianceKpis.fromJson(Map<String, dynamic> json) {
    return SafetyComplianceKpis(
      overallCompliancePct: (json['overall_compliance_pct'] as num?)?.toDouble() ?? 96.4,
      complianceChangePct: (json['compliance_change_pct'] as num?)?.toDouble() ?? 2.3,
      activeCertificates: (json['active_certificates'] as num?)?.toInt() ?? 6,
      expiringCertificates: (json['expiring_certificates'] as num?)?.toInt() ?? 2,
      totalInspections: (json['total_inspections'] as num?)?.toInt() ?? 6,
      inspectionsPassedPct: (json['inspections_passed_pct'] as num?)?.toDouble() ?? 83.3,
      actionNeededInspections: (json['action_needed_inspections'] as num?)?.toInt() ?? 1,
      openIncidents: (json['open_incidents'] as num?)?.toInt() ?? 0,
      criticalIncidents: (json['critical_incidents'] as num?)?.toInt() ?? 0,
      drillsConducted: (json['drills_conducted'] as num?)?.toInt() ?? 2,
      avgEvacuationSeconds: (json['avg_evacuation_seconds'] as num?)?.toDouble() ?? 146.0,
      sosReadinessStatus: json['sos_readiness_status']?.toString() ?? '100% Operational',
    );
  }
}

/// 2. Safety Inspection Item
class SafetyInspectionItem {
  final String id;
  final String inspectionCode;
  final String title;
  final String category;
  final String? buildingId;
  final String? buildingName;
  final String locationDisplay;
  final String inspectorName;
  final String inspectorRole;
  final String? inspectorUserId;
  final DateTime inspectionDate;
  final String status;
  final double complianceScore;
  final String? findings;
  final List<dynamic> actionItems;
  final DateTime? nextInspectionDate;
  final DateTime createdAt;

  const SafetyInspectionItem({
    required this.id,
    required this.inspectionCode,
    required this.title,
    required this.category,
    this.buildingId,
    this.buildingName,
    required this.locationDisplay,
    required this.inspectorName,
    required this.inspectorRole,
    this.inspectorUserId,
    required this.inspectionDate,
    required this.status,
    this.complianceScore = 95.0,
    this.findings,
    this.actionItems = const [],
    this.nextInspectionDate,
    required this.createdAt,
  });

  factory SafetyInspectionItem.fromJson(Map<String, dynamic> json) {
    return SafetyInspectionItem(
      id: json['id']?.toString() ?? '',
      inspectionCode: json['inspection_code']?.toString() ?? 'SI-000',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Fire Safety',
      buildingId: json['building_id']?.toString(),
      buildingName: json['building_name']?.toString(),
      locationDisplay: json['location_display']?.toString() ?? 'Main Campus',
      inspectorName: json['inspector_name']?.toString() ?? 'Inspector',
      inspectorRole: json['inspector_role']?.toString() ?? 'Safety Officer',
      inspectorUserId: json['inspector_user_id']?.toString(),
      inspectionDate: DateTime.tryParse(json['inspection_date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'Passed',
      complianceScore: (json['compliance_score'] as num?)?.toDouble() ?? 95.0,
      findings: json['findings']?.toString(),
      actionItems: json['action_items'] is List ? json['action_items'] : const [],
      nextInspectionDate: json['next_inspection_date'] != null ? DateTime.tryParse(json['next_inspection_date'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// 3. Safety Incident Item
class SafetyIncidentItem {
  final String id;
  final String incidentCode;
  final String title;
  final String severity;
  final String incidentType;
  final String? buildingId;
  final String locationDisplay;
  final String reportedByName;
  final String reportedByRole;
  final DateTime incidentTime;
  final String status;
  final String? description;
  final String? immediateActionTaken;
  final String? preventiveMeasures;
  final int victimsCount;
  final bool firstAidProvided;
  final DateTime? resolvedAt;
  final String? resolvedByName;

  const SafetyIncidentItem({
    required this.id,
    required this.incidentCode,
    required this.title,
    required this.severity,
    required this.incidentType,
    this.buildingId,
    required this.locationDisplay,
    required this.reportedByName,
    required this.reportedByRole,
    required this.incidentTime,
    required this.status,
    this.description,
    this.immediateActionTaken,
    this.preventiveMeasures,
    this.victimsCount = 0,
    this.firstAidProvided = false,
    this.resolvedAt,
    this.resolvedByName,
  });

  factory SafetyIncidentItem.fromJson(Map<String, dynamic> json) {
    return SafetyIncidentItem(
      id: json['id']?.toString() ?? '',
      incidentCode: json['incident_code']?.toString() ?? 'INC-000',
      title: json['title']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'Medium',
      incidentType: json['incident_type']?.toString() ?? 'Other',
      buildingId: json['building_id']?.toString(),
      locationDisplay: json['location_display']?.toString() ?? 'Campus Grounds',
      reportedByName: json['reported_by_name']?.toString() ?? 'Staff',
      reportedByRole: json['reported_by_role']?.toString() ?? 'Staff',
      incidentTime: DateTime.tryParse(json['incident_time']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString() ?? 'Reported',
      description: json['description']?.toString(),
      immediateActionTaken: json['immediate_action_taken']?.toString(),
      preventiveMeasures: json['preventive_measures']?.toString(),
      victimsCount: (json['victims_count'] as num?)?.toInt() ?? 0,
      firstAidProvided: json['first_aid_provided'] == true,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      resolvedByName: json['resolved_by_name']?.toString(),
    );
  }
}

/// 4. Statutory Compliance Certificate Item
class ComplianceCertificateItem {
  final String id;
  final String certificateCode;
  final String title;
  final String category;
  final String issuingAuthority;
  final String certificateNumber;
  final String? buildingId;
  final String locationDisplay;
  final DateTime issueDate;
  final DateTime expiryDate;
  final String status;
  final int daysToExpiry;
  final String? documentUrl;
  final String? notes;

  const ComplianceCertificateItem({
    required this.id,
    required this.certificateCode,
    required this.title,
    required this.category,
    required this.issuingAuthority,
    required this.certificateNumber,
    this.buildingId,
    required this.locationDisplay,
    required this.issueDate,
    required this.expiryDate,
    required this.status,
    this.daysToExpiry = 90,
    this.documentUrl,
    this.notes,
  });

  factory ComplianceCertificateItem.fromJson(Map<String, dynamic> json) {
    return ComplianceCertificateItem(
      id: json['id']?.toString() ?? '',
      certificateCode: json['certificate_code']?.toString() ?? 'CERT-000',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Fire Safety',
      issuingAuthority: json['issuing_authority']?.toString() ?? '',
      certificateNumber: json['certificate_number']?.toString() ?? '',
      buildingId: json['building_id']?.toString(),
      locationDisplay: json['location_display']?.toString() ?? 'All Campus Buildings',
      issueDate: DateTime.tryParse(json['issue_date']?.toString() ?? '') ?? DateTime.now(),
      expiryDate: DateTime.tryParse(json['expiry_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      status: json['status']?.toString() ?? 'Valid',
      daysToExpiry: (json['days_to_expiry'] as num?)?.toInt() ?? 90,
      documentUrl: json['document_url']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

/// 5. Emergency Evacuation & Safety Drill Item
class SafetyDrillItem {
  final String id;
  final String drillCode;
  final String title;
  final String drillType;
  final String? buildingId;
  final String locationDisplay;
  final DateTime scheduledDate;
  final DateTime? conductedDate;
  final String status;
  final int participantsCount;
  final int evacuationTimeSeconds;
  final int targetTimeSeconds;
  final String coordinatorName;
  final String coordinatorRole;
  final String performanceRating;
  final String? observations;

  const SafetyDrillItem({
    required this.id,
    required this.drillCode,
    required this.title,
    required this.drillType,
    this.buildingId,
    required this.locationDisplay,
    required this.scheduledDate,
    this.conductedDate,
    required this.status,
    this.participantsCount = 0,
    this.evacuationTimeSeconds = 0,
    this.targetTimeSeconds = 180,
    required this.coordinatorName,
    this.coordinatorRole = 'Chief Safety Warden',
    this.performanceRating = 'Good',
    this.observations,
  });

  factory SafetyDrillItem.fromJson(Map<String, dynamic> json) {
    return SafetyDrillItem(
      id: json['id']?.toString() ?? '',
      drillCode: json['drill_code']?.toString() ?? 'DRL-00',
      title: json['title']?.toString() ?? '',
      drillType: json['drill_type']?.toString() ?? 'Fire Evacuation',
      buildingId: json['building_id']?.toString(),
      locationDisplay: json['location_display']?.toString() ?? 'Whole Campus',
      scheduledDate: DateTime.tryParse(json['scheduled_date']?.toString() ?? '') ?? DateTime.now(),
      conductedDate: json['conducted_date'] != null ? DateTime.tryParse(json['conducted_date'].toString()) : null,
      status: json['status']?.toString() ?? 'Scheduled',
      participantsCount: (json['participants_count'] as num?)?.toInt() ?? 0,
      evacuationTimeSeconds: (json['evacuation_time_seconds'] as num?)?.toInt() ?? 0,
      targetTimeSeconds: (json['target_time_seconds'] as num?)?.toInt() ?? 180,
      coordinatorName: json['coordinator_name']?.toString() ?? 'Safety Warden',
      coordinatorRole: json['coordinator_role']?.toString() ?? 'Chief Safety Warden',
      performanceRating: json['performance_rating']?.toString() ?? 'Good',
      observations: json['observations']?.toString(),
    );
  }
}

/// Generic List Response for Tables
class SafetyListResponse<T> {
  final int totalCount;
  final List<T> records;
  final int page;
  final int pageSize;
  final int totalPages;

  const SafetyListResponse({
    this.totalCount = 0,
    this.records = const [],
    this.page = 1,
    this.pageSize = 10,
    this.totalPages = 1,
  });
}

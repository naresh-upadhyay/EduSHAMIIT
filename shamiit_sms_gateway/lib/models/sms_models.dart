import 'dart:convert';

class SimInfo {
  final int subscriptionId;
  final int simSlotIndex;
  final String carrierName;
  final String displayName;
  final String countryIso;
  final String? phoneNumber;
  final String simState;
  final String networkOperator;
  final String networkType;
  final int? signalStrengthDbm;
  final int signalLevel;
  final String signalLabel;
  final bool isActive;
  final bool isDataEnabled;
  String usageMode; // SEND_RECEIVE, SEND_ONLY, RECEIVE_ONLY
  final String balanceInfo;
  final String validityInfo;
  final int sentCount;
  final int receivedCount;
  final int failedCount;

  SimInfo({
    required this.subscriptionId,
    required this.simSlotIndex,
    required this.carrierName,
    required this.displayName,
    required this.countryIso,
    this.phoneNumber,
    required this.simState,
    required this.networkOperator,
    required this.networkType,
    this.signalStrengthDbm,
    required this.signalLevel,
    required this.signalLabel,
    required this.isActive,
    required this.isDataEnabled,
    this.usageMode = 'SEND_RECEIVE',
    this.balanceInfo = 'Not Available',
    this.validityInfo = 'Not Available',
    this.sentCount = 0,
    this.receivedCount = 0,
    this.failedCount = 0,
  });

  String get slotLabel => 'SIM ${simSlotIndex + 1}';
  String get displayTitle => '$slotLabel ($carrierName)';
  bool get canSend => isActive && usageMode != 'RECEIVE_ONLY';

  factory SimInfo.fromMap(Map<String, dynamic> json) {
    bool asBool(dynamic v, [bool def = false]) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      return def;
    }

    return SimInfo(
      subscriptionId: (json['subscription_id'] as num?)?.toInt() ?? 0,
      simSlotIndex: (json['sim_slot_index'] as num?)?.toInt() ?? 0,
      carrierName: (json['carrier_name'] as String?) ?? 'Unknown Carrier',
      displayName: (json['display_name'] as String?) ?? (json['carrier_name'] as String? ?? 'SIM'),
      countryIso: (json['country_iso'] as String?) ?? '',
      phoneNumber: (json['phone_number'] as String?)?.trim().isNotEmpty == true
          ? (json['phone_number'] as String).trim()
          : null,
      simState: (json['sim_state'] as String?) ?? 'UNKNOWN',
      networkOperator: (json['network_operator'] as String?) ?? '',
      networkType: (json['network_type'] as String?) ?? 'Unknown',
      signalStrengthDbm: (json['signal_strength_dbm'] as num?)?.toInt(),
      signalLevel: (json['signal_level'] as num?)?.toInt() ?? 0,
      signalLabel: (json['signal_label'] as String?) ?? 'Unknown',
      isActive: asBool(json['is_active'], true),
      isDataEnabled: asBool(json['is_data_enabled'], false),
      usageMode: (json['usage_mode'] as String?) ?? 'SEND_RECEIVE',
      balanceInfo: (json['balance_info'] as String?) ?? 'Not Available',
      validityInfo: (json['validity_info'] as String?) ?? 'Not Available',
      sentCount: (json['sent_count'] as num?)?.toInt() ?? 0,
      receivedCount: (json['received_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'subscription_id': subscriptionId,
        'sim_slot_index': simSlotIndex,
        'carrier_name': carrierName,
        'display_name': displayName,
        'country_iso': countryIso,
        'phone_number': phoneNumber,
        'sim_state': simState,
        'network_operator': networkOperator,
        'network_type': networkType,
        'signal_strength_dbm': signalStrengthDbm,
        'signal_level': signalLevel,
        'signal_label': signalLabel,
        'is_active': isActive,
        'is_data_enabled': isDataEnabled,
        'usage_mode': usageMode,
        'balance_info': balanceInfo,
        'validity_info': validityInfo,
      };
}

class SmsMessageRecord {
  final String messageUuid;
  final String direction; // OUTBOUND, INBOUND
  final String? senderNumber;
  final String recipientNumber;
  final String messageBody;
  final String encoding;
  final int segmentCount;
  final int? sendingSimSlot;
  final int? sendingSubscriptionId;
  final int? receivingSimSlot;
  final int? receivingSubscriptionId;
  final String? carrierName;
  final String applicationSource;
  final String? referenceId;
  final String priority;
  final String status;
  final bool deliveryReportRequested;
  final String? scheduledAt;
  final String? expiresAt;
  final String createdAt;
  final String? queuedAt;
  final String? submittedAt;
  final String? deliveredAt;
  final String? receivedAt;
  final int retryCount;
  final String? failureReason;
  final String syncStatus;
  final List<Map<String, dynamic>> partStatuses;

  SmsMessageRecord({
    required this.messageUuid,
    required this.direction,
    this.senderNumber,
    required this.recipientNumber,
    required this.messageBody,
    required this.encoding,
    required this.segmentCount,
    this.sendingSimSlot,
    this.sendingSubscriptionId,
    this.receivingSimSlot,
    this.receivingSubscriptionId,
    this.carrierName,
    required this.applicationSource,
    this.referenceId,
    required this.priority,
    required this.status,
    required this.deliveryReportRequested,
    this.scheduledAt,
    this.expiresAt,
    required this.createdAt,
    this.queuedAt,
    this.submittedAt,
    this.deliveredAt,
    this.receivedAt,
    this.retryCount = 0,
    this.failureReason,
    this.syncStatus = 'SYNCED',
    this.partStatuses = const [],
  });

  bool get isInbound => direction.toUpperCase() == 'INBOUND';
  int? get effectiveSimSlot => isInbound ? receivingSimSlot : sendingSimSlot;
  String get counterparty => isInbound ? (senderNumber ?? 'Unknown') : recipientNumber;

  factory SmsMessageRecord.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> parseParts(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    final dReq = map['delivery_report_requested'];
    return SmsMessageRecord(
      messageUuid: (map['message_uuid'] as String?) ?? '',
      direction: (map['direction'] as String?) ?? 'OUTBOUND',
      senderNumber: map['sender_number'] as String?,
      recipientNumber: (map['recipient_number'] as String?) ?? '',
      messageBody: (map['message_body'] as String?) ?? '',
      encoding: (map['encoding'] as String?) ?? 'GSM7',
      segmentCount: (map['segment_count'] as num?)?.toInt() ?? 1,
      sendingSimSlot: (map['sending_sim_slot'] as num?)?.toInt(),
      sendingSubscriptionId: (map['sending_subscription_id'] as num?)?.toInt(),
      receivingSimSlot: (map['receiving_sim_slot'] as num?)?.toInt(),
      receivingSubscriptionId: (map['receiving_subscription_id'] as num?)?.toInt(),
      carrierName: map['carrier_name'] as String?,
      applicationSource: (map['application_source'] as String?) ?? 'SMS Gateway App',
      referenceId: map['reference_id'] as String?,
      priority: (map['priority'] as String?) ?? 'NORMAL',
      status: (map['status'] as String?) ?? 'QUEUED',
      deliveryReportRequested: dReq is bool ? dReq : ((dReq as num?)?.toInt() ?? 1) == 1,
      scheduledAt: map['scheduled_at'] as String?,
      expiresAt: map['expires_at'] as String?,
      createdAt: (map['created_at'] as String?) ?? '',
      queuedAt: map['queued_at'] as String?,
      submittedAt: map['submitted_at'] as String?,
      deliveredAt: map['delivered_at'] as String?,
      receivedAt: map['received_at'] as String?,
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      failureReason: map['failure_reason'] as String?,
      syncStatus: (map['sync_status'] as String?) ?? 'SYNCED',
      partStatuses: parseParts(map['part_statuses'] ?? map['part_statuses_json']),
    );
  }
}

class SmsEventRecord {
  final String eventUuid;
  final String? messageUuid;
  final String eventType;
  final String title;
  final String? description;
  final int? simSlot;
  final int? subscriptionId;
  final String? applicationSource;
  final String eventTimestamp;

  SmsEventRecord({
    required this.eventUuid,
    this.messageUuid,
    required this.eventType,
    required this.title,
    this.description,
    this.simSlot,
    this.subscriptionId,
    this.applicationSource,
    required this.eventTimestamp,
  });

  factory SmsEventRecord.fromMap(Map<String, dynamic> map) {
    return SmsEventRecord(
      eventUuid: (map['event_uuid'] as String?) ?? '',
      messageUuid: map['message_uuid'] as String?,
      eventType: (map['event_type'] as String?) ?? 'INFO',
      title: (map['title'] as String?) ?? '',
      description: map['description'] as String?,
      simSlot: (map['sim_slot'] as num?)?.toInt(),
      subscriptionId: (map['subscription_id'] as num?)?.toInt(),
      applicationSource: map['application_source'] as String?,
      eventTimestamp: (map['event_timestamp'] as String?) ?? '',
    );
  }
}

class SmsStatistics {
  final int sentToday;
  final int receivedToday;
  final int deliveredToday;
  final int failedToday;
  final int queueSize;
  final int scheduledCount;
  final double deliveryRate;
  final List<Map<String, dynamic>> hourlyActivity;
  final List<Map<String, dynamic>> appUsage;
  final List<Map<String, dynamic>> simUsage;
  final List<SmsEventRecord> recentEvents;
  final Map<String, dynamic>? activeDevice;

  SmsStatistics({
    this.sentToday = 0,
    this.receivedToday = 0,
    this.deliveredToday = 0,
    this.failedToday = 0,
    this.queueSize = 0,
    this.scheduledCount = 0,
    this.deliveryRate = 0.0,
    this.hourlyActivity = const [],
    this.appUsage = const [],
    this.simUsage = const [],
    this.recentEvents = const [],
    this.activeDevice,
  });

  factory SmsStatistics.fromMap(Map<String, dynamic> map) {
    final eventsRaw = map['recent_events'] as List<dynamic>? ?? [];
    return SmsStatistics(
      sentToday: (map['sent_today'] as num?)?.toInt() ?? 0,
      receivedToday: (map['received_today'] as num?)?.toInt() ?? 0,
      deliveredToday: (map['delivered_today'] as num?)?.toInt() ?? 0,
      failedToday: (map['failed_today'] as num?)?.toInt() ?? 0,
      queueSize: (map['queue_size'] as num?)?.toInt() ?? 0,
      scheduledCount: (map['scheduled_count'] as num?)?.toInt() ?? 0,
      deliveryRate: (map['delivery_rate'] as num?)?.toDouble() ?? 0.0,
      hourlyActivity: (map['hourly_activity'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      appUsage: (map['app_usage'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      simUsage: (map['sim_usage'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      recentEvents: eventsRaw
          .map((e) => SmsEventRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      activeDevice: map['active_device'] is Map
          ? Map<String, dynamic>.from(map['active_device'] as Map)
          : null,
    );
  }
}

class AutomationRule {
  final String id;
  final String ruleName;
  final String applicationName;
  final String triggerEvent;
  final String recipientMapping;
  final String? templateId;
  final String messageTemplate;
  final int? preferredSimSlot;
  final int? preferredSubscriptionId;
  final String priority;
  final bool isActive;
  final Map<String, dynamic> scheduleRestriction;
  final String? webhookUrl;
  final int executionCount;
  final String? lastTriggeredAt;

  AutomationRule({
    required this.id,
    required this.ruleName,
    required this.applicationName,
    required this.triggerEvent,
    required this.recipientMapping,
    this.templateId,
    required this.messageTemplate,
    this.preferredSimSlot,
    this.preferredSubscriptionId,
    this.priority = 'NORMAL',
    this.isActive = true,
    this.scheduleRestriction = const {},
    this.webhookUrl,
    this.executionCount = 0,
    this.lastTriggeredAt,
  });

  factory AutomationRule.fromMap(Map<String, dynamic> map) {
    return AutomationRule(
      id: (map['id'] ?? '').toString(),
      ruleName: (map['rule_name'] as String?) ?? '',
      applicationName: (map['application_name'] as String?) ?? 'EduSHAMIIT',
      triggerEvent: (map['trigger_event'] as String?) ?? '',
      recipientMapping: (map['recipient_mapping'] as String?) ?? 'parent_phone',
      templateId: map['template_id']?.toString(),
      messageTemplate: (map['message_template'] as String?) ?? '',
      preferredSimSlot: (map['preferred_sim_slot'] as num?)?.toInt(),
      preferredSubscriptionId: (map['preferred_subscription_id'] as num?)?.toInt(),
      priority: (map['priority'] as String?) ?? 'NORMAL',
      isActive: (map['is_active'] as bool?) ?? true,
      scheduleRestriction: map['schedule_restriction'] is Map
          ? Map<String, dynamic>.from(map['schedule_restriction'] as Map)
          : {},
      webhookUrl: map['webhook_url'] as String?,
      executionCount: (map['execution_count'] as num?)?.toInt() ?? 0,
      lastTriggeredAt: map['last_triggered_at'] as String?,
    );
  }
}

class MessageTemplate {
  final String id;
  final String templateName;
  final String applicationName;
  final String category;
  final String messageBody;
  final List<String> availableVariables;
  final List<String> requiredVariables;
  final String? dltTemplateId;
  final String? dltHeader;
  final String defaultPriority;
  final int? preferredSimSlot;
  final bool isActive;

  MessageTemplate({
    required this.id,
    required this.templateName,
    required this.applicationName,
    required this.category,
    required this.messageBody,
    this.availableVariables = const [],
    this.requiredVariables = const [],
    this.dltTemplateId,
    this.dltHeader,
    this.defaultPriority = 'NORMAL',
    this.preferredSimSlot,
    this.isActive = true,
  });

  factory MessageTemplate.fromMap(Map<String, dynamic> map) {
    return MessageTemplate(
      id: (map['id'] ?? '').toString(),
      templateName: (map['template_name'] as String?) ?? '',
      applicationName: (map['application_name'] as String?) ?? 'EduSHAMIIT',
      category: (map['category'] as String?) ?? 'Notification',
      messageBody: (map['message_body'] as String?) ?? '',
      availableVariables: (map['available_variables'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      requiredVariables: (map['required_variables'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      dltTemplateId: map['dlt_template_id'] as String?,
      dltHeader: map['dlt_header'] as String?,
      defaultPriority: (map['default_priority'] as String?) ?? 'NORMAL',
      preferredSimSlot: (map['preferred_sim_slot'] as num?)?.toInt(),
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}

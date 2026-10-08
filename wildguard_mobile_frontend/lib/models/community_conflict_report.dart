enum ConflictReportStatus {
  pendingSync,
  unverified,
  verified,
  inProgress,
  resolved,
  duplicate,
  rejected,
}

enum ThreatSeverity { low, medium, high, critical }

extension ConflictReportStatusLabel on ConflictReportStatus {
  String get code => switch (this) {
    ConflictReportStatus.pendingSync => 'PENDING_SYNC',
    ConflictReportStatus.unverified => 'UNVERIFIED',
    ConflictReportStatus.verified => 'VERIFIED',
    ConflictReportStatus.inProgress => 'IN_PROGRESS',
    ConflictReportStatus.resolved => 'RESOLVED',
    ConflictReportStatus.duplicate => 'DUPLICATE',
    ConflictReportStatus.rejected => 'REJECTED',
  };
  String get label => code.replaceAll('_', ' ');
}

extension ThreatSeverityLabel on ThreatSeverity {
  String get code => name.toUpperCase();
}

class CommunityConflictReport {
  final String id, reporterName, type, description, zone, channel;
  final double latitude, longitude;
  final ThreatSeverity severity;
  final ConflictReportStatus status;
  final DateTime createdAt;
  final String? reporterPhone, cloNotes, rangerUnit, photoBase64;
  final String? dispatchPriority, dispatchInstructions;

  const CommunityConflictReport({
    required this.id,
    required this.reporterName,
    required this.type,
    required this.description,
    required this.zone,
    required this.channel,
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.reporterPhone,
    this.cloNotes,
    this.rangerUnit,
    this.photoBase64,
    this.dispatchPriority,
    this.dispatchInstructions,
  });

  CommunityConflictReport copyWith({
    ConflictReportStatus? status,
    String? cloNotes,
    String? rangerUnit,
    String? photoBase64,
    String? dispatchPriority,
    String? dispatchInstructions,
  }) => CommunityConflictReport(
    id: id,
    reporterName: reporterName,
    type: type,
    description: description,
    zone: zone,
    channel: channel,
    latitude: latitude,
    longitude: longitude,
    severity: severity,
    status: status ?? this.status,
    createdAt: createdAt,
    reporterPhone: reporterPhone,
    cloNotes: cloNotes ?? this.cloNotes,
    rangerUnit: rangerUnit ?? this.rangerUnit,
    photoBase64: photoBase64 ?? this.photoBase64,
    dispatchPriority: dispatchPriority ?? this.dispatchPriority,
    dispatchInstructions: dispatchInstructions ?? this.dispatchInstructions,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'reporterName': reporterName,
    'type': type,
    'description': description,
    'zone': zone,
    'channel': channel,
    'latitude': latitude,
    'longitude': longitude,
    'severity': severity.code,
    'status': status.code,
    'createdAt': createdAt.toIso8601String(),
    'reporterPhone': reporterPhone,
    'cloNotes': cloNotes,
    'rangerUnit': rangerUnit,
    'photoBase64': photoBase64,
    'dispatchPriority': dispatchPriority,
    'dispatchInstructions': dispatchInstructions,
  };
  factory CommunityConflictReport.fromJson(Map<String, dynamic> j) =>
      CommunityConflictReport(
        id: j['id'],
        reporterName: j['reporterName'] ?? 'Community member',
        type: j['type'] ?? 'Wildlife conflict',
        description: j['description'] ?? '',
        zone: j['zone'] ?? 'Unspecified zone',
        channel: j['channel'] ?? 'MOBILE_APP',
        latitude: (j['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 0,
        severity: ThreatSeverity.values.firstWhere(
          (e) => e.code == j['severity'],
          orElse: () => ThreatSeverity.medium,
        ),
        status: ConflictReportStatus.values.firstWhere(
          (e) => e.code == j['status'],
          orElse: () => ConflictReportStatus.unverified,
        ),
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        reporterPhone: j['reporterPhone'],
        cloNotes: j['cloNotes'],
        rangerUnit: j['rangerUnit'],
        photoBase64: j['photoBase64'],
        dispatchPriority: j['dispatchPriority'],
        dispatchInstructions: j['dispatchInstructions'],
      );
}

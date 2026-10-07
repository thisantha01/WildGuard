/// Incident severity levels.
enum IncidentSeverity {
  low('LOW', 'Low Severity'),
  medium('MEDIUM', 'Medium Severity'),
  high('HIGH', 'High Severity'),
  critical('CRITICAL', 'Critical Alert');

  final String code;
  final String displayName;

  const IncidentSeverity(this.code, this.displayName);

  static IncidentSeverity fromCode(String code) {
    return IncidentSeverity.values.firstWhere(
      (sev) => sev.code == code || sev.name == code,
      orElse: () => IncidentSeverity.medium,
    );
  }
}

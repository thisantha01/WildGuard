/// Incident types matching backend domain model.
enum IncidentType {
  snare('SNARE', 'Wire Snare / Trap'),
  carcass('CARCASS', 'Animal Carcass'),
  poacherTrack('POACHER_TRACK', 'Poacher Footprints / Tracks'),
  illegalCamp('ILLEGAL_CAMP', 'Illegal Campsite'),
  gunshotHeard('GUNSHOT_HEARD', 'Gunshot Heard'),
  trap('TRAP', 'Hunting Trap'),
  illegalLogging('ILLEGAL_LOGGING', 'Illegal Timber Logging'),
  fenceBreach('FENCE_BREACH', 'Electric Fence Breach'),
  other('OTHER', 'Other Suspicious Activity');

  final String code;
  final String displayName;

  const IncidentType(this.code, this.displayName);

  static IncidentType fromCode(String code) {
    return IncidentType.values.firstWhere(
      (type) => type.code == code || type.name == code,
      orElse: () => IncidentType.other,
    );
  }
}

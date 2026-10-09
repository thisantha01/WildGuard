/// Injury severity classification mirroring `InjurySeverity` backend enum.
enum InjurySeverity {
  none,
  human,
  animal;

  static InjurySeverity fromJson(String? raw) {
    switch (raw) {
      case 'HUMAN':
        return InjurySeverity.human;
      case 'ANIMAL':
        return InjurySeverity.animal;
      case 'NONE':
      default:
        return InjurySeverity.none;
    }
  }

  String toJson() => name.toUpperCase();

  String get displayLabel {
    switch (this) {
      case InjurySeverity.none:
        return 'None';
      case InjurySeverity.human:
        return 'Human';
      case InjurySeverity.animal:
        return 'Animal';
    }
  }
}

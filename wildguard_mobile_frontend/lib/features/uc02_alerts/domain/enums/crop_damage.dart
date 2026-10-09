/// Crop damage classification mirroring `CropDamage` backend enum.
enum CropDamage {
  none,
  minor,
  major;

  static CropDamage fromJson(String? raw) {
    switch (raw) {
      case 'MINOR':
        return CropDamage.minor;
      case 'MAJOR':
        return CropDamage.major;
      case 'NONE':
      default:
        return CropDamage.none;
    }
  }

  String toJson() => name.toUpperCase();

  String get displayLabel {
    switch (this) {
      case CropDamage.none:
        return 'None';
      case CropDamage.minor:
        return 'Minor';
      case CropDamage.major:
        return 'Major';
    }
  }
}

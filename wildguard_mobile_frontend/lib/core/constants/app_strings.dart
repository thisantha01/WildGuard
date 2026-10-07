/// Centralized user-facing strings to prevent magic strings.
class AppStrings {
  AppStrings._();

  // App & Navigation
  static const String appTitle = 'WildGuard Field Ranger';
  static const String tabLogIncident = 'Log Incident';
  static const String tabSyncManager = 'Sync Manager';
  static const String tabGeofence = 'Geofence Alerts';
  static const String tabCommunity = 'Community';
  static const String tabAnalytics = 'Analytics';

  // Feature 1: Log Incident Screen (HCI / UX requirements)
  static const String offlineBannerText = '⚠ OFFLINE MODE: Data will be saved to device.';
  static const String incidentTypeLabel = 'Incident Type';
  static const String severityLabel = 'Severity Level';
  static const String descriptionLabel = 'Field Incident Notes / Description';
  static const String descriptionHint = 'Describe tracks, snare material, carcass condition, etc...';
  static const String gpsLostText = 'GPS Lost';
  static const String dropPinButtonText = '[ Drop Pin on Offline Map ]';
  static const String locationAcquiredText = 'GPS Coordinates Acquired';
  static const String takePhotoButtonText = '[ 📷 Take Photo ]';
  static const String selectGalleryButtonText = '[ 🖼️ Select Gallery ]';
  static const String saveOfflineButtonText = '[ SAVE OFFLINE ]';
  static const String noPhotoSelectedText = 'No Evidence Photo Attached';

  // Feature 2: Sync Manager Screen
  static const String syncDashboardTitle = 'Field Sync Dashboard';
  static const String syncAllPendingButtonText = '[ 🔄 SYNC ALL PENDING ]';
  static const String statusPending = 'PENDING';
  static const String statusSynced = 'SYNCED';
  static const String statusFailed = 'FAILED';
  static const String emptyIncidentListText = 'No incidents recorded on this device yet.';
  static const String syncSuccessMessage = 'All pending incidents synchronized successfully!';
  static const String savedOfflineSuccess = 'Incident logged locally in offline storage.';
}

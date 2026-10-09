/// UC02-specific constants. Import this instead of scattering magic numbers
/// across widgets.
class Uc02Constants {
  Uc02Constants._();

  // Touch targets (Fitts's Law — usable outdoors with gloves)
  static const double primaryButtonHeight = 56.0;
  static const double iconButtonSize = 72.0;
  static const double minButtonSpacing = 12.0;
  static const double minBodyFontSize = 16.0;
  static const double minLabelFontSize = 14.0;

  // Layout
  static const double screenPadding = 16.0;
  static const double cardRadius = 12.0;
  static const double chipRadius = 20.0;

  // Auto-refresh interval for alerts list (simulated push)
  static const Duration alertsRefreshInterval = Duration(seconds: 12);

  // Sync retry cap
  static const int maxSyncRetries = 5;

  // Map defaults
  static const double mapDefaultZoom = 13.0;
  static const double mapMarkerSize = 36.0;

  // Offline banner
  static const String offlineBannerText =
      '⚠ OFFLINE — Alerts and actions are saved on this phone and will sync automatically';

  // Decline reasons shown in the dialog
  static const List<String> declineReasons = [
    'Vehicle breakdown',
    'On another incident',
    'Other',
  ];

  // Stepper labels for Respond & Navigate screen
  static const List<String> stepperLabels = [
    'Acknowledged',
    'Dispatched',
    'On Scene',
  ];

  // Phone config keys (values come from AppConstants or API; these are labels)
  static const String baseCallNotConfigured = 'Base radio not configured';
  static const String cloCallNotConfigured = 'CLO number not configured';

  // UC02 tab label
  static const String tabLabel = 'Alerts';
}

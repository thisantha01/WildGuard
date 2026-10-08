import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../models/incident_type.dart';
import '../viewmodels/auth_manager.dart';
import '../viewmodels/community_conflict_manager.dart';
import '../viewmodels/offline_sync_manager.dart';
import '../widgets/location_picker_widget.dart';
import '../widgets/offline_banner_widget.dart';
import '../widgets/photo_picker_widget.dart';
import '../widgets/severity_selector_widget.dart';
import 'login_screen.dart';

/// Feature 1: The "Log Incident" Screen (HCI & UX Optimized for Field Rangers).
class LogIncidentScreen extends StatefulWidget {
  final VoidCallback? onReturnToDashboard;
  final bool villagerMode;

  const LogIncidentScreen({
    super.key,
    this.onReturnToDashboard,
    this.villagerMode = false,
  });

  @override
  State<LogIncidentScreen> createState() => _LogIncidentScreenState();
}

class _LogIncidentScreenState extends State<LogIncidentScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _communityZoneController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLocate();
    });
  }

  Future<void> _autoLocate() async {
    final manager = context.read<OfflineSyncManager>();
    // Asynchronously requests current GPS coordinates and timestamp from device OS
    final success = await manager.fetchLocation();
    if (!mounted) return;

    if (!success || manager.isGpsLost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text(AppStrings.gpsWarningText)),
            ],
          ),
          backgroundColor: AppColors.pendingAmber,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _communityZoneController.dispose();
    super.dispose();
  }

  void _onSaveOffline(BuildContext context, OfflineSyncManager manager) async {
    final messenger = ScaffoldMessenger.of(context);
    final communityManager = widget.villagerMode
        ? context.read<CommunityConflictManager>()
        : null;
    final reporterName =
        context.read<AuthManager>().currentUser?.fullName ?? 'Community member';
    final reporterPhone = context.read<AuthManager>().currentUser?.phoneNumber;
    final desc = _descriptionController.text.trim();

    if (widget.villagerMode && _communityZoneController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter your village or zone before submitting.'),
          backgroundColor: AppColors.pendingAmber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (desc.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please enter incident notes / description before saving.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.pendingAmber,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (manager.latitude == null || manager.longitude == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.location_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GPS coordinates are required. Please acquire GPS or drop a pin.',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.pendingAmber,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final success = await manager.saveIncidentOffline(description: desc);

      if (!mounted) return;

      if (success) {
        if (widget.villagerMode && manager.lastSavedIncident != null) {
          await communityManager!.submitIncident(
            manager.lastSavedIncident!,
            reporterName: reporterName,
            reporterPhone: reporterPhone,
            zone: _communityZoneController.text.trim(),
          );
        }
        _descriptionController.clear();
        if (widget.villagerMode) _communityZoneController.clear();
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text(AppStrings.savedOfflineSuccess),
              ],
            ),
            backgroundColor: AppColors.syncedGreen,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _showSaveSuccessModal(context, manager.lastSavedIncident);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    manager.errorMessage ?? 'Failed to save offline incident.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.failedRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(manager.errorMessage ?? e.toString())),
              ],
            ),
            backgroundColor: AppColors.failedRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Prominent Visual Success Modal ("Incident Saved to Device - Pending Sync")
  /// Unblocks the Ranger's workflow and returns them to the active patrol dashboard.
  void _showSaveSuccessModal(BuildContext context, dynamic incident) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.syncedGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.syncedGreen,
                size: 46,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.villagerMode
                  ? 'Incident Report Saved'
                  : 'Incident Saved to Device',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.villagerMode
                  ? 'Your report is queued for the response team'
                  : 'Pending sync with base station',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (incident != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            incident.type.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          incident.severity.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppColors.pendingAmber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incident.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            ElevatedButton(
              key: const Key('return_to_dashboard_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadius,
                  ),
                ),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                widget.onReturnToDashboard?.call();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Return to Patrol Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRangerProfileDialog(BuildContext context) {
    final authManager = context.read<AuthManager>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Ranger Profile'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name: ${authManager.rangerDisplayName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Park: ${authManager.parkName}'),
            const SizedBox(height: 6),
            Text(
              'Auth: ${authManager.currentUser != null ? "Online Verified (JWT Active)" : "Offline Field Mode"}',
            ),
            if (authManager.currentUser != null) ...[
              const SizedBox(height: 6),
              Text('Role: ${authManager.currentUser!.role}'),
              Text('Email: ${authManager.currentUser!.email}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.failedRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              authManager.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<OfflineSyncManager>();
    final authManager = context.watch<AuthManager>();

    // Red offline alert banner appears ONLY if the device cannot sync with the database:
    // • Device is offline (no network)
    // • Or Ranger is working in offline guest mode / unauthenticated
    final canSyncWithDatabase =
        manager.isOnline &&
        authManager.isAuthenticated &&
        !authManager.isOfflineGuestMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.villagerMode ? 'Report an Incident' : 'Log Field Incident',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('ranger_profile_button'),
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Ranger Profile & Session',
            onPressed: () => _showRangerProfileDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top HCI Alert Banner: High-urgency full-width RED banner shown ONLY when unable to sync
          if (!canSyncWithDatabase) const OfflineBannerWidget(),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.standardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.villagerMode) ...[
                    TextFormField(
                      controller: _communityZoneController,
                      decoration: const InputDecoration(
                        labelText: 'Village / zone',
                        hintText: 'Enter your village or sector',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Village or zone is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Incident Type Dropdown
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.standardPadding,
                        vertical: 4.0,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<IncidentType>(
                          value: manager.selectedType,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.primary,
                          ),
                          onChanged: (IncidentType? newType) {
                            if (newType != null) {
                              manager.setIncidentType(newType);
                            }
                          },
                          items: IncidentType.values.map((IncidentType type) {
                            return DropdownMenuItem<IncidentType>(
                              value: type,
                              child: Text(
                                type.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Severity Selector Widget (HCI / Fitts's Law 2x2 Large Touch Targets)
                  SeveritySelectorWidget(
                    selectedSeverity: manager.selectedSeverity,
                    onSeverityChanged: (sev) =>
                        manager.setIncidentSeverity(sev),
                  ),
                  const SizedBox(height: 12),

                  // Description Input
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadius,
                      ),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        AppConstants.standardPadding,
                      ),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: AppStrings.descriptionLabel,
                          hintText: AppStrings.descriptionHint,
                          border: InputBorder.none,
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location Section (HCI Map placeholder + [ Drop Pin on Offline Map ])
                  LocationPickerWidget(
                    latitude: manager.latitude,
                    longitude: manager.longitude,
                    isGpsLost: manager.isGpsLost,
                    isLocating: manager.isLocating,
                    onFetchGps: () async {
                      final success = await manager.fetchLocation();
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(AppStrings.gpsWarningText),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.pendingAmber,
                            duration: Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    onDropPin: () => manager.dropPinOnOfflineMap(),
                    onLocationChanged: (lat, lon) =>
                        manager.setCoordinates(lat, lon),
                  ),
                  const SizedBox(height: 12),

                  // Photo Section (Fitts's Law large touch targets + Preview Box)
                  PhotoPickerWidget(
                    photoPath: manager.photoPath,
                    photoBase64: manager.photoBase64,
                    onTakePhoto: () => manager.pickPhoto(ImageSource.camera),
                    onSelectGallery: () =>
                        manager.pickPhoto(ImageSource.gallery),
                    onClearPhoto: () => manager.clearPhoto(),
                  ),
                  const SizedBox(height: 20),

                  // Primary Call-to-Action: Large Button labeled [ SAVE OFFLINE ]
                  ElevatedButton(
                    key: const Key('save_offline_button'),
                    onPressed: () => _onSaveOffline(context, manager),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        double.infinity,
                        AppConstants.largeTouchTargetHeight,
                      ),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.borderRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      widget.villagerMode
                          ? 'SUBMIT INCIDENT REPORT'
                          : AppStrings.saveOfflineButtonText,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../models/incident_severity.dart';
import '../models/incident_type.dart';
import '../viewmodels/auth_manager.dart';
import '../viewmodels/offline_sync_manager.dart';
import '../widgets/location_picker_widget.dart';
import '../widgets/offline_banner_widget.dart';
import '../widgets/photo_picker_widget.dart';
import '../widgets/severity_selector_widget.dart';
import 'login_screen.dart';

/// Feature 1: The "Log Incident" Screen (HCI & UX Optimized for Field Rangers).
class LogIncidentScreen extends StatefulWidget {
  const LogIncidentScreen({super.key});

  @override
  State<LogIncidentScreen> createState() => _LogIncidentScreenState();
}

class _LogIncidentScreenState extends State<LogIncidentScreen> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onSaveOffline(BuildContext context, OfflineSyncManager manager) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await manager.saveIncidentOffline(
        description: _descriptionController.text,
      );

      if (success && mounted) {
        _descriptionController.clear();
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
      }
    } catch (_) {
      if (mounted && manager.errorMessage != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(manager.errorMessage!)),
              ],
            ),
            backgroundColor: AppColors.failedRed,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showRangerProfileDialog(BuildContext context) {
    final authManager = context.read<AuthManager>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
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
            Text('Name: ${authManager.rangerDisplayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Park: ${authManager.parkName}'),
            const SizedBox(height: 6),
            Text('Auth: ${authManager.currentUser != null ? "Online Verified (JWT Active)" : "Offline Field Mode"}'),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.failedRed, foregroundColor: Colors.white),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Field Incident'),
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
          // Top HCI Alert Banner: High-urgency full-width RED banner
          const OfflineBannerWidget(),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.standardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Incident Type Dropdown
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
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
                                style: const TextStyle(fontWeight: FontWeight.w600),
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
                    onSeverityChanged: (sev) => manager.setIncidentSeverity(sev),
                  ),
                  const SizedBox(height: 12),

                  // Description Input
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.standardPadding),
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
                    onFetchGps: () => manager.fetchLocation(),
                    onDropPin: () => manager.dropPinOnOfflineMap(),
                  ),
                  const SizedBox(height: 12),

                  // Photo Section (Fitts's Law large touch targets + Preview Box)
                  PhotoPickerWidget(
                    photoPath: manager.photoPath,
                    onTakePhoto: () => manager.pickPhoto(ImageSource.camera),
                    onSelectGallery: () => manager.pickPhoto(ImageSource.gallery),
                  ),
                  const SizedBox(height: 20),

                  // Primary Call-to-Action: Large Button labeled [ SAVE OFFLINE ]
                  ElevatedButton(
                    key: const Key('save_offline_button'),
                    onPressed: () => _onSaveOffline(context, manager),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, AppConstants.largeTouchTargetHeight),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
                    ),
                    child: const Text(
                      AppStrings.saveOfflineButtonText,
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

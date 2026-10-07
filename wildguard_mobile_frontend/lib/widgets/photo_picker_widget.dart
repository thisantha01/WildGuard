import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// Photo evidence section optimized with Fitts's Law large touch targets and cross-platform preview.
class PhotoPickerWidget extends StatelessWidget {
  final String? photoPath;
  final String? photoBase64;
  final VoidCallback onTakePhoto;
  final VoidCallback onSelectGallery;
  final VoidCallback? onClearPhoto;

  const PhotoPickerWidget({
    super.key,
    required this.photoPath,
    this.photoBase64,
    required this.onTakePhoto,
    required this.onSelectGallery,
    this.onClearPhoto,
  });

  bool get _hasPhoto =>
      (photoBase64 != null && photoBase64!.isNotEmpty) ||
      (photoPath != null && photoPath!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera_back_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Incident Evidence Photo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (_hasPhoto && onClearPhoto != null)
                  TextButton.icon(
                    onPressed: onClearPhoto,
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.failedRed),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: AppColors.failedRed, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Fitts's Law Large Touch Targets (Massive Action Buttons)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onTakePhoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, AppConstants.photoTargetHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppStrings.takePhotoButtonText,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSelectGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, AppConstants.photoTargetHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppStrings.selectGalleryButtonText,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Thumbnail Preview Box
            Container(
              height: AppConstants.thumbnailHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: Border.all(
                  color: _hasPhoto ? AppColors.syncedGreen.withValues(alpha: 0.6) : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: _buildImagePreview(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    // 1. Prioritize Base64 image data (Universal for Web & Mobile)
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final cleanBase64 = photoBase64!.contains(',')
            ? photoBase64!.split(',').last
            : photoBase64!;
        final bytes = base64Decode(cleanBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius - 1),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildPlaceholder(),
          ),
        );
      } catch (_) {}
    }

    // 2. Fallback to native File path on mobile Android / iOS
    if (photoPath != null && photoPath!.isNotEmpty && !kIsWeb) {
      try {
        final file = File(photoPath!);
        if (file.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius - 1),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            ),
          );
        }
      } catch (_) {}
    }

    // 3. Fallback to Placeholder if no image is attached
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
        SizedBox(height: 6),
        Text(
          AppStrings.noPhotoSelectedText,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

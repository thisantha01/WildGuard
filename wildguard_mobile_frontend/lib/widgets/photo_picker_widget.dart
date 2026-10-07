import 'dart:io';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// Photo evidence section optimized with Fitts's Law large touch targets and preview.
class PhotoPickerWidget extends StatelessWidget {
  final String? photoPath;
  final VoidCallback onTakePhoto;
  final VoidCallback onSelectGallery;

  const PhotoPickerWidget({
    super.key,
    required this.photoPath,
    required this.onTakePhoto,
    required this.onSelectGallery,
  });

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
            const Row(
              children: [
                Icon(Icons.photo_camera_back_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Incident Evidence Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: photoPath != null && File(photoPath!).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius - 1),
                      child: Image.file(
                        File(photoPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                        SizedBox(height: 6),
                        Text(
                          AppStrings.noPhotoSelectedText,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

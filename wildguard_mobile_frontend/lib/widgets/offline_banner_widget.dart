import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';

/// Full-width red offline alert banner optimized for high-urgency visibility.
class OfflineBannerWidget extends StatelessWidget {
  const OfflineBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.offlineBannerRed,
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 22,
          ),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              AppStrings.offlineBannerText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

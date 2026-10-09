import 'package:flutter/material.dart';
import '../constants/uc02_constants.dart';

/// High-contrast amber offline banner displayed at the top of every UC02
/// screen when the device has no network connection.
///
/// Only visible when [isOnline] is false.
class OfflineBanner extends StatelessWidget {
  final bool isOnline;

  const OfflineBanner({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();

    return Semantics(
      label: 'Offline mode active. Alerts and actions are saved locally.',
      child: Container(
        width: double.infinity,
        color: const Color(0xFFF57C00),
        padding: const EdgeInsets.symmetric(
          horizontal: Uc02Constants.screenPadding,
          vertical: 8,
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                Uc02Constants.offlineBannerText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

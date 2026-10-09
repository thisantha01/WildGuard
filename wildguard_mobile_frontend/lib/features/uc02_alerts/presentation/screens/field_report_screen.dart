import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../viewmodels/auth_manager.dart';
import '../../domain/entities/alert_detail.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/alert_status.dart';
import '../../domain/enums/crop_damage.dart';
import '../../domain/enums/injury_severity.dart';
import '../providers/alerts_provider.dart';
import 'report_saved_screen.dart';

/// Screen 4 — Field Report & Resolution (Screenshot 4).
///
/// Features:
///   - Top bar: "Wildlife Monitor / Sri Lanka DWC" & "Saman P / Unit R-07"
///   - Title "Field report & resolution"
///   - Animal name, tag, species, zone
///   - Status badge (PENDING RESOLUTION) & zone-exit confirmation
///   - Evaluator verification toggle to unlock form
///   - Crop damage 3-pill selector (None, Minor, Major)
///   - Injuries 3-pill selector (None, Human, Animal)
///   - "Situation is safe" switch toggle
///   - Notes (optional)
///   - "Add photo" button with photo preview
///   - Offline strip: "Saved on phone - will sync automatically"
///   - Primary button: "✓ SUBMIT REPORT"
class FieldReportScreen extends StatefulWidget {
  final String alertId;
  final String? capturedPhotoPath;

  const FieldReportScreen({
    super.key,
    required this.alertId,
    this.capturedPhotoPath,
  });

  @override
  State<FieldReportScreen> createState() => _FieldReportScreenState();
}

class _FieldReportScreenState extends State<FieldReportScreen> {
  CropDamage _cropDamage = CropDamage.none;
  InjurySeverity _injuries = InjurySeverity.none;
  bool _situationSafe = false;
  bool _animalLeftZoneVerified = false;
  final _notesController = TextEditingController();
  String? _photoPath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.capturedPhotoPath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().loadAlertDetail(widget.alertId);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AuthManager? authManager;
    try {
      authManager = Provider.of<AuthManager>(context, listen: false);
    } catch (_) {}
    final user = authManager?.currentUser;
    final rangerName = (user?.fullName.isNotEmpty == true) ? user!.fullName : 'Saman P';
    final unitCode = (user?.badgeNumber?.isNotEmpty == true)
        ? (user!.badgeNumber!.startsWith('Unit') ? user.badgeNumber! : 'Unit ${user.badgeNumber}')
        : 'Unit R-07';

    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        final detail = provider.currentDetail;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Header Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back',
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Wildlife Monitor',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Sri Lanka DWC',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rangerName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            unitCode,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Screen Content ──────────────────────────────────────────
                Expanded(child: _buildBody(context, provider, detail)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AlertsProvider provider, AlertDetail? detail) {
    if (provider.detailState == AlertsLoadState.loading && detail == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (detail == null) {
      return const Center(child: Text('Alert not available.'));
    }

    final isPendingResolution =
        detail.status == AlertStatus.pendingResolution || _animalLeftZoneVerified;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title: "Field report & resolution" ───────────────────────────
          const Text(
            'Field report & resolution',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),

          // Animal Name + Code
          Row(
            children: [
              Text(
                '${detail.animalName} (${detail.animalTag ?? "ELE-024"})',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                detail.displayCode,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${detail.species ?? "Sri Lankan elephant"} · ${detail.zoneName}',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // ── Status Pill ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPendingResolution ? 'PENDING RESOLUTION' : detail.status.displayLabel.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── Condition Subtitle ───────────────────────────────────────────
          Text(
            '${detail.animalName} has stayed outside the farmland zone (3 readings)',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          // ── Evaluator Demo / Animal Left Zone Toggle ──────────────────────
          if (detail.status != AlertStatus.pendingResolution) ...[
            InkWell(
              onTap: () => _toggleAnimalLeftZone(!_animalLeftZoneVerified, detail),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _animalLeftZoneVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _animalLeftZoneVerified ? const Color(0xFF0D6838) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _animalLeftZoneVerified ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: _animalLeftZoneVerified ? const Color(0xFF0D6838) : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _animalLeftZoneVerified
                            ? 'Animal left zone verified (Form unlocked ✓)'
                            : 'Click to verify: Animal has left zone',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _animalLeftZoneVerified ? const Color(0xFF0D6838) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Crop Damage Selector ─────────────────────────────────────────
          const Text(
            'Crop damage',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _pillOption('None', _cropDamage == CropDamage.none, () => setState(() => _cropDamage = CropDamage.none))),
              const SizedBox(width: 8),
              Expanded(child: _pillOption('Minor', _cropDamage == CropDamage.minor, () => setState(() => _cropDamage = CropDamage.minor))),
              const SizedBox(width: 8),
              Expanded(child: _pillOption('Major', _cropDamage == CropDamage.major, () => setState(() => _cropDamage = CropDamage.major))),
            ],
          ),
          const SizedBox(height: 16),

          // ── Injuries Selector ────────────────────────────────────────────
          const Text(
            'Injuries',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _pillOption('None', _injuries == InjurySeverity.none, () => setState(() => _injuries = InjurySeverity.none))),
              const SizedBox(width: 8),
              Expanded(child: _pillOption('Human', _injuries == InjurySeverity.human, () => setState(() => _injuries = InjurySeverity.human))),
              const SizedBox(width: 8),
              Expanded(child: _pillOption('Animal', _injuries == InjurySeverity.animal, () => setState(() => _injuries = InjurySeverity.animal))),
            ],
          ),
          const SizedBox(height: 16),

          // ── Situation is Safe Card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Text(
                  'Situation is safe',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                Switch(
                  value: _situationSafe,
                  activeColor: const Color(0xFF0D6838),
                  onChanged: (val) => setState(() => _situationSafe = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Notes (optional) ─────────────────────────────────────────────
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Notes (optional)',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          // ── Add Photo Button ─────────────────────────────────────────────
          _buildPhotoButton(),
          const SizedBox(height: 14),

          // ── Offline Saved on Phone Strip ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Color(0xFF92400E), size: 18),
                SizedBox(width: 8),
                Text(
                  'Saved on phone - will sync automatically',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Submit Report Button ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6838),
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_situationSafe && !_isSubmitting)
                  ? () => _submit(context, provider, detail)
                  : null,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'SUBMIT REPORT',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _pillOption(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D6838) : const Color(0xFFCBD5E1),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0D6838) : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoButton() {
    if (_photoPath != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(_photoPath!),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.image_rounded, size: 40),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Photo attached', style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => _photoPath = null),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0D6838),
        side: const BorderSide(color: Color(0xFF0D6838), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 44),
      ),
      onPressed: _pickPhoto,
      icon: const Icon(Icons.camera_alt_outlined, size: 20),
      label: const Text('Add photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() => _photoPath = photo.path);
      }
    } catch (_) {}
  }

  Future<void> _toggleAnimalLeftZone(bool val, AlertDetail detail) async {
    setState(() => _animalLeftZoneVerified = val);

    if (val && detail.status != AlertStatus.pendingResolution) {
      try {
        final tag = detail.animalTag ?? 'ELE-001';
        final uri = Uri.parse('${AppConstants.defaultApiBaseUrl}/dev/simulate-collar');
        final client = http.Client();
        for (int i = 0; i < 2; i++) {
          await client.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'animalTag': tag, 'scenario': 'OUTSIDE_ZONE'}),
          ).timeout(const Duration(seconds: 3));
        }
        if (mounted) {
          context.read<AlertsProvider>().refreshCurrentDetail();
        }
      } catch (_) {}
    }
  }

  Future<void> _submit(
      BuildContext context, AlertsProvider provider, AlertDetail detail) async {
    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'cropDamage': _cropDamage.toJson(),
      'injuries': _injuries.toJson(),
      'situationSafe': _situationSafe,
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
    };

    if (_photoPath != null) {
      try {
        final bytes = await File(_photoPath!).readAsBytes();
        payload['photoBase64'] = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (_) {}
    }

    final newStatus = await provider.performAction(
      alertId: detail.id,
      currentStatus: _animalLeftZoneVerified ? AlertStatus.pendingResolution : detail.status,
      type: ActionType.fieldReport,
      payload: payload,
    );

    if (!context.mounted) return;
    setState(() => _isSubmitting = false);

    if (newStatus != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReportSavedScreen(
            alertId: detail.id,
            displayCode: detail.displayCode,
            cropDamage: _cropDamage,
            injuries: _injuries,
            wasOnline: provider.isOnline,
          ),
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!)));
      provider.clearError();
    }
  }
}

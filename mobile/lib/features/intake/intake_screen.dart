import 'package:flutter/material.dart';

import 'package:routewise_mobile/shared/design_system/app_colors.dart';
import 'package:routewise_mobile/shared/design_system/app_haptics.dart';
import 'package:routewise_mobile/shared/design_system/app_text_styles.dart';
import 'package:routewise_mobile/shared/design_system/widgets/primary_button.dart';
import 'package:routewise_mobile/shared/design_system/widgets/status_chip.dart';
import 'data/parcel.dart';
import 'data/parsed_address.dart';
import 'services/parcel_api.dart';
import 'state/intake_controller.dart';
import 'screens/manual_entry_sheet.dart';
import 'screens/map_pin_sheet.dart';
import 'screens/scan_screen.dart';

/// Scan / Add tab: barcode scan, OCR and manual parcel entry.
///
/// Pass an existing [IntakeController] to inject a test double; omit to use
/// the default controller wired to the real HTTP API.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key, this.controller});

  final IntakeController? controller;

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  late IntakeController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? IntakeController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a parcel'),
        actions: [
          ListenableBuilder(
            listenable: _ctrl,
            builder: (_, _) => _CountBadge(count: _ctrl.addedCount),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: _ctrl,
                builder: (_, _) {
                  final parcels = _ctrl.parcels;
                  if (parcels.isEmpty) return _emptyBody(c);
                  return _parcelList(parcels, c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------

  Widget _emptyBody(AppColors c) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 40),
        _scanHeroCard(c),
        const SizedBox(height: 28),
        Center(
          child: Text('— or —', style: AppTextStyles.caption(c)),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Type address manually',
          variant: PrimaryButtonVariant.ghost,
          icon: Icons.keyboard_rounded,
          onPressed: _openManualEntry,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _scanHeroCard(AppColors c) {
    return GestureDetector(
      onTap: _openScanner,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.surfaceHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.outline),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.qr_code_scanner_rounded, color: c.accent, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan a barcode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Point the camera at the parcel label\'s barcode or QR code',
              style: AppTextStyles.caption(c),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Parcel list
  // ---------------------------------------------------------------

  Widget _parcelList(List<Parcel> parcels, AppColors c) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _scanHeroCard(c)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                Text('TODAY', style: AppTextStyles.sectionLabel(c)),
                const Spacer(),
                PrimaryButton(
                  label: 'Manual',
                  variant: PrimaryButtonVariant.ghost,
                  icon: Icons.keyboard_rounded,
                  onPressed: _openManualEntry,
                  height: 40,
                  width: 170,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: parcels.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ParcelTile(
              parcel: parcels[i],
              onAmberTap: _openMapPin,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: _ctrl,
          builder: (_, _) => ScanScreen(controller: _ctrl),
        ),
      ),
    );
  }

  Future<void> _openManualEntry() async {
    final address = await showModalBottomSheet<ManualAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ManualEntrySheet(),
    );
    if (address == null || !mounted) return;

    try {
      await _ctrl.manualSave(address);
      Haptics.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Parcel added — ${_ctrl.addedCount} total'),
          backgroundColor: context.appColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } on ParcelApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _openMapPin(Parcel parcel) async {
    if (parcel.latitude == null || parcel.longitude == null) return;
    final result = await showModalBottomSheet<PinResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapPinSheet(latitude: parcel.latitude!, longitude: parcel.longitude!),
    );
    if (result == null || !mounted) return;

    try {
      await _ctrl.confirmPin(parcel.id, result.latitude, result.longitude);
      Haptics.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pin confirmed'),
          backgroundColor: context.appColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ParcelApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

// ---------------------------------------------------------------
// Count badge (animated scale on change)
// ---------------------------------------------------------------

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: count > 0 ? c.accentSoft : c.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: count > 0 ? c.accent.withValues(alpha: 0.4) : c.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: count > 0 ? c.accent : c.textMuted),
            const SizedBox(width: 6),
            Text(
              '$count added',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: count > 0 ? c.accent : c.textMuted,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Parcel tile
// ---------------------------------------------------------------

class _ParcelTile extends StatelessWidget {
  const _ParcelTile({required this.parcel, required this.onAmberTap});
  final Parcel parcel;
  final Future<void> Function(Parcel) onAmberTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    final bool showBadge;
    final String badgeLabel;
    final StatusTone badgeTone;

    switch (parcel.geocodeStatus) {
      case ParcelGeocodeStatus.confirmed:
      case ParcelGeocodeStatus.geocoded:
        showBadge = true;
        badgeLabel = 'Confirmed';
        badgeTone = StatusTone.success;
      case ParcelGeocodeStatus.autoGeocoded:
        showBadge = true;
        badgeLabel = 'Auto';
        badgeTone = StatusTone.warning;
      case ParcelGeocodeStatus.notGeocoded:
        showBadge = true;
        badgeLabel = 'Not geocoded';
        badgeTone = StatusTone.neutral;
      case ParcelGeocodeStatus.failed:
        showBadge = true;
        badgeLabel = 'Geocode failed';
        badgeTone = StatusTone.error;
    }

    final tile = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_rounded, color: c.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parcel.rawAddress.isEmpty ? 'No address' : parcel.rawAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (parcel.orderId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Order ${parcel.orderId}',
                    style: AppTextStyles.caption(c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (showBadge)
            GestureDetector(
              onTap: parcel.geocodeStatus == ParcelGeocodeStatus.autoGeocoded
                  ? () => onAmberTap(parcel)
                  : null,
              child: StatusChip(label: badgeLabel, tone: badgeTone),
            ),
        ],
      ),
    );

    return tile;
  }
}

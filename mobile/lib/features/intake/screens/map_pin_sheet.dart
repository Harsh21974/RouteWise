import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_haptics.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../shared/design_system/widgets/primary_button.dart';

/// Result returned by [MapPinSheet] on confirm.
class PinResult {
  const PinResult(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Bottom-sheet map with a single draggable pin.
///
/// Returns a [PinResult] on confirm, null on cancel.
class MapPinSheet extends StatefulWidget {
  const MapPinSheet({super.key, required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  State<MapPinSheet> createState() => _MapPinSheetState();
}

class _MapPinSheetState extends State<MapPinSheet> {
  late LatLng _point;
  late final MapController _mapCtrl;

  @override
  void initState() {
    super.initState();
    _point = LatLng(widget.latitude, widget.longitude);
    _mapCtrl = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.location_on, color: c.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_point.latitude.toStringAsFixed(5)}, ${_point.longitude.toStringAsFixed(5)}',
                    style: AppTextStyles.sectionLabel(c),
                  ),
                ),
                Text('Drag to adjust', style: AppTextStyles.caption(c)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: _point,
                  initialZoom: 17,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.scrollWheelZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.routewise.routewise_mobile',
                  ),
                  MarkerLayer(markers: [_buildMarker()]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Confirm pin',
                    icon: Icons.check_rounded,
                    onPressed: () {
                      Haptics.success();
                      Navigator.pop(context, PinResult(_point.latitude, _point.longitude));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                _IconSquare(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // -- custom draggable marker (flutter_map 8.x has no built-in) ------------

  Marker _buildMarker() {
    return Marker(
      point: _point,
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _onDrag,
        child: const Icon(Icons.push_pin, size: 36, color: Color(0xFFC5F517)),
      ),
    );
  }

  void _onDrag(DragUpdateDetails details) {
    final cam = _mapCtrl.camera;
    final screenPos = cam.latLngToScreenOffset(_point);
    final newLatLng = cam.screenOffsetToLatLng(screenPos + details.delta);
    setState(() => _point = newLatLng);
  }
}

/// Compact square icon tile (used for the sheet's cancel control).
class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: c.accentSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.accent.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: c.accent),
        ),
      ),
    );
  }
}

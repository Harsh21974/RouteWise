import 'package:flutter/material.dart';

import '../../shared/design_system/app_colors.dart';
import '../../shared/design_system/app_haptics.dart';
import '../../shared/design_system/app_text_styles.dart';
import '../../shared/design_system/widgets/progress_ring.dart';
import '../../shared/design_system/widgets/stat_card.dart';
import '../route/route_format.dart';
import '../route/state/route_planner.dart';

/// Progress tab: the day's totals — delivered / remaining counts and distance
/// covered — centered on the design-system [ProgressRing]. Celebrates (ring
/// flashes green + a burst + haptic) when every stop is complete.
class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key, this.planner});

  /// Shared [RoutePlanner] from the shell; omitted only in isolated screens.
  final RoutePlanner? planner;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late final RoutePlanner _planner;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    _planner = widget.planner ?? RoutePlanner();
    _planner.addListener(_onPlannerChanged);
  }

  @override
  void dispose() {
    _planner.removeListener(_onPlannerChanged);
    if (widget.planner == null) _planner.dispose();
    super.dispose();
  }

  void _onPlannerChanged() {
    if (_planner.isAllComplete && !_celebrated) {
      _celebrated = true;
      Haptics.success();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery progress')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _planner,
          builder: (_, _) {
            final delivered = _planner.deliveredCount;
            final total = _planner.totalCount;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('DAY PROGRESS', style: AppTextStyles.sectionLabel(c)),
                const SizedBox(height: 20),
                if (_planner.isAllComplete) ...[
                  const _AllDoneCelebration(),
                  const SizedBox(height: 24),
                ],
                Center(
                  child: ProgressRing(
                    progress: _planner.progress,
                    size: 150,
                    strokeWidth: 14,
                    label: '$delivered',
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _planner.hasPlan
                        ? '$delivered of $total delivered'
                        : '0 of 0 delivered',
                    style: AppTextStyles.caption(c).copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 28),
                StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Delivered',
                  value: '$delivered',
                  caption: total > 0 ? 'of $total stops' : 'stops on today\'s route',
                ),
                const SizedBox(height: 16),
                StatCard(
                  icon: Icons.schedule,
                  label: 'Remaining',
                  value: '${_planner.remainingCount}',
                  caption: _planner.skippedCount > 0
                      ? '${_planner.skippedCount} skipped'
                      : 'stops left to drive',
                ),
                const SizedBox(height: 16),
                StatCard(
                  icon: Icons.route,
                  label: 'Covered',
                  value: formatMeters(_planner.coveredMeters),
                  caption: 'distance driven along your route',
                ),
                if (!_planner.hasPlan) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Optimize a route on the My Route tab and this dashboard '
                    'tracks your stops live.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption(c),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Short, finite celebration shown when every stop is done: a lime burst with
/// a check that eases in, then a "great shift" caption.
class _AllDoneCelebration extends StatelessWidget {
  const _AllDoneCelebration();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutBack,
      builder: (context, t, _) {
        return Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: c.success, width: 2),
              boxShadow: [
                BoxShadow(
                  color: c.success.withValues(alpha: 0.35 * t),
                  blurRadius: 22,
                  spreadRadius: 6 * t,
                ),
              ],
            ),
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Icon(Icons.emoji_events_rounded, color: c.success, size: 34),
            ),
          ),
        );
      },
    );
  }
}
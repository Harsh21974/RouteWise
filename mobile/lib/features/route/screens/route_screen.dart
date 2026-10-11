import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_haptics.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../shared/design_system/widgets/empty_state.dart';
import '../../../shared/design_system/widgets/primary_button.dart';
import '../../../shared/design_system/widgets/status_chip.dart';
import '../data/route_plan.dart';
import '../state/route_planner.dart';
import '../route_format.dart';
import '../widgets/route_map_view.dart';
import '../widgets/route_solving_view.dart';
import '../widgets/stop_card.dart';
import '../../intake/data/parcel.dart';
import '../../intake/state/intake_controller.dart';

/// My Route tab: optimize the day's deliveries, then drive through them on an
/// OSM map with ordered, actionable stop cards.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, this.planner, this.intake});

  /// Injected for tests / shared across tabs; omitted in the real shell.
  final RoutePlanner? planner;

  /// Source of today's parcels to pick the CONFIRMED/AUTO_GEOCODED ids from.
  final IntakeController? intake;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final RoutePlanner _planner;
  late final IntakeController? _intake;
  RoutePlan? _seenPlan;
  int? _activeStopId;

  @override
  void initState() {
    super.initState();
    _planner = widget.planner ?? RoutePlanner();
    _intake = widget.intake;
    _planner.addListener(_onPlannerChanged);
  }

  @override
  void dispose() {
    _planner.removeListener(_onPlannerChanged);
    if (widget.planner == null) _planner.dispose();
    super.dispose();
  }

  void _onPlannerChanged() {
    if (_planner.plan != _seenPlan) {
      _seenPlan = _planner.plan;
      setState(() => _activeStopId = null);
    }
  }

  /// Ids of parcels that are ready to route (CONFIRMED/AUTO_GEOCODED + pin).
  List<int> _eligibleIds() => [
        for (final parcel in _intake?.parcels ?? const <Parcel>[])
          if ((parcel.geocodeStatus.isAmber || parcel.geocodeStatus.isGreen) &&
              parcel.latitude != null &&
              parcel.longitude != null)
            parcel.id,
      ];

  Future<void> _optimize() async {
    final ids = _eligibleIds();
    Haptics.light();
    await _planner.optimize(deliveryIds: ids);
  }

  void _selectStop(int deliveryId) {
    Haptics.selection();
    setState(() => _activeStopId = deliveryId);
  }

  void _deliver(int deliveryId) {
    _planner.markDelivered(deliveryId);
    if (_planner.isAllComplete) {
      Haptics.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route complete — all ${_planner.totalCount} stops done!')),
      );
    }
  }

  void _skip(int deliveryId) {
    Haptics.light();
    _planner.skip(deliveryId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your route'),
        actions: [
          ListenableBuilder(
            listenable: _planner,
            builder: (context, _) {
              if (!_planner.hasPlan) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    StatusChip(
                      label: '${_planner.remainingCount} left',
                      tone: _planner.remainingCount == 0
                          ? StatusTone.success
                          : StatusTone.accent,
                    ),
                    IconButton(
                      tooltip: 'Re-plan',
                      icon: const Icon(Icons.replay),
                      onPressed: _planner.reset,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable:
              _intake == null ? _planner : Listenable.merge([_planner, _intake]),
          builder: (_, _) => _body(),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_planner.phase) {
      case RoutePhase.idle:
        return _idleView();
      case RoutePhase.solving:
        return RouteSolvingView(stopCount: _eligibleIds().length);
      case RoutePhase.error:
        return _errorView();
      case RoutePhase.solved:
        return _solvedView();
    }
  }

  Widget _idleView() {
    final ready = _eligibleIds().length;
    final empty = ready == 0;
    return EmptyState(
      icon: Icons.route_rounded,
      title: 'Your route is empty',
      subtitle: empty
          ? 'Add parcels and get them geocoded first — the app optimizes '
              'them into one driving order starting from your location.'
          : 'Optimize $ready ready ${ready == 1 ? 'stop' : 'stops'} into one '
              'driving order, starting from your current location.',
      action: PrimaryButton(
        label: empty ? 'Optimize My Route' : 'Optimize My Route · $ready',
        icon: Icons.auto_awesome,
        onPressed: empty ? null : _optimize,
      ),
    );
  }

  Widget _errorView() {
    final empty = _eligibleIds().isEmpty;
    if (empty) return _idleView();

    final c = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_problem, size: 56, color: c.warning),
            const SizedBox(height: 20),
            Text(
              'Could not solve your route',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              _planner.errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(c).copyWith(fontSize: 14),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Try again',
              icon: Icons.refresh,
              variant: PrimaryButtonVariant.outlined,
              onPressed: _optimize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _solvedView() {
    final c = context.appColors;
    final stops = _planner.stops;
    final plan = _planner.plan!;

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: RouteMapView(
            plan: plan,
            stops: stops,
            activeStopId: _activeStopId,
            onStopTap: _selectStop,
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
child: Row(
                    children: [
                      Text('STOPS', style: AppTextStyles.sectionLabel(c)),
                      const Spacer(),
                      Text(
                        '${formatMeters(_planner.plan!.totalDistanceMeters)}'
                        ' · ${formatEta(_planner.plan!.totalDurationSeconds)} total',
                        style: AppTextStyles.caption(c),
                      ),
                    ],
                  ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: stops.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    return StopCard(
                      stop: stop,
                      active: stop.deliveryId == _activeStopId,
                      onTap: () => _selectStop(stop.deliveryId),
                      onDeliver: () => _deliver(stop.deliveryId),
                      onSkip: () => _skip(stop.deliveryId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
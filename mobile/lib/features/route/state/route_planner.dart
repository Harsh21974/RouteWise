import 'package:flutter/foundation.dart';

import '../data/route_plan.dart';
import '../services/driver_location.dart';
import '../services/route_api.dart';

/// Lifecycle of the route planning flow.
enum RoutePhase { idle, solving, solved, error }

/// Owns the day's optimized route: solving state, per-stop progression
/// (delivered / skipped) and the aggregate stats shown on the Progress tab.
class RoutePlanner extends ChangeNotifier {
  RoutePlanner({RouteApi? api, DriverLocationSource? location})
      : _api = api ?? RouteApi(),
        _location = location ?? DeviceDriverLocationSource();

  final RouteApi _api;
  final DriverLocationSource _location;

  RoutePhase _phase = RoutePhase.idle;
  RoutePlan? _plan;
  List<OrderedStop> _stops = const [];
  String? _errorMessage;

  RoutePhase get phase => _phase;
  RoutePlan? get plan => _plan;
  bool get hasPlan => _plan != null && _stops.isNotEmpty;
  String? get errorMessage => _errorMessage;

  List<OrderedStop> get stops => List.unmodifiable(_stops);

  // -- Day stats -------------------------------------------------------------

  int get totalCount => _stops.length;
  int get deliveredCount =>
      _stops.where((s) => s.state == StopState.delivered).length;
  int get skippedCount =>
      _stops.where((s) => s.state == StopState.skipped).length;
  int get remainingCount =>
      _stops.where((s) => s.state == StopState.pending).length;

  /// Completed fraction 0..1 for the Progress ring (delivered + skipped).
  double get progress {
    if (totalCount == 0) return 0;
    return (deliveredCount + skippedCount) / totalCount;
  }

  bool get isAllComplete => totalCount > 0 && remainingCount == 0;

  /// Cumulative route distance driven so far — the distance to the furthest
  /// completed stop (the driver passes every earlier stop to get there).
  double get coveredMeters {
    double covered = 0;
    for (final stop in _stops) {
      if (stop.isDone) covered = stop.cumulativeMeters;
    }
    return covered;
  }

  // -- Solving ---------------------------------------------------------------

  /// Optimizes a route over [deliveryIds] starting from the driver's current
  /// location. Clears to an error phase when there is nothing to plan.
  Future<void> optimize({required List<int> deliveryIds}) async {
    if (deliveryIds.isEmpty) {
      _plan = null;
      _stops = const [];
      _phase = RoutePhase.error;
      _errorMessage = 'Nothing to optimize yet — add and geocode parcels first.';
      notifyListeners();
      return;
    }

    _phase = RoutePhase.solving;
    _errorMessage = null;
    notifyListeners();

    try {
      final start = await _location.current();
      final plan = await _api.optimize(deliveryIds: deliveryIds, start: start);
      _plan = plan;
      _stops = plan.stops;
      _phase = RoutePhase.solved;
    } catch (e) {
      _plan = null;
      _stops = const [];
      _phase = RoutePhase.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // -- Driving through the route ---------------------------------------------

  void markDelivered(int deliveryId) => _complete(deliveryId, StopState.delivered);

  void skip(int deliveryId) => _complete(deliveryId, StopState.skipped);

  void _complete(int deliveryId, StopState state) {
    final index = _stops.indexWhere((s) => s.deliveryId == deliveryId);
    if (index == -1 || _stops[index].isDone) return;
    final updated = [..._stops];
    updated[index] = updated[index].copyWith(state: state);
    _stops = updated;
    notifyListeners();
  }

  /// Discards the current plan so the driver can re-plan with the leftover
  /// stops or a fresh batch.
  void reset() {
    _plan = null;
    _stops = const [];
    _phase = RoutePhase.idle;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
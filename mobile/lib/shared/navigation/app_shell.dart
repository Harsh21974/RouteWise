import 'package:flutter/material.dart';

import '../../features/delivery/delivery_screen.dart';
import '../../features/intake/intake_screen.dart';
import '../../features/intake/state/intake_controller.dart';
import '../../features/route/screens/route_screen.dart';
import '../../features/route/state/route_planner.dart';

/// Driver-facing shell: bottom navigation across the three core tabs.
///
/// Screens stay alive (IndexedStack) so switching tabs never loses scroll
/// position or in-progress input. The [IntakeController] (today's parcels) and
/// the [RoutePlanner] (the optimized route + day stats) are owned here and
/// shared across the tabs they feed.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  late final IntakeController _intake;
  late final RoutePlanner _planner;

  @override
  void initState() {
    super.initState();
    _intake = IntakeController();
    _planner = RoutePlanner();
  }

  @override
  void dispose() {
    _planner.dispose();
    _intake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          IntakeScreen(controller: _intake),
          RouteScreen(planner: _planner, intake: _intake),
          DeliveryScreen(planner: _planner),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scan / Add',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'My Route',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../shared/design_system/widgets/empty_state.dart';

/// My Route tab: optimized drop order and the live map.
///
/// Placeholder only — routing business logic lands later.
class RouteScreen extends StatelessWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your route')),
      body: SafeArea(
        child: EmptyState(
          icon: Icons.route_rounded,
          title: 'Your route is empty',
          subtitle: 'Optimized drop order and the live route map will appear '
              'here once a route is assigned.',
        ),
      ),
    );
  }
}
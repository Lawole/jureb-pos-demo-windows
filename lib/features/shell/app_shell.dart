import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_home.dart';
import '../sales/checkout_screen.dart';

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.permission,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final Permission permission;
  final WidgetBuilder builder;
}

final _destinations = <_NavDestination>[
  _NavDestination(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    permission: Permission.viewDashboard,
    builder: (_) => const DashboardScreen(),
  ),
  _NavDestination(
    label: 'Sales',
    icon: Icons.point_of_sale_outlined,
    permission: Permission.makeSale,
    builder: (_) => const CheckoutScreen(),
  ),
  _NavDestination(
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
    permission: Permission.manageProducts,
    builder: (_) => const InventoryHome(),
  ),
  _NavDestination(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    permission: Permission.viewReports,
    builder: (_) => const _ComingSoonScreen(title: 'Reports'),
  ),
  _NavDestination(
    label: 'Staff',
    icon: Icons.badge_outlined,
    permission: Permission.manageStaff,
    builder: (_) => const _ComingSoonScreen(title: 'Staff & Roles'),
  ),
  _NavDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    permission: Permission.manageSettings,
    builder: (_) => const _ComingSoonScreen(title: 'Settings'),
  ),
];

/// Root app shell shown after login: a sidebar of nav destinations filtered
/// to what the logged-in staff member's role permits, plus the selected
/// screen's content.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<AuthController>().currentStaff;
    if (staff == null) return const SizedBox.shrink();

    final visibleDestinations =
        _destinations.where((d) => staff.can(d.permission)).toList();
    final selected = _selectedIndex.clamp(0, visibleDestinations.length - 1);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.point_of_sale, size: 32),
                  const SizedBox(height: 8),
                  Text(staff.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall),
                  Text(staff.role.name.toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Log out',
                    icon: const Icon(Icons.logout),
                    onPressed: () => context.read<AuthController>().logout(),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final d in visibleDestinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: visibleDestinations[selected].builder(context)),
        ],
      ),
    );
  }
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('$title — coming in a later phase',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

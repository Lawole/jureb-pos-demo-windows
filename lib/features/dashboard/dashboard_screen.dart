import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';
import '../inventory/inventory_home.dart';

/// Dashboard shown after login. Sales/till/shift cards stay placeholders
/// until Phase 4 reporting gives them real data; low-stock is wired up
/// since Phase 2 inventory tracking already exists.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<AuthController>().currentStaff;
    final db = context.read<Services>().db;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${staff?.fullName ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Role: ${staff?.role.name ?? ''}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              const _PlaceholderCard(title: "Today's Sales", value: '₦0'),
              const _PlaceholderCard(title: 'Till Status', value: 'Closed'),
              StreamBuilder<List<Product>>(
                stream: db.productDao.watchLowStock(),
                builder: (context, snapshot) {
                  return _LowStockCard(count: snapshot.data?.length);
                },
              ),
              const _PlaceholderCard(title: 'Active Shift', value: 'None'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final hasLowStock = (count ?? 0) > 0;
    return SizedBox(
      width: 220,
      child: Card(
        color: hasLowStock ? Theme.of(context).colorScheme.errorContainer : null,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InventoryHome()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Low Stock Items',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(count?.toString() ?? '…',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      ),
    );
  }
}

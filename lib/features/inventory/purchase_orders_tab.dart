import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import 'create_purchase_order_page.dart';
import 'purchase_order_detail_page.dart';

Color _statusColor(BuildContext context, PurchaseOrderStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    PurchaseOrderStatus.draft => scheme.surfaceContainerHighest,
    PurchaseOrderStatus.ordered => scheme.tertiaryContainer,
    PurchaseOrderStatus.partiallyReceived => scheme.secondaryContainer,
    PurchaseOrderStatus.received => scheme.primaryContainer,
    PurchaseOrderStatus.cancelled => scheme.errorContainer,
  };
}

class PurchaseOrdersTab extends StatelessWidget {
  const PurchaseOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreatePurchaseOrderPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New purchase order'),
      ),
      body: StreamBuilder<List<PurchaseOrder>>(
        stream: db.purchaseOrderDao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('No purchase orders yet.'));
          }
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: FutureBuilder<Supplier?>(
                  future: db.supplierDao.findById(order.supplierId),
                  builder: (context, snap) => Text(snap.data?.name ?? order.supplierId),
                ),
                subtitle: Text('Ordered ${order.orderedAt.toLocal().toString().split(' ').first}'),
                trailing: Chip(
                  label: Text(order.status.name),
                  backgroundColor: _statusColor(context, order.status),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PurchaseOrderDetailPage(purchaseOrderId: order.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

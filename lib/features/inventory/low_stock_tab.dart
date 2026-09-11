import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';
import 'stock_adjustment_dialog.dart';

class LowStockTab extends StatelessWidget {
  const LowStockTab({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;
    final staff = context.watch<AuthController>().currentStaff!;

    return StreamBuilder<List<Product>>(
      stream: db.productDao.watchLowStock(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!;
        if (products.isEmpty) {
          return const Center(child: Text('Nothing is low on stock. 🎉'));
        }
        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
              title: Text(product.name),
              subtitle: Text(
                  'On hand: ${product.quantityOnHand} · Threshold: ${product.lowStockThreshold}'),
              trailing: staff.can(Permission.adjustStock)
                  ? FilledButton(
                      onPressed: () => showStockAdjustmentDialog(context, product),
                      child: const Text('Restock'),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

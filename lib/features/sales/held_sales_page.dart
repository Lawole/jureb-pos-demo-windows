import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/cart_controller.dart';

class HeldSalesPage extends StatelessWidget {
  const HeldSalesPage({super.key});

  Future<void> _resume(BuildContext context, Sale sale) async {
    final db = context.read<Services>().db;
    final items = await db.saleDao.itemsFor(sale.id);
    if (!context.mounted) return;
    context.read<CartController>().loadLines(
      [
        for (final item in items)
          CartLine(
            productId: item.productId,
            name: item.productNameSnapshot,
            unitPriceKobo: item.unitPriceKobo,
            quantity: item.quantity,
            isVatable: item.isVatable,
            lineDiscountKobo: item.discountKobo,
          ),
      ],
      resuming: sale,
    );
    Navigator.of(context).pop();
  }

  Future<void> _void(BuildContext context, Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Void held sale?'),
        content: Text('Discard ${sale.receiptNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Void')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<Services>().sales.voidHeldSale(sale.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      appBar: AppBar(title: const Text('Held sales')),
      body: StreamBuilder<List<Sale>>(
        stream: db.saleDao.watchHeldSales(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sales = snapshot.data!;
          if (sales.isEmpty) {
            return const Center(child: Text('No sales on hold.'));
          }
          return ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return ListTile(
                title: Text(sale.receiptNumber),
                subtitle: Text(
                    'Held ${DateFormat('dd MMM, hh:mm a').format(sale.heldAt ?? sale.createdAt)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(NairaFormatter.forTill(sale.totalKobo),
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _void(context, sale),
                      child: const Text('Void'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _resume(context, sale),
                      child: const Text('Resume'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

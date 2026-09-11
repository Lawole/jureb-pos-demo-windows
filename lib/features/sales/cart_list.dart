import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../state/cart_controller.dart';

class CartList extends StatelessWidget {
  const CartList({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final lines = cart.lines;
    final totals = cart.totals;

    if (lines.isEmpty) {
      return const Expanded(
        child: Center(child: Text('Cart is empty — scan or search a product to begin.')),
      );
    }

    return Expanded(
      child: ListView.separated(
        itemCount: lines.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final line = lines[index];
          final lineResult = totals.lines[index];
          return ListTile(
            title: Text(line.name),
            subtitle: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => cart.setQuantity(line.productId, line.quantity - 1),
                ),
                SizedBox(
                  width: 40,
                  child: Text(_qty(line.quantity), textAlign: TextAlign.center),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => cart.setQuantity(line.productId, line.quantity + 1),
                ),
                const SizedBox(width: 12),
                Text('@ ${NairaFormatter.forTill(line.unitPriceKobo)}'),
                if (line.lineDiscountKobo > 0) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('-${NairaFormatter.forTill(line.lineDiscountKobo)}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(NairaFormatter.forTill(lineResult.totalKobo),
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  tooltip: 'Line discount',
                  icon: const Icon(Icons.percent),
                  onPressed: () => _showLineDiscountDialog(context, cart, line),
                ),
                IconButton(
                  tooltip: 'Void line',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => cart.removeLine(line.productId),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _qty(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();

  Future<void> _showLineDiscountDialog(
      BuildContext context, CartController cart, CartLine line) async {
    final controller = TextEditingController(
        text: line.lineDiscountKobo > 0 ? (line.lineDiscountKobo / 100).toStringAsFixed(2) : '');
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Discount — ${line.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Discount amount (₦)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(0), child: const Text('Clear')),
          FilledButton(
            onPressed: () {
              final naira = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(context).pop((naira * 100).round());
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (result != null) {
      cart.setLineDiscount(line.productId, result);
    }
  }
}

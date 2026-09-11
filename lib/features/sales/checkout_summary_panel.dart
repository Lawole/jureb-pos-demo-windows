import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../state/cart_controller.dart';

class CheckoutSummaryPanel extends StatelessWidget {
  const CheckoutSummaryPanel({
    super.key,
    required this.onHold,
    required this.onPay,
    this.showHold = true,
  });

  final VoidCallback onHold;
  final VoidCallback onPay;
  final bool showHold;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final totals = cart.totals;
    final hasItems = cart.lines.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: hasItems ? () => _showCartDiscountDialog(context, cart) : null,
              icon: const Icon(Icons.percent),
              label: Text(totals.cartDiscountKobo > 0
                  ? 'Cart discount: ${NairaFormatter.forTill(totals.cartDiscountKobo)}'
                  : 'Add cart discount'),
            ),
            const SizedBox(height: 16),
            _totalsRow(context, 'Subtotal', totals.subtotalKobo),
            if (totals.cartDiscountKobo > 0)
              _totalsRow(context, 'Discount', -totals.cartDiscountKobo),
            _totalsRow(context, 'VAT (7.5%)', totals.vatKobo),
            const Divider(),
            _totalsRow(context, 'TOTAL', totals.totalKobo, emphasize: true),
            const SizedBox(height: 24),
            if (showHold) ...[
              OutlinedButton.icon(
                onPressed: hasItems ? onHold : null,
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Hold sale'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              onPressed: hasItems ? onPay : null,
              icon: const Icon(Icons.payment),
              label: const Text('Pay'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsRow(BuildContext context, String label, int amountKobo, {bool emphasize = false}) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(NairaFormatter.forTill(amountKobo), style: style),
        ],
      ),
    );
  }

  Future<void> _showCartDiscountDialog(BuildContext context, CartController cart) async {
    final current = cart.cartDiscountKobo;
    final controller =
        TextEditingController(text: current > 0 ? (current / 100).toStringAsFixed(2) : '');
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Whole-cart discount'),
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
      cart.setCartDiscount(result);
    }
  }
}

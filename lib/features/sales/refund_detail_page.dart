import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';

class RefundDetailPage extends StatefulWidget {
  const RefundDetailPage({super.key, required this.sale});

  final Sale sale;

  @override
  State<RefundDetailPage> createState() => _RefundDetailPageState();
}

class _RefundDetailPageState extends State<RefundDetailPage> {
  final Map<String, TextEditingController> _controllers = {};
  PaymentMethod _refundMethod = PaymentMethod.cash;
  bool _submitting = false;
  String? _error;

  TextEditingController _controllerFor(String itemId) =>
      _controllers.putIfAbsent(itemId, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(List<SaleItem> items) async {
    final services = context.read<Services>();
    final staffId = context.read<AuthController>().currentStaff!.id;
    final tillSession = await services.db.tillSessionDao.findOpen();
    if (tillSession == null) {
      setState(() => _error = 'Open a till before processing a refund');
      return;
    }
    final lines = <RefundLineInput>[];
    for (final item in items) {
      final text = _controllers[item.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final qty = double.tryParse(text);
      if (qty == null || qty <= 0) continue;
      lines.add(RefundLineInput(saleItemId: item.id, quantity: qty));
    }
    if (lines.isEmpty) {
      setState(() => _error = 'Enter a quantity to refund for at least one item');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final refund = await services.sales.refundSale(
        originalSaleId: widget.sale.id,
        tillSessionId: tillSession.id,
        staffId: staffId,
        returnedLines: lines,
        refundMethod: _refundMethod,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Refund complete'),
            content: Text(
                'Refund ${refund.receiptNumber} issued for ${NairaFormatter.forTill(refund.totalKobo)}.'),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context)
                    ..pop()
                    ..pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Refund — ${widget.sale.receiptNumber}')),
      body: FutureBuilder<List<SaleItem>>(
        future: _itemsFuture ??= _loadItems(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          final refundable = items.where((i) => i.quantity - i.returnedQuantity > 0).toList();

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Original total: ${NairaFormatter.forTill(widget.sale.totalKobo)}'),
                const SizedBox(height: 16),
                if (refundable.isEmpty)
                  const Text('Every item on this sale has already been refunded.')
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: refundable.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = refundable[index];
                        final remaining = item.quantity - item.returnedQuantity;
                        return Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(item.productNameSnapshot),
                            ),
                            Expanded(
                              child: Text('Sold: ${_fmt(item.quantity)}'),
                            ),
                            Expanded(
                              child: Text('Refundable: ${_fmt(remaining)}'),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controllerFor(item.id),
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Refund qty', isDense: true),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Refund method: '),
                    const SizedBox(width: 8),
                    DropdownButton<PaymentMethod>(
                      value: _refundMethod,
                      items: [
                        for (final m in PaymentMethod.values)
                          DropdownMenuItem(value: m, child: Text(m.name)),
                      ],
                      onChanged: (v) => setState(() => _refundMethod = v!),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: refundable.isEmpty || _submitting ? null : () => _submit(items),
                  child: _submitting
                      ? const SizedBox(
                          height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Process refund'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<SaleItem>>? _itemsFuture;

  Future<List<SaleItem>> _loadItems() {
    final db = context.read<Services>().db;
    return db.saleDao.itemsFor(widget.sale.id);
  }

  String _fmt(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();
}

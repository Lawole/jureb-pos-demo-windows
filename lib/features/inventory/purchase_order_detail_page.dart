import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';

class PurchaseOrderDetailPage extends StatefulWidget {
  const PurchaseOrderDetailPage({super.key, required this.purchaseOrderId});

  final String purchaseOrderId;

  @override
  State<PurchaseOrderDetailPage> createState() =>
      _PurchaseOrderDetailPageState();
}

class _PurchaseOrderDetailPageState extends State<PurchaseOrderDetailPage> {
  final Map<String, TextEditingController> _receiveControllers = {};
  bool _submitting = false;
  String? _error;

  TextEditingController _controllerFor(String itemId) =>
      _receiveControllers.putIfAbsent(itemId, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _receiveControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _receive(List<PurchaseOrderItem> items) async {
    final lines = <ReceivedLineInput>[];
    for (final item in items) {
      final text = _receiveControllers[item.id]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final qty = double.tryParse(text);
      if (qty == null || qty <= 0) continue;
      lines.add(ReceivedLineInput(itemId: item.id, quantityReceivedNow: qty));
    }
    if (lines.isEmpty) {
      setState(
        () => _error = 'Enter a received quantity for at least one line',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final inventory = context.read<Services>().inventory;
      final staffId = context.read<AuthController>().currentStaff!.id;
      await inventory.receivePurchaseOrder(
        purchaseOrderId: widget.purchaseOrderId,
        receivedLines: lines,
        staffId: staffId,
      );
      for (final c in _receiveControllers.values) {
        c.clear();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase order')),
      body: StreamBuilder<PurchaseOrder?>(
        stream: db.purchaseOrderDao.watchById(widget.purchaseOrderId),
        builder: (context, orderSnapshot) {
          final order = orderSnapshot.data;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<PurchaseOrderItem>>(
            stream: db.purchaseOrderDao.watchItems(widget.purchaseOrderId),
            builder: (context, itemsSnapshot) {
              final items = itemsSnapshot.data ?? const [];
              final canReceive =
                  order.status != PurchaseOrderStatus.received &&
                  order.status != PurchaseOrderStatus.cancelled;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status: ${order.status.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (order.expectedAt != null)
                        Text(
                          'Expected: ${order.expectedAt!.toLocal().toString().split(' ').first}',
                        ),
                    ],
                  ),
                  if (order.notes != null) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${order.notes}'),
                  ],
                  const SizedBox(height: 24),
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                      4: FlexColumnWidth(1.4),
                    },
                    children: [
                      const TableRow(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Product',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Ordered',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Received',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Unit cost',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Receive now',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      for (final item in items)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: FutureBuilder<Product?>(
                                future: db.productDao.findById(item.productId),
                                builder: (context, snap) =>
                                    Text(snap.data?.name ?? item.productId),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${item.quantityOrdered}'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${item.quantityReceived}'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                NairaFormatter.forReceipt(item.unitCostKobo),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: canReceive
                                  ? TextField(
                                      controller: _controllerFor(item.id),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (canReceive) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : () => _receive(items),
                      child: _submitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Record receipt'),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';

class _DraftLine {
  _DraftLine();
  String? productId;
  final quantityController = TextEditingController(text: '1');
  final unitCostController = TextEditingController();

  void dispose() {
    quantityController.dispose();
    unitCostController.dispose();
  }
}

class CreatePurchaseOrderPage extends StatefulWidget {
  const CreatePurchaseOrderPage({super.key});

  @override
  State<CreatePurchaseOrderPage> createState() => _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _supplierId;
  DateTime? _expectedAt;
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_supplierId == null) {
      setState(() => _error = 'Select a supplier');
      return;
    }
    final items = <PurchaseOrderLineInput>[];
    for (final line in _lines) {
      if (line.productId == null) continue;
      final qty = double.tryParse(line.quantityController.text.trim());
      final cost = double.tryParse(line.unitCostController.text.trim());
      if (qty == null || qty <= 0 || cost == null || cost < 0) continue;
      items.add(PurchaseOrderLineInput(
        productId: line.productId!,
        quantityOrdered: qty,
        unitCostKobo: (cost * 100).round(),
      ));
    }
    if (items.isEmpty) {
      setState(() => _error = 'Add at least one valid line item');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final inventory = context.read<Services>().inventory;
      final staffId = context.read<AuthController>().currentStaff!.id;
      await inventory.createPurchaseOrder(
        supplierId: _supplierId!,
        staffId: staffId,
        items: items,
        expectedAt: _expectedAt,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New purchase order'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create order'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            StreamBuilder<List<Supplier>>(
              stream: db.supplierDao.watchAll(),
              builder: (context, snapshot) {
                final suppliers = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    for (final s in suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_expectedAt == null
                  ? 'Expected delivery date (optional)'
                  : 'Expected: ${_expectedAt!.toLocal().toString().split(' ').first}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _expectedAt = picked);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 24),
            Text('Line items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            StreamBuilder<List<Product>>(
              stream: db.productDao.watchAll(),
              builder: (context, snapshot) {
                final products = snapshot.data ?? [];
                return Column(
                  children: [
                    for (final line in _lines)
                      _LineItemRow(
                        line: line,
                        products: products,
                        onChanged: () => setState(() {}),
                        onRemove: _lines.length > 1
                            ? () => setState(() {
                                  line.dispose();
                                  _lines.remove(line);
                                })
                            : null,
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _lines.add(_DraftLine())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add line'),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    required this.line,
    required this.products,
    required this.onChanged,
    required this.onRemove,
  });

  final _DraftLine line;
  final List<Product> products;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: line.productId,
              decoration: const InputDecoration(labelText: 'Product'),
              items: [
                for (final p in products)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) {
                line.productId = v;
                Product? product;
                for (final p in products) {
                  if (p.id == v) {
                    product = p;
                    break;
                  }
                }
                if (product != null && line.unitCostController.text.isEmpty) {
                  line.unitCostController.text =
                      (product.costPriceKobo / 100).toStringAsFixed(2);
                }
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: line.quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qty ordered'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: line.unitCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Unit cost (₦)'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';

/// Adjustment types a user picks from directly. Sale-driven movements
/// (saleDeduction, saleReturn) are posted automatically by the checkout
/// flow in Phase 3 and never appear here.
const _manualTypes = [
  StockMovementType.restock,
  StockMovementType.damage,
  StockMovementType.loss,
  StockMovementType.transferIn,
  StockMovementType.transferOut,
  StockMovementType.adjustmentIncrease,
  StockMovementType.adjustmentDecrease,
];

String _labelFor(StockMovementType type) => switch (type) {
      StockMovementType.restock => 'Restock',
      StockMovementType.damage => 'Damage',
      StockMovementType.loss => 'Loss',
      StockMovementType.transferIn => 'Transfer in',
      StockMovementType.transferOut => 'Transfer out',
      StockMovementType.adjustmentIncrease => 'Adjustment (increase)',
      StockMovementType.adjustmentDecrease => 'Adjustment (decrease)',
      StockMovementType.saleDeduction => 'Sale',
      StockMovementType.saleReturn => 'Sale return',
    };

Future<void> showStockAdjustmentDialog(BuildContext context, Product product) {
  return showDialog(
    context: context,
    builder: (_) => StockAdjustmentDialog(product: product),
  );
}

class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({super.key, required this.product});

  final Product product;

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  StockMovementType _type = StockMovementType.restock;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final inventory = context.read<Services>().inventory;
      final staffId = context.read<AuthController>().currentStaff!.id;
      await inventory.adjustStock(
        productId: widget.product.id,
        type: _type,
        quantity: int.parse(_quantityController.text.trim()),
        staffId: staffId,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
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
    return AlertDialog(
      title: Text('Adjust stock — ${widget.product.name}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current quantity: ${widget.product.quantityOnHand}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<StockMovementType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Movement type'),
                items: [
                  for (final t in _manualTypes)
                    DropdownMenuItem(value: t, child: Text(_labelFor(t))),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                autofocus: true,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Apply'),
        ),
      ],
    );
  }
}

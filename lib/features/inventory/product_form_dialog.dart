import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';

/// Shows the add/edit product dialog. Returns after the dialog is closed;
/// the caller doesn't need the result since the product list is a live
/// stream that updates itself.
Future<void> showProductFormDialog(BuildContext context, {Product? existing}) {
  return showDialog(
    context: context,
    builder: (_) => ProductFormDialog(existing: existing),
  );
}

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.existing});

  final Product? existing;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _barcodeController =
      TextEditingController(text: widget.existing?.barcode ?? '');
  late final _skuController =
      TextEditingController(text: widget.existing?.sku ?? '');
  late final _costController = TextEditingController(
      text: widget.existing == null
          ? ''
          : (widget.existing!.costPriceKobo / 100).toStringAsFixed(2));
  late final _priceController = TextEditingController(
      text: widget.existing == null
          ? ''
          : (widget.existing!.sellingPriceKobo / 100).toStringAsFixed(2));
  late final _lowStockController = TextEditingController(
      text: '${widget.existing?.lowStockThreshold ?? 0}');
  late final _initialQuantityController = TextEditingController(text: '0');

  String? _categoryId;
  String? _supplierId;
  late ProductUnit _unit = widget.existing?.unit ?? ProductUnit.piece;
  late bool _isVatable = widget.existing?.isVatable ?? true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
    _supplierId = widget.existing?.supplierId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _skuController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _lowStockController.dispose();
    _initialQuantityController.dispose();
    super.dispose();
  }

  int _parseKobo(String text) =>
      ((double.tryParse(text.trim()) ?? 0) * 100).round();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final inventory = context.read<Services>().inventory;
      final staffId = context.read<AuthController>().currentStaff!.id;
      final costKobo = _parseKobo(_costController.text);
      final priceKobo = _parseKobo(_priceController.text);
      final lowStock = int.tryParse(_lowStockController.text.trim()) ?? 0;

      if (widget.existing == null) {
        final initialQty =
            int.tryParse(_initialQuantityController.text.trim()) ?? 0;
        await inventory.createProduct(
          name: _nameController.text.trim(),
          barcode: _barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim(),
          sku: _skuController.text.trim().isEmpty
              ? null
              : _skuController.text.trim(),
          categoryId: _categoryId,
          supplierId: _supplierId,
          costPriceKobo: costKobo,
          sellingPriceKobo: priceKobo,
          isVatable: _isVatable,
          unit: _unit,
          lowStockThreshold: lowStock,
          initialQuantity: initialQty,
          staffId: staffId,
        );
      } else {
        await inventory.updateProduct(widget.existing!.copyWith(
          name: _nameController.text.trim(),
          barcode: Value(_barcodeController.text.trim().isEmpty
              ? null
              : _barcodeController.text.trim()),
          sku: Value(_skuController.text.trim().isEmpty
              ? null
              : _skuController.text.trim()),
          categoryId: Value(_categoryId),
          supplierId: Value(_supplierId),
          costPriceKobo: costKobo,
          sellingPriceKobo: priceKobo,
          isVatable: _isVatable,
          unit: _unit,
          lowStockThreshold: lowStock,
        ));
      }
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
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit product' : 'Add product'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        decoration:
                            const InputDecoration(labelText: 'Barcode (optional)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _skuController,
                        decoration:
                            const InputDecoration(labelText: 'SKU (optional)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Cost price (₦)'),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Selling price (₦)'),
                        validator: (v) =>
                            double.tryParse(v ?? '') == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ProductUnit>(
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          for (final unit in ProductUnit.values)
                            DropdownMenuItem(
                                value: unit, child: Text(unit.name)),
                        ],
                        onChanged: (v) => setState(() => _unit = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lowStockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Low stock threshold'),
                      ),
                    ),
                  ],
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _initialQuantityController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Initial stock quantity'),
                  ),
                ],
                const SizedBox(height: 12),
                StreamBuilder<List<Category>>(
                  stream: db.categoryDao.watchAll(),
                  builder: (context, snapshot) {
                    final categories = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        for (final c in categories)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Supplier>>(
                  stream: db.supplierDao.watchAll(),
                  builder: (context, snapshot) {
                    final suppliers = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _supplierId,
                      decoration: const InputDecoration(labelText: 'Supplier'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        for (final s in suppliers)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _supplierId = v),
                    );
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('VAT applicable (7.5%)'),
                  value: _isVatable,
                  onChanged: (v) => setState(() => _isVatable = v),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

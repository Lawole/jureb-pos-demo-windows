import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/cart_controller.dart';

/// The primary checkout input: a hardware barcode scanner behaves like a
/// keyboard that types the code then hits Enter, so this is just an
/// autofocused text field. Typing without a scanner (manual search) shows
/// live suggestions below, for products with no barcode or a bad label.
class ScanSearchBar extends StatefulWidget {
  const ScanSearchBar({super.key});

  @override
  State<ScanSearchBar> createState() => _ScanSearchBarState();
}

class _ScanSearchBarState extends State<ScanSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return;
    final db = context.read<Services>().db;

    final exactMatch = await db.productDao.findByBarcode(value);
    if (exactMatch != null) {
      _addProduct(exactMatch);
      return;
    }

    final matches = await db.productDao.watchAll(query: value).first;
    if (matches.length == 1) {
      _addProduct(matches.first);
    } else if (matches.isEmpty) {
      setState(() => _error = 'No product matches "$value"');
    } else {
      // Multiple matches: leave the live suggestion list below for the
      // cashier to pick from instead of guessing which one they meant.
      setState(() => _error = null);
    }
  }

  void _addProduct(Product product) {
    if (product.quantityOnHand <= 0) {
      setState(() => _error = '${product.name} is out of stock');
      return;
    }
    context.read<CartController>().addProduct(product);
    _controller.clear();
    setState(() {
      _query = '';
      _error = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.qr_code_scanner),
            hintText: 'Scan barcode or type product name / SKU…',
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
          onChanged: (value) => setState(() => _query = value),
          onSubmitted: _handleSubmit,
        ),
        if (_query.isNotEmpty)
          StreamBuilder<List<Product>>(
            stream: db.productDao.watchAll(query: _query),
            builder: (context, snapshot) {
              final results = snapshot.data ?? [];
              if (results.isEmpty) return const SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.only(top: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final product = results[index];
                      return ListTile(
                        dense: true,
                        title: Text(product.name),
                        subtitle: Text(
                            'Stock: ${product.quantityOnHand} · ${NairaFormatter.forTill(product.sellingPriceKobo)}'),
                        onTap: () => _addProduct(product),
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

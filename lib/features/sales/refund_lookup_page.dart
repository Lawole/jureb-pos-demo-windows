import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import 'refund_detail_page.dart';

class RefundLookupPage extends StatefulWidget {
  const RefundLookupPage({super.key});

  @override
  State<RefundLookupPage> createState() => _RefundLookupPageState();
}

class _RefundLookupPageState extends State<RefundLookupPage> {
  final _controller = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final receiptNumber = _controller.text.trim();
    if (receiptNumber.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    final db = context.read<Services>().db;
    final sale = await db.saleDao.findByReceiptNumber(receiptNumber);
    if (!mounted) return;
    setState(() => _searching = false);
    if (sale == null) {
      setState(() => _error = 'No sale found with receipt number "$receiptNumber"');
      return;
    }
    if (sale.status != SaleStatus.completed && sale.status != SaleStatus.partiallyRefunded) {
      setState(() => _error =
          'Sale ${sale.receiptNumber} is ${sale.status.name} and cannot be refunded');
      return;
    }
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RefundDetailPage(sale: sale)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Returns / refunds')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the receipt number from the original sale.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Receipt number',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  onSubmitted: (_) => _searching ? null : _search(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(
                          height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Find sale'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

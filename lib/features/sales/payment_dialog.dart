import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';
import '../../state/cart_controller.dart';
import 'receipt_preview_page.dart';

Future<CompletedSale?> showPaymentDialog(
  BuildContext context, {
  required String tillSessionId,
  required int totalDueKobo,
  Sale? resumingSale,
}) {
  return showDialog<CompletedSale>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PaymentDialog(
      tillSessionId: tillSessionId,
      totalDueKobo: totalDueKobo,
      resumingSale: resumingSale,
    ),
  );
}

class _Tender {
  _Tender({required this.method, required this.amountKobo, this.reference});
  final PaymentMethod method;
  final int amountKobo;
  final String? reference;
}

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.tillSessionId,
    required this.totalDueKobo,
    this.resumingSale,
  });

  final String tillSessionId;
  final int totalDueKobo;
  final Sale? resumingSale;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final List<_Tender> _tenders = [];
  PaymentMethod _method = PaymentMethod.cash;
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  bool _submitting = false;
  String? _error;
  CompletedSale? _completed;

  int get _totalTendered => _tenders.fold(0, (sum, t) => sum + t.amountKobo);
  int get _balanceRemaining => widget.totalDueKobo - _totalTendered;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _addTender(int amountKobo) {
    if (amountKobo <= 0) return;
    setState(() {
      _tenders.add(_Tender(
        method: _method,
        amountKobo: amountKobo,
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
      ));
      _amountController.clear();
      _referenceController.clear();
      _error = null;
    });
  }

  void _addExact() {
    final remaining = _balanceRemaining;
    if (remaining > 0) _addTender(remaining);
  }

  void _addFromField() {
    final naira = double.tryParse(_amountController.text.trim());
    if (naira == null || naira <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    _addTender((naira * 100).round());
  }

  Future<void> _completeSale() async {
    if (_balanceRemaining > 0) {
      setState(() => _error = 'Payments do not yet cover the total');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final saleService = context.read<Services>().sales;
      final staffId = context.read<AuthController>().currentStaff!.id;
      final payments = [
        for (final t in _tenders)
          PaymentDraft(method: t.method, amountKobo: t.amountKobo, reference: t.reference),
      ];

      final CompletedSale result;
      if (widget.resumingSale != null) {
        result = await saleService.completeHeldSale(
          saleId: widget.resumingSale!.id,
          staffId: staffId,
          payments: payments,
        );
      } else {
        final cart = context.read<CartController>();
        result = await saleService.completeSale(
          tillSessionId: widget.tillSessionId,
          staffId: staffId,
          lines: [
            for (final l in cart.lines)
              SaleLineDraft(
                productId: l.productId,
                productNameSnapshot: l.name,
                unitPriceKobo: l.unitPriceKobo,
                quantity: l.quantity,
                isVatable: l.isVatable,
                lineDiscountKobo: l.lineDiscountKobo,
              ),
          ],
          payments: payments,
          cartDiscountKobo: cart.cartDiscountKobo,
        );
      }
      setState(() => _completed = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed != null) {
      return _SuccessView(
        completedSale: _completed!,
        onDone: () => Navigator.of(context).pop(_completed),
      );
    }

    return AlertDialog(
      title: const Text('Take payment'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summaryRow('Total due', widget.totalDueKobo),
            _summaryRow('Tendered', _totalTendered),
            _summaryRow(
              _balanceRemaining > 0 ? 'Balance remaining' : 'Change due',
              _balanceRemaining.abs(),
              emphasize: true,
            ),
            const Divider(height: 24),
            if (_tenders.isNotEmpty) ...[
              ..._tenders.map((t) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_methodLabel(t.method)),
                    subtitle: t.reference != null ? Text('Ref: ${t.reference}') : null,
                    trailing: Text(NairaFormatter.forTill(t.amountKobo)),
                  )),
              const Divider(),
            ],
            Row(
              children: [
                DropdownButton<PaymentMethod>(
                  value: _method,
                  items: [
                    for (final m in PaymentMethod.values)
                      DropdownMenuItem(value: m, child: Text(_methodLabel(m))),
                  ],
                  onChanged: (v) => setState(() => _method = v!),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (₦)'),
                    onSubmitted: (_) => _addFromField(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addFromField,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'Add tender',
                ),
              ],
            ),
            if (_method != PaymentMethod.cash)
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Reference (optional)'),
              ),
            if (_method == PaymentMethod.cash && _balanceRemaining > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final note in [200, 500, 1000, 2000, 5000])
                    OutlinedButton(
                      onPressed: () => _addTender(note * 100),
                      child: Text('₦$note'),
                    ),
                  FilledButton.tonal(
                    onPressed: _addExact,
                    child: const Text('Exact'),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting || _balanceRemaining > 0 ? null : _completeSale,
          child: _submitting
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Complete sale'),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, int amountKobo, {bool emphasize = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: emphasize ? const TextStyle(fontWeight: FontWeight.bold) : null),
            Text(NairaFormatter.forTill(amountKobo),
                style: emphasize
                    ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                    : null),
          ],
        ),
      );

  String _methodLabel(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.transfer => 'Transfer',
        PaymentMethod.other => 'Other',
      };
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.completedSale, required this.onDone});

  final CompletedSale completedSale;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sale complete'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text('Receipt ${completedSale.sale.receiptNumber}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('Total: ${NairaFormatter.forTill(completedSale.sale.totalKobo)}'),
            if (completedSale.changeDueKobo > 0)
              Text('Change due: ${NairaFormatter.forTill(completedSale.changeDueKobo)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReceiptPreviewPage(
                    saleId: completedSale.sale.id,
                    changeDueKobo: completedSale.changeDueKobo,
                  ),
                ),
              ),
              icon: const Icon(Icons.print_outlined),
              label: const Text('View / print receipt'),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}

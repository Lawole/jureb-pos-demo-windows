import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';
import '../../state/cart_controller.dart';
import 'cart_list.dart';
import 'checkout_summary_panel.dart';
import 'held_sales_page.dart';
import 'payment_dialog.dart';
import 'refund_lookup_page.dart';
import 'scan_search_bar.dart';
import 'till_close_dialog.dart';
import 'till_open_dialog.dart';

/// The main till screen. Everything here is gated on a till being open —
/// `db.tillSessionDao.watchOpen()` is a live stream, so the moment someone
/// opens or closes the till this screen switches views automatically.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return StreamBuilder<TillSession?>(
      stream: db.tillSessionDao.watchOpen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final session = snapshot.data;
        if (session == null) return const _NoTillOpenView();
        return _CheckoutBody(session: session);
      },
    );
  }
}

class _NoTillOpenView extends StatelessWidget {
  const _NoTillOpenView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.point_of_sale_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('No till is open yet.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showTillOpenDialog(context),
            icon: const Icon(Icons.lock_open),
            label: const Text('Open till'),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBody extends StatelessWidget {
  const _CheckoutBody({required this.session});

  final TillSession session;

  Future<void> _holdSale(BuildContext context) async {
    final cart = context.read<CartController>();
    if (cart.lines.isEmpty) return;
    final saleService = context.read<Services>().sales;
    final staffId = context.read<AuthController>().currentStaff!.id;
    try {
      final held = await saleService.holdSale(
        tillSessionId: session.id,
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
        cartDiscountKobo: cart.cartDiscountKobo,
      );
      cart.clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sale held as ${held.receiptNumber}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not hold sale: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;
    final cart = context.watch<CartController>();
    final totalDueKobo = cart.resumingSale?.totalKobo ?? cart.totals.totalKobo;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.point_of_sale, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                  'Till open since ${DateFormat('hh:mm a').format(session.openedAt)} · '
                  'Float ${NairaFormatter.forTill(session.openingFloatKobo)}'),
              const Spacer(),
              StreamBuilder<List<Sale>>(
                stream: db.saleDao.watchHeldSales(),
                builder: (context, snapshot) {
                  final heldCount = snapshot.data?.length ?? 0;
                  return TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HeldSalesPage()),
                    ),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: Text('Held sales ($heldCount)'),
                  );
                },
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RefundLookupPage()),
                ),
                icon: const Icon(Icons.assignment_return_outlined),
                label: const Text('Returns'),
              ),
              OutlinedButton.icon(
                onPressed: () => showTillCloseDialog(context, session),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Close till'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const ScanSearchBar(),
                      const SizedBox(height: 8),
                      const CartList(),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CheckoutSummaryPanel(
                    showHold: cart.resumingSale == null,
                    onHold: () => _holdSale(context),
                    onPay: () async {
                      final result = await showPaymentDialog(
                        context,
                        tillSessionId: session.id,
                        totalDueKobo: totalDueKobo,
                        resumingSale: cart.resumingSale,
                      );
                      if (result != null) cart.clear();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

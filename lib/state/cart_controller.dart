import 'package:flutter/foundation.dart';
import 'package:pos_core/pos_core.dart';

/// One item in the cart, before it becomes a real sale in the database.
class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    required this.unitPriceKobo,
    required this.quantity,
    required this.isVatable,
    this.lineDiscountKobo = 0,
  });

  final String productId;
  final String name;
  final int unitPriceKobo;
  double quantity;
  final bool isVatable;
  int lineDiscountKobo;
}

/// Everything about the cart currently being rung up at the till, in one
/// place. This is a [ChangeNotifier] — every method that changes something
/// ends with `notifyListeners()`, which tells every widget on screen that's
/// watching this controller to rebuild.
///
/// A cart only becomes a real database record when it's held or paid for
/// (see `SaleService` in pos_core) — nothing in this class touches the
/// database.
class CartController extends ChangeNotifier {
  final List<CartLine> lines = [];
  int cartDiscountKobo = 0;

  /// Set while the cart on screen is a held sale being resumed, so "Pay"
  /// knows to complete that existing sale instead of creating a new one.
  Sale? resumingSale;

  void addProduct(Product product, {double quantity = 1}) {
    final existing = lines.where((l) => l.productId == product.id).firstOrNull;
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      lines.add(CartLine(
        productId: product.id,
        name: product.name,
        unitPriceKobo: product.sellingPriceKobo,
        quantity: quantity,
        isVatable: product.isVatable,
      ));
    }
    notifyListeners();
  }

  void setQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeLine(productId);
      return;
    }
    final line = lines.where((l) => l.productId == productId).firstOrNull;
    if (line != null) {
      line.quantity = quantity;
      notifyListeners();
    }
  }

  void setLineDiscount(String productId, int discountKobo) {
    final line = lines.where((l) => l.productId == productId).firstOrNull;
    if (line != null) {
      line.lineDiscountKobo = discountKobo;
      notifyListeners();
    }
  }

  void removeLine(String productId) {
    lines.removeWhere((l) => l.productId == productId);
    notifyListeners();
  }

  void setCartDiscount(int discountKobo) {
    cartDiscountKobo = discountKobo;
    notifyListeners();
  }

  /// Replaces the whole cart — used when resuming a held sale.
  void loadLines(List<CartLine> newLines, {Sale? resuming}) {
    lines
      ..clear()
      ..addAll(newLines);
    resumingSale = resuming;
    notifyListeners();
  }

  void clear() {
    lines.clear();
    cartDiscountKobo = 0;
    resumingSale = null;
    notifyListeners();
  }

  /// The VAT/discount totals for what's in the cart right now, using the
  /// exact same math (`SalesCalculator`) that actually runs at checkout —
  /// so the numbers on screen always match what gets charged.
  CartTotals get totals => SalesCalculator.computeCart(
        [
          for (final l in lines)
            CartLineInput(
              unitPriceKobo: l.unitPriceKobo,
              quantity: l.quantity,
              isVatable: l.isVatable,
              lineDiscountKobo: l.lineDiscountKobo,
            ),
        ],
        cartDiscountKobo: cartDiscountKobo,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

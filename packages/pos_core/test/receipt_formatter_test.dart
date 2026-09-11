import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

ReceiptData _sampleReceipt({bool refund = false}) => ReceiptData(
      receiptNumber: 'R000001',
      issuedAt: DateTime(2026, 1, 15, 14, 30),
      cashierName: 'Amaka Okafor',
      lines: const [
        ReceiptLine(
            name: 'Rice 5kg',
            quantity: 2,
            unitPriceKobo: 450000,
            lineTotalKobo: 967500,
            isVatable: true),
        ReceiptLine(
            name: 'Bread (VAT-exempt)',
            quantity: 1,
            unitPriceKobo: 80000,
            lineTotalKobo: 80000,
            isVatable: false),
      ],
      subtotalKobo: 980000,
      cartDiscountKobo: 0,
      vatKobo: 67500,
      totalKobo: 1047500,
      payments: const [
        ReceiptPayment(method: PaymentMethod.cash, amountKobo: 1050000),
      ],
      changeDueKobo: 2500,
      business: const BusinessProfile(tin: '12345678-0001', phone: '0800-000-0000'),
      isRefund: refund,
    );

void main() {
  group('buildThermalReceiptPdf', () {
    test('produces non-empty PDF bytes at 80mm', () async {
      final doc = buildThermalReceiptPdf(_sampleReceipt());
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(bytes.take(4), [0x25, 0x50, 0x44, 0x46]); // '%PDF'
    });

    test('produces non-empty PDF bytes at 58mm', () async {
      final doc = buildThermalReceiptPdf(_sampleReceipt(), widthMm: 58);
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });

    test('renders a refund receipt without throwing', () async {
      final doc = buildThermalReceiptPdf(_sampleReceipt(refund: true));
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });
  });

  group('buildA4InvoicePdf', () {
    test('produces non-empty PDF bytes', () async {
      final doc = buildA4InvoicePdf(_sampleReceipt());
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
      expect(bytes.take(4), [0x25, 0x50, 0x44, 0x46]);
    });
  });

  group('ReceiptData.fromSale', () {
    test('marks a refund sale correctly', () {
      final sale = Sale(
        id: 's1',
        receiptNumber: 'R000002',
        tillSessionId: 't1',
        staffId: 'staff1',
        status: SaleStatus.refunded,
        originalSaleId: 'original-sale-id',
        subtotalKobo: 100000,
        cartDiscountKobo: 0,
        vatKobo: 7500,
        totalKobo: 107500,
        createdAt: DateTime(2026, 1, 1),
      );
      final data = ReceiptData.fromSale(
        sale: sale,
        items: const [],
        payments: const [],
        cashierName: 'Test Cashier',
      );
      expect(data.isRefund, isTrue);
      expect(data.receiptNumber, 'R000002');
    });

    test('a normal completed sale is not marked as a refund', () {
      final sale = Sale(
        id: 's1',
        receiptNumber: 'R000003',
        tillSessionId: 't1',
        staffId: 'staff1',
        status: SaleStatus.completed,
        subtotalKobo: 100000,
        cartDiscountKobo: 0,
        vatKobo: 7500,
        totalKobo: 107500,
        createdAt: DateTime(2026, 1, 1),
      );
      final data = ReceiptData.fromSale(
        sale: sale,
        items: const [],
        payments: const [],
        cashierName: 'Test Cashier',
      );
      expect(data.isRefund, isFalse);
    });
  });
}

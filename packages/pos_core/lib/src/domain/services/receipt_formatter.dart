import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../database/database.dart';
import '../../database/tables/sales_tables.dart';
import '../../utils/money.dart';

class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPriceKobo,
    required this.lineTotalKobo,
    required this.isVatable,
  });

  final String name;
  final double quantity;
  final int unitPriceKobo;
  final int lineTotalKobo;
  final bool isVatable;
}

class ReceiptPayment {
  const ReceiptPayment({required this.method, required this.amountKobo});

  final PaymentMethod method;
  final int amountKobo;
}

/// Business details a receipt is printed with. Placeholder defaults until
/// Phase 6 adds a real settings screen — kept as a plain data class now so
/// nothing else has to change when that screen exists.
class BusinessProfile {
  const BusinessProfile({
    this.name = 'Jureb Supermarket',
    this.address = 'Lagos, Nigeria',
    this.tin,
    this.phone,
  });

  final String name;
  final String address;
  final String? tin;
  final String? phone;
}

/// Printer/UI-agnostic view of a sale, built once from [Sale] + [SaleItem]s
/// + [Payment]s and consumed by both the thermal-width and A4 renderers so
/// they can never disagree about what a receipt says.
class ReceiptData {
  const ReceiptData({
    required this.receiptNumber,
    required this.issuedAt,
    required this.cashierName,
    required this.lines,
    required this.subtotalKobo,
    required this.cartDiscountKobo,
    required this.vatKobo,
    required this.totalKobo,
    required this.payments,
    required this.changeDueKobo,
    required this.business,
    this.isRefund = false,
  });

  factory ReceiptData.fromSale({
    required Sale sale,
    required List<SaleItem> items,
    required List<Payment> payments,
    required String cashierName,
    BusinessProfile business = const BusinessProfile(),
    int changeDueKobo = 0,
  }) {
    return ReceiptData(
      receiptNumber: sale.receiptNumber,
      issuedAt: sale.completedAt ?? sale.createdAt,
      cashierName: cashierName,
      lines: [
        for (final item in items)
          ReceiptLine(
            name: item.productNameSnapshot,
            quantity: item.quantity,
            unitPriceKobo: item.unitPriceKobo,
            lineTotalKobo: item.lineTotalKobo,
            isVatable: item.isVatable,
          ),
      ],
      subtotalKobo: sale.subtotalKobo,
      cartDiscountKobo: sale.cartDiscountKobo,
      vatKobo: sale.vatKobo,
      totalKobo: sale.totalKobo,
      payments: [
        for (final p in payments)
          ReceiptPayment(method: p.method, amountKobo: p.amountKobo),
      ],
      changeDueKobo: changeDueKobo,
      business: business,
      isRefund: sale.status == SaleStatus.refunded && sale.originalSaleId != null,
    );
  }

  final String receiptNumber;
  final DateTime issuedAt;
  final String cashierName;
  final List<ReceiptLine> lines;
  final int subtotalKobo;
  final int cartDiscountKobo;
  final int vatKobo;
  final int totalKobo;
  final List<ReceiptPayment> payments;
  final int changeDueKobo;
  final BusinessProfile business;
  final bool isRefund;
}

String _paymentLabel(PaymentMethod method) => switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.card => 'Card',
      PaymentMethod.transfer => 'Transfer',
      PaymentMethod.other => 'Other',
    };

final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

/// Builds a thermal-format receipt as a PDF sized to [widthMm] (80 or 58),
/// so it prints correctly through a thermal printer's normal Windows
/// driver. Height is unbounded — thermal printers cut at content length,
/// not a fixed page size.
pw.Document buildThermalReceiptPdf(ReceiptData data, {double widthMm = 80}) {
  final doc = pw.Document();
  final pageFormat = PdfPageFormat(
    widthMm * PdfPageFormat.mm,
    double.infinity,
    marginAll: 4 * PdfPageFormat.mm,
  );
  final baseStyle = pw.TextStyle(fontSize: widthMm <= 58 ? 7 : 8);
  final boldStyle = baseStyle.copyWith(fontWeight: pw.FontWeight.bold);

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
              child: pw.Text(data.business.name,
                  style: boldStyle.copyWith(fontSize: baseStyle.fontSize! + 2))),
          pw.Center(child: pw.Text(data.business.address, style: baseStyle)),
          if (data.business.tin != null)
            pw.Center(
                child: pw.Text('TIN: ${data.business.tin}', style: baseStyle)),
          if (data.business.phone != null)
            pw.Center(
                child: pw.Text(data.business.phone!, style: baseStyle)),
          pw.SizedBox(height: 6),
          _dashedDivider(),
          pw.Text(data.isRefund ? 'REFUND RECEIPT' : 'SALES RECEIPT',
              style: boldStyle),
          pw.Text('No: ${data.receiptNumber}', style: baseStyle),
          pw.Text(_dateFormat.format(data.issuedAt), style: baseStyle),
          pw.Text('Served by: ${data.cashierName}', style: baseStyle),
          _dashedDivider(),
          for (final line in data.lines) ...[
            pw.Text(line.name, style: baseStyle),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    '${_qty(line.quantity)} x ${NairaFormatter.forPrint(line.unitPriceKobo)}${line.isVatable ? '' : ' *'}',
                    style: baseStyle),
                pw.Text(NairaFormatter.forPrint(line.lineTotalKobo),
                    style: baseStyle),
              ],
            ),
          ],
          _dashedDivider(),
          _totalsRow('Subtotal', data.subtotalKobo, baseStyle),
          if (data.cartDiscountKobo > 0)
            _totalsRow('Discount', -data.cartDiscountKobo, baseStyle),
          _totalsRow('VAT (7.5%)', data.vatKobo, baseStyle),
          _totalsRow('TOTAL', data.totalKobo, boldStyle),
          _dashedDivider(),
          for (final payment in data.payments)
            _totalsRow(_paymentLabel(payment.method), payment.amountKobo, baseStyle),
          if (data.changeDueKobo > 0)
            _totalsRow('Change', data.changeDueKobo, baseStyle),
          if (data.lines.any((l) => !l.isVatable))
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('* VAT-exempt item', style: baseStyle),
            ),
          pw.SizedBox(height: 8),
          pw.Center(
              child: pw.Text('Thank you for shopping with us!',
                  style: baseStyle)),
        ],
      ),
    ),
  );
  return doc;
}

/// Builds a full A4 invoice — the fallback for stores without a thermal
/// printer, and the more formal document some customers ask for.
pw.Document buildA4InvoicePdf(ReceiptData data) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(data.business.name,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text(data.business.address),
                  if (data.business.tin != null)
                    pw.Text('TIN: ${data.business.tin}'),
                  if (data.business.phone != null) pw.Text(data.business.phone!),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(data.isRefund ? 'REFUND INVOICE' : 'INVOICE',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('No: ${data.receiptNumber}'),
                  pw.Text(_dateFormat.format(data.issuedAt)),
                  pw.Text('Served by: ${data.cashierName}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey600),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
            children: [
              _invoiceHeaderRow(),
              for (final line in data.lines)
                pw.TableRow(children: [
                  _cell(line.name + (line.isVatable ? '' : ' (VAT-exempt)')),
                  _cell(_qty(line.quantity), align: pw.Alignment.centerRight),
                  _cell(NairaFormatter.forPrint(line.unitPriceKobo),
                      align: pw.Alignment.centerRight),
                  _cell(NairaFormatter.forPrint(line.lineTotalKobo),
                      align: pw.Alignment.centerRight),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _totalsRow('Subtotal', data.subtotalKobo, const pw.TextStyle()),
                  if (data.cartDiscountKobo > 0)
                    _totalsRow(
                        'Discount', -data.cartDiscountKobo, const pw.TextStyle()),
                  _totalsRow('VAT (7.5%)', data.vatKobo, const pw.TextStyle()),
                  pw.Divider(),
                  _totalsRow('TOTAL', data.totalKobo,
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Payment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (final payment in data.payments)
            pw.Text('${_paymentLabel(payment.method)}: '
                '${NairaFormatter.forPrint(payment.amountKobo)}'),
          if (data.changeDueKobo > 0)
            pw.Text('Change given: ${NairaFormatter.forPrint(data.changeDueKobo)}'),
        ],
      ),
    ),
  );
  return doc;
}

pw.TableRow _invoiceHeaderRow() => pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell('Item', bold: true),
        _cell('Qty', bold: true, align: pw.Alignment.centerRight),
        _cell('Unit price', bold: true, align: pw.Alignment.centerRight),
        _cell('Amount', bold: true, align: pw.Alignment.centerRight),
      ],
    );

pw.Widget _cell(String text, {bool bold = false, pw.Alignment? align}) => pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: align ?? pw.Alignment.centerLeft,
        child: pw.Text(text,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    );

pw.Widget _totalsRow(String label, int amountKobo, pw.TextStyle style) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(NairaFormatter.forPrint(amountKobo), style: style),
      ],
    );

pw.Widget _dashedDivider() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text('- ' * 20, style: const pw.TextStyle(fontSize: 8)),
    );

String _qty(double quantity) =>
    quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toString();

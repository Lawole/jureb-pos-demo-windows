import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../services.dart';

/// Shows a sale's receipt in three formats and lets the user send any of
/// them to whatever printer Windows has installed — thermal printers show
/// up as normal printers via their driver, so this one preview/print path
/// covers 80mm, 58mm, and the A4 fallback without touching raw ESC/POS.
class ReceiptPreviewPage extends StatefulWidget {
  const ReceiptPreviewPage({super.key, required this.saleId, this.changeDueKobo = 0});

  final String saleId;
  final int changeDueKobo;

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

enum _Format { thermal80, thermal58, a4 }

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  _Format _format = _Format.thermal80;

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<_Format>(
              segments: const [
                ButtonSegment(value: _Format.thermal80, label: Text('80mm')),
                ButtonSegment(value: _Format.thermal58, label: Text('58mm')),
                ButtonSegment(value: _Format.a4, label: Text('A4')),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.first),
            ),
          ),
        ],
      ),
      body: FutureBuilder<ReceiptData?>(
        future: _buildReceiptData(db),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return PdfPreview(
            build: (format) => switch (_format) {
              _Format.thermal80 => buildThermalReceiptPdf(data, widthMm: 80).save(),
              _Format.thermal58 => buildThermalReceiptPdf(data, widthMm: 58).save(),
              _Format.a4 => buildA4InvoicePdf(data).save(),
            },
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: true,
            allowSharing: true,
          );
        },
      ),
    );
  }

  Future<ReceiptData?> _buildReceiptData(PosDatabase db) async {
    final sale = await db.saleDao.findById(widget.saleId);
    if (sale == null) return null;
    final items = await db.saleDao.itemsFor(widget.saleId);
    final payments = await db.saleDao.paymentsFor(widget.saleId);
    final staff = await db.staffDao.findById(sale.staffId);
    return ReceiptData.fromSale(
      sale: sale,
      items: items,
      payments: payments,
      cashierName: staff?.fullName ?? 'Unknown',
      changeDueKobo: widget.changeDueKobo,
    );
  }
}

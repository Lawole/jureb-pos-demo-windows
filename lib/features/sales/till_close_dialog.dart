import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';

Future<void> showTillCloseDialog(BuildContext context, TillSession session) {
  return showDialog(
    context: context,
    builder: (_) => TillCloseDialog(session: session),
  );
}

class TillCloseDialog extends StatefulWidget {
  const TillCloseDialog({super.key, required this.session});

  final TillSession session;

  @override
  State<TillCloseDialog> createState() => _TillCloseDialogState();
}

class _TillCloseDialogState extends State<TillCloseDialog> {
  final _controller = TextEditingController();
  bool _closing = false;
  String? _error;
  TillCloseResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final naira = double.tryParse(_controller.text.trim());
    if (naira == null || naira < 0) {
      setState(() => _error = 'Enter the counted cash amount');
      return;
    }
    setState(() {
      _closing = true;
      _error = null;
    });
    try {
      final tillService = context.read<Services>().till;
      final result = await tillService.closeTill(
        tillSessionId: widget.session.id,
        countedCashKobo: (naira * 100).round(),
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      final variance = _result!.varianceKobo;
      final isShort = variance < 0;
      final isOver = variance > 0;
      return AlertDialog(
        title: const Text('Till closed'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('Opening float', widget.session.openingFloatKobo),
              _row('Expected cash', _result!.expectedCashKobo),
              _row('Counted cash', _result!.countedCashKobo),
              const Divider(),
              _row(
                isShort ? 'Short' : isOver ? 'Over' : 'Balanced',
                variance,
                color: isShort
                    ? Theme.of(context).colorScheme.error
                    : isOver
                        ? Colors.orange
                        : Colors.green,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Close till'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Count all cash in the drawer, including the opening float.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Counted cash (₦)'),
              onSubmitted: (_) => _closing ? null : _close(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _closing ? null : _close,
          child: _closing
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Close till'),
        ),
      ],
    );
  }

  Widget _row(String label, int amountKobo, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(NairaFormatter.forReceipt(amountKobo),
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

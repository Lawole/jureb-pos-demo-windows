import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';

Future<void> showTillOpenDialog(BuildContext context) {
  return showDialog(context: context, builder: (_) => const TillOpenDialog());
}

class TillOpenDialog extends StatefulWidget {
  const TillOpenDialog({super.key});

  @override
  State<TillOpenDialog> createState() => _TillOpenDialogState();
}

class _TillOpenDialogState extends State<TillOpenDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final naira = double.tryParse(_controller.text.trim());
    if (naira == null || naira < 0) {
      setState(() => _error = 'Enter a valid opening float');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tillService = context.read<Services>().till;
      final staffId = context.read<AuthController>().currentStaff!.id;
      await tillService.openTill(
        staffId: staffId,
        openingFloatKobo: (naira * 100).round(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Open till'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Count the cash currently in the drawer and enter it as the opening float.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Opening float (₦)'),
              onSubmitted: (_) => _saving ? null : _open(),
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _open,
          child: _saving
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Open till'),
        ),
      ],
    );
  }
}

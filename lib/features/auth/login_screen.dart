import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';

enum _LoginMode { pin, password }

/// The screen shown whenever nobody is logged in. Cashiers use the PIN pad
/// (fast, no keyboard needed); admins/managers can switch to username +
/// password instead.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _LoginMode _mode = _LoginMode.pin;
  String _pin = '';
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    if (_pin.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final error = await auth.loginWithPin(_pin);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
      if (error != null) _pin = '';
    });
  }

  Future<void> _submitPassword() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    final error = await auth.loginWithPassword(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.point_of_sale,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Jureb POS', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  SegmentedButton<_LoginMode>(
                    segments: const [
                      ButtonSegment(value: _LoginMode.pin, label: Text('PIN')),
                      ButtonSegment(value: _LoginMode.password, label: Text('Username')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (selection) => setState(() {
                      _mode = selection.first;
                      _error = null;
                      _pin = '';
                    }),
                  ),
                  const SizedBox(height: 24),
                  if (_mode == _LoginMode.pin)
                    _PinPad(
                      pin: _pin,
                      loading: _loading,
                      onChanged: (pin) => setState(() => _pin = pin),
                      onSubmit: _submitPin,
                    )
                  else
                    _PasswordForm(
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      loading: _loading,
                      onSubmit: _submitPassword,
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordForm extends StatelessWidget {
  const _PasswordForm({
    required this.usernameController,
    required this.passwordController,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: usernameController,
          decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
          obscureText: true,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Log in'),
          ),
        ),
      ],
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({
    required this.pin,
    required this.loading,
    required this.onChanged,
    required this.onSubmit,
  });

  final String pin;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  void _append(String digit) {
    if (pin.length < 8) onChanged(pin + digit);
  }

  void _backspace() {
    if (pin.isNotEmpty) onChanged(pin.substring(0, pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final digit = event.character;
        if (digit != null && RegExp(r'^[0-9]$').hasMatch(digit)) {
          _append(digit);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace) {
          _backspace();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter && !loading) {
          onSubmit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Wrap(
              spacing: 8,
              children: [for (var i = 0; i < pin.length; i++) const CircleAvatar(radius: 6)],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                OutlinedButton(
                  onPressed: loading ? null : () => _append(digit),
                  child: Text(digit, style: const TextStyle(fontSize: 18)),
                ),
              OutlinedButton(
                onPressed: loading ? null : _backspace,
                child: const Icon(Icons.backspace_outlined),
              ),
              OutlinedButton(
                onPressed: loading ? null : () => _append('0'),
                child: const Text('0', style: TextStyle(fontSize: 18)),
              ),
              FilledButton(
                onPressed: loading || pin.isEmpty ? null : onSubmit,
                child: const Icon(Icons.check),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

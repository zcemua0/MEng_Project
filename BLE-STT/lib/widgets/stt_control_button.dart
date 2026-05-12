// Start STT / Stop STT button widget.

import 'package:flutter/material.dart';

class SttControlButton extends StatelessWidget {
  final bool isListening;
  final bool isBusy;
  final VoidCallback? onPressed;

  const SttControlButton({
    super.key,
    required this.isListening,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = isListening ? 'Stop STT' : 'Start STT';
    final icon = isListening ? Icons.stop : Icons.mic;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(isBusy ? 'Please wait...' : label),
      ),
    );
  }
}
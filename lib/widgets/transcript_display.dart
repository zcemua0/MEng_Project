import 'package:flutter/material.dart';

class TranscriptDisplay extends StatelessWidget {
  final String text;

  const TranscriptDisplay({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = text.trim().isEmpty
        ? 'Transcribed text will appear here...'
        : text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: SingleChildScrollView(
        child: Text(
          displayText,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
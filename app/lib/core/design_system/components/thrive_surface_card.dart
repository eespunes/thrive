import 'package:flutter/material.dart';
import 'package:thrive_app/core/design_system/design_tokens.dart';

class ThriveSurfaceCard extends StatelessWidget {
  const ThriveSurfaceCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ThriveSpacing.lg),
        child: child,
      ),
    );
  }
}

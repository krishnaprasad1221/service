import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WebWrapper extends StatelessWidget {
  final Widget child;

  const WebWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A marca: um cilindro fechado com grãos dentro — o instrumento visto de
/// lado. Os mesmos grãos viram elemento de interface no [WeekPulse].
class GanzaMark extends StatelessWidget {
  const GanzaMark({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ganzá',
      child: Container(
        height: height,
        width: height * 2.4,
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: AppRadii.borderCapsule,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            5,
            (_) => Container(
              width: height * 0.14,
              height: height * 0.14,
              decoration: BoxDecoration(
                color: context.colors.onPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

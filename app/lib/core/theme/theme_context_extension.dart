import 'package:flutter/material.dart';

import 'ganza_colors.dart';

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get texts => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  GanzaColors get ganza => Theme.of(this).extension<GanzaColors>()!;
}

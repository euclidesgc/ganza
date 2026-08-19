import 'package:flutter/widgets.dart';

abstract final class AppIcons {
  /// Cada glifo precisa ser `const IconData` para o Flutter fazer o
  /// subsetting da fonte no build de release (`--tree-shake-icons`).
  static const errorState = IconData(0xECA1, fontFamily: 'RemixIcon');
  static const transactions = IconData(0xF457, fontFamily: 'RemixIcon');
  static const signOut = IconData(0xEEDA, fontFamily: 'RemixIcon');
  static const dateField = IconData(0xEB25, fontFamily: 'RemixIcon');
  static const addAction = IconData(0xEA13, fontFamily: 'RemixIcon');
}

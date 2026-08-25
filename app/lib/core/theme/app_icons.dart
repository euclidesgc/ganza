import 'package:flutter/material.dart';

abstract final class AppIcons {
  /// Cada glifo precisa ser `const IconData` para o Flutter fazer o
  /// subsetting da fonte no build de release (`--tree-shake-icons`).
  static const errorState = IconData(0xECA1, fontFamily: 'RemixIcon');
  static const transactions = IconData(0xF457, fontFamily: 'RemixIcon');
  static const signOut = IconData(0xEEDA, fontFamily: 'RemixIcon');
  static const dateField = IconData(0xEB25, fontFamily: 'RemixIcon');
  static const addAction = IconData(0xEA13, fontFamily: 'RemixIcon');
  static const home = IconData(0xEE2B, fontFamily: 'RemixIcon');
  static const menu = IconData(0xEF3E, fontFamily: 'RemixIcon');
  static const settings = IconData(0xF0E6, fontFamily: 'RemixIcon');
  static const account = IconData(0xEA09, fontFamily: 'RemixIcon');
  static const aiFeature = IconData(0xF36B, fontFamily: 'RemixIcon');
  static const bank = IconData(0xEA94, fontFamily: 'RemixIcon');
  static const chat = IconData(0xEB51, fontFamily: 'RemixIcon');
  static const apiKey = IconData(0xEE6F, fontFamily: 'RemixIcon');
  static const revealSecret = IconData(0xECB5, fontFamily: 'RemixIcon');
  static const hideSecret = IconData(0xECB7, fontFamily: 'RemixIcon');
  static const connectedStatus = IconData(0xEB80, fontFamily: 'RemixIcon');
  static const notConfiguredStatus = IconData(0xEA21, fontFamily: 'RemixIcon');
  static const advance = IconData(0xEA6E, fontFamily: 'RemixIcon');
  static const microphone = Icons.mic_outlined;
  static const stopRecording = Icons.stop_circle_outlined;
}

import 'package:flutter/widgets.dart';

abstract final class AppRadii {
  static const sm = Radius.circular(6);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(20);

  /// A cápsula é a forma da marca — o cilindro do instrumento visto de lado.
  static const capsule = Radius.circular(999);

  static const borderSm = BorderRadius.all(sm);
  static const borderMd = BorderRadius.all(md);
  static const borderLg = BorderRadius.all(lg);
  static const borderCapsule = BorderRadius.all(capsule);
}

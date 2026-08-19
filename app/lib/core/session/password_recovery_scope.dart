import 'package:flutter/foundation.dart';

class PasswordRecoveryScope extends ChangeNotifier {
  bool _isActive = false;

  bool get isActive => _isActive;

  // GoTrue entrega uma sessão válida tanto no login normal quanto no evento
  // passwordRecovery/verifyOTP de recuperação; sem este sinalizador externo
  // a guarda de rota não teria como distinguir os dois casos.
  void begin() {
    if (_isActive) return;
    _isActive = true;
    notifyListeners();
  }

  void end() {
    if (!_isActive) return;
    _isActive = false;
    notifyListeners();
  }
}

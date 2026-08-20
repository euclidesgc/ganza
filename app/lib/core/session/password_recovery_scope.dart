import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class PasswordRecoveryScope extends ChangeNotifier {
  bool _isActive = false;

  bool get isActive => _isActive;

  // GoTrue entrega uma sessão válida tanto no login normal quanto no evento
  // passwordRecovery/verifyOTP de recuperação; sem este sinalizador externo
  // a guarda de rota não teria como distinguir os dois casos.
  void begin() {
    if (_isActive) return;
    _isActive = true;
    _notify();
  }

  void end() {
    if (!_isActive) return;
    _isActive = false;
    _notify();
  }

  // begin() nasce dentro do construtor do PasswordRecoveryCodeCubit, e o
  // BlocProvider.create é lazy: ele só roda no primeiro context.read, que
  // acontece durante o build da própria árvore de rotas. notifyListeners
  // síncrono ali reentra no GoRouter (que escuta este escopo via
  // refreshListenable) enquanto ele ainda está no meio do seu build,
  // disparando "setState() or markNeedsBuild() called during build". Por
  // isso _isActive já muda de forma síncrona — o redirect que rodar neste
  // mesmo frame já lê o valor novo — e só o notifyListeners é adiado para
  // depois do frame corrente quando chamado em fase de build/layout/paint.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}

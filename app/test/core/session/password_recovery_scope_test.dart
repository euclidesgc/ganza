import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganza/core/session/password_recovery_scope.dart';

void main() {
  group('PasswordRecoveryScope', () {
    testWidgets('begin() chamado durante o build não notifica um listener que '
        'reconstrói uma árvore ainda em build', (tester) async {
      final scope = PasswordRecoveryScope();

      await tester.pumpWidget(
        MaterialApp(
          home: _RouterLikeListener(
            scope: scope,
            child: Builder(
              builder: (context) {
                scope.begin();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(scope.isActive, isTrue);

      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('end() chamado durante o build também adia a notificação', (
      tester,
    ) async {
      final scope = PasswordRecoveryScope()..begin();

      await tester.pumpWidget(
        MaterialApp(
          home: _RouterLikeListener(
            scope: scope,
            child: Builder(
              builder: (context) {
                scope.end();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(scope.isActive, isFalse);

      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    test('begin() e end() fora da fase de build notificam de imediato', () {
      final scope = PasswordRecoveryScope();
      var notifications = 0;
      scope.addListener(() => notifications++);

      scope.begin();
      expect(notifications, 1);
      expect(scope.isActive, isTrue);

      scope.end();
      expect(notifications, 2);
      expect(scope.isActive, isFalse);
    });

    test('begin() e end() são idempotentes', () {
      final scope = PasswordRecoveryScope();
      var notifications = 0;
      scope.addListener(() => notifications++);

      scope.begin();
      scope.begin();
      expect(notifications, 1);

      scope.end();
      scope.end();
      expect(notifications, 2);
    });
  });
}

/// Reproduz, sem depender do go_router, o formato do bug real: um widget
/// que escuta o [PasswordRecoveryScope] (como o `Router` do go_router
/// escuta o `refreshListenable`) e reconstrói via `setState` quando
/// notificado. Se o [child] chamar `scope.begin()`/`scope.end()` durante o
/// próprio build — como o `BlocProvider.create` lazy do
/// `PasswordRecoveryCodeCubit` faz — e a notificação for síncrona, o
/// `setState` deste widget reentra na build scope ainda travada pelo
/// framework, reproduzindo "setState() or markNeedsBuild() called during
/// build".
class _RouterLikeListener extends StatefulWidget {
  const _RouterLikeListener({required this.scope, required this.child});

  final PasswordRecoveryScope scope;
  final Widget child;

  @override
  State<_RouterLikeListener> createState() => _RouterLikeListenerState();
}

class _RouterLikeListenerState extends State<_RouterLikeListener> {
  @override
  void initState() {
    super.initState();
    widget.scope.addListener(_handleScopeChanged);
  }

  void _handleScopeChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.scope.removeListener(_handleScopeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

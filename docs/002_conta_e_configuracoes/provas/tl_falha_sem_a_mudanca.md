# Provas de falha-sem-a-mudança — Lote de fechamento da 002

Cada mutação abaixo foi aplicada ao código de produção, o teste rodou vermelho
e a árvore foi restaurada.

## TL.1 — a ordem do abandono da recuperação importa

Mutação: em `password_recovery_code_cubit.dart`, inverter
`signOutWithoutChangingPassword` para desligar o escopo **antes** de encerrar a
sessão.

Saída vermelha (`flutter test .../sign_out_without_changing_password_link_test.dart`):

```
Expected: true
  Actual: <false>
```

A sessão só pode cair com o escopo ainda ligado — a ordem é a substância da
prova.

## TL.2 — o item de transações empilha, não substitui

Mutação: em `app_shell.dart`, trocar `TransactionsRoutes.pushNamed` por
`context.goNamed` (substitui a rota em vez de empilhar).

Saída vermelha (`flutter test test/app_router_test.dart --plain-name 'drawer chega a transações...'`):

```
Test failed. See exception logs above.
```

O `router.pop()` depois de `goNamed` não devolve à lista de áreas — a pilha se
perdeu.

## TL.3 — a guarda não reage ao evento de entrada

Mutação: em `app_router.dart`, acrescentar `AuthRoutes.changePasswordPath` ao
conjunto `publicPaths`, fazendo a guarda mandar para a raiz quando a sessão
emite o evento de entrada.

Saída vermelha (`flutter test test/app_router_test.dart --plain-name 'trocar a senha logado...'`):

```
Test failed. See exception logs above.
```

A troca de senha logado não pode deslogar nem navegar — o evento de `signedIn`
que a confirmação da senha atual provoca não muda a rota.

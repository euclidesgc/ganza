# Round 02 - E2E local da feature 002

## Contexto

Stack local descartável em `http://127.0.0.1:54321`; commit `6b5c64e`.

Resultado: **VERDE** — 4 cenas, nenhuma falha.

O ciclo completo de conta, ponta a ponta pela tela: criar conta, tentar entrar
sem confirmar, confirmar pelo link que chegou na caixa local, entrar, recuperar
a senha e sair. **Nenhum passo avançou por SQL, Studio, chave `service_role` ou
endpoint `/admin`** — a lista ordenada dos comandos que substituem esse atalho
está em "Ambiente e comandos".

A tentativa anterior desta mesma rodada parou na cena `recuperar_senha` com
`setState() or markNeedsBuild() called during build` vindo do `Router`,
consertado em `c278c9f`. O log desta rodada não traz mais a frase:
`grep -c 'markNeedsBuild' docs/002_conta_e_configuracoes/e2e/round_02/logs/execucao.txt`
imprime `0`. Ele é versionado com extensão `.txt` porque `*.log` está no
`.gitignore` e a prova precisa chegar ao PR — mesmo caminho que a round_01
usou para `logs/gotrue_requisicoes.txt`.

## Passos executados

| Cena | Resultado | Evidência |
| --- | --- | --- |
| criar_conta | PASS | [10_conta_criada_confirme_email.png](10_conta_criada_confirme_email.png) |
| entrar_sem_confirmar | PASS | [11_entrar_sem_confirmar.png](11_entrar_sem_confirmar.png) |
| confirmar_e_entrar | PASS | [12_dentro_do_app_com_a_conta_nova.png](12_dentro_do_app_com_a_conta_nova.png) [13_email_lembrado_apos_sair.png](13_email_lembrado_apos_sair.png) |
| recuperar_senha | PASS | [14_codigo_errado_recusado.png](14_codigo_errado_recusado.png) [15_nova_senha_apos_codigo_certo.png](15_nova_senha_apos_codigo_certo.png) [16_senha_nova_fraca_recusada.png](16_senha_nova_fraca_recusada.png) [17_dentro_do_app_apos_trocar_a_senha.png](17_dentro_do_app_apos_trocar_a_senha.png) [18_senha_antiga_recusada.png](18_senha_antiga_recusada.png) [19_entrar_com_a_senha_nova.png](19_entrar_com_a_senha_nova.png) |

Contagem por cena, como o `patrol test` a imprimiu (uma invocação por cena,
`logs/cena_<nome>.log`, não versionado):

```
🧪 conta_e_recuperacao_test cena criar_conta
📝 Total: 1   ✅ Successful: 1   ❌ Failed: 0   ⏩ Skipped: 0   ⏱️ 1m 18s
🧪 conta_e_recuperacao_test cena entrar_sem_confirmar
📝 Total: 1   ✅ Successful: 1   ❌ Failed: 0   ⏩ Skipped: 0   ⏱️ 1m 9s
🧪 conta_e_recuperacao_test cena confirmar_e_entrar
📝 Total: 1   ✅ Successful: 1   ❌ Failed: 0   ⏩ Skipped: 0   ⏱️ 1m 14s
🧪 conta_e_recuperacao_test cena recuperar_senha
📝 Total: 1   ✅ Successful: 1   ❌ Failed: 0   ⏩ Skipped: 0   ⏱️ 1m 49s
```

A conta desta execução foi **confirmada pelo token que chegou na mensagem
capturada** e entrou no app pela tela de entrar:
[12_dentro_do_app_com_a_conta_nova.png](12_dentro_do_app_com_a_conta_nova.png)
é a tela de dentro do app com ela. Antes disso,
[11_entrar_sem_confirmar.png](11_entrar_sem_confirmar.png) mostra a mesma conta
já existente sendo recusada por falta de confirmação.

Os **dois modos de falha do fluxo de recuperação** ficaram em estados
visualmente distintos, cada um com a sua ação corretiva legível:

| Modo de falha | Print | O que a tela mostra |
| --- | --- | --- |
| Código recusado | [14_codigo_errado_recusado.png](14_codigo_errado_recusado.png) | "Código inválido ou vencido. Confira e digite de novo, ou volte para pedir um novo código." — a etapa do código continua montada, com o que foi digitado preservado no campo |
| Senha nova fraca | [16_senha_nova_fraca_recusada.png](16_senha_nova_fraca_recusada.png) | "A senha precisa ter pelo menos 6 caracteres." — a etapa da nova senha continua montada, com os dois campos preservados |

Nenhum dos dois exibe a mensagem genérica de erro inesperado nem "Sua sessão
expirou. Entre de novo.". O print sozinho registraria sem cobrar: a cena
`recuperar_senha` de `app/patrol_test/conta_e_recuperacao_test.dart` assere as
duas mensagens **por extenso** antes de capturar, e assere `isNot` da mensagem
de sessão expirada — mudar qualquer um dos textos quebra a cena.

As mensagens que o capturador local recebeu para o endereço desta
execução, sem token e sem código:
[`mensagens_capturadas.json`](mensagens_capturadas.json).

## Ambiente e comandos

- Stack local descartável: `http://127.0.0.1:54321`
- `scripts/e2e-emulator.sh start|cleanup` controla exclusivamente o AVD desta rodada.
- `scripts/local-supabase.sh reset`
- `scripts/e2e-002-auth.sh`

Comando único desta rodada, do qual todo o resto decorre:

```
bash scripts/e2e-local.sh 002 > docs/002_conta_e_configuracoes/e2e/round_02/logs/execucao.txt 2>&1
```

Em ordem, o que ele executou no lugar de qualquer atalho por banco:

1. `scripts/local-supabase.sh reset` — stack descartável do zero.
2. `scripts/capture-e2e-evidence.py --port 8765 --serial emulator-5554` — os
   prints são tirados pela máquina, por `adb reverse`, no ponto da asserção.
3. `scripts/e2e-emulator.sh start Pixel_8_Pro emulator-5554` e `harden` — AVD
   exclusivo da rodada, sem diálogo de sistema por cima dos prints.
4. `curl -X POST $SUPABASE_URL/auth/v1/token?grant_type=password` com o endereço
   sorteado — devolve `400`, provando que o endereço estava livre antes.
5. `patrol test --target=patrol_test/conta_e_recuperacao_test.dart --dart-define=E2E_CENA=criar_conta`
   — cadastro pela tela de cadastro.
6. `… --dart-define=E2E_CENA=entrar_sem_confirmar` — a conta existe e mesmo
   assim não entra.
7. `… --dart-define=E2E_CENA=confirmar_e_entrar` — a própria cena lê a mensagem
   pela API do capturador local e faz `GET $SUPABASE_URL/auth/v1/verify?token=<o
   que chegou na mensagem>&type=signup`, que é a rota pública do link do e-mail;
   assere `303` sem `error_code` e só então entra pela tela de entrar.
8. `… --dart-define=E2E_CENA=recuperar_senha` — código errado, senha fraca,
   código certo, senha trocada, senha antiga recusada, senha nova aceita.
9. `curl -X POST $SUPABASE_URL/auth/v1/token?grant_type=password` duas vezes, ao
   fim: a senha do cadastro devolve `400` e a definida na recuperação devolve
   `200`.

**Nenhum `psql`, nenhum Studio, nenhuma chave `service_role`, nenhum endpoint
`/admin`.** O roteiro não tem como usá-los:
`grep -rniE 'service_role|/admin|psql|update auth\.users' app/patrol_test/conta_e_recuperacao_test.dart`
não devolve nenhuma linha, e ele recusa alvo que não seja a stack local antes de
tocar em qualquer conta.

Logs e ressalvas ficam em `logs/` (não versionado). Não são gravados vídeos.

## Rastro

O que esta rodada criou e onde:

- **Conta no GoTrue local**, endereço sorteado na execução
  (`e2e-<12 letras>@ganza.local`) — vive só no Postgres da stack descartável.
- **Duas mensagens no capturador local** (confirmação e recuperação), resumidas
  sem token e sem código em [`mensagens_capturadas.json`](mensagens_capturadas.json).
- **AVD `Pixel_8_Pro` headless** e o app `br.com.ganza.ganza` instalado nele.
- **`adb reverse tcp:8765`** ligando o emulador ao servidor de captura.
- **PNGs `10_` a `19_`** neste diretório, e a saída completa da execução em
  [`logs/execucao.txt`](logs/execucao.txt); a saída crua por cena fica em
  `logs/cena_<nome>.log`, que o `.gitignore` deixa de fora.

Nada saiu da máquina local: HML e produção não são alvo deste roteiro, que falha
com mensagem explícita se `SUPABASE_URL` ou a URL do capturador não forem de
host local.

## Limpeza no wrap

- O `trap … EXIT` de `scripts/e2e-local.sh` já rodou `scripts/e2e-emulator.sh
  cleanup` e `scripts/local-supabase.sh down` ao fim desta rodada: o emulador
  foi derrubado, o `adb reverse` removido e a stack — com a conta, as mensagens
  e o banco inteiro — deixou de existir. `scripts/local-supabase.sh status`
  confirma a stack fora do ar.
- **Sai no wrap do E2E da feature**, quando a evidência já estiver atestada:
  `app/patrol_test/` inteiro, a `dev_dependency` `patrol` do
  `app/pubspec.yaml`, `scripts/e2e-002-auth.sh` e
  `scripts/capture-e2e-evidence.py`. Nada disso é compilado no binário de
  produção — tudo vive fora de `app/lib/`.
- **Fica:** este `report.md`, os PNGs e `logs/execucao.txt`, que são a prova.
  Os `logs/cena_<nome>.log` não são versionados (`*.log` no `.gitignore`) e
  morrem com a árvore de trabalho.

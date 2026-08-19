# Round 02 — tentativa 03 — FAIL (execução interrompida)

Rodada **descartada**, preservada como prova do modo de falha. Não pode ser
usada como evidência de DoD: das dez cenas, seis não chegaram a rodar.

Só este relatório é versionado: PNGs, snapshots e logs da tentativa foram
descartados por serem ~4 MB de prova de um harness que já mudou. Os nomes de
arquivo citados descrevem o que foi observado na época.

## Resultado

Executor `scripts/e2e-local.sh 001` em 18/08/2026, 22:26 → 22:40. Já rodava
com o orçamento corrigido de 600 s por cena: o `e2e_shots.sh.snapshot` da
tentativa mostrava `timeout --kill-after=60s 600`.

| Cena | Resultado | Evidência |
| --- | --- | --- |
| erro de leitura | PASS | `01_erro_de_leitura.png` |
| estado vazio | PASS | `02_estado_vazio.png` |
| lista carregada | PASS | `03_lista_carregada.png` |
| algarismos tabulares | PASS | `04_algarismos_tabulares.png` |
| abandono | PASS | `06_formulario_abandonado.png` · count 2 → 2 |
| **feliz** | **INTERROMPIDA** | `logs/cena_feliz.log` |
| banco · duplo · sem_rede · sessão expirada | não executadas | — |

## Diagnóstico — execução interrompida, não travamento

`logs/cena_feliz.log` termina em `• Executing tests of apk … on emulator-5554`
às 22:39, cerca de um minuto depois do fim do build. `logs/emulador.log`
registra o desligamento às 22:40, pelo `trap cleanup` do executor.

Não é estouro de orçamento: com 600 s, a cena teria até ~22:49 e o log
registraria a saída 124, como na
[tentativa 02](../round_02_falha_02/report.md). Um minuto de execução seguido
de cleanup é assinatura de sinal recebido pelo processo.

Não existe `logs/executor.log` nesta pasta, ao contrário da tentativa 02: o
executor rodou em primeiro plano, preso à sessão que o disparou, e morreu com
ela.

**Classificação: processo de execução.** O produto não foi tocado nesta
tentativa, e as cinco cenas que rodaram passaram.

## Correção aplicada

O executor passa a ser disparado desacoplado da sessão, com deadline e relato
de progresso — regra escrita em `.claude/agents/qa.md` e no sentinela de
término via `trap … EXIT` da skill `instrumentar-e2e` (commit `a2f4fa4`).

Investigação posterior encontrou a causa ambiental de fundo, comum a esta
tentativa e à anterior: dois `dart language-server` pendurados ocupavam
23,5 GiB dos 31 GiB da máquina, com 1,6 GiB disponíveis e 18 GiB de swap em
uso. A rodada seguinte parte de 25 GiB livres.

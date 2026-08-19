# Round 02 — tentativa 01 — FAIL (ambiente)

Rodada **descartada**. Preservada porque é a prova do modo de falha, não lixo.
Não pode ser usada como evidência de DoD.

Só este relatório é versionado: PNGs, snapshots e logs da tentativa foram
descartados por serem ~4 MB de prova de um harness que já mudou. Os nomes de
arquivo citados descrevem o que foi observado na época.

## Resultado

Executor `scripts/e2e-local.sh 001`, commit `d76681c`, stack local
`http://127.0.0.1:54321`. As 8 cenas Patrol saíram verdes
(`Successful: 1 / Failed: 0` em cada `logs/cena_*.log`) e o script terminou
`exit 0` — mas **os 10 PNGs são inservíveis**.

| Cena | Patrol | Print utilizável | Motivo |
| --- | --- | --- | --- |
| erro | PASS | **FAIL** | ANR por cima |
| vazio | PASS | **FAIL** | ANR por cima |
| lista | PASS | **FAIL** | ANR por cima |
| algarismos tabulares | n/a | **FAIL** | recorte tirado do print contaminado |
| abandono | PASS | **FAIL** | ANR por cima |
| feliz | PASS | **PARCIAL** | linha nova legível no topo; resto sob o scrim |
| duplo | PASS | **FAIL** | o botão `Registrar` fica **inteiramente** atrás do diálogo — a linha do DoD não é atestável |
| sem_rede | PASS | **FAIL** | a mensagem curta de erro fica atrás do diálogo |
| sessao_expirada | PASS | **FAIL** | a área onde uma mensagem residual apareceria fica atrás do diálogo |

## Modo de falha

Em **todos** os 10 prints o Android desenhou o diálogo de sistema
**"System UI isn't responding" / Close app / Wait**, centralizado, com scrim
escurecendo a tela inteira. O diálogo tapa exatamente a faixa que o DoD da
Fase 4 manda o dev humano atestar.

Causa: sob `emulator -no-window -gpu swiftshader_indirect` (renderização por
software), o `com.android.systemui` da API 35 estoura ANR nesta máquina. O
diálogo é do **SystemUI**, não do app — `com.ganza.dev` respondeu a todos os
toques do Patrol, preencheu o formulário, gravou a linha e recarregou a lista.

**Classificação: ambiente.** Não é defeito de produto.

## Correção aplicada

`scripts/e2e-emulator.sh` ganhou o subcomando `harden`, chamado pelos dois
roteiros logo após `sys.boot_completed`:

    adb -s "$SERIAL" shell settings put global hide_error_dialogs 1
    adb -s "$SERIAL" shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS

## Ressalva sobre o `report.md` original

O `report.md` que `scripts/e2e-local.sh` gerou para esta rodada trazia **PASS
em todas as oito linhas**, porque o gerador escreve a tabela com literais
fixos (`scripts/e2e-local.sh:67-74`) em vez de derivá-la do resultado das
cenas. Uma rodada com todos os prints inservíveis foi rotulada verde. Este
arquivo substitui aquele.

A evidência bruta do executor ficou em `logs/executor.log`, descartado junto
com o resto dos artefatos desta tentativa.

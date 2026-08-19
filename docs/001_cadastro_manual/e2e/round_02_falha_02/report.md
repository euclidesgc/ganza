# Round 02 — tentativa 02 — FAIL (ambiente)

Rodada **descartada**, preservada como prova do modo de falha. Não pode ser
usada como evidência de DoD: falta a cena `sessao_expirada` e o
`04_sessao_expirada_login.png`.

Só este relatório é versionado: PNGs, snapshots e logs da tentativa foram
descartados por serem ~4 MB de prova de um harness que já mudou. Os nomes de
arquivo citados descrevem o que foi observado na época.

## Resultado

Executor `scripts/e2e-local.sh 001` com o emulador já endurecido contra ANR.
Os prints saíram **limpos** — o diálogo do SystemUI não apareceu em nenhum.
9 de 10 prints gerados; 7 das 8 cenas verdes.

| Cena | Resultado | Evidência |
| --- | --- | --- |
| erro de leitura | PASS | `01_erro_de_leitura.png` |
| estado vazio | PASS | `02_estado_vazio.png` |
| lista carregada | PASS | `03_lista_carregada.png` |
| algarismos tabulares | PASS | `04_algarismos_tabulares.png` |
| abandono | PASS | `06_formulario_abandonado.png` · count 2 → 2 |
| feliz | PASS | `01_formulario_preenchido.png` + `02_lista_com_a_linha_nova.png` · count 2 → 3 |
| banco (decisão A1) | PASS | `linha_registrada.json` — `amount=4500`, `source=manual`, `direction=out`, `area_id=null` |
| duplo | PASS | `05_botao_desabilitado_durante_envio.png` · count 3 → 4 (dois toques, uma linha) |
| sem_rede | PASS | `03_sem_rede_campos_preservados.png` · count 4 → 4 |
| **sessao_expirada** | **FAIL** | saída **124** — `logs/cena_sessao_expirada.log` |

Como o roteiro terminou `exit 1`, `scripts/e2e-local.sh` abortou antes de
gerar o `report.md` automático. Este arquivo foi escrito à mão.

## Diagnóstico da cena que falhou — ambiente, não produto

Saída 124 é o `timeout --kill-after=30s 300` matando o `patrol test`, não o
app travando. O que sustenta a classificação:

1. **A mesma cena, no mesmo binário, passou na tentativa 01**: build 52,6 s +
   execução 1 m 34 s ≈ 147 s, com folga sobre os 300 s. Um travamento do
   caminho "token vencido → renovação recusada" teria travado ali também.
2. **A tentativa 02 inteira ficou mais lenta**, não só essa cena: `abandono`
   subiu de 2 m 0 s para 2 m 11 s e `sem_rede` de 1 m 41 s para 2 m 4 s.
   Degradação global da máquina, não um caminho de código específico.
3. **O build dessa cena estourou para 100,8 s** (as outras sete ficaram entre
   52 s e 62 s), sobrando menos de 200 s do orçamento para uma execução que
   precisa de 95 s a 131 s. O log para em
   `• Executing tests of apk … on emulator-5554` — morreu no orçamento.
4. Memória disponível na máquina oscilou até ~3,7 GiB de 31 GiB durante a
   janela, com build Gradle e emulador concorrendo.

**Classificação: ambiente / orçamento do harness.** Nenhuma correção de
produto foi feita — o produto não foi tocado nesta investigação.

## Correção aplicada

Orçamento por cena de 300 s → 600 s, em `docs/001_cadastro_manual/e2e_shots.sh:184`
e `docs/001_cadastro_manual/e2e_registro_shots.sh:284`:

    timeout --kill-after=60s 600 patrol test …

A evidência bruta do executor ficou em `logs/executor.log`, descartado junto
com o resto dos artefatos desta tentativa.

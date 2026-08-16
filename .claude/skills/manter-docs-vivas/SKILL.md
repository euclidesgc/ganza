---
name: manter-docs-vivas
description: Fecha a documentação viva de uma feature do ganza (final_report, roadmap, README, CHANGELOG, ANALYTICS, ERROR_LOGS). Usada pelo QA no fechamento (DoD).
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Skill: manter as docs vivas

Objetivo: nada fica "na cabeça". A memória do que foi feito mora em arquivos versionados. Sem docs em dia, a DoD não fecha.

Na pasta da feature (`docs/NN-<nome>/`):

1. **final_report.md** — o relatório de entrega: roteiro cumprido, resultado de cada caso, links para os prints em `evidencias/`. Responde "isso foi testado mesmo?".
2. **specs.md / prd.md / plan.md** — conferir que dizem a verdade sobre o que existe. Desvio aprovado já deve estar refletido + registrado no **variance_report.md** (como estava, por que mudou, o que mudou). Documento que mente é pior que nenhum.

Na raiz:

3. **docs/roadmap.md** — marque o item entregue `[x]` e o próximo `[-]`. Reordene se a entrega mudou a precedência, e **reescreva o texto do item** se ele ficou confuso. Decisão pendente do humano vira linha no roadmap, junto do item que a espera — nunca fica só no prompt de retomada.
4. **README.md** — como rodar, o que existe. Comando novo (emulador, migration, seed) entra aqui.
5. **CHANGELOG.md** — uma entrada objetiva na seção `Unreleased` (Keep a Changelog).
6. **ANALYTICS.md** — por módulo: cada evento enviado, quando dispara, o que carrega. Se a feature não tem evento, registre "nenhum evento" **explicitamente** — não omita.
7. **ERROR_LOGS.md** — por módulo: cada erro monitorado, quem dispara, em que situação (as `Failure` tipadas e o que o `AppBlocObserver` reporta).

Se a feature mudou o schema, confira também que **`docs/plano.md` §7 (modelo de dados) não ficou mentindo** — ele é o mapa que orienta quem chega depois.

Regra: escreva para o leitor de daqui a seis meses. Linguagem natural + técnica, pt-BR, curto e verificável.

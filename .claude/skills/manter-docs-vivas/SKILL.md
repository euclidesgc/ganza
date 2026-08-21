---
name: manter-docs-vivas
description: Fecha a documentação viva de uma feature do ganza (final_report, roadmap, README, CHANGELOG, ANALYTICS, ERROR_LOGS). Usada pelo QA no fechamento (DoD), decomposta em duas frentes — a pasta da feature e a raiz —, cada uma com o seu bloco DoD.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Skill: manter as docs vivas

Objetivo: nada fica "na cabeça". A memória do que foi feito mora em arquivos versionados. Sem docs em dia, a DoD não fecha.

Na pasta da feature (`docs/NNN_<nome>/`):

1. **final_report.md** — crie-o no fechamento da feature: roteiro cumprido, resultado de cada caso, referência à bateria automatizada (unit + widget) que prova cada um. Responde "isso foi testado mesmo?".
2. **`decisions.md` / `changes.md`** — decisão local fica no primeiro; desvio
   pós-início fica no segundo, com planejamento original, impedimento,
   alternativas, decisão, resumo e lista da reconciliação.
3. **01_prd.md / 02_specs.md / 03_plan.md** — conferir que dizem a verdade
   sobre o que existe, já reconciliados depois de cada mudança registrada.
   Documento que mente é pior que nenhum.

Na raiz:

4. **docs/roadmap.md** — marque o item entregue `[x]` e o próximo `[-]`. O roadmap fica curto; decisão transversal ou pendência humana vai para `docs/decisions.md`, nunca para a lista de features.
5. **README.md** — como rodar, o que existe. Comando novo (emulador, migration, seed) entra aqui.
6. **CHANGELOG.md** — uma entrada objetiva na seção `Unreleased` (Keep a Changelog).
7. **ANALYTICS.md** — ainda não existe; a primeira feature que fechar o cria. Por módulo: cada evento enviado, quando dispara, o que carrega. Se a feature não tem evento, registre "nenhum evento" **explicitamente** — não omita.
8. **ERROR_LOGS.md** — ainda não existe; a primeira feature que fechar o cria. Por módulo: cada erro monitorado, quem dispara, em que situação (as `Failure` tipadas e o que o `AppBlocObserver` reporta).

**Os alvos da pasta da feature (1–3) e os da raiz (4–8) são frentes disjuntas** e vão em paralelo — um agente cada, com worktree próprio porque escrevem ao mesmo tempo. Cada frente é uma tarefa com bloco DoD próprio, julgada ao fim pelo `supervisor-dod` (`.claude/agents/supervisor-dod.md`).

Se a feature mudou o schema, confira também que **`docs/plano.md` §7 (modelo de dados) não ficou mentindo** — ele é o mapa que orienta quem chega depois. É o caso mais visível de uma armadilha maior:

**Registrar a mudança não basta — uma correção torna falso o texto vizinho.** O parágrafo que descrevia o comportamento antigo, a contagem que não bate mais, o caminho que mudou de nome: nada disso se corrige sozinho. Depois de editar, releia o que **ficou** no documento e confirme que nenhuma frase virou mentira. Duas entradas do mesmo `CHANGELOG.md` que se contradizem são defeito, não detalhe de redação — uma delas está errada e quem lê não tem como saber qual; resolva no mesmo PR.

**Comando escrito em documentação exige execução, não leitura.** Todo comando que o `README.md` traz tem de rodar copiado e colado, exatamente como está — rode cada um antes de fechar. Comando que só parece certo é o defeito mais barato de introduzir e o mais caro de descobrir.

Regra: escreva para o leitor de daqui a seis meses. Linguagem natural + técnica, pt-BR, curto e verificável.

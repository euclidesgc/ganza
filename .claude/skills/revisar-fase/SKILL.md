---
name: revisar-fase
description: Valida uma fase implementada contra o 03_plan.md e as regras do ganza. Usada pelo QA ao fim de cada fase, antes do resumo de PR ao dev.
allowed-tools: Read, Glob, Grep, Bash, mcp__code-review-graph__detect_changes_tool, mcp__code-review-graph__get_review_context_tool, mcp__dart__analyze_files, mcp__dart__run_tests
---

# Skill: revisar uma fase

Objetivo: dado o diff da fase, conferir item a item se o que foi feito bate com o que estava planejado — o caminho inverso da `criar-modulo`.

Confira, nesta ordem:

1. **DoD da etapa — antes de tudo.** Cada linha foi **executada** e a saída bate com o esperado? Teste automatizado no DoD foi visto **falhar sem a mudança**? Linha que envolve serviço no ar foi verificada **contra o domínio**, não contra `localhost`? Linha não verificada = etapa não fechada. A skill `fechar-etapa` conduz isso.

2. **Plano.** Cada tarefa da fase no `docs/NNN_<nome>/03_plan.md` foi feita?
   Algo foi feito que **não** estava no plano? É `fail` até haver registro
   prévio em `changes.md` com planejamento original, impedimento, alternativas,
   decisão, resumo e reconciliação de PRD/specs/plano. Não aceite justificativa
   verbal nem reescrita silenciosa dos documentos.

3. **Invariantes de produto** (`CLAUDE.md` — estas se **provam**, não se declaram):
   - Nenhum caminho grava registro sem `confirmed`. Procure ativamente pelo atalho: um `insert` direto no fluxo de ingestão, um "só para teste", um flag. A extração devolve **lista**; o card **não** é editável.
   - Cálculo financeiro é código determinístico com teste, não resposta de modelo.
   - Nenhuma chave de terceiro alcançável pelo app (dart-define, asset, resposta de endpoint, log).
   - Toda tabela nova tem RLS **e** política; a migration aplica limpo num banco vazio e veio em PR próprio.
   - Storage por URL assinada, nunca bucket público.

4. **Fronteiras.** presentation não importa data; nenhuma lógica chama o get_it por dentro (só `pageBuilder`); nenhum módulo importa o interno de outro (só barrel público); domain sem `package:flutter` e sem `fromMap`; o app não fala com API externa.

5. **Convenções.** Estado sealed + switch exaustivo; `Either<Failure, T>` nos contratos; um use case por operação; entidade imutável; barrel público só com rota + DI; zero build_runner; `isClosed` após await; dinheiro em centavos inteiros; timestamp em UTC até a borda.

6. **Design system e widgets** (se a fase tem UI): (a) **Gate 1 — nenhuma função/método retorna `Widget`** (permitidos: `build`, `pageBuilder`, callbacks `itemBuilder`/`builder:` sem árvore inline extensa); (b) **Gate 3 — uma classe/widget por arquivo** (podem coabitar: par `StatefulWidget`+`State`, cubit+estados via `part of`, família `sealed`, enums num `*_enum.dart`); (c) **Gate 2 — widget no tier certo** (feature → módulo → `core/widgets/`); (d) **Gate 4 — zero hardcode de estilo** (nada de `Color(0x…)`/`EdgeInsets.all(16)`/`TextStyle(fontSize:)`/`BorderRadius.circular(16)` cru); (e) **escopo mínimo de rebuild** — sem `BlocBuilder` único no topo de tela grande.

7. **Princípios de interface** (se a fase tem UI): sem celebração/streak/confete; a tela mostra hoje e esta semana, sem relatório saltando na frente; alvos grandes e ação no alcance do polegar; superfície chapada. Data no card é **explícita** ("15/08, sexta"), nunca relativa.

8. **Acessibilidade.** Cor não é o único sinal; controles com `Semantics`/tooltip; contraste da paleta verificado.

9. **Edge Functions** (se a fase toca): entrada validada por schema na borda; `index.ts` só com `Deno.serve(handler)`; cliente criado com o **JWT do usuário** onde a RLS deve valer (`service_role` só em trabalho agendado, com o porquê escrito); chamada de IA pela camada abstraída gravando em `ai_usage`; log sem dado sensível; dependência com versão fixada no `deno.json`.

10. **Cancela de máquina — o piso.** `dart format`, `flutter analyze` e `flutter test` verdes; `deno fmt`/`lint`/`check`/`test` verdes; `gates_guard.sh` e `validar-workflows.sh` limpos. **Rode — não confie no relato.** Isto é pré-requisito, não o "pronto": o pronto é o item 1.

11. **Docs.** O 03_plan.md foi marcado com o progresso? PRD/specs/plano
    continuam dizendo a verdade? `decisions.md` contém somente decisões da
    feature? Todo desvio está em `changes.md` e referencia a reconciliação? O
    roadmap reflete o estado?

Devolva: veredito por item (OK ou o que desviou, com arquivo e linha), e a lista do que precisa voltar como tarefa. Se algo contradiz uma regra do projeto, a regra ganha.

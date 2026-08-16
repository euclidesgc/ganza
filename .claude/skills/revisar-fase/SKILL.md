---
name: revisar-fase
description: Valida uma fase implementada contra o plan.md e as regras do ganza. Usada pelo QA ao fim de cada fase, antes do resumo de PR ao dev.
allowed-tools: Read, Glob, Grep, Bash, mcp__code-review-graph__detect_changes_tool, mcp__code-review-graph__get_review_context_tool, mcp__dart__analyze_files, mcp__dart__run_tests
---

# Skill: revisar uma fase

Objetivo: dado o diff da fase, conferir item a item se o que foi feito bate com o que estava planejado — o caminho inverso da `criar-modulo`.

Confira, nesta ordem:

1. **Plano.** Cada tarefa da fase no `docs/NN-<nome>/plan.md` foi feita? Algo foi feito que **não** estava no plano? Desvio não se aceita de cara: reporte ao tech-lead (correção ou justificativa ao dev).

2. **Invariantes de produto** (`CLAUDE.md` — estas se **provam**, não se declaram):
   - Nenhum caminho grava registro sem `confirmed`. Procure ativamente pelo atalho: um `insert` direto no fluxo de ingestão, um "só para teste", um flag. A extração devolve **lista**; o card **não** é editável.
   - Cálculo financeiro é código determinístico com teste, não resposta de modelo.
   - Nenhuma chave de terceiro alcançável pelo app (dart-define, asset, resposta de endpoint, log).
   - Toda tabela nova tem RLS **e** política; a migration aplica limpo num banco vazio e veio em PR próprio.
   - Storage por URL assinada, nunca bucket público.

3. **Fronteiras.** presentation não importa data; nenhuma lógica chama o get_it por dentro (só `pageBuilder`); nenhum módulo importa o interno de outro (só barrel público); domain sem `package:flutter` e sem `fromMap`; o app não fala com API externa.

4. **Convenções.** Estado sealed + switch exaustivo; `Either<Failure, T>` nos contratos; um use case por operação; entidade imutável; barrel público só com rota + DI; zero build_runner; `isClosed` após await; dinheiro em centavos inteiros; timestamp em UTC até a borda.

5. **Design system e widgets** (se a fase tem UI): (a) **Gate 1 — nenhuma função/método retorna `Widget`** (permitidos: `build`, `pageBuilder`, callbacks `itemBuilder`/`builder:` sem árvore inline extensa); (b) **Gate 3 — uma classe/widget por arquivo** (podem coabitar: par `StatefulWidget`+`State`, cubit+estados via `part of`, família `sealed`, enums num `*_enum.dart`); (c) **Gate 2 — widget no tier certo** (feature → módulo → `core/widgets/`); (d) **Gate 4 — zero hardcode de estilo** (nada de `Color(0x…)`/`EdgeInsets.all(16)`/`TextStyle(fontSize:)`/`BorderRadius.circular(16)` cru); (e) **escopo mínimo de rebuild** — sem `BlocBuilder` único no topo de tela grande.

6. **Princípios de interface** (se a fase tem UI): sem celebração/streak/confete; a tela mostra hoje e esta semana, sem relatório saltando na frente; alvos grandes e ação no alcance do polegar; superfície chapada. Data no card é **explícita** ("15/08, sexta"), nunca relativa.

7. **Acessibilidade.** Cor não é o único sinal; controles com `Semantics`/tooltip; contraste da paleta verificado.

8. **Backend** (se a fase toca): DTO validado com `class-validator`; chamada de IA passando pela camada abstraída e gravando em `ai_usage`; log sem dado sensível; `service_role` só no servidor.

9. **Cancela de máquina.** `flutter analyze` verde e testes existentes passando (e `pnpm lint`/`pnpm build`/testes no backend). **Rode — não confie no relato.**

10. **Docs.** O plan.md foi marcado com o progresso? specs/prd continuam dizendo a verdade? O roadmap reflete o estado?

Devolva: veredito por item (OK ou o que desviou, com arquivo e linha), e a lista do que precisa voltar como tarefa. Se algo contradiz uma regra do projeto, a regra ganha.

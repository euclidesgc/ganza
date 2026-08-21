---
name: escrever-testes
description: Escreve a bateria automatizada do ganza (unit + widget + golden + backend) — por último, após o gate do CISO da fase. Usada pelo QA na etapa final do fluxo, decomposta em uma frente por camada, cada uma com o seu bloco DoD.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Skill: escrever os testes automatizados

Objetivo: blindar o comportamento **já estável** (o alvo parou de se mexer). Guiado pelo PRD: caminho feliz, exceções, casos de borda.

Convenções:

- `test/` espelha `lib/`. Sem build_runner: **mocktail** (`class MockX extends Mock implements X {}`) e **bloc_test**.
- `registerFallbackValue` para `any()` com tipo custom; entidades precisam de `Equatable` para os matchers.
- Backend: Jest, com o mesmo princípio — o que é regra tem teste, o que é encanamento não.

O que escrever, por camada:

1. **Use cases** — a regra e cada `Failure` previsto (`when(() => repo.x()).thenAnswer(...)`; asserte `Left`/`Right`).
2. **Cubits** — `blocTest` com `build/act/expect` afirmando a **sequência exata** de estados, incluindo falhas.
3. **Widget** — um teste por estado do sealed (`whenListen` + `BlocProvider.value`); interações (tap, arrasto no kanban); acessibilidade (tooltip presente, seleção não só por cor).
4. **Golden** — captura de referência dos estados visuais estáveis. Gere com `flutter test --update-goldens` e commite.
5. **Backend** — endpoints (DTO inválido → 400), a camada de IA com provedor fake (inclusive o **fallback** disparando), e o parser de parcelamento com a matriz de descrições reais ("PARC 03/12", "3/12", "PARCELA 3 DE 12", e as que **não** são parcelamento).

## A bateria se decompõe por frente disjunta

**"Escrever os testes" soa como uma coisa só e não é.** Vale aqui a mesma regra
da implementação — e é justamente aqui que ela costuma ser esquecida, o que
transforma a bateria no segundo maior executor da sessão. As cinco camadas acima
já nomeiam as frentes naturais: use cases, cubits, widget, golden e backend
escrevem arquivos de teste disjuntos e nenhuma espera o resultado da outra.
Quando for esse o caso, **um agente por frente, em paralelo**, com worktree
próprio, porque vão escrever ao mesmo tempo. O que tem dependência real continua
em fila: helper compartilhado (fixture, `registerFallbackValue` de tipo custom,
harness de pump) nasce numa frente só, antes das demais.

**Cada frente é uma tarefa com bloco DoD próprio**, marcada
`[paralela · frente X · worktree]` no `03_plan.md` e julgada ao fim pelo
`supervisor-dod` (`.claude/agents/supervisor-dod.md`). Consolide as frentes e
**só então** rode a suíte completa na branch integrada.

## O que este produto exige que não é padrão

- **Matemática financeira tem teste por caso, com valor esperado ao centavo.** Price e SAC, saldo devedor, quitação antecipada nos dois cenários (reduzir prazo × reduzir parcela). Número de juros sem teste é número errado esperando a vez. Inclua o caso de borda: última parcela, quitação no primeiro mês, taxa zero.
- **Recorrência tem teste para os dois modos.** `calendar` (data fixa) e `interval_from_completion` (conta da conclusão real). O caso que importa: a ocorrência atrasa cinco dias — em `interval_from_completion` a próxima é quinze dias **depois do feito**, não da data prevista. Errar isso desalinha a rotina para sempre.
- **Adiar move a data da mesma ocorrência.** Teste que "adiei três vezes" continua contando **uma** ocorrência no ciclo, e que os três movimentos estão no log de eventos.
- **Os cinco estados terminais são distinguíveis**, em especial **pulada** (escolha) × **perdida** (falha automática). Se o teste trata as duas como "não feita", o histórico perdeu o valor que justifica existir.
- **Conciliação**: match por valor igual (± centavos) em janela de ±5 dias funde e o valor do banco é canônico; sem match, fica `standalone`; e **não** duplica quando o mesmo fato entra por chat e por extrato.
- **Confirmação**: existe um teste que prova que a ingestão **não grava** na tabela final. É a invariante nº 1 e ela merece teste explícito, não confiança.

**Widget e golden testam coisas ortogonais — não corte uma categoria achando que a outra cobre.** O golden pega regressão *visual* que nenhuma asserção lógica enxerga: cor errada, elemento cortado, clip que mudou de camada. O teste de comportamento prova o que o golden não prova: o callback disparou, o estado mudou, o texto é o certo. Descartar uma das duas cria ponto cego real. Sobreposição existe caso a caso — quando os dois afirmam exatamente a mesma coisa estreita —, e aí se decide olhando o par, nunca a categoria.

**Rode escopado enquanto escreve, suíte inteira antes de fechar.** Ver "Ritmo de teste e paralelismo" no `CLAUDE.md`.

Pirâmide: muito domínio/cubit, alguns widget, poucos integração. **Tudo verde na suíte consolidada é o DoD da fase** — o que autoriza o PR, verificado pela `fechar-etapa`. Ele não substitui o bloco DoD de cada frente: uma tarefa fecha pelo bloco dela, com os arquivos que ela escreveu passando.

---
name: escrever-testes
description: Escreve a bateria automatizada do ganza (unit + widget + golden + backend) — por último, após o E2E atestado e o segundo gate do CISO. Usada pelo QA na etapa final do fluxo.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__dart__run_tests, mcp__dart__analyze_files
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

## O que este produto exige que não é padrão

- **Matemática financeira tem teste por caso, com valor esperado ao centavo.** Price e SAC, saldo devedor, quitação antecipada nos dois cenários (reduzir prazo × reduzir parcela). Número de juros sem teste é número errado esperando a vez. Inclua o caso de borda: última parcela, quitação no primeiro mês, taxa zero.
- **Recorrência tem teste para os dois modos.** `calendar` (data fixa) e `interval_from_completion` (conta da conclusão real). O caso que importa: a ocorrência atrasa cinco dias — em `interval_from_completion` a próxima é quinze dias **depois do feito**, não da data prevista. Errar isso desalinha a rotina para sempre.
- **Adiar move a data da mesma ocorrência.** Teste que "adiei três vezes" continua contando **uma** ocorrência no ciclo, e que os três movimentos estão no log de eventos.
- **Os cinco estados terminais são distinguíveis**, em especial **pulada** (escolha) × **perdida** (falha automática). Se o teste trata as duas como "não feita", o histórico perdeu o valor que justifica existir.
- **Conciliação**: match por valor igual (± centavos) em janela de ±5 dias funde e o valor do banco é canônico; sem match, fica `standalone`; e **não** duplica quando o mesmo fato entra por chat e por extrato.
- **Confirmação**: existe um teste que prova que a ingestão **não grava** na tabela final. É a invariante nº 1 e ela merece teste explícito, não confiança.

Pirâmide: muito domínio/cubit, alguns widget, poucos integração. DoD: **tudo verde** — e só então a tarefa fecha.

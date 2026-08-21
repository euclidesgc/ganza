# RETOMADA

- **Item em curso**: 002 - Conta, configurações e chaves do usuário — **Fase 4** (Configuração de IA e o gating), **onda 1 de 6**
- **Branch / PR**: `feature/GZ-28-schema-credenciais-de-ia` (PR 4a, migrations) e `feature/GZ-29-configuracao-de-ia` (PR 4b, empilhada) — **nenhum PR aberto ainda**; os dois nascem ao fim da fase. PR #30 (Fase 3) mergeado.
- **Último gate/veredito**: 5 tarefas com `**DoD: CUMPRIDO**` do `supervisor-dod` cego — T4.1, T4.5, T4.6, T4.7, T4.8 — e consolidadas nas branches. Suíte do app verde na `GZ-29` integrada (53 testes, `analyze` limpo).
- **Primeira ação da retomada**: conferir a T4.3 (worktree `.claude/worktrees/t4-3`, `especialista-infra`, mede a chave-mestra do Vault na VPS por comando de leitura) — se não tiver commit, redespachar com o bloco DoD das linhas 1146-1150 de `docs/002_conta_e_configuracoes/03_plan.md`; se tiver, mandar ao `supervisor-dod`.
- **Depois**: fechar a onda 1, então onda 2 (**T4.2**, ponte de Vault) → onda 3 (**T4.4**, Edge Function `ai-credentials`) → ondas 4 a 6, pela tabela de ondas do `03_plan.md`.
- **Pendências do humano**: nenhuma bloqueante. A T4.3 pode gerar uma: se a chave-mestra do Vault não estiver em volume, montar o volume toca serviço da VPS compartilhada e **exige autorização** — e até lá **nenhuma chave real de IA é salva em produção**.
- **Harness**: o `auditor-de-criterios` devolveu **os seis** blocos da onda 1 antes do despacho (verde por construção, vermelho impossível, prova mutante); o `tech-lead` corrigiu a forma sem afrouxar exigência, e o padrão "provar invertendo" virou **evidência colada** em `docs/002_conta_e_configuracoes/provas/t4_<n>_falha_sem_a_mudanca.md` — aplicado também às Fases 5, 6 e ao lote de fechamento.
- **Ponteiros**: `docs/002_conta_e_configuracoes/03_plan.md` (Fase 4 nas linhas 1046-1291) · `decisions.md` · `changes.md` · `docs/decisions.md` (**D19 resolvida pela T4.5**; D30, D32, D34, D35, D36)

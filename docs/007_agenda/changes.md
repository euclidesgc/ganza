# Histórico de mudanças - Feature 007 - Agenda e Google Calendar

Este arquivo é append-only. Registre uma entrada antes de mudar a implementação
ou os documentos canônicos por causa de um desvio descoberto após o início da
feature. Depois da entrada, reconcilie PRD, specs e plano para que descrevam o
estado final, sem preservar neles uma versão obsoleta do planejamento.

## Mudanças registradas

### CHG-001 - Revogar PKCE e separar a identidade do fluxo OAuth

- **Data:** 2026-08-25
- **Fase/PR:** Fase 1 · PR 1 · T1.1 (migration `0017`).
- **Planejado originalmente:** o state OAuth seria marcado como consumido, mas
  sua linha e o segredo PKCE no Vault permaneceriam até uma exclusão posterior.
  O desenho também concedia CRUD das tabelas Calendar a `service_role` e
  expunha RPCs com `p_user_id` para a Edge Function usá-las no fluxo iniciado
  por uma pessoa.
- **Por que não foi possível prosseguir:** a revisão CISO demonstrou dois
  desvios de segurança. O verificador PKCE é efêmero e não pode sobreviver ao
  consumo nem à expiração do state; o cleanup somente em `DELETE`/troca de
  referência não cobre nenhum desses caminhos. Além disso, `service_role` com
  CRUD direto e um `p_user_id` controlável na perna interativa contornam a
  identidade do JWT e a fronteira de RLS, permitindo que o desenho deixe de
  provar que a vinculação pertence ao solicitante.
- **Alternativas consideradas:** (1) manter states consumidos para auditoria e
  apenas nulificar `pkce_secret_ref`; preserva lixo e adiciona estados/garantias
  de auditoria não requisitados. (2) limpar somente no handler; falha em crash,
  callback abandonado e expiração sem tráfego. (3) aceitar `p_user_id` com JWT
  e compará-lo a `auth.uid()`; reduz o risco, mas mantém uma API de
  impersonação desnecessária. (4) manter CRUD de `service_role` nas tabelas;
  torna a revisão de autorização dependente do chamador, não do banco.
- **Decisão tomada:** o state será consumido de forma atômica: o RPC obtém o
  verificador apenas para a transação do callback e remove a autorização, cujo
  trigger remove o segredo Vault. Autorizações vencidas serão removidas por
  rotina de purge agendada no banco, também acionável antes de iniciar novo
  OAuth, com o mesmo trigger de limpeza. O fluxo interativo usará o cliente
  Supabase portando o JWT; relações de usuário terão `user_id` derivado de
  `auth.uid()` e RLS. Não haverá CRUD direto de tabelas Calendar por
  `service_role`, nem RPC interativa que aceite `p_user_id`. A perna pública do
  callback continua excepcional e só recebe o state: a ponte interna resolve o
  dono a partir do state consumido, sem aceitar identidade do chamador.
- **Resumo da resolução:** **planejada; sem alteração de código nesta
  entrada.** A correção da migration trocará grants de CRUD por RPCs mínimas,
  fará a criação iniciada por JWT derivar o dono no banco e implementará o
  consumo/purge que apaga a referência e o segredo PKCE. Testes de migration e
  backend deverão provar consumo, expiração e a impossibilidade de escolher
  outro `user_id`.
- **Reconciliação documental:** `01_prd.md` não muda, pois produto e DoD não
  foram alterados. `02_specs.md` §§2--4 passa a descrever limpeza física do
  PKCE, `auth.uid()` e a exceção state-only do callback; `decisions.md` recebe
  FD-007; `03_plan.md` ajusta invariantes, T1.1/T2.1 e DoD para exigir essas
  provas. A migration só será corrigida depois deste registro.

## Modelo de registro

### CHG-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Fase/PR:** identificador da fase ou PR afetado.
- **Planejado originalmente:** o que `01_prd.md`, `02_specs.md` ou `03_plan.md`
  determinava antes do desvio.
- **Por que não foi possível prosseguir:** fato técnico, produto ou dependência
  que tornou o planejamento impraticável.
- **Alternativas consideradas:** opções avaliadas e suas concessões.
- **Decisão tomada:** escolha final e responsável pela aprovação.
- **Resumo da resolução:** como código, ambiente ou processo ficou resolvido.
- **Reconciliação documental:** arquivos e seções de `01_prd.md`,
  `02_specs.md` e `03_plan.md` atualizados para a realidade final.

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

### CHG-002 - Agendar o purge e criar o teste de banco que o DoD de T1.1 não cobrava

- **Data:** 2026-08-27
- **Fase/PR:** Fase 1 · PR 1 · T1.1 (migration `0017`).
- **Planejado originalmente:** o CHG-001 decidiu que autorizações vencidas
  seriam removidas por **rotina de purge agendada no banco**, também acionável
  antes de iniciar novo OAuth. O bloco de DoD de T1.1 em `03_plan.md`, porém,
  exigia apenas "teste em banco descartável" e "teste de autorização", sem
  nomear agendamento, arquivo de teste ou comando que os executasse.
- **Por que não foi possível prosseguir:** a auditoria do bloco devolveu
  `DOD INVÁLIDO` por dois defeitos de critério. Primeiro, o DoD ficou mais
  fraco que o CHG-001: `supabase/migrations/0017_criar_vinculo_google_calendar.sql`
  entregou `public.google_oauth_authorizations_purge_expired()` e a chamada no
  início do OAuth, mas nenhum `cron.schedule` — e purge disparado no
  `authorize` é exatamente a alternativa (3) que o CHG-001 rejeitou, "limpar
  somente no handler". Sem agendamento, quem vincula uma vez e não volta deixa
  state vencido e segredo PKCE no Vault indefinidamente. Segundo, os dois
  critérios não nomeavam artefato: o supervisor é cego ao plano e não tem como
  julgar "teste em banco descartável" sem caminho nem comando, e o repositório
  não tinha nenhum teste de banco — todos os `*_test.ts` são Deno contra
  handlers de Edge Function.
- **Alternativas consideradas:** (1) aceitar o purge só no `authorize`; é a
  alternativa já rejeitada no CHG-001 e deixa segredo vivo sem tráfego.
  (2) agendar a limpeza fora do banco, por cron de infraestrutura ou job de
  CI; move para outro sistema uma garantia que o schema deve sustentar sozinho
  e não é provável pela própria migration. (3) escrever o teste de banco em
  Deno, como os demais; exigiria expor o Postgres em rede e duplicar o
  bootstrap do schema `auth`, que hoje só existe no job `migrations`.
  (4) adiar o teste de banco para a fase de bateria automatizada; separaria a
  prova da migration do PR que a introduz e deixaria a Fase 1 sem cancela.
- **Decisão tomada:** o DoD passa a exigir por extenso o agendamento da rotina
  de purge por `cron.schedule`, com o job correspondente presente em
  `cron.job`. `pg_cron` já está habilitado em
  `supabase/migrations/0001_habilitar_extensoes.sql` e o job `migrations` sobe
  o Postgres com `shared_preload_libraries=pg_cron` e
  `cron.database_name=postgres`, então não há impedimento técnico. As provas
  de comportamento passam a morar em
  `supabase/tests/0017_vinculo_google_calendar.sql`, executado por um passo
  novo do job `migrations` de `.github/workflows/ci.yml`, depois de "Aplicar
  migrations em ordem", com
  `docker exec -i pg psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -q`.
  É o único ponto do repositório que já tem Postgres descartável com
  0001--0017 aplicadas, e é prova da própria migration — não é app nem
  backend, portanto cabe no PR 1, que segue contendo exclusivamente a
  migration e suas provas.
- **Resumo da resolução:** **planejada; sem alteração de código nesta
  entrada.** Os bullets 4 e 5 do bloco de T1.1 foram reescritos para nomear o
  caminho completo do teste e o comando que o roda, preservando todas as
  condições que já exigiam e somando o agendamento. O bloco estava com sete
  linhas desde 86ca480, acima do limite de três a seis: os dois primeiros
  bullets viraram um só comando encadeado por `set -eu`, que já os conjugava,
  sem perder nenhuma verificação; agora são seis. Cabe ao executor de T1.1 acrescentar o `cron.schedule` à migration,
  criar `supabase/tests/0017_vinculo_google_calendar.sql` e o passo de CI que
  o executa. Nenhuma exigência foi afrouxada.
- **Reconciliação documental:** `01_prd.md` não muda, pois produto e DoD de
  produto seguem iguais. `02_specs.md` §3 já dizia que "o purge roda agendado
  e também antes de iniciar novo OAuth", de modo que não contradiz esta
  entrada e não foi alterado. `03_plan.md` recebe o veredito `DOD INVÁLIDO` na
  linha de T1.1, os bullets 4 e 5 reescritos, o `-U` nos sete comandos `rg`
  multilinha, o estado do topo e a tabela "Progresso". `decisions.md` não
  muda: FD-004 já fixa que o trigger elimina o segredo Vault ao remover a
  linha, e o agendamento é execução dessa decisão, não decisão nova.

### CHG-003 - O escopo `calendar.events` não autoriza a leitura da lista de calendários

- **Data:** 2026-08-29
- **Fase/PR:** Fase 2 · PR 2 · T2.1 (consentimento) e T2.2 (leitura), esta já em `CUMPRIDO`.
- **Planejado originalmente:** `02_specs.md` §4 fechava o consentimento em um escopo só,
  `https://www.googleapis.com/auth/calendar.events`, e ao mesmo tempo mandava
  `GET /calendar/events` ler `calendarList` e depois os eventos de cada calendário
  acessível, como a FD-001 promete e o DoD da fase cobra ("consulta todos os
  calendários sem cache").
- **Por que não foi possível prosseguir:** os dois pedidos são incompatíveis no Google.
  A referência de `calendarList.list` aceita apenas `calendar`, `calendar.readonly`,
  `calendar.calendarlist` e `calendar.calendarlist.readonly`
  (`https://developers.google.com/workspace/calendar/api/v3/reference/calendarList/list`,
  consultada em 2026-08-29); `calendar.events` não está entre eles, e `calendars.get`
  não é rota de fuga, porque exige `calendar.calendars[.readonly]` ou `calendar[.readonly]`.
  Com o escopo planejado, a enumeração devolveria 403 e a leitura ficaria restrita ao
  calendário primário. A bateria não pega o defeito: o `fetch` é stubado em T2.1 e T2.2,
  e a prova real depende do projeto Google Cloud, que é a pendência humana P1.
- **Alternativas consideradas:** (1) acrescentar `calendar.readonly`; autoriza a listagem,
  mas concede ver e baixar qualquer calendário acessível, privilégio maior que o necessário
  e redundante com `calendar.events` na leitura de eventos. (2) reduzir a promessa ao
  calendário primário; dispensa a listagem, mas contraria a FD-001 e o DoD do PRD, e por
  ser decisão de produto não cabe ao tech-lead. (3) trocar `calendarList.list` por
  `calendars.get`; não resolve o escopo e ainda perde o nome do calendário.
  (4) manter como está e descobrir em produção; é o modo de falha que a P1 esconde.
- **Decisão tomada:** acrescentar `https://www.googleapis.com/auth/calendar.calendarlist.readonly`
  ao lado de `https://www.googleapis.com/auth/calendar.events`, registrada como FD-009 em
  `decisions.md`. É decisão técnica e reversível: mantém a escrita restrita a eventos, cumpre
  a promessa de produto sem alterá-la e é estritamente menos privilegiada que `calendar.readonly`.
  Nenhuma migration muda.
- **Resumo da resolução:** **planejada; sem alteração de código nesta entrada.** O código de
  T2.1 vive na worktree do executor e precisa de uma correção: acrescentar o segundo escopo à
  URL de autorização em `supabase/functions/calendar/google_oauth.ts` e o caso de teste que
  falha quando qualquer um dos dois escopos falta. `listAccessibleCalendars` e `listAllEvents`,
  entregues por T2.2 sobre `calendarList`, permanecem corretos e não mudam.
- **Reconciliação documental:** `02_specs.md` §4 passa a citar os dois escopos e a razão do
  segundo; `decisions.md` recebe FD-009; `03_plan.md` reescreve a primeira linha do DoD de T2.1,
  que citava o escopo literal, e acrescenta os dois escopos ao DoD da Fase 2. `01_prd.md` §7
  ainda diz que "o escopo necessário para ler todos os eventos e criar/remarcar é
  `.../calendar.events`": a frase ficou incompleta e cabe ao `product-manager` acrescentar o
  segundo escopo, porque é declaração de privacidade que alimenta a tela de consentimento.

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

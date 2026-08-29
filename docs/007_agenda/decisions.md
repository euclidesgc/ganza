# Decisões da feature 007 - Agenda e Google Calendar

Registre aqui somente decisões de escopo, produto, arquitetura ou execução que
valem para esta feature. Decisões transversais pertencem a
[`docs/decisions.md`](../decisions.md).

## Decisões vigentes

| ID | Decisão | Contexto e impacto | Data |
|---|---|---|---|
| FD-001 | Leitura percorre todos os calendários acessíveis; criação usa `primary`. | Resolve a aparente divergência entre leitura ampla do PRD e a recomendação de escrita no primário sem reduzir a leitura. | 2026-08-25 |
| FD-002 | Eventos são consultados sob demanda no Google, no horizonte -90/+365 dias. | Não há tabela, cache, sync ou webhook; o horizonte limita custo e payload sem tornar o app fonte de verdade. | 2026-08-25 |
| FD-003 | OAuth usa authorization-code server-side, state de uso único, PKCE e acesso offline. | Callback é público apenas por exigência do provedor e é autenticado pelo state; tokens nunca chegam ao Flutter. | 2026-08-25 |
| FD-004 | Refresh token e verificador PKCE vivem no Vault; segredo OAuth do projeto vive somente em env do runtime. | Remove credenciais do banco em claro, respostas e app, com limpeza de segredo órfão. | 2026-08-25 |
| FD-005 | Recorrências são exibidas, mas remarcação de série ou ocorrência é recusada. | A API distingue os efeitos; escolher implicitamente seria comportamento de produto não aprovado. | 2026-08-25 |
| FD-006 | A confirmação é idempotente pela proposta Calendar. | Evita duplicação em timeout/retry, sem criar espelho local de eventos. | 2026-08-25 |
| FD-007 | A identidade do fluxo interativo vem do JWT/RLS; a perna pública resolve o dono exclusivamente pelo state. | Elimina CRUD de `service_role` e parâmetros de impersonação no fluxo da pessoa, sem tornar o callback OAuth um endpoint autenticado por JWT. | 2026-08-25 |

## Decisões detalhadas

### FD-001 - Leitura ampla e escrita delimitada

- **Data:** 2026-08-25
- **Contexto:** o PRD exige eventos de todos os calendários acessíveis e, ao mesmo tempo, nova criação no calendário primário.
- **Alternativas:** listar só `primary` simplificaria paginação, mas violaria leitura ampla; permitir escrever em todos exigiria seleção/configuração fora do escopo.
- **Decisão:** listar eventos de cada calendário retornado por `calendarList`; criar em `primary` e remarcar exclusivamente pelo par concreto `calendarId` + `eventId` confirmado.
- **Impacto:** nenhum calendário vira cópia local; a UI identifica o calendário de cada evento e a proposta mostra o destino da escrita.

### FD-002 - Fonte única sem sync e horizonte explícito

- **Data:** 2026-08-25
- **Contexto:** consultar todos os calendários sem limite criaria payload e latência imprevisíveis, mas cache/sincronização contradiria a fonte única.
- **Alternativas:** espelhar eventos ou usar webhook reduziria leituras, ao custo de estado concorrente; listar todo o histórico é caro e pouco útil para a agenda inicial.
- **Decisão:** cada abertura/atualização consulta Google diretamente, paginada, de 90 dias antes até 365 dias depois do instante atual; não criar tabela de evento, cache persistente, sync ou webhook.
- **Impacto:** alteração externa aparece na próxima leitura; eventos fora do horizonte não são exibidos até mudar o produto, sem serem apagados ou desatualizados localmente.

### FD-003 - OAuth server-side com callback autenticado pelo state

- **Data:** 2026-08-25
- **Contexto:** o app não pode possuir client secret nem refresh token, e o callback do OAuth não carregará a sessão Supabase do app.
- **Alternativas:** implicit flow expõe mais no cliente; callback autenticado por JWT é inviável depois da navegação externa; state reutilizável abre CSRF e vinculação cruzada.
- **Decisão:** `POST /calendar/authorize` autenticado cria state aleatório armazenado apenas como SHA-256, com expiração de 10 minutos e uso único, e PKCE; `GET /calendar/callback` público valida/consome esse state antes de trocar o code no servidor.
- **Impacto:** callback não é endpoint anônimo de dados; erro, state vencido ou já consumido não cria vínculo e não revela a conta associada.

### FD-004 - Segredos no lugar correto

- **Data:** 2026-08-25
- **Contexto:** refresh token é credencial de usuário e client secret é credencial de projeto; ambos vazam se chegam ao Flutter, log ou SQL em claro.
- **Alternativas:** guardar refresh em coluna cifrada manualmente aumenta superfície e limpeza; usar `dart-define` para client secret deixa-o no binário.
- **Decisão:** refresh token e verificador PKCE são segredos Vault referenciados por UUID; client ID, client secret e redirect URI são env allowlisted somente à função Calendar/Coolify; trigger elimina segredos vinculados ao excluir as linhas.
- **Impacto:** API expõe só estado de conexão e agenda normalizada; a preparação de env pode ser feita sem inserir valores reais no repositório.

### FD-005 - Recorrência é leitura, não mutação inicial

- **Data:** 2026-08-25
- **Contexto:** uma ocorrência e a série inteira exigem patchs distintos e têm efeitos irreversíveis diferentes.
- **Alternativas:** sempre alterar série, sempre alterar ocorrência ou perguntar no meio da confirmação; todas escolhem produto não aprovado ou expandem a conversa.
- **Decisão:** consultar com instâncias para exibição e recusar `reschedule` quando o evento tiver `recurringEventId`/regra recorrente, com erro explícito.
- **Impacto:** eventos recorrentes não sofrem alteração silenciosa; decisão futura pode ampliar apenas o contrato de proposta.

### FD-006 - Idempotência da proposta, não sincronização

- **Data:** 2026-08-25
- **Contexto:** timeout pode ocorrer depois de Google criar/alterar evento e antes de a resposta voltar; repetir criaria duplicata ou estado ambíguo.
- **Alternativas:** marcar como confirmado antes da chamada mente em falha; criar tabela de eventos para deduplicar cria espelho; pedir confirmação nova penaliza a pessoa.
- **Decisão:** a proposta `pending` é a chave: criação grava `ganza_proposal_id` em propriedade privada do evento e procura essa chave antes de criar; remarcação usa o alvo imutável e transição condicional da proposta.
- **Impacto:** retry reutiliza a mesma proposta; em falha incerta a UI relê Google antes de oferecer tentativa, sem declarar sucesso local.

### FD-007 - Autoridade por origem do fluxo

- **Data:** 2026-08-25
- **Contexto:** state/PKCE protegem a perna de OAuth, mas não substituem a fronteira de identidade para relações Calendar. Dar CRUD a `service_role` ou receber `p_user_id` no fluxo iniciado pela pessoa permite impersonação desnecessária.
- **Alternativas:** deixar `service_role` fazer CRUD direto e confiar no handler; aceitar `p_user_id` e compará-lo a `auth.uid()`; exigir JWT no callback. As duas primeiras mantêm superfície de impersonação; a última não funciona após a navegação de OAuth.
- **Decisão:** endpoints iniciados pelo usuário usam o cliente Supabase com o JWT, RLS e RPCs que derivam `user_id = auth.uid()` sem parâmetro de dono. Não há CRUD direto de `service_role` nas tabelas Calendar nem RPC interativa com `p_user_id`. O callback público aceita somente o state OAuth; sua ponte interna resolve o dono a partir do state consumido e não recebe identidade do chamador.
- **Impacto:** a ligação pertence ao sujeito autenticado que iniciou o fluxo; a única exceção sem JWT permanece limitada à capacidade opaca, única e expirável concedida pelo state.

### FD-008 - Estado de reconexão derivado na leitura, não persistido

- **Data:** 2026-08-29
- **Contexto:** a migration `0017_criar_vinculo_google_calendar.sql` revoga CRUD das tabelas Calendar de `service_role` e de `authenticated`, e nenhuma das suas RPCs escreve `status`: `google_calendar_connection_save` e `google_oauth_authorization_complete_callback` só gravam `'active'`. Não existe, portanto, caminho para marcar `reconnect_required` no banco — e o refresh do modo Testing do Google expira em sete dias, então o estado precisa aparecer para a pessoa de algum jeito.
- **Alternativas:** criar migration nova com RPC de marcação de `status`, chamada quando a renovação falha; descartada porque acrescenta a família de prova migration/SQL a uma fase que hoje é só Edge Function/Deno, contrariando a regra de corte de entrega do `CLAUDE.md`, e porque estado persistido fica obsoleto quando a pessoa reconecta por fora do app, sem nada no ganzá para limpá-lo. Persistir passa a ser necessário só quando existir notificação proativa de "reconecte", que não é escopo desta feature.
- **Decisão:** nesta fase o estado de reconexão não é persistido. O adaptador de credenciais devolve resultado tipado `reconnect_required` quando o Google recusa a renovação do refresh token, e `GET /calendar/connection` deriva o estado na própria leitura, sem gravar em `public.google_calendar_connections`. A coluna `status` continua existindo e permanece `'active'` enquanto o vínculo existir.
- **Impacto:** `GET /calendar/connection` paga uma tentativa de renovação por leitura, custo aceito. `supabase/functions/calendar/calendar_credentials.ts` e `handler.ts` não escrevem `status`, e o DoD de T2.1 e T2.3 em `03_plan.md` cobra o estado derivado, não a escrita. Introduzir notificação proativa de reconexão reabre esta decisão e exige migration própria.


### FD-009 - Escopo de consentimento: eventos mais lista de calendários

- **Data:** 2026-08-29
- **Contexto:** o escopo `https://www.googleapis.com/auth/calendar.events` não autoriza `calendarList.list`. A referência oficial do método aceita apenas `calendar`, `calendar.readonly`, `calendar.calendarlist` e `calendar.calendarlist.readonly` (`https://developers.google.com/workspace/calendar/api/v3/reference/calendarList/list`, consultada em 2026-08-29). Sem um desses, enumerar os calendários da pessoa devolve 403 e a promessa de ler todos os calendários da FD-001 não se cumpre. O `fetch` stubado dos testes de T2.1 e T2.2 não revela isso: só o Google revelaria, em produção.
- **Alternativas:** (1) acrescentar `calendar.readonly`, que autoriza a listagem mas também "ver e baixar qualquer calendário a que você tem acesso", incluindo conteúdo que `calendar.events` já cobre — privilégio maior que o necessário. (2) reduzir a promessa ao calendário primário, dispensando `calendarList`; muda o PRD e é decisão do humano, não técnica. (3) usar `calendars.get` em vez de `calendarList.list`; não resolve, pois esse método exige `calendar.calendars[.readonly]` ou `calendar[.readonly]` e continua fora de `calendar.events`.
- **Decisão:** a URL de consentimento pede `https://www.googleapis.com/auth/calendar.events` ("ver e editar eventos em todos os seus calendários") e `https://www.googleapis.com/auth/calendar.calendarlist.readonly` ("ver a lista de calendários do Google que você assina"), além de `openid` para o `sub` do `id_token`. É a combinação de menor privilégio que cumpre a promessa: a escrita continua restrita a eventos e a leitura ampla se limita a enumerar calendários, sem o acesso geral de `calendar.readonly`.
- **Impacto:** `supabase/functions/calendar/google_oauth.ts` monta a URL com os dois escopos; `calendarList.list` passa a devolver `summary` e `timeZone` legitimamente, e `calendars.get` continua desnecessário. A tela de consentimento passa a listar duas permissões, o que a descrição de privacidade do produto precisa declarar. Nenhuma migration muda.


### FD-010 - Três dívidas da Fase 2 que ficam declaradas, com gatilho na P1

- **Data:** 2026-08-29
- **Contexto:** o crítico integrador achou três resíduos que não bloqueiam a fase e que, sem registro, existiriam só na conversa que os descobriu. **(1) Um `401` do Google nunca vira `reconnect_required`:** `supabase/functions/calendar/google_calendar.ts` trata todo `!response.ok` — inclusive `401` — como indisponibilidade, que sai como `google_unavailable`/502; o único produtor de `reconnect_required` é `supabase/functions/calendar/calendar_credentials.ts`, e só no `invalid_grant` da renovação. Na prática a janela é estreita, porque o access token é obtido a cada requisição e um `401` na chamada seguinte é raro, mas quando acontecer a pessoa lê "Google indisponível" no lugar de "reconecte". **(2) Política de retry divergente para o mesmo provedor:** `google_calendar.ts` repete uma vez em falha de rede e 5xx; `calendar_credentials.ts` e o `exchangeCode` de `google_oauth.ts` não repetem nada, embora os dois falem com o mesmo `oauth2.googleapis.com/token`. Isso não é decisão tomada: T2.1 e T2.2 rodaram em worktrees isoladas e cada uma resolveu por si, sem reconciliação. **(3) `hashContent` mora no lugar errado:** é utilitário de hash genérico importado de `supabase/functions/_shared/observability/ai_event.ts`, um módulo nomeado para telemetria de IA; quem procurar um hash não olha ali, e quem mexer na telemetria não espera ter um utilitário genérico como dependente.
- **Alternativas:** corrigir agora as três. Descartada para (1) e (2) porque a correção certa depende de saber o que o Google devolve **de fato** — se `401` de token expirado, `403` de escopo, ou `invalid_grant` só na renovação —, e hoje nada disso é observável: o `fetch` é stubado em toda a bateria e o projeto Google Cloud é a pendência humana **P1**. Escolher o comportamento por suposição plantaria um segundo desvio com cara de decisão. Descartada para (3) porque mover um símbolo compartilhado toca `supabase/functions/ingest/handler.ts` e o teste de `_shared/observability/`, fora do escopo desta fase e sem urgência.
- **Decisão:** as três ficam declaradas como dívida, não corrigidas nesta fase. **Gatilho de (1) e (2): a primeira sessão de trabalho contra o Google real, assim que a P1 destravar** — ali se decide, com resposta observada, o mapeamento de `401`/`403` para `reconnect_required` e uma política única de retry para todas as chamadas ao Google, escrita num só lugar. **Gatilho de (3): a próxima feature que tocar `supabase/functions/_shared/observability/`**, que move `hashContent` para um utilitário de propósito geral e ajusta os importadores no mesmo PR.
- **Impacto:** enquanto a dívida (1) existir, `reconnect_required` só aparece pelo caminho da renovação, e a UI da Fase 3 não deve tratar `google_unavailable` como estado permanente. A dívida (2) mantém a leitura de eventos mais resiliente que a troca de código e a renovação, o que é aceitável mas não é desenho. Nenhuma das três altera contrato público, migration ou o DoD já julgado das tarefas da Fase 2.


## Conflito do PRD reconciliado sem alterar o PRD

Não há conflito material no PRD: a frase sobre guardar "o calendário primário"
é interpretada como destino de escrita, pois as seções 1, 3 e 6 exigem leitura
de todos os calendários acessíveis. FD-001 torna essa separação explícita. A
recomendação backend de `primary` não pode ser usada para reduzir a leitura a
um calendário sem contrariar o DoD do próprio PRD.

## Modelo de decisão

### FD-NNN - Título objetivo

- **Data:** AAAA-MM-DD
- **Contexto:** problema ou oportunidade que exigiu a decisão.
- **Alternativas:** opções consideradas e suas concessões.
- **Decisão:** escolha feita e responsável.
- **Impacto:** arquivos, contrato, risco ou dependência afetados.

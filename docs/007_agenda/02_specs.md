# 007 - Agenda e Google Calendar · Especificação técnica

Estado: pronta para implementação na branch `feature/007-agenda-google-calendar`.
O PRD é a fonte de produto; esta especificação fecha os contratos técnicos sem
alterar seu escopo.

## 1. Discovery e âncoras verificadas

O CRG não está instalado neste ambiente (`rtk crg --help` não resolve o
executável). O discovery usou `scripts/docs_index.py` e `rg` como fallback.

| Área | Âncora | Reuso / lacuna confirmada |
|---|---|---|
| Propostas | `supabase/migrations/0010_criar_messages_e_proposed_actions.sql` | Há RLS e estados `pending/confirmed/cancelled`, mas `kind` não contém Calendar e o payload não tem contrato de calendário. |
| Confirmação | `supabase/functions/proposals/handler.ts` e `supabase/functions/_shared/ai/proposal_writer.ts` | A fronteira de confirmação e a proteção por JWT são o modelo a copiar; o writer atual só materializa registros locais e não pode chamar Google. |
| Edge runtime | `supabase/functions/main/index.ts` e `supabase/functions/main/env.ts` | O roteador autentica toda função fora de `PUBLICAS` e faz allowlist de env por função; a nova função deve receber somente as variáveis Google de que precisa. |
| Vault | `supabase/migrations/0008_criar_ponte_de_vault_das_credenciais_de_ia.sql` | Há padrão de `secret_ref`, RPC `security definer`, grants exclusivos a `service_role` e limpeza do segredo associado. |
| Chat | `app/lib/modules/chat_module/` | `ChatProposal`, `ChatRepositoryImpl`, `ChatCubit` e `ChatProposalCard` já mostram propostas e confirmam por Edge Function; o card atual só exibe descrição/valor. |
| Rotas/DI | `app/lib/app_router.dart`, `app/lib/modules/chat_module/chat_routes.dart`, `app/lib/modules/chat_module/chat_injection.dart` | O módulo novo segue route por módulo, barrel público e DI explícita; o router não é lugar para cliente Google. |
| Convenções | `CLAUDE.md`, `docs/plano.md` §6.10 e D34 de `docs/decisions.md` | Google é canônico, app não fala com terceiros, RLS é obrigatória; E2E está suspenso e a prova é unitária/widget. |

Não há módulo `calendar_module`, endpoint Calendar, tabela de vínculo Google,
cache/sincronização de eventos, webhook ou seleção de calendário existentes.

## 2. Decisões técnicas fechadas

As decisões locais e suas concessões estão em [`decisions.md`](decisions.md).
Em resumo: a leitura percorre todos os calendários acessíveis, mas escrita
cria no `primary`; a consulta é sempre ao Google, com janela explícita de 90
dias anteriores a 365 posteriores; recorrências são lidas como ocorrências e
não são remarcadas nesta versão; OAuth é authorization-code server-side com
state de uso único, PKCE e refresh offline. O state é removido fisicamente,
junto com seu verificador PKCE no Vault, tanto no consumo quanto no purge por
expiração. Relações iniciadas por uma pessoa derivam o dono de `auth.uid()` do
JWT e obedecem RLS; a exceção é o callback público, cuja única fonte de
identidade é o state. Refresh token fica no Vault; repetição de confirmação é
idempotente por proposta.

## 3. Dados persistidos

Migration proposta: `supabase/migrations/0017_criar_vinculo_google_calendar.sql`.
Ela não cria entidade nem espelho de evento.

| Tabela | Campos mínimos | Regras |
|---|---|---|
| `public.google_calendar_connections` | `id`, `user_id`, `google_subject`, `primary_calendar_id`, `refresh_secret_ref`, `status`, `created_at`, `updated_at`, `last_connected_at` | Uma conexão por usuário; `status` fechado em `active/reconnect_required`, e nesta fase nenhuma rota grava `reconnect_required`: o estado é derivado na leitura de `GET /calendar/connection` (FD-008); RLS `user_id = auth.uid()`; operações interativas derivam esse campo no banco, nunca de request/body; o app nunca seleciona `refresh_secret_ref`. |
| `public.google_oauth_authorizations` | `id`, `user_id`, `state_sha256`, `pkce_secret_ref`, `redirect_uri`, `expires_at`, `created_at` | State opaco tem uso único e expira em 10 minutos; só o hash é persistido e o verificador fica no Vault. Não há histórico `consumed_at`: consumo e expiração removem a linha e o segredo físico correspondente. |
| `public.proposed_actions` | novos `kind`: `create_calendar_event`, `reschedule_calendar_event`; payload Calendar fechado | Ação continua `pending` até confirmação e recebe `resulting_id`/`resulting_type` só após resposta de sucesso do Google. |

As tabelas Calendar não concedem CRUD direto a `service_role`. As RPCs mínimas
mantêm `search_path = ''`: no fluxo interativo autenticado, criam/consultam
relações sob o JWT e derivam `user_id = auth.uid()` internamente, sem
`p_user_id`; a ponte excepcional do callback recebe somente state, resolve o
dono dentro do banco e nunca aceita identidade do chamador. O consumo atômico
e a rotina de purge no banco removem a autorização; o trigger dessa remoção
apaga o segredo PKCE. A exclusão/troca de conexão apaga o refresh token. O
purge roda agendado e também antes de iniciar novo OAuth. Nenhuma coluna guarda
token em claro.

## 4. Contratos de backend

Todos os endpoints vivem em `supabase/functions/calendar/`; `index.ts` contém
somente `Deno.serve(handler)`. Cada requisição autenticada cria cliente
Supabase com o JWT recebido: RLS e RPCs derivam o dono por `auth.uid()`, e o
request não contém `user_id`. Não existe CRUD direto de `service_role` nas
tabelas Calendar nem RPC interativa com `p_user_id`. O callback é público só
porque OAuth exige isso: recebe `state`, consome-o de modo atômico e a ponte
interna resolve o dono a partir dele; não confia em JWT, body, query ou header
como identidade. Qualquer uso de credencial privilegiada fica limitado a
operação interna de Vault e nunca é passado ao app.

| Método e rota | Auth | Request | Response / efeito |
|---|---|---|---|
| `POST /calendar/authorize` | JWT do usuário | `{}` | Executa purge de states vencidos, cria state de uso único cujo dono vem de `auth.uid()` e devolve `{ authorization_url }`; URL contém `state`, PKCE challenge, `access_type=offline`, `prompt=consent` e os escopos mínimos `https://www.googleapis.com/auth/calendar.events`, para ler e escrever eventos, e `https://www.googleapis.com/auth/calendar.calendarlist.readonly`, sem o qual `calendarList.list` devolve 403 (FD-009). |
| `GET /calendar/callback` | State, não JWT | query `code`, `state`, `error` | Endpoint público por necessidade OAuth. Seu único insumo de identidade é state válido; a ponte interna resolve o dono, troca code no servidor, grava refresh no Vault e consome/remove fisicamente a autorização e PKCE de modo atômico. Retorna página sem token que redireciona ao deep link configurado. |
| `GET /calendar/connection` | JWT do usuário | — | `{ status: 'connected'|'disconnected'|'reconnect_required', primary_calendar_id?: string }`; não devolve subject, tokens, secret refs ou URL de autorização. |
| `GET /calendar/events?time_min=<UTC>&time_max=<UTC>` | JWT do usuário | ISO UTC dentro do horizonte permitido | Lê `calendarList`, depois eventos de cada calendário acessível; devolve itens normalizados e `calendar_id`, `calendar_name`, `event_id`, `title` (o `summary` do Google, `null` quando omitido), `start`, `end`, `all_day`, `recurring_event_id?`, `time_zone`; sem persistir eventos. **A resposta tolera falha por calendário** e pode vir parcial, sem sinalização — ver logo abaixo. |
| `POST /calendar/proposals` | JWT do usuário | `{ proposal_id, action: 'confirm'|'cancel' }` | Cancela sem chamada externa; confirma uma proposta Calendar pendente e faz create/patch idempotente; devolve `{ status, proposal_id }` ou erro tipado. |

`GET /calendar/events` é tolerante a falha parcial, e isso muda o que a
ausência de eventos significa. A leitura percorre os calendários de
`calendarList` um a um: o que responde entra no resultado, e o calendário que
falhar no meio do caminho — 403, 404 ou 410 por remoção ou perda de acesso
entre a listagem e a leitura — é **omitido**, com uma linha de log
`calendar_events_partial_failure` contendo só o `calendar_id` e o nome da
classe do erro. Só quando **todos** os calendários falham a rota devolve
`502 google_unavailable`, porque aí não há resultado parcial a preservar.

**Não há sinalização ao cliente de que a lista veio parcial**: nem campo na
resposta, nem cabeçalho, nem código. A consequência para quem constrói a tela
é direta e precisa ser dita: "nenhum evento naquele calendário" e "aquele
calendário falhou" chegam ao app com a mesma aparência. A tela da Fase 3 não
deve, portanto, afirmar vazio como fato do calendário da pessoa — e uma
sinalização explícita de parcialidade, se um dia for desejada, é mudança de
contrato desta rota, não detalhe de implementação.

Erros fechados, separados **pela forma da resposta**, porque as duas rotas de
saída não são intercambiáveis.

Como JSON `{ error: { code, message } }`, nas rotas sob JWT: `unauthorized`,
`method_not_allowed`, `not_found`, `invalid_json`, `invalid_payload`,
`invalid_action`, `invalid_proposal_id`, `connection_required`,
`reconnect_required`, `google_unavailable`, `internal_error` e, na confirmação,
`proposal_not_found`, `proposal_not_pending`, `event_not_found`,
`event_ambiguous`, `recurring_event_unsupported`, `write_failed`.

Como **página HTML em pt-BR**, e só em `GET /calendar/callback`: sucesso,
`authorization_denied` (200), `invalid_state` (400), `invalid_payload` (400) e
qualquer outra falha (502). O callback termina numa aba do navegador, não num
cliente HTTP, então `invalid_state` e `authorization_denied` **nunca chegam ao
app como `{ error: { code } }`** — quem for tratá-los no cliente não os
encontrará.

Dois nomes são razão interna e não código público: `unauthenticated`, que em
`POST /calendar/authorize` sai como `unauthorized`, e `connection_not_found`,
que em `GET /calendar/connection` vira `{ status: 'disconnected' }` e em
`GET /calendar/events` vira `connection_required`. Já `reconnect_required`
aparece nas duas formas: corpo de sucesso 200 em `/connection` e erro 409 em
`/events`.

Não existe `state_expired`, e a ausência é deliberada: state inexistente,
vencido e já consumido devolvem o mesmo `invalid_state`. O callback é público
por necessidade do OAuth, então distinguir os três contaria a quem chama sem
credencial se aquele state alguma vez existiu e se já foi usado — exatamente a
informação que a FD-003 nega ao dizer que erro, state vencido ou consumido não
cria vínculo nem revela a conta associada. O banco também não teria como
distinguir: o consumo remove a linha fisicamente e a leitura já filtra por
`expires_at > now()`, de modo que depois disso "vencido" e "nunca existiu" são
o mesmo estado. Quem for "corrigir" isso no futuro está reintroduzindo um
oráculo de enumeração, não consertando um bug.

Logs contêm somente código, operação e identificadores técnicos; nunca título,
horário, payload, token ou segredo.

## 5. Contrato de proposta Calendar

`create_calendar_event` aceita somente:

```json
{
  "title": "Dentista",
  "calendar_id": "primary",
  "time_zone": "America/Sao_Paulo",
  "start": "2026-08-28T14:00:00-03:00",
  "end": "2026-08-28T15:00:00-03:00",
  "all_day": false
}
```

`reschedule_calendar_event` inclui, além da proposta de horário, o par alvo
imutável `{ "calendar_id", "event_id" }`, o instantâneo `original_start` e
`original_end`, e rejeita payload com `recurring_event_id`. A confirmação
reconsulta o evento: id inexistente, divergência do horário original ou evento
recorrente produz erro e não faz patch aproximado.

Antes de gravar, a borda resolve datas relativas em instantâneos absolutos no
fuso do calendário. Evento de dia inteiro conserva `date` sem fabricar hora.
O card sempre mostra título, calendário, data/hora absoluta e, no remarcação,
antes/depois. O modelo/chat apenas propõe esse payload validado; ele não vê
nem manipula token Google.

## 6. Idempotência e consistência externa

A proposta é a chave de idempotência. Na primeira confirmação de criação, a
função envia `extendedProperties.private.ganza_proposal_id = <proposalId>`.
Antes de criar, consulta o calendário alvo por essa chave; se achar um evento,
marca a mesma proposta como confirmada e devolve sucesso sem duplicar. Para
remarcação, a função faz patch somente do `calendarId + eventId` da proposta e
só uma proposta `pending` por vez pode avançar por atualização condicional.

Se a rede falhar depois de a requisição sair, o endpoint não declara sucesso
local: retorna `google_unavailable`; a UI recarrega a agenda e uma nova
tentativa reutiliza a mesma proposta/idempotency key. Não há cache, sync ou
webhook para esconder um estado divergente: a leitura seguinte vem do Google.

## 7. App Flutter

Novo módulo: `app/lib/modules/calendar_module/`, com domínio Dart puro,
models zard em data e Cubit/estados sealed em presentation. A leitura usa a
Edge Function, não `supabase_flutter` direto, pois contém integração Google e
renovação de token. O app usa PostgREST somente para ler as propostas pendentes
já autorizadas por RLS e Edge Function para iniciar OAuth, listar agenda e
confirmar/cancelar a escrita.

A abertura da URL OAuth e o retorno ao aplicativo são encapsulados em serviço
de plataforma; a URL é recebida do backend e não contém segredo do projeto.
Falha de retorno não cria conexão fictícia: a tela consulta `/connection` ao
retomar e apresenta reconexão quando necessário.

## 8. Dependências externas e riscos

Para o fluxo real faltam projeto Google Cloud, consent screen publicada ou
modo Testing, client ID/secret, redirect HTTPS e conta de teste. Isso bloqueia
apenas a prova contra Google, não migrations, contratos, testes com `fetch`
stubado, UI ou deploy. O modo Testing pode revogar refresh em sete dias; a UI
trata isso como `reconnect_required`, nunca como calendário vazio atualizado.

O principal risco de escopo é tentar resolver disponibilidade, múltiplas
contas, escolha de calendário, alteração de convidados ou sincronização. Não
há base técnica para introduzi-los aqui: cada um muda o contrato e exige nova
decisão de produto.

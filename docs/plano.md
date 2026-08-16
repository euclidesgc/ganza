# Ganzá — Plano de Produto e Arquitetura

> Versão 0.6 — o sistema ganhou nome e identidade visual.
> Stack: Flutter (Android e Web, mesmo código), Supabase self-hosted, Gemini, Pluggy, Google Calendar.

**Mudou desde a v0.5:** o sistema passou a se chamar Ganzá e ganhou a seção 11, com marca,
paleta, tipografia e os princípios de interface derivados do significado do nome.

**O nome.** Ganzá é o chocalho cilíndrico cheio de sementes que sustenta o ritmo no forró e no
maracatu. Ele não faz solo: marca o pulso por baixo de tudo. É a descrição exata do produto —
muitos registros pequenos guardados num recipiente só, mantendo o ritmo da sua semana sem
disputar atenção.

---

## 1. Problema

Sua vida está espalhada: contas em cinco instituições, faturas em PDF, parcelas e financiamentos que só aparecem quando caem, contas fixas de valor variável lembradas na véspera, arrumação da casa e banho do cachorro na memória, livros que você queria ler perdidos numa nota, projetos de trabalho em outro lugar.

O ponto crítico não mudou: **ferramenta que exige disciplina de entrada estruturada é abandonada em três semanas.** O custo de registrar tem que ser próximo de zero. Estruturar é trabalho do sistema.

Finanças é a parte com mais regras, não a parte mais importante.

---

## 2. Objetivos

| # | Objetivo | Como se mede |
|---|---|---|
| O1 | Registrar qualquer coisa em menos de 10 segundos | Toque no app até a confirmação |
| O2 | Interpretação correta na primeira tentativa | ≥ 85% dos cards confirmados sem refazer |
| O3 | Visão financeira sem trabalho manual | ≥ 95% das transações vindas de sincronização |
| O4 | Nenhum vencimento perdido | Zero atrasos por esquecimento em 3 meses |
| O5 | Enxergar o comprometido, não só o gasto | Previsão de 12 meses sempre disponível |
| O6 | Saber quanto sobra | Receita menos despesa e comprometido, por mês |
| O7 | Saber o que você realmente cumpre | Taxa de cumprimento por rotina |
| O8 | Sobreviver ao próprio uso | Uso diário 90 dias após a Fase 2 |

O8 é o objetivo real.

---

## 3. Não-objetivos (v1)

| Não faremos | Por quê |
|---|---|
| **OCR / leitura de QR de nota fiscal** | O texto ou áudio é a fonte do dado; a imagem é comprovante anexo. |
| **Correção de registro pelo chat** | Corrigir é na tela do registro. Tira `update` do modelo. |
| **Entidade de pessoas** | Presente e aniversário ficam na descrição; aniversário já vive na agenda. |
| **Metas com progresso mensurável** | Objetivos são listas e projetos, não indicadores. |
| **Orçamento por categoria** | P1. Teto sem histórico é chute. A coluna nasce no schema, nula. |
| **Multiusuário** | Muda RLS, LGPD, e o plano pessoal gratuito da Pluggy só vale para contas nominais suas. |
| **iOS** | Flutter deixa a porta aberta; não pague o custo agora. |
| **Entidades definidas pelo usuário** | "Áreas configuráveis" ≠ schema dinâmico. |
| **Sincronização bidirecional de agenda** | Google Calendar é a fonte da verdade. |
| **Offline-first completo** | v1 tem só fila de saída para mensagens do chat. |
| **Iniciação de pagamentos (Pix)** | O app avisa; quem paga é você. |
| **Investimentos e patrimônio** | Fase futura. |
| **Gravação sem confirmação** | Regra do sistema, não escopo. |

---

## 4. Riscos

**R1 — Escopo. (alta)** Cinco produtos num só. Cada fase usável sozinha, e usada de verdade antes da próxima.

**R2 — Duplicidade. (alta)** Registro manual, parcelamento informado e extrato descrevem o mesmo fato. Conciliação no modelo desde a primeira migration.

**R3 — Notificações no Android brasileiro. (média-alta)** Alarme exato restrito desde o Android 12; fabricantes matam background. Dupla via obrigatória.

**R4 — Fadiga de alerta. (média-alta)** App que insiste vira app silenciado. Por isso atrasada para de notificar em 3 dias.

**R5 — Custo da primeira carga. (média)** Milhares de transações sem categoria, tabela de aprendizado vazia.

**R6 — Credencial vazada. (média)** APK se descompila. Nada de chave no cliente.

**R7 — Transcrição de valores em pt-BR. (média)** É por isso que a confirmação é obrigatória.

**R8 — Cobertura incompleta de instituição. (média)** Entrada manual é caminho de primeira classe, não remendo.

**R9 — Infraestrutura própria. (média-alta)** VPS compartilhada com outros sistemas, sem backup gerenciado e sem redundância. Se a VPS cair, o app cai; se o disco morrer sem backup, os dados vão junto. Mitigação: `pg_dump` agendado com cópia externa desde a Fase 0, e monitoramento de memória. Migrar para o gerenciado depois é barato — mesmo stack, mesmas migrations.

---

## 5. Arquitetura

```
┌──────────────────────────────────────────────┐
│  Flutter (Android / Web)                     │
│  ├── Chat (texto, áudio, foto, documento)    │
│  ├── Dashboards e gráficos                   │
│  ├── Boards kanban (listas e projetos)       │
│  ├── Rotinas e atrasadas                     │
│  ├── Telas financeiras                       │
│  └── Configurações                           │
└───────────────┬──────────────────────────────┘
                │ supabase_flutter (auth + RLS)
┌───────────────▼──────────────────────────────┐
│  Supabase                                    │
│  ├── Postgres (dados + RLS)                  │
│  ├── Storage (áudio, fotos, PDFs)            │
│  ├── Edge Functions                          │
│  │    ├── /ingest       → interpreta mensagem│
│  │    ├── /transcribe   → áudio → texto      │
│  │    ├── /sync-finance → Pluggy             │
│  │    ├── /calendar     → Google Calendar    │
│  │    ├── /finance-math → juros e amortização│
│  │    ├── /schedule     → gera ocorrências   │
│  │    └── /notify       → push e cobranças   │
│  ├── pg_cron (sync, varredura, geração)      │
│  └── Vault (chaves de IA, Pluggy, OAuth)     │
└───────────────┬──────────────────────────────┘
                │
     ┌──────────┴───────────┬──────────────────┐
   Pluggy               Gemini          Google Calendar
```

**Princípio:** o app Flutter não fala com nenhuma API externa diretamente. Tudo por Edge Function.

### 5.1 Infraestrutura

O Supabase roda **self-hosted em VPS própria, orquestrado por Coolify**, com domínio DuckDNS e TLS emitido pelo Coolify.

Isso é viável: o compose oficial do Supabase traz Postgres, Auth (GoTrue), PostgREST, Realtime, Storage, Kong, Studio e o runtime de Edge Functions. `pg_cron` e Vault funcionam normalmente. Nada do que este plano desenha fica impossível.

**Pré-requisitos a verificar antes da Fase 0:**

- **Memória disponível.** A pilha completa sobe cerca de dez contêineres. Com outros sistemas já rodando na mesma VPS, confirmar folga real de RAM antes de instalar. Se faltar, dá para enxugar: Studio, Realtime e imgproxy não são necessários para este app.
- **Arquitetura do processador.** Confirmar x86 ou ARM e a disponibilidade das imagens correspondentes.
- **Backup.** Deixa de ser problema de terceiro e vira responsabilidade sua. `pg_dump` agendado com cópia fora da VPS, desde o primeiro dia. O banco vai guardar extratos e contratos.
- **URL pública com HTTPS estável.** Necessária para o redirect do OAuth do Google e para o app alcançar o backend fora de casa.
- **SMTP próprio** para os e-mails de autenticação.

Memória e arquitetura serão verificadas no início da Fase 0, pela sessão de construção, que terá acesso à VPS. Não são bloqueantes para fechar o plano.

**Diferença prática que afeta o dia a dia:** no self-hosted não existe `supabase functions deploy` para a nuvem. As Edge Functions são servidas pelo contêiner de runtime a partir de um volume, então o fluxo de publicação passa a ser deploy do repositório, não comando de CLI. Vale montar isso na Fase 0, senão vira atrito em toda alteração de função.

### 5.2 Estrutura do repositório

Um único código Flutter gera Android e Web. **Não são dois projetos** — é o mesmo `lib/` com dois alvos de build e ajustes pontuais de captura (áudio e câmera se comportam diferente no navegador).

```
ganza/
├── melos.yaml
├── apps/
│   └── app/                    # Flutter — Android e Web
├── packages/
│   ├── core/                   # modelos, tipos, erros
│   ├── data/                   # repositórios, cliente Supabase
│   ├── design_system/          # tema e componentes
│   └── features/
│       ├── chat/
│       ├── routines/
│       ├── boards/
│       ├── finance/
│       └── settings/
├── supabase/
│   ├── migrations/             # SQL versionado
│   ├── functions/              # Edge Functions em TypeScript/Deno
│   │   ├── ingest/
│   │   ├── schedule/
│   │   ├── notify/
│   │   ├── sync-finance/
│   │   ├── finance-math/
│   │   └── calendar/
│   ├── seed.sql
│   └── config.toml
├── infra/
│   └── coolify/                # compose e variáveis de ambiente
└── docs/
    └── plano.md
```

O projeto é poliglota: Dart no app, TypeScript nas funções, SQL nas migrations. Não há como fugir disso com Supabase.

**Sobre o acento:** use `ganza` sem acento no repositório, no `applicationId`, nos nomes de pacote e na URL. "Ganzá" fica reservado para o que aparece na tela. Acento em identificador técnico gera atrito em domínio, handle e resolução de dependências.

---

## 6. Decisões que definem o projeto

### 6.1 Confirmação obrigatória, sem exceção

**Nada vira registro sem confirmação explícita.** Não há gravação automática, nem para tipo de baixo risco, nem com confiança alta.

```
mensagem → classificação → extração → CARD → confirma → grava
                                           → cancela → você refaz
```

O card **não é editável**: confirmar ou cancelar. Errou, manda de novo com o ajuste.

**Uma mensagem pode gerar vários registros**, com confirmação **um por vez, em sequência**. Cancelar um não afeta o outro. A extração devolve lista, nunca objeto.

### 6.2 Intenções do chat

| Intenção | O que faz | Quando |
|---|---|---|
| `create` | registra transação, tarefa, rotina, nota, compromisso | Fase 1 |
| `attach` | vincula foto a registro existente | Fase 3 |
| `query` | responde pergunta sobre os dados | Fase 6 |

`update` não existe no chat. `query` entra na taxonomia desde o início mesmo sem implementação, para que uma pergunta feita cedo receba "ainda não sei consultar" em vez de virar registro torto.

**Resolução de referência** (`attach`): filtro estruturado montado pelo modelo — janela de data, faixa de valor, termo na descrição —, nunca SQL livre. Um candidato → card. Vários → lista de 2 a 3. Nenhum → pergunta.

**Foto sem texto** → pergunta na hora; a imagem fica pendurada na mensagem até você responder.

**Datas relativas** → contexto carrega data, hora e fuso. Verbo no passado resolve para o passado. O card mostra data explícita ("15/08, sexta").

**Categoria** → sempre sugerida. Cada correção grava `descrição normalizada → categoria` em `category_hints`; a repetição seguinte resolve por lookup, sem modelo.

### 6.3 Áreas, boards e o fim da área "Finanças"

Núcleo fixo de tipos: `transaction`, `commitment`, `routine`, `task`, `note`, `document`. (`event` mora na agenda.)

**Áreas padrão:** Rotina pessoal, Rotina profissional, Alimentação, Objetivos. Configuráveis: criar, renomear, reordenar, arquivar. Excluir desassocia, não apaga.

**Finanças não é área — é uma visão transversal.** Ração do cachorro é despesa da área Casa; presente é despesa da área onde aquilo faz sentido; almoço é Alimentação. O dashboard financeiro agrega por cima de todas as áreas. Compartimentar dinheiro numa área contraria o "tudo relacionado".

**Board com prazo opcional cobre três coisas que pareciam diferentes:**

| O que é | Como se implementa |
|---|---|
| Lista ("Livros para ler", "Aulas para assistir") | board sem prazo, tarefas sem data |
| Projeto ("Reforma", entrega de trabalho) | board com prazo e status, tarefas com data |
| Evento ("Festa 12/09") | board com prazo, tarefas e despesas vinculadas |

Uma área contém quantos boards você quiser. Nenhum tipo novo.

Vínculos por tabela genérica:

```sql
create table links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  source_type text not null, source_id uuid not null,
  target_type text not null, target_id uuid not null,
  relation text not null default 'related',
  created_at timestamptz default now()
);
```

### 6.4 Rotinas: o mesmo padrão de compromisso, aplicado a esforço

Lavar roupa toda semana e banho no cachorro a cada quinze dias não são tarefas com data — são **regras que geram ocorrências**, exatamente como conta de luz gera cobrança mensal.

**Correção em relação ao que eu disse antes:** o *padrão* é o mesmo, mas as tabelas são separadas. `commitments` carrega oito colunas financeiras (juros, sistema de amortização, fatura, cartão) que seriam peso morto em "banho no cachorro", e `routines` precisa de modos de recorrência que não fazem sentido para dinheiro. Duas tabelas, mesmo desenho, mais uma view unificada para "o que vem esta semana".

**Dois modos de recorrência — a distinção mais importante aqui:**

| Modo | Como calcula a próxima | Exemplo |
|---|---|---|
| `calendar` | data fixa, independente de quando foi feito | lavar roupa toda segunda |
| `interval_from_completion` | conta a partir da conclusão real | banho no cachorro a cada 15 dias |

Se o banho atrasa cinco dias, o próximo é quinze dias depois do banho real. Com recorrência de calendário, isso ficaria errado para sempre.

**Cinco estados terminais da ocorrência**, só um automático:

`feita` · `adiada` · `pulada` · `cancelada` · `perdida` (automático, passou da data sem ação)

A distinção entre *pulada* (escolha) e *perdida* (falha) é o que dá valor ao histórico. Misturar as duas transforma o registro em ruído.

**Adiar move a data da mesma ocorrência, não cria outra.** O ciclo é a unidade de contagem — "a lavagem da semana 33" é uma, tenha sido movida três vezes ou nenhuma. Os movimentos ficam num log de eventos. Se cada adiamento gerasse ocorrência nova, "quantas vezes lavei roupa em agosto" perderia resposta confiável.

**Adiar não afeta o próximo ciclo**, exceto no modo `interval_from_completion`.

**Atrasada para de notificar depois de 3 dias**, mas continua visível na lista de atrasadas até você resolver. App que insiste vira app silenciado.

O retorno disso é a taxa de cumprimento por rotina: o número que responde "eu realmente lavo roupa toda semana ou acho que lavo?".

### 6.5 Compromisso financeiro é movimento previsível, com direção

Toda `transaction` tem `direction`: `in` ou `out`. Um compromisso gera ocorrências mensais, também com direção. Salário é compromisso de entrada; financiamento é de saída. Mesma máquina.

| `value_mode` | Data | Valor | Exemplo |
|---|---|---|---|
| `one_off` | conhecida | conhecido | café, almoço (não gera compromisso) |
| `installment` | previsível | conhecido desde o início | compra em 12x, financiamento |
| `fixed` | previsível | igual todo mês | aluguel, assinatura |
| `variable` | previsível | desconhecido até informar | luz, água, gás, salário |

- **Installment** gera todas as ocorrências futuras na criação.
- **Variable** gera ocorrência com valor nulo; entra na previsão pela média dos últimos meses, marcada como estimativa.
- Quando a Pluggy traz o movimento real, ele **casa com a ocorrência prevista** — não vira lançamento novo.

**Parcelamento entra por duas vias:** informado no chat, **ou** detectado na fatura. A detecção não precisa de IA — a descrição carrega o indicador ("PARC 03/12", "3/12", "PARCELA 3 DE 12"); regex resolve a maioria. Deduplicação por estabelecimento + valor da parcela + total de parcelas.

### 6.6 Financiamento: contrato, não lista de parcelas

Guarda valor total, número de parcelas, saldo devedor, **taxa de juros**, sistema de amortização (Price ou SAC) e indexador.

**Simulação de quitação antecipada** compara sempre os dois cenários: reduzir prazo e reduzir valor da parcela, com juros economizados em cada um.

Base legal: o CDC garante redução proporcional dos juros na liquidação antecipada; o valor é o presente das parcelas restantes descontado pela taxa do contrato.

**Ressalvas — o número do app vai divergir do número do banco:**
- Contrato tem seguro (MIP e DFI no imobiliário), taxa de administração e IOF, que não descontam na mesma proporção.
- Imobiliário indexado à TR depende de projeção; é estimativa.
- O número oficial é o que o banco informar.

**Regra dura: esse cálculo é código determinístico, nunca IA.** O modelo interpreta o pedido; quem calcula é uma função em `/finance-math`.

### 6.7 Conciliação, receita e primeira carga

`source` (`manual` | `chat` | `bank_sync`) e `reconciliation_status` (`pending` | `matched` | `standalone` | `ignored`).

Match por valor igual (± centavos) em janela de ±5 dias. Match → funde, valor do banco é canônico. Sem match → pergunta no chat.

**Forma de pagamento se infere disso.** Nasce `unknown`; se em 15 dias nada casou, vira `cash`. O app nunca pergunta.

**Cartão-benefício** é conta com saldo próprio, não cartão com fatura. Gasto é despesa normal; **a recarga mensal entra como receita**. As restrições de uso fazem quase toda despesa dele cair na mesma categoria.

**Primeira carga puxa todo o histórico disponível** — na prática algo em torno de 12 meses.

- **Categorização em lote, com agrupamento antes.** "UBER *TRIP" aparece 200 vezes e consome uma chamada, não 200.
- **Histórico não concilia.** Entra como `standalone`.

### 6.8 Cobertura das instituições

Verificado: Caixa, Itaú, Nubank e C6 têm conector na Pluggy; Safra também, com fluxo próprio de autorização no app.

- **Dados de operação de crédito são opcionais no consentimento.** Se não marcar, financiamento não vem.
- **Instituição com só contrato de crédito, sem conta:** deve funcionar, mas **testar na primeira semana da Fase 2**.
- **Cartão-benefício:** cobertura não confirmada. Verificar na lista de conectores.

**Fallback:** o que não conectar entra como compromisso manual.

### 6.9 O app inicia conversa

Gatilhos: ocorrência variável sem valor perto do vencimento, fatura fechando, vencimento chegando, rotina do dia, transação sem conciliação.

**Cobrança de conta variável:** 3 dias antes por padrão, configurável por despesa. Não cobra se o valor já chegou pelo banco.

Pergunta pendente tem estado próprio (`pending_questions`) e reaparece até ser respondida ou dispensada.

**Alerta é uma notificação em dois canais**: mensagem no chat e alarme no celular. Entrega em dupla via:

- **Local** (`flutter_local_notifications` + `android_alarm_manager_plus`): exige `SCHEDULE_EXACT_ALARM`, falha em aparelhos com otimização agressiva.
- **Servidor** (`pg_cron` → Edge Function → FCM): a via confiável.

Onboarding pede exclusão da otimização de bateria.

### 6.10 Agenda: Google Calendar é a fonte da verdade

Sem tabela de eventos própria, sem sincronização bidirecional. O app lê e escreve na API e guarda só o vínculo em `links`.

- Mostra **todos** os compromissos, não só os criados pelo app.
- Marcar e remarcar pelo chat escreve na agenda.
- Aniversários e datas pessoais vêm de lá — motivo pelo qual não existe entidade de pessoas.

Ressalva: OAuth do Google exige app publicado ou modo de teste com refresh token expirando a cada 7 dias.

### 6.11 IA plugável

Provedor padrão: **Gemini**, tier gratuito, decisão consciente de que dado financeiro passa por lá.

```sql
ai_providers(id, name, kind, base_url, secret_ref /* Vault */, enabled)
ai_routes(task_type, provider_id, model, temperature, max_tokens, fallback_provider_id)
```

`task_type`: `classify_intent`, `extract_record`, `bulk_categorize`, `resolve_reference`, `transcribe_audio`, `summarize_period`, `refine_idea`, `answer_query`, `chat_general`.

O Gemini aceita áudio direto, então transcrição e extração poderiam ser uma chamada só. **Mantenha os dois `task_types` separados** — quando errar, você precisa saber qual etapa falhou.

1. Chave nunca sai do Vault, nunca chega ao cliente.
2. O app pede "execute a tarefa X", não "chame o provedor Y".
3. Toda chamada grava custo e latência em `ai_usage`.
4. Toda rota tem fallback.

---

## 7. Modelo de dados (esboço)

```
profiles              id, timezone, locale, settings jsonb
areas                 id, user_id, slug, name, icon, color, allowed_types text[],
                      default_view, dashboard_config jsonb, is_system, position, archived_at

messages              id, user_id, role, content, media_path, media_type, transcript, created_at
proposed_actions      id, message_id, sequence, kind, payload jsonb, status, resulting_id, resulting_type
pending_questions     id, user_id, kind, context jsonb, due_at, status, answered_message_id

transactions          id, user_id, area_id, direction /*in|out*/, amount, currency, occurred_at,
                      description, merchant, category_id, account_id, card_id, invoice_id,
                      occurrence_id, payment_method, source, external_id,
                      reconciliation_status, metadata jsonb

commitments           id, user_id, area_id, name, direction, value_mode, total_amount,
                      installments_total, due_day, closing_day, reminder_days_before /*3*/,
                      interest_rate_monthly, amortization_system, indexer, outstanding_balance,
                      category_id, card_id, account_id, status, started_at, ends_at
occurrences           id, commitment_id, sequence, due_date, expected_amount, actual_amount,
                      estimate_source, transaction_id, status

routines              id, user_id, area_id, board_id, name, recurrence_mode
                      /*calendar|interval_from_completion*/, recurrence_rule, interval_days,
                      reminder_days_before, notify_until_days /*3*/, status
routine_occurrences   id, routine_id, sequence, due_date, completed_at,
                      status /*pending|done|postponed|skipped|cancelled|missed*/
occurrence_events     id, occurrence_type, occurrence_id, event /*postponed|skipped|...*/,
                      from_date, to_date, note, created_at

accounts              id, user_id, provider, external_id, institution,
                      type /*checking|savings|benefit_wallet|credit*/, balance,
                      usage_restrictions jsonb, last_synced_at
cards                 id, user_id, account_id, label, brand, last_four, closing_day, due_day, credit_limit
invoices              id, card_id, period, closing_date, due_date, total, status, paid_at

categories            id, user_id, name, parent_id, icon, budget_monthly /*null até P1*/
category_hints        id, user_id, normalized_description, category_id, hits, updated_at

boards                id, user_id, area_id, name, due_date /*null = lista*/, status
board_columns         id, board_id, name, position, wip_limit
tasks                 id, user_id, area_id, board_id, column_id, title, description,
                      status, priority, due_at, position, completed_at

notes                 id, user_id, area_id, title, body, status /*raw|refined|archived*/
documents             id, user_id, storage_path, kind, uploaded_at

calendar_link         id, user_id, google_account, refresh_token_ref, primary_calendar_id
links                 (ver 6.3)
ai_providers / ai_routes / ai_usage   (ver 6.11)
```

RLS em **todas** as tabelas desde a primeira migration, política `user_id = auth.uid()`.

---

## 8. Requisitos

### P0

| ID | Requisito | Critério de aceite |
|---|---|---|
| F1 | Chat de texto que interpreta e propõe | "gastei 45 no almoço" → card com valor, data, categoria sugerida |
| F2 | Múltiplos registros por mensagem | Duas coisas numa frase → dois cards em sequência |
| F3 | Confirmação obrigatória | Nenhum caminho grava sem `status = confirmed` |
| F4 | Sincronização via Pluggy | Cron diário; primeira carga com todo histórico disponível |
| F5 | Receita e despesa | Toda transação tem direção; dashboard mostra o que sobra |
| F6 | Compromissos e ocorrências | Parcelamento em 12x gera 12 ocorrências futuras na previsão |
| F7 | Detecção de parcelamento na fatura | "PARC 03/12" vira compromisso sem duplicar o informado no chat |
| F8 | Contrato de financiamento | Taxa, sistema de amortização e saldo; simulação prazo × parcela |
| F9 | Conta variável com cobrança ativa | Ocorrência sem valor gera pergunta 3 dias antes (configurável) |
| F10 | Conciliação | Movimento bancário funde com registro manual ou ocorrência prevista |
| F11 | Faturas de cartão | Fatura por período **e** transações navegáveis individualmente |
| F12 | Cartão-benefício | Conta com saldo; gasto = despesa, recarga = receita |
| F13 | Rotinas recorrentes | Dois modos de recorrência; ocorrências geradas automaticamente |
| F14 | Histórico de cumprimento | Cinco estados terminais; adiar move a mesma ocorrência e registra o evento |
| F15 | Atrasadas sem fadiga | Para de notificar em 3 dias, permanece na lista |
| F16 | Boards com prazo opcional | Lista, projeto e evento no mesmo mecanismo |
| F17 | Kanban | Arrastar entre colunas, colunas configuráveis, posição persistida |
| F18 | Alertas em dupla via | Entregue com o app fechado, por push do servidor |
| F19 | Dashboard financeiro transversal | Agrega todas as áreas: gasto por categoria, evolução, comprometido, saldo |
| F20 | Áreas configuráveis | Criar, renomear, reordenar, arquivar |
| F21 | Telas de correção | Editar transação, compromisso, ocorrência e rotina fora do chat |
| F22 | Camada de IA abstraída | Trocar provedor/modelo de um `task_type` sem mexer no código |
| F23 | Segurança | Nenhuma credencial no cliente; RLS total; storage com URL assinada |

### P1

Áudio · anexo de foto a registro existente · Google Calendar · `query` pelo chat · configurações de IA com painel de custo · dashboards por área · taxa de cumprimento por rotina · busca global · orçamento por categoria · versão web.

### P2

Resumo mensal por IA · refinamento de ideias (`note` → tarefas) · importação de OFX · recorrências complexas · OCR opcional por despesa · investimentos · modo offline real.

---

## 9. Fases

Se a fase N não estiver em uso diário, não comece a N+1.

**A rotina vem antes de finanças.** É ela que faz o app ser aberto todo dia, e é o domínio mais barato para construir a máquina de ocorrência, estado terminal, log de eventos e notificação em dupla via. Quando finanças chegar, herda tudo isso pronto — a parte difícil da arquitetura é validada no domínio fácil.

| Fase | Conteúdo | Estimativa |
|---|---|---|
| **0 — Fundação** | Supabase self-hosted no Coolify, backup agendado, fluxo de deploy das Edge Functions, monorepo melos, Flutter, auth, migrations com RLS, navegação, tema. Cadastro manual. Sem IA. | 3 sem |
| **1 — Chat de texto** | `/ingest`, classificação, extração em lista, `proposed_actions`, cards em sequência. | 2–3 sem |
| **2 — Rotina** | Rotinas com dois modos de recorrência, geração de ocorrências, cinco estados terminais, log de eventos, lista de atrasadas, boards com prazo opcional, kanban, alertas em dupla via. | 3–4 sem |
| **3 — Finanças** | Pluggy, receita e despesa, compromissos e ocorrências, parcelamento, contrato de financiamento e simulação, faturas, cartão-benefício, conciliação, primeira carga em lote, cobrança de conta variável, dashboard, telas de correção. | 5–6 sem |
| **4 — Multimodal** | Áudio com transcrição; foto como anexo; `attach`. | 2 sem |
| **5 — Agenda** | OAuth Google, leitura de todos os eventos, criar e remarcar pelo chat. | 2 sem |
| **6 — Organização** | Áreas configuráveis, dashboards por área, vínculos, taxa de cumprimento. | 2–3 sem |
| **7 — Controle** | Configurações de IA, painel de custo, `query` pelo chat, orçamento. | 3 sem |
| **8 — Web** | Build web, layout responsivo, ajustes de captura. | 2 sem |

**Total realista, uma pessoa em tempo parcial: 6 a 7 meses.**

A Fase 0 cresceu de 2 para 3 semanas por causa da infraestrutura própria: subir o Supabase no Coolify, resolver variáveis de ambiente, TLS, SMTP, backup e o fluxo de publicação das funções consome tempo que no gerenciado não existiria. É custo pago uma vez.

**Primeiro momento em que o app é útil de verdade: fim da Fase 2**, em torno de 8 a 10 semanas.

## 10. Custo mensal estimado

| Item | Valor |
|---|---|
| VPS própria com Coolify | R$ 0 (já existente) |
| Supabase self-hosted | R$ 0 em licença; custa RAM e manutenção |
| Armazenamento de backup externo | R$ 0 a poucos reais, conforme destino |
| Pluggy — Meu Pluggy, uso pessoal | R$ 0 |
| Google Calendar API | R$ 0 |
| Gemini, tier gratuito | R$ 0, sujeito a limite de requisições |
| FCM | R$ 0 |

Custo financeiro próximo de zero. O custo real da escolha por infraestrutura própria não é dinheiro: é tempo de manutenção e o risco de perder dados sem backup.

## 11. Identidade

A identidade sai do significado do nome, não de tendência visual.

### 11.1 Marca

Um cilindro fechado com grãos dentro — o instrumento visto de lado. Reduz a uma cápsula de cantos arredondados com cinco pontos internos, legível a 24px.

Os grãos se destacam da marca e viram elemento de interface: faixa de pulso da rotina, indicador de dias cumpridos e perdidos, estado de carregamento. O mesmo vocabulário no logo e na tela.

### 11.2 Paleta

Tirada dos materiais do instrumento: couro, palha trançada, latão envelhecido e semente escura. Nenhum azul de SaaS.

| Token | Hex | Papel |
|---|---|---|
| couro | `#1C1815` | fundo escuro, tinta |
| casca | `#3A322B` | superfície elevada no escuro |
| ocre | `#C8813A` | primário — a cor do próprio instrumento |
| latão | `#E3B15F` | acento claro, previsto, estimativa |
| palha | `#EFE6D6` | fundo claro, texto sobre escuro |
| verde seco | `#6B7F5A` | cumprido, conciliado |
| terracota | `#B4553D` | atrasado, perdido, estouro |

Verde e terracota carregam estado sem virar semáforo. Num app aberto todo dia, vermelho saturado transforma a tela num painel de alarmes e ensina você a ignorá-la.

### 11.3 Tipografia

- **Fraunces** nos títulos — traço levemente irregular, combina com o material artesanal.
- **IBM Plex Sans** no corpo e nos números — tem algarismos tabulares, necessários para colunas de valores não dançarem entre linhas.

### 11.4 Princípios de interface

Derivados do instrumento, e valem mais que a paleta:

**O ganzá não solta solo.** O app sustenta por baixo, não disputa atenção. Sem confete, sem streak, sem parabéns por lavar roupa. É o mesmo raciocínio que já levou os alertas a silenciarem depois de três dias.

**O som é contínuo, não é evento.** A tela inicial mostra hoje e esta semana. Relatório é coisa que se vai buscar, não que salta na frente.

**Toca-se com uma mão, num gesto.** Alvos grandes, ações no alcance do polegar, chat sempre a um toque.

**Material humilde.** Superfícies chapadas, sem vidro fosco, sombra pesada ou brilho. Se parecer caro demais, errou o instrumento.

---

## 12. Perguntas em aberto

1. **RAM e arquitetura disponíveis na VPS** — a verificar no início da Fase 0, pela sessão de construção, que terá acesso à VPS. A pilha do Supabase sobe cerca de dez contêineres e a máquina já roda outros sistemas; se a folga de memória não for suficiente, as alternativas são reduzir a pilha (dispensar Studio, Realtime e imgproxy) ou voltar ao Supabase gerenciado.
2. Destino do backup externo: outro provedor, máquina local, ou serviço de objeto? Também a definir na Fase 0.
3. Limite de requisições do tier gratuito do Gemini na primeira carga financeira: pode exigir processar em lotes ao longo de horas.
4. Se o cartão-benefício não tiver conector na Pluggy, entrada manual mensal é aceitável?

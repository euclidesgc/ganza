# 007 - Agenda e Google Calendar · PRD

A agenda do Ganzá é uma janela para o Google Calendar, que continua sendo a
fonte da verdade. A feature conecta uma conta Google, mostra seus compromissos
e permite criar ou remarcar compromissos pelo chat com confirmação explícita.
Ela não cria um segundo calendário nem uma sincronização concorrente
(`docs/plano.md` §6.10).

## 1. Resultado esperado

Depois de autorizar uma conta Google, a pessoa vê na agenda todos os eventos
dos calendários aos quais essa conta tem acesso. Alterações feitas no Google
aparecem na próxima leitura da agenda; o Ganzá não mantém eventos próprios
nem decide qual versão prevalece.

Pelo chat, ela pode pedir um novo compromisso ou remarcar um existente. O chat
mostra o título, a data e a hora explícitos, o calendário alvo e, na
remarcação, o horário original e o proposto. Somente **confirmar** executa a
escrita no Google; cancelar não cria nem altera evento algum.

## 2. Fronteira: o que o chat interpreta e o que o sistema decide

| O chat interpreta | O sistema decide |
|---|---|
| intenção de criar ou remarcar, título, referência ao evento e data/hora propostas | autorização OAuth, calendário e evento concretos, fuso, chamada à API Google e sucesso/falha da operação |
| pedido com data relativa, como “sexta às 14h” | data absoluta no fuso do calendário e os campos exibidos no card antes da confirmação |

O chat nunca recebe token Google nem chama a API diretamente. Ele produz uma
proposta; a confirmação é a única transição que provoca a mutação externa,
mantendo a regra geral de confirmação obrigatória.

## 3. Caminhos felizes

### Conectar e consultar a agenda

1. A pessoa escolhe conectar Google Calendar e conclui o consentimento OAuth
   com permissão somente para eventos.
2. O backend guarda o vínculo da conta, a referência segura do refresh token e
   o calendário primário; nenhum token volta ao app.
3. A agenda consulta os calendários acessíveis e mostra seus eventos, incluindo
   os que foram criados fora do Ganzá.
4. Uma alteração feita no Google é refletida ao abrir ou atualizar a agenda.

### Criar pelo chat

1. A pessoa escreve “marque dentista na sexta às 14h”.
2. O chat propõe um evento com título, data/hora absoluta e calendário primário
   da conta conectada.
3. O card de confirmação mostra esses dados de forma explícita.
4. Confirmar cria o evento no Google; a agenda passa a exibi-lo. Cancelar não
   deixa evento nem vínculo local.

### Remarcar pelo chat

1. A pessoa pede para remarcar um evento identificável, por exemplo “mude a
   consulta de amanhã para sexta às 14h”.
2. O sistema localiza um único evento e propõe a alteração, exibindo antes e
   depois com datas e horas explícitas.
3. Confirmar atualiza aquele evento no Google. A próxima leitura usa o estado
   devolvido pelo Google, que é canônico.

## 4. Exceções e casos de borda

- **Sem conta conectada, consentimento recusado, token revogado ou refresh
  inválido:** a agenda informa que a conexão precisa ser feita novamente; não
  usa token expirado como se os dados fossem atuais.
- **Evento inexistente, ambíguo ou alterado/removido no Google antes da
  confirmação:** não há alteração por aproximação. O chat pede esclarecimento
  ou informa que a proposta ficou desatualizada.
- **Pedido de criar sem título ou sem data suficiente:** o chat pede somente o
  dado faltante; não inventa horário nem cria rascunho no Google.
- **Evento de dia inteiro:** permanece de dia inteiro. Se o pedido muda apenas
  a data de um evento com hora, preserva a hora original; hora explícita no
  pedido a substitui. A interpretação e a exibição usam o fuso do calendário,
  nunca data relativa no card.
- **Conflitos no mesmo horário:** não impedem a criação nesta fase. A agenda
  mostra a sobreposição; não existe sugestão automática de horário livre.
- **Evento recorrente:** é mostrado na agenda, mas sua remarcação via chat não
  é entregue inicialmente. Alterar uma ocorrência ou toda a série tem efeitos
  distintos e exige uma decisão explícita de produto, não uma escolha implícita
  da API.
- **Falha de rede/API após confirmar:** o app informa falha e recarrega a agenda
  antes de oferecer nova tentativa, evitando declarar sucesso local sem a
  confirmação do Google.

## 5. O que esta feature não entrega

- Tabela, cache persistente ou sincronização bidirecional de eventos.
- Calendário local do aparelho, Outlook, iCloud ou outro provedor.
- Edição ou remoção por chat; alteração de convidados, videoconferência,
  descrição, local, lembretes ou regra de recorrência.
- Escolha/configuração de calendário de escrita, múltiplas contas Google ou
  criação de calendários. A primeira versão grava no calendário primário da
  conta conectada.
- Detecção de disponibilidade, prevenção de conflitos ou notificações novas.

## 6. Invariantes que o DoD cobra

1. **Google é a fonte da verdade:** não existe entidade/tabela de evento do
   Ganzá; a listagem vem da API Google e uma atualização externa prevalece na
   próxima leitura.
2. **Leitura ampla, escrita delimitada:** a agenda mostra eventos de todos os
   calendários acessíveis à conta autorizada; criação usa o calendário primário
   e remarcação só atinge o par concreto `calendarId` + `eventId` confirmado.
3. **Nenhuma alteração externa sem confirmação explícita:** criar/remarcar é
   proposta primeiro; cancelar, ambiguidade ou falha não mutam o Google.
4. **Token é secreto:** credencial OAuth, refresh token e segredo do cliente
   vivem apenas no backend/Vault; o aplicativo recebe estado de conexão e dados
   de agenda, jamais essas credenciais.
5. **Fuso e data explícitos:** toda proposta mostra data absoluta e horário no
   fuso do calendário; eventos de dia inteiro não ganham horário artificial.

## 7. Dependências, riscos e pressupostos reversíveis

- **Dependências:** 002 (sessão e cofre de credenciais), 003 (chat,
  `proposed_actions` e confirmação) e a infraestrutura de Edge Functions.
- **Dependência externa bloqueante para integração real:** o responsável pelo
  projeto deve fornecer/configurar um projeto Google Cloud, cliente OAuth,
  tela de consentimento, URIs de redirecionamento HTTPS e uma conta de teste.
  Sem isso, é possível planejar e testar contratos locais, mas não provar o
  fluxo OAuth contra o Google.
- **Risco de operação:** enquanto a tela OAuth estiver em modo *Testing*, o
  refresh token de escopos Calendar expira em sete dias. A conexão deve expor o
  estado “reconectar”; uso diário exige publicação/consentimento adequado no
  Google, não uma promessa falsa de renovação permanente. [Documentação OAuth
  do Google](https://developers.google.com/identity/protocols/oauth2)
- **Risco de privacidade:** o escopo necessário para ler todos os eventos e
  criar/remarcar é `https://www.googleapis.com/auth/calendar.events`; ele dá
  acesso a eventos de todos os calendários acessíveis. A tela de consentimento
  e a descrição do produto precisam declarar isso de forma direta.
- **Pressuposto reversível:** há uma única conta Google conectada e o
  calendário primário é o destino de novas criações. Uma seleção de calendário
  pode ser adicionada depois sem converter o Google em cópia local.

## 8. Decisão humana pendente e Definition of Done

### Decisão humana pendente

1. **Aprovar este PRD e a limitação inicial para eventos recorrentes.** A
   alternativa é definir já se “remarcar” altera uma ocorrência, toda a série
   ou sempre pergunta — são comportamentos materialmente diferentes.
2. **Disponibilizar a configuração externa Google OAuth** descrita na seção 7.
   É autoridade sobre conta externa; não deve ser presumida pelo time.

### Definition of Done da feature

- Uma conta autorizada vê eventos de calendários acessíveis, inclusive eventos
  criados fora do app, e uma alteração externa aparece após atualização.
- O chat cria um evento no calendário primário somente após confirmação, e o
  card mostra dados explícitos antes da escrita.
- O chat remarca um evento único somente após confirmação; alvo ambíguo,
  recorrente, removido ou sem conexão não sofre mutação silenciosa.
- Tokens e segredo OAuth não aparecem no Flutter, em `dart-define`, respostas
  de API ou logs; o vínculo persistido segue RLS e armazenamento seguro.
- Fluxos visíveis e falhas relevantes têm cobertura de teste unitário/widget e
  o DoD de cada tarefa/fase é aprovado pelo gauntlet.

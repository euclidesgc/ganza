# 002 - Conta, configurações e chaves do usuário · PRD

Enriquece [`02_specs.md`](02_specs.md). O que está lá não se repete aqui: este documento é o contrato do "pronto".

Decisões desta feature estão em [`decisions.md`](decisions.md). Desvios já
resolvidos e a reconciliação documental correspondente estão em
[`changes.md`](changes.md); este PRD descreve somente o estado final.

## 1. Resultado esperado

Ao fim desta feature, **uma pessoa que não é o dono do repositório** instala o app, cria a própria conta, recupera a senha sozinha quando esquecer, abre o menu lateral e configura três coisas: como o app deve chamá-la, qual modelo de IA usar **com a chave dela**, e qual banco conectar. Nada do que ela registra é visível para outra conta, e o que ela gasta em IA sai da conta dela.

Enquanto ela não configurar a IA, o app não fica quebrado: fica um **app de registro manual**, com o chat visivelmente apagado e o motivo escrito na tela.

O que isto prova, e é o único motivo da feature existir: **o ganzá deixa de ser monousuário por desenho.** Até aqui, "separação por usuário" era uma política de RLS que ninguém tinha como violar porque só existia uma conta. A partir daqui existe uma segunda conta, e o isolamento vira prova, não pressuposto.

O que **não** se prova aqui, e não deve ser cobrado: qualidade da interpretação do chat (não há chat ainda), conciliação bancária (conectar ≠ conciliar) e controle de custo agregado de IA.

## 2. Quem usa, e o que muda para cada um

| | Hoje | Depois desta feature |
|---|---|---|
| **O dono** | conta única criada à mão; senha esquecida se redefine pelo Studio; o app não sabe o nome dele; não existe chave de IA em lugar nenhum | cria e recupera conta pelo app; o nome aparece no menu; traz a própria chave e escolhe o modelo |
| **Uma segunda pessoa** | não existe — a porta está fechada no ambiente remoto (`422 signup_disabled`, decisão **D11**) | instala, cria conta, e vê **só** os próprios registros |

A decisão **D11** de `docs/decisions.md` ("conta única, cadastro fechado; o app é monousuário por desenho") e o não-objetivo **"Multiusuário"** de `docs/plano.md` §3 caem com esta feature. Não é detalhe de implementação: eram a justificativa escrita para não existir tela de cadastro.

Multiusuário aqui significa **isolamento**, não colaboração. Duas contas não se veem, não se convidam e não compartilham nada.

## 3. As três seções de Configurações

O menu lateral nasce ampliável — hoje ele leva a Configurações, e Configurações lista três seções. Cada uma existe porque uma coisa que a pessoa precisa hoje só se resolve fora do app.

| Seção | O problema, hoje | O que a pessoa faz | O que ela nunca vê |
|---|---|---|---|
| **Dados do usuário** | O app não tem como chamá-la pelo nome, e trocar a senha exige acesso ao painel do banco de dados | edita o nome e troca a senha informando a atual | nenhum campo de e-mail editável — o motivo está escrito na tela |
| **IA** | Não existe caminho para trazer a própria chave. Sem isso, todo custo de modelo seria do dono do servidor, para todo mundo | escolhe provedor e modelo de um catálogo e cola a própria chave | **a chave de volta.** A tela mostra "configurada ✓", provedor, modelo e os quatro últimos dígitos |
| **Integração bancária** | Sem conexão não há extrato, e o app não tem como saber que ele existe | conecta pelo fluxo do provedor, vê o status e desconecta | credencial nenhuma do provedor — quem fala com ele é o servidor |

### 3.1 Por que o e-mail não se troca aqui

No estado atual do servidor, aplicar um endereço novo não exige prova de posse. Um dígito errado move a conta para um endereço que a pessoa não controla — e o único caminho de volta, a recuperação de senha, vai para lá. O campo fica somente leitura **com o motivo visível**, não escondido atrás de um campo que não responde ao toque.

### 3.2 Por que a chave é do usuário, e por que isso não fere a invariante 4

A invariante 4 do `CLAUDE.md` ("nenhuma credencial no cliente") continua valendo inteira. O que esta feature obriga a distinguir:

| | Credencial **do projeto** (Gemini do ganzá, provedor bancário, FCM, Google) | Credencial **do usuário** (a chave de IA dele) |
|---|---|---|
| De onde vem | do humano, direto no servidor | da pessoa, digitada no app |
| Por onde passa | nunca pelo app | pelo app **uma vez**, a caminho do servidor |
| Onde vive | env/Vault do servidor | cifrada no servidor |
| Volta para o app? | nunca | **nunca** |

A régua não mudou: o binário descompilado não pode conter chave nenhuma, e nenhuma resposta do servidor pode devolver uma chave. As duas continuam verdadeiras — o que entra é uma chave que **atravessa** o cliente, sem nunca ficar nele.

### 3.3 Por que a integração bancária depende de uma decisão que não é técnica

Quem contrata o agregador é o **projeto**, não a pessoa: a Pluggy é Instituição de Pagamento licenciada pelo BCB e o contrato é do desenvolvedor (`https://www.pluggy.ai/legal`, `https://www.pluggy.ai/desenvolvedores`, consultados em 19/08/2026). Trazer a credencial de cada usuário foi avaliado e **descartado** — a razão está em [`decisions.md`](decisions.md) (FD-019), e a curta é que o teto de requisição do provedor é por IP, não por credencial (`https://docs.pluggy.ai/docs/rate-limits`).

Isso põe uma decisão **comercial** no caminho, e ela é do dono: o ambiente gratuito serve para desenvolver e provar a seção (100 conexões, **sem sincronização automática**), enquanto atualizar sozinho exige o ambiente pago, publicado a partir de R$ 2.500/mês (`https://docs.pluggy.ai/page/faq`, `https://www.pluggy.ai/precos`). O que a seção promete nesta feature — **conectar, ver status e desconectar** — cabe inteiro no gratuito. Extrato chegando sozinho, não.

Se a conta paga não fizer sentido, existe caminho **sem agregador nenhum**: importar o extrato em OFX/CSV, que os bancos grandes exportam e que se lê de forma determinística, sem IA (FD-021). Ele custa zero e perde o tempo real. Não é o desenho desta feature; é a saída registrada por escrito para quando a conta não fechar.

## 4. Gating: apagado com motivo, nunca escondido

O chat só abre com a IA configurada e ativa; a conciliação, com o banco conectado. Sem nenhum dos dois, o app é registro manual — que é um app inteiro, não um app pela metade.

A decisão de produto não é *se* barra, é **como a indisponibilidade aparece**:

| Alternativa | Por que não |
|---|---|
| Esconder o item | Quem não sabe que o chat existe não sabe que falta configurar. O menu vira um lugar onde coisas surgem sozinhas |
| Deixar ativo e falhar depois | Ensina o caminho errado e gasta a paciência da pessoa numa tela que nunca ia funcionar |
| **Apagado, com o motivo** | Diz o que falta e onde resolver, em uma linha, sem cobrar nada |

O produto tem o princípio "**o app não insiste**" (`docs/plano.md` §11.4). Não tem o princípio "o app engana". Item apagado não insiste — só não mente sobre por que não abre. O motivo é anunciado também por leitor de tela: sem isso, quem não enxerga a cor encontra um item morto.

Vale a recíproca, e ela é metade do critério: assim que a chave é salva, o item **acende sem navegação manual no meio**. Configurar e continuar preso na tela recém-preenchida é o modo de falha que o gating produz quando é escrito pela metade.

## 5. A promessa que o chat vai herdar

O chat é a feature seguinte, mas a defesa dele nasce aqui: retrofitar defesa em pipeline pronto custa reescrita, e escrevê-la antes custa o mesmo que escrever o pipeline torto.

O vetor **não é a pessoa digitando no próprio chat** — aquilo é dado dela, e ela já pode registrar o que quiser pela tela manual. O vetor é **texto de terceiro que entra no mesmo prompt**: nome de estabelecimento vindo do extrato, texto extraído de foto ou PDF, transcrição de áudio.

A invariante 1 ("nada vira registro sem confirmação explícita") já elimina a categoria inteira "a saída do modelo vira estado do sistema". O que sobra, e o que esta feature promete:

| O risco que sobra | Promessa de produto |
|---|---|
| **Proposta convincente.** Um card plausível originado do extrato pode ser confirmado sem a pessoa perceber que não foi ela quem pediu | Toda mensagem carrega a procedência desde a origem, e o teto de propostas por mensagem limita o volume. Mostrar a procedência **no card** é obrigação da fase que desenhar o card |
| **Custo.** Um texto que peça repetição, ou uma carga de doze meses do extrato, esgota a cota e derruba o app inteiro | Teto de tamanho de entrada, de itens por lote e de gasto por dia, com a recusa visível no mesmo lugar onde o custo é visível — em vez de sumir |
| **Aprendizado envenenado.** A memória de categoria é aplicada depois **sem passar pelo modelo**; errar ali erra em silêncio e para sempre | Ela só aprende de **correção explícita da pessoa**, nunca da saída do modelo |

O que **não** entra como defesa: lista de palavras proibidas e "detector de injection" por outro modelo. Os dois estão em [`decisions.md`](decisions.md) com a razão escrita — não é economia de esforço, é que nenhum dos dois se prova com teste.

## 6. Critérios de aceite

Linguagem de produto. A prova executável de cada linha mora no DoD de fase, em `03_plan.md`.

| # | Uma pessoa consegue… |
|---|---|
| A1 | criar conta pelo app, sem ninguém abrir painel de banco de dados |
| A2 | recuperar a senha esquecida sozinha, digitando o código que chegou no e-mail |
| A3 | fechar o app e reiniciar o aparelho, e voltar sem digitar a senha de novo |
| A4 | abrir o menu lateral de qualquer tela de topo e chegar às Configurações |
| A5 | mudar o próprio nome e vê-lo no menu |
| A6 | trocar a senha informando a atual — e **não** conseguir trocar sem ela |
| A7 | salvar a própria chave de IA e nunca mais vê-la: só provedor, modelo e quatro dígitos |
| A8 | ver o chat apagado com o motivo antes de configurar a IA, e alcançável logo depois, sem navegar à mão |
| A9 | conectar um banco, distinguir os quatro estados por texto e desconectar com confirmação |
| A10 | ter certeza de que a conta ao lado não lê nada dela — provado com **duas** contas, não deduzido da política |

**A3 é critério de aceite e é a primeira medição da feature.** Pelo código, a sessão já deveria persistir: o app inicializa o Supabase com os defaults de sessão persistida e renovação automática, e não há tempo de inatividade configurado em nenhum ambiente. Se ela persistir, a caixinha "lembrar" sai do escopo **por escrito**; se não persistir, o passo exato em que ela cai vira tarefa nomeada. Implementar antes de medir é remédio para doença não diagnosticada — e o remédio que já existia numa branch guardava a senha da pessoa **em claro** no aparelho.

## 7. Fora de escopo (explícito)

| Não entra | Onde entra |
|---|---|
| O chat, os cards de confirmação, a interpretação de mensagem | feature 003 |
| **Conciliação**: casar lançamento do extrato com registro, categorizar em lote, matemática financeira | feature 005 |
| Painel de custo de IA, orçamento por categoria, escolher provedor por tipo de tarefa | feature 009 |
| **Troca de e-mail** | depende de SMTP e da decisão sobre confirmação automática de cadastro |
| Login social, dois fatores, biometria, PIN local | não é objetivo da v1 |
| Convite, papéis, permissões, compartilhamento entre contas | isolamento não é colaboração |
| Excluir a conta pela interface | o caminho existe no banco (apagar a conta leva a credencial e o segredo junto); a tela não |
| Recuperar senha clicando no link do e-mail | limitação conhecida: o e-mail traz o código, e é o código que a tela pede |
| **Sincronização automática do extrato** | só existe no ambiente pago do agregador (`https://docs.pluggy.ai/page/faq`, consultado em 19/08/2026); aqui o status é lido sob demanda, e conectar não é sincronizar |
| **Trazer a própria credencial do agregador bancário** (BYOK de banco) | avaliado e descartado com razão escrita em [`decisions.md`](decisions.md) (FD-019); a credencial é do projeto, e isso não reabre |
| **Importar extrato em OFX/CSV** | alternativa sem agregador, registrada em [`decisions.md`](decisions.md) (FD-021); entra se e quando o dono decidir não contratar plano pago |
| Mais seções de configuração (notificações, aparência, exportar dados) | a casca nasce ampliável; nenhuma delas entra agora |

## 8. Exceções e casos de borda

| Situação | Comportamento esperado |
|---|---|
| Cadastro com e-mail já existente | Mensagem própria, distinta de qualquer outra; o formulário preserva o que foi digitado |
| Senha nova fraca | Mensagem própria dizendo o que falta |
| Cadastro desligado no servidor | Mensagem própria ("cadastro fechado"), nunca erro genérico nem tela em branco |
| Recuperação pedida para e-mail inexistente | **Mesma** resposta do e-mail existente. Responder "essa conta não existe" entrega a lista de quem tem conta |
| Reenvio pedido cedo demais | Mensagem dizendo que é preciso esperar, distinta de "código errado" |
| Código de recuperação errado | Mensagem curta, campo preservado, o código continua válido para nova tentativa |
| Código expirado | Mensagem **distinta** de "código errado" — os dois modos de falha não podem parecer o mesmo |
| Código certo | A pessoa vai para o campo de **nova senha**. O código correto já entrega uma sessão válida; sem tratamento explícito, ela seria logada na home e nunca veria o campo |
| Senha atual errada na troca | Mensagem curta; os campos de senha nova e confirmação são preservados |
| Nova senha e confirmação diferentes | Envio bloqueado antes de sair do aparelho |
| Nome vazio | Envio bloqueado antes de sair do aparelho |
| Chave de IA recusada pelo provedor | Mensagem própria, e a credencial **não** fica marcada como configurada — meio-configurado é o estado que engana |
| Sem rede ao salvar a chave | Falha tipada, mensagem curta, o campo preserva o que foi digitado |
| Credencial de IA removida | O chat volta a apagado na hora, sem reinstalar nem relogar |
| Banco devolve erro de conexão | Estado próprio, com rótulo textual, distinto de "não conectado" |
| Provedor bancário fora do ar | Mensagem própria. Nunca tela "conectado" com lista vazia |
| Conta apagada | A credencial e o segredo cifrado dela morrem junto. Segredo órfão é cifrado e eterno |
| Aparelho destravado na mão de outra pessoa | A troca de senha pede a senha atual. É o que separa "usar o app" de "tomar a conta" |
| Duas contas no mesmo aparelho, uma depois da outra | Sair limpa a sessão; a segunda conta não vê nem a lista nem as configurações da primeira |

## 9. Analytics

**Nesta feature não sai evento nenhum.** Não existe SDK de analytics no projeto e o Firebase segue como decisão **P1**, pendente do humano. Registrar isso é honestidade de escopo, não esquecimento.

O que fica definido, para os nomes não nascerem ad hoc:

| Evento | Propriedades | Quando |
|---|---|---|
| `account_signup_submitted` | — | toque em criar conta |
| `account_signup_failed` | `error_code` | qualquer recusa do servidor |
| `password_recovery_requested` | — | pedido de código enviado |
| `password_recovery_completed` | `attempt_count` | senha trocada com sucesso |
| `settings_section_opened` | `section` | abertura de Conta, IA ou Banco |
| `ai_credential_saved` | `provider_kind`, `model` | chave aceita pelo servidor |
| `gated_destination_blocked` | `destination`, `missing_capability` | desvio do router num destino sem capacidade |
| `bank_connection_state_changed` | `status` | mudança de estado da conexão |

Nenhuma propriedade carrega e-mail, nome, chave, os quatro últimos dígitos ou identificador de conexão. O que se mede é o funil, não a pessoa.

## 10. Erros monitorados

Três classes precisam ser distinguíveis no log sem ler código:

1. **Recusa de credencial da pessoa** — senha errada, código errado, chave inválida. É o sistema funcionando; recorrente vira sinal de usabilidade, não de bug.
2. **Configuração de ambiente ausente** — sem SMTP, sem credencial do provedor bancário. Responde com "configuração ausente" e código próprio, **nunca** erro interno nem tela em branco. Recorrente significa ambiente mal provisionado, e é do humano.
3. **Falha inesperada** — a única que merece atenção. Identificador de outra conta chegando a um caminho de serviço é bug de autorização, não do banco.

Em nenhuma das três entra chave, senha, token, e-mail ou conteúdo de mensagem no log.

## 11. Dependências e riscos

- **SMTP virou bloqueio.** A pendência **P4** dizia "não bloqueia nada hoje"; com recuperação de senha no escopo, ela bloqueia. Provedor decidido: **Gmail com App Password** — o domínio é `supabase.ganza.bmjtech.duckdns.org`, e o DuckDNS não permite registro SPF/DKIM/DMARC, o que elimina Resend, Brevo, SES e Postmark. Criar a conta é do humano; o E2E não espera por ela, porque a stack local usa capturador de e-mail próprio.
- **Cadastro aberto com confirmação automática cria conta sem prova de posse do e-mail.** Qualquer endereço inventado vira conta confirmada. Decisão do humano: aceitar a dívida com o gatilho de pagamento escrito, ou desligar a confirmação automática — o que exige o SMTP **antes**.
- **A chave-mestra do cofre não está em volume no servidor.** Recriar o contêiner do banco transformaria todo segredo salvo em texto cifrado indecifrável. Consequência de produto: **nenhuma chave real de IA é salva em produção** enquanto isso não for resolvido; a feature inteira se desenvolve e se prova contra a stack local descartável.
- **As credenciais do provedor bancário são do projeto**, criadas em conta que só o humano abre. Bloqueiam a fase de banco do primeiro comando ao E2E, e o plano não tenta contornar com modo simulado: inventar um provedor falso custaria mais que esperar e provaria outra coisa. Pedir a credencial ao usuário não é saída: BYOK está descartado em [`decisions.md`](decisions.md) (FD-019).
- **O plano pessoal gratuito da Pluggy vale para contas nominais do titular** — a página do "Meu Pluggy" o condiciona a isso e a FAQ diz que uso comercial exige plano pago (`https://www.pluggy.ai/meu-pluggy`, consultado em 19/08/2026), o que confirma a ressalva de `docs/plano.md` §3. Abrir o app para outras pessoas **com integração bancária real** exige a conta do projeto: gratuita no ambiente de desenvolvimento (100 conexões, sem sincronização automática) ou paga a partir de R$ 2.500/mês (`https://www.pluggy.ai/precos`). É decisão comercial do humano, não técnica, e não bloqueia conectar contra a sandbox.
- **Uma pergunta contratual segue aberta.** Os termos de uso formais do provedor só existem em PDF (`https://www.pluggy.ai/legal`) e o texto não foi extraído: a leitura de que BYOK seria uso indevido do plano pessoal é **inferência do material comercial público, não citação de cláusula**. A pergunta a enviar por escrito está na pendência **P13** do plano. Ela não bloqueia esta feature — o desenho já é credencial do projeto.
- **O gate de IA protege hoje um destino sem tela.** O chat é a feature seguinte; se o gate não for exercitado agora, nasce inerte e quebra calado quando o chat chegar.
- **Risco de escopo.** A casca de Configurações convida a crescer — notificações, aparência, exportar dados, tema. A régua é o critério de aceite: três seções, e o chat acende.

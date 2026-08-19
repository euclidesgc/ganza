# Rodada 01 — E2E da listagem de transações (Fase 3 · T3.8)

Gerado por `docs/01-cadastro-manual/e2e_shots.sh` em 17/08/2026 02:01
— emulador `Pixel_8_Pro` (Android API 35,
fuso `America/Sao_Paulo`), build `--flavor prod` contra o Supabase de produção.
Nenhum print foi tirado à mão: o app é dirigido por `integration_test` e a
captura sai do driver.

O fuso do aparelho é parte da prova, não do ambiente: a lista formata a data
no fuso de quem lê. O script fixa `America/Sao_Paulo` no boot e **aborta** se não
conseguir — um print tirado num emulador em UTC não provaria o fuso.

**O atestado é do dev humano.** O QA gerou; quem confere as imagens é você.

## O que cada arquivo prova

| arquivo | o que prova |
| --- | --- |
| `01_erro_de_leitura.png` | Com a rede do emulador derrubada (`svc wifi/data disable`), a lista mostra ícone de erro, mensagem e o botão **Tentar de novo**. O teste também afirma que o texto do estado vazio **não** aparece aqui. |
| `02_estado_vazio.png` | Conta sem nenhuma transação (todas apagadas por id, ver `estado_inicial.json`): **"Nenhuma transação registrada."**, sem ilustração e sem entusiasmo. O teste afirma que **"Tentar de novo" não aparece**. |
| `01` + `02` juntos | Falha e vazio são telas **visivelmente diferentes** — o `prd.md` proíbe que um erro se disfarce de "nada aqui". Duas imagens, dois estados. |
| `03_lista_carregada.png` | Lista com as três linhas recriadas **pela Edge Function real** (`POST /functions/v1/transactions`, nunca por SQL). Prova quatro coisas na mesma imagem: **(a) fuso** — `Venda de sábado à noite` está guardada como `2026-08-16T01:30:00+00:00` (ver `linhas_semeadas.json`) e aparece como **`15/08, sábado`**, o dia que o usuário viveu às 22:30; formatada em UTC sairia `16/08, domingo`. **(b) entrada** — a mesma linha é `direction: "in"` e vem com **`+`** e a cor de entrada, ao lado de duas saídas em `−` e cor de saída. **(c) valor e data no formato do DoD** — `Almoço`, `14/08, sexta`, `−R$ 45,00` à direita, com o menos tipográfico (−, U+2212). **(d) volta** — a `AppBar` tem a seta de voltar para Áreas (rota empilhada por `pushNamed`). |
| `04_algarismos_tabulares.png` | **Recorte ampliado 2× da mesma captura de `03`** (não é outra tela), na coluna de valores: `+R$ 1.234.567,89` imediatamente acima de `−R$ 7,00`, e `−R$ 45,00` abaixo. O maior e o menor valor colados, com **sinais opostos**: é onde a coluna dançaria se a fonte não tivesse `FontFeature.tabularFigures()` (T3.2), e onde se vê se o `+` e o `−` ocupam a mesma largura. |
| `linhas_semeadas.json` | O que o banco guardou nesta rodada — `occurred_at` em UTC ao lado do que o print mostra. É por aqui que se confere o fuso sem abrir o Postgres. |
| `estado_inicial.json` | Fotografia da tabela **antes** de qualquer DELETE — os ids apagados estão aqui. |
| `logs/` | Saída completa de cada cena e do emulador. |
| `*.snapshot` | Cópia congelada dos scripts e do teste que produziram exatamente estas imagens. |

O DoD escreve a data como `15/08, sexta`: é a **forma** (`dd/MM, dia-da-semana`),
não o calendário — 15/08/2026 cai num sábado. A rodada mostra as duas metades
com datas reais, `15/08, sábado` e `14/08, sexta`.

## O que o olho tem de julgar (não vira asserção)

1. Os três valores terminam na **mesma vertical** e os algarismos têm a mesma
   largura entre linhas, com `+` e `−` alinhados (`04`).
2. A cor da entrada e a da saída se distinguem **sem depender de cor** — o
   `+`/`−` textual está lá — e nenhuma das duas some no fundo.
3. O vazio é **neutro** — nada de confete, ilustração ou convite animado.
4. O erro **parece** erro: cor, ícone e ação de saída visíveis.
5. A descrição fica em uma linha, com reticências se estourar.

## Achados desta rodada (não bloqueiam o DoD)

1. **Mensagem de erro genérica sem rede.** Em `01`, sem conexão nenhuma, o app
   diz "Algo deu errado. Tente de novo." em vez de algo como "Sem conexão".
   O estado está correto e distinto do vazio (que é o que o DoD exige), mas a
   mensagem não ajuda o usuário a agir.

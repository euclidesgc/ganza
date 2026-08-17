# Rodada 01 — E2E da listagem de transações (Fase 3 · T3.8)

Gerado por `docs/01-cadastro-manual/e2e_shots.sh` em 17/08/2026 01:22
— emulador `Pixel_8_Pro` (Android API 35),
build `--flavor prod` contra o Supabase de produção. Nenhum print foi tirado
à mão: o app é dirigido por `integration_test` e a captura sai do driver.

**O atestado é do dev humano.** O QA gerou; quem confere as imagens é você.

## O que cada arquivo prova

| arquivo | o que prova |
| --- | --- |
| `01_erro_de_leitura.png` | Com a rede do emulador derrubada (`svc wifi/data disable`), a lista mostra ícone de erro, mensagem e o botão **Tentar de novo**. O teste também afirma que o texto do estado vazio **não** aparece aqui. |
| `02_estado_vazio.png` | Conta sem nenhuma transação (todas apagadas por id, ver `estado_inicial.json`): **"Nenhuma transação registrada."**, sem ilustração e sem entusiasmo. O teste afirma que **"Tentar de novo" não aparece**. |
| `01` + `02` juntos | Falha e vazio são telas **visivelmente diferentes** — o `prd.md` proíbe que um erro se disfarce de "nada aqui". Duas imagens, dois estados. |
| `03_lista_carregada.png` | Lista com as três linhas recriadas **pela Edge Function real** (`POST /functions/v1/transactions`, nunca por SQL): descrição, data no formato `14/08, sexta` e valor `−R$ 45,00` alinhado à direita, com o menos tipográfico (−, U+2212). |
| `04_algarismos_tabulares.png` | **Recorte ampliado 2× da mesma captura de `03`** (não é outra tela), na coluna de valores: `−R$ 1.234.567,89` e `−R$ 7,00` em linhas vizinhas. É onde a coluna dançaria se a fonte não tivesse `FontFeature.tabularFigures()` (T3.2). |
| `estado_inicial.json` | Fotografia da tabela **antes** de qualquer DELETE — os ids apagados estão aqui. |
| `logs/` | Saída completa de cada cena e do emulador. |
| `*.snapshot` | Cópia congelada dos scripts e do teste que produziram exatamente estas imagens. |

## Sobre o `15/08, sexta` do DoD

O DoD cita `15/08, sexta` como **forma**, não como data: em 2026, 15/08 cai num
sábado, e uma data de 2025 sairia com ano (`15/08/2025, sexta`) pela própria
regra do formatador. A rodada cobre as duas metades da forma com datas reais:
`14/08, sexta` (dia de semana pedido) e `15/08, sábado` (dia do mês pedido).

## O que o olho tem de julgar (não vira asserção)

1. Os três valores terminam na **mesma vertical** e os algarismos têm a mesma
   largura entre linhas (`04`).
2. O vazio é **neutro** — nada de confete, ilustração ou convite animado.
3. O erro **parece** erro: cor, ícone e ação de saída visíveis.
4. A descrição fica em uma linha, com reticências se estourar.

## Achados desta rodada (não bloqueiam o DoD)

1. **Mensagem de erro genérica sem rede.** Em `01`, sem conexão nenhuma, o app
   diz "Algo deu errado. Tente de novo." em vez de algo como "Sem conexão".
   O estado está correto e distinto do vazio (que é o que o DoD exige), mas a
   mensagem não ajuda o usuário a agir.
2. **Sem volta para Áreas.** A `AppBar` de Transações não tem seta de voltar —
   a rota é alcançada por `context.goNamed` (troca de rota, não empilha), então
   não há pilha para o `AppBar` gerar o botão.

# Rodada 02 — E2E do registro pelo app (Fase 4 · T4.7)

Gerado por `docs/001_cadastro_manual/e2e_registro_shots.sh` em 19/08/2026 00:07
— emulador `Pixel_8_Pro` (Android API 35,
fuso `America/Sao_Paulo`), build `--flavor dev` contra o Supabase local.
Nenhum print foi tirado à mão e nenhuma linha desta rodada nasceu de `curl`:
o formulário é preenchido dígito a dígito e o botão **Registrar** é tocado pelo
executor Patrol, sem interação manual.

O fuso do aparelho é parte da prova: "ontem" só é ontem se o emulador vive no
mesmo fuso de quem calculou o esperado. O script fixa `America/Sao_Paulo` no boot e
**aborta** se não conseguir.

**O atestado é do dev humano.** O QA gerou; quem confere as imagens é você.

## O que cada arquivo prova

| arquivo | o que prova |
| --- | --- |
| `01_formulario_preenchido.png` | O formulário com **Despesa** (default, rótulo textual visível), **R$ 45,00** no campo de valor — digitado dígito a dígito, entrando pela direita —, **Almoço** na descrição e **17/08, segunda** (ontem) no seletor de data. O botão **Registrar** está habilitado; o teste afirma que ele estava **desabilitado** com o formulário vazio. |
| `02_lista_com_a_linha_nova.png` | Depois do toque em **Registrar**: o formulário saiu de cena e a lista foi **refeita pelo PostgREST** (não houve inserção local). A linha nova aparece **no topo**, acima de `Café` e `Venda da feira` — o teste compara as coordenadas verticais, não confia no olho. Valor `−R$ 45,00` e data `17/08, segunda`. |
| `03_sem_rede_campos_preservados.png` | Envio com saída para o Supabase local bloqueada por `iptables`. O formulário mostra **"Sem conexão com o servidor."** — a mensagem nova da T4.2; o teste afirma que **"Algo deu errado. Tente de novo." não aparece em lugar nenhum**. E os campos continuam preenchidos: o teste lê os `controller` do valor e da descrição e o rótulo da data **depois** do erro. |
| `04_sessao_expirada_login.png` | Sessão expirada → o app está **no login**, não numa mensagem de erro. O teste afirma a ausência de "Algo deu errado. Tente de novo." **e** de "Sua sessão expirou. Entre de novo." — não é um banner disfarçado, é outra tela. |
| `03` + `04` juntos | Os dois modos de falha em **estados visualmente distintos**: um mantém o formulário com tudo no lugar e uma mensagem curta; o outro troca de tela. |
| `05_botao_desabilitado_durante_envio.png` | Com o envio em voo, o botão vira **"Registrando…"** e o teste lê `onPressed == null` — desabilitado de fato, não só apagado. O print é tirado **entre** o primeiro e o segundo toque (latência `gprs` forçada no emulador para o estado durar o suficiente). |
| `06_formulario_abandonado.png` | Formulário inteiro preenchido e abandonado pelo botão de voltar, **sem** tocar em Registrar — o estado que a contagem abaixo prova não ter virado linha. |
| `linha_registrada.json` | A linha que **o app** gravou, lida pelo PostgREST logo após o print `02`. |
| `linhas_semeadas.json` | As duas linhas antigas plantadas pela Edge Function antes da rodada, para que a linha do app tenha com quem disputar o topo. |
| `estado_inicial.json` | Fotografia da tabela **antes** de qualquer DELETE — os ids apagados estão aqui. |
| `contagens.json` | Todos os `count(*)` antes/depois desta rodada, na ordem em que rodaram. |
| `logs/` | Saída completa de cada cena e do emulador. |
| `*.snapshot` | Cópia congelada dos scripts e do teste que produziram exatamente estas imagens. |

## A linha do banco, conferida e não assumida (decisão A1)

Equivalente ao `select amount, source, direction, user_id, area_id from
public.transactions order by created_at desc limit 1` do DoD, feito pelo
PostgREST com o JWT do dono logo após o print `02` (ver `linha_registrada.json`):

```json
{
  "amount": 4500,
  "source": "manual",
  "direction": "out",
  "user_id": "af4b6de0-42c2-4c56-8e1e-67b486a95239",
  "area_id": null,
  "description": "Almoço",
  "occurred_at": "2026-08-17T15:00:00+00:00",
  "reconciliation_status": "pending",
  "created_at": "2026-08-19T02:57:19.829439+00:00"
}
```

- `amount` é **4500**, inteiro — nunca `4499`, que é o que `double.parse('45,00') * 100` produziria.
- `source` é **manual**, `direction` é **out**, `user_id` é o da conta do dono.
- `area_id` é **nulo** — a decisão A1 (transação nasce sem área) verificada no banco.

## As contagens (`select count(*)`)

| momento | antes | depois |
| --- | --- | --- |
| formulário preenchido e **abandonado** (invariante nº 1) | 2 | 2 |
| caminho feliz (um toque em Registrar) | 2 | 3 |
| **toque duplo** no botão | 3 | 4 |
| envio **sem rede** | 4 | 4 |

Partida: 2 linhas (tabela esvaziada por id e semeada com duas linhas
antigas). Final: 4 linhas na conta do dono — 2 criadas
pelo app nesta rodada, para a limpeza manual da T5.1 (risco X6 do plano).

## Como a sessão expirada foi induzida

Com o formulário preenchido, o teste chama
`auth.setSession('refresh-token-invalidado-pelo-e2e', accessToken: <JWT com exp no passado>)`.
É o mesmo caminho que o cliente percorre sozinho quando o access token vence:
ele lê o `exp`, conclui que precisa renovar, pede a renovação ao GoTrue,
recebe **400**, apaga a sessão e emite `signedOut`. O `refreshListenable` do
`go_router` reavalia o `redirect` e leva ao `/entrar`. O JWT forjado tem
assinatura inválida de propósito — ele **nunca** vai ao servidor; quem vai é o
refresh token, e é a recusa dele que derruba a sessão.

## O que o olho tem de julgar (não vira asserção)

1. O formulário preenchido está **legível e na ordem do `02_specs.md` §6.1** —
   direção, valor, descrição, data — e o valor tem destaque tipográfico (`01`).
2. A mensagem de falha sem rede é **curta e cabe numa linha**, e o formulário
   continua parecendo um formulário, não uma tela de erro (`03`).
3. O login (`04`) não tem resíduo do formulário nem mensagem de erro pendurada.
4. O botão em voo (`05`) **parece** desabilitado — contraste e rótulo — e não
   apenas "sem cor".
5. A linha nova no topo (`02`) não empurrou o layout: valores continuam
   alinhados à direita, com algarismos tabulares.

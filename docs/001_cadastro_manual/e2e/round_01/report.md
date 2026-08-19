# Round 01 - Listagem de transações

## Contexto

Rodada histórica da feature 001. Ela foi executada contra o ambiente remoto
antes da adoção do harness local e está preservada apenas como evidência do
estado anterior. Não pode ser usada como prova para um novo PR.

## Evidências registradas

| Passo | Resultado registrado | Evidência |
| --- | --- | --- |
| Falha de leitura sem rede | A tela de erro é distinta do estado vazio. | [01_erro_de_leitura.png](01_erro_de_leitura.png) |
| Estado vazio | A lista mostra a mensagem neutra prevista. | [02_estado_vazio.png](02_estado_vazio.png) |
| Lista carregada | Data, direção, valor e navegação estão visíveis. | [03_lista_carregada.png](03_lista_carregada.png) |
| Alinhamento numérico | Valores usam algarismos tabulares. | [04_algarismos_tabulares.png](04_algarismos_tabulares.png) |

Os comandos, dados semeados e logs desta rodada estão nos snapshots e em
`logs/`. A próxima rodada válida deve ser gerada por `scripts/e2e-local.sh`.

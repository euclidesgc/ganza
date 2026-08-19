# Round 02 - E2E local da feature 001

## Contexto

Stack local descartável em `http://127.0.0.1:54321`; commit `a2f4fa4`.

## Passos executados

| Cenário | Expectativa | Resultado | Evidência |
| --- | --- | --- | --- |
| Erro de leitura | Estado de erro distinto do vazio | PASS | [PNG](01_erro_de_leitura.png) · [log](logs/listagem.log) |
| Estado vazio | Lista sem transações não se confunde com falha | PASS | [PNG](02_estado_vazio.png) · [log](logs/listagem.log) |
| Lista e RLS | Linhas do dono aparecem após leitura local | PASS | [PNG](03_lista_carregada.png) · [log](logs/listagem.log) |
| Abandono | Formulário sem Registrar não cria linha | PASS | [PNG](06_formulario_abandonado.png) · [log](logs/registro.log) |
| Criação pelo app | Registrar cria exatamente uma linha no topo | PASS | [PNG](02_lista_com_a_linha_nova.png) · [log](logs/registro.log) |
| Toque duplo | Dois toques criam uma única linha | PASS | [PNG](05_botao_desabilitado_durante_envio.png) · [log](logs/registro.log) |
| Falha de rede | Campos permanecem e nada é gravado | PASS | [PNG](03_sem_rede_campos_preservados.png) · [log](logs/registro.log) |
| Sessão expirada | Sessão inválida retorna ao login | PASS | [PNG](04_sessao_expirada_login.png) · [log](logs/registro.log) |

## Ambiente e comandos

- Stack local descartável: `http://127.0.0.1:54321`
- `scripts/e2e-emulator.sh start|cleanup` controla exclusivamente o AVD desta rodada.
- `scripts/local-supabase.sh reset`
- `docs/001_cadastro_manual/e2e_shots.sh`
- `docs/001_cadastro_manual/e2e_registro_shots.sh`

Logs e ressalvas ficam em [`logs/`](logs/). Não são gravados vídeos.

# 006 - Recursos multimodais · PRD

A porta de entrada por voz: você fala, o sistema **transcreve** e o texto entra
no mesmo pipeline de interpretação do chat — nada muda na confirmação obrigatória
(`docs/plano.md` §6.11). A transcrição é um `task_type` **separado** da extração
(FD-001): quando errar, é preciso saber qual etapa falhou.

## 1. Resultado esperado

A pessoa grava um áudio ("gastei 45 no almoço ontem"); o sistema transcreve,
passa o texto pelo `/ingest` e devolve a mesma **lista de cards de confirmação**
do chat. Nada grava sem confirmar.

## 2. Fronteira: o que a IA interpreta e o que o código decide

| A IA interpreta | O código decide |
|---|---|
| O áudio → texto (transcrição, `transcribe_audio`) | O envelope, o conjunto fechado de `kind`/campos, a confirmação |
| O texto → registros (extração, `extract_record`) | Nada mais — a transcrição e a extração são etapas separadas |

## 3. Caminho feliz

1. Pessoa grava o áudio.
2. `/transcribe` chama `transcribe_audio` (Gemini, áudio inline) → texto, grava a
   `message` (`media_type='audio'`, `transcript`, `origin='transcript'`).
3. O app chama `/ingest` com o texto transcrito.
4. Extração devolve lista; cards em sequência; confirmar grava, cancelar não.

## 4. Exceções e casos de borda

- **Áudio sem fala** → transcrição vazia → resposta "não entendi o áudio", sem gravar.
- **Áudio grande demais** → recusado na borda (teto de bytes), antes de qualquer chamada.

## 5. O que esta feature **não** entrega primeiro

- **Foto como anexo** e **`attach`** (vincular a registro existente) — ficam para
  uma fase posterior (registrado no `changes.md`).

## 6. Invariantes que o DoD cobra

1. **Transcrição e extração são `task_type` separados** (FD-001) — duas chamadas
   de IA, cada uma com `ai_usage` próprio.
2. **Nada grava sem confirmação** — o áudio vira proposta, nunca registro.
3. **Nenhuma credencial no cliente** — a chave de IA fica no Vault; o app só fala
   com o Supabase.

## 7. Dependências e riscos

- **Depende** da 003 (chat/`/ingest`/cards) e da 002 (IA no Vault, `ai_routes`).
- **Risco**: transcrição errada → vira proposta errada, mas **só depois de
  confirmada** (a invariante nº 1 protege).
- **Risco**: custo do áudio no tier gratuito → `assertWithinLimits` + teto de bytes.

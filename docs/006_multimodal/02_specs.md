# 006 - Recursos multimodais · Specs

Âncoras e contratos. O "o quê" está no [`01_prd.md`](01_prd.md); o fatiamento,
no [`03_plan.md`](03_plan.md).

## 1. O que já existe e se reutiliza

- **`ai_routes`** já tem o `task_type` `transcribe_audio` (migration 0011); a
  camada `_shared/ai/execute.ts` resolve rota/provedor e lê o segredo do Vault.
- **`messages`** já tem `media_path`, `media_type`, `transcript` e `origin`
  (`'transcript'` incluso).
- **`/ingest`** (003) já faz a extração e devolve os cards — a transcrição só
  precisa alimentá-lo.

## 2. Contrato do `/transcribe`

```
POST /functions/v1/transcribe
Authorization: Bearer <jwt>
{ "audio_base64": "string", "mime_type": "audio/mp4" }
→ 200 { "transcript": "string", "message_id": "uuid" }
```

- Valida na borda: `audio_base64` presente e ≤ teto de bytes; `mime_type` em um
  conjunto fechado (`audio/mp4`, `audio/mpeg`, `audio/wav`, `audio/webm`,
  `audio/ogg`, `audio/flac`).
- Chama `transcribe_audio` (Gemini, áudio **inline** via `inline_data`).
- Grava a `message` (`role='user'`, `origin='transcript'`, `media_type='audio'`,
  `transcript`, `content=''`) e o `ai_usage` da transcrição.

## 3. Fluxo de dados

```
áudio → /transcribe → transcribe_audio → texto → messages (transcript)
texto → /ingest → extract_record → parseProposals → proposed_actions → cards
```

Duas chamadas de IA, dois `task_type`, dois `ai_usage` (FD-001).

## 4. Invariantes que o DoD cobra

1. A transcrição **não** grava em `proposed_actions` nem em `transactions` — só
   em `messages` (com `transcript`); a extração/confirmação segue o fluxo da 003.
2. A transcrição é um `task_type` separado (FD-001).
3. Áudio inválido/fora do conjunto fechado é recusado na borda.

# Resumo do Harness Gauntlet

## Entregas

- Backlog canônico em `docs/roadmap.md`, com uma pasta numerada por feature.
- Documentação por feature: PRD, specs, plano, decisões, mudanças e evidências E2E.
- Orquestração Gauntlet nos agentes e skills, com críticos independentes, rubricas binárias, limite de rodadas e dossiê de escalonamento.
- Stack Supabase local descartável compatível com HML, comandos de ciclo de vida e bloqueio explícito de hosts remotos nos roteiros E2E.
- E2E Flutter exclusivamente com Patrol, PNGs e logs; vídeos não são gerados.
- Controle de emulador por PID e serial, além de timeout por cenário. Cada cenário é iniciado em grupo de processo próprio para que o `trap` encerre seus filhos de teste.
- `scripts/verify-gauntlet.sh` integrado aos gates para conferir documentação, provas e referências de evidência.

## Validação executada

- `flutter analyze`: aprovado.
- `flutter test -r compact`: aprovado, 25 testes.
- `scripts/verify-gauntlet.sh`: aprovado.
- Sintaxe dos scripts do harness: aprovada.
- E2E local de listagem com Patrol: aprovado durante a validação, cobrindo RLS, erro de leitura, vazio, lista carregada e PNGs.

## Ressalva de E2E

A rodada completa do registro não foi preservada como evidência: depois da listagem aprovada, o runner Android do Patrol ficou sem emitir o resultado do primeiro cenário de registro em uma repetição. Os recursos locais foram encerrados e a rodada incompleta foi removida para não parecer aprovada.

Não houve merge para `develop`. O gate de E2E completo deve passar em uma nova rodada antes do merge, conforme o próprio Gauntlet exige.

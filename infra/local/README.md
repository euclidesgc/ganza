# Stack local

Esta composição reproduz as imagens da HML para desenvolvimento e E2E. Use
`scripts/local-supabase.sh reset` para um banco descartável com migrations e
usuário de teste, e `scripts/local-supabase.sh down` para remover todos os
containers e volumes locais.

Portas: Kong `54321`, Postgres `54322` e Studio `54323`.

O Studio usa `2026.03.16-sha-5528817`: a tag curta `2026.03.16` documentada
na HML não existe no registry do Studio. Os demais serviços mantêm exatamente
as tags da HML.

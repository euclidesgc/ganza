# Stack local

Esta composição reproduz as imagens da HML para desenvolvimento e E2E. Use
`scripts/local-supabase.sh reset` para um banco descartável com migrations e
usuário de teste, e `scripts/local-supabase.sh down` para remover todos os
containers e volumes locais.

Portas: Kong `54321`, Postgres `54322`, Studio `54323` e Mailpit `54325`.

O Studio usa `2026.03.16-sha-5528817`: a tag curta `2026.03.16` documentada
na HML não existe no registry do Studio. Os demais serviços que têm
contraparte na HML mantêm exatamente as mesmas tags. O `mail` é exceção: não
existe na HML — lá o `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS` apontam para um
provedor real (`docs/deploy/coolify.md`), aqui existe só para capturar
e-mail sem depender de SMTP nenhum.

## E-mail local (Mailpit)

`GOTRUE_MAILER_AUTOCONFIRM` é `'false'`: cadastro e recuperação de senha
exigem o código enviado por e-mail, como em produção. O serviço `mail`
(`axllent/mailpit`) captura tudo que o GoTrue envia — nada sai para um SMTP
real. A imagem é multi-arch (`amd64`/`arm64`), então serve tanto a máquina
de desenvolvimento quanto a VPS ARM sem troca de tag. Caixa de entrada:
http://127.0.0.1:54325.

Ler a última mensagem capturada (o código de recuperação/confirmação vem na
linha "Alternatively, enter the code: XXXXXX" do corpo):

```sh
curl -s "http://127.0.0.1:54325/api/v1/message/$(curl -s 'http://127.0.0.1:54325/api/v1/messages?limit=1' | jq -r '.messages[0].ID')" | jq -r '.Text'
```

# GitFlow — padrão de branches do ganza

Segue o **GitFlow** (modelo de Vincent Driessen), com a variante prática **feature / bugfix / hotfix**. Este documento é a **fonte da verdade** sobre branches — para o humano e para os agentes.

---

## 1. Branches permanentes

| Branch | Papel | Regras |
|---|---|---|
| **`main`** | Produção. Cada commit é uma versão entregue (tag `vX.Y.Z`). | **PROTEGIDA.** Nunca recebe push direto nem trabalho de agente. Só merges de `release/*` e `hotfix/*`. |
| **`develop`** | Integração. Reflete o próximo release. | Branch **base** de todo o trabalho. Só recebe features/bugfixes **completos**, sempre via PR. Sem push direto. |

> Regra de ouro: **ninguém comita direto em `main` ou `develop`.** Todo trabalho nasce num branch de suporte e volta por Pull Request.

---

## 2. Branches de suporte (temporários)

| Tipo | Nasce de | Volta para | Naming | Uso |
|---|---|---|---|---|
| **`feature/*`** | `develop` | `develop` | `feature/<issue>-<slug>` | Funcionalidade nova. **Default.** |
| **`bugfix/*`** | `develop` | `develop` | `bugfix/<issue>-<slug>` | Bug encontrado **em desenvolvimento**. |
| **`hotfix/*`** | **`main`** | `main` **e** `develop` | `hotfix/<issue>-<slug>` | Bug **em produção**. Sobe PATCH. Início é decisão humana. |
| **`release/*`** | `develop` | `main` **e** `develop` | `release/<vX.Y.Z>` | Estabilização. Sobe MINOR, **sem feature nova**. Conduzido por humano. |

- Merges de volta para `main`/`develop` usam **`--no-ff`**.
- Ao fechar `release/*` ou `hotfix/*`: merge em `main`, **cria-se a tag**, e merge de volta em `develop`. Havendo `release/*` aberto, o `hotfix/*` é integrado nele em vez de `develop`.
- Branches de suporte são **deletados** após o merge.

---

## 3. Fluxo visual

```
  hotfix/*  ──────────────┐ (sai de main)
                          v
main  ●─────────────────────●──────────────●   (tags vX.Y.Z; protegida)
       \                   ^                ^
        \           release/* (estabiliza)  │
         \               ^                  │
develop   ●──●──●──●──●───●──────●──●──●─────●   (integração)
              ^     ^            ^     ^
        feature/*  bugfix/*  feature/*  (saem e voltam para develop, via PR)
```

---

## 4. Ambientes — e por que `hml` ainda não existe

O GitFlow acima é o destino. **A infraestrutura chega nele por etapas**, e a etapa atual é deliberadamente menor:

| Etapa | Remoto | Local | Quando |
|---|---|---|---|
| **Agora** | só **produção** (`main`) | Supabase em Docker: é onde a migration é testada e o E2E roda | até a Fase 2 |
| **Depois** | + **homologação** (`develop` → `hml.`) | idem | quando a falta doer |

O motivo é concreto: cada ambiente remoto é uma stack Supabase inteira numa VPS de **2 vCPU compartilhada com outros dois projetos**. Duplicar isso para um app de um usuário só é custo sem retorno enquanto o local dá conta.

**A consequência prática:** onde as skills de GitFlow dizem "valide em homologação", leia "valide no ambiente local" enquanto `hml` não existir. O merge em `develop` continua obrigatório — o que muda é só onde se olha o resultado.

Quando o `hml` nascer, ele entra sob `hml.ganza.duckdns.org` / `api-hml.ganza.duckdns.org` — a mesma convenção do driva e do love-secret no mesmo servidor.

---

## 5. Regras operacionais para os agentes

1. Trabalhe **somente** no branch da sua tarefa. Confira com `git rev-parse --abbrev-ref HEAD`.
2. **Nunca** `git commit`/`git push` direto em `main` ou `develop`.
3. PR com a base correta: `feature/*` e `bugfix/*` → **`develop`**; `hotfix/*` → **`main`** (e merge de volta em `develop`).
4. Antes de abrir/atualizar o PR, traga a base (`git merge --no-edit origin/develop`) para o diff ficar atual.
5. Merges `develop → main` (releases) e a criação de `hotfix/*` são **decisão humana**, salvo instrução explícita.
6. **Migration vai em PR separado, e primeiro** — nunca no mesmo PR que UI. É a única peça irreversível em produção.
7. **Mais de um PR aberto ao mesmo tempo vai em pilha** — nunca vários PRs independentes contra `develop`. Ver seção 6.

---

## 6. Pilha de PRs (stacked pull requests)

Quando um trabalho rende **mais de um PR simultâneo**, eles vão numa **pilha**, com o recurso nativo do GitHub. A skill **`empilhar-prs`** tem o passo a passo; aqui ficam a regra e o porquê.

**A regra:** nunca abra N PRs independentes contra `develop`. Encadeie as branches (cada uma nasce da anterior) e publique a pilha.

**Dois motivos:**

1. **Um build por pilha, não um por PR.** Cada PR independente dispara o CI inteiro. A pilha mergeia o PR escolhido **e todos os não-mergeados abaixo dele** numa operação só.
2. **O merge para de ser manual e frágil.** Na pilha nativa, o próximo PR é rebaseado automaticamente quando o de baixo entra.

**A armadilha, herdada de duas mordidas no driva.** O filtro `on.pull_request.branches` do `ci.yml` precisa cobrir **todo prefixo que pode virar base de pilha**, não só os do GitFlow. Lá, um PR do meio da pilha passou sem CI porque a base era `docs/**` e o prefixo não estava na lista — e o auto-deploy do Coolify dispara no push **sem consultar o CI**. Prefixo novo em uso como base ⇒ **entra no filtro no mesmo PR**.

**Restrições do recurso:** sem auto-merge, não dá para mergear um PR do meio isoladamente, e a pilha exige histórico linear.

---
name: criar-modulo
description: Cria um módulo novo no app do ganza seguindo o gabarito de Clean Architecture do CLAUDE.md. Use ao iniciar qualquer módulo/feature nova no app Flutter.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Skill: criar um módulo novo

Objetivo: criar um módulo seguindo o gabarito do `CLAUDE.md`. Na dúvida, imite o módulo já existente mais parecido.

Passos:

1. Crie `app/lib/modules/<nome>_module/` com `domain/`, `data/`, `presentation/`.
2. **Domain**: entidade (`Equatable`, imutável, sem `fromMap`), contrato `abstract interface class` devolvendo `Either<Failure, T>` (fpdart), e **um use case por operação** com método `call()` (mesmo o passa-fica). Dinheiro é inteiro em centavos; estado terminal é enum fechado; data é `DateTime` absoluto.
3. **Data**: model com (de)serialização validada por **zard** (`safeParse` → Either), impl atrás do contrato. O único `try/catch` mora aqui, traduzindo `PostgrestException`/`AuthException`/`StorageException`/`DioException` → `Failure` tipada. **Escolha da fonte:** leitura e escrita trivial vão por `supabase_flutter`; escrita que exige lógica (interpretar, categorizar, calcular, conciliar, sincronizar) vai pelo backend. Chamar IA ou Pluggy direto do app não é opção.
4. **Presentation**: cubit com estado `sealed` (via `part of`) + `switch` exaustivo, guarda `isClosed` após `await`; página `StatelessWidget` com `static Widget pageBuilder` (o único lugar que toca o get_it). **Widgets**: cada pedaço é um widget próprio (dados pelo construtor — **nunca** `Widget _buildX()`), uma classe por arquivo; específico da feature em `presentation/<feature>/widgets/`, usado por várias features do módulo em `presentation/widgets/`, genérico da app em `core/widgets/`. **Estilo** vem de `core/theme/` (token/`Theme.of`) — zero hardcode.
5. Fiação: `<nome>_routes.dart` (classe `XRoutes`, rotas nomeadas), `<nome>_injection.dart` (`registerXModule(GetIt)`: repositório lazySingleton, use cases factory), e o barrel público `<nome>_module.dart` que exporta **só** esses dois. Cada pasta termina com seu barrel; os de `data/` são internos.
6. Registre no `injection.dart` e no `app_router.dart` da raiz (que só importam o barrel público).
7. Rode `flutter analyze`. Não dê por pronto com lint vermelho.

Se o módulo precisa de tabela nova, a **migration vem antes e em PR separado** (skill `criar-migration`).

Regras inegociáveis (o `CLAUDE.md`, o lint e o `gates_guard.sh` cobram):

- presentation NUNCA importa data.
- nenhuma classe de lógica chama o service locator por dentro (só o `pageBuilder`).
- estado imutável; cor não carrega informação sozinha (acessibilidade); alvo de toque grande.
- zero build_runner.
- zero função-retorna-widget; uma classe/widget por arquivo; widget no tier certo; zero estilo hardcoded.
- **nada grava registro sem confirmação explícita** — se o módulo cria dado a partir do chat, o caminho passa por `proposed_actions`.

# Bússola — notas para quem trabalha neste repositório

App iOS de organização pessoal. Português de Portugal em todo o lado: nomes de
tipos, comentários, interface e mensagens de commit.

## Construir

Os testes não precisam de XcodeGen nem de Homebrew:

```bash
swift test --package-path Packages/BussolaCore
```

Para o projecto Xcode (o `.xcodeproj` não está no repositório, por desenho):

```bash
export DEVELOPMENT_TEAM=XXXXXXXXXX
xcodegen generate
```

Sem Homebrew, o XcodeGen instala-se pelo binário pré-compilado — ver
`docs/09-primeiro-arranque-no-mac.md`.

Sem toolchain Swift à mão, `./Tools/verificar.sh` corre três verificações que
apanham erros de compilação sem compilador:

| Ferramenta | Apanha |
|---|---|
| `verificar_estrutura.py` | Chavetas, parênteses e aspas desequilibradas |
| `verificar_referencias.py` | Chamadas cujos argumentos não batem com a declaração |
| `verificar_imports.py` | Imports em falta entre módulos |

Nenhuma sabe nada de tipos, genéricos, overloads ou protocolos. Passar não
significa que compila — significa que não falha por estas três razões.

## Este código nunca foi compilado

Foi escrito num container Linux sem Xcode nem toolchain Swift. As três
verificações acima passam, mas não substituem um compilador. Se estás a ler isto
numa sessão com Xcode à mão, o primeiro trabalho útil é `swift test` — ver
`docs/10-continuar-no-mac-com-claude.md`.

## Arquitectura, em três regras

1. **`BussolaDomain` não importa frameworks.** Sem SwiftData, SwiftUI, EventKit
   ou FoundationModels. É por isso que os invariantes se testam em milissegundos.
   Se uma regra precisa de um framework para ser testada, está na camada errada.
2. **As camadas de I/O não decidem nada.** `RemindersBridge` executa as acções que
   o `ReminderReconciler` produziu; `BussolaStore` traduz; `FoundationModelsTriager`
   propõe. A decisão vive sempre no domínio.
3. **MV, não MVVM.** `@Observable` já é o padrão observável. Vistas que recebem o
   modelo usam `let`, não `@State` — `@State` recria o valor a cada reconstrução
   da vista-mãe.

## Invariantes que não se relaxam

| Regra | Onde | Porquê |
|---|---|---|
| Máximo 1 Rocha + 3 Pedras | `DayPlanBuilder` | Um limite que se pode ultrapassar não resolve um problema de compromisso |
| Nunca as 3 Pedras da mesma área | `DayPlanBuilder` | Sem isto o trabalho engole tudo e Obras e Família apagam-se |
| Sem âncora o plano não fecha | `DayPlanBuilder.construir()` | É o passo com melhor evidência por trás |
| A captura nunca pede metadados | `CapturarView` | Cada campo reduz a taxa de captura de forma desproporcionada |
| A IA propõe, o humano decide | `TriageSuggestion` | Uma app que arquiva sozinha perde-se ao primeiro erro |
| A sincronização nunca apaga tarefas | `SyncAction.desligarEspelho` | Apagar dados do utilizador por causa de um sync é a pior falha possível |

## Armadilhas conhecidas

- **Esquema CloudKit**: toda a propriedade nova num `@Model` precisa de valor por
  omissão ou de ser opcional, e as relações têm de ser opcionais e sem unicidade.
  Violar isto faz o sync falhar **em silêncio**.
- **`calendarItemIdentifier`** do EventKit só é estável depois do `commit()`.
  Lê-se no fim, nunca logo a seguir ao `save`.
- **Escrita local muda `updatedAt`** (`TaskItem.tocar()`), senão a ponte com os
  Lembretes não vê a alteração e o last-write-wins decide mal.
- **O spool só se apaga depois do `save()`.** Apagar antes perde capturas quando
  a gravação falha.
- **Widgets não montam `ModelContainer`.** Lêem `InstantaneoDoDia` do App Group.

## Convenções

- Comentários explicam **porquê**, não o quê. Se o comentário repete o código, sai.
- Nomes de teste são frases que descrevem o comportamento, não `testFoo()`.
- Swift Testing (`@Test`, `#expect`), não XCTest.
- Mensagens de erro dizem o que aconteceu e o que fazer. Nada de "algo correu mal".

## Decisões já tomadas — não reabrir sem razão nova

Estão em `docs/06-decisoes-adr.md`, com o que se rejeitou e porquê. As mais
prováveis de serem reabertas por engano:

- **ADR-002**: a Família vai pelos Lembretes, não por CKShare. SwiftData não
  suporta base de dados partilhada, e a esposa não instalaria uma app sideloaded.
- **ADR-004**: cinco áreas fixas em código. Criar áreas é fugir ao trabalho de decidir.
- **ADR-006**: não há ecrã de "todas as tarefas". É deliberado.
- **ADR-008**: tesouraria fica para a v2. A v1 cobre só a dimensão temporal do financeiro.

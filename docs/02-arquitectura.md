# 02 — Arquitectura técnica

## 1. Stack

| Camada | Escolha | Porquê |
|---|---|---|
| UI | SwiftUI, iOS 26+ | Alvo único (o teu iPhone). Sem compatibilidade retroactiva a pagar. |
| Linguagem | Swift 6, concorrência estrita | Erros de threading em compilação, não em produção |
| Persistência | **SwiftData** (base privada) | [Recomendação da Apple para apps novas](https://vburojevic.dev/blog/cloudkit-sync-swiftdata/): `@Model` + `ModelConfiguration` com CloudKit espelha para iCloud sem código de sync |
| Sincronização | CloudKit **private database** | Grátis, offline-first, sem servidor a manter |
| Partilha família | **EventKit → Lembretes da Apple** | Ver ADR-002. Decisão crítica. |
| IA | **Foundation Models** (on-device) | LLM ~3B local, grátis, offline, dados não saem do dispositivo |
| Captura | App Intents + WidgetKit + Speech | Botão de Acção, Siri, ecrã bloqueado, Centro de Controlo |
| Calendário | EventKit (leitura) | Capacidade real do dia, não estimada |
| Agendamento | BGTaskScheduler + UNUserNotificationCenter | Pré-computar o plano antes da notificação das 21h |

## 2. A restrição que moldou a arquitectura

**SwiftData não suporta a base de dados partilhada do CloudKit.** A framework, incluindo a API `DataStore`, não oferece suporte a `CKShare`; a alternativa oficial é `NSPersistentCloudKitContainer` (Core Data), e em iOS 26 há ainda [problemas documentados](https://developer.apple.com/forums/thread/788427) — os URLs de partilha não abrem apps de terceiros e `CKShareRequestAccessOperation` está presente no SDK mas não funcional.

Três caminhos foram avaliados:

| Opção | Custo | Veredicto |
|---|---|---|
| Core Data + `NSPersistentCloudKitContainer` | Suporta partilha, mas é 3–4× mais código e uma API mal documentada para este padrão | ❌ Paga-se um imposto arquitectural permanente por uma funcionalidade periférica |
| Sync próprio sobre `CKSyncEngine` | Controlo total | ❌ Semanas de trabalho e uma classe inteira de bugs novos |
| **Ponte EventKit → Lembretes** | Nenhum sync a escrever | ✅ **Escolhida** |

E há um argumento que fecha a discussão antes do argumento técnico:

> **A tua esposa não vai instalar uma app compilada em Xcode com um perfil de developer que caduca de 7 em 7 dias.**

Ela já tem os Lembretes no iPhone dela. Uma lista partilhada dos Lembretes funciona hoje, sem instalação, sem conta, sem manutenção. A Bússola lê e escreve nessa lista via EventKit: as tarefas de Família aparecem no plano diário e o que ela adiciona chega à tua Inbox.

**A partilha é um problema resolvido pela Apple. Resolvê-lo outra vez é vaidade de engenharia.**

## 3. Módulos (Swift Package Manager, pacote local)

```
Bussola.xcodeproj
└── Packages/BussolaCore/
    ├── Sources/
    │   ├── Domain/          modelos, invariantes, regras — zero dependências, 100% testável
    │   ├── Persistence/     SwiftData: contentor, migrações, queries
    │   ├── CaptureKit/      App Intents, transcrição, escrita na Inbox
    │   ├── TriageKit/       Foundation Models: @Generable + fallback determinístico
    │   ├── PlannerKit/      cálculo de capacidade, proposta de Rocha/Pedras, rotação de áreas
    │   ├── ReviewKit/       rituais diário e semanal, termómetro de áreas
    │   ├── BridgeKit/       EventKit: calendário (leitura) + Lembretes (leitura/escrita)
    │   └── DesignSystem/    tokens, componentes, acessibilidade
    └── Tests/               Swift Testing
Targets:
├── Bussola               app principal
├── BussolaWidgets        WidgetKit + Live Activity
└── BussolaIntents        App Intents (Botão de Acção / Siri / Atalhos)
```

**`Domain` não importa SwiftData, SwiftUI nem EventKit.** É Swift puro. As regras de negócio — "3 Pedras no máximo", "não podem ser todas da mesma área", "uma tarefa sem próxima acção é um defeito" — testam-se em milissegundos, sem simulador e sem iCloud.

### Padrão de UI: MV, não MVVM

SwiftUI com `@Observable` já é o padrão observável. Uma camada de ViewModels por ecrã acrescenta cerimónia sem acrescentar testabilidade — os testes vivem no `Domain`. As vistas falam com serviços `@Observable` injectados via `@Environment`.

## 4. Captura: o caminho crítico

Este é o percurso mais importante da app. **Orçamento: < 2 segundos entre a intenção e o registo garantido.**

```
Botão de Acção  ─┐
Siri            ─┤
Widget bloqueio ─┼──► CaptureIntent (App Intent, executa fora do processo da app)
Centro Controlo ─┤         │
Partilhar       ─┘         ▼
                    grava áudio + SFSpeechRecognizer (on-device)
                           │
                           ▼
                    Capture(texto, áudio, timestamp, localização?)
                           │
                           ▼
                    App Group ── escrita atómica no ficheiro ──► Inbox
                                                                   │
                                            (a app, quando abrir)  ▼
                                                          SwiftData + CloudKit
```

Quatro decisões que sustentam o orçamento de 2 segundos:

- **`Button(intent:)` executa sem abrir a app** — o widget grava directamente
- **O áudio original guarda-se sempre**, mesmo com transcrição bem-sucedida. Transcrição de português com ruído de obra falha; o áudio é a rede de segurança e ouve-se na triagem
- **Escrita primeiro no App Group, sync depois.** Se o CloudKit estiver indisponível, a captura não pode falhar. Nunca.
- **Sem UI de confirmação.** Um háptico e acabou. Um alerta de "guardado!" custa 800 ms e não acrescenta informação

## 5. Triagem com IA local

[Foundation Models](https://developer.apple.com/videos/play/wwdc2025/286/) dá acesso ao modelo de ~3B parâmetros do Apple Intelligence a partir de Swift. A funcionalidade que interessa é **guided generation**: com `@Generable`, o modelo devolve um tipo Swift preenchido e verificado, não uma string para parsear.

```swift
@Generable
struct TriageSuggestion {
    @Guide(description: "Reescreve como acção concreta começada por verbo no infinitivo")
    var actionTitle: String

    @Guide(description: "A área a que pertence")
    var area: AreaSuggestion            // enum @Generable — o modelo não pode inventar áreas

    @Guide(description: "Tipo: acção própria, espera por terceiro, referência ou lixo")
    var kind: ItemKind

    @Guide(description: "Nome da pessoa de quem se espera, se kind == .waitingFor")
    var waitingOn: String?

    @Guide(description: "Minutos estimados: 5, 15, 30, 60 ou 90")
    var estimatedMinutes: Int

    @Guide(description: "Data mencionada no texto, formato ISO-8601. Nunca inventar.")
    var dueDate: String?

    @Guide(description: "0 a 100. Abaixo de 60 o item vai para revisão manual.")
    var confidence: Int
}
```

**Três salvaguardas obrigatórias:**

1. **A IA propõe, nunca decide.** Toda a sugestão passa pelo teu polegar na triagem. Um sistema em que a IA arquiva sozinha é um sistema em que se deixa de confiar ao primeiro erro — e a confiança é o activo que se está a construir.
2. **Degradação para regras determinísticas.** Se o Apple Intelligence não estiver disponível (dispositivo, região ou idioma), um classificador de palavras-chave e datas assume o lugar. A app funciona sempre; só perde qualidade de proposta.
3. **`confidence` calibra o gesto.** Acima de 80, swipe simples aceita. Abaixo de 60, o item abre para edição. A app pede atenção só quando é preciso — que é o que a torna suportável.

> Nota de idioma: o modelo local suporta português, mas a qualidade em pt-PT com vocabulário de obra e fiscalidade é uma incógnita até se medir. A [Fase 2](05-roadmap.md) inclui um conjunto de 50 capturas reais para avaliar a taxa de acerto. Se ficar abaixo de 70%, o plano B está em [ADR-007](06-decisoes-adr.md).

## 6. Ponte EventKit

**Calendário (só leitura).** A capacidade do dia é calculada a partir dos eventos reais, não de uma estimativa. Se amanhã tens quatro horas de reuniões, o planeador propõe uma Rocha mais curta ou nenhuma. Um planeador que ignora o calendário mente, e um planeador que mente deixa de se usar.

**Lembretes (leitura e escrita).** Lista partilhada "Família" mapeada bidireccionalmente:

| Lembretes | Bússola |
|---|---|
| Título | `Task.title` |
| Notas | `Task.notes` |
| Data de vencimento | `Task.dueDate` |
| Prioridade | `Task.priority` |
| Concluído | `Task.status` |
| Identificador externo | `Task.externalID` — chave de reconciliação |

Sincronização a cada abertura da app e no ritual das 21h. Reconciliação por `externalID` com **last-write-wins** — não vale a pena resolver conflitos numa lista de compras partilhada entre duas pessoas.

## 7. Privacidade e resiliência

- **Nada sai do dispositivo excepto para o teu iCloud privado.** Sem backend, sem analytics, sem terceiros. Não é postura ideológica: dados financeiros da empresa e informação da tua filha não pertencem ao servidor de ninguém.
- **A app funciona por completo offline.** SwiftData é local; o CloudKit é replicação, não dependência.
- **Exportação em JSON e Markdown**, um toque, para Ficheiros. Não vais ficar refém do teu próprio código daqui a três anos.
- **Regra de esquema CloudKit:** toda a propriedade precisa de valor por omissão ou de ser opcional, e todas as relações têm de ser opcionais e sem restrições de unicidade. Violar isto faz o sync falhar em silêncio, que é a pior falha possível. Um ecrã de diagnóstico oculto mostra o estado do sync e a data da última sincronização.

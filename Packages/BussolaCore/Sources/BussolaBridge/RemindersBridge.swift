import Foundation
import BussolaDomain

#if canImport(EventKit)
import EventKit
#endif

/// A ponte para a lista partilhada dos Lembretes.
///
/// É assim que a área Família é partilhada com a esposa sem ela instalar nada.
/// A partilha é um problema já resolvido pela Apple — resolvê-lo outra vez com
/// CKShare seria vaidade de engenharia, e além disso ela não instalaria uma app
/// compilada em Xcode com um perfil que caduca de sete em sete dias (ADR-002).
///
/// Esta camada **não decide nada**: lê, escreve, e executa as acções que o
/// `ReminderReconciler` produziu. Toda a lógica de conflitos vive no domínio,
/// onde se testa sem simulador nem permissões.
public struct RemindersBridge: Sendable {

    public enum Falha: Error, LocalizedError {
        case semAcesso
        case listaNaoEncontrada(String)
        case indisponivel

        public var errorDescription: String? {
            switch self {
            case .semAcesso:
                "A Bússola não tem acesso aos Lembretes. Podes dar-lho nas Definições."
            case .listaNaoEncontrada(let nome):
                "Não encontrei a lista «\(nome)» nos Lembretes. Cria-a e partilha-a."
            case .indisponivel:
                "Os Lembretes não estão disponíveis nesta plataforma."
            }
        }
    }

    /// O nome da lista a espelhar. Configurável, porque é a esposa que a cria e
    /// pode chamar-lhe o que quiser.
    public let nomeDaLista: String

    public init(nomeDaLista: String = "Família") {
        self.nomeDaLista = nomeDaLista
    }

    #if canImport(EventKit)
    // EKEventStore não é Sendable, e uma instância por chamada perderia as
    // permissões concedidas e refaria trabalho caro a cada leitura. A Apple
    // desenha-o para viver uma vez por processo; `nonisolated(unsafe)` é a
    // forma honesta de dizer que a garantia vem daí e não do compilador.
    nonisolated(unsafe) private static let store = EKEventStore()
    #endif

    public func pedirAcesso() async -> Bool {
        #if canImport(EventKit)
        return (try? await Self.store.requestFullAccessToReminders()) ?? false
        #else
        return false
        #endif
    }

    /// As listas existentes, para o utilizador escolher qual espelhar.
    public func listasDisponiveis() -> [String] {
        #if canImport(EventKit)
        return Self.store.calendars(for: .reminder).map(\.title)
        #else
        return []
        #endif
    }

    // MARK: - Leitura

    public func ler() async throws -> [ReminderMirror] {
        #if canImport(EventKit)
        let lista = try lista()
        let predicado = Self.store.predicateForReminders(in: [lista])

        let lembretes: [EKReminder] = await withCheckedContinuation { continuacao in
            Self.store.fetchReminders(matching: predicado) { resultado in
                continuacao.resume(returning: resultado ?? [])
            }
        }
        return lembretes.map(espelho(de:))
        #else
        throw Falha.indisponivel
        #endif
    }

    // MARK: - Escrita

    /// Executa as acções decididas pelo domínio.
    ///
    /// Devolve os identificadores atribuídos às tarefas que passaram a ter
    /// espelho, para o chamador os poder guardar. Sem isto, a passagem seguinte
    /// criaria os mesmos lembretes outra vez.
    public func aplicar(_ accoes: [SyncAction]) async throws -> [UUID: String] {
        #if canImport(EventKit)
        let lista = try lista()

        // `calendarItemIdentifier` só passa a ser estável depois do commit: lido
        // antes disso vem vazio ou temporário, e a passagem seguinte criava os
        // mesmos lembretes outra vez. Por isso guardam-se as referências e os
        // identificadores só se recolhem no fim.
        var criados: [(UUID, EKReminder)] = []

        for accao in accoes {
            switch accao {
            case .criarLembrete(let tarefa):
                let lembrete = EKReminder(eventStore: Self.store)
                lembrete.calendar = lista
                aplicar(tarefa, a: lembrete)
                try Self.store.save(lembrete, commit: false)
                criados.append((tarefa.id, lembrete))

            case .actualizarLembrete(let tarefa):
                guard let id = tarefa.externalID, let lembrete = procurar(id) else { continue }
                aplicar(tarefa, a: lembrete)
                try Self.store.save(lembrete, commit: false)

            case .concluirLembrete(let id):
                guard let lembrete = procurar(id) else { continue }
                lembrete.isCompleted = true
                try Self.store.save(lembrete, commit: false)

            // Estas três mudam o lado de cá; quem chama é que as aplica à base
            // de dados. Enumerar todos os casos em vez de usar `default` é
            // deliberado: um caso novo em SyncAction passa a dar erro de
            // compilação aqui, em vez de ser silenciosamente ignorado.
            case .criarTarefa, .actualizarTarefa, .concluirTarefa, .desligarEspelho:
                continue
            }
        }

        // Um único commit no fim: o EventKit é lento por escrita, e o ritual não
        // pode ficar à espera de trinta gravações individuais.
        try Self.store.commit()

        return Dictionary(
            criados.map { ($0.0, $0.1.calendarItemIdentifier) },
            uniquingKeysWith: { a, _ in a }
        )
        #else
        throw Falha.indisponivel
        #endif
    }

    // MARK: - Privado

    #if canImport(EventKit)
    private func lista() throws -> EKCalendar {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw Falha.semAcesso
        }
        guard let lista = Self.store.calendars(for: .reminder)
            .first(where: { $0.title.caseInsensitiveCompare(nomeDaLista) == .orderedSame })
        else {
            throw Falha.listaNaoEncontrada(nomeDaLista)
        }
        return lista
    }

    private func procurar(_ identificador: String) -> EKReminder? {
        Self.store.calendarItem(withIdentifier: identificador) as? EKReminder
    }

    private func espelho(de lembrete: EKReminder) -> ReminderMirror {
        ReminderMirror(
            externalID: lembrete.calendarItemIdentifier,
            title: lembrete.title ?? "",
            notes: lembrete.notes ?? "",
            dueDate: lembrete.dueDateComponents.flatMap {
                Calendar.current.date(from: $0)
            },
            completed: lembrete.isCompleted,
            lastModified: lembrete.lastModifiedDate ?? lembrete.creationDate ?? .distantPast
        )
    }

    private func aplicar(_ tarefa: TaskItem, a lembrete: EKReminder) {
        lembrete.title = tarefa.title
        lembrete.notes = tarefa.notes.isEmpty ? nil : tarefa.notes
        lembrete.dueDateComponents = tarefa.dueDate.map {
            Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
        }
        lembrete.isCompleted = tarefa.status == .done
    }
    #endif
}

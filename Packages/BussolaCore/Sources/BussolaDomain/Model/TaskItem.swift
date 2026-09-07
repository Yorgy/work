import Foundation

/// Onde uma tarefa está no ciclo de vida.
public enum TaskStatus: String, Sendable, Codable, CaseIterable {
    case inbox      // capturada, ainda não triada
    case next       // triada, disponível para entrar num plano
    case planned    // comprometida para um dia concreto
    case doing      // a decorrer agora
    case done
    case waiting    // à espera de terceiro — ver WaitingFor
    case someday    // um dia, talvez. Fora do radar diário.
    case dropped

    /// Estados que contam como trabalho por fazer.
    public var estaAberta: Bool {
        switch self {
        case .inbox, .next, .planned, .doing, .waiting: true
        case .done, .someday, .dropped: false
        }
    }
}

/// O tipo de cabeça que a tarefa exige.
///
/// A Rocha exige `.deep`. Não se agenda trabalho profundo para as 17h30 de
/// sexta-feira, e um planeador que ignora isto produz planos que não se cumprem.
public enum Energy: String, Sendable, Codable, CaseIterable {
    case deep       // exige concentração contínua
    case shallow    // exige atenção, não concentração
    case admin      // mecânico

    public var descricao: String {
        switch self {
        case .deep:    "Profundo"
        case .shallow: "Corrente"
        case .admin:   "Administrativo"
        }
    }
}

/// A âncora de execução: *quando* e *onde*.
///
/// É a tradução prática das implementation intentions de Gollwitzer — pistas
/// situacionais associadas a um momento e a um lugar são recordadas melhor do
/// que uma intenção vaga. Nenhuma tarefa entra num plano sem âncora.
public struct Anchor: Sendable, Hashable, Codable {
    public var quando: String   // "depois de deixar a miúda na escola"
    public var onde: String     // "no carro"

    public init(quando: String, onde: String) {
        self.quando = quando
        self.onde = onde
    }

    public var estaCompleta: Bool {
        !quando.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !onde.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var descricao: String { "\(quando), \(onde)" }
}

/// A unidade de execução.
public struct TaskItem: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var notes: String
    public var area: AreaID
    public var projectID: UUID?
    public var status: TaskStatus
    public var energy: Energy
    public var estimatedMinutes: Int

    /// Data-limite real. Falhá-la tem consequência.
    public var dueDate: Date?

    /// A tarefa existe mas não deve aparecer antes desta data.
    /// Diferente de `dueDate` — sem isto a Inbox enche-se de coisas que ainda
    /// não são para agora, e o sistema perde credibilidade.
    public var defersUntil: Date?

    public var anchor: Anchor?

    /// Identificador do lembrete correspondente, quando a tarefa é espelhada
    /// na lista partilhada dos Lembretes. Chave de reconciliação — ver ADR-002.
    public var externalID: String?

    /// Origem, quando gerada por um modelo de recorrência.
    public var recurrenceID: UUID?

    /// Fazer isto liberta trabalho de outra pessoa.
    ///
    /// Pesa na proposta do plano: uma tarefa que desbloqueia o empreiteiro ou o
    /// contabilista vale mais do que uma que só te desbloqueia a ti, porque a
    /// espera deles corre em paralelo com tudo o resto.
    public var unblocksOthers: Bool

    public var createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        area: AreaID,
        projectID: UUID? = nil,
        status: TaskStatus = .next,
        energy: Energy = .shallow,
        estimatedMinutes: Int = 15,
        dueDate: Date? = nil,
        defersUntil: Date? = nil,
        anchor: Anchor? = nil,
        externalID: String? = nil,
        recurrenceID: UUID? = nil,
        unblocksOthers: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.area = area
        self.projectID = projectID
        self.status = status
        self.energy = energy
        self.estimatedMinutes = estimatedMinutes
        self.dueDate = dueDate
        self.defersUntil = defersUntil
        self.anchor = anchor
        self.externalID = externalID
        self.recurrenceID = recurrenceID
        self.unblocksOthers = unblocksOthers
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// Uma tarefa diferida não aparece em lado nenhum até à data.
    public func estaDisponivel(em agora: Date) -> Bool {
        guard status.estaAberta else { return false }
        guard let defersUntil else { return true }
        return defersUntil <= agora
    }

    /// Areia: tudo abaixo de 5 minutos. Faz-se numa passagem única.
    public var eAreia: Bool { estimatedMinutes <= 5 }

    /// Candidata a Rocha: exige concentração e tem duração de bloco.
    public var podeSerRocha: Bool { energy == .deep && estimatedMinutes >= 45 }

    public func diasDesdeCriacao(ate agora: Date, calendario: Calendar = .current) -> Int {
        calendario.dateComponents([.day], from: createdAt, to: agora).day ?? 0
    }
}

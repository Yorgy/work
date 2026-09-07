import Foundation

public enum PlanError: Error, Equatable, Sendable {
    case pedrasCheias(limite: Int)
    case todasDaMesmaArea(AreaID)
    case semAncora(taskID: UUID)
    case rochaNaoEProfunda(taskID: UUID)
    case tarefaIndisponivel(taskID: UUID)
    case tarefaJaNoPlano(taskID: UUID)
    case planoJaFechado

    public var mensagem: String {
        switch self {
        case .pedrasCheias(let limite):
            "Já tens \(limite) Pedras. Para acrescentar outra, tens de remover uma."
        case .todasDaMesmaArea(let area):
            "As três Pedras ficariam todas em \(area.nome). Escolhe uma de outra área."
        case .semAncora:
            "Falta dizer quando e onde. Sem âncora, a tarefa não entra no plano."
        case .rochaNaoEProfunda:
            "A Rocha tem de ser trabalho profundo de pelo menos 45 minutos."
        case .tarefaIndisponivel:
            "Essa tarefa está adiada ou fechada."
        case .tarefaJaNoPlano:
            "Essa tarefa já está no plano de amanhã."
        case .planoJaFechado:
            "O plano de hoje já foi fechado. Replanear a meio do dia é comer ao sabor do vento."
        }
    }
}

/// Como correu o dia. Guardado para comparar plano com realidade ao fim de
/// semanas e calibrar o buffer com dados em vez de opinião.
public struct DayOutcome: Sendable, Hashable, Codable {
    public var rochaCumprida: Bool
    public var pedrasCumpridas: Int
    public var nota: String

    public init(rochaCumprida: Bool = false, pedrasCumpridas: Int = 0, nota: String = "") {
        self.rochaCumprida = rochaCumprida
        self.pedrasCumpridas = pedrasCumpridas
        self.nota = nota
    }
}

/// O compromisso para um dia.
///
/// Criado no ritual das 21h e imutável a partir da meia-noite — só o `outcome`
/// se altera durante o dia. Guarda apenas identificadores; as regras que
/// dependem do conteúdo das tarefas vivem em `DayPlanBuilder`.
public struct DayPlan: Identifiable, Sendable, Hashable, Codable {
    public static let limiteDePedras = 3

    public let id: UUID

    /// Normalizada ao início do dia.
    public let date: Date

    public var rockID: UUID?
    public var pebbleIDs: [UUID]
    public var sandIDs: [UUID]

    /// Capacidade calculada no momento do planeamento.
    public var capacityMinutes: Int

    public var plannedAt: Date
    public var closedAt: Date?
    public var outcome: DayOutcome?

    public init(
        id: UUID = UUID(),
        date: Date,
        rockID: UUID? = nil,
        pebbleIDs: [UUID] = [],
        sandIDs: [UUID] = [],
        capacityMinutes: Int = 0,
        plannedAt: Date = Date(),
        closedAt: Date? = nil,
        outcome: DayOutcome? = nil,
        calendario: Calendar = .current
    ) {
        self.id = id
        self.date = calendario.startOfDay(for: date)
        self.rockID = rockID
        self.pebbleIDs = pebbleIDs
        self.sandIDs = sandIDs
        self.capacityMinutes = capacityMinutes
        self.plannedAt = plannedAt
        self.closedAt = closedAt
        self.outcome = outcome
    }

    public var estaVazio: Bool { rockID == nil && pebbleIDs.isEmpty }

    /// Identificadores comprometidos, pela ordem em que se executam.
    /// A Rocha primeiro: se só uma coisa acontecer, tem de ser esta.
    public var ordemDeExecucao: [UUID] {
        (rockID.map { [$0] } ?? []) + pebbleIDs
    }

    public func contem(_ taskID: UUID) -> Bool {
        rockID == taskID || pebbleIDs.contains(taskID) || sandIDs.contains(taskID)
    }
}

/// Constrói e valida um plano durante o ritual.
///
/// É aqui que vivem os invariantes que dão sentido ao sistema. O limite de
/// 1 Rocha + 3 Pedras não é uma sugestão: uma restrição que se pode ultrapassar
/// não resolve um problema de compromisso, e a fricção **é** a funcionalidade.
public struct DayPlanBuilder: Sendable {
    public private(set) var date: Date
    public private(set) var rock: TaskItem?
    public private(set) var pebbles: [TaskItem]
    public private(set) var sand: [TaskItem]
    public private(set) var capacityMinutes: Int

    private let calendario: Calendar

    public init(
        date: Date,
        capacityMinutes: Int = 0,
        calendario: Calendar = .current
    ) {
        self.calendario = calendario
        self.date = calendario.startOfDay(for: date)
        self.capacityMinutes = capacityMinutes
        self.rock = nil
        self.pebbles = []
        self.sand = []
    }

    // MARK: - Rocha

    public mutating func definirRocha(_ tarefa: TaskItem, em agora: Date = Date()) throws {
        try validarDisponibilidade(tarefa, em: agora)
        guard tarefa.podeSerRocha else { throw PlanError.rochaNaoEProfunda(taskID: tarefa.id) }
        if pebbles.contains(where: { $0.id == tarefa.id }) {
            throw PlanError.tarefaJaNoPlano(taskID: tarefa.id)
        }
        rock = tarefa
    }

    public mutating func removerRocha() { rock = nil }

    // MARK: - Pedras

    public mutating func acrescentarPedra(_ tarefa: TaskItem, em agora: Date = Date()) throws {
        try validarDisponibilidade(tarefa, em: agora)
        guard pebbles.count < DayPlan.limiteDePedras else {
            throw PlanError.pedrasCheias(limite: DayPlan.limiteDePedras)
        }
        guard !contem(tarefa.id) else { throw PlanError.tarefaJaNoPlano(taskID: tarefa.id) }

        // Com cinco áreas em jogo, garantir variedade vale mais do que optimizar
        // urgência. Sem esta regra, Clientes consome as três Pedras e Obras e
        // Família apagam-se — que é exactamente o padrão a corrigir.
        let futuras = pebbles.map(\.area) + [tarefa.area]
        if futuras.count == DayPlan.limiteDePedras, Set(futuras).count == 1 {
            throw PlanError.todasDaMesmaArea(tarefa.area)
        }

        pebbles.append(tarefa)
    }

    public mutating func removerPedra(_ taskID: UUID) {
        pebbles.removeAll { $0.id == taskID }
    }

    /// Troca directa, para quando o limite está cheio. É o gesto que o ritual
    /// oferece em vez de deixar acrescentar mais uma.
    public mutating func substituirPedra(
        _ velha: UUID, por nova: TaskItem, em agora: Date = Date()
    ) throws {
        guard let indice = pebbles.firstIndex(where: { $0.id == velha }) else {
            throw PlanError.tarefaIndisponivel(taskID: velha)
        }
        try validarDisponibilidade(nova, em: agora)
        guard !contem(nova.id) else { throw PlanError.tarefaJaNoPlano(taskID: nova.id) }

        var candidatas = pebbles
        candidatas[indice] = nova
        if candidatas.count == DayPlan.limiteDePedras, Set(candidatas.map(\.area)).count == 1 {
            throw PlanError.todasDaMesmaArea(nova.area)
        }
        pebbles = candidatas
    }

    /// Reordena as Pedras. A ordem é informação: a 2 só se activa quando a 1 fecha.
    public mutating func reordenarPedras(_ ordem: [UUID]) {
        let porID = Dictionary(uniqueKeysWithValues: pebbles.map { ($0.id, $0) })
        var reordenadas = ordem.compactMap { porID[$0] }
        // Preserva qualquer Pedra que a ordem recebida tenha omitido.
        for pedra in pebbles where !reordenadas.contains(where: { $0.id == pedra.id }) {
            reordenadas.append(pedra)
        }
        pebbles = reordenadas
    }

    // MARK: - Areia

    public mutating func acrescentarAreia(_ tarefa: TaskItem) {
        guard tarefa.eAreia, !contem(tarefa.id) else { return }
        sand.append(tarefa)
    }

    // MARK: - Capacidade

    public mutating func definirCapacidade(_ minutos: Int) {
        capacityMinutes = max(0, minutos)
    }

    /// Minutos comprometidos. A Areia conta — cinco minutos vezes oito é uma
    /// manhã, e fingir que não conta é como se estoiram os planos.
    public var minutosComprometidos: Int {
        (rock?.estimatedMinutes ?? 0)
            + pebbles.reduce(0) { $0 + $1.estimatedMinutes }
            + sand.reduce(0) { $0 + $1.estimatedMinutes }
    }

    /// Aviso, não erro. O limite duro é 1+3; a capacidade informa a escolha.
    public var excedeCapacidade: Bool {
        capacityMinutes > 0 && minutosComprometidos > capacityMinutes
    }

    public var minutosEmExcesso: Int {
        max(0, minutosComprometidos - capacityMinutes)
    }

    // MARK: - Fecho

    /// Tarefas sem âncora. Nenhuma pode entrar no plano final — é o passo que
    /// toda a gente quer saltar e o que tem melhor evidência por trás.
    public var semAncora: [TaskItem] {
        let comprometidas = (rock.map { [$0] } ?? []) + pebbles
        return comprometidas.filter { !($0.anchor?.estaCompleta ?? false) }
    }

    public var estaPronto: Bool { !estaVazio && semAncora.isEmpty }

    public var estaVazio: Bool { rock == nil && pebbles.isEmpty }

    /// Produz o plano persistível, ou falha a dizer o que falta.
    public func construir(plannedAt: Date = Date()) throws -> DayPlan {
        if let primeira = semAncora.first {
            throw PlanError.semAncora(taskID: primeira.id)
        }
        if pebbles.count == DayPlan.limiteDePedras, Set(pebbles.map(\.area)).count == 1 {
            throw PlanError.todasDaMesmaArea(pebbles[0].area)
        }
        return DayPlan(
            date: date,
            rockID: rock?.id,
            pebbleIDs: pebbles.map(\.id),
            sandIDs: sand.map(\.id),
            capacityMinutes: capacityMinutes,
            plannedAt: plannedAt,
            calendario: calendario
        )
    }

    // MARK: - Privado

    public func contem(_ taskID: UUID) -> Bool {
        rock?.id == taskID
            || pebbles.contains { $0.id == taskID }
            || sand.contains { $0.id == taskID }
    }

    private func validarDisponibilidade(_ tarefa: TaskItem, em agora: Date) throws {
        guard tarefa.estaDisponivel(em: agora) else {
            throw PlanError.tarefaIndisponivel(taskID: tarefa.id)
        }
    }
}

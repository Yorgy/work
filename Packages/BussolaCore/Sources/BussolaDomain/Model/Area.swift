import Foundation

/// As cinco áreas de responsabilidade. Fixas por design — ver ADR-004.
///
/// Criar áreas novas é a forma mais comum de fugir ao trabalho de decidir:
/// reorganizar a taxonomia sente-se produtivo e não produz nada. Cinco áreas
/// cabem na cabeça e tornam o termómetro legível de relance.
public enum AreaID: String, CaseIterable, Sendable, Codable, Hashable {
    case agencia
    case clientes
    case familia
    case obras
    case pessoal

    public var nome: String {
        switch self {
        case .agencia:  "Agência"
        case .clientes: "Clientes"
        case .familia:  "Família"
        case .obras:    "Obras"
        case .pessoal:  "Pessoal"
        }
    }

    public var subtitulo: String {
        switch self {
        case .agencia:  "Financeiro"
        case .clientes: "Web"
        case .familia:  "Casa"
        case .obras:    "Empreitada"
        case .pessoal:  "Eu"
        }
    }

    /// Nome do símbolo SF usado na interface.
    public var simbolo: String {
        switch self {
        case .agencia:  "eurosign.circle"
        case .clientes: "chevron.left.forwardslash.chevron.right"
        case .familia:  "house"
        case .obras:    "hammer"
        case .pessoal:  "leaf"
        }
    }

    /// A área Família vive numa lista partilhada dos Lembretes — ver ADR-002.
    /// É a única cujas tarefas atravessam a fronteira do dispositivo.
    public var espelhadaNosLembretes: Bool { self == .familia }
}

/// Estado de atenção de uma área, derivado dos dias desde o último toque.
///
/// O "toque" conta quando se **conclui** uma tarefa da área. Ver uma área não
/// é atendê-la, e um sistema que confunde as duas coisas mente ao utilizador.
public enum AreaTemperature: String, Sendable, Codable, CaseIterable, Comparable {
    case viva        // 0–3 dias
    case arrefecer   // 4–7
    case fria        // 8–14
    case escura      // > 14

    public var descricao: String {
        switch self {
        case .viva:      "Viva"
        case .arrefecer: "A arrefecer"
        case .fria:      "Fria"
        case .escura:    "Escura"
        }
    }

    /// Acima de 14 dias a área bloqueia o ritual das 21h até se decidir:
    /// agir ou pôr em pausa explícita. Deliberadamente incómodo — uma área
    /// escura há duas semanas ou tem trabalho por fazer, ou devia estar
    /// oficialmente em pausa. O que não pode é ficar num limbo silencioso.
    public var bloqueiaRitual: Bool { self == .escura }

    /// Peso da frieza no algoritmo de proposta do plano, normalizado a 0…1.
    public var pesoNaProposta: Double {
        switch self {
        case .viva:      0.0
        case .arrefecer: 0.35
        case .fria:      0.75
        case .escura:    1.0
        }
    }

    private var ordem: Int {
        switch self {
        case .viva: 0
        case .arrefecer: 1
        case .fria: 2
        case .escura: 3
        }
    }

    public static func < (lhs: AreaTemperature, rhs: AreaTemperature) -> Bool {
        lhs.ordem < rhs.ordem
    }
}

/// O estado corrente de uma área: identidade fixa, atenção variável.
public struct Area: Identifiable, Sendable, Hashable, Codable {
    public let id: AreaID

    /// Última vez que uma tarefa desta área foi **concluída**.
    /// `nil` significa que nunca foi tocada — tratada como escura.
    public var lastTouchedAt: Date?

    /// Pausa explícita. Uma área em pausa não bloqueia o ritual nem entra
    /// no cálculo da proposta, mas continua visível no termómetro.
    public var pausadaAte: Date?

    public init(id: AreaID, lastTouchedAt: Date? = nil, pausadaAte: Date? = nil) {
        self.id = id
        self.lastTouchedAt = lastTouchedAt
        self.pausadaAte = pausadaAte
    }

    public func estaPausada(em agora: Date) -> Bool {
        guard let pausadaAte else { return false }
        return pausadaAte > agora
    }
}

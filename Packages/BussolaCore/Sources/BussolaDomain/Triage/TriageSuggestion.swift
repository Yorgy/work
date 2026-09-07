import Foundation

/// O que uma captura afinal é.
public enum ItemKind: String, Sendable, Codable, CaseIterable {
    case accao          // trabalho teu
    case espera         // dívida de outra pessoa
    case referencia     // informação a guardar, sem acção
    case lixo           // não era nada

    public var descricao: String {
        switch self {
        case .accao:      "Acção"
        case .espera:     "À espera"
        case .referencia: "Referência"
        case .lixo:       "Lixo"
        }
    }
}

/// Proposta de classificação para uma captura.
///
/// Na implementação com Foundation Models este tipo é gerado com `@Generable`,
/// o que faz o modelo devolver um valor verificado em vez de uma string para
/// parsear. Aqui vive a forma pura, para o domínio não depender do framework.
public struct TriageSuggestion: Sendable, Hashable, Codable {
    /// Reescrita como acção concreta começada por verbo.
    public var actionTitle: String
    public var area: AreaID
    public var kind: ItemKind
    public var energy: Energy
    public var estimatedMinutes: Int
    public var dueDate: Date?
    /// De quem se espera, quando `kind == .espera`.
    public var waitingOn: String?
    public var channel: Channel?
    /// 0…100. Calibra o gesto na triagem, não a decisão.
    public var confidence: Int

    public init(
        actionTitle: String,
        area: AreaID,
        kind: ItemKind = .accao,
        energy: Energy = .shallow,
        estimatedMinutes: Int = 15,
        dueDate: Date? = nil,
        waitingOn: String? = nil,
        channel: Channel? = nil,
        confidence: Int = 50
    ) {
        self.actionTitle = actionTitle
        self.area = area
        self.kind = kind
        self.energy = energy
        self.estimatedMinutes = estimatedMinutes
        self.dueDate = dueDate
        self.waitingOn = waitingOn
        self.channel = channel
        self.confidence = min(100, max(0, confidence))
    }

    /// Abaixo deste limiar, o cartão abre para edição em vez de propor swipe.
    /// A app pede atenção só quando é preciso — que é o que a torna suportável.
    public static let limiarDeConfianca = 60

    public var exigeRevisaoManual: Bool { confidence < Self.limiarDeConfianca }

    /// Acima de 80 basta o swipe; entre 60 e 80 mostra-se a razão da dúvida.
    public var aceitaSwipeSimples: Bool { confidence >= 80 }

    /// Converte a proposta aceite numa tarefa.
    public func materializar(
        origem: Capture,
        agora: Date = Date()
    ) -> TaskItem {
        TaskItem(
            title: actionTitle,
            notes: origem.text == actionTitle ? "" : origem.text,
            area: area,
            status: kind == .espera ? .waiting : .next,
            energy: energy,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            createdAt: origem.createdAt
        )
    }
}

/// Quem sabe transformar uma captura numa proposta.
///
/// Duas implementações, escolhidas em runtime: o modelo local do Apple
/// Intelligence e um classificador determinístico. A app nunca deixa de
/// funcionar por causa da IA — ver ADR-007.
public protocol Triaging: Sendable {
    var isAvailable: Bool { get }
    func sugerir(para captura: Capture, agora: Date) async throws -> TriageSuggestion
}

public extension Triaging {
    func sugerir(para captura: Capture) async throws -> TriageSuggestion {
        try await sugerir(para: captura, agora: Date())
    }
}

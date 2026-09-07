import Foundation

/// Por onde o pedido saiu. Determina quanto tempo é razoável esperar antes de
/// insistir — insistir cedo demais queima crédito, tarde demais perde o negócio.
public enum Channel: String, Sendable, Codable, CaseIterable {
    case email
    case mensagem       // WhatsApp, SMS
    case chamada
    case formal         // contabilista, finanças, entidades oficiais
    case presencial

    /// Dias até o follow-up automático.
    public var diasDeFollowUp: Int {
        switch self {
        case .email:      3
        case .mensagem:   2
        case .chamada:    1
        case .formal:     7
        case .presencial: 5
        }
    }

    public var descricao: String {
        switch self {
        case .email:      "Email"
        case .mensagem:   "Mensagem"
        case .chamada:    "Chamada"
        case .formal:     "Formal"
        case .presencial: "Presencial"
        }
    }
}

/// Dívida de outra pessoa que tu tens de cobrar.
///
/// Metade do trabalho é esperar por terceiros: o cliente que tem de aprovar a
/// maquete, o contabilista que tem de enviar o mapa, o empreiteiro que ficou de
/// dar preço. As apps de tarefas tratam isto como uma tarefa normal, o que está
/// errado — não é trabalho teu. É o buraco onde se perdem dinheiro e credibilidade.
public struct WaitingFor: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID

    /// A tarefa correspondente, em estado `.waiting`.
    public let taskID: UUID

    /// De quem se espera. Obrigatório — "à espera" sem dono é só uma desculpa.
    public var owner: String

    public var channel: Channel
    public var requestedAt: Date
    public var followUpAt: Date

    /// Quantas vezes já se insistiu. Ao fim de três, o problema deixa de ser
    /// o esquecimento da outra pessoa e passa a ser uma decisão tua.
    public var followUpCount: Int

    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        owner: String,
        channel: Channel = .email,
        requestedAt: Date = Date(),
        followUpAt: Date? = nil,
        followUpCount: Int = 0,
        resolvedAt: Date? = nil,
        calendario: Calendar = .current
    ) {
        self.id = id
        self.taskID = taskID
        self.owner = owner
        self.channel = channel
        self.requestedAt = requestedAt
        self.followUpAt = followUpAt
            ?? calendario.date(byAdding: .day, value: channel.diasDeFollowUp, to: requestedAt)
            ?? requestedAt
        self.followUpCount = followUpCount
        self.resolvedAt = resolvedAt
    }

    public var estaResolvido: Bool { resolvedAt != nil }

    public func estaVencido(em agora: Date) -> Bool {
        !estaResolvido && followUpAt <= agora
    }

    public func diasDeSilencio(ate agora: Date, calendario: Calendar = .current) -> Int {
        let desde = ultimoContacto
        return max(0, calendario.dateComponents([.day], from: desde, to: agora).day ?? 0)
    }

    /// A data do contacto mais recente: o pedido original, ou o último follow-up.
    private var ultimoContacto: Date {
        guard followUpCount > 0 else { return requestedAt }
        // `followUpAt` avança a cada insistência, por isso o contacto anterior
        // está um ciclo de canal atrás dele.
        return Calendar.current.date(
            byAdding: .day, value: -channel.diasDeFollowUp, to: followUpAt
        ) ?? requestedAt
    }

    /// Regista uma insistência e reagenda a seguinte.
    public mutating func registarFollowUp(em agora: Date = Date(), calendario: Calendar = .current) {
        followUpCount += 1
        followUpAt = calendario.date(
            byAdding: .day, value: channel.diasDeFollowUp, to: agora
        ) ?? agora
    }
}

public enum FollowUpPolicy {
    /// Ao fim de três insistências sem resposta, o problema mudou de dono.
    /// A app deixa de propor mais um follow-up e passa a propor uma decisão:
    /// escalar, contornar ou desistir.
    public static let limiteDeInsistencias = 3

    /// Pendentes que já venceram, mais silenciosos primeiro. É o ecrã que mais
    /// depressa paga o custo de construir a app.
    public static func vencidos(
        _ pendentes: [WaitingFor],
        em agora: Date = Date()
    ) -> [WaitingFor] {
        pendentes
            .filter { $0.estaVencido(em: agora) }
            .sorted { $0.diasDeSilencio(ate: agora) > $1.diasDeSilencio(ate: agora) }
    }

    public static func exigeDecisao(_ pendente: WaitingFor) -> Bool {
        pendente.followUpCount >= limiteDeInsistencias && !pendente.estaResolvido
    }

    /// Texto do follow-up, pronto a copiar. Sóbrio: quem insiste com floreados
    /// insiste pior.
    public static func rascunho(para pendente: WaitingFor, assunto: String) -> String {
        let dias = pendente.diasDeSilencio(ate: Date())
        switch pendente.followUpCount {
        case 0:
            return "Olá \(pendente.owner), só a confirmar se recebeu o pedido sobre \(assunto). Obrigado."
        case 1:
            return "Olá \(pendente.owner), a retomar o assunto \(assunto) — passaram \(dias) dias. Consegue dar-me uma data?"
        default:
            return "Olá \(pendente.owner), sobre \(assunto): preciso de fechar isto esta semana. Se não for possível da sua parte, diga-me para eu avançar de outra forma."
        }
    }
}

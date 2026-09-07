import Foundation

public struct AreaReading: Identifiable, Sendable, Hashable {
    public var id: AreaID { area }
    public let area: AreaID
    public let temperatura: AreaTemperature
    /// `nil` quando a área nunca foi tocada.
    public let diasDesdeUltimoToque: Int?
    public let tarefasAbertas: Int
    public let pendentesDeTerceiros: Int
    public let emPausa: Bool

    public init(
        area: AreaID,
        temperatura: AreaTemperature,
        diasDesdeUltimoToque: Int?,
        tarefasAbertas: Int,
        pendentesDeTerceiros: Int,
        emPausa: Bool
    ) {
        self.area = area
        self.temperatura = temperatura
        self.diasDesdeUltimoToque = diasDesdeUltimoToque
        self.tarefasAbertas = tarefasAbertas
        self.pendentesDeTerceiros = pendentesDeTerceiros
        self.emPausa = emPausa
    }

    /// "há 16 dias" — a cor nunca é o único sinal.
    public var descricaoDoToque: String {
        guard let dias = diasDesdeUltimoToque else { return "nunca tocada" }
        switch dias {
        case 0: return "hoje"
        case 1: return "ontem"
        default: return "há \(dias) dias"
        }
    }

    /// Uma área em pausa explícita não bloqueia nada.
    public var bloqueiaRitual: Bool {
        !emPausa && temperatura.bloqueiaRitual
    }
}

/// Mede atenção, não volume.
///
/// Com cinco áreas em jogo, o risco não é esquecer tarefas — é uma área inteira
/// ficar escura durante um mês sem ninguém dar por isso. Este é o oposto do que
/// fazem as apps normais, que só mostram o que está atrasado.
public struct AreaThermometer: Sendable {
    public static let limiarArrefecer = 4
    public static let limiarFrio = 8
    public static let limiarEscuro = 15

    public init() {}

    public static func temperatura(paraDias dias: Int?) -> AreaTemperature {
        guard let dias else { return .escura }
        switch dias {
        case ..<limiarArrefecer: return .viva
        case ..<limiarFrio:      return .arrefecer
        case ..<limiarEscuro:    return .fria
        default:                 return .escura
        }
    }

    public func ler(
        areas: [Area],
        tarefas: [TaskItem],
        pendentes: [WaitingFor],
        agora: Date = Date(),
        calendario: Calendar = .current
    ) -> [AreaReading] {
        let abertasPorArea = Dictionary(grouping: tarefas.filter { $0.status.estaAberta }) { $0.area }
        let areaPorTarefa = Dictionary(tarefas.map { ($0.id, $0.area) }, uniquingKeysWith: { a, _ in a })
        let pendentesPorArea = Dictionary(
            grouping: pendentes.filter { !$0.estaResolvido }.compactMap { areaPorTarefa[$0.taskID] },
            by: { $0 }
        )
        let porID = Dictionary(areas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        return AreaID.allCases.map { id in
            let area = porID[id] ?? Area(id: id)
            let dias = area.lastTouchedAt.map {
                max(0, calendario.dateComponents([.day], from: $0, to: agora).day ?? 0)
            }
            return AreaReading(
                area: id,
                temperatura: Self.temperatura(paraDias: dias),
                diasDesdeUltimoToque: dias,
                tarefasAbertas: abertasPorArea[id]?.count ?? 0,
                pendentesDeTerceiros: pendentesPorArea[id]?.count ?? 0,
                emPausa: area.estaPausada(em: agora)
            )
        }
        .sorted { $0.temperatura > $1.temperatura }
    }

    /// Áreas que bloqueiam o ritual até se decidir: agir ou pausar.
    public func bloqueios(_ leituras: [AreaReading]) -> [AreaReading] {
        leituras.filter(\.bloqueiaRitual)
    }
}

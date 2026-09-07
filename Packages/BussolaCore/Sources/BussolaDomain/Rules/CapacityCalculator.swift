import Foundation

/// Um bloco ocupado no calendário. Só interessa a duração e se é mesmo bloqueante.
public struct BusyBlock: Sendable, Hashable {
    public var start: Date
    public var end: Date
    /// Eventos de dia inteiro e convites recusados não bloqueiam tempo real.
    public var bloqueia: Bool

    public init(start: Date, end: Date, bloqueia: Bool = true) {
        self.start = start
        self.end = end
        self.bloqueia = bloqueia
    }

    public var minutos: Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }
}

public struct Capacity: Sendable, Hashable {
    /// Minutos realmente disponíveis para trabalho planeado.
    public let availableMinutes: Int
    /// Minutos reservados para o imprevisto.
    public let bufferMinutes: Int
    /// Minutos consumidos por compromissos já marcados.
    public let committedMinutes: Int

    public var availableHours: Double { Double(availableMinutes) / 60 }

    public init(availableMinutes: Int, bufferMinutes: Int, committedMinutes: Int) {
        self.availableMinutes = max(0, availableMinutes)
        self.bufferMinutes = max(0, bufferMinutes)
        self.committedMinutes = max(0, committedMinutes)
    }

    /// "3h20" — para o ecrã do ritual.
    public var descricao: String {
        let h = availableMinutes / 60
        let m = availableMinutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(String(format: "%02d", m))"
    }
}

/// Calcula a capacidade real de um dia a partir do calendário.
///
/// Um planeador que ignora o calendário mente, e um planeador que mente deixa
/// de se usar. Se amanhã tens quatro horas de reuniões, propor uma Rocha de
/// 90 minutos é uma forma sofisticada de planear o falhanço.
public struct CapacityCalculator: Sendable {
    /// Fracção do tempo livre reservada ao imprevisto.
    ///
    /// 40% não é pessimismo: é a única forma de um plano sobreviver a uma filha
    /// com febre ou a um cliente em pânico. Um plano que assume 100% de
    /// aproveitamento falha todos os dias, e um plano que falha todos os dias
    /// deixa de se fazer ao fim de três semanas.
    public static let bufferPadrao = 0.4

    public var minutosUteisPorDia: Int
    public var minutosDeFamilia: Int
    public var bufferRatio: Double

    public init(
        minutosUteisPorDia: Int = 8 * 60,
        minutosDeFamilia: Int = 90,
        bufferRatio: Double = CapacityCalculator.bufferPadrao
    ) {
        self.minutosUteisPorDia = minutosUteisPorDia
        self.minutosDeFamilia = minutosDeFamilia
        self.bufferRatio = min(max(bufferRatio, 0), 0.9)
    }

    public func calcular(blocosOcupados: [BusyBlock]) -> Capacity {
        let ocupados = blocosOcupados.filter(\.bloqueia).reduce(0) { $0 + $1.minutos }
        let livre = max(0, minutosUteisPorDia - ocupados - minutosDeFamilia)
        let buffer = Int((Double(livre) * bufferRatio).rounded())
        return Capacity(
            availableMinutes: livre - buffer,
            bufferMinutes: buffer,
            committedMinutes: ocupados
        )
    }

    /// Duração máxima sensata para a Rocha de amanhã.
    ///
    /// Devolve `nil` quando não há espaço — e nesse caso o ritual propõe um dia
    /// só de Pedras, em vez de fingir que cabe um bloco profundo.
    public func duracaoDeRocha(para capacidade: Capacity) -> Int? {
        // A Rocha não pode comer mais de metade do disponível, ou não sobra
        // nada para as Pedras e o plano desfaz-se ao primeiro imprevisto.
        let tecto = capacidade.availableMinutes / 2
        guard tecto >= 45 else { return nil }
        return min(90, tecto)
    }
}

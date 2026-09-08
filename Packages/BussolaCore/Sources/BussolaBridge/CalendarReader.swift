import Foundation
import BussolaDomain

#if canImport(EventKit)
import EventKit
#endif

/// Lê o calendário para a capacidade do dia deixar de ser um palpite.
///
/// Um planeador que ignora o calendário mente, e um planeador que mente deixa de
/// se usar: se amanhã tens quatro horas de reuniões, propor uma Rocha de 90
/// minutos é planear o falhanço com antecedência.
///
/// Só leitura. A Bússola nunca escreve no calendário — os compromissos com
/// terceiros não são dela.
public struct CalendarReader: Sendable {

    public enum Acesso: Sendable, Equatable {
        case concedido
        case negado
        case indisponivel

        public var podeLer: Bool { self == .concedido }
    }

    public init() {}

    #if canImport(EventKit)
    // EKEventStore não é Sendable, e uma instância por chamada perderia as
    // permissões concedidas e refaria trabalho caro a cada leitura. A Apple
    // desenha-o para viver uma vez por processo; `nonisolated(unsafe)` é a
    // forma honesta de dizer que a garantia vem daí e não do compilador.
    nonisolated(unsafe) private static let store = EKEventStore()
    #endif

    public func pedirAcesso() async -> Acesso {
        #if canImport(EventKit)
        do {
            let concedido = try await Self.store.requestFullAccessToEvents()
            return concedido ? .concedido : .negado
        } catch {
            return .negado
        }
        #else
        return .indisponivel
        #endif
    }

    /// Os blocos ocupados de um dia.
    ///
    /// Três classes de evento não bloqueiam tempo real e são marcadas como tal:
    /// os de dia inteiro (uma anotação, não um compromisso), os convites
    /// recusados, e os que estão marcados como disponível. Contá-los apagaria o
    /// dia inteiro na aritmética da capacidade.
    public func blocos(de dia: Date, calendario: Calendar = .current) async -> [BusyBlock] {
        #if canImport(EventKit)
        let inicio = calendario.startOfDay(for: dia)
        guard let fim = calendario.date(byAdding: .day, value: 1, to: inicio) else { return [] }

        let predicado = Self.store.predicateForEvents(
            withStart: inicio, end: fim, calendars: nil
        )
        return Self.store.events(matching: predicado).map { evento in
            BusyBlock(
                start: max(evento.startDate, inicio),
                end: min(evento.endDate, fim),
                bloqueia: bloqueia(evento)
            )
        }
        #else
        return []
        #endif
    }

    #if canImport(EventKit)
    private func bloqueia(_ evento: EKEvent) -> Bool {
        if evento.isAllDay { return false }
        if evento.status == .canceled { return false }
        if evento.availability == .free { return false }
        // Um convite que recusaste não te ocupa a agenda.
        if let participante = evento.attendees?.first(where: \.isCurrentUser),
           participante.participantStatus == .declined {
            return false
        }
        return true
    }
    #endif

    /// A capacidade real de um dia, já calculada.
    public func capacidade(
        de dia: Date,
        calculadora: CapacityCalculator = CapacityCalculator(),
        calendario: Calendar = .current
    ) async -> Capacity {
        let ocupados = await blocos(de: dia, calendario: calendario)
        return calculadora.calcular(blocosOcupados: ocupados)
    }
}

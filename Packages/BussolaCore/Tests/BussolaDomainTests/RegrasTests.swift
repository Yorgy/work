import Foundation
import Testing
@testable import BussolaDomain

@Suite("Capacidade — um planeador que ignora o calendário mente")
struct CapacityTests {

    @Test("O buffer de 40% sai do tempo que sobra, não do dia inteiro")
    func bufferSaiDoLivre() {
        let calc = CapacityCalculator(minutosUteisPorDia: 480, minutosDeFamilia: 90)
        // 3 horas de reuniões.
        let blocos = [BusyBlock(start: Fixo.data(2026, 9, 8, hora: 10),
                                end: Fixo.data(2026, 9, 8, hora: 13))]
        let c = calc.calcular(blocosOcupados: blocos)

        // 480 − 180 − 90 = 210 livres; buffer = 84; disponível = 126.
        #expect(c.committedMinutes == 180)
        #expect(c.bufferMinutes == 84)
        #expect(c.availableMinutes == 126)
    }

    @Test("Eventos não bloqueantes não consomem capacidade")
    func naoBloqueantes() {
        let calc = CapacityCalculator(minutosUteisPorDia: 480, minutosDeFamilia: 0)
        let blocos = [BusyBlock(start: Fixo.data(2026, 9, 8, hora: 9),
                                end: Fixo.data(2026, 9, 8, hora: 18),
                                bloqueia: false)]
        #expect(calc.calcular(blocosOcupados: blocos).committedMinutes == 0)
    }

    @Test("Um dia cheio não recebe Rocha — em vez de fingir que cabe um bloco profundo")
    func diaCheioNaoTemRocha() {
        let calc = CapacityCalculator(minutosUteisPorDia: 480, minutosDeFamilia: 90)
        let cheio = [BusyBlock(start: Fixo.data(2026, 9, 8, hora: 9),
                               end: Fixo.data(2026, 9, 8, hora: 16))]
        let capacidade = calc.calcular(blocosOcupados: cheio)
        #expect(calc.duracaoDeRocha(para: capacidade) == nil)
    }

    @Test("A Rocha nunca come mais de metade do disponível")
    func rochaNaoComeTudo() {
        let calc = CapacityCalculator(minutosUteisPorDia: 480, minutosDeFamilia: 0)
        let capacidade = calc.calcular(blocosOcupados: [])
        // 480 livres; buffer 192; disponível 288 → tecto 144 → limitado a 90.
        #expect(capacidade.availableMinutes == 288)
        #expect(calc.duracaoDeRocha(para: capacidade) == 90)
    }

    @Test("A capacidade nunca fica negativa")
    func nuncaNegativa() {
        let calc = CapacityCalculator(minutosUteisPorDia: 120, minutosDeFamilia: 90)
        let blocos = [BusyBlock(start: Fixo.data(2026, 9, 8, hora: 9),
                                end: Fixo.data(2026, 9, 8, hora: 17))]
        #expect(calc.calcular(blocosOcupados: blocos).availableMinutes == 0)
    }

    @Test("Descrição legível para o ecrã do ritual")
    func descricao() {
        #expect(Capacity(availableMinutes: 200, bufferMinutes: 0, committedMinutes: 0).descricao == "3h20")
        #expect(Capacity(availableMinutes: 180, bufferMinutes: 0, committedMinutes: 0).descricao == "3h")
    }
}

@Suite("Termómetro — mede atenção, não volume")
struct ThermometerTests {

    private func leituras(diasPorArea: [AreaID: Int?], tarefas: [TaskItem] = []) -> [AreaReading] {
        let areas = AreaID.allCases.map { id -> Area in
            let dias = diasPorArea[id] ?? nil
            return Area(id: id, lastTouchedAt: dias.map { Fixo.dias($0, antesDe: Fixo.segunda) })
        }
        return AreaThermometer().ler(
            areas: areas, tarefas: tarefas, pendentes: [],
            agora: Fixo.segunda, calendario: Fixo.calendario
        )
    }

    @Test("Os limiares mapeiam dias em temperatura")
    func limiares() {
        #expect(AreaThermometer.temperatura(paraDias: 0) == .viva)
        #expect(AreaThermometer.temperatura(paraDias: 3) == .viva)
        #expect(AreaThermometer.temperatura(paraDias: 4) == .arrefecer)
        #expect(AreaThermometer.temperatura(paraDias: 7) == .arrefecer)
        #expect(AreaThermometer.temperatura(paraDias: 8) == .fria)
        #expect(AreaThermometer.temperatura(paraDias: 14) == .fria)
        #expect(AreaThermometer.temperatura(paraDias: 15) == .escura)
        // Nunca tocada é escura, não desconhecida — obriga a decidir.
        #expect(AreaThermometer.temperatura(paraDias: nil) == .escura)
    }

    @Test("Uma área escura bloqueia o ritual")
    func areaEscuraBloqueia() {
        let lidas = leituras(diasPorArea: [.obras: 16, .agencia: 0, .clientes: 1,
                                           .familia: 2, .pessoal: 3])
        let bloqueios = AreaThermometer().bloqueios(lidas)
        #expect(bloqueios.count == 1)
        #expect(bloqueios.first?.area == .obras)
    }

    @Test("Uma pausa explícita desarma o bloqueio, mas a área continua visível")
    func pausaDesarma() {
        let areas = AreaID.allCases.map { id -> Area in
            Area(
                id: id,
                lastTouchedAt: Fixo.dias(30, antesDe: Fixo.segunda),
                pausadaAte: id == .obras ? Fixo.dias(30, depoisDe: Fixo.segunda) : nil
            )
        }
        let lidas = AreaThermometer().ler(
            areas: areas, tarefas: [], pendentes: [],
            agora: Fixo.segunda, calendario: Fixo.calendario
        )
        let obras = lidas.first { $0.area == .obras }
        #expect(obras?.temperatura == .escura)
        #expect(obras?.emPausa == true)
        #expect(obras?.bloqueiaRitual == false)
        #expect(lidas.count == AreaID.allCases.count)
    }

    @Test("As áreas mais frias vêm primeiro")
    func ordenacao() {
        let lidas = leituras(diasPorArea: [.agencia: 0, .clientes: 20, .familia: 5,
                                           .obras: 10, .pessoal: 1])
        #expect(lidas.first?.area == .clientes)
        #expect(lidas.last?.area == .agencia)
    }

    @Test("Conta tarefas abertas por área, ignorando as fechadas")
    func contagens() {
        let tarefas = [
            TaskItem.fake("a", area: .obras),
            TaskItem.fake("b", area: .obras, estado: .done),
            TaskItem.fake("c", area: .obras, estado: .waiting),
        ]
        let lidas = leituras(diasPorArea: [.obras: 2], tarefas: tarefas)
        let obras = lidas.first { $0.area == .obras }
        #expect(obras?.tarefasAbertas == 2)
    }

    @Test("A descrição do toque é legível — a cor nunca é o único sinal")
    func descricaoDoToque() {
        let lidas = leituras(diasPorArea: [.agencia: 0, .clientes: 1, .obras: 16])
        #expect(lidas.first { $0.area == .agencia }?.descricaoDoToque == "hoje")
        #expect(lidas.first { $0.area == .clientes }?.descricaoDoToque == "ontem")
        #expect(lidas.first { $0.area == .obras }?.descricaoDoToque == "há 16 dias")
    }
}

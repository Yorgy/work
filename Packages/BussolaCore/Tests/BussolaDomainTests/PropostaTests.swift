import Foundation
import Testing
@testable import BussolaDomain

@Suite("Proposta do plano — propõe, não decide")
struct PlanProposerTests {

    private let proposer = PlanProposer(calendario: Fixo.calendario)

    private func leituras(_ mapa: [AreaID: Int]) -> [AreaReading] {
        let areas = AreaID.allCases.map { id in
            Area(id: id, lastTouchedAt: Fixo.dias(mapa[id] ?? 0, antesDe: Fixo.segunda))
        }
        return AreaThermometer().ler(
            areas: areas, tarefas: [], pendentes: [],
            agora: Fixo.segunda, calendario: Fixo.calendario
        )
    }

    private var capacidadeFolgada: Capacity {
        Capacity(availableMinutes: 300, bufferMinutes: 120, committedMinutes: 0)
    }

    @Test("Entre duas tarefas iguais, ganha a da área mais fria")
    func friezaDesempata() {
        let quente = TaskItem.fake("Quente", area: .clientes)
        let fria = TaskItem.fake("Fria", area: .obras)

        let p = proposer.propor(
            tarefas: [quente, fria],
            leituras: leituras([.clientes: 0, .obras: 16]),
            capacidade: capacidadeFolgada,
            agora: Fixo.segunda
        )
        #expect(p.pedras.first?.task.id == fria.id)
        #expect(p.pedras.first?.razao == "Obras está fria")
    }

    @Test("Um prazo a vencer bate a frieza da área")
    func prazoDomina() {
        let urgente = TaskItem.fake("Urgente", area: .clientes, due: Fixo.segunda)
        let fria = TaskItem.fake("Fria", area: .obras)

        let p = proposer.propor(
            tarefas: [urgente, fria],
            leituras: leituras([.clientes: 0, .obras: 16]),
            capacidade: capacidadeFolgada,
            agora: Fixo.segunda
        )
        #expect(p.pedras.first?.task.id == urgente.id)
        #expect(p.pedras.first?.razao == "prazo a aproximar-se")
    }

    @Test("A proposta nunca produz três Pedras da mesma área")
    func nuncaProproeTresIguais() {
        // Cinco candidatas de Clientes, muito fortes, e uma fraca de outra área.
        var tarefas = (1...5).map {
            TaskItem.fake("Cliente \($0)", area: .clientes, due: Fixo.segunda)
        }
        tarefas.append(.fake("Obra fraca", area: .obras))

        let p = proposer.propor(
            tarefas: tarefas,
            leituras: leituras([.clientes: 0, .obras: 0]),
            capacidade: capacidadeFolgada,
            agora: Fixo.segunda
        )
        #expect(p.pedras.count == 3)
        #expect(Set(p.pedras.map(\.task.area)).count > 1)
    }

    @Test("Uma tarefa que desbloqueia outra pessoa sobe")
    func desbloqueioSobe() {
        let normal = TaskItem.fake("Normal", area: .clientes)
        let desbloqueia = TaskItem.fake("Manda preço ao empreiteiro",
                                        area: .clientes, desbloqueia: true)

        let p = proposer.propor(
            tarefas: [normal, desbloqueia],
            leituras: leituras([.clientes: 0]),
            capacidade: capacidadeFolgada,
            agora: Fixo.segunda
        )
        #expect(p.pedras.first?.task.id == desbloqueia.id)
    }

    @Test("Não há Rocha quando não há espaço para uma")
    func semEspacoSemRocha() {
        let apertada = Capacity(availableMinutes: 60, bufferMinutes: 40, committedMinutes: 380)
        let p = proposer.propor(
            tarefas: [.rocha("Profundo"), .fake("Pedra", area: .obras)],
            leituras: leituras([:]),
            capacidade: apertada,
            agora: Fixo.segunda
        )
        #expect(p.rocha == nil)
        #expect(p.pedras.isEmpty == false)
    }

    @Test("A Rocha não é reproposta como Pedra")
    func rochaNaoDuplica() {
        let r = TaskItem.rocha("Profundo", area: .clientes)
        let p = proposer.propor(
            tarefas: [r, .fake("Outra", area: .obras)],
            leituras: leituras([:]),
            capacidade: capacidadeFolgada,
            agora: Fixo.segunda
        )
        #expect(p.rocha?.task.id == r.id)
        #expect(p.pedras.contains { $0.task.id == r.id } == false)
    }

    @Test("Tarefas em espera e adiadas ficam de fora")
    func excluidas() {
        let tarefas = [
            TaskItem.fake("À espera", area: .obras, estado: .waiting),
            TaskItem.fake("Adiada", area: .obras, adiadaAte: Fixo.dias(3, depoisDe: Fixo.segunda)),
            TaskItem.fake("Boa", area: .obras),
        ]
        let p = proposer.propor(
            tarefas: tarefas, leituras: leituras([:]),
            capacidade: capacidadeFolgada, agora: Fixo.segunda
        )
        #expect(p.pedras.count == 1)
        #expect(p.pedras.first?.task.title == "Boa")
    }

    @Test("Uma área em pausa não recebe propostas")
    func areaEmPausaNaoEProposta() {
        let areas = AreaID.allCases.map { id in
            Area(id: id,
                 lastTouchedAt: Fixo.dias(20, antesDe: Fixo.segunda),
                 pausadaAte: id == .obras ? Fixo.dias(30, depoisDe: Fixo.segunda) : nil)
        }
        let lidas = AreaThermometer().ler(areas: areas, tarefas: [], pendentes: [],
                                          agora: Fixo.segunda, calendario: Fixo.calendario)
        let p = proposer.propor(
            tarefas: [.fake("Obra", area: .obras), .fake("Cliente", area: .clientes)],
            leituras: lidas, capacidade: capacidadeFolgada, agora: Fixo.segunda
        )
        #expect(p.pedras.contains { $0.task.area == .obras } == false)
        #expect(p.pedras.count == 1)
    }

    @Test("A Areia sai separada das Pedras")
    func areiaSeparada() {
        let p = proposer.propor(
            tarefas: [.fake("Rápida", area: .obras, minutos: 3),
                      .fake("Substancial", area: .clientes, minutos: 30)],
            leituras: leituras([:]), capacidade: capacidadeFolgada, agora: Fixo.segunda
        )
        #expect(p.areia.count == 1)
        #expect(p.pedras.count == 1)
        #expect(p.pedras.first?.task.title == "Substancial")
    }

    @Test("A urgência satura no prazo e anula-se a 30 dias")
    func curvaDeUrgencia() {
        let hoje = TaskItem.fake("Hoje", due: Fixo.segunda)
        let atrasada = TaskItem.fake("Atrasada", due: Fixo.dias(5, antesDe: Fixo.segunda))
        let longe = TaskItem.fake("Longe", due: Fixo.dias(40, depoisDe: Fixo.segunda))

        #expect(proposer.urgencia(hoje, agora: Fixo.segunda) == 1)
        #expect(proposer.urgencia(atrasada, agora: Fixo.segunda) == 1)
        #expect(proposer.urgencia(longe, agora: Fixo.segunda) == 0)
        #expect(proposer.urgencia(.fake("Sem prazo"), agora: Fixo.segunda) == 0)
    }

    @Test("Áreas escuras chegam à proposta como bloqueios")
    func bloqueiosPassam() {
        let p = proposer.propor(
            tarefas: [.fake("x", area: .clientes)],
            leituras: leituras([.obras: 20, .clientes: 0, .agencia: 0,
                                .familia: 0, .pessoal: 0]),
            capacidade: capacidadeFolgada, agora: Fixo.segunda
        )
        #expect(p.bloqueios.map(\.area) == [.obras])
    }
}

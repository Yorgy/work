import Foundation
import Testing
@testable import BussolaDomain

@Suite("Plano do dia — os invariantes que dão sentido ao sistema")
struct DayPlanTests {

    private func builder(capacidade: Int = 240) -> DayPlanBuilder {
        DayPlanBuilder(date: Fixo.segunda, capacityMinutes: capacidade, calendario: Fixo.calendario)
    }

    @Test("A quarta Pedra é recusada — o limite não é uma sugestão")
    func limiteDePedras() throws {
        var b = builder()
        try b.acrescentarPedra(.fake("1", area: .agencia), em: Fixo.segunda)
        try b.acrescentarPedra(.fake("2", area: .obras), em: Fixo.segunda)
        try b.acrescentarPedra(.fake("3", area: .familia), em: Fixo.segunda)

        #expect(b.pebbles.count == 3)
        #expect(throws: PlanError.pedrasCheias(limite: 3)) {
            try b.acrescentarPedra(.fake("4", area: .pessoal), em: Fixo.segunda)
        }
    }

    @Test("Três Pedras da mesma área são recusadas — sem isto, o trabalho engole tudo")
    func rotacaoDeAreas() throws {
        var b = builder()
        try b.acrescentarPedra(.fake("1", area: .clientes), em: Fixo.segunda)
        try b.acrescentarPedra(.fake("2", area: .clientes), em: Fixo.segunda)

        #expect(throws: PlanError.todasDaMesmaArea(.clientes)) {
            try b.acrescentarPedra(.fake("3", area: .clientes), em: Fixo.segunda)
        }
        // Mas duas da mesma área e uma diferente passam.
        try b.acrescentarPedra(.fake("3", area: .obras), em: Fixo.segunda)
        #expect(b.pebbles.count == 3)
    }

    @Test("Sem âncora, o plano não fecha")
    func ancoraObrigatoria() throws {
        var b = builder()
        let semAncora = TaskItem.fake("Sem quando nem onde", ancorada: false)
        try b.acrescentarPedra(semAncora, em: Fixo.segunda)

        #expect(b.semAncora.count == 1)
        #expect(b.estaPronto == false)
        #expect(throws: PlanError.semAncora(taskID: semAncora.id)) {
            _ = try b.construir()
        }
    }

    @Test("A Rocha tem de ser trabalho profundo de pelo menos 45 minutos")
    func rochaEProfunda() throws {
        var b = builder()
        #expect(throws: (any Error).self) {
            try b.definirRocha(.fake("Rápida", minutos: 15, energia: .admin), em: Fixo.segunda)
        }
        try b.definirRocha(.rocha(), em: Fixo.segunda)
        #expect(b.rock != nil)
    }

    @Test("Uma tarefa adiada não entra no plano")
    func tarefaAdiada() throws {
        var b = builder()
        let adiada = TaskItem.fake("Só para a semana", adiadaAte: Fixo.dias(5, depoisDe: Fixo.segunda))
        #expect(throws: PlanError.tarefaIndisponivel(taskID: adiada.id)) {
            try b.acrescentarPedra(adiada, em: Fixo.segunda)
        }
    }

    @Test("A mesma tarefa não entra duas vezes")
    func semDuplicados() throws {
        var b = builder()
        let t = TaskItem.fake("Única")
        try b.acrescentarPedra(t, em: Fixo.segunda)
        #expect(throws: PlanError.tarefaJaNoPlano(taskID: t.id)) {
            try b.acrescentarPedra(t, em: Fixo.segunda)
        }
    }

    @Test("Substituir é o gesto que o ritual oferece quando o limite está cheio")
    func substituirPedra() throws {
        var b = builder()
        let velha = TaskItem.fake("Velha", area: .agencia)
        try b.acrescentarPedra(velha, em: Fixo.segunda)
        try b.acrescentarPedra(.fake("2", area: .obras), em: Fixo.segunda)
        try b.acrescentarPedra(.fake("3", area: .familia), em: Fixo.segunda)

        let nova = TaskItem.fake("Nova", area: .pessoal)
        try b.substituirPedra(velha.id, por: nova, em: Fixo.segunda)

        #expect(b.pebbles.count == 3)
        #expect(b.contem(nova.id))
        #expect(!b.contem(velha.id))
        // A ordem preserva-se: a nova ocupa a posição da que saiu.
        #expect(b.pebbles.first?.id == nova.id)
    }

    @Test("Reordenar preserva Pedras omitidas da ordem recebida")
    func reordenarTolerante() throws {
        var b = builder()
        let a = TaskItem.fake("A", area: .agencia)
        let c = TaskItem.fake("C", area: .obras)
        let d = TaskItem.fake("D", area: .familia)
        try b.acrescentarPedra(a, em: Fixo.segunda)
        try b.acrescentarPedra(c, em: Fixo.segunda)
        try b.acrescentarPedra(d, em: Fixo.segunda)

        b.reordenarPedras([d.id, a.id])   // omite `c` de propósito

        #expect(b.pebbles.map(\.id) == [d.id, a.id, c.id])
    }

    @Test("Exceder a capacidade avisa, não bloqueia — o limite duro é 1+3")
    func capacidadeAvisa() throws {
        var b = builder(capacidade: 60)
        try b.acrescentarPedra(.fake("1", area: .agencia, minutos: 45), em: Fixo.segunda)
        try b.acrescentarPedra(.fake("2", area: .obras, minutos: 45), em: Fixo.segunda)

        #expect(b.excedeCapacidade)
        #expect(b.minutosEmExcesso == 30)
        // E mesmo assim constrói: a decisão é do humano.
        #expect(throws: Never.self) { _ = try b.construir() }
    }

    @Test("A ordem de execução põe a Rocha primeiro")
    func ordemDeExecucao() throws {
        var b = builder()
        let r = TaskItem.rocha("A Rocha")
        let p = TaskItem.fake("Pedra", area: .obras)
        try b.definirRocha(r, em: Fixo.segunda)
        try b.acrescentarPedra(p, em: Fixo.segunda)

        let plano = try b.construir()
        #expect(plano.ordemDeExecucao == [r.id, p.id])
        #expect(plano.contem(p.id))
    }

    @Test("A Areia entra sem ocupar lugar de Pedra")
    func areia() throws {
        var b = builder()
        b.acrescentarAreia(.fake("Rápida", minutos: 3))
        b.acrescentarAreia(.fake("Não é areia", minutos: 30))  // ignorada

        #expect(b.sand.count == 1)
        #expect(b.pebbles.isEmpty)
    }
}

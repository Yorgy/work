import Foundation
import Testing
@testable import BussolaDomain

@Suite("Ponte com os Lembretes — reconciliação")
struct ReminderReconcilerTests {

    private let reconciler = ReminderReconciler(area: .familia)

    private func tarefaFamilia(
        _ titulo: String = "Comprar fraldas",
        externalID: String? = nil,
        due: Date? = nil,
        notas: String = "",
        estado: TaskStatus = .next,
        actualizada: Date = Fixo.segunda
    ) -> TaskItem {
        TaskItem(
            title: titulo, notes: notas, area: .familia, status: estado,
            dueDate: due, externalID: externalID,
            createdAt: Fixo.dias(1, antesDe: Fixo.segunda), updatedAt: actualizada
        )
    }

    private func lembrete(
        _ id: String = "R1",
        titulo: String = "Comprar fraldas",
        notas: String = "",
        due: Date? = nil,
        feito: Bool = false,
        modificado: Date = Fixo.segunda
    ) -> ReminderMirror {
        ReminderMirror(
            externalID: id, title: titulo, notes: notas,
            dueDate: due, completed: feito, lastModified: modificado
        )
    }

    // MARK: - Criação

    @Test("Uma tarefa de Família sem espelho vira lembrete")
    func criaLembrete() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia()], lembretes: [], agora: Fixo.segunda
        )
        #expect(accoes.count == 1)
        if case .criarLembrete(let t) = accoes[0] {
            #expect(t.title == "Comprar fraldas")
        } else {
            Issue.record("esperava criarLembrete, veio \(accoes[0])")
        }
    }

    @Test("Tarefas de outras áreas não atravessam a ponte")
    func soFamilia() {
        let outras = AreaID.allCases.filter { $0 != .familia }.map {
            TaskItem(title: "x", area: $0, createdAt: Fixo.segunda)
        }
        #expect(reconciler.reconciliar(tarefas: outras, lembretes: [], agora: Fixo.segunda).isEmpty)
    }

    @Test("Uma tarefa já concluída não vai criar lembrete só para o fechar")
    func naoCriaLembreteDeTarefaFeita() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia(estado: .done)], lembretes: [], agora: Fixo.segunda
        )
        #expect(accoes.isEmpty)
    }

    @Test("Um lembrete que a esposa criou entra como captura por triar")
    func lembreteNovoEntraNaInbox() {
        let accoes = reconciler.reconciliar(
            tarefas: [], lembretes: [lembrete("R9", titulo: "Marcar creche")], agora: Fixo.segunda
        )
        #expect(accoes.count == 1)
        guard case .criarTarefa(let espelho) = accoes[0] else {
            Issue.record("esperava criarTarefa"); return
        }
        let nova = reconciler.tarefa(de: espelho, agora: Fixo.segunda)
        // Passa pelo ritual como qualquer captura tua. É isto que impede a lista
        // partilhada de entrar directamente no teu dia.
        #expect(nova.status == .inbox)
        #expect(nova.area == .familia)
        #expect(nova.externalID == "R9")
    }

    @Test("Um lembrete que já chega concluído não se importa")
    func lembreteFeitoNaoEntra() {
        let accoes = reconciler.reconciliar(
            tarefas: [], lembretes: [lembrete(feito: true)], agora: Fixo.segunda
        )
        #expect(accoes.isEmpty)
    }

    // MARK: - Conflitos

    @Test("Nada mudou dos dois lados: não se escreve nada")
    func semRuido() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia(externalID: "R1")],
            lembretes: [lembrete("R1")],
            agora: Fixo.segunda
        )
        // Sem isto, cada passagem escrevia dos dois lados e os timestamps
        // entravam em ping-pong entre os dispositivos.
        #expect(accoes.isEmpty)
    }

    @Test("O lado mais recente ganha — lembrete mais novo")
    func lembreteGanha() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia(externalID: "R1", actualizada: Fixo.dias(2, antesDe: Fixo.segunda))],
            lembretes: [lembrete("R1", titulo: "Comprar fraldas e toalhitas")],
            agora: Fixo.segunda
        )
        guard case .actualizarTarefa(let t) = accoes.first else {
            Issue.record("esperava actualizarTarefa, veio \(String(describing: accoes.first))"); return
        }
        #expect(t.title == "Comprar fraldas e toalhitas")
        #expect(t.updatedAt == Fixo.segunda)
    }

    @Test("O lado mais recente ganha — tarefa mais nova")
    func tarefaGanha() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia("Título novo", externalID: "R1", actualizada: Fixo.segunda)],
            lembretes: [lembrete("R1", modificado: Fixo.dias(3, antesDe: Fixo.segunda))],
            agora: Fixo.segunda
        )
        guard case .actualizarLembrete(let t) = accoes.first else {
            Issue.record("esperava actualizarLembrete"); return
        }
        #expect(t.title == "Título novo")
    }

    @Test("Concluir vence a data — alguém fez mesmo o trabalho")
    func concluirVence() {
        // O lembrete está desactualizado no título mas foi marcado como feito.
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia("Título mais recente", externalID: "R1", actualizada: Fixo.segunda)],
            lembretes: [lembrete("R1", titulo: "antigo", feito: true,
                                 modificado: Fixo.dias(5, antesDe: Fixo.segunda))],
            agora: Fixo.segunda
        )
        #expect(accoes.count == 1)
        if case .concluirTarefa = accoes[0] {} else {
            Issue.record("esperava concluirTarefa, veio \(accoes[0])")
        }
    }

    @Test("Concluir propaga-se também no sentido inverso")
    func concluirPropagaParaOLembrete() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia(externalID: "R1", estado: .done)],
            lembretes: [lembrete("R1")],
            agora: Fixo.segunda
        )
        #expect(accoes == [.concluirLembrete("R1")])
    }

    @Test("Concluído dos dois lados não gera trabalho")
    func ambosFeitos() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia(externalID: "R1", estado: .done)],
            lembretes: [lembrete("R1", feito: true)],
            agora: Fixo.segunda
        )
        #expect(accoes.isEmpty)
    }

    // MARK: - Desaparecimentos

    @Test("Um lembrete apagado NUNCA apaga a tarefa — só lhe tira o espelho")
    func nuncaApagaDados() {
        let tarefa = tarefaFamilia(externalID: "R1")
        let accoes = reconciler.reconciliar(
            tarefas: [tarefa], lembretes: [], agora: Fixo.segunda
        )
        // "O lembrete sumiu" tanto pode ser um apagamento deliberado como a
        // lista ter deixado de estar partilhada. Apagar dados por causa de uma
        // sincronização é a pior falha que este sistema pode ter.
        #expect(accoes == [.desligarEspelho(tarefa.id)])
    }

    @Test("Uma tarefa largada não ressuscita como lembrete")
    func largadaFicaLargada() {
        let accoes = reconciler.reconciliar(
            tarefas: [tarefaFamilia(estado: .dropped)], lembretes: [], agora: Fixo.segunda
        )
        #expect(accoes.isEmpty)
    }

    // MARK: - Propriedades

    @Test("Datas iguais ao segundo não contam como alteração")
    func toleranciaDeData() {
        let base = Fixo.data(2026, 9, 10)
        #expect(reconciler.mesmaData(base, base.addingTimeInterval(0.4)))
        #expect(!reconciler.mesmaData(base, base.addingTimeInterval(120)))
        #expect(reconciler.mesmaData(nil, nil))
        #expect(!reconciler.mesmaData(base, nil))
    }

    @Test("Reconciliar é idempotente: correr duas vezes não gera mais trabalho")
    func idempotencia() {
        var tarefa = tarefaFamilia(externalID: "R1", actualizada: Fixo.dias(2, antesDe: Fixo.segunda))
        let espelho = lembrete("R1", titulo: "Mudado pela Ana")

        let primeira = reconciler.reconciliar(
            tarefas: [tarefa], lembretes: [espelho], agora: Fixo.segunda
        )
        #expect(primeira.count == 1)

        // Aplica-se a acção e volta a correr.
        if case .actualizarTarefa(let t) = primeira[0] { tarefa = t }
        let segunda = reconciler.reconciliar(
            tarefas: [tarefa], lembretes: [espelho], agora: Fixo.segunda
        )
        #expect(segunda.isEmpty)
    }

    @Test("Uma lista grande dos dois lados não produz acções a mais")
    func escala() {
        let tarefas = (0..<50).map { tarefaFamilia("T\($0)", externalID: "R\($0)") }
        let lembretes = (0..<50).map { lembrete("R\($0)", titulo: "T\($0)") }
        #expect(reconciler.reconciliar(
            tarefas: tarefas, lembretes: lembretes, agora: Fixo.segunda
        ).isEmpty)
    }
}

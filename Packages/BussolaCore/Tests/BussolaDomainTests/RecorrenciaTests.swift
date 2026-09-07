import Foundation
import Testing
@testable import BussolaDomain

@Suite("Recorrências — o motor fiscal e doméstico")
struct RecurrenceTests {

    private func componentes(_ data: Date?) -> DateComponents? {
        data.map { Fixo.calendario.dateComponents([.year, .month, .day], from: $0) }
    }

    @Test("O IVA trimestral aponta para o próximo mês de entrega")
    func ivaTrimestral() {
        let iva = RecurrenceTemplate(
            title: "IVA", area: .agencia,
            rule: .emMeses(meses: [2, 5, 9, 11], dia: 20)
        )
        // A 7 de Setembro, o próximo é 20 de Setembro.
        let c = componentes(iva.proximaOcorrencia(depoisDe: Fixo.segunda, calendario: Fixo.calendario))
        #expect(c?.month == 9 && c?.day == 20)

        // A 25 de Setembro, já passou: o próximo é 20 de Novembro.
        let depois = iva.proximaOcorrencia(
            depoisDe: Fixo.data(2026, 9, 25), calendario: Fixo.calendario
        )
        #expect(componentes(depois)?.month == 11)
    }

    @Test("A viragem de ano não parte a regra")
    func viragemDeAno() {
        let modelo = RecurrenceTemplate(
            title: "Modelo 22", area: .agencia, rule: .anual(mes: 5, dia: 31)
        )
        let c = componentes(modelo.proximaOcorrencia(
            depoisDe: Fixo.data(2026, 12, 20), calendario: Fixo.calendario
        ))
        #expect(c?.year == 2027 && c?.month == 5 && c?.day == 31)
    }

    @Test("A tarefa aparece com a antecedência configurada, não no prazo")
    func antecedencia() {
        let iva = RecurrenceTemplate(
            title: "Preparar IVA", area: .agencia,
            rule: .emMeses(meses: [9], dia: 20), leadDays: 12
        )
        // 20 − 12 = 8 de Setembro. A 7, ainda é cedo.
        #expect(iva.gerarSeDevido(em: Fixo.data(2026, 9, 7), calendario: Fixo.calendario) == nil)

        let gerada = iva.gerarSeDevido(em: Fixo.data(2026, 9, 9), calendario: Fixo.calendario)
        #expect(gerada != nil)
        #expect(componentes(gerada?.dueDate)?.day == 20)
        #expect(gerada?.area == .agencia)
    }

    @Test("A origem da data viaja com a tarefa — uma data sem origem não é confiável")
    func origemDaData() {
        let modelo = RecurrenceTemplate(
            title: "IES", area: .agencia, rule: .anual(mes: 7, dia: 15),
            leadDays: 365, fonteDaData: "Até 15 de Julho. Confirmar com o contabilista."
        )
        let gerada = modelo.gerarSeDevido(em: Fixo.segunda, calendario: Fixo.calendario)
        #expect(gerada?.notes.contains("Confirmar com o contabilista") == true)
    }

    @Test("Um modelo desligado não gera nada")
    func desligado() {
        let modelo = RecurrenceTemplate(
            title: "x", area: .agencia, rule: .mensal(dia: 1), leadDays: 365, enabled: false
        )
        #expect(modelo.gerarSeDevido(em: Fixo.segunda, calendario: Fixo.calendario) == nil)
    }

    @Test("Dias impossíveis não escorregam para o mês seguinte")
    func diaImpossivel() {
        let modelo = RecurrenceTemplate(
            title: "x", area: .pessoal, rule: .anual(mes: 2, dia: 30)
        )
        #expect(modelo.proximaOcorrencia(depoisDe: Fixo.segunda, calendario: Fixo.calendario) == nil)
    }

    @Test("O calendário fiscal traz as obrigações com origem documentada")
    func calendarioFiscal() {
        let modelos = CalendarioFiscalPT.modelos()
        #expect(modelos.count >= 7)
        #expect(modelos.allSatisfy { $0.area == .agencia })
        #expect(modelos.allSatisfy { !$0.fonteDaData.isEmpty })
        #expect(modelos.allSatisfy {
            $0.proximaOcorrencia(depoisDe: Fixo.segunda, calendario: Fixo.calendario) != nil
        })
    }
}

@Suite("À espera de — a dívida que se cobra")
struct WaitingForTests {

    @Test("O canal determina quando se insiste")
    func ritmoPorCanal() {
        let email = WaitingFor(taskID: UUID(), owner: "Vítor", channel: .email,
                               requestedAt: Fixo.segunda, calendario: Fixo.calendario)
        #expect(Fixo.calendario.dateComponents([.day], from: Fixo.segunda, to: email.followUpAt).day == 3)

        let formal = WaitingFor(taskID: UUID(), owner: "Contabilista", channel: .formal,
                                requestedAt: Fixo.segunda, calendario: Fixo.calendario)
        #expect(Fixo.calendario.dateComponents([.day], from: Fixo.segunda, to: formal.followUpAt).day == 7)
    }

    @Test("Vencidos saem ordenados por dias de silêncio")
    func ordenadosPorSilencio() {
        let antigo = WaitingFor(taskID: UUID(), owner: "A", channel: .email,
                                requestedAt: Fixo.dias(20, antesDe: Fixo.segunda),
                                calendario: Fixo.calendario)
        let recente = WaitingFor(taskID: UUID(), owner: "B", channel: .email,
                                 requestedAt: Fixo.dias(5, antesDe: Fixo.segunda),
                                 calendario: Fixo.calendario)
        let futuro = WaitingFor(taskID: UUID(), owner: "C", channel: .email,
                                requestedAt: Fixo.segunda, calendario: Fixo.calendario)

        let vencidos = FollowUpPolicy.vencidos([recente, futuro, antigo], em: Fixo.segunda)
        #expect(vencidos.map(\.owner) == ["A", "B"])
    }

    @Test("Um pendente resolvido sai da lista")
    func resolvidoSai() {
        let resolvido = WaitingFor(taskID: UUID(), owner: "A", channel: .email,
                                   requestedAt: Fixo.dias(20, antesDe: Fixo.segunda),
                                   resolvedAt: Fixo.segunda, calendario: Fixo.calendario)
        #expect(FollowUpPolicy.vencidos([resolvido], em: Fixo.segunda).isEmpty)
    }

    @Test("Insistir reagenda a próxima insistência")
    func insistirReagenda() {
        var p = WaitingFor(taskID: UUID(), owner: "Vítor", channel: .mensagem,
                           requestedAt: Fixo.segunda, calendario: Fixo.calendario)
        #expect(p.followUpCount == 0)
        p.registarFollowUp(em: Fixo.segunda, calendario: Fixo.calendario)
        #expect(p.followUpCount == 1)
        #expect(Fixo.calendario.dateComponents([.day], from: Fixo.segunda, to: p.followUpAt).day == 2)
    }

    @Test("Ao fim de três insistências, o problema mudou de dono")
    func exigeDecisao() {
        var p = WaitingFor(taskID: UUID(), owner: "Vítor", requestedAt: Fixo.segunda,
                           calendario: Fixo.calendario)
        #expect(!FollowUpPolicy.exigeDecisao(p))
        for _ in 0..<3 { p.registarFollowUp(em: Fixo.segunda, calendario: Fixo.calendario) }
        #expect(FollowUpPolicy.exigeDecisao(p))
    }

    @Test("O rascunho endurece com o número de insistências")
    func rascunhoEndurece() {
        var p = WaitingFor(taskID: UUID(), owner: "Vítor", requestedAt: Fixo.segunda,
                           calendario: Fixo.calendario)
        #expect(FollowUpPolicy.rascunho(para: p, assunto: "o orçamento").contains("Vítor"))
        p.followUpCount = 3
        #expect(FollowUpPolicy.rascunho(para: p, assunto: "o orçamento").contains("esta semana"))
    }
}

@Suite("Projectos — o defeito silencioso")
struct ProjectAuditTests {

    @Test("Um projecto activo sem próxima acção é sinalizado")
    func semProximaAccao() {
        let p = Project(name: "Site do cliente X", area: .clientes, createdAt: Fixo.dias(30, antesDe: Fixo.segunda))
        let parados = ProjectAudit.semProximaAccao(
            projectos: [p], tarefas: [], agora: Fixo.segunda, calendario: Fixo.calendario
        )
        #expect(parados.count == 1)
        #expect(parados.first?.diasParado == 30)
    }

    @Test("Uma tarefa em espera não conta como próxima acção — não é trabalho teu")
    func esperaNaoConta() {
        let p = Project(name: "Obra", area: .obras, createdAt: Fixo.dias(10, antesDe: Fixo.segunda))
        var t = TaskItem.fake("À espera do preço", area: .obras, estado: .waiting)
        t.projectID = p.id

        let parados = ProjectAudit.semProximaAccao(
            projectos: [p], tarefas: [t], agora: Fixo.segunda, calendario: Fixo.calendario
        )
        #expect(parados.count == 1)
    }

    @Test("Com uma acção disponível, o projecto está são")
    func projectoSao() {
        let p = Project(name: "Obra", area: .obras)
        var t = TaskItem.fake("Pedir preço", area: .obras)
        t.projectID = p.id

        let parados = ProjectAudit.semProximaAccao(
            projectos: [p], tarefas: [t], agora: Fixo.segunda, calendario: Fixo.calendario
        )
        #expect(parados.isEmpty)
    }

    @Test("Projectos pausados e fechados não são auditados")
    func naoAuditaInactivos() {
        let projectos = [
            Project(name: "A", area: .obras, status: .paused),
            Project(name: "B", area: .obras, status: .done),
            Project(name: "C", area: .obras, status: .dropped),
        ]
        let parados = ProjectAudit.semProximaAccao(
            projectos: projectos, tarefas: [], agora: Fixo.segunda, calendario: Fixo.calendario
        )
        #expect(parados.isEmpty)
    }

    @Test("Os mais parados vêm primeiro")
    func ordenacao() {
        let velho = Project(name: "Velho", area: .obras, createdAt: Fixo.dias(60, antesDe: Fixo.segunda))
        let novo = Project(name: "Novo", area: .clientes, createdAt: Fixo.dias(5, antesDe: Fixo.segunda))
        let parados = ProjectAudit.semProximaAccao(
            projectos: [novo, velho], tarefas: [], agora: Fixo.segunda, calendario: Fixo.calendario
        )
        #expect(parados.map(\.project.name) == ["Velho", "Novo"])
    }
}

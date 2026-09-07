import Foundation

/// Como uma obrigação se repete.
public enum RecurrenceRule: Sendable, Hashable, Codable {
    /// Todos os meses, num dia fixo.
    case mensal(dia: Int)
    /// Em meses específicos do ano, num dia fixo. Meses 1…12.
    case emMeses(meses: [Int], dia: Int)
    /// Uma vez por ano.
    case anual(mes: Int, dia: Int)
    /// De N em N dias, a contar da última ocorrência.
    case cadaNDias(Int)
}

/// Gera tarefas com antecedência a partir de uma regra.
///
/// Cobre tanto o IVA trimestral como a inspecção do carro ou o pagamento da
/// creche. É a dimensão **temporal** do financeiro — a única que entra na v1,
/// por ADR-008.
public struct RecurrenceTemplate: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var area: AreaID
    public var rule: RecurrenceRule

    /// Com quantos dias de antecedência a tarefa aparece na Inbox.
    /// "Preparar IVA do 3.º trimestre" tem de aparecer a 10 de Novembro, não a 25.
    public var leadDays: Int

    public var estimatedMinutes: Int
    public var energy: Energy

    /// Origem da data, textual. Uma data sem origem não é confiável, e um
    /// sistema com datas fiscais não confiáveis é um passivo, não um activo.
    public var fonteDaData: String

    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        area: AreaID,
        rule: RecurrenceRule,
        leadDays: Int = 10,
        estimatedMinutes: Int = 30,
        energy: Energy = .admin,
        fonteDaData: String = "",
        enabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.area = area
        self.rule = rule
        self.leadDays = leadDays
        self.estimatedMinutes = estimatedMinutes
        self.energy = energy
        self.fonteDaData = fonteDaData
        self.enabled = enabled
    }

    /// Próxima data-limite estritamente depois de `depoisDe`.
    public func proximaOcorrencia(
        depoisDe referencia: Date,
        calendario: Calendar = .current
    ) -> Date? {
        switch rule {
        case .mensal(let dia):
            return proximaComDia(dia, emMeses: Array(1...12), depoisDe: referencia, calendario: calendario)
        case .emMeses(let meses, let dia):
            return proximaComDia(dia, emMeses: meses, depoisDe: referencia, calendario: calendario)
        case .anual(let mes, let dia):
            return proximaComDia(dia, emMeses: [mes], depoisDe: referencia, calendario: calendario)
        case .cadaNDias(let n):
            guard n > 0 else { return nil }
            return calendario.date(byAdding: .day, value: n, to: referencia)
        }
    }

    /// A data em que a tarefa deve aparecer na Inbox.
    public func dataDeAparecimento(
        paraLimite limite: Date,
        calendario: Calendar = .current
    ) -> Date {
        calendario.date(byAdding: .day, value: -leadDays, to: limite) ?? limite
    }

    /// Gera a tarefa, se estiver na altura de ela aparecer.
    /// Devolve `nil` quando ainda é cedo — a tarefa existe, mas não se mostra.
    public func gerarSeDevido(
        em agora: Date = Date(),
        calendario: Calendar = .current
    ) -> TaskItem? {
        guard enabled else { return nil }
        guard let limite = proximaOcorrencia(depoisDe: agora, calendario: calendario) else { return nil }
        let aparece = dataDeAparecimento(paraLimite: limite, calendario: calendario)
        guard aparece <= agora else { return nil }

        let notas = fonteDaData.isEmpty ? "" : "Origem da data: \(fonteDaData)"
        return TaskItem(
            title: title,
            notes: notas,
            area: area,
            status: .next,
            energy: energy,
            estimatedMinutes: estimatedMinutes,
            dueDate: limite,
            recurrenceID: id,
            createdAt: agora
        )
    }

    private func proximaComDia(
        _ dia: Int,
        emMeses meses: [Int],
        depoisDe referencia: Date,
        calendario: Calendar
    ) -> Date? {
        let mesesOrdenados = meses.filter { (1...12).contains($0) }.sorted()
        guard !mesesOrdenados.isEmpty, (1...31).contains(dia) else { return nil }

        let anoBase = calendario.component(.year, from: referencia)
        // Dois anos de janela chegam para apanhar a viragem de ano.
        for ano in [anoBase, anoBase + 1] {
            for mes in mesesOrdenados {
                var componentes = DateComponents()
                componentes.year = ano
                componentes.month = mes
                componentes.day = dia
                componentes.hour = 9
                guard let candidata = calendario.date(from: componentes) else { continue }
                if candidata > referencia { return candidata }
            }
        }
        return nil
    }
}

/// Obrigações fiscais portuguesas, como ponto de partida.
///
/// > Estas datas **não são fonte de verdade**. O regime concreto da empresa
/// > (mensal vs. trimestral, isenções, prorrogações) altera-as, e a app mostra
/// > sempre a origem de cada uma para se poder confirmar e editar.
/// > Confirmar com o contabilista e no Portal das Finanças.
public enum CalendarioFiscalPT {
    public static func modelos() -> [RecurrenceTemplate] {
        [
            RecurrenceTemplate(
                title: "Entregar declaração periódica de IVA (trimestral)",
                area: .agencia,
                rule: .emMeses(meses: [2, 5, 9, 11], dia: 20),
                leadDays: 12,
                estimatedMinutes: 60,
                fonteDaData: "Regime trimestral: entrega até dia 20 do 2.º mês seguinte ao trimestre. Confirmar com o contabilista."
            ),
            RecurrenceTemplate(
                title: "Pagar IVA (trimestral)",
                area: .agencia,
                rule: .emMeses(meses: [2, 5, 9, 11], dia: 25),
                leadDays: 5,
                estimatedMinutes: 15,
                fonteDaData: "Pagamento até dia 25 do mesmo mês da entrega."
            ),
            RecurrenceTemplate(
                title: "Retenções na fonte de IRS/IRC do mês anterior",
                area: .agencia,
                rule: .mensal(dia: 20),
                leadDays: 6,
                estimatedMinutes: 30,
                fonteDaData: "Até dia 20 do mês seguinte ao da retenção."
            ),
            RecurrenceTemplate(
                title: "Segurança Social — declaração e pagamento",
                area: .agencia,
                rule: .mensal(dia: 20),
                leadDays: 8,
                estimatedMinutes: 30,
                fonteDaData: "Declaração de remunerações até dia 10; pagamento entre 10 e 20 do mês seguinte."
            ),
            RecurrenceTemplate(
                title: "Modelo 22 (IRC)",
                area: .agencia,
                rule: .anual(mes: 5, dia: 31),
                leadDays: 30,
                estimatedMinutes: 90,
                energy: .deep,
                fonteDaData: "Até 31 de Maio do ano seguinte ao exercício."
            ),
            RecurrenceTemplate(
                title: "IES — Informação Empresarial Simplificada",
                area: .agencia,
                rule: .anual(mes: 7, dia: 15),
                leadDays: 21,
                estimatedMinutes: 60,
                fonteDaData: "Até 15 de Julho."
            ),
            RecurrenceTemplate(
                title: "Pagamento por conta de IRC",
                area: .agencia,
                rule: .emMeses(meses: [7, 9, 12], dia: 31),
                leadDays: 10,
                estimatedMinutes: 20,
                fonteDaData: "Julho, Setembro e Dezembro. Confirmar valores com o contabilista."
            ),
        ]
    }
}

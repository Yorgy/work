import Foundation
@testable import BussolaDomain

/// Calendário fixo em Lisboa, para os testes de data não dependerem de onde
/// correm nem de quando correm.
enum Fixo {
    static var calendario: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Lisbon") ?? .gmt
        c.locale = Locale(identifier: "pt_PT")
        return c
    }()

    /// Uma segunda-feira, para os testes de dia da semana serem legíveis.
    static let segunda = data(2026, 9, 7, hora: 21)

    static func data(_ ano: Int, _ mes: Int, _ dia: Int, hora: Int = 9) -> Date {
        var c = DateComponents()
        c.year = ano; c.month = mes; c.day = dia; c.hour = hora
        return calendario.date(from: c)!
    }

    static func dias(_ n: Int, antesDe referencia: Date) -> Date {
        calendario.date(byAdding: .day, value: -n, to: referencia)!
    }

    static func dias(_ n: Int, depoisDe referencia: Date) -> Date {
        calendario.date(byAdding: .day, value: n, to: referencia)!
    }
}

extension TaskItem {
    /// Tarefa de teste com o mínimo de ruído no local de chamada.
    static func fake(
        _ titulo: String = "Tarefa",
        area: AreaID = .clientes,
        minutos: Int = 15,
        energia: Energy = .shallow,
        due: Date? = nil,
        criada: Date = Fixo.segunda,
        ancorada: Bool = true,
        desbloqueia: Bool = false,
        estado: TaskStatus = .next,
        adiadaAte: Date? = nil
    ) -> TaskItem {
        TaskItem(
            title: titulo,
            area: area,
            status: estado,
            energy: energia,
            estimatedMinutes: minutos,
            dueDate: due,
            defersUntil: adiadaAte,
            anchor: ancorada ? Anchor(quando: "depois do café", onde: "no escritório") : nil,
            unblocksOthers: desbloqueia,
            createdAt: criada
        )
    }

    /// Uma candidata a Rocha: profunda e com duração de bloco.
    static func rocha(
        _ titulo: String = "Trabalho profundo",
        area: AreaID = .clientes,
        minutos: Int = 90,
        criada: Date = Fixo.segunda
    ) -> TaskItem {
        .fake(titulo, area: area, minutos: minutos, energia: .deep, criada: criada)
    }
}

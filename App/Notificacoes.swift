import Foundation
import UserNotifications
import BussolaDomain

/// Exactamente três notificações. Não quatro.
///
/// Uma app de organização que interrompe é uma contradição, e a quarta
/// notificação é sempre aquela em que se desliga tudo — e com tudo desligado
/// perde-se também a das 21h, que é a única que interessa mesmo.
public enum Notificacoes {
    public enum Identificador: String, CaseIterable {
        case ritual = "pt.bussola.ritual"
        case alinhamento = "pt.bussola.alinhamento"
        case revisao = "pt.bussola.revisao"
    }

    public static func pedirAutorizacao() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Reagenda as três. Idempotente — corre a cada arranque.
    public static func agendar() async {
        let centro = UNUserNotificationCenter.current()
        centro.removePendingNotificationRequests(
            withIdentifiers: Identificador.allCases.map(\.rawValue)
        )

        // 21h — o ritual. Esta é a que importa.
        await agendarDiaria(
            .ritual,
            hora: 21, minuto: 0,
            titulo: "Seis minutos",
            corpo: "Seis minutos para amanhã não ser adivinhado."
        )

        // 07h30 — alinhamento. Só se lê; não se planeia nada de manhã.
        await agendarDiaria(
            .alinhamento,
            hora: 7, minuto: 30,
            titulo: "Hoje",
            corpo: "O dia já está decidido. Abre para ver a Rocha."
        )

        // Domingo às 20h — revisão semanal.
        var componentes = DateComponents()
        componentes.weekday = 1   // 1 = domingo
        componentes.hour = 20
        componentes.minute = 0
        await agendar(
            .revisao,
            componentes: componentes,
            titulo: "Revisão da semana",
            corpo: "Vinte minutos: o que arrefeceu, quem não respondeu, o que está parado."
        )
    }

    /// Actualiza o corpo da notificação da manhã com a Rocha real do dia.
    ///
    /// Uma notificação genérica lê-se uma semana e ignora-se para sempre. Uma
    /// que diz o nome da tarefa faz o trabalho de a lembrar.
    public static func actualizarAlinhamento(rocha: String?) async {
        guard let rocha else { return }
        var componentes = DateComponents()
        componentes.hour = 7
        componentes.minute = 30
        await agendar(
            .alinhamento,
            componentes: componentes,
            titulo: "A Rocha de hoje",
            corpo: rocha
        )
    }

    public static func cancelarTudo() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: Identificador.allCases.map(\.rawValue)
        )
    }

    // MARK: - Privado

    private static func agendarDiaria(
        _ id: Identificador, hora: Int, minuto: Int, titulo: String, corpo: String
    ) async {
        var componentes = DateComponents()
        componentes.hour = hora
        componentes.minute = minuto
        await agendar(id, componentes: componentes, titulo: titulo, corpo: corpo)
    }

    private static func agendar(
        _ id: Identificador, componentes: DateComponents, titulo: String, corpo: String
    ) async {
        let conteudo = UNMutableNotificationContent()
        conteudo.title = titulo
        conteudo.body = corpo
        conteudo.sound = .default
        // Sem badge: um número vermelho permanente é culpa formatada, e a app
        // existe para reduzir culpa, não para a produzir.

        let pedido = UNNotificationRequest(
            identifier: id.rawValue,
            content: conteudo,
            trigger: UNCalendarNotificationTrigger(dateMatching: componentes, repeats: true)
        )
        try? await UNUserNotificationCenter.current().add(pedido)
    }
}

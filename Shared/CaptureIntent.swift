import AppIntents
import Foundation
import BussolaDomain
import BussolaPersistence

/// Capturar sem abrir a app.
///
/// Este intent corre a partir do Botão de Acção, da Siri, do Centro de Controlo
/// e do widget de ecrã bloqueado — quase sempre **fora** do processo da app.
/// Não monta `ModelContainer`, não toca no CloudKit, não apresenta interface:
/// escreve no spool do App Group e devolve o controlo.
///
/// Orçamento: menos de 2 segundos entre a intenção e o registo garantido. Tudo
/// o que aqui se acrescentar sai desse orçamento.
public struct CapturarIntent: AppIntent {
    public static var title: LocalizedStringResource = "Capturar"
    public static var description = IntentDescription(
        "Guarda um pensamento na Inbox da Bússola, sem abrir a app."
    )

    /// Não abre a app. É o ponto todo.
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "O quê", requestValueDialog: "O que queres assentar?")
    public var texto: String

    public init() {}

    public init(texto: String) {
        self.texto = texto
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let captura = Capture(text: texto, source: .siri)

        guard let directorio = InboxSpool.directorioDoAppGroup(BussolaStore.appGroupID) else {
            // Sem App Group não há onde escrever. Dizer isto em voz alta é
            // melhor do que engolir a captura em silêncio.
            throw CaptureError.semArmazenamentoPartilhado
        }
        try InboxSpool(directory: directorio).escrever(captura)

        // Sem alerta de confirmação: um "guardado!" custa cerca de 800 ms e não
        // acrescenta informação nenhuma. O háptico do sistema chega.
        return .result(dialog: "Assente.")
    }
}

public enum CaptureError: Error, CustomLocalizedStringResourceConvertible {
    case semArmazenamentoPartilhado

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .semArmazenamentoPartilhado:
            "A Bússola não consegue aceder ao armazenamento partilhado. Abre a app uma vez."
        }
    }
}

/// Atalhos oferecidos ao sistema, para aparecerem na Siri e no Spotlight sem
/// configuração nenhuma.
public struct BussolaShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CapturarIntent(),
            phrases: [
                "Assentar na \(.applicationName)",
                "Capturar na \(.applicationName)",
                "Nova nota na \(.applicationName)",
            ],
            shortTitle: "Capturar",
            systemImageName: "square.and.pencil"
        )
    }
}

/// Versão do intent para o botão do widget: sem parâmetros, abre o ditado.
///
/// O widget não consegue pedir texto, por isso este abre a app directamente no
/// ecrã de captura com o microfone já ligado. É o único caminho de captura que
/// abre a app, e existe porque ditar exige interface.
public struct CapturarPorVozIntent: AppIntent {
    public static var title: LocalizedStringResource = "Capturar por voz"
    public static var openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await CaptureRouter.shared.pedirCapturaPorVoz()
        return .result()
    }
}

/// Ponte entre o intent e a interface, para o widget conseguir abrir a app já
/// a gravar.
@MainActor
public final class CaptureRouter {
    public static let shared = CaptureRouter()
    private init() {}

    public private(set) var deveAbrirCapturaPorVoz = false

    public func pedirCapturaPorVoz() {
        deveAbrirCapturaPorVoz = true
    }

    public func consumir() -> Bool {
        defer { deveAbrirCapturaPorVoz = false }
        return deveAbrirCapturaPorVoz
    }
}

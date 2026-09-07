import Foundation
import BussolaDomain

/// A fila de capturas em disco, partilhada entre a app e as suas extensões.
///
/// O `CaptureIntent` corre **fora** do processo da app — a partir do Botão de
/// Acção, do widget de ecrã bloqueado ou da Siri — e nesse contexto não há
/// `ModelContainer` montado nem tempo para o montar. A captura escreve aqui um
/// ficheiro por item, e a app importa quando abrir.
///
/// A ordem é essa e não a inversa: **escrita primeiro, sync depois**. Se o
/// CloudKit estiver indisponível, se o SwiftData falhar a abrir, se a app tiver
/// sido morta pelo sistema — a captura não pode falhar. Nunca. Uma ideia não
/// capturada está perdida para sempre; uma ideia mal classificada corrige-se em
/// três segundos na triagem.
///
/// O directório é injectado em vez de resolvido cá dentro, para o
/// comportamento se poder testar sem App Groups nem simulador.
public struct InboxSpool: Sendable {
    public let directory: URL

    private static let extensaoDeItem = "captura"
    private static let subpastaDeAudio = "audio"

    public init(directory: URL) {
        self.directory = directory
    }

    /// O directório partilhado do App Group. `nil` fora de iOS/macOS ou quando
    /// o entitlement não está configurado — nesse caso a app deve dizê-lo, em
    /// vez de perder capturas em silêncio.
    public static func directorioDoAppGroup(_ identificador: String) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identificador)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    // MARK: - Escrita

    /// Grava uma captura. Atómica: ou o ficheiro existe inteiro, ou não existe.
    ///
    /// Sem escrita atómica, uma captura interrompida a meio deixaria um ficheiro
    /// truncado que a app leria como JSON inválido — perdendo o item e, pior,
    /// sem se saber que se perdeu.
    public func escrever(_ captura: Capture) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        let dados = try codificador.encode(captura)

        let destino = directory
            .appendingPathComponent(captura.id.uuidString)
            .appendingPathExtension(Self.extensaoDeItem)
        try dados.write(to: destino, options: .atomic)
    }

    /// Guarda o áudio ditado e devolve o caminho a pôr na captura.
    ///
    /// O original guarda-se sempre, mesmo com transcrição bem-sucedida:
    /// transcrição de português com ruído de obra falha, e o áudio é a única
    /// rede de segurança que resta na triagem.
    public func guardarAudio(_ dados: Data, para id: UUID, extensao: String = "m4a") throws -> String {
        let pasta = directory.appendingPathComponent(Self.subpastaDeAudio, isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let destino = pasta.appendingPathComponent(id.uuidString).appendingPathExtension(extensao)
        try dados.write(to: destino, options: .atomic)
        return destino.path
    }

    // MARK: - Leitura

    /// Tudo o que está por importar, mais antigo primeiro.
    ///
    /// Um ficheiro ilegível não interrompe a leitura dos outros: é posto de lado
    /// para inspecção manual. Perder uma captura é mau; perder as restantes por
    /// causa dela é indefensável.
    public func pendentes() throws -> (capturas: [Capture], ilegiveis: [URL]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return ([], []) }

        let ficheiros = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == Self.extensaoDeItem }

        let descodificador = JSONDecoder()
        descodificador.dateDecodingStrategy = .iso8601

        var capturas: [Capture] = []
        var ilegiveis: [URL] = []
        for ficheiro in ficheiros {
            guard let dados = try? Data(contentsOf: ficheiro),
                  let captura = try? descodificador.decode(Capture.self, from: dados)
            else {
                ilegiveis.append(ficheiro)
                continue
            }
            capturas.append(captura)
        }
        return (capturas.sorted { $0.createdAt < $1.createdAt }, ilegiveis)
    }

    /// Remove um item já importado para a base de dados.
    ///
    /// Só se chama **depois** de o `save()` ter corrido. Apagar antes é como se
    /// perdem capturas quando a gravação falha.
    public func remover(_ id: UUID) throws {
        let ficheiro = directory
            .appendingPathComponent(id.uuidString)
            .appendingPathExtension(Self.extensaoDeItem)
        if FileManager.default.fileExists(atPath: ficheiro.path) {
            try FileManager.default.removeItem(at: ficheiro)
        }
    }

    /// Põe de lado um ficheiro que não se consegue ler, para se poder ver o que
    /// aconteceu. Não se apaga: um ficheiro corrompido é a prova de um bug.
    public func quarentena(_ ficheiro: URL) throws {
        let pasta = directory.appendingPathComponent("quarentena", isDirectory: true)
        try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
        let destino = pasta.appendingPathComponent(ficheiro.lastPathComponent)
        try? FileManager.default.removeItem(at: destino)
        try FileManager.default.moveItem(at: ficheiro, to: destino)
    }

    public func contagemPendente() -> Int {
        ((try? pendentes().capturas.count) ?? 0)
    }
}

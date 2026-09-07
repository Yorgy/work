import Foundation

/// Como a captura entrou no sistema. Útil para perceber, ao fim de meses, qual
/// dos caminhos realmente se usa — e amputar os que não se usam.
public enum CaptureSource: String, Sendable, Codable, CaseIterable {
    case actionButton
    case siri
    case lockScreenWidget
    case controlCenter
    case shareSheet
    case app
    case reminders      // chegou da lista partilhada — ver ADR-002
}

/// Um pensamento em bruto, tal como saiu da cabeça.
///
/// Deliberadamente pobre em campos: o ecrã de captura nunca pede área, projecto
/// nem data. Cada campo adicional reduz a taxa de captura de forma
/// desproporcionada, e uma ideia não capturada custa infinitamente mais do que
/// uma ideia mal classificada — a segunda corrige-se em três segundos na triagem.
public struct Capture: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var text: String

    /// Caminho do ficheiro de áudio no App Group, quando houve ditado.
    ///
    /// O original guarda-se **sempre**, mesmo com transcrição bem-sucedida:
    /// transcrição de português com ruído de obra falha, e o áudio é a rede de
    /// segurança que se ouve na triagem.
    public var audioPath: String?

    public var source: CaptureSource
    public var createdAt: Date

    /// Resolvida quando a captura passa pela triagem.
    public var triagedAt: Date?

    public init(
        id: UUID = UUID(),
        text: String,
        audioPath: String? = nil,
        source: CaptureSource = .app,
        createdAt: Date = Date(),
        triagedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.audioPath = audioPath
        self.source = source
        self.createdAt = createdAt
        self.triagedAt = triagedAt
    }

    public var estaNaInbox: Bool { triagedAt == nil }

    /// Uma captura só de áudio, sem transcrição utilizável, ainda é válida —
    /// ouve-se na triagem. O que não é válido é uma captura vazia de tudo.
    public var temConteudo: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || audioPath != nil
    }
}

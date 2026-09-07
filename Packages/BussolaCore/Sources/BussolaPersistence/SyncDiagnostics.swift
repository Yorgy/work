#if canImport(SwiftData)
import Foundation
import SwiftData
#if canImport(CloudKit)
import CloudKit
#endif

/// O estado do sync, visível num ecrã escondido.
///
/// O CloudKit falha em silêncio: a app continua a funcionar no telemóvel e os
/// dados param de chegar ao iCloud sem um único erro à vista. Só se descobre
/// semanas depois, ao instalar noutro dispositivo. Um ecrã de diagnóstico é
/// parte da funcionalidade, não um extra de developer.
@MainActor
@Observable
public final class SyncDiagnostics {
    public enum Estado: Sendable, Equatable {
        case desconhecido
        case indisponivel(String)
        case pronto
        case erro(String)

        public var descricao: String {
            switch self {
            case .desconhecido:            "A verificar…"
            case .indisponivel(let razao): "Indisponível — \(razao)"
            case .pronto:                  "Ligado ao iCloud"
            case .erro(let mensagem):      "Erro — \(mensagem)"
            }
        }

        public var estaSao: Bool { self == .pronto }
    }

    public private(set) var estado: Estado = .desconhecido
    public private(set) var ultimaVerificacao: Date?
    public private(set) var capturasPorImportar: Int = 0

    private let spool: InboxSpool?

    public init(spool: InboxSpool? = nil) {
        self.spool = spool
    }

    public func verificar() async {
        ultimaVerificacao = Date()
        capturasPorImportar = spool?.contagemPendente() ?? 0

        #if canImport(CloudKit)
        do {
            let estadoDaConta = try await CKContainer.default().accountStatus()
            switch estadoDaConta {
            case .available:
                estado = .pronto
            case .noAccount:
                estado = .indisponivel("sem sessão iniciada no iCloud")
            case .restricted:
                estado = .indisponivel("iCloud restringido neste dispositivo")
            case .couldNotDetermine:
                estado = .indisponivel("não foi possível determinar")
            case .temporarilyUnavailable:
                estado = .indisponivel("temporariamente indisponível")
            @unknown default:
                estado = .indisponivel("estado desconhecido")
            }
        } catch {
            estado = .erro(error.localizedDescription)
        }
        #else
        estado = .indisponivel("CloudKit não disponível nesta plataforma")
        #endif
    }
}
#endif

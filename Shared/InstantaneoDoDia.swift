import Foundation
import BussolaDomain
import BussolaPersistence

/// O que os widgets mostram, escrito pela app e lido pela extensão.
///
/// Deliberadamente pobre: strings já formatadas, nenhum identificador, nenhuma
/// relação. Um widget que monta `ModelContainer` e sincroniza CloudKit para
/// desenhar quatro linhas de texto é um widget que o sistema mata por exceder o
/// orçamento de memória — e um widget morto é pior do que nenhum, porque fica
/// no ecrã principal a mostrar informação velha.
public struct InstantaneoDoDia: Codable, Sendable {
    public struct AreaResumo: Codable, Sendable {
        public let nome: String
        public let temperatura: String
        public let dias: String
    }

    public let rocha: String?
    public let pedras: [String]
    public let areas: [AreaResumo]
    public let actualizadoEm: Date

    public var estaVazio: Bool { rocha == nil && pedras.isEmpty }

    public init(rocha: String?, pedras: [String], areas: [AreaResumo], actualizadoEm: Date = Date()) {
        self.rocha = rocha
        self.pedras = pedras
        self.areas = areas
        self.actualizadoEm = actualizadoEm
    }

    // MARK: - Ficheiro partilhado

    private static let nomeDoFicheiro = "instantaneo.json"

    private static var url: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: BussolaStore.appGroupID)?
            .appendingPathComponent(nomeDoFicheiro)
    }

    public static func ler() -> InstantaneoDoDia? {
        guard let url, let dados = try? Data(contentsOf: url) else { return nil }
        let descodificador = JSONDecoder()
        descodificador.dateDecodingStrategy = .iso8601
        return try? descodificador.decode(InstantaneoDoDia.self, from: dados)
    }

    public func escrever() throws {
        guard let url = Self.url else { return }
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        try codificador.encode(self).write(to: url, options: .atomic)
    }

    /// Construído a partir do estado real, para a app chamar depois do ritual e
    /// de cada conclusão.
    public static func construir(
        plano: DayPlan?,
        tarefas: [TaskItem],
        leituras: [AreaReading]
    ) -> InstantaneoDoDia {
        let porID = Dictionary(tarefas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return InstantaneoDoDia(
            rocha: plano?.rockID.flatMap { porID[$0]?.title },
            pedras: (plano?.pebbleIDs ?? []).compactMap { id in
                guard let tarefa = porID[id], tarefa.status.estaAberta else { return nil }
                return tarefa.title
            },
            areas: leituras.map {
                AreaResumo(
                    nome: $0.area.nome,
                    temperatura: $0.temperatura.rawValue,
                    dias: $0.descricaoDoToque
                )
            }
        )
    }

    static let exemplo = InstantaneoDoDia(
        rocha: "Fechar a proposta do cliente X",
        pedras: ["Enviar mapa ao contabilista", "Pedir preço da caldeira"],
        areas: [
            AreaResumo(nome: "Agência", temperatura: "viva", dias: "hoje"),
            AreaResumo(nome: "Obras", temperatura: "escura", dias: "há 16 dias"),
        ]
    )
}

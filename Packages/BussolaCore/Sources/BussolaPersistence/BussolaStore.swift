#if canImport(SwiftData)
import Foundation
import SwiftData
import BussolaDomain

/// Versão 1 do esquema.
///
/// Existe desde o primeiro commit, ainda que só haja uma versão: migrar
/// SwiftData com CloudKit activo e dados reais no telemóvel sem plano de
/// migração é a forma mais rápida de perder um ano de capturas.
public enum BussolaSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { .init(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            AreaRecord.self, TaskRecord.self, CaptureRecord.self,
            ProjectRecord.self, WaitingForRecord.self, DayPlanRecord.self,
            RecurrenceRecord.self,
        ]
    }
}

public enum BussolaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [BussolaSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// O contentor e as consultas.
///
/// Não é um "repositório" com uma camada de abstracção por cima: SwiftData já é
/// essa camada, e envolvê-la noutra só acrescentaria indirecção. O que esta
/// classe faz é traduzir para os tipos do domínio, para que as regras não
/// dependam do framework.
@MainActor
public final class BussolaStore {
    public let container: ModelContainer
    public var context: ModelContext { container.mainContext }

    /// Identificador do App Group. A extensão de captura escreve aqui antes de
    /// a app sequer abrir — ver `InboxSpool`.
    public static let appGroupID = "group.pt.bussola.app"

    public init(emMemoria: Bool = false, comCloudKit: Bool = true) throws {
        let configuracao: ModelConfiguration
        if emMemoria {
            configuracao = ModelConfiguration(isStoredInMemoryOnly: true)
        } else if comCloudKit {
            configuracao = ModelConfiguration(
                cloudKitDatabase: .private("iCloud.pt.bussola.app")
            )
        } else {
            configuracao = ModelConfiguration()
        }

        container = try ModelContainer(
            for: Schema(BussolaSchemaV1.models),
            migrationPlan: BussolaMigrationPlan.self,
            configurations: configuracao
        )
    }

    // MARK: - Arranque

    /// Garante que as cinco áreas existem. Idempotente — corre a cada arranque.
    public func prepararAreas() throws {
        let existentes = try context.fetch(FetchDescriptor<AreaRecord>())
        let presentes = Set(existentes.map(\.areaID))
        for area in AreaID.allCases where !presentes.contains(area) {
            context.insert(AreaRecord(area: area))
        }
        if context.hasChanges { try context.save() }
    }

    /// Instala o calendário fiscal na primeira execução, sem duplicar em
    /// arranques seguintes.
    public func prepararRecorrencias() throws {
        let existentes = try context.fetch(FetchDescriptor<RecurrenceRecord>())
        guard existentes.isEmpty else { return }
        for modelo in CalendarioFiscalPT.modelos() {
            context.insert(RecurrenceRecord(modelo))
        }
        try context.save()
    }

    // MARK: - Captura

    public func guardar(_ captura: Capture) throws {
        context.insert(CaptureRecord(captura))
        try context.save()
    }

    /// A Inbox, mais antigas primeiro — a ordem por que se triam.
    public func inbox() throws -> [Capture] {
        let descritor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.triagedAt == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descritor).map(\.domain)
    }

    public func marcarTriada(_ capturaID: UUID, em agora: Date = Date()) throws {
        let descritor = FetchDescriptor<CaptureRecord>(
            predicate: #Predicate { $0.uuid == capturaID }
        )
        guard let registo = try context.fetch(descritor).first else { return }
        registo.triagedAt = agora
        try context.save()
    }

    // MARK: - Tarefas

    public func guardar(_ tarefa: TaskItem) throws {
        let id = tarefa.id
        let descritor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.uuid == id })
        if let existente = try context.fetch(descritor).first {
            existente.aplicar(tarefa)
        } else {
            context.insert(TaskRecord(tarefa))
        }
        try context.save()
    }

    public func tarefas() throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskRecord>()).map(\.domain)
    }

    public func tarefas(com ids: [UUID]) throws -> [TaskItem] {
        guard !ids.isEmpty else { return [] }
        let conjunto = Set(ids)
        let todas = try context.fetch(FetchDescriptor<TaskRecord>())
        let porID = Dictionary(
            todas.filter { conjunto.contains($0.uuid) }.map { ($0.uuid, $0.domain) },
            uniquingKeysWith: { a, _ in a }
        )
        // Devolve pela ordem pedida: nas Pedras, a ordem é informação.
        return ids.compactMap { porID[$0] }
    }

    /// Conclui uma tarefa e toca a área — é o toque que alimenta o termómetro.
    ///
    /// Ver uma área não é atendê-la, por isso o toque regista-se aqui e em mais
    /// lado nenhum.
    public func concluir(_ taskID: UUID, em agora: Date = Date()) throws {
        let descritor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.uuid == taskID })
        guard let registo = try context.fetch(descritor).first else { return }
        registo.rawStatus = TaskStatus.done.rawValue
        registo.completedAt = agora

        let area = registo.rawArea
        let areas = FetchDescriptor<AreaRecord>(predicate: #Predicate { $0.rawID == area })
        try context.fetch(areas).first?.lastTouchedAt = agora

        try context.save()
    }

    // MARK: - Áreas

    public func areas() throws -> [Area] {
        try context.fetch(FetchDescriptor<AreaRecord>()).map(\.domain)
    }

    public func pausar(_ area: AreaID, ate: Date) throws {
        let raw = area.rawValue
        let descritor = FetchDescriptor<AreaRecord>(predicate: #Predicate { $0.rawID == raw })
        try context.fetch(descritor).first?.pausadaAte = ate
        try context.save()
    }

    // MARK: - Planos

    public func guardar(_ plano: DayPlan) throws {
        let dia = plano.date
        let descritor = FetchDescriptor<DayPlanRecord>(predicate: #Predicate { $0.date == dia })
        if let existente = try context.fetch(descritor).first {
            existente.aplicar(plano)
        } else {
            context.insert(DayPlanRecord(plano))
        }
        try context.save()
    }

    public func plano(para dia: Date, calendario: Calendar = .current) throws -> DayPlan? {
        let inicio = calendario.startOfDay(for: dia)
        let descritor = FetchDescriptor<DayPlanRecord>(predicate: #Predicate { $0.date == inicio })
        return try context.fetch(descritor).first?.domain
    }

    // MARK: - À espera de

    public func guardar(_ pendente: WaitingFor) throws {
        let id = pendente.id
        let descritor = FetchDescriptor<WaitingForRecord>(predicate: #Predicate { $0.uuid == id })
        if let existente = try context.fetch(descritor).first {
            context.delete(existente)
        }
        context.insert(WaitingForRecord(pendente))
        try context.save()
    }

    public func pendentes() throws -> [WaitingFor] {
        let descritor = FetchDescriptor<WaitingForRecord>(
            predicate: #Predicate { $0.resolvedAt == nil }
        )
        return try context.fetch(descritor).map(\.domain)
    }

    // MARK: - Projectos

    public func projectos() throws -> [Project] {
        try context.fetch(FetchDescriptor<ProjectRecord>()).map(\.domain)
    }

    public func guardar(_ projecto: Project) throws {
        let id = projecto.id
        let descritor = FetchDescriptor<ProjectRecord>(predicate: #Predicate { $0.uuid == id })
        if let existente = try context.fetch(descritor).first { context.delete(existente) }
        context.insert(ProjectRecord(projecto))
        try context.save()
    }

    // MARK: - Recorrências

    /// Gera as tarefas das recorrências devidas, sem duplicar.
    /// Devolve quantas criou — o ritual mostra "3 obrigações entraram na Inbox".
    @discardableResult
    public func gerarRecorrenciasDevidas(
        em agora: Date = Date(), calendario: Calendar = .current
    ) throws -> Int {
        let registos = try context.fetch(FetchDescriptor<RecurrenceRecord>())
        var criadas = 0

        for registo in registos {
            guard let modelo = registo.domain,
                  let tarefa = modelo.gerarSeDevido(em: agora, calendario: calendario),
                  let limite = tarefa.dueDate
            else { continue }

            // Já foi gerada para esta ocorrência.
            if let ultima = registo.ultimaGeradaPara, ultima >= limite { continue }

            context.insert(TaskRecord(tarefa))
            registo.ultimaGeradaPara = limite
            criadas += 1
        }
        if context.hasChanges { try context.save() }
        return criadas
    }
}

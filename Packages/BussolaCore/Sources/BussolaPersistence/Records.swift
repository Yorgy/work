#if canImport(SwiftData)
import Foundation
import SwiftData
import BussolaDomain

// Regras de esquema do CloudKit, respeitadas desde o primeiro commit:
//
//   1. Toda a propriedade tem valor por omissão ou é opcional.
//   2. Todas as relações são opcionais.
//   3. Nenhuma restrição de unicidade (`@Attribute(.unique)`).
//
// Violá-las faz o sync falhar em silêncio, que é a pior falha possível:
// a app continua a funcionar no telemóvel e os dados param de chegar a lado
// nenhum, sem um único erro visível. Ver `SyncDiagnostics`.
//
// Os enums guardam-se como String em vez de tipos `Codable`: um enum
// serializado é opaco na consola do CloudKit e um valor desconhecido vindo de
// uma versão futura da app rebenta a descodificação em vez de degradar.

@Model
public final class AreaRecord {
    public var rawID: String = AreaID.pessoal.rawValue
    public var lastTouchedAt: Date?
    public var pausadaAte: Date?

    public init(area: AreaID, lastTouchedAt: Date? = nil, pausadaAte: Date? = nil) {
        self.rawID = area.rawValue
        self.lastTouchedAt = lastTouchedAt
        self.pausadaAte = pausadaAte
    }

    public var areaID: AreaID { AreaID(rawValue: rawID) ?? .pessoal }

    public var domain: Area {
        Area(id: areaID, lastTouchedAt: lastTouchedAt, pausadaAte: pausadaAte)
    }

    public func aplicar(_ area: Area) {
        rawID = area.id.rawValue
        lastTouchedAt = area.lastTouchedAt
        pausadaAte = area.pausadaAte
    }
}

@Model
public final class TaskRecord {
    public var uuid: UUID = UUID()
    public var title: String = ""
    public var notes: String = ""
    public var rawArea: String = AreaID.pessoal.rawValue
    public var projectUUID: UUID?
    public var rawStatus: String = TaskStatus.inbox.rawValue
    public var rawEnergy: String = Energy.shallow.rawValue
    public var estimatedMinutes: Int = 15
    public var dueDate: Date?
    public var defersUntil: Date?
    public var anchorQuando: String?
    public var anchorOnde: String?
    public var externalID: String?
    public var recurrenceUUID: UUID?
    public var unblocksOthers: Bool = false
    public var createdAt: Date = Date()
    public var completedAt: Date?

    public init(_ tarefa: TaskItem) {
        aplicar(tarefa)
    }

    public var domain: TaskItem {
        TaskItem(
            id: uuid,
            title: title,
            notes: notes,
            area: AreaID(rawValue: rawArea) ?? .pessoal,
            projectID: projectUUID,
            status: TaskStatus(rawValue: rawStatus) ?? .inbox,
            energy: Energy(rawValue: rawEnergy) ?? .shallow,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            defersUntil: defersUntil,
            anchor: anchor,
            externalID: externalID,
            recurrenceID: recurrenceUUID,
            unblocksOthers: unblocksOthers,
            createdAt: createdAt,
            completedAt: completedAt
        )
    }

    private var anchor: Anchor? {
        guard let anchorQuando, let anchorOnde else { return nil }
        return Anchor(quando: anchorQuando, onde: anchorOnde)
    }

    public func aplicar(_ t: TaskItem) {
        uuid = t.id
        title = t.title
        notes = t.notes
        rawArea = t.area.rawValue
        projectUUID = t.projectID
        rawStatus = t.status.rawValue
        rawEnergy = t.energy.rawValue
        estimatedMinutes = t.estimatedMinutes
        dueDate = t.dueDate
        defersUntil = t.defersUntil
        anchorQuando = t.anchor?.quando
        anchorOnde = t.anchor?.onde
        externalID = t.externalID
        recurrenceUUID = t.recurrenceID
        unblocksOthers = t.unblocksOthers
        createdAt = t.createdAt
        completedAt = t.completedAt
    }
}

@Model
public final class CaptureRecord {
    public var uuid: UUID = UUID()
    public var text: String = ""
    public var audioPath: String?
    public var rawSource: String = CaptureSource.app.rawValue
    public var createdAt: Date = Date()
    public var triagedAt: Date?

    public init(_ captura: Capture) {
        uuid = captura.id
        text = captura.text
        audioPath = captura.audioPath
        rawSource = captura.source.rawValue
        createdAt = captura.createdAt
        triagedAt = captura.triagedAt
    }

    public var domain: Capture {
        Capture(
            id: uuid,
            text: text,
            audioPath: audioPath,
            source: CaptureSource(rawValue: rawSource) ?? .app,
            createdAt: createdAt,
            triagedAt: triagedAt
        )
    }
}

@Model
public final class ProjectRecord {
    public var uuid: UUID = UUID()
    public var name: String = ""
    public var outcome: String = ""
    public var rawArea: String = AreaID.pessoal.rawValue
    public var rawStatus: String = ProjectStatus.active.rawValue
    public var dueDate: Date?
    public var createdAt: Date = Date()

    public init(_ p: Project) {
        uuid = p.id
        name = p.name
        outcome = p.outcome
        rawArea = p.area.rawValue
        rawStatus = p.status.rawValue
        dueDate = p.dueDate
        createdAt = p.createdAt
    }

    public var domain: Project {
        Project(
            id: uuid,
            name: name,
            outcome: outcome,
            area: AreaID(rawValue: rawArea) ?? .pessoal,
            status: ProjectStatus(rawValue: rawStatus) ?? .active,
            dueDate: dueDate,
            createdAt: createdAt
        )
    }
}

@Model
public final class WaitingForRecord {
    public var uuid: UUID = UUID()
    public var taskUUID: UUID = UUID()
    public var owner: String = ""
    public var rawChannel: String = Channel.email.rawValue
    public var requestedAt: Date = Date()
    public var followUpAt: Date = Date()
    public var followUpCount: Int = 0
    public var resolvedAt: Date?

    public init(_ w: WaitingFor) {
        uuid = w.id
        taskUUID = w.taskID
        owner = w.owner
        rawChannel = w.channel.rawValue
        requestedAt = w.requestedAt
        followUpAt = w.followUpAt
        followUpCount = w.followUpCount
        resolvedAt = w.resolvedAt
    }

    public var domain: WaitingFor {
        WaitingFor(
            id: uuid,
            taskID: taskUUID,
            owner: owner,
            channel: Channel(rawValue: rawChannel) ?? .email,
            requestedAt: requestedAt,
            followUpAt: followUpAt,
            followUpCount: followUpCount,
            resolvedAt: resolvedAt
        )
    }
}

@Model
public final class DayPlanRecord {
    public var uuid: UUID = UUID()
    public var date: Date = Date()
    public var rockUUID: UUID?
    /// Ordem preservada: a Pedra 2 só se activa quando a 1 fecha.
    public var pebbleUUIDs: [UUID] = []
    public var sandUUIDs: [UUID] = []
    public var capacityMinutes: Int = 0
    public var plannedAt: Date = Date()
    public var closedAt: Date?
    public var rochaCumprida: Bool = false
    public var pedrasCumpridas: Int = 0
    public var notaDoDia: String = ""

    public init(_ p: DayPlan) {
        aplicar(p)
    }

    public var domain: DayPlan {
        DayPlan(
            id: uuid,
            date: date,
            rockID: rockUUID,
            pebbleIDs: pebbleUUIDs,
            sandIDs: sandUUIDs,
            capacityMinutes: capacityMinutes,
            plannedAt: plannedAt,
            closedAt: closedAt,
            outcome: closedAt == nil ? nil : DayOutcome(
                rochaCumprida: rochaCumprida,
                pedrasCumpridas: pedrasCumpridas,
                nota: notaDoDia
            )
        )
    }

    public func aplicar(_ p: DayPlan) {
        uuid = p.id
        date = p.date
        rockUUID = p.rockID
        pebbleUUIDs = p.pebbleIDs
        sandUUIDs = p.sandIDs
        capacityMinutes = p.capacityMinutes
        plannedAt = p.plannedAt
        closedAt = p.closedAt
        rochaCumprida = p.outcome?.rochaCumprida ?? false
        pedrasCumpridas = p.outcome?.pedrasCumpridas ?? 0
        notaDoDia = p.outcome?.nota ?? ""
    }
}

@Model
public final class RecurrenceRecord {
    public var uuid: UUID = UUID()
    public var title: String = ""
    public var rawArea: String = AreaID.agencia.rawValue
    /// A regra guarda-se codificada: é a única estrutura com forma variável, e
    /// dar-lhe seis colunas planas tornaria o esquema ilegível.
    public var ruleData: Data = Data()
    public var leadDays: Int = 10
    public var estimatedMinutes: Int = 30
    public var rawEnergy: String = Energy.admin.rawValue
    public var fonteDaData: String = ""
    public var enabled: Bool = true
    /// Evita gerar a mesma ocorrência duas vezes.
    public var ultimaGeradaPara: Date?

    public init(_ m: RecurrenceTemplate) {
        uuid = m.id
        title = m.title
        rawArea = m.area.rawValue
        ruleData = (try? JSONEncoder().encode(m.rule)) ?? Data()
        leadDays = m.leadDays
        estimatedMinutes = m.estimatedMinutes
        rawEnergy = m.energy.rawValue
        fonteDaData = m.fonteDaData
        enabled = m.enabled
    }

    public var domain: RecurrenceTemplate? {
        guard let rule = try? JSONDecoder().decode(RecurrenceRule.self, from: ruleData) else {
            return nil
        }
        return RecurrenceTemplate(
            id: uuid,
            title: title,
            area: AreaID(rawValue: rawArea) ?? .agencia,
            rule: rule,
            leadDays: leadDays,
            estimatedMinutes: estimatedMinutes,
            energy: Energy(rawValue: rawEnergy) ?? .admin,
            fonteDaData: fonteDaData,
            enabled: enabled
        )
    }
}
#endif

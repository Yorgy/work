import Foundation

public enum ProjectStatus: String, Sendable, Codable, CaseIterable {
    case active
    case paused
    case done
    case dropped
}

/// Um projecto tem fim. Uma área não. É a distinção que o PARA acerta e que
/// mantém a lista de projectos honesta.
public struct Project: Identifiable, Sendable, Hashable, Codable {
    public let id: UUID
    public var name: String

    /// O resultado que define "acabado". Um projecto sem resultado escrito é um
    /// projecto que nunca fecha, porque ninguém sabe quando fechou.
    public var outcome: String

    public var area: AreaID
    public var status: ProjectStatus
    public var dueDate: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        outcome: String = "",
        area: AreaID,
        status: ProjectStatus = .active,
        dueDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.outcome = outcome
        self.area = area
        self.status = status
        self.dueDate = dueDate
        self.createdAt = createdAt
    }
}

/// Um projecto activo sem próxima acção definida é um defeito, não uma opção.
///
/// É a falha mais comum e a mais silenciosa: o projecto parece vivo na lista e
/// não avança há semanas porque ninguém decidiu qual é o passo seguinte. A
/// revisão semanal existe em grande parte para apanhar isto.
public struct StalledProject: Sendable, Hashable, Identifiable {
    public var id: UUID { project.id }
    public let project: Project
    public let diasParado: Int

    public init(project: Project, diasParado: Int) {
        self.project = project
        self.diasParado = diasParado
    }
}

public enum ProjectAudit {
    /// Projectos activos sem uma única tarefa disponível.
    public static func semProximaAccao(
        projectos: [Project],
        tarefas: [TaskItem],
        agora: Date = Date(),
        calendario: Calendar = .current
    ) -> [StalledProject] {
        let porProjecto = Dictionary(grouping: tarefas.filter { $0.projectID != nil }) { $0.projectID! }

        return projectos
            .filter { $0.status == .active }
            .compactMap { projecto in
                let doProjecto = porProjecto[projecto.id] ?? []
                let temProxima = doProjecto.contains {
                    $0.estaDisponivel(em: agora) && $0.status != .waiting
                }
                guard !temProxima else { return nil }

                // Sem tarefas de todo conta desde a criação do projecto.
                let ultimoSinal = doProjecto.map(\.createdAt).max() ?? projecto.createdAt
                let dias = calendario.dateComponents([.day], from: ultimoSinal, to: agora).day ?? 0
                return StalledProject(project: projecto, diasParado: max(0, dias))
            }
            .sorted { $0.diasParado > $1.diasParado }
    }
}

import Foundation

/// Uma tarefa candidata, já pontuada, com a razão pela qual subiu.
public struct ScoredTask: Identifiable, Sendable, Hashable {
    public var id: UUID { task.id }
    public let task: TaskItem
    public let score: Double
    /// Porque é que esta subiu. Mostrada na interface — uma proposta sem razão
    /// é um oráculo, e num oráculo não se confia nem se discorda.
    public let razao: String

    public init(task: TaskItem, score: Double, razao: String) {
        self.task = task
        self.score = score
        self.razao = razao
    }
}

public struct PlanProposal: Sendable {
    public let rocha: ScoredTask?
    public let pedras: [ScoredTask]
    public let areia: [TaskItem]
    public let capacidade: Capacity
    /// Áreas escuras que bloqueiam o ritual até se decidir.
    public let bloqueios: [AreaReading]

    public init(
        rocha: ScoredTask?,
        pedras: [ScoredTask],
        areia: [TaskItem],
        capacidade: Capacity,
        bloqueios: [AreaReading]
    ) {
        self.rocha = rocha
        self.pedras = pedras
        self.areia = areia
        self.capacidade = capacidade
        self.bloqueios = bloqueios
    }
}

/// Propõe o plano de amanhã. Propõe — não decide.
///
/// A pontuação é deliberadamente legível e ajustável. Um algoritmo de
/// priorização que ninguém consegue explicar é um algoritmo em que ninguém
/// confia, e a confiança é o activo que este sistema existe para construir.
///
///     S = 3·U + 2·F + 1,5·B + 1·I − 2·X
///
/// onde U é urgência por prazo, F a frieza da área, B se desbloqueia terceiros,
/// I a idade da tarefa e X a penalização por repetir área.
public struct PlanProposer: Sendable {
    public struct Pesos: Sendable {
        public var urgencia = 3.0
        public var frieza = 2.0
        public var desbloqueia = 1.5
        public var idade = 1.0
        public var repeticaoDeArea = 2.0
        public init() {}
    }

    public var pesos: Pesos
    private let calendario: Calendar

    public init(pesos: Pesos = Pesos(), calendario: Calendar = .current) {
        self.pesos = pesos
        self.calendario = calendario
    }

    // MARK: - Componentes

    /// 1 quando o prazo é hoje ou já passou; 0 a partir de 30 dias.
    func urgencia(_ tarefa: TaskItem, agora: Date) -> Double {
        guard let due = tarefa.dueDate else { return 0 }
        let dias = calendario.dateComponents([.day], from: agora, to: due).day ?? 0
        if dias <= 0 { return 1 }
        if dias >= 30 { return 0 }
        return 1 - (Double(dias) / 30)
    }

    /// Satura aos 30 dias: uma tarefa parada há dois meses não é o dobro de
    /// urgente de uma parada há um, mas é claramente um sintoma.
    func idade(_ tarefa: TaskItem, agora: Date) -> Double {
        let dias = tarefa.diasDesdeCriacao(ate: agora, calendario: calendario)
        return min(1, max(0, Double(dias) / 30))
    }

    func pontuar(
        _ tarefa: TaskItem,
        temperaturaDaArea: AreaTemperature,
        areasJaEscolhidas: [AreaID],
        agora: Date
    ) -> ScoredTask {
        let u = urgencia(tarefa, agora: agora)
        let f = temperaturaDaArea.pesoNaProposta
        let b = tarefa.unblocksOthers ? 1.0 : 0.0
        let i = idade(tarefa, agora: agora)
        let x = areasJaEscolhidas.contains(tarefa.area) ? 1.0 : 0.0

        let score = pesos.urgencia * u
            + pesos.frieza * f
            + pesos.desbloqueia * b
            + pesos.idade * i
            - pesos.repeticaoDeArea * x

        return ScoredTask(task: tarefa, score: score, razao: razao(u: u, f: f, b: b, i: i, tarefa: tarefa))
    }

    private func razao(u: Double, f: Double, b: Double, i: Double, tarefa: TaskItem) -> String {
        // A razão dominante, não uma lista de factores. Uma explicação com
        // quatro cláusulas não se lê às 21h.
        let candidatas: [(Double, String)] = [
            (pesos.urgencia * u, tarefa.dueDate != nil ? "prazo a aproximar-se" : ""),
            (pesos.frieza * f, "\(tarefa.area.nome) está fria"),
            (pesos.desbloqueia * b, "desbloqueia outra pessoa"),
            (pesos.idade * i, "está parada há semanas"),
        ]
        return candidatas
            .filter { !$0.1.isEmpty && $0.0 > 0 }
            .max { $0.0 < $1.0 }?.1 ?? "sem sinal forte"
    }

    // MARK: - Proposta

    public func propor(
        tarefas: [TaskItem],
        leituras: [AreaReading],
        capacidade: Capacity,
        agora: Date = Date()
    ) -> PlanProposal {
        let disponiveis = tarefas.filter {
            $0.estaDisponivel(em: agora) && $0.status != .waiting && $0.status != .doing
        }
        let temperaturas = Dictionary(
            leituras.map { ($0.area, $0.temperatura) }, uniquingKeysWith: { a, _ in a }
        )
        let pausadas = Set(leituras.filter(\.emPausa).map(\.area))

        let elegiveis = disponiveis.filter { !pausadas.contains($0.area) }
        let areia = elegiveis.filter(\.eAreia)
        let substanciais = elegiveis.filter { !$0.eAreia }

        // Rocha: só há Rocha se houver espaço para uma. Um dia cheio de reuniões
        // recebe um plano só de Pedras, em vez de um bloco profundo a fingir.
        let calc = CapacityCalculator()
        let tectoDaRocha = calc.duracaoDeRocha(para: capacidade)

        var rocha: ScoredTask?
        if let tecto = tectoDaRocha {
            rocha = substanciais
                .filter { $0.podeSerRocha && $0.estimatedMinutes <= tecto }
                .map {
                    pontuar($0, temperaturaDaArea: temperaturas[$0.area] ?? .escura,
                            areasJaEscolhidas: [], agora: agora)
                }
                .max { $0.score < $1.score }
        }

        // Pedras: escolha gulosa que repontua a cada passo, para a penalização
        // por repetir área ter efeito real em vez de decorativo.
        var escolhidas: [ScoredTask] = []
        var areasEscolhidas: [AreaID] = rocha.map { [$0.task.area] } ?? []
        var restantes = substanciais.filter { $0.id != rocha?.task.id }

        while escolhidas.count < DayPlan.limiteDePedras, !restantes.isEmpty {
            let pontuadas = restantes.map {
                pontuar($0, temperaturaDaArea: temperaturas[$0.area] ?? .escura,
                        areasJaEscolhidas: areasEscolhidas, agora: agora)
            }
            guard let melhor = pontuadas.max(by: { $0.score < $1.score }) else { break }

            // O invariante das três áreas não pode ser violado pela própria
            // proposta: seria a app a propor um plano que depois recusa.
            let futuras = escolhidas.map(\.task.area) + [melhor.task.area]
            if futuras.count == DayPlan.limiteDePedras, Set(futuras).count == 1 {
                let alternativa = pontuadas
                    .filter { $0.task.area != melhor.task.area }
                    .max { $0.score < $1.score }
                guard let alternativa else { break }
                escolhidas.append(alternativa)
                areasEscolhidas.append(alternativa.task.area)
                restantes.removeAll { $0.id == alternativa.id }
                continue
            }

            escolhidas.append(melhor)
            areasEscolhidas.append(melhor.task.area)
            restantes.removeAll { $0.id == melhor.id }
        }

        return PlanProposal(
            rocha: rocha,
            pedras: escolhidas,
            areia: areia.sorted { $0.createdAt < $1.createdAt },
            capacidade: capacidade,
            bloqueios: AreaThermometer().bloqueios(leituras)
        )
    }
}

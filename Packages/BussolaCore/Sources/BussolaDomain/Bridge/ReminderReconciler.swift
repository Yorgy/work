import Foundation

/// Um lembrete da lista partilhada, reduzido ao que interessa.
///
/// Deliberadamente pobre: os Lembretes da Apple não têm área, energia, âncora
/// nem projecto, e fingir que têm produziria perda de dados em cada passagem.
/// A área Família aceita ser mais pobre do que as outras — é o preço de a
/// esposa não ter de instalar nada (ADR-002).
public struct ReminderMirror: Sendable, Hashable, Identifiable {
    public var id: String { externalID }

    public let externalID: String
    public var title: String
    public var notes: String
    public var dueDate: Date?
    public var completed: Bool
    public var lastModified: Date

    public init(
        externalID: String,
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        completed: Bool = false,
        lastModified: Date = Date()
    ) {
        self.externalID = externalID
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.completed = completed
        self.lastModified = lastModified
    }
}

/// O que a ponte tem de fazer, decidido sem tocar em EventKit.
public enum SyncAction: Sendable, Hashable {
    /// Tarefa de Família ainda sem espelho — criar lembrete.
    case criarLembrete(TaskItem)
    /// A tarefa é mais recente — escrever por cima do lembrete.
    case actualizarLembrete(TaskItem)
    /// Lembrete que a esposa criou — trazer para dentro.
    case criarTarefa(ReminderMirror)
    /// O lembrete é mais recente — a tarefa já vem com os valores aplicados.
    case actualizarTarefa(TaskItem)
    /// Conclusão a propagar.
    case concluirTarefa(UUID)
    case concluirLembrete(String)
    /// O lembrete desapareceu do outro lado.
    ///
    /// **Nunca apaga a tarefa.** Só lhe tira o espelho. Apagar dados do
    /// utilizador por causa de uma sincronização é a pior falha que este sistema
    /// pode ter, e "o lembrete sumiu" tanto pode ser um apagamento deliberado
    /// como a lista ter deixado de estar partilhada.
    case desligarEspelho(UUID)
}

/// Decide o que sincronizar. Função pura: entram dois lados, sai uma lista de
/// acções.
///
/// Vive no domínio de propósito. A alternativa — meter esta lógica dentro do
/// código que fala com o EventKit — só se conseguiria testar com um simulador,
/// permissões concedidas e uma lista real de Lembretes, o que na prática
/// significa não a testar de todo.
public struct ReminderReconciler: Sendable {

    /// A área espelhada. Só uma, e por desenho.
    public let area: AreaID

    public init(area: AreaID = .familia) {
        self.area = area
    }

    public func reconciliar(
        tarefas: [TaskItem],
        lembretes: [ReminderMirror],
        agora: Date = Date()
    ) -> [SyncAction] {
        let daArea = tarefas.filter { $0.area == area && $0.status != .dropped }
        let porExternalID = Dictionary(
            daArea.compactMap { tarefa in tarefa.externalID.map { ($0, tarefa) } },
            uniquingKeysWith: { a, _ in a }
        )
        let lembretesPorID = Dictionary(
            lembretes.map { ($0.externalID, $0) }, uniquingKeysWith: { a, _ in a }
        )

        var accoes: [SyncAction] = []

        // 1. Tarefas locais sem espelho → criar lembrete.
        for tarefa in daArea where tarefa.externalID == nil {
            // Uma tarefa já fechada nunca chega a existir do outro lado: criar
            // um lembrete só para o marcar como feito é ruído na lista de outra
            // pessoa.
            guard tarefa.status != .done else { continue }
            accoes.append(.criarLembrete(tarefa))
        }

        // 2. Pares existentes → last-write-wins, com a conclusão à frente.
        for (externalID, tarefa) in porExternalID {
            guard let lembrete = lembretesPorID[externalID] else {
                accoes.append(.desligarEspelho(tarefa.id))
                continue
            }

            let tarefaFeita = tarefa.status == .done
            if lembrete.completed && !tarefaFeita {
                // Concluir vence sempre. Não é ambíguo: alguém fez o trabalho.
                accoes.append(.concluirTarefa(tarefa.id))
                continue
            }
            if tarefaFeita && !lembrete.completed {
                accoes.append(.concluirLembrete(externalID))
                continue
            }
            if tarefaFeita && lembrete.completed { continue }

            guard mudou(tarefa: tarefa, lembrete: lembrete) else { continue }

            if lembrete.lastModified > tarefa.updatedAt {
                accoes.append(.actualizarTarefa(aplicar(lembrete, a: tarefa, agora: agora)))
            } else {
                accoes.append(.actualizarLembrete(tarefa))
            }
        }

        // 3. Lembretes que ninguém cá dentro conhece → a esposa criou.
        let conhecidos = Set(porExternalID.keys)
        for lembrete in lembretes where !conhecidos.contains(lembrete.externalID) {
            // Um lembrete que já chega concluído não vale a pena importar: seria
            // criar uma tarefa só para a fechar no mesmo instante.
            guard !lembrete.completed else { continue }
            accoes.append(.criarTarefa(lembrete))
        }

        return accoes
    }

    /// Só há conflito se algum campo espelhado for mesmo diferente. Sem isto, a
    /// sincronização escrevia dos dois lados a cada passagem e os `lastModified`
    /// entravam em ping-pong.
    func mudou(tarefa: TaskItem, lembrete: ReminderMirror) -> Bool {
        tarefa.title != lembrete.title
            || tarefa.notes != lembrete.notes
            || !mesmaData(tarefa.dueDate, lembrete.dueDate)
    }

    /// Compara ao segundo. Os Lembretes arredondam datas, e uma diferença de
    /// milissegundos não é uma alteração.
    func mesmaData(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return abs(x.timeIntervalSince(y)) < 1
        default: return false
        }
    }

    func aplicar(_ lembrete: ReminderMirror, a tarefa: TaskItem, agora: Date) -> TaskItem {
        var actualizada = tarefa
        actualizada.title = lembrete.title
        actualizada.notes = lembrete.notes
        actualizada.dueDate = lembrete.dueDate
        actualizada.updatedAt = agora
        return actualizada
    }

    /// Constrói a tarefa a partir de um lembrete criado do outro lado.
    ///
    /// Entra em `.inbox`, não em `.next`: aquilo que outra pessoa acrescentou
    /// passa pelo teu ritual como qualquer captura tua. É o que impede a lista
    /// partilhada de se tornar uma porta de entrada para o teu dia sem passar
    /// por uma decisão.
    public func tarefa(de lembrete: ReminderMirror, agora: Date = Date()) -> TaskItem {
        TaskItem(
            title: lembrete.title,
            notes: lembrete.notes,
            area: area,
            status: .inbox,
            energy: .shallow,
            estimatedMinutes: 15,
            dueDate: lembrete.dueDate,
            externalID: lembrete.externalID,
            createdAt: agora,
            updatedAt: agora
        )
    }
}

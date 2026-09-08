import Foundation
import Observation
import WidgetKit
import BussolaDomain
import BussolaPersistence
import BussolaTriage
import BussolaBridge

/// O estado da app, num só sítio.
///
/// Não há uma camada de ViewModels por ecrã: SwiftUI com `@Observable` já é o
/// padrão observável, e uma camada extra acrescentaria cerimónia sem acrescentar
/// testabilidade — os testes que interessam vivem no `Domain`, sobre regras
/// puras, e não precisam disto.
@MainActor
@Observable
public final class AppModel {
    // MARK: - Dependências

    let store: BussolaStore
    let triager: any Triaging
    let spool: InboxSpool?
    public let diagnostico: SyncDiagnostics

    private let calendario: Calendar
    let leitorDeCalendario = CalendarReader()
    var ponteDeLembretes = RemindersBridge()

    // MARK: - Estado

    public private(set) var inbox: [Capture] = []
    public private(set) var tarefas: [TaskItem] = []
    public private(set) var areas: [Area] = []
    public private(set) var pendentes: [WaitingFor] = []
    public private(set) var projectos: [Project] = []
    public private(set) var planoDeHoje: DayPlan?
    public private(set) var leituras: [AreaReading] = []

    public private(set) var aCarregar = false
    public private(set) var ultimoErro: String?

    /// Estado das pontes, para as Definições poderem explicar o que falta em vez
    /// de a app degradar em silêncio.
    public private(set) var acessoAoCalendario: CalendarReader.Acesso = .indisponivel
    public private(set) var acessoAosLembretes = false
    public private(set) var ultimaSincronizacaoFamilia: Date?
    public private(set) var avisoDaPonte: String?

    // MARK: - Arranque

    public init(
        store: BussolaStore,
        triager: any Triaging,
        spool: InboxSpool?,
        calendario: Calendar = .current
    ) {
        self.store = store
        self.triager = triager
        self.spool = spool
        self.calendario = calendario
        self.diagnostico = SyncDiagnostics(spool: spool)
    }

    public static func arrancar(emMemoria: Bool = false) throws -> AppModel {
        let store = try BussolaStore(emMemoria: emMemoria, comCloudKit: !emMemoria)
        try store.prepararAreas()
        try store.prepararRecorrencias()

        let directorio = InboxSpool.directorioDoAppGroup(BussolaStore.appGroupID)
        return AppModel(
            store: store,
            triager: TriagerFactory.melhorDisponivel(),
            spool: directorio.map(InboxSpool.init(directory:))
        )
    }

    /// Corre a cada abertura da app. A ordem importa.
    public func recarregar(agora: Date = Date()) async {
        aCarregar = true
        defer { aCarregar = false }
        do {
            // 1. Importar o que as extensões escreveram enquanto a app estava
            //    fechada. Primeiro de tudo: são capturas que ainda não existem
            //    em lado nenhum a não ser num ficheiro.
            try importarDoSpool()

            // 2. Gerar as obrigações recorrentes que já é altura de mostrar.
            try store.gerarRecorrenciasDevidas(em: agora, calendario: calendario)

            // 3. Ler o estado.
            inbox = try store.inbox()
            tarefas = try store.tarefas()
            areas = try store.areas()
            pendentes = try store.pendentes()
            projectos = try store.projectos()
            planoDeHoje = try store.plano(para: agora, calendario: calendario)
            recalcularLeituras(agora: agora)
            publicarInstantaneo()

            ultimoErro = nil
        } catch {
            ultimoErro = error.localizedDescription
        }
        await diagnostico.verificar()
        await sincronizarFamilia(agora: agora)
    }

    /// Passa o que está no App Group para a base de dados.
    ///
    /// Só se apaga o ficheiro **depois** de o `save()` ter corrido — apagar
    /// antes é como se perdem capturas quando a gravação falha.
    func importarDoSpool() throws {
        guard let spool else { return }
        let (capturas, ilegiveis) = try spool.pendentes()

        for captura in capturas {
            try store.guardar(captura)
            try spool.remover(captura.id)
        }
        for ficheiro in ilegiveis {
            try? spool.quarentena(ficheiro)
        }
    }

    // MARK: - Captura

    public func capturar(_ texto: String, audioPath: String? = nil, origem: CaptureSource = .app) {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let captura = Capture(text: limpo, audioPath: audioPath, source: origem)
        guard captura.temConteudo else { return }
        do {
            try store.guardar(captura)
            inbox.append(captura)
        } catch {
            // Se a base de dados falhar, o spool é a rede de segurança.
            try? spool?.escrever(captura)
            ultimoErro = error.localizedDescription
        }
    }

    // MARK: - Triagem

    public func sugerir(para captura: Capture, agora: Date = Date()) async -> TriageSuggestion {
        do {
            return try await triager.sugerir(para: captura, agora: agora)
        } catch {
            return RuleBasedTriager(calendario: calendario).analisar(captura.text, agora: agora)
        }
    }

    /// Aceita uma proposta e materializa o que ela implica.
    public func aceitar(
        _ sugestao: TriageSuggestion, para captura: Capture, agora: Date = Date()
    ) {
        do {
            switch sugestao.kind {
            case .lixo:
                break   // A captura fica marcada como triada e desaparece.

            case .referencia:
                var tarefa = sugestao.materializar(origem: captura, agora: agora)
                tarefa.status = .someday
                try store.guardar(tarefa)

            case .accao:
                try store.guardar(sugestao.materializar(origem: captura, agora: agora))

            case .espera:
                let tarefa = sugestao.materializar(origem: captura, agora: agora)
                try store.guardar(tarefa)
                let pendente = WaitingFor(
                    taskID: tarefa.id,
                    owner: sugestao.waitingOn ?? "Por identificar",
                    channel: sugestao.channel ?? .email,
                    requestedAt: agora,
                    calendario: calendario
                )
                try store.guardar(pendente)
            }

            try store.marcarTriada(captura.id, em: agora)
            inbox.removeAll { $0.id == captura.id }
            tarefas = try store.tarefas()
            pendentes = try store.pendentes()
        } catch {
            ultimoErro = error.localizedDescription
        }
    }

    public func descartar(_ captura: Capture, agora: Date = Date()) {
        do {
            try store.marcarTriada(captura.id, em: agora)
            inbox.removeAll { $0.id == captura.id }
        } catch {
            ultimoErro = error.localizedDescription
        }
    }

    // MARK: - Execução

    public func concluir(_ tarefa: TaskItem, agora: Date = Date()) {
        do {
            try store.concluir(tarefa.id, em: agora)
            tarefas = try store.tarefas()
            areas = try store.areas()
            recalcularLeituras(agora: agora)
            publicarInstantaneo()
        } catch {
            ultimoErro = error.localizedDescription
        }
    }

    public func guardar(_ tarefa: TaskItem, agora: Date = Date()) {
        do {
            var actualizada = tarefa
            actualizada.tocar(em: agora)
            try store.guardar(actualizada)
            tarefas = try store.tarefas()
        } catch {
            ultimoErro = error.localizedDescription
        }
    }

    public func guardar(_ plano: DayPlan) {
        do {
            try store.guardar(plano)
            planoDeHoje = try store.plano(para: Date(), calendario: calendario)
            publicarInstantaneo()
            // A notificação da manhã passa a dizer o nome da Rocha: uma
            // notificação genérica ignora-se ao fim de uma semana.
            let rocha = plano.rockID.flatMap { id in tarefas.first { $0.id == id }?.title }
            Task { await Notificacoes.actualizarAlinhamento(rocha: rocha) }
        } catch {
            ultimoErro = error.localizedDescription
        }
    }

    public func pausar(_ area: AreaID, dias: Int, agora: Date = Date()) {
        guard let ate = calendario.date(byAdding: .day, value: dias, to: agora) else { return }
        do {
            try store.pausar(area, ate: ate)
            areas = try store.areas()
            recalcularLeituras(agora: agora)
        } catch {
            ultimoErro = error.localizedDescription
        }
    }

    // MARK: - Ponte com os Lembretes

    /// Espelha a área Família na lista partilhada.
    ///
    /// Corre a cada abertura da app e no ritual. Toda a decisão sobre conflitos
    /// vem do `ReminderReconciler`, que é código puro e testado; aqui só se
    /// executa o que ele decidiu.
    public func sincronizarFamilia(agora: Date = Date()) async {
        guard acessoAosLembretes else { return }
        avisoDaPonte = nil
        do {
            let lembretes = try await ponteDeLembretes.ler()
            let reconciler = ReminderReconciler(area: .familia)
            let accoes = reconciler.reconciliar(
                tarefas: tarefas, lembretes: lembretes, agora: agora
            )
            guard !accoes.isEmpty else {
                ultimaSincronizacaoFamilia = agora
                return
            }

            // Primeiro o lado de lá, para os identificadores novos voltarem.
            let novosEspelhos = try await ponteDeLembretes.aplicar(accoes)

            // Depois o lado de cá.
            for accao in accoes {
                switch accao {
                case .criarTarefa(let espelho):
                    try store.guardar(reconciler.tarefa(de: espelho, agora: agora))

                case .actualizarTarefa(let tarefa):
                    try store.guardar(tarefa)

                case .concluirTarefa(let id):
                    try store.concluir(id, em: agora)

                case .desligarEspelho(let id):
                    // Nunca apaga a tarefa — só lhe tira a ligação.
                    if var tarefa = tarefas.first(where: { $0.id == id }) {
                        tarefa.externalID = nil
                        tarefa.tocar(em: agora)
                        try store.guardar(tarefa)
                    }

                case .criarLembrete, .actualizarLembrete, .concluirLembrete:
                    continue
                }
            }

            // Guardar os identificadores atribuídos. Sem isto, a passagem
            // seguinte criava os mesmos lembretes outra vez.
            for (taskID, externalID) in novosEspelhos {
                guard var tarefa = tarefas.first(where: { $0.id == taskID }) else { continue }
                tarefa.externalID = externalID
                try store.guardar(tarefa)
            }

            tarefas = try store.tarefas()
            areas = try store.areas()
            inbox = try store.inbox()
            recalcularLeituras(agora: agora)
            publicarInstantaneo()
            ultimaSincronizacaoFamilia = agora
        } catch {
            // A ponte falhar não pode partir a app: a Família continua a
            // funcionar como área local até o acesso voltar.
            avisoDaPonte = error.localizedDescription
        }
    }

    // MARK: - Capacidade real

    /// A capacidade de um dia, a partir do calendário quando há acesso.
    ///
    /// Sem acesso, cai para um dia típico — e as Definições dizem que está a
    /// usar uma estimativa, em vez de a app fingir que sabe.
    public func capacidade(para dia: Date) async -> Capacity {
        guard acessoAoCalendario.podeLer else {
            return CapacityCalculator().calcular(blocosOcupados: [])
        }
        return await leitorDeCalendario.capacidade(de: dia, calendario: calendario)
    }

    // MARK: - Permissões

    public func verificarAcessos() async {
        acessoAoCalendario = await leitorDeCalendario.pedirAcesso()
        acessoAosLembretes = await ponteDeLembretes.pedirAcesso()
    }

    public func escolherLista(_ nome: String) {
        ponteDeLembretes = RemindersBridge(nomeDaLista: nome)
    }

    public var listasDeLembretes: [String] {
        ponteDeLembretes.listasDisponiveis()
    }

    // MARK: - Derivados

    /// Escreve o que os widgets mostram e manda-os refrescar.
    ///
    /// Chamado sempre que muda alguma coisa visível de fora: ao recarregar, ao
    /// fechar o plano e ao concluir uma tarefa. Um widget desactualizado no ecrã
    /// principal mina a confiança no sistema mais depressa do que um erro.
    func publicarInstantaneo() {
        let instantaneo = InstantaneoDoDia.construir(
            plano: planoDeHoje, tarefas: tarefas, leituras: leituras
        )
        try? instantaneo.escrever()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func recalcularLeituras(agora: Date = Date()) {
        leituras = AreaThermometer().ler(
            areas: areas, tarefas: tarefas, pendentes: pendentes,
            agora: agora, calendario: calendario
        )
    }

    public var areasEscuras: [AreaReading] {
        AreaThermometer().bloqueios(leituras)
    }

    public func tarefas(com ids: [UUID]) -> [TaskItem] {
        let porID = Dictionary(tarefas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { porID[$0] }
    }

    public var followUpsVencidos: [WaitingFor] {
        FollowUpPolicy.vencidos(pendentes)
    }

    public var projectosParados: [StalledProject] {
        ProjectAudit.semProximaAccao(
            projectos: projectos, tarefas: tarefas, calendario: calendario
        )
    }

    /// Nome do dono, para a lista de esperas. Precisa da tarefa correspondente.
    public func tarefa(de pendente: WaitingFor) -> TaskItem? {
        tarefas.first { $0.id == pendente.taskID }
    }
}

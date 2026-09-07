import SwiftUI
import BussolaDomain

// MARK: - Passo 2 — Fechar o dia

/// O que ficou por fazer hoje, com uma escolha obrigatória por item.
///
/// Nada transita para amanhã em silêncio. É esse arrastamento silencioso que
/// produz a lista fantasma em que se deixa de acreditar — e a partir daí o
/// sistema já não serve para nada.
struct PassoFecharODia: View {
    @State var modelo: AppModel
    let avancar: () -> Void

    private var porFechar: [TaskItem] {
        guard let plano = modelo.planoDeHoje else { return [] }
        return modelo.tarefas(com: plano.ordemDeExecucao).filter { $0.status.estaAberta }
    }

    var body: some View {
        if porFechar.isEmpty {
            ContentUnavailableView {
                Label("Dia fechado", systemImage: "checkmark.seal")
            } description: {
                Text("Não ficou nada por decidir.")
            } actions: {
                Button("Continuar", action: avancar).buttonStyle(.borderedProminent)
            }
        } else {
            List {
                Section {
                    ForEach(porFechar) { tarefa in
                        LinhaDeDecisao(tarefa: tarefa) { decisao in
                            aplicar(decisao, a: tarefa)
                        }
                    }
                } header: {
                    Text("Ficou por fazer")
                } footer: {
                    Text("Cada uma precisa de uma decisão. Nada passa para amanhã sozinho.")
                }

                Section {
                    Button("Continuar", action: avancar)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func aplicar(_ decisao: Decisao, a tarefa: TaskItem) {
        var actualizada = tarefa
        switch decisao {
        case .reagendar:
            actualizada.status = .next
        case .largar:
            actualizada.status = .dropped
        case .esperar:
            actualizada.status = .waiting
        case .algumDia:
            actualizada.status = .someday
        }
        modelo.guardar(actualizada)
    }

    enum Decisao { case reagendar, largar, esperar, algumDia }
}

struct LinhaDeDecisao: View {
    let tarefa: TaskItem
    let decidir: (PassoFecharODia.Decisao) -> Void

    @State private var decidida = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tarefa.title).font(.subheadline)
                Spacer()
                if decidida {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }

            if !decidida {
                HStack(spacing: 8) {
                    botao("Reagendar", .reagendar)
                    botao("À espera", .esperar)
                    botao("Um dia", .algumDia)
                    botao("Largar", .largar)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func botao(_ titulo: String, _ decisao: PassoFecharODia.Decisao) -> some View {
        Button(titulo) {
            decidir(decisao)
            withAnimation { decidida = true }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

// MARK: - Passo 3 — Escolher amanhã

struct PassoEscolher: View {
    @State var modelo: AppModel
    let proposta: PlanProposal
    @Binding var construtor: DayPlanBuilder
    let avancar: () -> Void

    @State private var erro: String?
    @State private var aTrocar: TaskItem?

    var body: some View {
        List {
            Section {
                CabecalhoDeCapacidade(
                    capacidade: proposta.capacidade,
                    comprometidos: construtor.minutosComprometidos,
                    excede: construtor.excedeCapacidade,
                    excesso: construtor.minutosEmExcesso
                )
            }

            if !proposta.bloqueios.isEmpty {
                Section {
                    ForEach(proposta.bloqueios) { leitura in
                        LinhaDeBloqueio(leitura: leitura) { dias in
                            modelo.pausar(leitura.area, dias: dias)
                        }
                    }
                } header: {
                    Text("A decidir antes de continuar")
                } footer: {
                    Text("Uma área escura há mais de duas semanas ou tem trabalho por fazer, ou devia estar em pausa. O que não pode é ficar num limbo.")
                }
            }

            Section("A Rocha") {
                if let rocha = construtor.rock {
                    LinhaEscolhida(tarefa: rocha, razao: razao(para: rocha)) {
                        construtor.removerRocha()
                    }
                } else {
                    Text("Sem Rocha amanhã — não há espaço para um bloco profundo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(Array(construtor.pebbles.enumerated()), id: \.element.id) { indice, pedra in
                    LinhaEscolhida(numero: indice + 1, tarefa: pedra, razao: razao(para: pedra)) {
                        construtor.removerPedra(pedra.id)
                    }
                }
                if construtor.pebbles.count < DayPlan.limiteDePedras {
                    Button {
                        aTrocar = construtor.pebbles.first
                    } label: {
                        Label("Escolher outra", systemImage: "plus.circle")
                    }
                }
            } header: {
                Text("As Pedras (\(construtor.pebbles.count)/\(DayPlan.limiteDePedras))")
            } footer: {
                Text("Para acrescentar uma quarta, tens de tirar outra. É aqui que se decide o dia.")
            }

            Section {
                Button("Continuar", action: avancar)
                    .frame(maxWidth: .infinity)
                    .disabled(construtor.estaVazio)
            }
        }
        .sheet(item: $aTrocar) { _ in
            SelectorDeTarefa(
                candidatas: candidatasDisponiveis,
                escolher: { escolhida in
                    do { try construtor.acrescentarPedra(escolhida) }
                    catch let falha as PlanError { erro = falha.mensagem }
                    catch { erro = error.localizedDescription }
                    aTrocar = nil
                }
            )
        }
        .alert("Não deu", isPresented: .constant(erro != nil)) {
            Button("Está bem") { erro = nil }
        } message: {
            Text(erro ?? "")
        }
    }

    private var candidatasDisponiveis: [TaskItem] {
        modelo.tarefas.filter {
            $0.estaDisponivel(em: Date()) && !$0.eAreia && !construtor.contem($0.id)
                && $0.status != .waiting
        }
    }

    private func razao(para tarefa: TaskItem) -> String? {
        if proposta.rocha?.task.id == tarefa.id { return proposta.rocha?.razao }
        return proposta.pedras.first { $0.task.id == tarefa.id }?.razao
    }
}

struct CabecalhoDeCapacidade: View {
    let capacidade: Capacity
    let comprometidos: Int
    let excede: Bool
    let excesso: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Capacidade de amanhã")
                    .font(.subheadline)
                Spacer()
                Text(capacidade.descricao)
                    .font(.headline.monospacedDigit())
            }
            Text("Já reservados \(Duracao.texto(capacidade.bufferMinutes)) para o imprevisto.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if excede {
                Label(
                    "Estás \(Duracao.texto(excesso)) acima. Tira alguma coisa.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LinhaDeBloqueio: View {
    let leitura: AreaReading
    let pausar: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(leitura.temperatura.cor).frame(width: 9, height: 9)
                Text(leitura.area.nome).font(.subheadline.weight(.medium))
                Spacer()
                Text(leitura.descricaoDoToque)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button("Pausar 30 dias") { pausar(30) }
                Button("Pausar 90 dias") { pausar(90) }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct LinhaEscolhida: View {
    var numero: Int?
    let tarefa: TaskItem
    let razao: String?
    let remover: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(numero.map { "\($0). \(tarefa.title)" } ?? tarefa.title)
                    .font(.subheadline)
                HStack(spacing: 8) {
                    EtiquetaDeArea(tarefa.area)
                    Text(Duracao.texto(tarefa.estimatedMinutes))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let razao {
                    Text("Subiu porque \(razao).")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button(role: .destructive, action: remover) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(minWidth: Tema.alvoMinimo, minHeight: Tema.alvoMinimo, alignment: .trailing)
            .accessibilityLabel("Tirar \(tarefa.title) do plano")
        }
    }
}

struct SelectorDeTarefa: View {
    let candidatas: [TaskItem]
    let escolher: (TaskItem) -> Void

    var body: some View {
        NavigationStack {
            List(candidatas) { tarefa in
                Button {
                    escolher(tarefa)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tarefa.title).foregroundStyle(Tema.tinta)
                        HStack(spacing: 8) {
                            EtiquetaDeArea(tarefa.area)
                            Text(Duracao.texto(tarefa.estimatedMinutes))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Escolher tarefa")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if candidatas.isEmpty {
                    ContentUnavailableView(
                        "Sem candidatas",
                        systemImage: "tray",
                        description: Text("Não há tarefas disponíveis fora do plano.")
                    )
                }
            }
        }
    }
}

// MARK: - Passo 4 — Ancorar

/// Cada Pedra recebe um *quando* e um *onde*.
///
/// É o passo que toda a gente quer saltar e o que tem melhor evidência por trás:
/// pistas situacionais associadas a um momento e a um lugar são recordadas
/// muito melhor do que uma intenção vaga. Sem âncora, o plano não fecha.
struct PassoAncorar: View {
    @Binding var construtor: DayPlanBuilder
    let concluir: () -> Void

    private static let quandos = [
        "assim que acordar", "depois do pequeno-almoço", "depois de deixar a miúda",
        "a meio da manhã", "antes do almoço", "logo a seguir ao almoço",
        "a meio da tarde", "antes de sair", "depois do jantar",
    ]

    private static let ondes = [
        "no escritório", "no carro", "em casa", "na obra",
        "no café", "a caminho", "ao telefone",
    ]

    var body: some View {
        List {
            Section {
                Text("Quando e onde. É o que separa lembrar de fazer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let rocha = construtor.rock {
                Section("A Rocha") {
                    EditorDeAncora(tarefa: rocha, quandos: Self.quandos, ondes: Self.ondes) {
                        actualizada in aplicarRocha(actualizada)
                    }
                }
            }

            if !construtor.pebbles.isEmpty {
                Section("As Pedras") {
                    ForEach(construtor.pebbles) { pedra in
                        EditorDeAncora(tarefa: pedra, quandos: Self.quandos, ondes: Self.ondes) {
                            actualizada in aplicarPedra(actualizada)
                        }
                    }
                }
            }

            Section {
                Button("Fechar o dia", action: concluir)
                    .frame(maxWidth: .infinity)
                    .disabled(!construtor.semAncora.isEmpty)
            } footer: {
                if !construtor.semAncora.isEmpty {
                    Text("Faltam \(construtor.semAncora.count) por ancorar.")
                }
            }
        }
    }

    private func aplicarRocha(_ tarefa: TaskItem) {
        try? construtor.definirRocha(tarefa)
    }

    private func aplicarPedra(_ tarefa: TaskItem) {
        let ordem = construtor.pebbles.map(\.id)
        construtor.removerPedra(tarefa.id)
        try? construtor.acrescentarPedra(tarefa)
        construtor.reordenarPedras(ordem)
    }
}

struct EditorDeAncora: View {
    let tarefa: TaskItem
    let quandos: [String]
    let ondes: [String]
    let aoMudar: (TaskItem) -> Void

    @State private var quando: String = ""
    @State private var onde: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tarefa.title).font(.subheadline.weight(.medium))

            Picker("Quando", selection: $quando) {
                Text("— quando —").tag("")
                ForEach(quandos, id: \.self) { Text($0).tag($0) }
            }
            Picker("Onde", selection: $onde) {
                Text("— onde —").tag("")
                ForEach(ondes, id: \.self) { Text($0).tag($0) }
            }
        }
        .onAppear {
            quando = tarefa.anchor?.quando ?? ""
            onde = tarefa.anchor?.onde ?? ""
        }
        .onChange(of: quando) { propagar() }
        .onChange(of: onde) { propagar() }
    }

    private func propagar() {
        guard !quando.isEmpty, !onde.isEmpty else { return }
        var actualizada = tarefa
        actualizada.anchor = Anchor(quando: quando, onde: onde)
        actualizada.status = .planned
        aoMudar(actualizada)
    }
}

// MARK: - Fecho

struct PassoFeito: View {
    let sair: () -> Void
    @State private var apareceu = false

    var body: some View {
        VStack(spacing: Tema.espaco) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .opacity(apareceu ? 1 : 0.4)

            Text("Fechado.")
                .font(.largeTitle.weight(.semibold))

            Text("Amanhã já está decidido. Não precisas de pensar mais nisto hoje.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Boa noite", action: sair)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { apareceu = true }
        }
    }
}

// MARK: - Editor de sugestão

struct EditorDeSugestao: View {
    let captura: Capture
    @State var sugestao: TriageSuggestion
    let guardar: (TriageSuggestion) -> Void

    @Environment(\.dismiss) private var fechar

    var body: some View {
        NavigationStack {
            Form {
                Section("O que foi capturado") {
                    Text(captura.text).font(.subheadline)
                }

                Section("Como fica") {
                    TextField("Acção", text: $sugestao.actionTitle, axis: .vertical)

                    Picker("Área", selection: $sugestao.area) {
                        ForEach(AreaID.allCases, id: \.self) { area in
                            Text(area.nome).tag(area)
                        }
                    }

                    Picker("Tipo", selection: $sugestao.kind) {
                        ForEach(ItemKind.allCases, id: \.self) { tipo in
                            Text(tipo.descricao).tag(tipo)
                        }
                    }

                    Picker("Demora", selection: $sugestao.estimatedMinutes) {
                        ForEach([5, 15, 30, 60, 90], id: \.self) { minutos in
                            Text(Duracao.texto(minutos)).tag(minutos)
                        }
                    }
                }

                if sugestao.kind == .espera {
                    Section("À espera de") {
                        TextField(
                            "Quem",
                            text: Binding(
                                get: { sugestao.waitingOn ?? "" },
                                set: { sugestao.waitingOn = $0.isEmpty ? nil : $0 }
                            )
                        )
                        Picker("Canal", selection: Binding(
                            get: { sugestao.channel ?? .email },
                            set: { sugestao.channel = $0 }
                        )) {
                            ForEach(Channel.allCases, id: \.self) { canal in
                                Text(canal.descricao).tag(canal)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Corrigir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { fechar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar(sugestao) }
                }
            }
        }
    }
}

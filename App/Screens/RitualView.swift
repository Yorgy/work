import SwiftUI
import BussolaDomain

/// Seis minutos às 21h. Quatro passos, sem saltar nenhum.
///
/// Este é o produto. Tudo o resto na app existe para alimentar ou consumir o
/// que aqui se decide.
struct RitualView: View {
    let modelo: AppModel
    @Environment(\.dismiss) private var fechar

    @State private var passo: Passo = .esvaziar
    @State private var construtor: DayPlanBuilder?
    @State private var proposta: PlanProposal?
    @State private var erro: String?

    enum Passo: Int, CaseIterable {
        case esvaziar, fecharODia, escolher, ancorar, feito

        var titulo: String {
            switch self {
            case .esvaziar:   "Esvaziar a Inbox"
            case .fecharODia: "Fechar o dia"
            case .escolher:   "Escolher amanhã"
            case .ancorar:    "Ancorar"
            case .feito:      "Fechado"
            }
        }

        var duracao: String {
            switch self {
            case .esvaziar:   "~2 min"
            case .fecharODia: "~1 min"
            case .escolher:   "~2 min"
            case .ancorar:    "~1 min"
            case .feito:      ""
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if passo != .feito {
                    BarraDeProgresso(passo: passo)
                }

                Group {
                    switch passo {
                    case .esvaziar:   PassoEsvaziar(modelo: modelo, avancar: avancar)
                    case .fecharODia: PassoFecharODia(modelo: modelo, avancar: avancar)
                    case .escolher:   passoEscolher
                    case .ancorar:    passoAncorar
                    case .feito:      PassoFeito { fechar() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(passo.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if passo != .feito {
                        Button("Mais logo") { fechar() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(passo.duracao)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Não deu", isPresented: Binding(
                get: { erro != nil },
                set: { if !$0 { erro = nil } }
            )) {
                Button("Está bem") { erro = nil }
            } message: {
                Text(erro ?? "")
            }
        }
        .interactiveDismissDisabled(passo == .ancorar)
    }

    // MARK: - Passo 3

    @ViewBuilder
    private var passoEscolher: some View {
        if let proposta, let construtor = Binding($construtor) {
            PassoEscolher(
                modelo: modelo,
                proposta: proposta,
                construtor: construtor,
                avancar: avancar
            )
        } else {
            ProgressView().task { await prepararProposta() }
        }
    }

    // MARK: - Passo 4

    @ViewBuilder
    private var passoAncorar: some View {
        if let construtor = Binding($construtor) {
            PassoAncorar(construtor: construtor) { fecharPlano() }
        } else {
            ProgressView()
        }
    }

    // MARK: - Acções

    private func avancar() {
        guard let seguinte = Passo(rawValue: passo.rawValue + 1) else { return }
        withAnimation { passo = seguinte }
    }

    private func prepararProposta() async {
        let calendario = Calendar.current
        guard let amanha = calendario.date(byAdding: .day, value: 1, to: Date()) else { return }

        // A capacidade vem do calendário real quando há acesso. Se amanhã tens
        // quatro horas de reuniões, não se propõe uma Rocha de 90 minutos.
        let capacidade = await modelo.capacidade(para: amanha)

        proposta = PlanProposer(calendario: calendario).propor(
            tarefas: modelo.tarefas,
            leituras: modelo.leituras,
            capacidade: capacidade,
            agora: Date()
        )

        var novo = DayPlanBuilder(
            date: amanha, capacityMinutes: capacidade.availableMinutes, calendario: calendario
        )
        if let rocha = proposta?.rocha { try? novo.definirRocha(rocha.task) }
        for pedra in proposta?.pedras ?? [] { try? novo.acrescentarPedra(pedra.task) }
        for areia in (proposta?.areia ?? []).prefix(8) { novo.acrescentarAreia(areia) }
        construtor = novo
    }

    private func fecharPlano() {
        guard let construtor else { return }
        do {
            let plano = try construtor.construir()
            modelo.guardar(plano)
            // Guarda as âncoras editadas no ritual.
            if let rocha = construtor.rock { modelo.guardar(rocha) }
            for pedra in construtor.pebbles { modelo.guardar(pedra) }
            withAnimation { passo = .feito }
        } catch let falha as PlanError {
            erro = falha.mensagem
        } catch {
            erro = error.localizedDescription
        }
    }
}

// MARK: - Progresso

struct BarraDeProgresso: View {
    let passo: RitualView.Passo

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { indice in
                Capsule()
                    .fill(indice <= passo.rawValue ? Color.accentColor : Color(.systemFill))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Tema.espaco)
        .padding(.vertical, 10)
        .accessibilityLabel("Passo \(passo.rawValue + 1) de 4")
    }
}

// MARK: - Passo 1 — Esvaziar

struct PassoEsvaziar: View {
    let modelo: AppModel
    let avancar: () -> Void

    @State private var sugestoes: [UUID: TriageSuggestion] = [:]
    @State private var aEditar: Capture?

    var body: some View {
        if modelo.inbox.isEmpty {
            ContentUnavailableView {
                Label("Inbox a zero", systemImage: "tray")
            } description: {
                Text("Nada por triar. É este o objectivo, todas as noites.")
            } actions: {
                Button("Continuar", action: avancar).buttonStyle(.borderedProminent)
            }
        } else {
            VStack {
                ScrollView {
                    LazyVStack(spacing: Tema.espaco) {
                        ForEach(modelo.inbox) { captura in
                            CartaoDeTriagem(
                                captura: captura,
                                sugestao: sugestoes[captura.id],
                                aceitar: { aceitar(captura) },
                                descartar: { modelo.descartar(captura) },
                                corrigir: { aEditar = captura }
                            )
                            .task { await carregarSugestao(captura) }
                        }
                    }
                    .padding(Tema.espaco)
                }

                Text("\(modelo.inbox.count) por triar")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .sheet(item: $aEditar) { captura in
                EditorDeSugestao(
                    captura: captura,
                    sugestao: sugestoes[captura.id] ?? .init(actionTitle: captura.text, area: .pessoal)
                ) { corrigida in
                    sugestoes[captura.id] = corrigida
                    modelo.aceitar(corrigida, para: captura)
                    aEditar = nil
                }
            }
        }
    }

    private func carregarSugestao(_ captura: Capture) async {
        guard sugestoes[captura.id] == nil else { return }
        sugestoes[captura.id] = await modelo.sugerir(para: captura)
    }

    private func aceitar(_ captura: Capture) {
        guard let sugestao = sugestoes[captura.id] else { return }
        // Confiança baixa nunca passa por swipe: é exactamente o caso em que a
        // pessoa tem de olhar.
        if sugestao.exigeRevisaoManual {
            aEditar = captura
        } else {
            modelo.aceitar(sugestao, para: captura)
        }
    }
}

struct CartaoDeTriagem: View {
    let captura: Capture
    let sugestao: TriageSuggestion?
    let aceitar: () -> Void
    let descartar: () -> Void
    let corrigir: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(captura.text)
                .font(.headline)

            if captura.audioPath != nil {
                Label("Áudio original guardado", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let sugestao {
                HStack(spacing: 10) {
                    EtiquetaDeArea(sugestao.area)
                    Text("·").foregroundStyle(.tertiary)
                    Text(sugestao.kind.descricao).font(.caption)
                    Spacer()
                    IndicadorDeConfianca(valor: sugestao.confidence)
                }
                if let dono = sugestao.waitingOn {
                    Label("Espera-se de \(dono)", systemImage: "person")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ProgressView().controlSize(.small)
            }

            HStack(spacing: Tema.espaco) {
                Button(role: .destructive, action: descartar) {
                    Label("Descartar", systemImage: "xmark")
                }
                Spacer()
                Button("Corrigir", action: corrigir)
                Button(action: aceitar) {
                    Label("Aceitar", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.subheadline)
            .buttonStyle(.bordered)
            .labelStyle(.titleOnly)
        }
        .cartao()
    }
}

struct IndicadorDeConfianca: View {
    let valor: Int

    var body: some View {
        Text("\(valor)%")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(cor.opacity(0.18), in: Capsule())
            .foregroundStyle(cor)
            .accessibilityLabel("Confiança da proposta: \(valor) por cento")
    }

    private var cor: Color {
        if valor >= 80 { return .green }
        if valor >= TriageSuggestion.limiarDeConfianca { return .orange }
        return .red
    }
}

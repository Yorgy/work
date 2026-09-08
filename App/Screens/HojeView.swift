import SwiftUI
import BussolaDomain

/// O ecrã de omissão. Estrutura vertical, sem separadores internos.
///
/// **Não tem botão de adicionar tarefa ao dia.** Adicionar ao dia é sempre um
/// acto do ritual. Se algo urgente aparece a meio do dia, entra pela Captura
/// como tudo o resto — a defesa contra a interrupção é arquitectural, não de
/// força de vontade.
struct HojeView: View {
    let modelo: AppModel
    @Binding var aMostrarRitual: Bool

    var body: some View {
        NavigationStack {
            List {
                if let plano = modelo.planoDeHoje, !plano.estaVazio {
                    seccaoDaRocha(plano)
                    seccaoDasPedras(plano)
                    seccaoDaAreia(plano)
                } else {
                    seccaoSemPlano
                }
                seccaoDeEsperas
            }
            .listStyle(.insetGrouped)
            .navigationTitle(dataDeHoje)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !modelo.inbox.isEmpty {
                        Button {
                            aMostrarRitual = true
                        } label: {
                            Label("\(modelo.inbox.count)", systemImage: "tray.full")
                        }
                        .accessibilityLabel("\(modelo.inbox.count) por triar")
                    }
                }
            }
            .refreshable { await modelo.recarregar() }
        }
    }

    // MARK: - Secções

    @ViewBuilder
    private func seccaoDaRocha(_ plano: DayPlan) -> some View {
        if let rochaID = plano.rockID, let rocha = modelo.tarefas(com: [rochaID]).first {
            Section {
                LinhaDeRocha(tarefa: rocha) { modelo.concluir(rocha) }
            } header: {
                Text("A Rocha")
            } footer: {
                Text("Se só isto acontecer, o dia foi bom.")
            }
        }
    }

    @ViewBuilder
    private func seccaoDasPedras(_ plano: DayPlan) -> some View {
        let pedras = modelo.tarefas(com: plano.pebbleIDs)
        if !pedras.isEmpty {
            Section("As Pedras") {
                ForEach(Array(pedras.enumerated()), id: \.element.id) { indice, pedra in
                    LinhaDePedra(
                        numero: indice + 1,
                        tarefa: pedra,
                        // A ordem é informação: a 2 só se activa quando a 1 fecha.
                        activa: indice == primeiraPorFazer(pedras)
                    ) {
                        modelo.concluir(pedra)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func seccaoDaAreia(_ plano: DayPlan) -> some View {
        let areia = modelo.tarefas(com: plano.sandIDs).filter { $0.status.estaAberta }
        if !areia.isEmpty {
            Section {
                DisclosureGroup("Areia (\(areia.count))") {
                    ForEach(areia) { tarefa in
                        Button {
                            modelo.concluir(tarefa)
                        } label: {
                            HStack {
                                Image(systemName: "circle")
                                Text(tarefa.title).foregroundStyle(Tema.tinta)
                                Spacer()
                                EtiquetaDeArea(tarefa.area)
                            }
                        }
                    }
                }
            } footer: {
                Text("Tudo abaixo de cinco minutos. Faz-se numa passagem só.")
            }
        }
    }

    private var seccaoSemPlano: some View {
        Section {
            ContentUnavailableView {
                Label("O dia ainda não está decidido", systemImage: "moon.stars")
            } description: {
                Text("O plano faz-se na véspera, às 21h. De manhã já é tarde para planear.")
            } actions: {
                Button("Fazer o ritual agora") { aMostrarRitual = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var seccaoDeEsperas: some View {
        let vencidos = modelo.followUpsVencidos
        if !vencidos.isEmpty {
            Section {
                ForEach(vencidos.prefix(4)) { pendente in
                    LinhaDeEspera(pendente: pendente, tarefa: modelo.tarefa(de: pendente))
                }
            } header: {
                Text("À espera de \(vencidos.count) \(vencidos.count == 1 ? "pessoa" : "pessoas")")
            } footer: {
                Text("Consciência, não acção. Trata-se na revisão.")
            }
        }
    }

    // MARK: - Auxiliares

    private func primeiraPorFazer(_ pedras: [TaskItem]) -> Int? {
        pedras.firstIndex { $0.status.estaAberta }
    }

    private var dataDeHoje: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_PT")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: Date()).capitalizadaPrimeira
    }
}

// MARK: - Linhas

struct LinhaDeRocha: View {
    let tarefa: TaskItem
    let concluir: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: concluir) {
                    Image(systemName: tarefa.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(tarefa.status == .done ? Color.green : Color.accentColor)
                }
                .buttonStyle(.plain)
                .frame(minWidth: Tema.alvoMinimo, minHeight: Tema.alvoMinimo, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text(tarefa.title)
                        .font(.title3.weight(.semibold))
                        .strikethrough(tarefa.status == .done)

                    if let ancora = tarefa.anchor {
                        Label(ancora.descricao, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                EtiquetaDeArea(tarefa.area)
                Label(Duracao.texto(tarefa.estimatedMinutes), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct LinhaDePedra: View {
    let numero: Int
    let tarefa: TaskItem
    let activa: Bool
    let concluir: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: concluir) {
                Image(systemName: simbolo)
                    .font(.title3)
                    .foregroundStyle(cor)
            }
            .buttonStyle(.plain)
            .frame(minWidth: Tema.alvoMinimo, minHeight: Tema.alvoMinimo, alignment: .leading)
            .disabled(!activa && tarefa.status.estaAberta)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(numero). \(tarefa.title)")
                    .strikethrough(tarefa.status == .done)
                    .foregroundStyle(activa || tarefa.status == .done ? Tema.tinta : Tema.tenue)

                if let ancora = tarefa.anchor, activa {
                    Text(ancora.descricao)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            EtiquetaDeArea(tarefa.area)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(activa ? "Pedra activa" : "Fecha a anterior primeiro")
    }

    private var simbolo: String {
        if tarefa.status == .done { return "checkmark.circle.fill" }
        return activa ? "largecircle.fill.circle" : "circle"
    }

    private var cor: Color {
        if tarefa.status == .done { return .green }
        return activa ? .accentColor : Tema.tenue
    }
}

struct LinhaDeEspera: View {
    let pendente: WaitingFor
    let tarefa: TaskItem?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(tarefa?.title ?? "Pedido sem tarefa")
                    .font(.subheadline)
                Text("\(pendente.owner) · \(pendente.diasDeSilencio(ate: Date())) dias de silêncio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if FollowUpPolicy.exigeDecisao(pendente) {
                Text("decidir")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.red.opacity(0.15), in: Capsule())
                    .foregroundStyle(.red)
            }
        }
    }
}

extension String {
    var capitalizadaPrimeira: String {
        guard let primeira = first else { return self }
        return String(primeira).uppercased() + dropFirst()
    }
}

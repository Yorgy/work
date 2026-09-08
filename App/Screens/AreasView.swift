import SwiftUI
import BussolaDomain

/// O termómetro.
///
/// Não mostra contagens de tarefas em destaque — isso é ansiedade formatada.
/// Mostra **atenção**: quanto tempo passou desde que cada área foi atendida.
///
/// Responde à pergunta que hoje não tem resposta — *o que é que eu estou a
/// deixar cair?* — que é muito melhor do que *o que é que eu tenho para fazer?*
struct AreasView: View {
    let modelo: AppModel
    @State private var areaAberta: AreaID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(modelo.leituras) { leitura in
                        Button {
                            areaAberta = leitura.area
                        } label: {
                            LinhaDeArea(leitura: leitura)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("O toque conta quando concluis uma tarefa da área. Olhar para uma área não é atendê-la.")
                }
            }
            .navigationTitle("Áreas")
            .refreshable { await modelo.recarregar() }
            .navigationDestination(item: $areaAberta) { area in
                DetalheDeArea(modelo: modelo, area: area)
            }
        }
    }
}

struct LinhaDeArea: View {
    let leitura: AreaReading

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: leitura.area.simbolo)
                .font(.title3)
                .foregroundStyle(leitura.area.cor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(leitura.area.nome).font(.body.weight(.medium))
                    if leitura.emPausa {
                        Text("em pausa")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemFill), in: Capsule())
                    }
                }
                // Cor **e** texto: a cor nunca é o único sinal.
                Text(leitura.descricaoDoToque)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Circle()
                    .fill(leitura.emPausa ? Color(.systemFill) : leitura.temperatura.cor)
                    .frame(width: 10, height: 10)
                Text("\(leitura.tarefasAbertas)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(leitura.area.nome), \(leitura.temperatura.descricao), tocada \(leitura.descricaoDoToque), \(leitura.tarefasAbertas) tarefas abertas"
        )
    }
}

struct DetalheDeArea: View {
    let modelo: AppModel
    let area: AreaID

    private var tarefas: [TaskItem] {
        modelo.tarefas
            .filter { $0.area == area && $0.status.estaAberta }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            if tarefas.isEmpty {
                ContentUnavailableView(
                    "Nada aberto",
                    systemImage: "checkmark.circle",
                    description: Text("Esta área está sem trabalho pendente.")
                )
            } else {
                ForEach(tarefas) { tarefa in
                    HStack(alignment: .top) {
                        Button {
                            modelo.concluir(tarefa)
                        } label: {
                            Image(systemName: "circle")
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: Tema.alvoMinimo, minHeight: Tema.alvoMinimo, alignment: .leading)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tarefa.title)
                            HStack(spacing: 8) {
                                if tarefa.status == .waiting {
                                    Label("à espera", systemImage: "hourglass")
                                }
                                if let due = tarefa.dueDate {
                                    Label(due.formatted(date: .abbreviated, time: .omitted),
                                          systemImage: "calendar")
                                }
                                Text(Duracao.texto(tarefa.estimatedMinutes))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(area.nome)
        .navigationBarTitleDisplayMode(.inline)
    }
}

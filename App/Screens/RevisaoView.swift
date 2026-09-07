import SwiftUI
import BussolaDomain

/// Revisão semanal, vinte minutos ao domingo.
///
/// Cinco secções em ecrã único. Não é uma lista de tarefas — é uma auditoria ao
/// sistema: o que arrefeceu, quem não respondeu, o que está parado sem ninguém
/// ter reparado.
struct RevisaoView: View {
    @State var modelo: AppModel
    @State private var nota = ""

    var body: some View {
        NavigationStack {
            List {
                seccaoTermometro
                seccaoEsperas
                seccaoProjectosParados
                seccaoRadar
                seccaoPergunta
                seccaoDiagnostico
            }
            .navigationTitle("Revisão")
            .refreshable { await modelo.recarregar() }
        }
    }

    // 1 — Que área esteve escura?
    private var seccaoTermometro: some View {
        Section {
            ForEach(modelo.leituras.prefix(3)) { leitura in
                HStack {
                    Circle().fill(leitura.temperatura.cor).frame(width: 9, height: 9)
                    Text(leitura.area.nome)
                    Spacer()
                    Text(leitura.descricaoDoToque)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("O que arrefeceu")
        } footer: {
            Text("As três áreas com menos atenção esta semana.")
        }
    }

    // 2 — Quem não respondeu.
    @ViewBuilder
    private var seccaoEsperas: some View {
        let vencidos = modelo.followUpsVencidos
        Section {
            if vencidos.isEmpty {
                Text("Ninguém em dívida contigo.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(vencidos) { pendente in
                    VStack(alignment: .leading, spacing: 5) {
                        LinhaDeEspera(pendente: pendente, tarefa: modelo.tarefa(de: pendente))
                        Text(FollowUpPolicy.rascunho(
                            para: pendente,
                            assunto: modelo.tarefa(de: pendente)?.title ?? "o assunto"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    }
                    .padding(.vertical, 3)
                }
            }
        } header: {
            Text("À espera de")
        } footer: {
            Text("O texto está pronto a copiar. Insistir mais de três vezes já não é esquecimento da outra pessoa — é uma decisão tua.")
        }
    }

    // 3 — O defeito silencioso.
    @ViewBuilder
    private var seccaoProjectosParados: some View {
        let parados = modelo.projectosParados
        if !parados.isEmpty {
            Section {
                ForEach(parados) { parado in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parado.project.name).font(.subheadline)
                            EtiquetaDeArea(parado.project.area)
                        }
                        Spacer()
                        Text("\(parado.diasParado) dias")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Projectos sem próxima acção")
            } footer: {
                Text("O defeito mais comum e o mais silencioso: o projecto parece vivo na lista e não avança porque ninguém decidiu o passo seguinte.")
            }
        }
    }

    // 4 — O que aí vem.
    @ViewBuilder
    private var seccaoRadar: some View {
        let proximas = modelo.tarefas
            .filter { tarefa in
                guard tarefa.status.estaAberta, let due = tarefa.dueDate else { return false }
                return due <= Date().addingTimeInterval(14 * 86_400)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        if !proximas.isEmpty {
            Section("Próximos 14 dias") {
                ForEach(proximas.prefix(10)) { tarefa in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tarefa.title).font(.subheadline)
                            EtiquetaDeArea(tarefa.area)
                        }
                        Spacer()
                        Text(tarefa.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // 5 — A pergunta que muda alguma coisa.
    private var seccaoPergunta: some View {
        Section {
            TextField(
                "O que correu mal esta semana e o que muda na próxima?",
                text: $nota, axis: .vertical
            )
            .lineLimit(3...6)
        } header: {
            Text("Uma pergunta")
        } footer: {
            Text("Sem esta, a revisão é só arrumação.")
        }
    }

    private var seccaoDiagnostico: some View {
        Section("Estado") {
            LabeledContent("iCloud", value: modelo.diagnostico.estado.descricao)
                .font(.caption)
            if modelo.diagnostico.capturasPorImportar > 0 {
                LabeledContent(
                    "Por importar",
                    value: "\(modelo.diagnostico.capturasPorImportar) capturas"
                )
                .font(.caption)
            }
            if let erro = modelo.ultimoErro {
                Text(erro).font(.caption).foregroundStyle(.red)
            }
        }
    }
}

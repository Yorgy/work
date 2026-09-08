import SwiftUI
import BussolaDomain
import BussolaBridge
import BussolaTriage

/// Onde as pontes se ligam e onde a app explica o que está degradado.
///
/// Uma app que perde funcionalidade em silêncio é uma app em que se deixa de
/// confiar: o utilizador nota que alguma coisa não bate certo, não percebe
/// porquê, e conclui que o sistema está partido. Aqui diz-se sempre o estado
/// real e o que fazer quanto a ele.
struct DefinicoesView: View {
    let modelo: AppModel
    @Environment(\.dismiss) private var fechar

    @State private var listaEscolhida = "Família"
    // Consultadas uma vez, não a cada reconstrução da vista: `listasDisponiveis`
    // e a disponibilidade do modelo local tocam em frameworks do sistema, e o
    // `body` de uma View corre muitas vezes.
    @State private var listas: [String] = []
    @State private var estadoDaIA = TriagerEstado(disponivel: false, razao: nil)

    var body: some View {
        NavigationStack {
            List {
                seccaoCalendario
                seccaoLembretes
                seccaoIA
                seccaoSync
                seccaoSobre
            }
            .navigationTitle("Definições")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { fechar() }
                }
            }
            .task {
                listas = modelo.listasDeLembretes
                listaEscolhida = listas.first ?? "Família"
                estadoDaIA = TriagerEstadoFactory.actual()
            }
        }
    }

    // MARK: - Calendário

    private var seccaoCalendario: some View {
        Section {
            LabeledContent("Acesso") {
                Text(textoDoCalendario)
                    .foregroundStyle(modelo.acessoAoCalendario.podeLer ? .green : .secondary)
            }
            if !modelo.acessoAoCalendario.podeLer {
                Button("Dar acesso ao calendário") {
                    Task { await verificar() }
                }
            }
        } header: {
            Text("Calendário")
        } footer: {
            Text(
                modelo.acessoAoCalendario.podeLer
                ? "A capacidade de amanhã é calculada a partir das tuas reuniões reais."
                : "Sem acesso, a capacidade usa um dia típico — uma estimativa, não a tua agenda. A Bússola só lê o calendário; nunca lá escreve."
            )
        }
    }

    private var textoDoCalendario: String {
        switch modelo.acessoAoCalendario {
        case .concedido:    "Concedido"
        case .negado:       "Negado"
        case .indisponivel: "Indisponível"
        }
    }

    // MARK: - Lembretes

    private var seccaoLembretes: some View {
        Section {
            LabeledContent("Acesso") {
                Text(modelo.acessoAosLembretes ? "Concedido" : "Por conceder")
                    .foregroundStyle(modelo.acessoAosLembretes ? .green : .secondary)
            }

            if modelo.acessoAosLembretes {
                if listas.isEmpty {
                    Text("Não encontrei listas nos Lembretes.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Picker("Lista a espelhar", selection: $listaEscolhida) {
                        ForEach(listas, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: listaEscolhida) { _, nova in
                        modelo.escolherLista(nova)
                        Task { await modelo.sincronizarFamilia() }
                    }
                }

                Button("Sincronizar agora") {
                    Task { await modelo.sincronizarFamilia() }
                }

                if let quando = modelo.ultimaSincronizacaoFamilia {
                    LabeledContent("Última passagem") {
                        Text(quando.formatted(date: .omitted, time: .shortened))
                            .font(.caption.monospacedDigit())
                    }
                }
            } else {
                Button("Dar acesso aos Lembretes") {
                    Task { await verificar() }
                }
            }

            if let aviso = modelo.avisoDaPonte {
                Text(aviso).font(.caption).foregroundStyle(.orange)
            }
        } header: {
            Text("Família partilhada")
        } footer: {
            Text("A área Família espelha-se numa lista partilhada dos Lembretes. É assim que a partilhas com quem não tem esta app instalada — e a app nunca apaga uma tarefa por causa de uma sincronização.")
        }
    }

    // MARK: - IA

    private var seccaoIA: some View {
        Section {
            LabeledContent("Triagem") {
                Text(estadoDaIA.disponivel ? "Modelo local" : "Regras")
                    .foregroundStyle(estadoDaIA.disponivel ? .green : .secondary)
            }
        } header: {
            Text("Inteligência")
        } footer: {
            Text(estadoDaIA.razao
                 ?? "As propostas da triagem são geradas no próprio iPhone. Nada do que capturas sai do dispositivo.")
        }
    }

    // MARK: - Estado

    private var seccaoSync: some View {
        Section("iCloud") {
            LabeledContent("Estado", value: modelo.diagnostico.estado.descricao)
                .font(.subheadline)
            if modelo.diagnostico.capturasPorImportar > 0 {
                LabeledContent(
                    "Por importar",
                    value: "\(modelo.diagnostico.capturasPorImportar)"
                )
            }
            Button("Verificar outra vez") {
                Task { await modelo.diagnostico.verificar() }
            }
        }
    }

    private var seccaoSobre: some View {
        Section {
            LabeledContent("Botão de Acção") {
                Text("Definições → Botão de Ação → Atalho → Bússola")
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
            }
        } footer: {
            Text("É esta configuração que faz o sistema funcionar. Sem ela, capturar volta a custar dez segundos — e a essa distância não se captura.")
        }
    }

    private func verificar() async {
        await modelo.verificarAcessos()
        listas = modelo.listasDeLembretes
        if let primeira = listas.first, !listas.contains(listaEscolhida) {
            listaEscolhida = primeira
            modelo.escolherLista(primeira)
        }
        await modelo.sincronizarFamilia()
    }
}

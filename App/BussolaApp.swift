import SwiftUI
import BussolaDomain
import BussolaPersistence

@main
struct BussolaApp: App {
    @State private var estado: EstadoDeArranque = .aArrancar

    var body: some Scene {
        WindowGroup {
            switch estado {
            case .aArrancar:
                ProgressView("A abrir a Bússola…")
                    .task { await arrancar() }

            case .pronto(let modelo):
                RaizView(modelo: modelo)

            case .falhou(let mensagem):
                FalhaDeArranqueView(mensagem: mensagem) {
                    estado = .aArrancar
                }
            }
        }
    }

    @MainActor
    private func arrancar() async {
        do {
            let modelo = try AppModel.arrancar()
            // Os acessos verificam-se antes do primeiro recarregar, para a
            // primeira passagem já poder usar o calendário e os Lembretes.
            await modelo.verificarAcessos()
            await modelo.recarregar()
            if await Notificacoes.pedirAutorizacao() {
                await Notificacoes.agendar()
            }
            estado = .pronto(modelo)
        } catch {
            estado = .falhou(error.localizedDescription)
        }
    }

    private enum EstadoDeArranque {
        case aArrancar
        case pronto(AppModel)
        case falhou(String)
    }
}

struct RaizView: View {
    let modelo: AppModel
    @Environment(\.scenePhase) private var fase

    @State private var separador: Separador = .hoje
    @State private var aMostrarCaptura = false
    @State private var aMostrarRitual = false

    enum Separador: Hashable { case hoje, areas, revisao }

    var body: some View {
        TabView(selection: $separador) {
            Tab("Hoje", systemImage: "sun.horizon", value: .hoje) {
                HojeView(modelo: modelo, aMostrarRitual: $aMostrarRitual)
            }
            Tab("Áreas", systemImage: "circle.grid.2x2", value: .areas) {
                AreasView(modelo: modelo)
            }
            Tab("Revisão", systemImage: "checklist", value: .revisao) {
                RevisaoView(modelo: modelo)
            }
        }
        // A captura está sempre a um toque, em qualquer separador. É o único
        // botão que a app mostra em todo o lado.
        .overlay(alignment: .bottomTrailing) {
            BotaoDeCaptura { aMostrarCaptura = true }
                .padding(.trailing, Tema.espaco)
                .padding(.bottom, 68)
        }
        .sheet(isPresented: $aMostrarCaptura) {
            CapturarView(modelo: modelo)
                .presentationDetents([.height(280)])
        }
        .fullScreenCover(isPresented: $aMostrarRitual) {
            RitualView(modelo: modelo)
        }
        .task(id: fase) {
            guard fase == .active else { return }
            await modelo.recarregar()
            // O widget de ecrã bloqueado abre a app já a pedir voz.
            if CaptureRouter.shared.consumir() { aMostrarCaptura = true }
        }
        .onOpenURL { url in
            if url.host == "ritual" { aMostrarRitual = true }
            if url.host == "capturar" { aMostrarCaptura = true }
        }
    }
}

struct BotaoDeCaptura: View {
    let accao: () -> Void

    var body: some View {
        Button(action: accao) {
            Image(systemName: "square.and.pencil")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 8, y: 4)
        }
        .accessibilityLabel("Capturar")
        .accessibilityHint("Assenta um pensamento na Inbox")
    }
}

struct FalhaDeArranqueView: View {
    let mensagem: String
    let tentarOutraVez: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("A Bússola não abriu", systemImage: "exclamationmark.icloud")
        } description: {
            // A mensagem real, não um "algo correu mal". Se o problema for o
            // iCloud, é isso que tem de aparecer para se poder resolver.
            Text(mensagem)
        } actions: {
            Button("Tentar outra vez", action: tentarOutraVez)
                .buttonStyle(.borderedProminent)
        }
    }
}

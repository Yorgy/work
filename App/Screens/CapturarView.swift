import SwiftUI
import BussolaDomain

/// O ecrã mais importante da app, e o mais pobre em funcionalidades.
///
/// Um campo e um microfone. **Sem selector de área, sem data, sem projecto.**
/// A tentação de "só mais um campinho para escolher a área" é a que mata o
/// sistema: cada campo reduz a taxa de captura de forma desproporcionada, e uma
/// ideia não capturada custa mais do que dez mal classificadas — as mal
/// classificadas corrigem-se em três segundos na triagem, a não capturada está
/// perdida para sempre.
struct CapturarView: View {
    @State var modelo: AppModel
    @Environment(\.dismiss) private var fechar

    @State private var texto = ""
    @State private var ditado = Ditado()
    @FocusState private var focado: Bool

    var body: some View {
        VStack(spacing: Tema.espaco) {
            TextField("O que te veio à cabeça?", text: $texto, axis: .vertical)
                .font(.title3)
                .lineLimit(3...5)
                .focused($focado)
                .submitLabel(.done)
                .onSubmit(guardar)

            HStack(spacing: Tema.espaco) {
                BotaoDeMicrofone(ditado: $ditado, texto: $texto)

                Spacer()

                Button("Assentar", action: guardar)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let erro = ditado.erro {
                Text(erro)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Tema.espaco * 1.25)
        .presentationDragIndicator(.visible)
        .onAppear { focado = true }
        .interactiveDismissDisabled(ditado.aGravar)
    }

    private func guardar() {
        let conteudo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !conteudo.isEmpty else { return }
        modelo.capturar(conteudo, audioPath: ditado.caminhoDoAudio, origem: .app)

        // Sem alerta de confirmação: um "guardado!" custa quase um segundo e não
        // acrescenta informação. O háptico chega, e o ecrã fechar é a prova.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        texto = ""
        fechar()
    }
}

struct BotaoDeMicrofone: View {
    @Binding var ditado: Ditado
    @Binding var texto: String

    var body: some View {
        Button {
            if ditado.aGravar {
                ditado.parar()
            } else {
                ditado.comecar { transcrito in
                    texto = transcrito
                }
            }
        } label: {
            Image(systemName: ditado.aGravar ? "stop.circle.fill" : "mic.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(ditado.aGravar ? Color.red : Color.accentColor)
                .symbolEffect(.pulse, isActive: ditado.aGravar)
        }
        .frame(minWidth: Tema.alvoMinimo, minHeight: Tema.alvoMinimo)
        .accessibilityLabel(ditado.aGravar ? "Parar de gravar" : "Ditar")
    }
}

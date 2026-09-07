import SwiftUI
import BussolaDomain

/// Os tokens visuais.
///
/// A app usa-se em dois contextos muito diferentes e ambos mandam no desenho:
/// na obra, com pó e sem óculos, e às 21h no escuro com a criança a dormir ao
/// lado. Daí o contraste alto, os alvos grandes e o modo escuro a sério.
public enum Tema {
    // Latão sobre ardósia. O latão é o acento, e só ele.
    public static let acento = Color("Acento", bundle: .main)

    public static let fundo = Color(.systemGroupedBackground)
    public static let superficie = Color(.secondarySystemGroupedBackground)
    public static let tinta = Color(.label)
    public static let tintaSecundaria = Color(.secondaryLabel)
    public static let tenue = Color(.tertiaryLabel)

    public static let raio: CGFloat = 12
    public static let espaco: CGFloat = 16
    /// Mínimo da Apple para alvos de toque. Não se desce daqui.
    public static let alvoMinimo: CGFloat = 44
}

public extension AreaTemperature {
    /// Semântica, separada do acento da marca.
    var cor: Color {
        switch self {
        case .viva:      .green
        case .arrefecer: .yellow
        case .fria:      .orange
        case .escura:    .red
        }
    }
}

public extension AreaID {
    var cor: Color {
        switch self {
        case .agencia:  .indigo
        case .clientes: .teal
        case .familia:  .pink
        case .obras:    .brown
        case .pessoal:  .mint
        }
    }
}

public extension Energy {
    var simbolo: String {
        switch self {
        case .deep:    "brain.head.profile"
        case .shallow: "circle.dotted"
        case .admin:   "tray.full"
        }
    }
}

/// Cartão de superfície. Usa-se onde há mesmo um objecto separado — não em
/// tudo, senão a hierarquia achata-se e deixa de haver ênfase nenhuma.
public struct CartaoModifier: ViewModifier {
    var destaque: Bool = false

    public func body(content: Content) -> some View {
        content
            .padding(Tema.espaco)
            .background(Tema.superficie, in: RoundedRectangle(cornerRadius: Tema.raio))
            .overlay {
                if destaque {
                    RoundedRectangle(cornerRadius: Tema.raio)
                        .strokeBorder(Tema.acento, lineWidth: 1.5)
                }
            }
    }
}

public extension View {
    func cartao(destaque: Bool = false) -> some View {
        modifier(CartaoModifier(destaque: destaque))
    }
}

/// Etiqueta de área: cor **e** texto. A cor nunca é o único sinal — nem para
/// quem não a distingue, nem para quem lê o ecrã ao sol.
public struct EtiquetaDeArea: View {
    let area: AreaID

    public init(_ area: AreaID) { self.area = area }

    public var body: some View {
        Label {
            Text(area.nome)
        } icon: {
            Image(systemName: area.simbolo)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(area.cor)
        .accessibilityLabel("Área \(area.nome)")
    }
}

/// Formata durações como se fala: "1h30", não "90 minutos".
public enum Duracao {
    public static func texto(_ minutos: Int) -> String {
        if minutos < 60 { return "\(minutos) min" }
        let h = minutos / 60, m = minutos % 60
        return m == 0 ? "\(h)h" : "\(h)h\(String(format: "%02d", m))"
    }
}

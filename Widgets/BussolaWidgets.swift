import WidgetKit
import SwiftUI
import AppIntents
import BussolaDomain
import BussolaPersistence

// MARK: - Captura

/// O widget que existe para uma coisa só: capturar sem abrir a app.
///
/// `Button(intent:)` executa o intent no processo do widget — no ecrã
/// bloqueado, sem desbloquear o telemóvel. É o caminho mais curto que o sistema
/// oferece entre ter a ideia e ela estar guardada.
struct CapturaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pt.bussola.captura", provider: CapturaProvider()) { entrada in
            CapturaWidgetView(pendentes: entrada.pendentes)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Capturar")
        .description("Assenta um pensamento sem abrir a app.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct CapturaEntry: TimelineEntry {
    let date: Date
    let pendentes: Int
}

struct CapturaProvider: TimelineProvider {
    func placeholder(in context: Context) -> CapturaEntry {
        CapturaEntry(date: Date(), pendentes: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CapturaEntry) -> Void) {
        completion(CapturaEntry(date: Date(), pendentes: contagem()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CapturaEntry>) -> Void) {
        let entrada = CapturaEntry(date: Date(), pendentes: contagem())
        // Uma hora chega: este widget é um botão, não um mostrador.
        completion(Timeline(entries: [entrada], policy: .after(Date().addingTimeInterval(3600))))
    }

    private func contagem() -> Int {
        guard let directorio = InboxSpool.directorioDoAppGroup(BussolaStore.appGroupID) else {
            return 0
        }
        return InboxSpool(directory: directorio).contagemPendente()
    }
}

struct CapturaWidgetView: View {
    let pendentes: Int
    @Environment(\.widgetFamily) private var familia

    var body: some View {
        switch familia {
        case .accessoryCircular:
            Button(intent: CapturarPorVozIntent()) {
                Image(systemName: "mic.fill")
            }
            .buttonStyle(.plain)

        default:
            VStack(spacing: 10) {
                Button(intent: CapturarPorVozIntent()) {
                    Label("Capturar", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)

                if pendentes > 0 {
                    Text("\(pendentes) por importar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Hoje

/// A Rocha e as Pedras, no ecrã principal.
///
/// Lê um instantâneo escrito pela app no App Group, em vez de abrir o
/// `ModelContainer`: um widget que monta SwiftData e sincroniza CloudKit para
/// mostrar quatro linhas de texto é um widget que o sistema mata.
struct HojeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pt.bussola.hoje", provider: HojeProvider()) { entrada in
            HojeWidgetView(instantaneo: entrada.instantaneo)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hoje")
        .description("A Rocha e as Pedras de hoje.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

struct HojeEntry: TimelineEntry {
    let date: Date
    let instantaneo: InstantaneoDoDia?
}

struct HojeProvider: TimelineProvider {
    func placeholder(in context: Context) -> HojeEntry {
        HojeEntry(date: Date(), instantaneo: .exemplo)
    }

    func getSnapshot(in context: Context, completion: @escaping (HojeEntry) -> Void) {
        completion(HojeEntry(date: Date(), instantaneo: InstantaneoDoDia.ler() ?? .exemplo))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HojeEntry>) -> Void) {
        let entrada = HojeEntry(date: Date(), instantaneo: InstantaneoDoDia.ler())
        // Refrescar à hora seguinte, e o ritual força uma actualização ao fechar.
        let proxima = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entrada], policy: .after(proxima)))
    }
}

struct HojeWidgetView: View {
    let instantaneo: InstantaneoDoDia?

    var body: some View {
        if let instantaneo, !instantaneo.estaVazio {
            VStack(alignment: .leading, spacing: 7) {
                if let rocha = instantaneo.rocha {
                    HStack(spacing: 6) {
                        Image(systemName: "mountain.2.fill").font(.caption)
                        Text(rocha)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                    }
                }
                ForEach(Array(instantaneo.pedras.enumerated()), id: \.offset) { indice, pedra in
                    HStack(spacing: 6) {
                        Image(systemName: indice == 0 ? "largecircle.fill.circle" : "circle")
                            .font(.caption2)
                            .foregroundStyle(indice == 0 ? .primary : .tertiary)
                        Text(pedra)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(indice == 0 ? .primary : .secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 6) {
                Text("O dia ainda não está decidido")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "bussola://ritual")!) {
                    Text("Fazer o ritual").font(.caption.weight(.medium))
                }
            }
        }
    }
}

// MARK: - Termómetro

struct TermometroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pt.bussola.termometro", provider: HojeProvider()) { entrada in
            TermometroWidgetView(areas: entrada.instantaneo?.areas ?? [])
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Termómetro")
        .description("Quanto tempo desde que tocaste em cada área.")
        .supportedFamilies([.systemSmall])
    }
}

struct TermometroWidgetView: View {
    let areas: [InstantaneoDoDia.AreaResumo]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(areas, id: \.nome) { area in
                HStack(spacing: 6) {
                    Circle().fill(cor(area.temperatura)).frame(width: 7, height: 7)
                    Text(area.nome).font(.caption2).lineLimit(1)
                    Spacer()
                    Text(area.dias).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cor(_ chave: String) -> Color {
        switch chave {
        case "viva":      .green
        case "arrefecer": .yellow
        case "fria":      .orange
        default:          .red
        }
    }
}

// MARK: - Bundle

@main
struct BussolaWidgetBundle: WidgetBundle {
    var body: some Widget {
        CapturaWidget()
        HojeWidget()
        TermometroWidget()
    }
}

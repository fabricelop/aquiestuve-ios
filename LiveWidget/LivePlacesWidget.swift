import ActivityKit
import WidgetKit
import SwiftUI

@main
struct AquiEstuveWidgetBundle: WidgetBundle {
    var body: some Widget { LivePlacesWidget() }
}

/// Keep the Lock Screen and expanded views under the system's 160-point budget.
/// Diagnostic mode uses NO deep links or external inputs, isolating rendering
/// failures from location/cache/deep-link problems.
struct LivePlacesWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LivePlaceAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("AquíEstuve", systemImage: "location.circle.fill")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(context.state.diagnostic ? "PRUEBA VISUAL" : "¿Dónde estás?")
                        .font(.caption2.bold())
                }
                if context.state.diagnostic {
                    Text("Panel de prueba visible en el iPhone")
                        .font(.subheadline.weight(.semibold))
                    Text("Si lees esto, la extensión se está dibujando correctamente.")
                        .font(.caption)
                } else if context.state.options.isEmpty {
                    Text("Abre AquíEstuve para cargar los sitios cercanos.")
                        .font(.caption)
                } else {
                    ForEach(context.state.options.prefix(3)) { option in
                        if let url = placeURL(option.id) {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                    Text(option.title).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(option.distance).font(.caption2)
                                    Image(systemName: "chevron.right").font(.caption2)
                                }
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        }
                    }
                }
                Text(context.state.diagnostic ? "No registra ninguna visita" : "Toca un lugar para revisar antes de confirmar")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(10)
            .activityBackgroundTint(.indigo.opacity(0.16))
            .activitySystemActionForegroundColor(.indigo)
            .widgetURL(URL(string: "aquiestuve://places"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("AquíEstuve", systemImage: "location.fill")
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.diagnostic ? "PRUEBA" : "\(context.state.options.count) cerca")
                        .font(.caption2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 7) {
                        if context.state.diagnostic {
                            Text("Diagnóstico: interfaz ampliada activa")
                                .font(.caption.bold())
                            Text("No se registra ninguna visita")
                                .font(.caption2)
                        } else if context.state.options.isEmpty {
                            Text("Abre la app para cargar lugares cercanos")
                                .font(.caption)
                        } else {
                            ForEach(context.state.options.prefix(3)) { option in
                                if let url = placeURL(option.id) {
                                    Link(destination: url) {
                                        HStack {
                                            Text(option.title).lineLimit(1)
                                            Spacer(minLength: 4)
                                            Text(option.distance).font(.caption2)
                                        }
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "location.circle.fill")
            } compactTrailing: {
                Text(context.state.diagnostic ? "TEST" : "\(context.state.options.count)")
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "location.circle.fill")
            }
            .widgetURL(URL(string: "aquiestuve://places"))
            .keylineTint(.indigo)
        }
    }
}

private func placeURL(_ id: String) -> URL? {
    var url = URLComponents()
    url.scheme = "aquiestuve"
    url.host = "place"
    url.queryItems = [URLQueryItem(name: "id", value: id)]
    return url.url
}

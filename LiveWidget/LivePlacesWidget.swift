import ActivityKit
import WidgetKit
import SwiftUI

@main
struct AquiEstuveWidgetBundle: WidgetBundle {
    var body: some Widget { LivePlacesWidget() }
}

struct LivePlacesWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LivePlaceAttributes.self) { context in
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("AquíEstuve", systemImage: "location.fill")
                        .font(.headline)
                    Spacer()
                    Text("Cerca de ti").font(.caption)
                }
                Text(context.state.title).font(.subheadline.weight(.semibold))
                if context.state.options.isEmpty {
                    Text("Abre AquíEstuve para buscar lugares cercanos.")
                        .font(.caption)
                } else {
                    ForEach(context.state.options.prefix(3)) { option in
                        if let url = placeURL(option.id) {
                            Link(destination: url) {
                                HStack(spacing: 7) {
                                    Image(systemName: "mappin.circle")
                                    Text(option.title).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(option.distance).font(.caption)
                                    Image(systemName: "chevron.right").font(.caption2)
                                }
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        }
                    }
                }
                Text("Toca un sitio para confirmar desde su ficha")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
            .activityBackgroundTint(.indigo.opacity(0.16))
            .activitySystemActionForegroundColor(.indigo)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("AquíEstuve", systemImage: "location.fill")
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(context.state.options.prefix(3)) { option in
                            if let url = placeURL(option.id) {
                                Link(destination: url) {
                                    HStack {
                                        Text(option.title).lineLimit(1)
                                        Spacer(minLength: 4)
                                        Text(option.distance).font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                    .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Toca un sitio para revisarlo").font(.caption2)
                }
            } compactLeading: {
                Image(systemName: "location.circle.fill")
            } compactTrailing: {
                Text("\(context.state.options.count)")
                    .font(.caption.weight(.bold))
            } minimal: {
                Image(systemName: "location.circle.fill")
            }
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

import ActivityKit
import Foundation

/// Shared, compact payload: an activity widget cannot access GPS or the network.
struct LivePlaceOption: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var distance: String
}

struct LivePlaceAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var updatedAt: Date
        var title: String
        var options: [LivePlaceOption]
    }
    var sessionID: String
}

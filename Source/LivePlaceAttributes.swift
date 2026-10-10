import ActivityKit
import Foundation

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
        /// A visual-only diagnostic: it must not create or confirm any visit.
        var diagnostic: Bool = false

        init(updatedAt: Date, title: String, options: [LivePlaceOption], diagnostic: Bool = false) {
            self.updatedAt = updatedAt
            self.title = title
            self.options = options
            self.diagnostic = diagnostic
        }
        private enum CodingKeys: String, CodingKey { case updatedAt, title, options, diagnostic }
        init(from decoder: Decoder) throws {
            let input = try decoder.container(keyedBy: CodingKeys.self)
            updatedAt = try input.decode(Date.self, forKey: .updatedAt)
            title = try input.decode(String.self, forKey: .title)
            options = try input.decode([LivePlaceOption].self, forKey: .options)
            diagnostic = try input.decodeIfPresent(Bool.self, forKey: .diagnostic) ?? false
        }
    }
    var sessionID: String
}

import Foundation

@main
struct CheckRadar {
    static func main() throws {
        func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError("Radar: " + message) }
        }
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let hereLat = 40.4168
        let hereLon = -3.7038
        var rule = RadarRule()
        verify(!rule.hidden(at: hereLat, hereLon, now: now), "new place visible")

        rule.favorite = true
        verify(!rule.hidden(at: hereLat, hereLon, now: now), "favorite is not a visit or hide")
        verify(RadarRanking.score(meters: 70, visits: 0, favorite: true) >
               RadarRanking.score(meters: 70, visits: 0, favorite: false), "favorite boost")
        verify(RadarRanking.score(meters: 5, visits: 0, favorite: false) >
               RadarRanking.score(meters: 190, visits: 0, favorite: true), "nearby should matter")

        rule.snoozedUntil = now.addingTimeInterval(4 * 3600)
        verify(rule.hidden(at: hereLat, hereLon, now: now), "temporary hide works")
        verify(!rule.hidden(at: hereLat, hereLon, now: now.addingTimeInterval(5 * 3600)),
               "temporary hide expires")

        rule.snoozedUntil = nil
        rule.hiddenAround = [RadarAnchor(latitude: hereLat, longitude: hereLon, createdAt: now)]
        verify(rule.hidden(at: hereLat, hereLon, now: now), "local zone hide")
        verify(!rule.hidden(at: 40.4268, hereLon, now: now), "not hidden globally")
        rule.hiddenAround = []
        rule.archived = true
        verify(rule.hidden(at: 40.4268, hereLon, now: now), "archived globally")
        rule.archived = false
        verify(!rule.hidden(at: hereLat, hereLon, now: now), "restore works")

        let stored = try JSONEncoder().encode(RadarSnapshot(rules: ["apple:venue-key": rule]))
        let decoded = try JSONDecoder().decode(RadarSnapshot.self, from: stored)
        verify(decoded.rules["apple:venue-key"] == rule, "lossless preferences persistence")
        verify(RadarRanking.score(meters: 100, visits: 5, favorite: false) >
               RadarRanking.score(meters: 100, visits: 0, favorite: false), "prior visits boost")
        print("10 Radar preference scenarios passed")
    }
}

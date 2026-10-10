import Foundation

@main
struct Tests {
    static func main() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let venue = UUID()
        func visit(_ from: Double, _ to: Double?, _ place: UUID?, _ lat: Double = 40.0,
                   _ lon: Double = -3.7, _ status: String = "unresolved", _ origin: String = "paseo") -> StayEvidence {
            StayEvidence(id: UUID(), placeID: place, latitude: lat, longitude: lon,
                         arrival: base.addingTimeInterval(from * 60),
                         departure: to.map { base.addingTimeInterval($0 * 60) },
                         status: status, origin: origin)
        }
        func assertCase(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError("Failed: " + message) }
        }
        // 11:02-12:34 contains 11:24-11:44; preserve confirmed.
        let college = StayReconciliation.reconcile([
            visit(0, 92, venue, 40, -3.7, "confirmed", "manual"),
            visit(22, 42, venue, 40.0001, -3.7, "unresolved", "paseo")
        ])
        assertCase(college.count == 1, "same-place contained interval must be merged")
        assertCase(college[0].status == "confirmed", "must preserve manual confirmation")
        assertCase(college[0].departure == base.addingTimeInterval(92*60), "must preserve full duration")

        let pending = StayReconciliation.reconcile([
            visit(136, 143, nil), visit(136, 143, nil, 40.0002, -3.7, "unresolved", "system")
        ])
        assertCase(pending.count == 1, "duplicate unnamed observations")

        let different = StayReconciliation.reconcile([
            visit(0, 60, venue, 40, -3.7, "confirmed"),
            visit(5, 55, UUID(), 40, -3.7, "confirmed")
        ])
        assertCase(different.count == 2, "different named venues must stay separate")

        let returnVisit = StayReconciliation.reconcile([
            visit(0, 20, venue), visit(20, 40, venue)
        ])
        assertCase(returnVisit.count == 2, "adjacent visits are distinct")

        let far = StayReconciliation.reconcile([
            visit(0, 20, nil, 40, -3.7), visit(5, 20, nil, 40.003, -3.7)
        ])
        assertCase(far.count == 2, "distant sites cannot merge")

        let assigned = StayReconciliation.reconcile([
            visit(0, 40, nil, 40, -3.7), visit(15, 35, venue, 40, -3.7, "confirmed")
        ])
        assertCase(assigned.count == 1 && assigned[0].placeID == venue, "named confirmation wins")
        assertCase(assigned[0].status == "confirmed", "confirmation is preserved")
        print("7 episode reconciliation scenarios passed")
    }
}

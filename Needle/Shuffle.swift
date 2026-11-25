import Foundation

enum Shuffle {
    static func deal(_ tracks: [Track], avoiding recent: Set<String>) -> [Track] {
        var seen = Set<String>()
        let unique = tracks.filter { $0.isLocal != true && seen.insert($0.uri).inserted }
        let fresh = unique.filter { !recent.contains($0.uri) }
        let stale = unique.filter { recent.contains($0.uri) }
        return spread(fresh) + spread(stale)
    }

    private static func spread(_ tracks: [Track]) -> [Track] {
        let groups = Dictionary(grouping: tracks.shuffled(), by: \.lead)
        var placed: [(spot: Double, track: Track)] = []
        for group in groups.values {
            let step = 1 / Double(group.count)
            var spot = Double.random(in: 0..<step)
            for track in group {
                placed.append((spot + Double.random(in: -0.15...0.15) * step, track))
                spot += step
            }
        }
        var order = placed.sorted { $0.spot < $1.spot }.map(\.track)
        untangle(&order)
        return order
    }

    private static func untangle(_ order: inout [Track]) {
        guard order.count > 2 else { return }
        for i in 1..<order.count where order[i].lead == order[i - 1].lead {
            let end = min(order.count, i + 200)
            guard i + 1 < end else { continue }
            for j in (i + 1)..<end {
                order.swapAt(i, j)
                if clean(order, at: [i, j]) {
                    break
                }
                order.swapAt(i, j)
            }
        }
    }

    private static func clean(_ list: [Track], at spots: [Int]) -> Bool {
        spots.allSatisfy { k in
            let before = k == 0 || list[k].lead != list[k - 1].lead
            let after = k == list.count - 1 || list[k].lead != list[k + 1].lead
            return before && after
        }
    }
}

import Foundation

/// Logical main-grid dimensions, independent of viewport fit and folder layout.
public struct MainGridCapacity: Codable, Equatable, Sendable {
    public static let supportedDimensions = 3...8
    public let columns: Int
    public let rows: Int

    public init?(columns: Int, rows: Int) {
        guard Self.supportedDimensions.contains(columns),
              Self.supportedDimensions.contains(rows) else { return nil }
        self.columns = columns
        self.rows = rows
    }

    private init(defaultColumns: Int, defaultRows: Int) {
        columns = defaultColumns
        rows = defaultRows
    }

    public static let `default` = MainGridCapacity(defaultColumns: 5, defaultRows: 7)
    public var itemsPerPage: Int { columns * rows }

    private enum CodingKeys: String, CodingKey { case columns, rows }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let columns = try container.decode(Int.self, forKey: .columns)
        let rows = try container.decode(Int.self, forKey: .rows)
        guard let value = Self(columns: columns, rows: rows) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Main-grid columns and rows must each be in 3...8."
            ))
        }
        self = value
    }
}

/// Relocation data only. The owner retains responsibility for focus visibility,
/// deferred keyboard admission, query state, and the safe layout boundary.
public struct MainGridCapacityRelocation: Equatable, Sendable {
    public let pageIndex: Int
    public let anchorIdentity: TopLevelEntryIdentity?
    public let selectedIdentity: TopLevelEntryIdentity?
    public let selectedPageIndex: Int?
    public let selectedSlotIndex: Int?
}

public enum MainGridCapacityAnchorRelocation {
    /// Input arrays are the old and current visible sequences, never canonical
    /// workspace order. No identity is selected merely to supply an anchor.
    /// An exhausted old page falls back to the nearest surviving old identity
    /// by distance from its first slot, with lower old indices winning ties.
    public static func relocate(
        previousEntries: [TopLevelEntryIdentity],
        currentEntries: [TopLevelEntryIdentity],
        currentPageIndex: Int,
        selectedIdentity: TopLevelEntryIdentity?,
        from oldCapacity: MainGridCapacity,
        to newCapacity: MainGridCapacity
    ) -> MainGridCapacityRelocation {
        guard !currentEntries.isEmpty else {
            return .init(pageIndex: 0, anchorIdentity: nil, selectedIdentity: nil,
                         selectedPageIndex: nil, selectedSlotIndex: nil)
        }
        // Clamp before multiplying so even hostile page indices cannot overflow.
        let oldLastPage = previousEntries.isEmpty ? 0 : (previousEntries.count - 1) / oldCapacity.itemsPerPage
        let oldPage = min(max(currentPageIndex, 0), oldLastPage)
        let start = oldPage * oldCapacity.itemsPerPage
        let end = start + min(oldCapacity.itemsPerPage, previousEntries.count - start)
        var currentIndices: [TopLevelEntryIdentity: Int] = [:]
        for (index, identity) in currentEntries.enumerated() where currentIndices[identity] == nil {
            currentIndices[identity] = index
        }
        let selectedIndex = selectedIdentity.flatMap { currentIndices[$0] }
        var anchor: TopLevelEntryIdentity?
        if let selectedIdentity, selectedIndex != nil,
           previousEntries[start..<end].contains(selectedIdentity) {
            anchor = selectedIdentity
        } else {
            anchor = previousEntries[start..<end].first { currentIndices[$0] != nil }
        }
        if anchor == nil {
            let nearest = previousEntries.indices.filter { currentIndices[previousEntries[$0]] != nil }
                .min { lhs, rhs in
                    let leftDistance = lhs >= start ? lhs - start : start - lhs
                    let rightDistance = rhs >= start ? rhs - start : start - rhs
                    return leftDistance == rightDistance ? lhs < rhs : leftDistance < rightDistance
                }
            anchor = nearest.map { previousEntries[$0] }
                ?? currentEntries[min(start, currentEntries.count - 1)]
        }
        let anchorIndex = anchor.flatMap { currentIndices[$0] } ?? 0
        return .init(pageIndex: anchorIndex / newCapacity.itemsPerPage,
                     anchorIdentity: anchor,
                     selectedIdentity: selectedIndex == nil ? nil : selectedIdentity,
                     selectedPageIndex: selectedIndex.map { $0 / newCapacity.itemsPerPage },
                     selectedSlotIndex: selectedIndex.map { $0 % newCapacity.itemsPerPage })
    }
}

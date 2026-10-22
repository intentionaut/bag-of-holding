/// Picks one item at random, never the one it picked last.
/// With a single item there is nothing else to give, so that item comes back.
public struct Picker<ID: Hashable> {
    public private(set) var last: ID?

    public init() {}

    /// `avoiding` holds items already shown this round (the bad-day run of three);
    /// they are skipped while anything else is left.
    public mutating func next<R: RandomNumberGenerator>(
        from ids: [ID], avoiding: Set<ID> = [], using rng: inout R
    ) -> ID? {
        guard !ids.isEmpty else { return nil }
        var pool = ids.filter { $0 != last && !avoiding.contains($0) }
        if pool.isEmpty { pool = ids.filter { $0 != last } }
        if pool.isEmpty { pool = ids }
        let pick = pool.randomElement(using: &rng)!
        last = pick
        return pick
    }
}
